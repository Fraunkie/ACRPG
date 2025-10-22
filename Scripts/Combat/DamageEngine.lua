if Debug and Debug.beginFile then Debug.beginFile("DamageEngine.lua") end
--==================================================
-- DamageEngine.lua (Safe, WC3-type correct version)
--==================================================
-- Provides: applySpellDamage, applyPhysicalDamage, applyTrueDamage
-- All constants initialized as real WC3 handles if available
--==================================================

DamageEngine = DamageEngine or {}
_G.DamageEngine = DamageEngine

--========== SAFE CONSTANT INITIALIZATION ==========
-- Try to create actual typed constants, or fallback to nil-safe stand-ins
ATTACK_TYPE_NORMAL     = ATTACK_TYPE_NORMAL     or ConvertAttackType(0)
ATTACK_TYPE_MAGIC      = ATTACK_TYPE_MAGIC      or ConvertAttackType(3)
DAMAGE_TYPE_NORMAL     = DAMAGE_TYPE_NORMAL     or ConvertDamageType(0)
DAMAGE_TYPE_MAGIC      = DAMAGE_TYPE_MAGIC      or ConvertDamageType(4)
DAMAGE_TYPE_UNIVERSAL  = DAMAGE_TYPE_UNIVERSAL  or ConvertDamageType(11)
WEAPON_TYPE_WHOKNOWS   = WEAPON_TYPE_WHOKNOWS   or ConvertWeaponType(0)
WEAPON_TYPE_NONE       = WEAPON_TYPE_NONE       or ConvertWeaponType(0)

--========== HELPERS ==========
local function unitAlive(u)
    return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
end

-- internal generic handler
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
    local after = GetWidgetLife(target)
    local dealt = math.max(0, before - after)
    return dealt
end

--========== PUBLIC API ==========
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
    print("[DamageEngine] initialized (safe WC3 types)")
end)

if Debug and Debug.endFile then Debug.endFile() end
