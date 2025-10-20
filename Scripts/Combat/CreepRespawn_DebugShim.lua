if Debug and Debug.beginFile then Debug.beginFile("CreepRespawn_DebugShim.lua") end
--==================================================
-- CreepRespawn_DebugShim.lua
-- Adds a read-only debug getter to CreepRespawnSystem via ProcBus mirrors.
-- Lets ChatTriggerRegistry's "-slot info N" show coords/facing.
-- • ASCII-only, WC3-safe, no percent symbols
--==================================================

do
    if not CreepRespawnSystem then CreepRespawnSystem = {} end
    _G.CreepRespawnSystem = CreepRespawnSystem

    -- Mirror store built from spawn events
    local SlotMirror = {}    -- [slotId] = { id, x, y, facing }

    -- Public debug getter used by ChatTriggerRegistry
    if not CreepRespawnSystem._DebugGetSlot then
        function CreepRespawnSystem._DebugGetSlot(slotId)
            return SlotMirror[slotId]
        end
    end

    local function ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function onCreepSpawn(payload)
        if not payload then return end
        local slotId = payload.slotId
        local u      = payload.unit
        if not slotId or not ValidUnit(u) then return end

        -- Cache current spawn coords and facing as the slot's canonical info
        local x = GetUnitX(u)
        local y = GetUnitY(u)
        local f = GetUnitFacing(u)

        SlotMirror[slotId] = { id = slotId, x = x, y = y, facing = f }
    end

    -- Optional: clear on DEATH does not remove slot; coords remain useful.
    -- Kept minimal.

    OnInit.final(function()
        if ProcBus and ProcBus.Subscribe then
            ProcBus.Subscribe("CREEP_SPAWN", onCreepSpawn)
        end
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawn_DebugShim")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
