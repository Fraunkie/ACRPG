if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem_RespawnHelpers.lua") end
--==================================================
-- ThreatSystem_RespawnHelpers.lua
-- Wires creep spawn/death signals into ThreatSystem.
-- • Listens to ProcBus: CREEP_SPAWN / CREEP_DEATH
-- • Fallback: native death watcher (just in case)
--==================================================

do
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end

    local function onSpawn(e)
        if not e or not valid(e.unit) then return end
        if _G.ThreatSystem and ThreatSystem.OnCreepSpawn then
            pcall(ThreatSystem.OnCreepSpawn, e.unit, e.isElite == true, e.packId)
        elseif _G.ThreatSystem and ThreatSystem.Register then
            pcall(ThreatSystem.Register, e.unit)
        end
    end

    local function onDeath(e)
        if not e or not valid(e.unit) then return end
        if _G.ThreatSystem and ThreatSystem.OnCreepDeath then
            pcall(ThreatSystem.OnCreepDeath, e.unit)
        elseif _G.ThreatSystem and ThreatSystem.ClearUnit then
            pcall(ThreatSystem.ClearUnit, e.unit)
        end
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("CREEP_SPAWN", onSpawn)
            PB.On("CREEP_DEATH", onDeath)
        end

        -- Fallback native watcher: if a tracked unit dies without bus event
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerRegisterPlayerUnitEvent(t, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerAddAction(t, function()
            local u = GetTriggerUnit()
            if not valid(u) then return end
            if _G.ThreatSystem and ThreatSystem.ClearUnit then
                pcall(ThreatSystem.ClearUnit, u)
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem_RespawnHelpers")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
