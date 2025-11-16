if Debug and Debug.beginFile then Debug.beginFile("ShardChargeSystem.lua") end
--==================================================
-- ShardChargeSystem.lua  (v0.5 — SD-first, custom inventory)
-- • Goku shard only (I00W)
-- • Triggers on SpiritDrive full event OR poll
-- • Reads SpiritDrive.Get(...) FIRST
-- • Falls back to PLAYER_DATA[pid].spiritDrive
-- • Debug gated at top
--==================================================

if not ShardChargeSystem then ShardChargeSystem = {} end
_G.ShardChargeSystem = ShardChargeSystem

do
    --------------------------------------------------
    -- Toggle
    --------------------------------------------------
    local DEBUG_SHARD = false

    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local GOKU_SHARD_ID = FourCC("I00W")
    local POLL_PERIOD   = 0.40

    local SHARD_RULES = {
        [GOKU_SHARD_ID] = {
            id   = GOKU_SHARD_ID,
            name = "Goku Ascension Shard (Uncharged)",
            mode = "spirit_full",
        },
    }

    --------------------------------------------------
    -- Debug
    --------------------------------------------------
    local lastPollDebug = 0

    local function dbg0(msg)
        if not DEBUG_SHARD then return end
        DisplayTextToPlayer(Player(0), 0, 0, "[ShardDebug] " .. tostring(msg))
    end

    local function dbgTo(pid, msg)
        if not DEBUG_SHARD then return end
        DisplayTextToPlayer(Player(pid), 0, 0, "[ShardDebug] " .. tostring(msg))
    end

    local function log(msg)
        if not DEBUG_SHARD then return end
        if Debug and Debug.printf then
            Debug.printf("[ShardCharge] " .. tostring(msg))
        end
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function getSpiritDrive(pid)
        if _G.SpiritDrive and SpiritDrive.Get then
            local v = SpiritDrive.Get(pid) or 0
            return v
        end
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].spiritDrive then
            return PLAYER_DATA[pid].spiritDrive
        end
        return 0
    end

    local function hasInCustomInv(pid, itemId)
        -- UI module first
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.HasItem then
            local ok, res = pcall(PlayerMenu_InventoryModule.HasItem, pid, itemId)
            if ok and res == true then
                return true
            end
        end
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.GetItemCount then
            local ok2, cnt = pcall(PlayerMenu_InventoryModule.GetItemCount, pid, itemId)
            if ok2 and type(cnt) == "number" and cnt > 0 then
                return true
            end
        end

        -- InventoryService fallback
        if _G.InventoryService and InventoryService.List then
            local list = InventoryService.List(pid)
            if list then
                local cap = 0
                if InventoryService.Capacity then
                    cap = InventoryService.Capacity(pid) or 0
                else
                    for k, _ in pairs(list) do
                        if type(k) == "number" and k > cap then
                            cap = k
                        end
                    end
                end
                local i = 1
                while i <= cap do
                    if list[i] == itemId then
                        return true
                    end
                    i = i + 1
                end
            end
        end

        return false
    end

    local function ensurePD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.chargedShards = pd.chargedShards or {}
        return pd
    end

    -- This is the new HasChargedShard function
    function ShardChargeSystem.HasChargedShard(pid)
        local pd = ensurePD(pid)
        for itemId, charged in pairs(pd.chargedShards) do
            if charged then
                return true
            end
        end
        return false
    end

    local function isCharged(pid, itemId)
        local pd = ensurePD(pid)
        return pd.chargedShards[itemId] == true
    end

    local function renameItemToCharged(itemId)
        if not _G.ItemDatabase or not ItemDatabase.GetData then
            return
        end
        local rec = ItemDatabase.GetData(itemId)
        if not rec then
            return
        end
        local name = rec.name or "Shard"
        local unSuffix = " (Uncharged)"
        local chSuffix = " (Charged)"
        local newName
        if string.len(name) >= string.len(unSuffix) and string.sub(name, string.len(name) - string.len(unSuffix) + 1) == unSuffix then
            local base = string.sub(name, 1, string.len(name) - string.len(unSuffix))
            newName = base .. chSuffix
        else
            newName = name .. chSuffix
        end
        rec.name = newName
    end

    local function refreshInv(pid)
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.Render then
            pcall(PlayerMenu_InventoryModule.Render, pid)
        end
    end

    local function markCharged(pid, itemId, niceName)
        local pd = ensurePD(pid)
        pd.chargedShards[itemId] = true

        renameItemToCharged(itemId)
        refreshInv(pid)

        DisplayTextToPlayer(Player(pid), 0, 0, (niceName or "Shard") .. " is now CHARGED!")

        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit("OnShardCharged", { pid = pid, itemId = itemId })
        end

        log("charged shard " .. tostring(itemId) .. " for pid " .. tostring(pid))
    end

    --------------------------------------------------
    -- Core check
    --------------------------------------------------
    local function tryCharge(pid, sdVal)
        for itemId, rule in pairs(SHARD_RULES) do
            if rule.mode == "spirit_full" then
                if hasInCustomInv(pid, itemId) then
                    if not isCharged(pid, itemId) then
                        if sdVal >= 100 then
                            markCharged(pid, itemId, rule.name)
                        else
                            -- still useful to know
                            dbgTo(pid, "has shard, SD=" .. tostring(sdVal) .. " need 100")
                        end
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- Init / wiring
    --------------------------------------------------
    local function initShard()
        dbg0("ShardChargeSystem init, Goku shard=" .. tostring(GOKU_SHARD_ID))

        -- listen to SD events
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSpiritDriveFull", function(e)
                if not e or e.pid == nil then return end
                local sdVal = getSpiritDrive(e.pid)
                dbgTo(e.pid, "OnSpiritDriveFull (bus) SD=" .. tostring(sdVal))
                tryCharge(e.pid, sdVal)
            end)
            PB.On("SpiritDriveFull", function(e)
                if not e or e.pid == nil then return end
                local sdVal = getSpiritDrive(e.pid)
                dbgTo(e.pid, "SpiritDriveFull (bus) SD=" .. tostring(sdVal))
                tryCharge(e.pid, sdVal)
            end)
            log("wired to ProcBus")
        else
            log("ProcBus not found, poll only")
        end

        -- safety poll
        TimerStart(CreateTimer(), POLL_PERIOD, true, function()
            local t = 0
            if os and os.clock then
                t = os.clock()
            end
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                    local sdVal = getSpiritDrive(pid)
                    if sdVal >= 100 then
                        tryCharge(pid, sdVal)
                    end
                    -- print SD every ~2s so you SEE it
                    if DEBUG_SHARD and pid == 0 and (t - lastPollDebug) > 2.0 then
                        dbg0("poll p0: SD=" .. tostring(sdVal))
                        lastPollDebug = t
                    end
                end
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ShardChargeSystem")
        end
    end

    if OnInit and OnInit.final then
        OnInit.final(initShard)
    else
        local trig = CreateTrigger()
        TriggerRegisterTimerEvent(trig, 3.00, false)
        TriggerAddAction(trig, initShard)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
