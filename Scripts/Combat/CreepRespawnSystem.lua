if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end
--==================================================
-- CreepRespawnSystem.lua
-- • Respawns only Neutral Aggressive creeps that were editor-placed.
-- • No periodic auto-tracking; spawned units ignored unless opted-in.
-- • Never respawns DUMY, heroes, structures, summons, or inventory carriers.
-- • NOW: also initializes HFIL stats on first scan + on respawn
-- • NOW: also re-registers to Threat/Aggro when we see them
--==================================================

do
    CreepRespawnSystem = _G.CreepRespawnSystem or {}
    _G.CreepRespawnSystem = CreepRespawnSystem

    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local RESPAWN_DELAY     = 30.0
    local SCAN_DELAY_START  = 3.0
    local DEBUG_ENABLED     = false

    --------------------------------------------------
    -- Hard filters
    --------------------------------------------------
    local DUMY_ID           = FourCC("DUMY")
    local AINV_ID           = FourCC("AInv")

    --------------------------------------------------
    -- Internal state
    -- slot: { id, x, y, facing, owner, placed=true|false }
    --------------------------------------------------
    local slots       = {}   -- key: handle id -> slot
    local placed_hids = {}   -- units seen during initial scan as NA (editor-placed)

    --------------------------------------------------
    -- Debug
    --------------------------------------------------
    local function DebugMsg(msg)
        if DEBUG_ENABLED then
            DisplayTextToForce(GetPlayersAll(), "[Respawn] " .. tostring(msg))
        end
    end

    --------------------------------------------------
    -- Small helpers
    --------------------------------------------------
    local function ValidUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function H(u)
        return GetHandleId(u)
    end

    local function IsNA(u)
        return GetOwningPlayer(u) == Player(PLAYER_NEUTRAL_AGGRESSIVE)
    end

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

    --------------------------------------------------
    -- NEW: try to apply HFIL stats to a unit
    --------------------------------------------------
    local function ApplyHFILStatsToUnit(u)
        if not ValidUnit(u) then return end
        if not _G.HFILUnitConfig or not HFILUnitConfig.GetByTypeId then
            return
        end
        local typeId = GetUnitTypeId(u)
        local row = HFILUnitConfig.GetByTypeId(typeId)
        if not row then
            return
        end

        -- HP
        if row.health and row.health > 0 then
            local ok = false
            if BlzSetUnitMaxHP then
                local ok2, err2 = pcall(BlzSetUnitMaxHP, u, row.health)
                if ok2 then
                    SetUnitState(u, UNIT_STATE_LIFE, row.health)
                    ok = true
                end
            end
            if not ok then
                -- fallback
                SetUnitState(u, UNIT_STATE_MAX_LIFE, row.health)
                SetUnitState(u, UNIT_STATE_LIFE, row.health)
            end
        end

        -- Armor
        if row.armor and row.armor >= 0 then
            if BlzSetUnitArmor then
                pcall(BlzSetUnitArmor, u, row.armor)
            end
            -- also try StatSystem if we have one
            if _G.StatSystem and StatSystem.SetArmor then
                pcall(StatSystem.SetArmor, u, row.armor)
            end
        end

        -- Base damage (we take the first index)
        if row.damage and row.damage > 0 then
            if BlzSetUnitBaseDamage then
                pcall(BlzSetUnitBaseDamage, u, row.damage, 0)
            end
            -- custom stat system path
            if _G.StatSystem and StatSystem.SetBaseDamage then
                pcall(StatSystem.SetBaseDamage, u, row.damage)
            end
        end

        -- Energy / magic resist from row
        if row.energyResist and row.energyResist > 0 then
            if _G.StatSystem and StatSystem.SetEnergyResist then
                pcall(StatSystem.SetEnergyResist, u, row.energyResist)
            elseif _G.StatSystem and StatSystem.SetMagicResist and (not row.magicResist) then
                pcall(StatSystem.SetMagicResist, u, row.energyResist)
            end
        end

        -- Dodge / Parry / Block / Crit
        -- These only make sense if your StatSystem exposes setters.
        if _G.StatSystem then
            if row.dodge and StatSystem.SetDodge then
                pcall(StatSystem.SetDodge, u, row.dodge)
            end
            if row.parry and StatSystem.SetParry then
                pcall(StatSystem.SetParry, u, row.parry)
            end
            if row.block and StatSystem.SetBlock then
                pcall(StatSystem.SetBlock, u, row.block)
            end
            if row.crit and StatSystem.SetCrit then
                pcall(StatSystem.SetCrit, u, row.crit)
            end
            if row.critMult and StatSystem.SetCritMult then
                pcall(StatSystem.SetCritMult, u, row.critMult)
            end
        end

        -- You can add more later if HFIL rows get bigger (spellBonusPct, physicalBonusPct, etc.)
        if DEBUG_ENABLED then
            DebugMsg("HFIL stats applied to " .. GetUnitName(u))
        end
    end

    --------------------------------------------------
    -- NEW: try to register to Threat / Aggro
    --------------------------------------------------
    local function RegisterCreepToThreat(u)
        if not ValidUnit(u) then return end

        -- ThreatSystem style
        local TS = rawget(_G, "ThreatSystem")
        if TS then
            if type(TS.RegisterUnit) == "function" then
                pcall(TS.RegisterUnit, u)
            elseif type(TS.OnUnitSpawn) == "function" then
                pcall(TS.OnUnitSpawn, u)
            end
        end

        -- AggroManager style
        local AM = rawget(_G, "AggroManager")
        if AM then
            if type(AM.RegisterCreep) == "function" then
                pcall(AM.RegisterCreep, u)
            elseif type(AM.OnUnitSpawn) == "function" then
                pcall(AM.OnUnitSpawn, u)
            end
        end

        if DEBUG_ENABLED then
            DebugMsg("Threat/Aggro registered for " .. GetUnitName(u))
        end
    end

    --------------------------------------------------
    -- Register only editor-placed NA creeps discovered at initial scan
    --------------------------------------------------
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

        -- NEW: initialize stats + threat for placed unit
        ApplyHFILStatsToUnit(u)
        RegisterCreepToThreat(u)

        -- DebugMsg("Registered placed unit")
    end

    --------------------------------------------------
    -- Optional: explicit opt-in for spawned NA (other systems call this)
    --------------------------------------------------
    function CreepRespawnSystem.ApplyHFILStatsToUnit(u)
        ApplyHFILStatsToUnit(u)
    end
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
            placed = false,
        }

        -- NEW: when other systems drop a creep in, we still want its stats + threat
        ApplyHFILStatsToUnit(u)
        RegisterCreepToThreat(u)

        -- DebugMsg("Registered spawned NA (opt-in)")
    end

    --------------------------------------------------
    -- Respawn a saved slot
    --------------------------------------------------
    local function Respawn(saved)
        if not saved then return end
        TimerStart(CreateTimer(), RESPAWN_DELAY, false, function()
            local owner = saved.owner or Player(PLAYER_NEUTRAL_AGGRESSIVE)
            local new = CreateUnit(owner, saved.id, saved.x, saved.y, saved.facing)

            -- NEW: apply HFIL stats right away to the respawned unit
            ApplyHFILStatsToUnit(new)
            -- NEW: re-register to threat/aggro
            RegisterCreepToThreat(new)

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

            -- DebugMsg("Respawned unit")
            DestroyTimer(GetExpiredTimer())
        end)
    end

    --------------------------------------------------
    -- Death handler
    --------------------------------------------------
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

    --------------------------------------------------
    -- One-time world scan to capture editor-placed NA creeps
    --------------------------------------------------
    local function InitialScanPlaced()
        local world = GetWorldBounds()

        -- pass 1: mark all NA handles
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

        -- pass 2: actually register and init them
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

        -- DebugMsg("Initial scan complete")
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
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

        DebugMsg("System ready (NA placed only, with HFIL+Threat init)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CreepRespawnSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
