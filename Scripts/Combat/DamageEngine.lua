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
    DisplayTextToPlayer(GetOwningPlayer(caster), 0, 0,
        "[DamageEngine] " ..
        "Caster=" .. tostring(GetUnitName(caster)) ..
        " Target=" .. tostring(GetUnitName(target)) ..
        " Amount=" .. tostring(amount) ..
        " Type=" .. tostring(dmgType)
    )
    local after = GetWidgetLife(target)
    local dealt = math.max(0, before - after)
    return dealt
end

--========== PUBLIC API ==========

function DamageEngine.showArcingDamageText(caster, target, damage, dmgType)
    -- Get the location of the target to place the text tag
    local x, y = GetUnitX(target), GetUnitY(target)

    -- Debug: Check if the position is valid
    DisplayTextToPlayer(GetOwningPlayer(target), 0, 0, "TextTag Position: x = " .. tostring(x) .. ", y = " .. tostring(y))

    -- Define text tag properties
    local textTag = CreateTextTag()
    if textTag == nil then
        print("[Error] Failed to create text tag!")
        return
    end

    SetTextTagPermanent(textTag, false)  -- Make it disappear after a short time
    SetTextTagLifespan(textTag, 1.0)  -- Lifespan of the text tag (in seconds)
    SetTextTagFadepoint(textTag, 0.8)  -- When it starts fading

    -- Set the text and size
    SetTextTagText(textTag, tostring(damage), 0.025)  -- Size of the text (adjustable)

    -- Set color based on damage type
    if dmgType == DAMAGE_TYPE_MAGIC then
        SetTextTagColor(textTag, 0, 0, 255, 255)  -- Blue for Energy (Magic)
    elseif dmgType == DAMAGE_TYPE_NORMAL then
        SetTextTagColor(textTag, 255, 255, 0, 255)  -- Yellow for Physical damage
    elseif dmgType == DAMAGE_TYPE_UNIVERSAL then
        SetTextTagColor(textTag, 255, 0, 0, 255)  -- Red for True Damage (Crit)
    else
        SetTextTagColor(textTag, 255, 255, 255, 255)  -- Default White
    end

    -- Position the text tag above the target unit (Z offset for height)
    SetTextTagPos(textTag, x, y, 50)  -- Adjust the height (50 is above the unit)

    -- Start a timer for the timed movement
    local startTime = os.clock()  -- Record the starting time when the text is created

    -- Create a timer to handle the movement and scaling over time
    local timer = CreateTimer()

    -- Timer update function
    TimerStart(timer, 0.03, true, function()
        local elapsedTime = os.clock() - startTime  -- Calculate how much time has passed since creation

        -- Debug: Check if the timer is running

        -- Calculate the movement and size increase over time
        local p = math.sin(math.pi * ((1 - elapsedTime) / 1.0))  -- Scaling effect
        x = x - 0.5  -- Move left
        y = y + 0.5  -- Move up
        SetTextTagPos(textTag, x, y, 50 + 50 * p)  -- Add dynamic height
        SetTextTagText(textTag, tostring(damage), (0.025 + 0.012 * p))  -- Increase text size over time

        -- End the timer after 1 second (to stop the movement)
        if elapsedTime >= 1.0 then
            DestroyTimer(timer)  -- Stop the timer
        end
    end)

    return textTag  -- Return the text tag for reference
end

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