if Debug then Debug.beginFile "TalentDeclaration" end
do
    OnInit.global(function()
        -- Spirit Vortex Talent
        CTT.RegisterTalent({
            fourCC = 'LST4',  -- Unique talent ID for the Lost Soul's Spirit Vortex
            tree = "Lost Soul",  -- Lost Soul Talent Tree
            column = 1,
            row = 3,  -- Place this below other talents
            maxPoints = 5,  -- Allow 5 points to be spent
            values = {
                additionalOrbs = 1,  -- Adds 1 orb per talent point
            },
            onLearn = function(pid, talentName, parentTree, oldRank, newRank)
                -- Update the Spirit Vortex ability to increase the number of orbs
                local currentOrbs = 2 + newRank * 1  -- Base 2 orbs + 1 orb per talent point
                -- Update Spirit Vortex ability to reflect the new orb count
                if _G.Spell_SpiritVortex and Spell_SpiritVortex.SetOrbCount then
                    Spell_SpiritVortex.SetOrbCount(pid, currentOrbs)
                end

                -- Display the change to the player
                DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex now has " .. tostring(currentOrbs) .. " orbs.")
            end,
        })

        -- Lost Soul Talent Tree (You can adjust the other talents accordingly)
        CTT.RegisterTalent({
            fourCC = 'LST1',  -- Unique talent ID for the Lost Soul talent
            tree = "Lost Soul",
            column = 1,
            row = 1,
            maxPoints = 1,
            values = {
                spiritBoost = 0.1  -- Increase Spirit Drive speed by 10%
            },
            onLearn = function(pid, talentName, parentTree, oldRank, newRank)
                -- Handle learning of the talent (for example, boosting Spirit Drive speed)
                if newRank > 0 then
                    DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Drive Boost Activated!")
                else
                    DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Drive Boost Removed!")
                end
            end,
        })

        -- Healing Boost Talent (Another example talent for Lost Soul)
        CTT.RegisterTalent({
            fourCC = 'LST2',
            tree = "Lost Soul",
            column = 2,
            row = 1,
            maxPoints = 1,
            values = {
                healingBoost = 0.15  -- Increase healing received by 15%
            },
            onLearn = function(pid, talentName, parentTree, oldRank, newRank)
                -- Apply healing boost when talent is learned
                if newRank > 0 then
                    DisplayTextToPlayer(Player(pid), 0, 0, "Healing Boost Activated!")
                else
                    DisplayTextToPlayer(Player(pid), 0, 0, "Healing Boost Removed!")
                end
            end,
        })

        -- You can continue to add more talents here as needed...

    end)
end
if Debug then Debug.endFile() end
