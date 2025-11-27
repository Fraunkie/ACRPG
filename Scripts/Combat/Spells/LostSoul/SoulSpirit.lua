if Debug and Debug.beginFile then Debug.beginFile("Spell_SoulSpirit.lua") end
do
    -- This aura is created entirely with code and does not use native buffs.
    Spell_SoulSpirit = Spell_SoulSpirit or {}
    _G.Spell_SoulSpirit = Spell_SoulSpirit

    -- Define values for attack speed and movement speed
    local VALUES = {
        attackSpeedBonus = 0.25,  -- 25% attack speed increase
        moveSpeedBonus = 0.50     -- 50% movement speed increase
    }

    -- Buff Data (effect when applied)
    local BUFF_DATA = {
        name = "Soul Spirit",
        icon = "ReplaceableTextures\\CommandButtons\\BTNSoulSpirit.blp",
        tooltip = "Increases your attack speed by 25".."%%".." and movement speed by 50".."%%"..".",
        effect = "Abilities\\Spells\\Other\\ANrm\\ANrmTarget.mdl",
        values = VALUES,
        isHidden = false,  -- Buff is not hidden, so the icon will appear in the buff bar
        showLevel = true,
        -- Apply effects
        onApply = function(whichUnit, source, values)
            -- Apply movement speed increase (based on current stat)
            local currentMoveSpeed = StatSystem.GetUnitStat(whichUnit, StatSystem.STAT_MOVEMENT_SPEED)
            StatSystem.SetUnitStat(whichUnit, StatSystem.STAT_MOVEMENT_SPEED, currentMoveSpeed + (currentMoveSpeed * values.moveSpeedBonus))

            -- Apply attack speed increase (based on current stat)
            local currentAttackSpeed = StatSystem.GetUnitStat(whichUnit, StatSystem.STAT_ATTACK_SPEED)
            StatSystem.SetUnitStat(whichUnit, StatSystem.STAT_ATTACK_SPEED, currentAttackSpeed + (currentAttackSpeed * values.attackSpeedBonus))
        end,
        -- No expiration, since this is a permanent aura
        isEternal = true,
    }

    -- Aura Data (only applies to the caster)
    local AURA_DATA = {
        name = "Soul Spirit",
        range = 100,
        condition = function(source, target)
            -- Only apply the aura to the caster (self)
            return source == target  -- Only the unit casting the aura is affected
        end,
        effect = "Abilities\\Spells\\Human\\Brilliance\\Brilliance.mdl",
        effectOnSelf = true,
    }

    -- Set the unit with the aura (this is now permanent)
    function Spell_SoulSpirit.setunit(u)
        BuffBot.CreateAura(u, AURA_DATA, BUFF_DATA)  -- Apply permanent aura to unit
    end

    -- Initialize the spell
    OnInit.final(function()
        if Debug then Debug.log("Soul Spirit Aura Initialized") end
    end)
end
if Debug and Debug.endFile then Debug.endFile() end
