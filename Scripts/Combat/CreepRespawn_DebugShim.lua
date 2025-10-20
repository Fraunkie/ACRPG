if Debug and Debug.beginFile then Debug.beginFile("CreepRespawn_DebugShim.lua") end
--==================================================
-- CreepRespawn_DebugShim.lua
-- Read-only mirror of spawn slots for debug queries.
-- • Builds SlotMirror from ProcBus CREEP_SPAWN events
-- • Exposes CreepRespawnSystem._DebugGetSlot(slotId)
--==================================================

do
    if not CreepRespawnSystem then CreepRespawnSystem = {} end
    _G.CreepRespawnSystem = CreepRespawnSystem

    local SlotMirror = {}  -- [slotId] = { id, x, y, facing }

    -- Public debug getter (used by ChatTriggerRegistry)
    if not CreepRespawnSystem._DebugGetSlot then
        function CreepRespawnSystem._DebugGetSlot(slotId)
            return SlotMirror[slotId]
        end
    end

    local function ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function onCreepSpawn(e)
        if not e then return end
        local slotId = e.id
        local u      = e.unit
        if not slotId or not ValidUnit(u) then return end

        local x = GetUnitX(u)
        local y = GetUnitY(u)
        local f = GetUnitFacing(u)
        SlotMirror[slotId] = { id = slotId, x = x, y = y, facing = f }
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("CREEP_SPAWN", onCreepSpawn)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawn_DebugShim")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
