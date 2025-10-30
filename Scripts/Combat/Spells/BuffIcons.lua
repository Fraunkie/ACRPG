if Debug and Debug.beginFile then Debug.beginFile("BuffIcons.lua") end
--==================================================
-- BuffIcons.lua
-- Mirrors native WC3 abilities into BuffBot UI.
--  • Passives: adds eternal icons when learned or pre-placed.
--  • AoE spells: shows timed buff icons based on OE duration.
--  • Supports dispel sync with native buffs.
-- Requires: BuffBot, EasyAbilityFields, TotalInitialization (OnInit.final)
--==================================================

do
    --------------------------------------------------
    -- CONFIG: add your ability rawcodes here
    --------------------------------------------------
    local PASSIVE_ABILS = {
        -- [abilityId] = { name=..., icon=..., tooltip=... }
        [FourCC('A000')] = {
            name    = "Soul Spirit",
            icon    = "ReplaceableTextures\\CommandButtons\\PASLightningSphereBlue.blp",
            tooltip = "|cff80ff80Passive:|r The Lost soul has Increases attack speed by 25%.",
        },
        [FourCC('Aps2')] = {
            name    = "Wailing Presence",
            icon    = "ReplaceableTextures\\CommandButtons\\BTNSpiritOfVengeance.blp",
            tooltip = "|cff80ff80Passive:|r Increases movement speed by 5%.",
        },
    }

    local AOE_CASTS = {
        -- [abilityId] = { name=..., icon=..., tooltip=..., trackTarget=true|false }
        [FourCC('Aoe1')] = {
            name    = "Soul Sunder",
            icon    = "ReplaceableTextures\\CommandButtons\\BTNHowlOfTerror.blp",
            tooltip = "Enemies are weakened for the duration.",
            trackTarget = false,
        },
    }

    local NATIVE_BUFF_OF = {
        -- [abilityId] = FourCC('Bxxx')
        [FourCC('Aoe1')] = FourCC('B000'), -- replace with your native buff if needed
    }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function readDuration(abilityId, unit)
        local fld = IsUnitType(unit, UNIT_TYPE_HERO) and "ahdu" or "adur"
        local ok, dur = pcall(function() return GetUnitAbilityField(unit, abilityId, fld) end)
        if ok and type(dur) == "number" and dur > 0 then return dur end
        ok, dur = pcall(function() return GetAbilityField(abilityId, fld, 1) end)
        if ok and type(dur) == "number" and dur > 0 then return dur end
        return 6.0
    end

    local function applyPassiveIcon(u, data)
        if not BuffBot or not BuffBot.Apply then return end
        BuffBot.Apply(u, {
            name      = data.name,
            icon      = data.icon,
            tooltip   = data.tooltip or "",
            isEternal = true,
            type      = "Passive",
        })
    end

    local function applyTimedIcon(u, data, abilityId)
        if not BuffBot or not BuffBot.Apply then return end
        local dur = readDuration(abilityId, u)
        BuffBot.Apply(u, {
            name     = data.name,
            icon     = data.icon,
            tooltip  = data.tooltip or "",
            duration = dur,
            type     = "Buff",
        })
    end

    local function mirrorDispelUntil(u, buffName, abilityId, nativeBuff)
        if not nativeBuff or nativeBuff == 0 then return end
        local t = CreateTimer()
        TimerStart(t, 0.20, true, function()
            if not validUnit(u) then
                DestroyTimer(t)
                return
            end
            if UnitHasBuffBJ and not UnitHasBuffBJ(u, nativeBuff) then
                if BuffBot and BuffBot.Dispel then
                    BuffBot.Dispel(u, buffName)
                end
                DestroyTimer(t)
            end
        end)
    end

    --------------------------------------------------
    -- Events
    --------------------------------------------------
    OnInit.final(function()
        -- Hero learns a passive ability
        local trigLearn = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trigLearn, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        end
        TriggerAddAction(trigLearn, function()
            local u = GetTriggerUnit()
            if not validUnit(u) then return end
            local abilId = GetLearnedSkill()
            local data = PASSIVE_ABILS[abilId]
            if data then
                applyPassiveIcon(u, data)
            end
        end)

        -- Pre-placed passives on map start
        TimerStart(CreateTimer(), 0.50, false, function()
            for i = 0, bj_MAX_PLAYERS - 1 do
                local p = Player(i)
                if GetPlayerSlotState(p) == PLAYER_SLOT_STATE_PLAYING then
                    local g = CreateGroup()
                    GroupEnumUnitsOfPlayer(g, p, nil)
                    while true do
                        local u = FirstOfGroup(g)
                        if not u then break end
                        GroupRemoveUnit(g, u)
                        if IsUnitType(u, UNIT_TYPE_HERO) then
                            for abilId, data in pairs(PASSIVE_ABILS) do
                                if GetUnitAbilityLevel(u, abilId) > 0 then
                                    applyPassiveIcon(u, data)
                                end
                            end
                        end
                    end
                    DestroyGroup(g)
                end
            end
        end)

        -- AoE spell casts
        local trigCast = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trigCast, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        end
        TriggerAddAction(trigCast, function()
            local caster = GetTriggerUnit()
            if not validUnit(caster) then return end
            local abilId = GetSpellAbilityId()
            local data = AOE_CASTS[abilId]
            if not data then return end

            local targetUnit = caster
            if data.trackTarget then
                local t = GetSpellTargetUnit()
                if validUnit(t) then targetUnit = t end
            end

            applyTimedIcon(targetUnit, data, abilId)

            local nb = NATIVE_BUFF_OF[abilId]
            if nb and nb ~= 0 then
                mirrorDispelUntil(targetUnit, data.name, abilId, nb)
            end
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
