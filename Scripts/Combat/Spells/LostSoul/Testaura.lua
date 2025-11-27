if Debug and Debug.beginFile then Debug.beginFile("Spell_SoulSpirit.lua") end
do
	--This aura is created entirely with code and does not use native buffs.
Spell_SoulSpirit = Spell_SoulSpirit or {}
_G.Spell_SoulSpirit = Spell_SoulSpirit
    local VALUES = {
        threshold = 0.5,
        regen = 5
    }

    local BUFF_DATA = {
        name = "Soul Spirit",
        icon = "ReplaceableTextures\\CommandButtons\\BTNNatureTouchGrow.blp",
        tooltip = "As long as this unit is below !threshold,$\x25! health, regenerates !regenConst! health per second.",
        effect = "Abilities\\Spells\\Other\\ANrm\\ANrmTarget.mdl",
        values = VALUES,
        isHidden= false,
        onPeriodic = function(whichUnit, source, values)
            StatSystem.SetUnitStat(whichUnit, moveSpeed, value)
        end,
		showLevel = true
    }

    local AURA_DATA = {
        name = "Soul Spirit",
        range = 100,
        icon = "ReplaceableTextures\\CommandButtons\\BTNNatureTouchGrow.blp",
        condition = function(source, target)
            return IsUnitAlly(target, GetOwningPlayer(source)) and GetUnitState(target, UNIT_STATE_LIFE) < VALUES.threshold*BlzGetUnitMaxHP(target)
        end,
        effect = "Abilities\\Spells\\Human\\Brilliance\\Brilliance.mdl",
        effectOnSelf = true,
        isHidden= false,
    }

    function Spell_TestAura.setunit(u)
        BuffBot.CreateAura(u, AURA_DATA, BUFF_DATA, 1)
    end

        OnInit.final(function()
        if Debug then Debug.log("Test Aura INITIALIZED") end
    end)
end
if Debug and Debug.endFile then Debug.endFile() end