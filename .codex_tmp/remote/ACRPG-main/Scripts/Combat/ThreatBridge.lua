if Debug and Debug.beginFile then Debug.beginFile("ThreatBridge.lua") end
--==================================================
-- ThreatBridge.lua
-- Listens to ProcBus creep events and syncs Threat/Aggro.
-- Safe if CreepRespawnSystem already registered: we check IsTracked first.
--==================================================

do
    if not ThreatBridge then ThreatBridge = {} end
    _G.ThreatBridge = ThreatBridge

    local function ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end
    local function IsTracked(u)
        if not ThreatSystem then return false end
        if ThreatSystem.IsTracked then return ThreatSystem.IsTracked(u) == true end
        if ThreatSystem._eliteFlagByUnit and ThreatSystem._eliteFlagByUnit[u] ~= nil then return true end
        return false
    end

    local function Register(u, isElite, packId)
        if AggroManager and AggroManager.Register then AggroManager.Register(u) end
        if ThreatSystem then
            if ThreatSystem.OnCreepSpawn then ThreatSystem.OnCreepSpawn(u, isElite, packId)
            elseif ThreatSystem.Register then ThreatSystem.Register(u) end
        end
    end
    local function Clear(u)
        if ThreatSystem then
            if ThreatSystem.OnCreepDeath then ThreatSystem.OnCreepDeath(u)
            elseif ThreatSystem.ClearUnit then ThreatSystem.ClearUnit(u) end
        end
        if AggroManager and AggroManager.Unregister then AggroManager.Unregister(u) end
    end

    local function onSpawn(payload)
        if not payload then return end
        local u = payload.unit; if not ValidUnit(u) or IsTracked(u) then return end
        Register(u, payload.isElite == true, payload.packId)
    end
    local function onDeath(payload)
        if not payload then return end
        local u = payload.unit; if not ValidUnit(u) then return end
        Clear(u)
    end

    OnInit.final(function()
        if ProcBus then
            if ProcBus.Subscribe then
                ProcBus.Subscribe("CREEP_SPAWN", onSpawn)
                ProcBus.Subscribe("CREEP_DEATH", onDeath)
            elseif ProcBus.On then
                ProcBus.On("CREEP_SPAWN", onSpawn)
                ProcBus.On("CREEP_DEATH", onDeath)
            end
        end
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
