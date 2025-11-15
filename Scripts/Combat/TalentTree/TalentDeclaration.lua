if Debug then Debug.beginFile "TalentDeclaration" end
do
    OnInit.global(function()
        --Lunar Blessing
        CTT.RegisterTalent({
            --Add name, tooltip, and icon from an ability.
            fourCC = 'Tlub',
            tree = "Lunar",
            column = 2,
            row = 1,
            maxPoints = 5,
            values = {
                manaReg = 0.2
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                if newRank > 0 then
                    UnitAddAbility(HeroOfPlayer[whichPlayer], FourCC "Alub")
                    SetUnitAbilityField(HeroOfPlayer[whichPlayer], "Alub", "Imrp", CTT.GetValue(whichPlayer, talentName, "manaReg"))
                else
                    UnitRemoveAbility(HeroOfPlayer[whichPlayer], FourCC "Alub")
                end
            end,
        })

        --Improved Scout
        CTT.RegisterTalent({
            fourCC = 'Towl',
            tree = "Lunar",
            column = 3,
            row = 1,
            maxPoints = 5,
            values = {
                duration = 5
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                local newDuration = math.tointeger(GetAbilityField("AEst", "adur") + CTT.GetValue(whichPlayer, talentName, "duration"))
                SetUnitAbilityField(HeroOfPlayer[whichPlayer], "AEst", "adur", newDuration)
                if GetLocalPlayer() == whichPlayer then
                    BlzSetAbilityExtendedTooltip(FourCC "AEst", "Summons an Owl Scout, which can be used to scout. Can see invisible units. Lasts " .. newDuration .. " seconds.", 0)
                end
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
                    UnitAddAbility(HeroOfPlayer[whichPlayer], FourCC "Apil")
                else
                    UnitRemoveAbility(HeroOfPlayer[whichPlayer], FourCC "Apil")
                end
            end,
        })

        --Starforce
        CTT.RegisterTalent({
            --Add name, tooltip, and icon without using an ability.
            name = "Starforce",
            tooltip = "Increases all spell damage you deal by !increase,\x25!.",
			prelearnTooltip = "Increases all duderized damage you deal by !increase,\x25!.",
            icon = "TalentIcons\\Starforce.blp",
            tree = "Lunar",
            column = 3,
            row = 2,
            maxPoints = 3,
            requirement = "Starlight Pillar",
            values = {
                increase = {0.04, 0.07, 0.1}
            },
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
                    UnitAddAbility(HeroOfPlayer[whichPlayer], FourCC "AEsf")
                else
                    UnitRemoveAbility(HeroOfPlayer[whichPlayer], FourCC "AEsf")
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
                    UnitAddAbility(HeroOfPlayer[whichPlayer], FourCC "AEar")
                elseif newRank > 1 then
                    SetUnitAbilityLevel(HeroOfPlayer[whichPlayer], FourCC "AEar", newRank)
                else
                    UnitRemoveAbility(HeroOfPlayer[whichPlayer], FourCC "AEar")
                end
            end,
        })

        --Tenacity
        CTT.RegisterTalent({
            fourCC = 'Tten',
            tree = "Survival",
            column = 2,
            row = 1,
            maxPoints = 5,
            values = {
                health = 25
            },
            onLearn = function(whichPlayer, talentName, parentTree, oldRank, newRank)
                if newRank > oldRank then
                    SetPlayerTechResearched(whichPlayer, FourCC "Rtnc", newRank)
                else
                    BlzDecPlayerTechResearched(whichPlayer, FourCC "Rtnc", oldRank - newRank)
                end
            end
        })
    end)
end
if Debug then Debug.endFile() end