if Debug and Debug.beginFile then Debug.beginFile("SoulStrike.lua") end

-- Spell ID for Soul Strike (A003)
local SOULSTRIKE_SPELL_ID = FourCC('A003')  -- A003 - Soul Strike
local debug = true

-- Function to calculate damage for Soul Strike based on powerLevel
local function SoulStrikeDamage(pid)
    local powerLevel = PLAYER_DATA[pid].powerLevel  -- Get the player's current power level
    local baseDamage = powerLevel * 0.5  -- Multiply by 0.5 for the damage calculation
    return baseDamage
end

-- Handler for the "MeleeHit" event
function OnSoulStrikeMeleeHit(payload)
    local unit = payload.unit  -- The unit that performed the melee attack
    local target = payload.target  -- The target of the melee hit
    local pid = GetPlayerId(unit)  -- Get the player ID who controls the unit casting Soul Strike

    -- Check if the unit has Soul Strike (A003) spell
    if not GetUnitAbilityLevel(unit, SOULSTRIKE_SPELL_ID) > 0 then
        return  -- Exit if the unit does not have the Soul Strike ability
    end

    -- Calculate the base damage for Soul Strike
    local baseDamage = SoulStrikeDamage(pid)

    -- Create the context for DamageResolver
    local ctx = {
        source = unit,  -- Attacking unit
        target = target,  -- Target of the melee hit
        amount = baseDamage,  -- Damage to resolve
        isAttack = true,  -- This is an attack (not a spell)
        isRanged = false  -- This is a melee attack
    }

    -- Resolve the final damage using DamageResolver
    local resolved = DamageResolver.Resolve(ctx)

    -- Apply the resolved damage to the target
    local finalDamage = resolved.amount

    -- Apply the damage to the target unit (using DamageEngine or a similar function)
    if DamageEngine then
        -- If DamageEngine exists, use it to apply damage
        DamageEngine.applySpellDamage(unit, target, finalDamage, DAMAGE_TYPE_MAGIC)  -- Magic is treated as Energy damage
        if debug then
            DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0,
                "[SoulStrike] Applied " .. tostring(finalDamage) .. " damage to " .. tostring(GetUnitName(target)))
        end
    else
        -- Fallback to native if DamageEngine is not available
        UnitDamageTarget(unit, target, finalDamage, true, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
    end

    -- Optional: Add visual or sound effects for Soul Strike proc (e.g., FX or SFX)
    local x, y = GetUnitX(target), GetUnitY(target)
    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\TalkToMe\\TalkToMe.mdl", x, y))  -- Example effect

    -- Optional: Any other effects (e.g., Soul Energy gain)
    -- SoulEnergy.Add(pid, 10)  -- Example: award Soul Energy on hit
end

-- Emitting the "MeleeHit" event via ProcBus
function OnMeleeHit(unit, target)
    local pid = GetPlayerId(unit)  -- Get the player ID
    local attackType = GetUnitAttackType(unit)  -- Get the attack type of the unit (melee or ranged)
    
    -- Check if the unit is performing a melee attack and has Soul Strike
    if attackType == ATTACK_TYPE_NORMAL and GetUnitAbilityLevel(unit, SOULSTRIKE_SPELL_ID) > 0 then
        -- Emit the "MeleeHit" event via ProcBus
        local payload = { unit = unit, target = target }
        ProcBus.Emit("MeleeHit", payload)
    end
end

-- Register the event handler for "MeleeHit" via ProcBus
ProcBus.On("MeleeHit", OnSoulStrikeMeleeHit)

-- Example trigger setup for melee hit detection
function InitSoulStrikeMeleeHit()
    local trigger = CreateTrigger()
    TriggerRegisterUnitEvent(trigger, GetTriggerUnit(), EVENT_UNIT_DAMAGED)
    TriggerAddAction(trigger, function() OnMeleeHit(GetTriggerUnit(), BlzGetEventDamageTarget()) end)
end

if Debug and Debug.endFile then Debug.endFile() end
