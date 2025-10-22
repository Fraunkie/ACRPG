if Debug and Debug.beginFile then Debug.beginFile("Spell_KiSlash.lua") end
--==================================================
-- Spell_KiSlash.lua  (standalone spell module)
-- Ki Slash: instant, forward cone, PHYSICAL damage.
-- - No dependency on SpellEngine types; runs itself.
-- - Safe if DamageEngine isn't present (falls back).
-- - Uses FX: war3mapImported\\blue slash.mdl
--==================================================

do
    --------------------------------------------------
    -- Config (tweak freely)
    --------------------------------------------------
    local ABIL_ID        = FourCC('A0KS')     -- <-- set to your Ki Slash rawcode
    local CONE_RANGE     = 450.0              -- reach of the slash
    local CONE_HALF_DEG  = 40.0               -- half-angle of the cone (total ~80°)
    local BASE_DAMAGE    = 40.0               -- flat base
    local STR_SCALE      = 0.50               -- add STR * this (or use another stat)
    local POWER_SCALE    = 0.50               -- add PowerLevel * this (optional)
    local HIT_FX_MODEL   = "war3mapImported\\blue slash.mdl"
    local HIT_FX_SCALE   = 1.10
    local SHOW_OWNER_NUM = false              -- floating numbers for the caster

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end

    local function radians(deg) return deg * bj_DEGTORAD end
    local function dot(ax, ay, bx, by) return ax*bx + ay*by end
    local function len(x, y) return SquareRoot(x*x + y*y) end

    local function ownerFloatText(u, txt, r, g, b)
        if not SHOW_OWNER_NUM then return end
        local p = GetOwningPlayer(u)
        if GetLocalPlayer() ~= p then return end
        local t = CreateTextTag()
        SetTextTagText(t, txt, 0.023)
        SetTextTagPosUnit(t, u, 50)
        SetTextTagColor(t, r or 255, g or 255, b or 255, 255)
        SetTextTagVelocity(t, 0.00, 0.03)
        SetTextTagLifespan(t, 0.8)
        SetTextTagFadepoint(t, 0.55)
    end

    local function dealPhysical(caster, target, amount)
        if amount <= 0 then return end
        if _G.DamageEngine and DamageEngine.applyPhysicalDamage then
            DamageEngine.applyPhysicalDamage(caster, target, amount)
        else
            if not WEAPON_TYPE_WHOKNOWS then WEAPON_TYPE_WHOKNOWS = 0 end
            UnitDamageTarget(
                caster, target, amount,
                true,  false,                 -- attack, ranged
                ATTACK_TYPE_NORMAL,
                DAMAGE_TYPE_NORMAL,
                WEAPON_TYPE_WHOKNOWS
            )
        end
    end

    -- Pull primary attributes/power safely from mirrors
    local function getSTR(pid)
        return (rawget(_G,"PlayerMStr") and PlayerMStr[pid]) or 0
    end
    local function getPowerLevel(pid)
        if _G.PlayerData and PlayerData.Get then
            return (PlayerData.Get(pid).powerLevel or 0)
        end
        return 0
    end

    local function computeDamage(caster)
        local pid   = GetPlayerId(GetOwningPlayer(caster))
        local str   = getSTR(pid)
        local pl    = getPowerLevel(pid)
        local dmg   = BASE_DAMAGE + (str * STR_SCALE) + (pl * POWER_SCALE)
        if dmg < 0 then dmg = 0 end
        return dmg
    end

    --------------------------------------------------
    -- Core: apply cone hit in front of caster
    --------------------------------------------------
    local function doKiSlash(caster)
        if not unitAlive(caster) then return end

        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local facing = radians(GetUnitFacing(caster))
        local fx, fy = math.cos(facing), math.sin(facing)
        local cosLimit = math.cos(radians(CONE_HALF_DEG))
        local range2   = CONE_RANGE * CONE_RANGE

        local dmg = computeDamage(caster)
        if SHOW_OWNER_NUM then ownerFloatText(caster, tostring(math.floor(dmg+0.5)), 255, 220, 80) end

        -- play the slash visual near the caster
        local eff = AddSpecialEffect(HIT_FX_MODEL, cx + fx*60.0, cy + fy*60.0)
        BlzSetSpecialEffectScale(eff, HIT_FX_SCALE)
        BlzSetSpecialEffectYaw(eff, facing)
        DestroyEffect(eff)

        local g = CreateGroup()
        GroupEnumUnitsInRange(g, cx, cy, CONE_RANGE + 40.0, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if IsUnitEnemy(u, GetOwningPlayer(caster)) and unitAlive(u) then
                local ux, uy = GetUnitX(u), GetUnitY(u)
                local vx, vy = ux - cx, uy - cy
                local d2     = vx*vx + vy*vy
                if d2 <= range2 then
                    local vl = len(vx, vy)
                    if vl > 0.0001 then
                        local nx, ny = vx / vl, vy / vl
                        local dp = dot(nx, ny, fx, fy)
                        if dp >= cosLimit then
                            dealPhysical(caster, u, dmg)
                        end
                    end
                end
            end
        end)
        DestroyGroup(g)

        -- small animation feedback
        SetUnitAnimation(caster, "attack")
    end

    --------------------------------------------------
    -- Wiring: listen to EFFECT for this one ability
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        end
        TriggerAddAction(t, function()
            if GetSpellAbilityId() == ABIL_ID then
                doKiSlash(GetTriggerUnit())
            end
        end)
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("Spell_KiSlash")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
