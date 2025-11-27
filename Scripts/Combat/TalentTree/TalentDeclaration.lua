if Debug then Debug.beginFile "TalentDeclaration" end
do
    OnInit.global(function()

        -- Energy Damage Lost Soul (Correct Scaling for Ranks)
CTT.RegisterTalent({
    name = "Bonus Energy Damage",
    tooltip = "Increases energy bonus damage by !increase,\x25!.",
    prelearnTooltip = "Increases energy bonus damage by !increase,\x25!.",
    icon = "ReplaceableTextures\\CommandButtons\\BTNSoulSpirit.blp",
    tree = "LostSoul",
    column = 1,
    row = 1,
    maxPoints = 3,
    values = {
        increase = 0.04  
    },
    onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
        local pid = GetPlayerId(whichPlayer)

        local combatData = PlayerData.GetCombat(pid)
        if not combatData.spellBonusPct then
            combatData.spellBonusPct = 0 
        end


        local energylevel = combatData.spellBonusPct or 0
        local increaseValue = CTT.GetValue(whichPlayer, talentName, "increase")


        if newRank == 1 then
            combatData.spellBonusPct = increaseValue
        elseif newRank == 2 then
            combatData.spellBonusPct = energylevel - (increaseValue / newRank) + increaseValue  
        elseif newRank == 3 then
            combatData.spellBonusPct = energylevel - (increaseValue / newRank) + increaseValue  
        end

        PlayerData.SetCombat(pid).spellBonusPct = combatData.spellBonusPct

    end
}) 
        --SpiritVortex Orb Count
        CTT.RegisterTalent({
            --Add name, tooltip, and icon from an ability.
            name = "Vortex Orbs",
            icon = "ReplaceableTextures\\CommandButtons\\BTNSpiritVortex.blp",
            tooltip = "Gain extra !orbs! orbs for Spirit Vortex.",
            prelearnTooltip = "Gain extra !orbs! orbs for Spirit Vortex.",
            tree = "LostSoul",
            column = 2,
            requirement = "Bonus Energy Damage",
            row = 1,
            maxPoints = 2,
            values = {
                orbs = 3
            },
        })

CTT.RegisterTalent({
    name = "Bonus Physical Damage",
    tooltip = "Increases Physical bonus damage by !increase,\x25!.",
    prelearnTooltip = "Increases Physical bonus damage by !increase,\x25!.",
    icon = "ReplaceableTextures\\CommandButtons\\BTNSoulSpirit.blp",
    tree = "LostSoul",
    column = 3,
    row = 1,
    maxPoints = 5,
    values = {
        increase = 0.04  
    },
    onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
        local pid = GetPlayerId(whichPlayer)

        local combatData = PlayerData.GetCombat(pid)
        if not combatData.physicalBonusPct then
            combatData.physicalBonusPc = 0 
        end


        local damagelevel = combatData.physicalBonusPc or 0
        local increaseValue = CTT.GetValue(whichPlayer, talentName, "increase")


        if newRank == 1 then
            combatData.physicalBonusPc = increaseValue
        elseif newRank == 2 then
            combatData.physicalBonusPc = damagelevel - (increaseValue / newRank) + increaseValue  
        elseif newRank == 3 then
            combatData.physicalBonusPc = damagelevel - (increaseValue / newRank) + increaseValue  
        end

        PlayerData.SetCombat(pid).physicalBonusPct = combatData.physicalBonusPc

    end
}) 

        --Starlight Pillar
        CTT.RegisterTalent({
            fourCC = 'Tslp',
            tree = "Lunar",
            column = 2,
            row = 2,
            requirement = "Lunar Blessing",
            values = {
                healthReg = 20,
                duration = 15
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                if newRank > 0 then
                    UnitAddAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "Apil")
                else
                    UnitRemoveAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "Apil")
                end
            end,
        })

        




        --Improved Starlight Pillar
        CTT.RegisterTalent({
            fourCC = 'Tisp',
            tree = "Lunar",
            column = 2,
            row = 3,
            maxPoints = 5,
            requirement = "Starlight Pillar",
            values = {
                increase = 0.1
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                local base = CTT.GetValue(whichPlayer, "Starlight Pillar", "healthReg")
                local duration = CTT.GetValue(whichPlayer, "Starlight Pillar", "duration")
                local increase = CTT.GetValue(whichPlayer, talentName, "increase")
                if GetLocalPlayer() == whichPlayer then
                    BlzSetAbilityExtendedTooltip(FourCC "Apil", "Creates a pillar of starlight at target location that heals a unit bathing in the light by " .. (math.tointeger(base*(1 + increase)) or base*(1 + increase)) .. " health per second. Lasts " .. duration .. " seconds.", 0)
                end
            end
        })

        --Starfall
        CTT.RegisterTalent({
            --Add name, tooltip, and icon without using an ability.
            name = "Starfall",
            tooltip = "While channeling, calls down waves of falling stars that damage nearby enemy units. Each wave deals !damage! damage. Lasts for !duration! seconds. !cooldown! seconds cooldown.",
            icon = "TalentIcons\\Starfall.blp",
            tree = "Lunar",
            column = 3,
            row = 3,
            --Retrieve values from the ability fields of the linked ability.
            ability = "AEsf",
            values = {
                damage = "Esf1",
                duration = "adur",
                cooldown = "acdn"
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                if newRank > 0 then
                    UnitAddAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "AEsf")
                else
                    UnitRemoveAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "AEsf")
                end
            end,
        })

        --Elune's Protection
        CTT.RegisterTalent({
            fourCC = 'Tfoc',
            tree = "Lunar",
            column = 4,
            row = 3,
            maxPoints = 3,
            requirement = "Starfall",
            values = {
                reduction = 0.3,
                duration = 5
            }
        })

        --Trueshot Aura
        CTT.RegisterTalent({
            name = "Trueshot Aura",
            tooltip = "An aura that gives friendly nearby units a !damage,\x25! bonus damage to their ranged attacks.",
            icon = "TalentIcons\\TrueshotAura.blp",
            tree = "Archery",
            column = 2,
            row = 1,
            maxPoints = 5,
            ability = "AEar",
            values = {
                damage = "Ear1"
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                if newRank == 1 then
                    UnitAddAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "AEar")
                elseif newRank > 1 then
                    SetUnitAbilityLevel(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "AEar", newRank)
                else
                    UnitRemoveAbility(PlayerData.Get(GetPlayerId(whichPlayer)), FourCC "AEar")
                end
            end,
        })

 
    end)
end
if Debug then Debug.endFile() end