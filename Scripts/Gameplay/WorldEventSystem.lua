if Debug and Debug.beginFile then Debug.beginFile("WorldEventSystem.lua") end
--==================================================
-- WorldEventSystem.lua
-- Version v0.09a
-- • Central manager for world and zone events
-- • One active event at a time (simple director)
-- • Events are table-driven: id, zone, duration, cooldown, weight, callbacks
-- • Uses ProcBus.Emit if available for start/end notifications
--==================================================

WorldEventSystem = WorldEventSystem or {}
_G.WorldEventSystem = WorldEventSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TICK_SECONDS      = 1.0     -- driver tick
    local ROLL_INTERVAL     = 15.0    -- how often we attempt to start a new event
    local DEBUG             = false   -- set true to spam prints

    -- Global warmup delay before ANY events can roll (seconds)
    local WORLD_EVENT_WARMUP_TIME = 10.00

    -- Spirit Surge reward tuning
    local SPIRIT_SURGE_SOUL_PER_KILL   = 5   -- Soul XP per HFIL kill
    local SPIRIT_SURGE_FRAG_PER_KILL   = 1   -- fragment currency per HFIL kill

    -- Spirit Surge spawn tuning
    local SPIRIT_SURGE_SPAWN_INTERVAL  = 20.0  -- currently unused, but kept as a tweakable
    local SPIRIT_SURGE_MAX_WAVES       = 5     -- max waves per event
    local SPIRIT_SURGE_UNITS_PER_POINT = 2     -- how many mobs per spawn point per wave

    -- Range to consider players "near" a spawn point for local avg power
    local SPIRIT_SURGE_PLAYER_RANGE   = 2000.0

    -- Beacon FX for spawn points (beam) + circle FX for area marker
    local SPIRIT_SURGE_BEACON_FX       = "Effect\\enviroment\\DigiRay.mdx"
    local SPIRIT_SURGE_CIRCLE_FX       = "Effect\\GroundCircles\\Spell_Marker_100.mdl"
    local TEX_BG                       = "UI\\Widgets\\EscMenu\\NightElf\\nightelf-options-menu-background.blp"

    -- Spirit Surge item pool (rarity + weight)
    local SPIRIT_SURGE_ITEM_POOL = {
        {
            id     = FourCC("I00W"),   -- Goku Shard (placeholder)
            rarity = "legendary",
            weight = 1,
        },
    }

    --------------------------------------------------
    -- Locals / State
    --------------------------------------------------
    local eventsById  = {}   -- id  -> def
    local eventList   = {}   -- array of defs
    local cooldownEnd = {}   -- id  -> game time when event can next start
    local readyFlag   = {}   -- id  -> true if externally flagged

    local activeId      = nil
    local activeEvent   = nil
    local activeContext = nil

    local nowTime       = 0.0
    local lastRollTime  = 0.0

    local ProcBus       = rawget(_G, "ProcBus")

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function debugPrint(msg)
        if not DEBUG then return end
        print("[WorldEventSystem] " .. tostring(msg))
    end

    local function emit(channel, payload)
        if not ProcBus or not ProcBus.Emit then return end
        local ok, err = pcall(ProcBus.Emit, channel, payload)
        if not ok and DEBUG then
            print("[WorldEventSystem] ProcBus error: " .. tostring(err))
        end
    end

    local function isPlayerSlotActive(pid)
        local p = Player(pid)
        return GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING
           and GetPlayerController(p) == MAP_CONTROL_USER
    end

    -- Safe PlayerData accessor
    local function PD(pid)
        if not _G.PlayerData or not PlayerData.Get then
            return nil
        end
        local ok, pd = pcall(PlayerData.Get, pid)
        if not ok then
            return nil
        end
        return pd
    end

    -- Zone helper (uses PD so it works with current PlayerData layout)
    local function anyPlayerInZone(zoneId)
        if not zoneId then
            return false
        end

        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isPlayerSlotActive(pid) then
                local pd = PD(pid)
                if pd and pd.zone == zoneId then
                    return true
                end
            end
        end
        return false
    end

    local function registerEvent(def)
        if not def or not def.id then
            debugPrint("Tried to register event without id")
            return
        end
        if eventsById[def.id] then
            debugPrint("Event already registered: " .. tostring(def.id))
            return
        end
        eventsById[def.id] = def
        eventList[#eventList + 1] = def
        debugPrint("Registered event " .. tostring(def.id))
    end

    --------------------------------------------------
    -- World Event UI
    --------------------------------------------------
    local ZONE_LABELS = {
        HFIL          = "HFIL - Home For Infinite Losers",
        REBIRTH_POOLS = "Rebirth Pools",
        BUREAU        = "King Yemma's Bureau",
        NEO_CAPSULE   = "Neo Capsule City",
        FOREST        = "Viridian Forest",
        DIGITAL_SEA   = "Digital Sea",
        LAND_OF_FIRE  = "Land of Fire",
    }

    local function getZoneLabel(zoneId)
        if not zoneId then
            return ""
        end
        local label = ZONE_LABELS[zoneId]
        if label then
            return label
        end
        return tostring(zoneId)
    end

    -- Average power level for all players currently in a given zone
    local function getZoneAveragePower(zoneId)
        if not zoneId then
            return 0
        end

        local total = 0
        local count = 0

        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isPlayerSlotActive(pid) then
                local pd = PD(pid)
                if pd and pd.zone == zoneId then
                    local stats = pd.stats or {}
                    local pwr = stats.power or 0
                    total = total + pwr
                    count = count + 1
                end
            end
        end

        if count == 0 then
            return 0
        end
        return total / count
    end

    -- Per-player UI frames
    local eventUIByPid = {} -- pid -> { panel, title, zone, info }

local function ensureEventUI(pid)
    local existing = eventUIByPid[pid]
    if existing then
        return existing
    end

    local parentFrame = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
    local panel = BlzCreateFrameByType("FRAME", "WorldEventPanel_" .. tostring(pid), parentFrame, "", 0)

    -- Size/position: top-center bar
    BlzFrameSetSize(panel, 0.28, 0.10)
    BlzFrameSetPoint(panel, FRAMEPOINT_TOP, parentFrame, FRAMEPOINT_TOP, -0.25, -0.10)

    -- Background frame (BACKDROP)
    local background = BlzCreateFrameByType("BACKDROP", "WorldEventBG_" .. tostring(pid), panel, "", 0)
    BlzFrameSetTexture(background, TEX_BG, 0, true)  -- Set your background texture here
    BlzFrameSetPoint(background, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, 0.0, 0.0)  -- Align it to the panel
    BlzFrameSetPoint(background, FRAMEPOINT_BOTTOMRIGHT, panel, FRAMEPOINT_BOTTOMRIGHT, 0.0, 0.0)  -- Stretch to the panel's size

    -- Title: [World Event] Event Name
    local title = BlzCreateFrameByType("TEXT", "WorldEventTitle_" .. tostring(pid), panel, "", 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, 0.0, 0.0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOPRIGHT, panel, FRAMEPOINT_TOPRIGHT, 0.0, 0.0)
    BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)

    -- Zone line: Zone Name (we will reuse this as general info header)
    local zoneText = BlzCreateFrameByType("TEXT", "WorldEventZone_" .. tostring(pid), panel, "", 0)
    BlzFrameSetPoint(zoneText, FRAMEPOINT_TOPLEFT, title, FRAMEPOINT_BOTTOMLEFT, 0.0, -0.004)
    BlzFrameSetPoint(zoneText, FRAMEPOINT_TOPRIGHT, title, FRAMEPOINT_BOTTOMRIGHT, 0.0, -0.004)
    BlzFrameSetTextAlignment(zoneText, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)

    -- Info line: wave / kills / etc
    local info = BlzCreateFrameByType("TEXT", "WorldEventInfo_" .. tostring(pid), panel, "", 0)
    BlzFrameSetPoint(info, FRAMEPOINT_TOPLEFT, zoneText, FRAMEPOINT_BOTTOMLEFT, 0.0, -0.004)
    BlzFrameSetPoint(info, FRAMEPOINT_TOPRIGHT, zoneText, FRAMEPOINT_BOTTOMRIGHT, 0.0, -0.004)
    BlzFrameSetTextAlignment(info, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)

    -- Make the panel visible now that it's all set
    BlzFrameSetVisible(panel, true)

    -- Store the UI for later access
    eventUIByPid[pid] = {
        panel = panel,
        title = title,
        zone  = zoneText,
        info  = info,
        background = background,
    }
    return eventUIByPid[pid]
end


    local function hideAllEventUI()
        for pid, ui in pairs(eventUIByPid) do
            if ui and ui.panel then
                BlzFrameSetVisible(ui.panel, false)
            end
        end
    end

    -- New: update UI with Spirit Surge stats
    local function refreshSpiritSurgeUI(ctx)
        if not ctx or not ctx.data then
            return
        end

        local zoneId    = ctx.zone
        local zoneLabel = getZoneLabel(zoneId)
        local avgPower  = ctx.data.avgPower or 0
        local wave      = ctx.data.waveCount or 0
        local maxWaves  = SPIRIT_SURGE_MAX_WAVES
        local totalMobs = ctx.data.lastWaveTotalMobs or 0

        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isPlayerSlotActive(pid) then
                local ui = ensureEventUI(pid)

                -- Title
                local eventName = activeEvent and (activeEvent.name or activeEvent.id or "") or ""
                if eventName ~= "" then
                    BlzFrameSetText(ui.title, "|cffffe080[World Event]|r " .. eventName)
                else
                    BlzFrameSetText(ui.title, "|cffffe080[World Event]|r")
                end

                -- Zone line: zone + avg power + wave
                local avgRounded = R2I(avgPower + 0.5)
                local zoneLine = ""
                if zoneLabel ~= "" then
                    zoneLine = zoneLabel .. "  |  Wave " .. tostring(wave) .. "/" .. tostring(maxWaves) ..
                               "  |  Avg Power: " .. tostring(avgRounded)
                end
                BlzFrameSetText(ui.zone, zoneLine)

                -- Player-specific info: their kills vs total mobs
                local killsByPlayer = ctx.killsByPlayer or {}
                local myKills       = killsByPlayer[pid] or 0

                local infoText = "Your Kills: " .. tostring(myKills) ..
                                 "  |  Total Wave Mobs: " .. tostring(totalMobs)
                BlzFrameSetText(ui.info, infoText)

                BlzFrameSetVisible(ui.panel, true)
            end
        end
    end

    local function pushEventMessage(pid, text, duration)
        local p = Player(pid)
        if not p or text == nil then
            return 0
        end

        local ui = ensureEventUI(pid)

        -- Title
        local eventName = ""
        if activeEvent then
            if activeEvent.name then
                eventName = activeEvent.name
            elseif activeEvent.id then
                eventName = activeEvent.id
            end
        end
        if eventName ~= "" then
            BlzFrameSetText(ui.title, "|cffffe080[World Event]|r " .. eventName)
        else
            BlzFrameSetText(ui.title, "|cffffe080[World Event]|r")
        end

        -- Generic zone/line (we keep basic version here for non-Spirit-Surge messages)
        local zoneId = activeEvent and activeEvent.zone or nil
        local zoneLabel = getZoneLabel(zoneId)
        if zoneLabel ~= "" then
            local avgPower = getZoneAveragePower(zoneId)
            local rounded = R2I(avgPower + 0.5)
            BlzFrameSetText(ui.zone, zoneLabel .. "  (Avg Power: " .. tostring(rounded) .. ")")
        else
            BlzFrameSetText(ui.zone, "")
        end

        -- Info/message line
        BlzFrameSetText(ui.info, text or "")

        BlzFrameSetVisible(ui.panel, true)

        -- Duration unused for now
        return 0
    end

    -- Public wrappers
    function WorldEventSystem.PushMessage(pid, text, duration)
        return pushEventMessage(pid, text, duration)
    end

    function WorldEventSystem.ClearMessages()
        hideAllEventUI()
    end

    --------------------------------------------------
    -- Event lifecycle
    --------------------------------------------------
    local function endActiveEvent(reason)
        if not activeEvent or not activeContext then
            return
        end

        local id   = activeEvent.id
        local zone = activeEvent.zone

        debugPrint("Ending event " .. tostring(id) .. " (" .. tostring(reason) .. ")")

        cooldownEnd[id] = nowTime + (activeEvent.cooldown or 0.0)

        if activeEvent.onEnd then
            local ok, err = pcall(activeEvent.onEnd, activeContext, nowTime, reason or "timeout")
            if not ok and DEBUG then
                debugPrint("onEnd error for " .. tostring(id) .. ": " .. tostring(err))
            end
        end

        emit("WorldEventEnded", { id = id, zone = zone, reason = reason })

        activeId      = nil
        activeEvent   = nil
        activeContext = nil

        hideAllEventUI()
    end

    local function startEvent(ev)
        local id   = ev.id
        local zone = ev.zone

        activeId    = id
        activeEvent = ev
        activeContext = {
            id              = id,
            zone            = zone,
            startedAt       = nowTime,
            elapsed         = 0.0,
            data            = {},     -- event-local storage
            killsByPlayer   = {},     -- pid -> count
            actionsByPlayer = {},     -- pid -> { [kind] = count },
        }

        debugPrint("Starting event " .. tostring(id))

        emit("WorldEventStarted", { id = id, zone = zone })

        if ev.onStart then
            local ok, err = pcall(ev.onStart, activeContext, nowTime)
            if not ok and DEBUG then
                debugPrint("onStart error for " .. tostring(id) .. ": " .. tostring(err))
            end
        end
    end

    local function pickAndStartEvent()
        local candidates  = {}
        local cumulative  = {}
        local totalWeight = 0.0

        for i = 1, #eventList do
            local ev = eventList[i]
            local id = ev.id

            local cdEnd = cooldownEnd[id] or 0.0
            if nowTime >= cdEnd then
                local ok = true

                if ev.checkTrigger then
                    local status, res = pcall(ev.checkTrigger, ev, nowTime, readyFlag[id])
                    ok = status and res and true or false
                end

                if ok then
                    local w = ev.weight or 1.0
                    if w > 0 then
                        totalWeight = totalWeight + w
                        candidates[#candidates + 1] = ev
                        cumulative[#cumulative + 1] = totalWeight
                    end
                end
            end
        end

        if totalWeight <= 0 then
            return
        end

        local r = math.random() * totalWeight
        local choice = candidates[#candidates]

        for i = 1, #candidates do
            if r <= cumulative[i] then
                choice = candidates[i]
                break
            end
        end

        if choice then
            readyFlag[choice.id] = nil
            startEvent(choice)
        end
    end

    local function driverTick()
        nowTime = nowTime + TICK_SECONDS

        if activeEvent and activeContext then
            activeContext.elapsed = nowTime - activeContext.startedAt

            if activeEvent.onTick then
                local ok, err = pcall(activeEvent.onTick, activeContext, nowTime, TICK_SECONDS)
                if not ok and DEBUG then
                    debugPrint("onTick error for " .. tostring(activeEvent.id) .. ": " .. tostring(err))
                end
            end

            if activeContext.forceEndReason then
                endActiveEvent(activeContext.forceEndReason)
                return
            end

            local duration = activeEvent.duration or 0.0
            if duration > 0 and activeContext.elapsed >= duration then
                endActiveEvent("timeout")
            end

            return
        end

        -- Global warmup
        if nowTime < WORLD_EVENT_WARMUP_TIME then
            return
        end

        if nowTime - lastRollTime < ROLL_INTERVAL then
            return
        end
        lastRollTime = nowTime

        pickAndStartEvent()
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function WorldEventSystem.IsActive(id)
        if not activeId then
            return false
        end
        if not id then
            return true
        end
        return activeId == id
    end

    function WorldEventSystem.GetActiveId()
        return activeId
    end

    function WorldEventSystem.GetActiveContext()
        return activeContext
    end

    function WorldEventSystem.GetEventDef(id)
        return eventsById[id]
    end

    function WorldEventSystem.MarkEventReady(id)
        if not id or not eventsById[id] then
            return
        end
        readyFlag[id] = true
        debugPrint("Event marked ready: " .. tostring(id))
    end

    function WorldEventSystem.ForceEndActive(reason)
        if not activeContext then
            return
        end
        activeContext.forceEndReason = reason or "forced"
    end

    function WorldEventSystem.AddKillContribution(pid, amount)
        if not activeContext then
            return
        end
        local kills = activeContext.killsByPlayer
        local old   = kills[pid] or 0
        kills[pid]  = old + (amount or 1)
    end

    function WorldEventSystem.AddActionContribution(pid, kind, amount)
        if not activeContext then
            return
        end
        local actions = activeContext.actionsByPlayer
        actions[pid]  = actions[pid] or {}
        local old     = actions[pid][kind] or 0
        actions[pid][kind] = old + (amount or 1)
    end

    function WorldEventSystem.ReportKill(killed, killer)
        if not activeEvent or not activeContext then
            return
        end
        if activeEvent.onKill then
            local ok, err = pcall(activeEvent.onKill, activeContext, killed, killer)
            if not ok and DEBUG then
                debugPrint("onKill error for " .. tostring(activeEvent.id) .. ": " .. tostring(err))
            end
        end
    end

    function WorldEventSystem.ReportAction(pid, kind, amount)
        if not activeEvent or not activeContext then
            return
        end
        WorldEventSystem.AddActionContribution(pid, kind, amount or 1)

        if activeEvent.onAction then
            local ok, err = pcall(activeEvent.onAction, activeContext, pid, kind, amount or 1)
            if not ok and DEBUG then
                debugPrint("onAction error for " .. tostring(activeEvent.id) .. ": " .. tostring(err))
            end
        end
    end

    --------------------------------------------------
    -- Threat registration helper (for spawned event mobs)
    --------------------------------------------------
    local function registerThreatUnit(u, packId)
        if not u or GetUnitTypeId(u) == 0 then
            return
        end
        local TS = rawget(_G, "ThreatSystem")
        if not TS then
            return
        end
        if TS.Register then
            -- TS.Register(u) -- left disabled for now
        end
    end

    function WorldEventSystem.RegisterSpawnedUnit(u)
        registerThreatUnit(u)
    end

    --------------------------------------------------
    -- HFIL helpers for Spirit Surge
    --------------------------------------------------
    local HFIL_UNIT_TYPES = {
        [FourCC("n001")] = true,
        [FourCC("n00G")] = true,
        [FourCC("n00U")] = true,
        [FourCC("n00W")] = true,
        [FourCC("n00T")] = true,
        [FourCC("n00Y")] = true,
        [FourCC("n00L")] = true,
        [FourCC("n00Z")] = true,
        [FourCC("n010")] = true,
    }

    local function isHFILCreep(u)
        if not u or GetUnitTypeId(u) == 0 then
            return false
        end
        local ut = GetUnitTypeId(u)
        return HFIL_UNIT_TYPES[ut] and true or false
    end

    --------------------------------------------------
    -- HFIL mob tiers for Spirit Surge (spawn logic)
    --------------------------------------------------
    local HFIL_MOB_POOLS = {
        tier1 = {
            "n001",
            "n00G",
        },
        tier2 = {
            "n00U",
            "n00W",
            "n00T",
            "n00Y",
        },
        tier3 = {
            "n00L",
            "n00Z",
            "n010",
        },
        miniboss = {
            -- "n0A0",
        },
    }

    --------------------------------------------------
    -- HFIL spawn points
    --------------------------------------------------
    local HFIL_SPAWN_POINTS = {
        entrance = {
            category = "starter",
            points = {
                { x = 27736.6, y = -21433.3, z = 588.0 },
                { x = 28148.3, y = -21764.1, z = 572.8 },
            },
        },
        graveyard = {
            category = "high",
            points = {
                { x = 22214.6, y = -21763.6, z = 343.7 },
                { x = 23208.9, y = -20683.4, z = 308.3 },
                { x = 23801.1, y = -21355.9, z = 308.2 },
            },
        },
    }

    local function getHFILSubzoneNames()
        local names = {}
        for name, info in pairs(HFIL_SPAWN_POINTS) do
            local pts = info.points or info
            if pts and #pts > 0 then
                names[#names + 1] = name
            end
        end
        return names
    end

    local function pickRandomHFILSubzone()
        local names = getHFILSubzoneNames()
        if #names == 0 then
            return nil, nil
        end
        local idx = GetRandomInt(1, #names)
        local name = names[idx]
        local info = HFIL_SPAWN_POINTS[name]
        local pts = info.points or info
        return name, pts
    end

    local function getHFILCategoryForPower(avgPower)
        if avgPower < 200 then
            return "starter"
        end
        if avgPower < 400 then
            return "mid"
        end
        if avgPower < 1500 then
            return "high"
        end
        return "end"
    end

    local function pickHFILSubzoneForPower(avgPower)
        local desiredCategory = getHFILCategoryForPower(avgPower)
        local matches = {}

        for name, info in pairs(HFIL_SPAWN_POINTS) do
            local cat = info.category or "starter"
            if cat == desiredCategory then
                matches[#matches + 1] = name
            end
        end

        if #matches == 0 then
            return pickRandomHFILSubzone()
        end

        local idx = GetRandomInt(1, #matches)
        local name = matches[idx]
        local info = HFIL_SPAWN_POINTS[name]
        local pts = info.points or info
        return name, pts
    end

    local function getHFILPlayers()
        local result = {}
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isPlayerSlotActive(pid) then
                local pd = PD(pid)
                if pd and pd.zone == "HFIL" then
                    result[#result + 1] = pid
                end
            end
        end
        return result
    end

    local function getAveragePowerFor(pids)
        local total = 0
        local count = 0

        for i = 1, #pids do
            local pid = pids[i]
            local pd = PD(pid)
            if pd then
                local stats = pd.stats or {}
                local p = stats.power or 0
                total = total + p
                count = count + 1
            end
        end

        if count == 0 then
            return 0
        end

        return total / count
    end

    local function selectHFILTiersForPower(avgPower)
        local tiers = {}

        if avgPower < 100 then
            tiers[#tiers + 1] = "tier1"
            return tiers
        end

        if avgPower < 250 then
            tiers[#tiers + 1] = "tier1"
            tiers[#tiers + 1] = "tier2"
            return tiers
        end

        if avgPower < 1000 then
            tiers[#tiers + 1] = "tier2"
            tiers[#tiers + 1] = "tier3"
            return tiers
        end

        tiers[#tiers + 1] = "tier2"
        tiers[#tiers + 1] = "tier3"
        tiers[#tiers + 1] = "miniboss"
        return tiers
    end

    -- New: players near any spawn point (within SPIRIT_SURGE_PLAYER_RANGE)
    local function getPlayersNearPoints(points)
        local result = {}

        if not points or #points == 0 then
            return result
        end

        local range = SPIRIT_SURGE_PLAYER_RANGE
        local rangeSq = range * range

        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isPlayerSlotActive(pid) then
                local pd = PD(pid)
                if pd and pd.hero then
                    local u = pd.hero
                    if GetUnitTypeId(u) ~= 0 then
                        local ux = GetUnitX(u)
                        local uy = GetUnitY(u)

                        local near = false
                        local i = 1
                        while i <= #points and not near do
                            local pt = points[i]
                            local dx = ux - pt.x
                            local dy = uy - pt.y
                            local distSq = dx * dx + dy * dy
                            if distSq <= rangeSq then
                                near = true
                            end
                            i = i + 1
                        end

                        if near then
                            result[#result + 1] = pid
                        end
                    end
                end
            end
        end

        return result
    end

    -- New: build spawn pool + avg power based on NEARBY players
    local function buildHFILSurgeSpawnPoolForPoints(pointsFallback)
        local points = pointsFallback or {}
        local pids = getPlayersNearPoints(points)

        -- If nobody is near the points, fallback to all HFIL players (original behavior)
        if #pids == 0 then
            pids = getHFILPlayers()
        end

        if #pids == 0 then
            return {}, 0
        end

        local avgPower   = getAveragePowerFor(pids)
        local tierNames  = selectHFILTiersForPower(avgPower)
        local pool       = {}

        local HC         = rawget(_G, "HFILUnitConfig")
        local hasEligible = HC and HC.IsEligible

        for t = 1, #tierNames do
            local tierName = tierNames[t]
            local tierList = HFIL_MOB_POOLS[tierName]
            if tierList then
                for i = 1, #tierList do
                    local raw = tierList[i]
                    local allowed = false

                    if hasEligible then
                        local j = 1
                        while j <= #pids and not allowed do
                            local pid = pids[j]
                            local ok, res = pcall(HC.IsEligible, pid, raw)
                            if ok and res then
                                allowed = true
                            end
                            j = j + 1
                        end
                    else
                        allowed = true
                    end

                    if allowed then
                        pool[#pool + 1] = raw
                    end
                end
            end
        end

        return pool, avgPower
    end

    -- Old global zone-based pool (kept for first wave if needed somewhere else)
    local function buildHFILSurgeSpawnPool()
        local pids = getHFILPlayers()
        if #pids == 0 then
            return {}, 0
        end

        local avgPower = getAveragePowerFor(pids)
        local tierNames = selectHFILTiersForPower(avgPower)

        local pool = {}

        local HC = rawget(_G, "HFILUnitConfig")
        local hasEligible = HC and HC.IsEligible

        for t = 1, #tierNames do
            local tierName = tierNames[t]
            local tierList = HFIL_MOB_POOLS[tierName]
            if tierList then
                for i = 1, #tierList do
                    local raw = tierList[i]
                    local allowed = false

                    if hasEligible then
                        local j = 1
                        while j <= #pids and not allowed do
                            local pid = pids[j]
                            local ok, res = pcall(HC.IsEligible, pid, raw)
                            if ok and res then
                                allowed = true
                            end
                            j = j + 1
                        end
                    else
                        allowed = true
                    end

                    if allowed then
                        pool[#pool + 1] = raw
                    end
                end
            end
        end

        return pool, avgPower
    end

    local function pickSurgeRewardItemId()
        if not SPIRIT_SURGE_ITEM_POOL or #SPIRIT_SURGE_ITEM_POOL == 0 then
            return nil
        end

        local total = 0
        local cumulative = {}

        for i = 1, #SPIRIT_SURGE_ITEM_POOL do
            local entry = SPIRIT_SURGE_ITEM_POOL[i]
            local w = entry.weight or 1
            if w > 0 then
                total = total + w
            end
            cumulative[i] = total
        end

        if total <= 0 then
            return nil
        end

        local r = GetRandomReal(0.0, total)
        local choiceIndex = #SPIRIT_SURGE_ITEM_POOL

        for i = 1, #SPIRIT_SURGE_ITEM_POOL do
            if r <= cumulative[i] then
                choiceIndex = i
                break
            end
        end

        local choice = SPIRIT_SURGE_ITEM_POOL[choiceIndex]
        return choice and choice.id or nil
    end

    local function grantSpiritSurgeRewards(ctx)
        local kills = ctx.killsByPlayer or {}

        for pid, count in pairs(kills) do
            if count and count > 0 then
                local pd = PD(pid)
                if pd then
                    local soul  = count * SPIRIT_SURGE_SOUL_PER_KILL
                    local frags = count * SPIRIT_SURGE_FRAG_PER_KILL

                    -- Soul Energy
                    if soul > 0 then
                        if _G.SoulEnergy and SoulEnergy.AddXp then
                            local ok = pcall(SoulEnergy.AddXp, pid, soul, "WorldEvent", { eventId = ctx.id or "HFIL_SPIRIT_SURGE" })
                            if not ok and DEBUG then
                                print("[SpiritSurge] SoulEnergy.AddXp failed for pid " .. tostring(pid))
                            end
                        else
                            pd.soulEnergy = (pd.soulEnergy or 0) + soul
                        end
                    end

                    -- Fragment currency
                    if frags > 0 then
                        pd.fragments = (pd.fragments or 0) + frags

                        -- Drop a *limited* number of fragment items to avoid huge loops
                        local fragmentItemIds = {
                            FourCC("I00U"),
                            FourCC("I012"),
                            FourCC("I00Z"),
                            FourCC("I00Y"),
                        }

                        local hero = nil
                        if _G.PlayerData and PlayerData.GetHero then
                            hero = PlayerData.GetHero(pid)
                        end

                        if hero and GetUnitTypeId(hero) ~= 0 then
                            local hx = GetUnitX(hero)
                            local hy = GetUnitY(hero)

                            local maxDrops = frags
                            if maxDrops > 10 then
                                maxDrops = 10
                            end

                            local i = 1
                            while i <= maxDrops do
                                local idx = GetRandomInt(1, #fragmentItemIds)
                                local itId = fragmentItemIds[idx]
                                local item = CreateItem(itId, hx, hy)
                                UnitAddItem(hero, item)
                                i = i + 1
                            end
                        end
                    end

                    -- Reward item (shard etc.)
                    local rewardItemId = pickSurgeRewardItemId()
                    if rewardItemId then
                        local hero = nil
                        if _G.PlayerData and PlayerData.GetHero then
                            hero = PlayerData.GetHero(pid)
                        end

                        if hero and GetUnitTypeId(hero) ~= 0 then
                            local hx = GetUnitX(hero)
                            local hy = GetUnitY(hero)
                            local rewardItem = CreateItem(rewardItemId, hx, hy)
                            UnitAddItem(hero, rewardItem)
                        end
                    end

                    if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING then
                        local msg = "[Spirit Surge] You gained " .. tostring(count * SPIRIT_SURGE_SOUL_PER_KILL) ..
                                    " Soul Energy and " .. tostring(count * SPIRIT_SURGE_FRAG_PER_KILL) ..
                                    " fragments during the surge."
                        DisplayTextToPlayer(Player(pid), 0, 0, msg)
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- Spirit Surge spawn helpers
    --------------------------------------------------
    local function createSurgeBeacons(ctx)
        local points = ctx.data.spawnPoints
        if not points or #points == 0 then
            return
        end

        ctx.data.spawnBeacons = ctx.data.spawnBeacons or {}
        ctx.data.spawnCircles = ctx.data.spawnCircles or {}

        for i = 1, #points do
            local pt = points[i]

            -- Beam / ray effect (existing)
            local eff = AddSpecialEffect(SPIRIT_SURGE_BEACON_FX, pt.x, pt.y)
            ctx.data.spawnBeacons[#ctx.data.spawnBeacons + 1] = eff

            -- New: selection-circle style effect
            local circle = AddSpecialEffect(SPIRIT_SURGE_CIRCLE_FX, pt.x, pt.y)
            -- Scale so it roughly covers the SPIRIT_SURGE_PLAYER_RANGE
            local scale = SPIRIT_SURGE_PLAYER_RANGE / 300.0
            BlzSetSpecialEffectScale(circle, scale)
            ctx.data.spawnCircles[#ctx.data.spawnCircles + 1] = circle
        end
    end

    local function destroySurgeBeacons(ctx)
        local beacons = ctx.data.spawnBeacons
        if beacons then
            for i = 1, #beacons do
                local eff = beacons[i]
                if eff then
                    DestroyEffect(eff)
                end
            end
        end
        ctx.data.spawnBeacons = nil

        local circles = ctx.data.spawnCircles
        if circles then
            for i = 1, #circles do
                local eff = circles[i]
                if eff then
                    DestroyEffect(eff)
                end
            end
        end
        ctx.data.spawnCircles = nil
    end

    local function cleanupSurgeUnits(ctx)
        local units = ctx.data.spawnedUnits
        if not units then
            return
        end

        for i = 1, #units do
            local u = units[i]
            if u and GetUnitTypeId(u) ~= 0 then
                KillUnit(u)
            end
        end

        ctx.data.spawnedUnits = nil
    end

    local function countAliveSurgeUnits(ctx)
        local units = ctx.data.spawnedUnits
        if not units then
            return 0
        end

        local alive = 0
        for i = 1, #units do
            local u = units[i]
            if u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405 then
                alive = alive + 1
            end
        end
        return alive
    end

    local function spawnSurgeWave(ctx)
        local points  = ctx.data.spawnPoints
        local mobPool = ctx.data.mobPool

        if not points or #points == 0 then
            debugPrint("Spirit Surge: no spawn points configured")
            return
        end

        if not mobPool or #mobPool == 0 then
            debugPrint("Spirit Surge: mob pool is empty")
            return
        end

        local owner = Player(PLAYER_NEUTRAL_AGGRESSIVE)

        ctx.data.spawnedUnits = {}
        local units = ctx.data.spawnedUnits
        local totalMobs = 0

        for pidx = 1, #points do
            local pt = points[pidx]
            local uCount = 1

            while uCount <= SPIRIT_SURGE_UNITS_PER_POINT do
                local mobIndex = GetRandomInt(1, #mobPool)
                local raw = mobPool[mobIndex]
                local u   = CreateUnit(owner, FourCC(raw), pt.x, pt.y, bj_UNIT_FACING)
                WorldEventSystem.RegisterSpawnedUnit(u)

                if _G.CreepRespawnSystem and CreepRespawnSystem.ApplyHFILStatsToUnit then
                    CreepRespawnSystem.ApplyHFILStatsToUnit(u)
                end

                units[#units + 1] = u
                totalMobs = totalMobs + 1
                uCount = uCount + 1
            end
        end

        ctx.data.lastWaveTotalMobs = totalMobs

        -- Refresh UI with updated wave info
        refreshSpiritSurgeUI(ctx)
    end

    --------------------------------------------------
    -- Event Definition: HFIL Spirit Surge
    --------------------------------------------------
    registerEvent({
        id         = "HFIL_SPIRIT_SURGE",
        name       = "HFIL Spirit Surge",
        zone       = "HFIL",
        duration   = 360.0,
        cooldown   = 850.0,
        weight     = 3.0,
        rollChance = 0.4,

        checkTrigger = function(self, t, isReadyFlag)
            if not anyPlayerInZone(self.zone) then
                return false
            end

            if isReadyFlag then
                return true
            end

            local chance = self.rollChance or 1.0
            local r = math.random()
            return r <= chance
        end,

        onStart = function(ctx, t)
            emit("HFIL_EVENT", { kind = "SPIRIT_SURGE", phase = "START" })
            debugPrint("HFIL Spirit Surge started")

            ctx.data.surgeActive  = true
            ctx.data.surgeFactor  = 0.5

            -- First wave uses old global HFIL pool (could also use nearby if you prefer)
            local pool, avgPower = buildHFILSurgeSpawnPool()
            ctx.data.mobPool     = pool
            ctx.data.avgPower    = avgPower

            local subzoneName, points = pickHFILSubzoneForPower(avgPower)
            ctx.data.spawnSubzone = subzoneName
            ctx.data.spawnPoints  = points

            debugPrint("Spirit Surge average power: " .. tostring(avgPower))
            if subzoneName then
                debugPrint("Spirit Surge spawn subzone: " .. tostring(subzoneName))
            else
                debugPrint("Spirit Surge has no spawn subzone (configure HFIL_SPAWN_POINTS)")
            end

            if points and #points > 0 then
                createSurgeBeacons(ctx)
            end

            ctx.data.waveCount    = 0
            ctx.data.nextSpawnAt  = nil

            spawnSurgeWave(ctx)
            ctx.data.waveCount = 1

            local pids = getHFILPlayers()
            for i = 1, #pids do
                local pid = pids[i]
                local zoneLabel = subzoneName or "HFIL"
                local txt = "|cff80ff80[World Event]|r Spirit Surge has begun in " .. zoneLabel .. "!"
                WorldEventSystem.PushMessage(pid, txt, 4.0)
            end
        end,

        onKill = function(ctx, killed, killer)
            if not killed or GetUnitTypeId(killed) == 0 then
                return
            end
            if not isHFILCreep(killed) then
                return
            end

            if not killer or GetUnitTypeId(killer) == 0 then
                return
            end

            local owner = GetOwningPlayer(killer)
            local pid   = GetPlayerId(owner)

            WorldEventSystem.AddKillContribution(pid, 1)

            -- Update UI live as kills happen
            refreshSpiritSurgeUI(ctx)
        end,

        onTick = function(ctx, t, dt)
            if not ctx.data.spawnPoints then
                return
            end

            local wavesDone    = ctx.data.waveCount or 0
            local maxWaves     = SPIRIT_SURGE_MAX_WAVES
            local aliveCurrent = countAliveSurgeUnits(ctx)

            if wavesDone >= maxWaves then
                debugPrint("Max waves reached")
                if aliveCurrent == 0 then
                    ctx.forceEndReason = "completed"
                end
                return
            end

            if aliveCurrent == 0 then
                -- Before spawning the next wave, rebuild mobPool + avgPower based on NEARBY players
                local points = ctx.data.spawnPoints
                local pool, avgPower = buildHFILSurgeSpawnPoolForPoints(points)
                ctx.data.mobPool  = pool
                ctx.data.avgPower = avgPower

                spawnSurgeWave(ctx)
                ctx.data.waveCount = (ctx.data.waveCount or 0) + 1
            end
        end,

        onEnd = function(ctx, t, reason)
            emit("HFIL_EVENT", { kind = "SPIRIT_SURGE", phase = "END", reason = reason })
            debugPrint("HFIL Spirit Surge ended (" .. tostring(reason) .. ")")

            cleanupSurgeUnits(ctx)
            destroySurgeBeacons(ctx)
            grantSpiritSurgeRewards(ctx)

            local pids = getHFILPlayers()
            for i = 1, #pids do
                local pid = pids[i]
                local txt = "|cffffe080[World Event]|r Spirit Surge has ended."
                WorldEventSystem.PushMessage(pid, txt, 3.0)
            end
        end,
    })

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local tim = CreateTimer()
        local seed = R2I(TimerGetElapsed(tim) * 1000)
        DestroyTimer(tim)
        math.randomseed(seed)

        local driver = CreateTimer()
        TimerStart(driver, TICK_SECONDS, true, driverTick)

        local PB = rawget(_G, "ProcBus")
        if PB and (PB.On or PB.Subscribe) then
            local on = PB.On or PB.Subscribe
            on("OnKill", function(e)
                if not e then
                    return
                end
                local WES = rawget(_G, "WorldEventSystem")
                if not WES or not WES.ReportKill then
                    return
                end

                local killed = e.target or e.victim
                local killer = e.source or e.killer

                if not killed or GetUnitTypeId(killed) == 0 then
                    return
                end
                if not killer or GetUnitTypeId(killer) == 0 then
                    return
                end

                WES.ReportKill(killed, killer)
            end)
        end

        debugPrint("WorldEventSystem ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
