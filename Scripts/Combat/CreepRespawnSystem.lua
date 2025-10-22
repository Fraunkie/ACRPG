if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end
--==================================================
-- CreepRespawnSystem.lua
-- • Respawns only Neutral Aggressive creeps that were editor-placed.
-- • No periodic auto-tracking; spawned units ignored unless opted-in.
-- • Never respawns DUMY, heroes, structures, summons, or inventory carriers.
--==================================================

do
    CreepRespawnSystem = _G.CreepRespawnSystem or {}
    _G.CreepRespawnSystem = CreepRespawnSystem

    -- Tunables
    local RESPAWN_DELAY     = 10.0
    local SCAN_DELAY_START  = 3.0
    local DEBUG_ENABLED     = true

    -- Hard filters
    local DUMY_ID           = FourCC("DUMY")
    local AINV_ID           = FourCC("AInv")

    -- Internal state
    -- slot: { id, x, y, facing, owner, placed=true|false }
    local slots       = {}   -- key: handle id -> slot
    local placed_hids = {}   -- units seen during initial scan as NA (editor-placed)

    -- Debug
    local function DebugMsg(msg)
        if DEBUG_ENABLED then
            DisplayTextToForce(GetPlayersAll(), "[Respawn] " .. tostring(msg))
        end
    end

    -- Helpers
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function H(u) return GetHandleId(u) end
    local function IsNA(u) return GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE) end

    local function PassesFilters(u)
        if not ValidUnit(u) then return false end
        if not IsNA(u) then return false end
        local id = GetUnitTypeId(u)
        if id == DUMY_ID then return false end
        if IsUnitType(u, UNIT_TYPE_STRUCTURE) then return false end
        if IsUnitType(u, UNIT_TYPE_HERO) then return false end
        if IsUnitType(u, UNIT_TYPE_SUMMONED) then return false end
        if GetUnitAbilityLevel(u, AINV_ID) > 0 then return false end
        return true
    end

    -- Register only editor-placed NA creeps discovered at initial scan
    local function RegisterPlaced(u)
        if not PassesFilters(u) then return end
        local hid = H(u)
        if not placed_hids[hid] then return end
        if slots[hid] then return end
        slots[hid] = {
            id     = GetUnitTypeId(u),
            x      = GetUnitX(u),
            y      = GetUnitY(u),
            facing = GetUnitFacing(u),
            owner  = GetOwningPlayer(u),
            placed = true,
        }
        DebugMsg("Registered placed unit")
    end

    -- Optional: explicit opt-in for spawned NA (call from other systems if desired)
    function CreepRespawnSystem.RegisterSpawnedNA(u)
        if not PassesFilters(u) then return end
        local hid = H(u)
        if slots[hid] then return end
        slots[hid] = {
            id     = GetUnitTypeId(u),
            x      = GetUnitX(u),
            y      = GetUnitY(u),
            facing = GetUnitFacing(u),
            owner  = GetOwningPlayer(u),
            placed = false, -- explicitly opted-in
        }
        DebugMsg("Registered spawned NA (opt-in)")
    end

    local function Respawn(saved)
        if not saved then return end
        TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
            local owner = saved.owner or Player(PLAYER_NEUTRAL_AGGRESSIVE)
            local new = CreateUnit(owner, saved.id, saved.x, saved.y, saved.facing)
            -- Re-register only if it was editor-placed; spawned NA remains opt-in only.
            if saved.placed then
                local hid = H(new)
                slots[hid] = {
                    id     = saved.id,
                    x      = saved.x,
                    y      = saved.y,
                    facing = saved.facing,
                    owner  = owner,
                    placed = true
                }
            end
            DebugMsg("Respawned unit")
            DestroyTimer(GetExpiredTimer())
        end)
    end

    local function OnDeath()
        local u = GetTriggerUnit()
        if not ValidUnit(u) then return end
        local hid = H(u)
        local saved = slots[hid]
        if not saved then return end

        -- Double guard: never respawn DUMY or anything that violates filters unless it was placed
        if saved.id == DUMY_ID then
            slots[hid] = nil
            return
        end
        if not PassesFilters(u) and not saved.placed then
            slots[hid] = nil
            return
        end

        slots[hid] = nil
        DebugMsg("Death captured")
        Respawn(saved)
    end

    -- One-time world scan to capture editor-placed NA creeps
    local function InitialScanPlaced()
        local world = GetWorldBounds()
        local g = CreateGroup()
        GroupEnumUnitsInRect(g, world, nil)
        while true do
            local u = FirstOfGroup(g)
            if not u then break end
            GroupRemoveUnit(g, u)
            if ValidUnit(u) and IsNA(u) then
                placed_hids[H(u)] = true
            end
        end
        DestroyGroup(g)

        local g2 = CreateGroup()
        GroupEnumUnitsInRect(g2, world, nil)
        while true do
            local u = FirstOfGroup(g2)
            if not u then break end
            GroupRemoveUnit(g2, u)
            if placed_hids[H(u)] then
                RegisterPlaced(u)
            end
        end
        DestroyGroup(g2)

        DebugMsg("Initial scan complete")
    end

    OnInit.final(function()
        -- Death listeners
        local tNA = CreateTrigger()
        TriggerRegisterPlayerUnitEvent(tNA, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerAddAction(tNA, OnDeath)

        local tAny = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(tAny, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddAction(tAny, OnDeath)

        -- One-time delayed scan (no periodic auto-registration)
        TimerStart(CreateTimer(), SCAN_DELAY_START, false, function()
            InitialScanPlaced()
            DestroyTimer(GetExpiredTimer())
        end)

        DebugMsg("System ready (NA placed only)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawnSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
