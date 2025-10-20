-- StatSystem.lua (refactored, PLAYER_DATA safe)
if Debug and Debug.beginFile then Debug.beginFile('StatSystem') end

StatSystem = {}
_G.StatSystem = StatSystem

do
    --------------------------------------------------
    -- CONFIG
    --------------------------------------------------
    local RECURSION_LIMIT = 8
    local DEBUG_ENABLED = false

    -- Stat identifiers (exported)
    StatSystem.STAT_DAMAGE = 1
    StatSystem.STAT_ARMOR = 2
    StatSystem.STAT_AGILITY = 3
    StatSystem.STAT_STRENGTH = 4
    StatSystem.STAT_INTELLIGENCE = 5
    StatSystem.STAT_HEALTH = 6
    StatSystem.STAT_MANA = 7
    StatSystem.STAT_MOVEMENT_SPEED = 8
    StatSystem.STAT_ATTACK_SPEED = 9
    StatSystem.STAT_HEALTH_REGEN = 10
    StatSystem.STAT_MANA_REGEN = 11
    StatSystem.STAT_MAGIC_RESISTANCE = 12
    StatSystem.STAT_SIGHT_RANGE = 13

    -- Hidden ability ids used to apply bonuses (ensure these exist in your object editor)
    local DAMAGE_ABILITY        = FourCC('A00R') -- Damage
    local ARMOR_ABILITY         = FourCC('A00O') -- Armor
    local STATS_ABILITY         = FourCC('A00N') -- Str/Agi/Int
    local HEALTH_ABILITY        = FourCC('A00T') -- Max Life
    local MANA_ABILITY          = FourCC('A00W') -- Max Mana
    local MOVEMENT_ABILITY      = FourCC('A00X') -- Move Speed
    local ATTACK_SPEED_ABILITY  = FourCC('A00P') -- Attack Speed
    local HEALTH_REGEN_ABILITY  = FourCC('A015')
    local MANA_REGEN_ABILITY    = FourCC('A016')
    local MAGIC_RESIST_ABILITY  = FourCC('A00B')
    local SIGHT_ABILITY         = FourCC('A00Y')

    -- Ability ILF/RLF fields
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
    -- INTERNAL STATE
    --------------------------------------------------
    local eventTriggers = {}
    local currentUnit, currentStat, currentAmount = nil, nil, nil

    -- Helper debug print
    local function debugPrint(msg)
        if DEBUG_ENABLED then
            print("[StatSystem] " .. tostring(msg))
        end
    end

    function StatSystem.ToggleDebug()
        DEBUG_ENABLED = not DEBUG_ENABLED
        print("StatSystem debug: " .. (DEBUG_ENABLED and "ON" or "OFF"))
        return DEBUG_ENABLED
    end

    --------------------------------------------------
    -- Safe ability add + make permanent helper
    --------------------------------------------------
    local function SafeAddAbility(unit, abilId)
        if not unit then return false end

        -- already has it?
        if GetUnitAbilityLevel(unit, abilId) > 0 then
            return true
        end

        -- Try simple add first
        UnitAddAbility(unit, abilId)
        if GetUnitAbilityLevel(unit, abilId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilId)
            return true
        end

        -- Try to temporarily enable for player's tech (some maps lock abilities)
        local owner = GetOwningPlayer(unit)
        if owner then
            SetPlayerAbilityAvailable(owner, abilId, true)
            UnitAddAbility(unit, abilId)
            if GetUnitAbilityLevel(unit, abilId) > 0 then
                UnitMakeAbilityPermanent(unit, true, abilId)
                return true
            end
        end

        -- Last ditch attempt
        UnitAddAbility(unit, abilId)
        if GetUnitAbilityLevel(unit, abilId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilId)
            return true
        end

        debugPrint("SafeAddAbility failed for ability id " .. tostring(abilId))
        return false
    end

    --------------------------------------------------
    -- Core: set ability field (int or real)
    -- returns boolean success
    --------------------------------------------------
    local function SetAbilityField(unit, abilityId, field, value, isInteger)
        if not unit then
            debugPrint("SetAbilityField: unit is nil")
            return false
        end

        -- Ensure ability exists on unit
        if GetUnitAbilityLevel(unit, abilityId) == 0 then
            if not SafeAddAbility(unit, abilityId) then
                return false
            end
        end

        local ua = BlzGetUnitAbility(unit, abilityId)
        if not ua then
            debugPrint("SetAbilityField: BlzGetUnitAbility failed")
            return false
        end

        local ok
        if isInteger then
            ok = BlzSetAbilityIntegerLevelField(ua, field, 0, value)
        else
            ok = BlzSetAbilityRealLevelField(ua, field, 0, value)
        end

        if not ok then
            debugPrint("SetAbilityField: BlzSet... returned false for field ".. tostring(field))
            return false
        end

        -- Refresh ability to apply changes
        IncUnitAbilityLevel(unit, abilityId)
        DecUnitAbilityLevel(unit, abilityId)

        return true
    end

    --------------------------------------------------
    -- Public: GetUnitStat
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
    -- Public: SetUnitStat
    -- Maintains percent for health/mana changes
    --------------------------------------------------
    function StatSystem.SetUnitStat(unit, statType, value)
        if not unit then return false end

        currentUnit, currentStat, currentAmount = unit, statType, value
        for i = 1, #eventTriggers do
            local ok, err = pcall(eventTriggers[i])
            if not ok then debugPrint("Stat event handler error: " .. tostring(err)) end
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
            local healthPercent = GetUnitLifePercentBJ(unit)  -- FIXED: BJ wrapper
            local success = SetAbilityField(unit, HEALTH_ABILITY, HEALTH_FIELD, value, true)
            if success then
                local currentMax = BlzGetUnitMaxHP(unit)
                local delta = value - prevBonus
                BlzSetUnitMaxHP(unit, currentMax + delta)
                SetUnitLifePercentBJ(unit, healthPercent)
            end
            return success
        elseif statType == StatSystem.STAT_MANA then
            local prevBonus = StatSystem.GetUnitStat(unit, StatSystem.STAT_MANA)
            local manaPercent = GetUnitManaPercentBJ(unit)  -- FIXED: BJ wrapper
            local success = SetAbilityField(unit, MANA_ABILITY, MANA_FIELD, value, true)
            if success then
                local currentMax = BlzGetUnitMaxMana(unit)
                local delta = value - prevBonus
                BlzSetUnitMaxMana(unit, currentMax + delta)
                SetUnitManaPercentBJ(unit, manaPercent)
            end
            return success
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
            local success = SetAbilityField(unit, SIGHT_ABILITY, SIGHT_FIELD, value, true)
            if success then
                local delta = value - prev
                BlzSetUnitRealField(unit, UNIT_RF_SIGHT_RADIUS, BlzGetUnitRealField(unit, UNIT_RF_SIGHT_RADIUS) + delta)
            end
            return success
        end

        debugPrint("SetUnitStat: invalid stat type " .. tostring(statType))
        return false
    end

    --------------------------------------------------
    -- Public: AddUnitStat (relative)
    --------------------------------------------------
    function StatSystem.AddUnitStat(unit, statType, delta)
        local cur = StatSystem.GetUnitStat(unit, statType) or 0
        return StatSystem.SetUnitStat(unit, statType, cur + (delta or 0))
    end

    --------------------------------------------------
    -- Public: RemoveUnitStat (reset)
    --------------------------------------------------
    function StatSystem.RemoveUnitStat(unit, statType)
        return StatSystem.SetUnitStat(unit, statType, 0)
    end

    --------------------------------------------------
    -- Events registration and getters
    --------------------------------------------------
    function StatSystem.RegisterStatEvent(handler)
        if type(handler) == 'function' then
            table.insert(eventTriggers, handler)
            debugPrint("Registered stat event")
            return true
        end
        return false
    end

    function StatSystem.GetStatEventUnit() return currentUnit end
    function StatSystem.GetStatEventType() return currentStat end
    function StatSystem.GetStatEventAmount() return currentAmount end

    --------------------------------------------------
    -- Chat commands (for testing)
    --------------------------------------------------
    local function SetupStatCommands()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-addstr", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-addagi", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-addint", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-adddmg", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-addarmor", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-debugstats", false)
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-mystats", false)
        end

        TriggerAddAction(trig, function()
            local p = GetTriggerPlayer()
            local txt = GetEventPlayerChatString()
            local pid = GetPlayerId(p)

            local hero = (PLAYER_DATA and PLAYER_DATA[pid] and PLAYER_DATA[pid].hero) or nil
            if not hero then
                DisplayTextToPlayer(p, 0, 0, "|cFFFF4444No hero found. Create one with the UI or -newsoul.|r")
                return
            end

            if string.find(txt, "-addstr") then
                StatSystem.AddUnitStat(hero, StatSystem.STAT_STRENGTH, 5)
                DisplayTextToPlayer(p, 0, 0, "|cFF88FF88Added +5 Strength to your hero|r")
            elseif string.find(txt, "-addagi") then
                StatSystem.AddUnitStat(hero, StatSystem.STAT_AGILITY, 5)
                DisplayTextToPlayer(p, 0, 0, "|cFF88FF88Added +5 Agility to your hero|r")
            elseif string.find(txt, "-addint") then
                StatSystem.AddUnitStat(hero, StatSystem.STAT_INTELLIGENCE, 5)
                DisplayTextToPlayer(p, 0, 0, "|cFF88FF88Added +5 Intelligence to your hero|r")
            elseif string.find(txt, "-adddmg") then
                StatSystem.AddUnitStat(hero, StatSystem.STAT_DAMAGE, 10)
                DisplayTextToPlayer(p, 0, 0, "|cFF88FF88Added +10 Damage to your hero|r")
            elseif string.find(txt, "-addarmor") then
                StatSystem.AddUnitStat(hero, StatSystem.STAT_ARMOR, 2)
                DisplayTextToPlayer(p, 0, 0, "|cFF88FF88Added +2 Armor to your hero|r")
            elseif string.find(txt, "-mystats") then
                local s = StatSystem.GetUnitStat(hero, StatSystem.STAT_STRENGTH)
                local a = StatSystem.GetUnitStat(hero, StatSystem.STAT_AGILITY)
                local i = StatSystem.GetUnitStat(hero, StatSystem.STAT_INTELLIGENCE)
                local dmg = StatSystem.GetUnitStat(hero, StatSystem.STAT_DAMAGE)
                local arm = StatSystem.GetUnitStat(hero, StatSystem.STAT_ARMOR)
                print("=== YOUR BONUS STATS ===")
                print("Strength: +" .. tostring(s))
                print("Agility: +" .. tostring(a))
                print("Intelligence: +" .. tostring(i))
                print("Damage: +" .. tostring(dmg))
                print("Armor: +" .. tostring(arm))
                print("======================")
            elseif string.find(txt, "-debugstats") then
                StatSystem.ToggleDebug()
            end
        end)
    end

    --------------------------------------------------
    -- Initialization
    --------------------------------------------------
    local function InitializeStatSystem()
        SetupStatCommands()
        debugPrint("StatSystem ready")
    end

    StatSystem.GetUnitStat         = StatSystem.GetUnitStat or StatSystem.GetUnitStat
    StatSystem.SetUnitStat         = StatSystem.SetUnitStat
    StatSystem.AddUnitStat         = StatSystem.AddUnitStat
    StatSystem.RemoveUnitStat      = StatSystem.RemoveUnitStat
    StatSystem.RegisterStatEvent   = StatSystem.RegisterStatEvent
    StatSystem.GetStatEventUnit    = StatSystem.GetStatEventUnit
    StatSystem.GetStatEventType    = StatSystem.GetStatEventType
    StatSystem.GetStatEventAmount  = StatSystem.GetStatEventAmount
    StatSystem.InitializeStatSystem= InitializeStatSystem

    -- Auto-init on map load (deferred so other systems can register)
    if OnInit and OnInit.final then
        OnInit.final(function()
            TimerStart(CreateTimer(), 1.5, false, function()
                InitializeStatSystem()
                DestroyTimer(GetExpiredTimer())
            end)
        end)
    else
        -- Fallback immediate init if OnInit not present
        InitializeStatSystem()
    end
end

if Debug and Debug.endFile then Debug.endFile() end
