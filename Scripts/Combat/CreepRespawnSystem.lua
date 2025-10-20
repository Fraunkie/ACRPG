if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end
--==================================================
-- CreepRespawnSystem.lua
-- Respawns dead creeps (editor-placed or spawned).
-- Fix: uses GroupEnumUnitsInRect (Lua-safe) instead of EnumUnitsInRect.
--==================================================

do
    CreepRespawnSystem = _G.CreepRespawnSystem or {}
    _G.CreepRespawnSystem = CreepRespawnSystem

    local RESPAWN_DELAY    = 10.0
    local SCAN_DELAY_START = 3.0
    local DEBUG_ENABLED    = true
    local slots = {}

    local function DebugMsg(msg)
        if DEBUG_ENABLED then
            DisplayTextToForce(GetPlayersAll(), "[Respawn] " .. tostring(msg))
        end
    end
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function H(u) return GetHandleId(u) end

    function CreepRespawnSystem.RegisterUnit(u)
        if not ValidUnit(u) then return end
        local h = H(u)
        if slots[h] then return end
        slots[h] = {
            id     = GetUnitTypeId(u),
            x      = GetUnitX(u),
            y      = GetUnitY(u),
            facing = GetUnitFacing(u)
        }
        DebugMsg("Registered " .. GetUnitName(u))
    end

    local function respawn(saved)
        if not saved then return end
        TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
            local new = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), saved.id, saved.x, saved.y, saved.facing)
            CreepRespawnSystem.RegisterUnit(new)
            DebugMsg("Respawned " .. GetUnitName(new))
            DestroyTimer(GetExpiredTimer())
        end)
    end

    local function onDeath()
        local u = GetTriggerUnit()
        if not ValidUnit(u) then return end
        local h = H(u)
        local saved = slots[h]
        if not saved then return end
        slots[h] = nil
        DebugMsg("Death captured for " .. GetUnitName(u))
        respawn(saved)
    end

    local function scanEditorPlaced()
        local count = 0
        local world = GetWorldBounds()
        local g = CreateGroup()
        GroupEnumUnitsInRect(g, world, nil)
        while true do
            local u = FirstOfGroup(g)
            if not u then break end
            GroupRemoveUnit(g, u)
            if ValidUnit(u) then
                local id = GetUnitTypeId(u)
                if id == FourCC("n001") or id == FourCC("n00G") then
                    CreepRespawnSystem.RegisterUnit(u)
                    count = count + 1
                end
            end
        end
        DestroyGroup(g)
        DebugMsg("Pre-placed registered " .. tostring(count))
    end

    OnInit.final(function()
        local tNA = CreateTrigger()
        TriggerRegisterPlayerUnitEvent(tNA, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerAddAction(tNA, onDeath)

        local tAny = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(tAny, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddAction(tAny, onDeath)

        TimerStart(CreateTimer(), SCAN_DELAY_START, false, function()
            scanEditorPlaced()
            DestroyTimer(GetExpiredTimer())
        end)

        DebugMsg("CreepRespawnSystem ready (delay " .. tostring(RESPAWN_DELAY) .. "s)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawnSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
