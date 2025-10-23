-- StatSystem.lua (merged: abilities + source aggregation + combat emit) [BJ-free percent math]
if Debug and Debug.beginFile then Debug.beginFile('StatSystem') end

StatSystem = {}
_G.StatSystem = StatSystem

do
    --------------------------------------------------
    -- CONFIG / CONSTANTS
    --------------------------------------------------
    local DEBUG_ENABLED = false

    -- Public stat ids
    StatSystem.STAT_DAMAGE           = 1
    StatSystem.STAT_ARMOR            = 2
    StatSystem.STAT_AGILITY          = 3
    StatSystem.STAT_STRENGTH         = 4
    StatSystem.STAT_INTELLIGENCE     = 5
    StatSystem.STAT_HEALTH           = 6
    StatSystem.STAT_MANA             = 7
    StatSystem.STAT_MOVEMENT_SPEED   = 8
    StatSystem.STAT_ATTACK_SPEED     = 9
    StatSystem.STAT_HEALTH_REGEN     = 10
    StatSystem.STAT_MANA_REGEN       = 11
    StatSystem.STAT_MAGIC_RESISTANCE = 12
    StatSystem.STAT_SIGHT_RANGE      = 13

    -- Hidden abilities (must exist in the object editor)
    local DAMAGE_ABILITY        = FourCC('A00R')
    local ARMOR_ABILITY         = FourCC('A00O')
    local STATS_ABILITY         = FourCC('A00N')
    local HEALTH_ABILITY        = FourCC('A00T')
    local MANA_ABILITY          = FourCC('A00W')
    local MOVEMENT_ABILITY      = FourCC('A00X')
    local ATTACK_SPEED_ABILITY  = FourCC('A00P')
    local HEALTH_REGEN_ABILITY  = FourCC('A015')
    local MANA_REGEN_ABILITY    = FourCC('A016')
    local MAGIC_RESIST_ABILITY  = FourCC('A00B')
    local SIGHT_ABILITY         = FourCC('A00Y')

    -- Ability fields
    local DAMAGE_FIELD        = ABILITY_ILF_ATTACK_BONUS
    local ARMOR_FIELD         = ABILITY_ILF_DEFENSE_BONUS_IDEF
    local AGILITY_FIELD       = ABILITY_ILF_AGILITY_BONUS
    local STRENGTH_FIELD      = ABILITY_ILF_STRENGTH_BONUS_ISTR
    local INTELLIGENCE_FIELD  = ABILITY_ILF_INTELLIGENCE_BONUS
    local HEALTH_FIELD        = ABILITY_ILF_MAX_LIFE_GAINED
    local MANA_FIELD          = ABILITY_ILF_MAX_MANA_GAINED
    local MOVEMENT_FIELD      = ABILITY_ILF_MOVEMENT_SPEED_BONUS
    local ATTACK_SPEED_FIELD  = ABILITY_RLF_ATTACK_SPEED_INCREASE_ISX1
    local HEALTH_REGEN_FIELD  = ABILITY_RLF_AMOUNT_OF_HIT_POINTS_REGENERATED
    local MANA_REGEN_FIELD    = ABILITY_RLF_AMOUNT_REGENERATED
    local MAGIC_RESIST_FIELD  = ABILITY_RLF_DAMAGE_REDUCTION_ISR2
    local SIGHT_FIELD         = ABILITY_ILF_SIGHT_RANGE_BONUS

    --------------------------------------------------
    -- DEBUG
    --------------------------------------------------
    local function debugPrint(msg)
        if DEBUG_ENABLED then print("[StatSystem] " .. tostring(msg)) end
    end
    function StatSystem.ToggleDebug()
        DEBUG_ENABLED = not DEBUG_ENABLED
        print("StatSystem debug: " .. (DEBUG_ENABLED and "ON" or "OFF"))
        return DEBUG_ENABLED
    end

    --------------------------------------------------
    -- SAFE ABILITY + WRITERS
    --------------------------------------------------
    local function SafeAddAbility(unit, abilId)
        if not unit then return false end
        if GetUnitAbilityLevel(unit, abilId) > 0 then return true end

        UnitAddAbility(unit, abilId)
        if GetUnitAbilityLevel(unit, abilId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilId)
            return true
        end

        local owner = GetOwningPlayer(unit)
        if owner then
            SetPlayerAbilityAvailable(owner, abilId, true)
            UnitAddAbility(unit, abilId)
            if GetUnitAbilityLevel(unit, abilId) > 0 then
                UnitMakeAbilityPermanent(unit, true, abilId)
                return true
            end
        end

        debugPrint("SafeAddAbility failed for " .. tostring(abilId))
        return false
    end

    local function SetAbilityField(unit, abilityId, field, value, isInteger)
        if not unit then return false end
        if GetUnitAbilityLevel(unit, abilityId) == 0 and not SafeAddAbility(unit, abilityId) then
            return false
        end
        local ua = BlzGetUnitAbility(unit, abilityId); if not ua then return false end
        local ok = isInteger
            and BlzSetAbilityIntegerLevelField(ua, field, 0, value)
            or  BlzSetAbilityRealLevelField(ua, field, 0, value)
        if not ok then return false end
        IncUnitAbilityLevel(unit, abilityId); DecUnitAbilityLevel(unit, abilityId)
        return true
    end

    --------------------------------------------------
    -- READ CURRENT APPLIED BONUSES
    --------------------------------------------------
    function StatSystem.GetUnitStat(unit, statType)
        if not unit then return 0 end
        if statType == StatSystem.STAT_DAMAGE then
            if GetUnitAbilityLevel(unit, DAMAGE_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, DAMAGE_ABILITY), DAMAGE_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_ARMOR then
            if GetUnitAbilityLevel(unit, ARMOR_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, ARMOR_ABILITY), ARMOR_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_AGILITY then
            if GetUnitAbilityLevel(unit, STATS_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, STATS_ABILITY), AGILITY_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_STRENGTH then
            if GetUnitAbilityLevel(unit, STATS_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, STATS_ABILITY), STRENGTH_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_INTELLIGENCE then
            if GetUnitAbilityLevel(unit, STATS_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, STATS_ABILITY), INTELLIGENCE_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_HEALTH then
            if GetUnitAbilityLevel(unit, HEALTH_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, HEALTH_ABILITY), HEALTH_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_MANA then
            if GetUnitAbilityLevel(unit, MANA_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, MANA_ABILITY), MANA_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_MOVEMENT_SPEED then
            if GetUnitAbilityLevel(unit, MOVEMENT_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, MOVEMENT_ABILITY), MOVEMENT_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_ATTACK_SPEED then
            if GetUnitAbilityLevel(unit, ATTACK_SPEED_ABILITY) > 0 then
                return BlzGetAbilityRealLevelField(BlzGetUnitAbility(unit, ATTACK_SPEED_ABILITY), ATTACK_SPEED_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_HEALTH_REGEN then
            if GetUnitAbilityLevel(unit, HEALTH_REGEN_ABILITY) > 0 then
                return BlzGetAbilityRealLevelField(BlzGetUnitAbility(unit, HEALTH_REGEN_ABILITY), HEALTH_REGEN_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_MANA_REGEN then
            if GetUnitAbilityLevel(unit, MANA_REGEN_ABILITY) > 0 then
                return BlzGetAbilityRealLevelField(BlzGetUnitAbility(unit, MANA_REGEN_ABILITY), MANA_REGEN_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_MAGIC_RESISTANCE then
            if GetUnitAbilityLevel(unit, MAGIC_RESIST_ABILITY) > 0 then
                return BlzGetAbilityRealLevelField(BlzGetUnitAbility(unit, MAGIC_RESIST_ABILITY), MAGIC_RESIST_FIELD, 0)
            end
        elseif statType == StatSystem.STAT_SIGHT_RANGE then
            if GetUnitAbilityLevel(unit, SIGHT_ABILITY) > 0 then
                return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(unit, SIGHT_ABILITY), SIGHT_FIELD, 0)
            end
        end
        return 0
    end

    --------------------------------------------------
    -- EVENT REGISTRY (optional)
    --------------------------------------------------
    local eventTriggers = {}
    local currentUnit, currentStat, currentAmount = nil, nil, nil
    function StatSystem.RegisterStatEvent(handler)
        if type(handler) == 'function' then table.insert(eventTriggers, handler); return true end
        return false
    end
    function StatSystem.GetStatEventUnit() return currentUnit end
    function StatSystem.GetStatEventType() return currentStat end
    function StatSystem.GetStatEventAmount() return currentAmount end

    --------------------------------------------------
    -- WRITE APPLIED BONUSES (BJ-free HP/MP preservation)
    --------------------------------------------------
    function StatSystem.SetUnitStat(unit, statType, value)
        if not unit then return false end

        currentUnit, currentStat, currentAmount = unit, statType, value
        for i = 1, #eventTriggers do
            local ok, err = pcall(eventTriggers[i]); if not ok then debugPrint(err) end
        end

        if statType == StatSystem.STAT_DAMAGE then
            return SetAbilityField(unit, DAMAGE_ABILITY, DAMAGE_FIELD, value, true)

        elseif statType == StatSystem.STAT_ARMOR then
            return SetAbilityField(unit, ARMOR_ABILITY, ARMOR_FIELD, value, true)

        elseif statType == StatSystem.STAT_AGILITY then
            return SetAbilityField(unit, STATS_ABILITY, AGILITY_FIELD, value, true)

        elseif statType == StatSystem.STAT_STRENGTH then
            return SetAbilityField(unit, STATS_ABILITY, STRENGTH_FIELD, value, true)

        elseif statType == StatSystem.STAT_INTELLIGENCE then
            return SetAbilityField(unit, STATS_ABILITY, INTELLIGENCE_FIELD, value, true)

        elseif statType == StatSystem.STAT_HEALTH then
            local prevBonus = StatSystem.GetUnitStat(unit, StatSystem.STAT_HEALTH)
            local maxHP     = BlzGetUnitMaxHP(unit)
            local curHP     = GetWidgetLife(unit)
            local hpPct     = (maxHP > 0) and (curHP / maxHP) or 1.0

            local ok = SetAbilityField(unit, HEALTH_ABILITY, HEALTH_FIELD, value, true)
            if ok then
                local newMax = maxHP + (value - prevBonus)
                if newMax < 1 then newMax = 1 end
                BlzSetUnitMaxHP(unit, newMax)
                SetWidgetLife(unit, newMax * hpPct)
            end
            return ok

        elseif statType == StatSystem.STAT_MANA then
            local prevBonus = StatSystem.GetUnitStat(unit, StatSystem.STAT_MANA)
            local maxMP     = BlzGetUnitMaxMana(unit)
            local curMP     = GetUnitState(unit, UNIT_STATE_MANA)
            local mpPct     = (maxMP > 0) and (curMP / maxMP) or 1.0

            local ok = SetAbilityField(unit, MANA_ABILITY, MANA_FIELD, value, true)
            if ok then
                local newMax = maxMP + (value - prevBonus)
                if newMax < 0 then newMax = 0 end
                BlzSetUnitMaxMana(unit, newMax)
                SetUnitState(unit, UNIT_STATE_MANA, newMax * mpPct)
            end
            return ok

        elseif statType == StatSystem.STAT_MOVEMENT_SPEED then
            return SetAbilityField(unit, MOVEMENT_ABILITY, MOVEMENT_FIELD, value, true)

        elseif statType == StatSystem.STAT_ATTACK_SPEED then
            return SetAbilityField(unit, ATTACK_SPEED_ABILITY, ATTACK_SPEED_FIELD, value, false)

        elseif statType == StatSystem.STAT_HEALTH_REGEN then
            return SetAbilityField(unit, HEALTH_REGEN_ABILITY, HEALTH_REGEN_FIELD, value, false)

        elseif statType == StatSystem.STAT_MANA_REGEN then
            return SetAbilityField(unit, MANA_REGEN_ABILITY, MANA_REGEN_FIELD, value, false)

        elseif statType == StatSystem.STAT_MAGIC_RESISTANCE then
            return SetAbilityField(unit, MAGIC_RESIST_ABILITY, MAGIC_RESIST_FIELD, value, false)

        elseif statType == StatSystem.STAT_SIGHT_RANGE then
            local prev = StatSystem.GetUnitStat(unit, StatSystem.STAT_SIGHT_RANGE)
            local ok = SetAbilityField(unit, SIGHT_ABILITY, SIGHT_FIELD, value, true)
            if ok then
                local delta = value - prev
                BlzSetUnitRealField(unit, UNIT_RF_SIGHT_RADIUS, BlzGetUnitRealField(unit, UNIT_RF_SIGHT_RADIUS) + delta)
            end
            return ok
        end

        debugPrint("SetUnitStat: invalid type " .. tostring(statType))
        return false
    end

    function StatSystem.AddUnitStat(unit, statType, delta)
        local cur = StatSystem.GetUnitStat(unit, statType) or 0
        return StatSystem.SetUnitStat(unit, statType, cur + (delta or 0))
    end
    function StatSystem.RemoveUnitStat(unit, statType)
        return StatSystem.SetUnitStat(unit, statType, 0)
    end

    --------------------------------------------------
    -- SOURCE AGGREGATION (items, buffs, etc.)
    --------------------------------------------------
    local SRC, LAST = {}, {}

    local function getHeroByPid(pid)
        local PD = rawget(_G, "PlayerData")
        if PD and PD.GetHero then
            local u = PD.GetHero(pid)
            if u then return u end
        end
        if _G.PLAYER_DATA and _G.PLAYER_DATA[pid] and _G.PLAYER_DATA[pid].hero then
            return _G.PLAYER_DATA[pid].hero
        end
        return nil
    end

    local function add(t, k, v) if type(v)=="number" then t[k]=(t[k] or 0)+v end end
    local function foldKey(k)
        if k=="strength" then return "str" end
        if k=="agility" then return "agi" end
        if k=="intelligence" then return "int" end
        if k=="damage" then return "attack" end
        if k=="armor" then return "defense" end
        if k=="moveSpeed" then return "speed" end
        return k
    end
    local MAP = {
        str="STR", agi="AGI", int="INT", hp="HP", mp="MP",
        defense="ARMOR", attack="DMG", speed="MS", attackSpeedPct="AS",
        spellPowerPct="SPB", physPowerPct="PWB",
    }

    local function pushTotals(pid, u, totals)
        local prev = LAST[pid] or {}
        local keys = {"STR","AGI","INT","HP","MP","ARMOR","DMG","MS","AS"}
        for i=1,#keys do
            local k=keys[i]; local new=totals[k] or 0; local old=prev[k] or 0
            if new ~= old then
                if     k=="STR"   then StatSystem.SetUnitStat(u, StatSystem.STAT_STRENGTH,       new)
                elseif k=="AGI"   then StatSystem.SetUnitStat(u, StatSystem.STAT_AGILITY,        new)
                elseif k=="INT"   then StatSystem.SetUnitStat(u, StatSystem.STAT_INTELLIGENCE,   new)
                elseif k=="HP"    then StatSystem.SetUnitStat(u, StatSystem.STAT_HEALTH,         new)
                elseif k=="MP"    then StatSystem.SetUnitStat(u, StatSystem.STAT_MANA,           new)
                elseif k=="ARMOR" then StatSystem.SetUnitStat(u, StatSystem.STAT_ARMOR,          new)
                elseif k=="DMG"   then StatSystem.SetUnitStat(u, StatSystem.STAT_DAMAGE,         new)
                elseif k=="MS"    then StatSystem.SetUnitStat(u, StatSystem.STAT_MOVEMENT_SPEED, new)
                elseif k=="AS"    then StatSystem.SetUnitStat(u, StatSystem.STAT_ATTACK_SPEED,   new)
                end
            end
        end
        LAST[pid] = totals

        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit("CombatStatsChanged", {
                pid = pid, unit = u, totals = totals,
                combat = {
                    armor = totals.ARMOR or 0,
                    spellBonusPct    = totals.SPB or 0.0,
                    physicalBonusPct = totals.PWB or 0.0,
                }
            })
        end
    end

    local function recompute(pid)
        local u = getHeroByPid(pid); if not u then return end
        local totals, book = {}, SRC[pid]
        if book then
            for _, mods in pairs(book) do
                if type(mods)=="table" then
                    for k,v in pairs(mods) do
                        if type(k)=="string" and type(v)=="number" then
                            k = foldKey(k); local tag = MAP[k]; if tag then add(totals, tag, v) end
                        end
                    end
                end
            end
        end
        pushTotals(pid, u, totals)
    end

    function StatSystem.ApplySource(pid, key, mods)
        if type(pid)~="number" or type(key)~="string" or type(mods)~="table" then return false end
        SRC[pid] = SRC[pid] or {}
        local copy = {}; for k,v in pairs(mods) do copy[k]=v end
        SRC[pid][key] = copy
        recompute(pid)
        return true
    end

    function StatSystem.RemoveSource(pid, key)
        local book = SRC[pid]; if not book then return false end
        book[key] = nil; recompute(pid); return true
    end

    function StatSystem.Recompute(pid) if type(pid)=="number" then recompute(pid) end end

    --------------------------------------------------
    -- COMBAT SNAPSHOT
    --------------------------------------------------
    local function pidOf(u) if not u then return nil end return GetPlayerId(GetOwningPlayer(u)) end
    function StatSystem.GetCombat(unit)
        local out = {
            armor = StatSystem.GetUnitStat(unit, StatSystem.STAT_ARMOR) or 0,
            spellBonusPct = 0.0, physicalBonusPct = 0.0,
        }
        local pid = pidOf(unit)
        if pid and LAST[pid] then
            out.spellBonusPct    = LAST[pid].SPB or 0.0
            out.physicalBonusPct = LAST[pid].PWB or 0.0
        end
        return out
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    local function InitializeStatSystem()
        debugPrint("StatSystem ready (merged, BJ-free)")
    end

    if OnInit and OnInit.final then
        OnInit.final(function()
            TimerStart(CreateTimer(), 1.0, false, function()
                InitializeStatSystem()
                DestroyTimer(GetExpiredTimer())
            end)
        end)
    else
        InitializeStatSystem()
    end
end

if Debug and Debug.endFile then Debug.endFile() end
