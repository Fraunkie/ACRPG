if Debug and Debug.beginFile then Debug.beginFile("DamageEngine.lua") end
--==================================================
-- DamageEngine.lua (Safe, WC3-type correct version)
--==================================================
-- Provides: applySpellDamage, applyPhysicalDamage, applyTrueDamage
-- All constants initialized as real WC3 handles if available
-- No use of the percent character anywhere
-- Also exposes:
--   DamageEngine.showArcingDamageText(caster, target, damage, dmgType)
--   DamageEngine.showCombatResultText(target, result)
--==================================================

DamageEngine = DamageEngine or {}
_G.DamageEngine = DamageEngine

--========== SAFE CONSTANT INITIALIZATION ==========
ATTACK_TYPE_NORMAL     = ATTACK_TYPE_NORMAL     or ConvertAttackType(0)
ATTACK_TYPE_MAGIC      = ATTACK_TYPE_MAGIC      or ConvertAttackType(3)
DAMAGE_TYPE_NORMAL     = DAMAGE_TYPE_NORMAL     or ConvertDamageType(0)
DAMAGE_TYPE_MAGIC      = DAMAGE_TYPE_MAGIC      or ConvertDamageType(4)
DAMAGE_TYPE_UNIVERSAL  = DAMAGE_TYPE_UNIVERSAL  or ConvertDamageType(11)
WEAPON_TYPE_WHOKNOWS   = WEAPON_TYPE_WHOKNOWS   or ConvertWeaponType(0)
WEAPON_TYPE_NONE       = WEAPON_TYPE_NONE       or ConvertWeaponType(0)

-- toggles so we can shut them up later if needed
local SHOW_NUMBER_TAGS = true
local SHOW_RESULT_TAGS = true   -- <-- this controls CRIT / BLOCK / DODGE / PARRY

--========== HELPERS ==========
local function unitAlive(u)
    return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
end

--==================================================
-- Result / outcome tag (CRIT, BLOCK, DODGE, PARRY)
--==================================================
function DamageEngine.showCombatResultText(target, result)
    if not SHOW_RESULT_TAGS then
        return
    end
    if not target or GetUnitTypeId(target) == 0 then
        return
    end
    if not result or result == "" or result == "HIT" then
        return
    end

    local x = GetUnitX(target)
    local y = GetUnitY(target)

    local tag = CreateTextTag()
    if not tag then
        return
    end

    local text  = string.lower(result)
    local size  = 0.022
    local r, g, b = 255, 255, 255

    -- pick colors per outcome
    if result == "CRIT" then
        text = "crit"
        r, g, b = 255, 80, 40
        size    = 0.026
    elseif result == "BLOCK" then
        text = "block"
        r, g, b = 200, 200, 200
    elseif result == "DODGE" then
        text = "dodge"
        r, g, b = 120, 220, 255
    elseif result == "PARRY" then
        text = "parry"
        r, g, b = 120, 255, 180
    else
        -- unknown result, keep white
    end

    SetTextTagPermanent(tag, false)
    SetTextTagLifespan(tag, 0.9)
    SetTextTagFadepoint(tag, 0.6)
    SetTextTagText(tag, text, size)
    SetTextTagColor(tag, r, g, b, 255)
    -- a bit higher than the number tag so they do not overlap as much
    SetTextTagPos(tag, x, y, 82)

    return tag
end

--==================================================
-- Floating damage text (arcing)  -- NUMBER TAG
--==================================================
function DamageEngine.showArcingDamageText(caster, target, damage, dmgType)
    if not SHOW_NUMBER_TAGS then
        return
    end
    if not target or GetUnitTypeId(target) == 0 then
        return
    end

    local baseX = GetUnitX(target)
    local baseY = GetUnitY(target)

    -- small per-type offsets so multiple tags do not stack exactly
    local dx = 0.0
    local dy = 0.0
    if dmgType == DAMAGE_TYPE_MAGIC then
        dx = 16.0
        dy = 10.0
    elseif dmgType == DAMAGE_TYPE_NORMAL then
        dx = -16.0
        dy = 0.0
    elseif dmgType == DAMAGE_TYPE_UNIVERSAL then
        dx = 0.0
        dy = 18.0
    end

    local x = baseX + dx
    local y = baseY + dy

    local textTag = CreateTextTag()
    if textTag == nil then
        print("[DamageEngine] could not create text tag")
        return
    end

    -- floor the shown number so 24.88 becomes 24
    local shown = tonumber(damage or 0) or 0
    if shown < 0 then
        shown = 0
    end
    shown = math.floor(shown + 0.0001)
    if shown < 1 then
        shown = 1
    end

    SetTextTagPermanent(textTag, false)
    SetTextTagLifespan(textTag, 1.0)
    SetTextTagFadepoint(textTag, 0.8)
    SetTextTagText(textTag, tostring(shown), 0.025)

    -- color by damage type
    if dmgType == DAMAGE_TYPE_MAGIC then
        SetTextTagColor(textTag, 0, 0, 255, 255)          -- blue
    elseif dmgType == DAMAGE_TYPE_UNIVERSAL then
        SetTextTagColor(textTag, 255, 0, 0, 255)          -- red
    elseif dmgType == DAMAGE_TYPE_NORMAL then
        SetTextTagColor(textTag, 255, 255, 0, 255)        -- yellow
    else
        SetTextTagColor(textTag, 255, 255, 255, 255)      -- white
    end

    SetTextTagPos(textTag, x, y, 50)

    -- simple drift timer
    local startTime = os.clock()
    local timer = CreateTimer()
    TimerStart(timer, 0.03, true, function()
        local now = os.clock()
        local elapsed = now - startTime

        x = x - 0.5
        y = y + 0.5

        SetTextTagPos(textTag, x, y, 50)

        if elapsed >= 1.0 then
            DestroyTimer(timer)
        end
    end)

    return textTag
end

--==================================================
-- INTERNAL GENERIC HANDLER
--==================================================
local function apply(caster, target, amount, opts)
    if not caster or not target or amount == nil then return 0 end
    if amount <= 0 or not unitAlive(target) then return 0 end

    local atkType  = (opts and opts.attackType) or ATTACK_TYPE_NORMAL
    local dmgType  = (opts and opts.damageType) or DAMAGE_TYPE_MAGIC
    local wepType  = (opts and opts.weaponType) or WEAPON_TYPE_WHOKNOWS
    local isAttack = (opts and opts.isAttack)   or false
    local isRanged = (opts and opts.isRanged)   or false

    local before = GetWidgetLife(target)
    UnitDamageTarget(caster, target, amount, isAttack, isRanged, atkType, dmgType, wepType)
    local after  = GetWidgetLife(target)
    local dealt  = math.max(0, before - after)

    -- this is the correct place to show the number
    if dealt > 0 then
        DamageEngine.showArcingDamageText(caster, target, dealt, dmgType)
    end

    return dealt
end

--==================================================
-- PUBLIC DAMAGE APIS
--==================================================
function DamageEngine.applySpellDamage(caster, target, amount, damageType)
    return apply(caster, target, amount, {
        attackType = ATTACK_TYPE_MAGIC,
        damageType = damageType or DAMAGE_TYPE_MAGIC,
        weaponType = WEAPON_TYPE_NONE,
        isAttack   = false,
        isRanged   = false
    })
end

function DamageEngine.applyPhysicalDamage(caster, target, amount)
    return apply(caster, target, amount, {
        attackType = ATTACK_TYPE_NORMAL,
        damageType = DAMAGE_TYPE_NORMAL,
        weaponType = WEAPON_TYPE_WHOKNOWS,
        isAttack   = true,
        isRanged   = false
    })
end

function DamageEngine.applyTrueDamage(caster, target, amount)
    return apply(caster, target, amount, {
        attackType = ATTACK_TYPE_NORMAL,
        damageType = DAMAGE_TYPE_UNIVERSAL,
        weaponType = WEAPON_TYPE_NONE,
        isAttack   = false,
        isRanged   = false
    })
end

function DamageEngine.isEnemy(caster, target)
    return caster and target and IsUnitEnemy(target, GetOwningPlayer(caster))
end

OnInit.final(function()
    print("[DamageEngine] initialized (safe WC3 types, integer text, result tags)")
end)

if Debug and Debug.endFile then Debug.endFile() end
