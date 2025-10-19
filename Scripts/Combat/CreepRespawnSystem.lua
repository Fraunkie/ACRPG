if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end
--==================================================
-- CREEP RESPAWN SYSTEM  (Synced with Main Systems Snapshot)
--==================================================
-- • Adopts all preplaced Neutral Hostile creeps as fixed "slots"
-- • On death, respawns at the original slot position and facing
-- • Integrates with AggroManager + ThreatSystem helpers
-- • Elite per-spawn roll using GameBalance.EliteConfig when available
-- • Emits ProcBus events (if present). No '%' in any strings.
--==================================================

-- Hard guard if natives are not ready (editor parse safety)
if not CreateUnit then
    print("[CreepRespawnSystem] Warcraft III natives not yet available.")
    if Debug and Debug.endFile then Debug.endFile() end
    return
end

if not CreepRespawnSystem then CreepRespawnSystem = {} end
_G.CreepRespawnSystem = CreepRespawnSystem

----------------------------------------------------
-- Local logger (WC3-safe)
----------------------------------------------------
local function LOG(ch, msg)
    if Log then
        Log("CreepRespawnSystem", ch or Color.CYAN, msg)
    else
        print("[CreepRespawnSystem] " .. tostring(msg))
    end
end
local function LOG_OK(msg) LOG(Color.GREEN, msg) end
local function LOG_WARN(msg) LOG(Color.YELLOW, msg) end

----------------------------------------------------
-- Config fallbacks (read from GameBalance when present)
----------------------------------------------------
local DEFAULT_RESPAWN_TIME = 10.0  -- fallback if no profile data
local DEFAULT_ELITE_CHANCE = 2     -- percent fallback if no config
local DEFAULT_ELITE_HP_X   = 3.0   -- x3 HP
local DEFAULT_ELITE_DMG_X  = 1.5   -- x1.5 Damage
local DEFAULT_SPAWN_GRACE  = 0.25  -- seconds; optional grace

-- read helpers with safe fallbacks
local function GB() return _G.GameBalance end
local function EliteDefaults()
    local gb = GB()
    if gb and gb.EliteConfig then
        local ec = gb.EliteConfig
        return ec.defaultChance or DEFAULT_ELITE_CHANCE,
               ec.hpX or DEFAULT_ELITE_HP_X,
               ec.dmgX or DEFAULT_ELITE_DMG_X
    end
    return DEFAULT_ELITE_CHANCE, DEFAULT_ELITE_HP_X, DEFAULT_ELITE_DMG_X
end
local function ThreatKnobs()
    local gb = GB()
    local t = gb and gb.Threat or nil
    return {
        spawnBasePing = (t and t.Spawn and t.Spawn.basePing) or 15,
        spawnPingOn   = (t and t.Spawn and t.Spawn.enablePing) ~= false,
        graceSuppress = (t and t.Spawn and t.Spawn.graceSuppress) ~= false,
        eliteDmgMult  = (t and t.Elite and t.Elite.dmgMult) or 2.0,
        eliteAblMult  = (t and t.Elite and t.Elite.abilityMult) or 1.5,
    }
end
local function ActiveDelayForSlot(slot)
    -- If profiles are not wired yet, use slot.respawn or default.
    local delay = slot.respawn or DEFAULT_RESPAWN_TIME
    local gb = GB()
    if gb and gb.RespawnProfiles then
        -- If a default profile exists, add its delay/jitter. Keep simple and safe.
        local prof = gb.RespawnProfiles.Default or gb.RespawnProfiles.HFIL_Starter
        if prof and prof.delay then
            delay = prof.delay
            if prof.jitter and prof.jitter > 0 then
                local half = math.floor(prof.jitter * 1000) -- ms scale to keep int ops stable
                local roll = GetRandomInt(-half, half)      -- jitter symmetrical
                delay = delay + (roll / 1000.0)
                if delay < 0.50 then delay = 0.50 end
            end
        end
    end
    return delay
end

----------------------------------------------------
-- Internal state
----------------------------------------------------
local SlotsByUnit = {}     -- [unit] = slot
local Slots       = {}     -- [slotId] = slot
local nextSlotId  = 1
local DEBUG_ENABLED = false

-- slot schema:
-- { id, unitType, x, y, facing, name, respawn, isPreplaced=true, packId=nil }

----------------------------------------------------
-- Helpers
----------------------------------------------------
local function IsStructure(u) return IsUnitType(u, UNIT_TYPE_STRUCTURE) end
local function IsDummy(u)
    -- Treat Locust as dummy/FX by default
    return GetUnitAbilityLevel(u, FourCC('Aloc')) ~= 0
end
local function IsHeroUnit(u) return IsUnitType(u, UNIT_TYPE_HERO) end
local function IsBag(u)
    if BagSystem and BagSystem.IsBagUnit then return BagSystem.IsBagUnit(u) end
    return false
end

local function SpiralFindSpawn(x, y, facing)
    -- Try a few small offsets if the point is blocked
    local utest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('hfoo'), x, y, facing)
    if utest then
        RemoveUnit(utest)
        return x, y
    end
    local step = 32.0
    for r = 1, 5 do
        local dx = r * step
        local dy = r * step
        local checks = {
            {x + dx, y}, {x - dx, y}, {x, y + dy}, {x, y - dy},
            {x + dx, y + dy}, {x - dx, y + dy}, {x + dx, y - dy}, {x - dx, y - dy}
        }
        for i = 1, #checks do
            local cx, cy = checks[i][1], checks[i][2]
            local test = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC('hfoo'), cx, cy, facing)
            if test then
                RemoveUnit(test)
                return cx, cy
            end
        end
    end
    return x, y
end

local function ApplyEliteUpgrades(u, slot)
    local chance, hpX, dmgX = EliteDefaults()

    -- per-unit override example via HFIL_UnitConfig if provided
    if HFIL_UnitConfig and HFIL_UnitConfig.EliteOverrides then
        local ov = HFIL_UnitConfig.EliteOverrides[slot.unitType]
        if ov then
            if ov.chance ~= nil then chance = ov.chance end
            if ov.hpX   ~= nil then hpX   = ov.hpX   end
            if ov.dmgX  ~= nil then dmgX  = ov.dmgX  end
        end
    end

    local rolledElite = GetRandomInt(1, 100) <= chance
    if not rolledElite then return false end

    -- HP scale
    local baseMax = BlzGetUnitMaxHP(u)
    local newMax  = math.floor(baseMax * hpX + 0.5)
    if newMax < 1 then newMax = baseMax end
    BlzSetUnitMaxHP(u, newMax)
    SetUnitState(u, UNIT_STATE_LIFE, newMax)

    -- Damage scale (StatSystem if present, else use native bonus if you have one)
    if StatSystem and StatSystem.AddUnitDamageMult then
        StatSystem.AddUnitDamageMult(u, dmgX)
    end

    -- Visual and label
    SetUnitScale(u, 1.10, 1.10, 1.10)
    if BlzSetUnitName then
        local nm = GetUnitName(u)
        BlzSetUnitName(u, "[Elite] " .. nm)
    end
    local fx1 = AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", u, "overhead"); if fx1 then DestroyEffect(fx1) end
    local fx2 = AddSpecialEffectTarget("Abilities\\Spells\\Other\\HealingSpray\\HealingSprayTarget.mdl", u, "origin"); if fx2 then DestroyEffect(fx2) end

    return true
end

local function RegisterThreatAndAggro(u, isElite, packId)
    if AggroManager and AggroManager.Register then
        AggroManager.Register(u)
    end
    if ThreatSystem then
        if ThreatSystem.OnCreepSpawn then
            ThreatSystem.OnCreepSpawn(u, isElite, packId)
        elseif ThreatSystem.Register then
            ThreatSystem.Register(u) -- fallback to baseline API name if helpers not yet added
        end
    end
end

local function ClearThreatAndAggro(u)
    if ThreatSystem then
        if ThreatSystem.OnCreepDeath then
            ThreatSystem.OnCreepDeath(u)
        elseif ThreatSystem.ClearUnit then
            ThreatSystem.ClearUnit(u)
        end
    end
    if AggroManager and AggroManager.Unregister then
        AggroManager.Unregister(u)
    end
end

local function Emit(eventName, payload)
    if ProcBus and ProcBus.Emit then
        ProcBus.Emit(eventName, payload)
    end
end

----------------------------------------------------
-- Spawn / Respawn core
----------------------------------------------------
local function CreateFromSlot(slot, forceElite)
    local x, y = SpiralFindSpawn(slot.x, slot.y, slot.facing)
    local u = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), slot.unitType, x, y, slot.facing)
    if not u then
        LOG_WARN("Failed to create unit for slot " .. tostring(slot.id))
        return nil
    end

    -- track mapping
    SlotsByUnit[u] = slot

    -- Elite roll and upgrades
    local isElite = false
    if forceElite == true then
        isElite = ApplyEliteUpgrades(u, slot) or true
    else
        isElite = ApplyEliteUpgrades(u, slot)
    end

    -- Register to systems
    RegisterThreatAndAggro(u, isElite, slot.packId)

    -- Optional spawn grace tiny window (no threat ping during grace)
    local tk = ThreatKnobs()
    if tk.spawnPingOn and (not tk.graceSuppress) then
        -- if grace suppress is false, ping immediately
        if ThreatSystem and ThreatSystem.AddThreat and GetLocalPlayer then
            -- add small base threat to nearest player in range (simple nearest finder)
            local nearestPid = -1
            local nearestDist = 1e9
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if GetPlayerSlotState(Player(pid)) == PLAYER_SLOT_STATE_PLAYING then
                    local hu = PlayerData and PlayerData.GetHero and PlayerData.GetHero(pid) or nil
                    if hu and GetUnitTypeId(hu) ~= 0 then
                        local dx = GetUnitX(hu) - x
                        local dy = GetUnitY(hu) - y
                        local d2 = dx*dx + dy*dy
                        if d2 < nearestDist then
                            nearestDist = d2
                            nearestPid = pid
                        end
                    end
                end
            end
            if nearestPid >= 0 then
                ThreatSystem.AddThreat(nearestPid, u, tk.spawnBasePing, "spawn")
            end
        end
    else
        -- if grace is enabled, we simply wait it out with a short timer before any auto-ping
        if tk.spawnPingOn and tk.graceSuppress then
            local t = CreateTimer()
            TimerStart(t, DEFAULT_SPAWN_GRACE, false, function()
                if ThreatSystem and ThreatSystem.AddThreat and SlotsByUnit[u] == slot then
                    local pid = -1
                    local nd2 = 1e9
                    for p = 0, bj_MAX_PLAYERS - 1 do
                        if GetPlayerSlotState(Player(p)) == PLAYER_SLOT_STATE_PLAYING then
                            local hu = PlayerData and PlayerData.GetHero and PlayerData.GetHero(p) or nil
                            if hu and GetUnitTypeId(hu) ~= 0 then
                                local dx = GetUnitX(hu) - x
                                local dy = GetUnitY(hu) - y
                                local d2 = dx*dx + dy*dy
                                if d2 < nd2 then nd2 = d2; pid = p end
                            end
                        end
                    end
                    if pid >= 0 then
                        ThreatSystem.AddThreat(pid, u, tk.spawnBasePing, "spawn")
                    end
                end
                DestroyTimer(t)
            end)
        end
    end

    -- Emit spawn event
    Emit("CREEP_SPAWN", { unit = u, slotId = slot.id, isElite = isElite, isInitial = slot._initialSpawn == true })

    return u
end

local function ScheduleRespawn(slot)
    local delay = ActiveDelayForSlot(slot)
    local t = CreateTimer()
    TimerStart(t, delay, false, function()
        CreateFromSlot(slot, false)
        DestroyTimer(t)
    end)
end

----------------------------------------------------
-- Death handler
----------------------------------------------------
local function OnCreepDeath()
    local dying = GetTriggerUnit()
    if not dying then return end
    local slot = SlotsByUnit[dying]
    if not slot then return end

    -- Clear state from systems
    ClearThreatAndAggro(dying)

    -- Unmap this unit from the slot
    SlotsByUnit[dying] = nil

    -- Emit death
    Emit("CREEP_DEATH", { unit = dying, slotId = slot.id })

    -- Schedule respawn for this slot
    ScheduleRespawn(slot)
end

----------------------------------------------------
-- Bootstrap: adopt preplaced creeps as fixed slots
----------------------------------------------------
local function AdoptPreplaced()
    local g = CreateGroup()
    GroupEnumUnitsOfPlayer(g, Player(PLAYER_NEUTRAL_AGGRESSIVE), nil)
    ForGroup(g, function()
        local u = GetEnumUnit()
        if u
            and not IsStructure(u)
            and not IsDummy(u)
            and not IsHeroUnit(u)
            and not IsBag(u)
        then
            local slot = {
                id        = nextSlotId, next = nil,
                unitType  = GetUnitTypeId(u),
                x         = GetUnitX(u),
                y         = GetUnitY(u),
                facing    = GetUnitFacing(u),
                name      = GetUnitName(u),
                respawn   = DEFAULT_RESPAWN_TIME,
                isPreplaced = true,
                packId    = nil,
                _initialSpawn = true,
            }
            Slots[slot.id] = slot
            nextSlotId = nextSlotId + 1

            -- map unit to slot and register
            SlotsByUnit[u] = slot

            -- Elite NOT applied to existing map-placed creeps at start (feel consistent)
            RegisterThreatAndAggro(u, false, slot.packId)

            -- Emit initial spawn event
            Emit("CREEP_SPAWN", { unit = u, slotId = slot.id, isElite = false, isInitial = true })
        end
    end)
    DestroyGroup(g)
end

----------------------------------------------------
-- Public API
----------------------------------------------------
function CreepRespawnSystem.ToggleDebug()
    DEBUG_ENABLED = not DEBUG_ENABLED
    LOG(nil, "Debug is " .. (DEBUG_ENABLED and "ON" or "OFF"))
end

function CreepRespawnSystem.RespawnNow(slotId, forceElite)
    local slot = Slots[slotId]
    if not slot then
        LOG_WARN("No slot found for id " .. tostring(slotId))
        return
    end
    CreateFromSlot(slot, forceElite == true)
end

----------------------------------------------------
-- Init (Total Initialization)
----------------------------------------------------
OnInit.final(function()
    -- Elite hints from GameBalance are read on demand per spawn
    -- Adopt preplaced units now
    AdoptPreplaced()

    -- Death trigger for Neutral Hostile creeps
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEvent(trg, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
    TriggerAddAction(trg, OnCreepDeath)

    LOG_OK("Creep Respawn System ready.")
    if InitBroker and InitBroker.SystemReady then
        InitBroker.SystemReady("CreepRespawnSystem")
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
