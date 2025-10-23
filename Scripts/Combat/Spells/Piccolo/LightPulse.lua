if Debug and Debug.beginFile then Debug.beginFile("Piccolo_LightPulse.lua") end
--==================================================
-- Piccolo_LightPulse.lua (A0LG)
-- Instant AoE pulse: damages enemies and heals allies, then a short HoT lingers.
-- Uses SpellSystemInit.GetDamageForSpell as the single source of "power".
-- • Radius 300
-- • Damage = power
-- • Heal upfront = 0.40 * power
-- • Heal per tick (2 ticks) = 0.10 * power
-- • Skips Neutral Passive and DUMY units
--==================================================

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local ABIL_ID          = FourCC('A0LG')

    local RADIUS           = 300.0
    local LINGER_TIME      = 1.50
    local LINGER_TICK      = 0.75    -- 2 ticks total
    local HEAL_INIT_FRAC   = 0.40
    local HEAL_TICK_FRAC   = 0.10
    local MIN_POWER        = 1       -- floor so something always happens

    local FX_BURST         = "Abilities\\Spells\\Human\\HolyBolt\\HolyBoltSpecialArt.mdl"
    local FX_LINGER        = "Abilities\\Spells\\Other\\ImmolationRed\\ImmolationRedTarget.mdl"

    local DUMY_ID          = FourCC('DUMY')
    local DEBUG_MSG        = true    -- set false after verifying

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local PT_NEUTRAL_PASSIVE = Player(PLAYER_NEUTRAL_PASSIVE)

    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end
    local function isNeutralPassiveUnit(u)
        return GetOwningPlayer(u) == PT_NEUTRAL_PASSIVE
    end
    local function isDummy(u)
        return GetUnitTypeId(u) == DUMY_ID
    end
    local function pidOf(u)
        return GetPlayerId(GetOwningPlayer(u))
    end
    local function say(p, text)
        if not DEBUG_MSG then return end
        DisplayTextToPlayer(p, 0, 0, text)
    end

    -- Damage via DamageEngine if present (magic), else fallback
    local function dealMagic(caster, target, amount)
        if not unitAlive(target) or amount <= 0 then return 0 end
        local before = GetWidgetLife(target)
        if DamageEngine and DamageEngine.applySpellDamage then
            local ok = pcall(DamageEngine.applySpellDamage, caster, target, amount, DAMAGE_TYPE_MAGIC)
            if not ok then
                UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
            end
        else
            UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
        end
        local after  = GetWidgetLife(target)
        return math.max(0, before - after)
    end

    -- Healing via DamageEngine if present, else fallback clamp
    local function applyHealing(caster, target, amount)
        if not unitAlive(target) or amount <= 0 then return 0 end
        if DamageEngine and DamageEngine.applyHealing then
            local ok, healed = pcall(DamageEngine.applyHealing, caster, target, amount)
            if ok and type(healed) == "number" then return math.max(0, healed) end
        end
        local life = GetUnitState(target, UNIT_STATE_LIFE)
        local max  = GetUnitState(target, UNIT_STATE_MAX_LIFE)
        local add  = math.min(amount, math.max(0, max - life))
        if add > 0 then SetUnitState(target, UNIT_STATE_LIFE, life + add) end
        return add
    end

    -- Get "power" from SpellSystemInit (follows your energy spell formula)
    local function getPower(pid, level)
        if _G.SpellSystemInit and SpellSystemInit.GetDamageForSpell then
            local ok, v = pcall(SpellSystemInit.GetDamageForSpell, pid, ABIL_ID, level or 1, nil)
            if ok and type(v) == "number" then
                return math.max(MIN_POWER, math.floor(v + 0.5))
            end
        end
        return 100 -- conservative fallback that keeps the spell meaningful
    end

    --------------------------------------------------
    -- Core
    --------------------------------------------------
    local function pulseOnce(caster, cx, cy, pid, power)
        local fx = AddSpecialEffect(FX_BURST, cx, cy); DestroyEffect(fx)

        local pCaster = Player(pid)
        local enemies, allies = 0, 0

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, cx, cy, RADIUS, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if unitAlive(u) and not isDummy(u) and not isNeutralPassiveUnit(u) then
                if IsUnitEnemy(u, pCaster) then
                    local dealt = dealMagic(caster, u, power)
                    enemies = enemies + (dealt > 0 and 1 or 0)
                elseif IsPlayerAlly(GetOwningPlayer(u), pCaster) then
                    local healed = applyHealing(caster, u, math.floor(power * HEAL_INIT_FRAC + 0.5))
                    allies = allies + 1 -- count as affected even if already full
                end
            end
        end)
        DestroyGroup(g)

        say(pCaster, "[Light Pulse] power="..power.." | enemies hit="..enemies.." | allies affected="..allies)
    end

    local function lingerHeal(caster, cx, cy, pid, power)
        local auraFx = AddSpecialEffect(FX_LINGER, cx, cy)
        if BlzSetSpecialEffectScale then BlzSetSpecialEffectScale(auraFx, 1.15) end

        local ticks = 0
        local perTick = math.max(1, math.floor(power * HEAL_TICK_FRAC + 0.5))

        local t = CreateTimer()
        TimerStart(t, LINGER_TICK, true, function()
            ticks = ticks + 1
            local pCaster = Player(pid)

            local g = CreateGroup()
            GroupEnumUnitsInRange(g, cx, cy, RADIUS, nil)
            ForGroup(g, function()
                local u = GetEnumUnit()
                if unitAlive(u) and not isDummy(u) and not isNeutralPassiveUnit(u) then
                    if IsPlayerAlly(GetOwningPlayer(u), pCaster) then
                        applyHealing(caster, u, perTick)
                    end
                end
            end)
            DestroyGroup(g)

            if ticks >= 2 or ticks * LINGER_TICK >= LINGER_TIME - 0.001 then
                DestroyEffect(auraFx)
                DestroyTimer(t)
            end
        end)
    end

    local function onCast(ctx)
        if ctx.abilityId ~= ABIL_ID then return end
        local caster = ctx.caster
        if not unitAlive(caster) then return end

        local pid   = pidOf(caster)
        local level = GetUnitAbilityLevel(caster, ABIL_ID)
        local power = getPower(pid, level)

        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        pulseOnce(caster, cx, cy, pid, power)
        lingerHeal(caster, cx, cy, pid, power)
    end

    --------------------------------------------------
    -- Hook
    --------------------------------------------------
    OnInit.final(function()
        if _G.SpellEngine and SpellEngine.RegisterScripted then
            SpellEngine.RegisterScripted(ABIL_ID, onCast)
        else
            local t = CreateTrigger()
            for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
                TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
            end
            TriggerAddAction(t, function()
                if GetSpellAbilityId() == ABIL_ID then
                    onCast({
                        caster    = GetTriggerUnit(),
                        abilityId = ABIL_ID,
                        level     = GetUnitAbilityLevel(GetTriggerUnit(), ABIL_ID)
                    })
                end
            end)
        end
        print("[Light Pulse] Ready (A0LG, energy-scaling)")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
