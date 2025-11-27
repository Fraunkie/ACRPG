if Debug then Debug.beginFile "TalentTree" end
do
    --[[
    =============================================================================================================================================================
                                                                    Classic Talent Trees
                                                                        by Antares
                                                                           v1.2

                                              A recreation of Clasic World of Warcraft class talent trees.

								Requires:
								TotalInitialization			    https://www.hiveworkshop.com/threads/total-initialization.317099/
                                Handle Type                     https://www.hiveworkshop.com/threads/get-handle-type.354436/
                                Easy Ability Fields (optional)  https://www.hiveworkshop.com/threads/easy-ability-fields.355859/

                                              For installation guide, tutorials & documentation, see here:
                                                    https://www.hiveworkshop.com/threads/.355929/

    =============================================================================================================================================================
                                                                           A P I
    =============================================================================================================================================================

        • The who parameter can be a player or a unit. Passing a unit is simply a shortcut and will reroute the function to the unit's owning player. Creating
          multiple sets of talent trees for different heroes controlled by the same player is not possible.
        • Each talent or talent tree is referenced exclusively by its name.


    CTT.RegisterTalent(data)                                Registers a talent from the data provided in the data table. The recognized fields for data table are
                                                            fourCC, name, icon, tooltip, tree, column, row, maxPoints, callback, requirement, and values.
                                                            For details, see hiveworkshop resource page.
    CTT.SetTrees(who, ...)                                  Sets the talent trees for the specified player to the provided list. The talent trees will be arranged
                                                            according to their order in the arguments.
    CTT.AddTrees(who, ...)                                  Adds the provided list of talent trees to the talents trees of the specified player. The talent trees
                                                            will be arranged according to their order in the arguments.
    CTT.GrantPoints(who, howMany?)                          Adds the specified amount, or 1 if not specified, to the player's unspent talent points.
    CTT.SetPoints(who, howMany)                             Sets the unspent talent points of the specified player to the provided amount.
    CTT.ForceSelectTalent(who, whichTalent, subtractCost?)  Selects the specified talent for a player. If the optional subtractCost argument is not set, the
                                                            player will not lose unspent talent points and all requirements of the talent will be ignored.
    CTT.ResetAllTalents(who)                                Resets all talents and refunds their cost for the specified player.
    CTT.GetUnspentPoints(who)                               Returns the amount of unspent talent points the specified player has.
    CTT.GetTalentRank(who, whichTalent)                     Returns the rank of the specified talent for a player.
    CTT.HasTalent(who, whichTalent)                         Returns whether a player has one or more talent points invested in the specified talent.
    CTT.IsTalentMaxed(who, whichTalent)                     Returns whether a player has invested the maximum number of points in the specified talent.
    CTT.DisableTalent(who, whichTalent, requirementText?)   Disables the specified talent for a player. The requirements text will be inserted on top of the tooltip
                                                            while it is disabled. If the optional overwriteRequirements flag is set, the text for other missing
                                                            requirements will be removed from the tooltip.
    CTT.EnableTalent(who, whichTalent)                      Enables for the specified player a talent which has been previously disabled with CTT.DisableTalent.
    CTT.GetPointsInTree(who, whichTree)                     Returns the number of talent points a player has invested into the specified talent tree.
    CTT.GetTotalPoints(who)                                 Returns the total number of talent points a player has distributed among talents. Does not include
                                                            unspent talent points.
    CTT.GetValue(who, whichTalent, whichValue)              Returns the value with the whichValue key in the values table stored for the specified talent at the
                                                            talent rank of a player.
    CTT.GetTooltip(who, whichTalent)                        Returns the tooltip for the specified talent at the talent rank of a player.
    CTT.GetTalentPosition(whichTalent)                      Returns the parent tree, the row, and the column of the specified talent.
    CTT.AffectedBy(object)                                  Returns a table containing all talents that affect the specified object. Object can be a fourCC code
                                                            or id.
    CTT.GetImageSizeRatio(width?, height?)                  Prints out the optimal image size ratio for the talent tree background images. You can specify either
                                                            width or height to get the other.
    CTT.Show(who?, enable?)                                 Opens the talent menu for the specified player, or for all players if no player is specified. Set the
                                                            optional enable parameter to false to instead force players to close the talent menu.
    CTT.IsOpened(who)                                       Returns whether the specified player has the talent tree opened.
    CTT.Compile(who)                                        Returns a table containing a sequence with the ranks of each talent for the specified player as well
                                                            as the number of unspent talent points as the last entry. Empty slots in the talent trees are included
                                                            as a 0.
    CTT.LoadBuild(who, data)                                Loads the specified player's talent build from the provided data table which has been generated with
                                                            the Compile function. Returns false if the load was not successful.
    CTT.ResetSavedBuild(who, data)                          Loads the talent build from the provided table and refunds all acquired talents for the specified
                                                            player. This function should be used if the talent build load from the Load function was not successful.

    =============================================================================================================================================================
                                                                        C O N F I G
    =============================================================================================================================================================
    ]]

    --Define talent trees by their name.
    local TALENT_TREES = {                        ---@constant string[]
        "Lunar",
        "Archery",
        "Survival",
	    "LostSoul",

    }

    --If enabled, the cost of talents is set by the GetTalentCost function. In addition, a cost indicator and symbol will appear in the talent tooltips. You need
    --to import an icon called "TalentPoints.blp".
    local VARIABLE_TALENT_COST                   = false

    --If enabled, the first talent row is at the bottom instead of the top.
    local TALENT_TREE_BOTTOM_TO_TOP              = true

    --Number of points required to be invested into a talent tree to unlock the next row of talents.
    local POINTS_IN_TREE_REQUIRED_PER_ROW        = 5
    --Number of points required to be invested into any talent to unlock the next row of talents for each tree.
    local POINTS_TOTAL_REQUIRED_PER_ROW          = 0
    --If enabled and VARIABLE_TALENT_COST is enabled, the above values refer to currency invested instead of talent points.
    local REQUIRE_CURRENCY_INSTEAD_OF_POINTS     = false

    --A function that is called whenever a player puts a point into any talent. Called with the arguments (whichPlayer, talentName, parentTree, oldRank, newRank).
    local GLOBAL_CALLBACK                        = nil

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the layout and the extents of the talent tree menu.

    --x-position of menu center.
    local TREE_MENU_X                            = 0.14
    local TREE_MENU_Y                            = 0.38

    local TREE_MENU_WIDTH                        = 0.28
    local TREE_MENU_HEIGHT                       = 0.395

    --x-Position of first talent column relative to left edge of menu.
    local TALENT_X_OFFSET                        = 0.043
    --y-Position of first talent row relative to top/bottom edge of menu.
    local TALENT_Y_OFFSET                        = 0.056

    local TALENT_VERTICAL_SPACING                = 0.0547
    local TALENT_HORIZONTAL_SPACING              = 0.0547
    local TALENT_BUTTON_SIZE                     = 0.03

    local NUMBER_OF_TALENT_ROWS                  = 6
    local NUMBER_OF_TALENT_COLUMNS               = 4

    local BACKGROUND_HORIZONTAL_INSET            = 0.02
    local BACKGROUND_VERTICAL_INSET              = -0.003

    local BLACK_FADE_CORNER_SIZE                 = 0.02

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the talent tooltips. Within these strings, you can use various auto-replacements.

    --This text appears when a requirement talent is not maxed out. Use !MAXPOINTS! for the maximum points of the requirement talent and !REQUIREMENT! for the
    --requirement talent's name.
    local REQUIREMENT_NOT_MET_TEXT               = "|cffff0000Requires !MAXPOINTS! point(s) in !REQUIREMENT!|r"

    --This text appears when not enough points are invested into the parent tree of the talent. Use !TREEPOINTS! for the required points in the tree and !TREE!
    --for the name of the tree.
    local NOT_ENOUGH_POINTS_IN_TREE_TEXT         = "|cffff0000Requires !TREEPOINTS! point(s) in !TREE! Talents|r"

    --This text appears when not enough points are invested into any talent. Use !TOTALPOINTS! to refer to the number of talent points required.
    local NOT_ENOUGH_POINTS_TOTAL_TEXT           = "|cffff0000Requires !TOTALPOINTS! Talents total|r"

    --The header of the talent tooltip.
    local TALENT_TITLE                           = "|cffaaaaaaTalent|r"

    --The header of the tooltip for the current rank of the talent. Use !POINTS! for the current rank, and !MAXPOINTS! for the maximum.
    local CURRENT_RANK_TEXT                      = "|cffaaaaffCurrent rank (!POINTS!/!MAXPOINTS!):|r"
    --The header of the tooltip for the next rank of the talent. Use !POINTS! for the next rank, and !MAXPOINTS! for the maximum.
    local NEXT_RANK_TEXT                         = "|cffaaaaffNext rank (!POINTS!/!MAXPOINTS!):|r"

    --The color of all auto-replacements from a talent's values table.
    local TOOLTIP_VALUE_COLOR                    = "|cffffcc00"

    --Increases the height of the tooltip relative to the height of the text box.
    local TALENT_TOOLTIP_HEIGHT_BUFFER           = 0.035

    --Define additional replacements that are automatically made in all tooltips. This table's entries define in pairs the strings that should be replaced and
    --strings to replace them with (string 1, replacement 1, string 2, replacement 2, ...).
    local REPLACEMENTS = {
        "Poisoned", "|cff00ff00Poisoned|r",
    }

    --If enabled, a list of all objects added with the affects flag is included at the bottom of each tooltip.
    local ADD_AFFECTED_OBJECTS_TO_TOOLTIP        = true
    local AFFECTS_HEADER                         = "|cffffcc00Affects:|r"
    local AFFECTED_ITEM_COLOR                    = "|cffaaaaaa"

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the rank indicators of the talent buttons.

    local RANK_INDICATOR_WIDTH                   = 0.024
    local RANK_INDICATOR_HEIGHT                  = 0.014
    local RANK_INDICATOR_HORIZONTAL_OVERLAP      = 0.014
    local RANK_INDICATOR_VERTICAL_OVERLAP        = 0.007
    local RANK_INDICATOR_FONT_SIZE               = 8

    --The color of the rank indicator when a talent cannot be picked.
    local UNAVAILABLE_COLOR                      = "|cffaaaaaa"
    --The color of the rank indicator when a talent can be picked.
    local AVAILABLE_COLOR                        = "|cff00ff00"
    --The color of the rank indicator when the talent is maxed.
    local MAXED_COLOR                            = "|cffffcc00"

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the size of the requirement arrows.

    local REQUIREMENT_ARROW_BUTTON_OVERLAP       = 0.004
    local REQUIREMENT_ARROW_WIDTH                = 0.008

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the text and layout of the top bar.

    local TOP_BAR_HEIGHT                         = 0.035
    local TOP_BAR_TEXT_VERTICAL_SHIFT            = 0.007

    --Relevant if the border of the bar isn't covered by the talent menu border.
    local TOP_BAR_HORIZONTAL_INSET               = 0.015
    local TOP_BAR_VERTICAL_SHIFT                 = -0.01

    local TOP_BAR_TEXT                           = "|cffffcc00Talents|r"
    local TOP_BAR_FONT_SIZE                      = 13

    local CLOSE_BUTTON_SIZE                      = 0.023
    local CLOSE_BUTTON_HORIZONTAL_SHIFT          = -0.001
    local CLOSE_BUTTON_VERTICAL_SHIFT            = -0.007
    local CLOSE_BUTTON_TEXTURE                   = "TalentMenuClose.blp"

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the text and layout of the bottom bar.

    local BOTTOM_BAR_HEIGHT                      = 0.029
    local BOTTOM_BAR_TEXT_VERTICAL_SHIFT         = -0.007
    --The distance between the left edge of the text box and the right edge of the menu.
    local BOTTOM_RIGHT_TEXT_HORIZONTAL_INSET     = 0.113
    --The distance between the left edge of the text box and the left edge of the menu.
    local BOTTOM_LEFT_TEXT_HORIZONTAL_INSET      = 0.023
    --Possible replacements are !TREE!, !UNSPENTPOINTS!, !TREEPOINTS!, !TREECURRENCY!, !TOTALPOINTS!, and !TOTALCURRENCY!.
    local BOTTOM_RIGHT_TEXT                      = "|cffffcc00Unspent Talents:|r !UNSPENTPOINTS!"
    local BOTTOM_LEFT_TEXT                       = "|cffffcc00!TREE! Talents:|r !TREEPOINTS!"

    --Relevant if the border of the bar isn't covered by the talent menu border.
    local BOTTOM_BAR_HORIZONTAL_INSET            = 0.015
    local BOTTOM_BAR_VERTICAL_SHIFT              = 0.01

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --These constants control the appearance and layout of the talent tree navigator buttons.

    local TREE_NAVIGATOR_WIDTH                   = 0.062
    local TREE_NAVIGATOR_HEIGHT                  = 0.028
    local TREE_NAVIGATOR_HORIZONTAL_SHIFT        = 0.016
    local TREE_NAVIGATOR_VERTICAL_SHIFT          = 0.017
    local TREE_NAVIGATOR_OVERLAP                 = 0.005
    local TREE_NAVIGATOR_SELECTED_SIZE_INCREASE  = 0.005

    local TREE_NAVIGATOR_FONT_SIZE               = 10
    local TREE_NAVIGATOR_SELECTED_COLOR          = "|cffffffff"
    local TREE_NAVIGATOR_UNSELECTED_COLOR        = "|cffaaaaaa"

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    --If you have VARIABLE_TALENT_COST enabled, use this function to determine the currency cost of a talent.

    ---@param talentName string
    ---@param maxPoints integer
    ---@param currentLevel integer
    ---@return integer
    local function GetTalentCost(talentName, maxPoints, currentLevel)
        if maxPoints == 1 then
            return 500
        else
            return 100
        end
    end

    --Set the icon paths for maxed and disabled versions of talent icons here.

    ---@param basePath string
    ---@return string
    local function GetTalentMaxedIconPath(basePath)
        return basePath .. "Maxed.blp"
    end

    ---@param basePath string
    ---@return string
    local function GetTalentDisabledIconPath(basePath)
        return basePath .. "Disabled.blp"
    end

    --[[
    =============================================================================================================================================================
                                                                E N D   O F   C O N F I G
    =============================================================================================================================================================
    ]]

    local BACKGROUND_INSET_BOTTOM       = BACKGROUND_VERTICAL_INSET + BOTTOM_BAR_HEIGHT + BOTTOM_BAR_VERTICAL_SHIFT
    local BACKGROUND_INSET_TOP          = BACKGROUND_VERTICAL_INSET + TOP_BAR_HEIGHT - TOP_BAR_VERTICAL_SHIFT

	local talentTreeParentFrame         = {}    ---@type framehandle[]

	local talentBackdrop                        ---@type framehandle
	local talentFrame                   = {}    ---@type framehandle[]
	local talentIconFrame               = {}    ---@type framehandle[]
	local talentIconClickedFrame        = {}    ---@type framehandle[]
	local talentIconDisabledFrame       = {}    ---@type framehandle[]
    local talentRankBoxFrame            = {}    ---@type framehandle[]
	local talentRankFrame               = {}    ---@type framehandle[]

    local treeNavigatorFrame            = {}    ---@type framehandle[]
    local treeNavigatorTitles           = {}    ---@type framehandle[]
    local treeNavigatorPosition         = {}    ---@type integer[]

    local talentTreePointsSpentText     = {}    ---@type framehandle[]
    local talentTreeUnspentPointsText   = {}    ---@type framehandle[]
    local treeFromNavigator             = {}    ---@type string[]

	local talentTooltipFrame            = {}    ---@type framehandle[]
	local talentTooltipTitleFrame       = {}    ---@type framehandle[]
	local talentTooltipTextFrame        = {}    ---@type framehandle[]
	local talentArrowHeadFrame          = {}    ---@type framehandle[][]
    local talentArrowBodyFrame          = {}    ---@type framehandle[][]
	local talentTooltipIconFrame        = {}    ---@type framehandle[]
	local talentTooltipCostFrame        = {}    ---@type framehandle[]

	local talentFromFrame               = {}    ---@type string[]
    local talentFromPosition            = {}    ---@type string[][][]
	local talentTooltip                 = {}    ---@type string[][]
	local talentIconPath                = {}    ---@type string[]
	local talentRequirement             = {}    ---@type string[][]
    local talentRequirementTexture      = {}    ---@type string[][]
	local talentSuccessors              = {}    ---@type string[][]
	local talentParentTree              = {}    ---@type string[]
	local talentColumn                  = {}    ---@type integer[]
	local talentRow                     = {}    ---@type integer[]
	local talentMaxPoints               = {}    ---@type integer[]
	local talentOnLearn                 = {}    ---@type function[]
	local talentValues                  = {}    ---@type number[][][] | string[][][] | boolean[][][]
    local talentAffects                 = {}    ---@type integer[][]
    local talentAbility                 = {}    ---@type integer[]

	local talentTrigger                         ---@type trigger

    local playerUnspentPoints           = {}    ---@type integer[]
    local playerTalentTrees             = {}    ---@type string[][]
    local playerPointsInTalent          = {}    ---@type integer[][]
    local playerPointsInTree            = {}    ---@type integer[][]
    local playerPointsTotal             = {}    ---@type integer[]
    local playerCurrencyInTree          = {}    ---@type integer[][]
    local playerCurrencyTotal           = {}    ---@type integer[]
    local currentTalentTree             = {}    ---@type string
    local playerRowsInTreeEnabled       = {}    ---@type integer[][]
    local playerTalentIsEnabled         = {}    ---@type boolean[][]
    local playerTalentIsHardDisabled    = {}    ---@type boolean[][]
    local playerTalentRequirementText   = {}    ---@type string[][]
    local playerTalentOverwriteText     = {}    ---@type boolean[][]

    local affectedByTalents             = {}    ---@type string[][]

    local localPlayer                           ---@type player
    local buttonPressSound                      ---@type sound
    local talentTreeOpen                = {}    ---@type boolean[]

    local talentTreesInitialized                ---@type boolean

    local GetOwner                              ---@type function

    local RECOGNIZED_FLAGS = {                  ---@constant table<string,boolean>
        fourCC = true,
        tree = true,
        column = true,
        row = true,
        name = true,
        tooltip = true,
        prelearnTooltip = true,
        icon = true,
        maxPoints = true,
        requirement = true,
        onLearn = true,
        onUnlearn = true,
        values = true,
        affects = true,
        ability = true
    }

    local REQUIRED_FLAGS = {                    ---@constant table<string,boolean>
        tree = true,
        column = true,
        row = true,
    }

    for __, tree in ipairs(TALENT_TREES) do
        TALENT_TREES[tree] = true
        talentFromPosition[tree] = {}
        for j = 1, NUMBER_OF_TALENT_COLUMNS do
            talentFromPosition[tree][j] = {}
        end
    end

    --===========================================================================================================================================================

    local function ToUpperCase(__, letter)
        return letter:upper()
    end

    local function ToPascalCase(whichString)
        whichString = whichString:gsub("|[cC]\x25x\x25x\x25x\x25x\x25x\x25x\x25x\x25x", "") --remove color codes
        whichString = whichString:gsub("|[rR]", "")                                         --remove closing color codes
        whichString = whichString:gsub("(\x25s)(\x25a)", ToUpperCase)                       --remove spaces and convert to upper case after space
        whichString = whichString:gsub("[^\x25w]", "")                                      --remove special characters
        return string.upper(whichString:sub(1,1)) .. string.sub(whichString,2)              --converts first character to upper case
    end

    local function PressCloseButton()
        if not BlzFrameIsVisible(talentBackdrop) then
            return
        end
        local player = GetTriggerPlayer()
        local pid = GetPlayerId(player)
        if localPlayer == player then
            StartSound(buttonPressSound)
        end
        CTT.Show(player, false)
        PlayerData.SetUIFocus(pid, false)
    end

    ---@param whichTalent string
    ---@param whichPlayer player
    ---@return boolean
    local function HasAllRequirements(whichTalent, whichPlayer)
        if talentRequirement[whichTalent] == nil then
            return true
        end

        for __, requirement in ipairs(talentRequirement[whichTalent]) do
            if playerPointsInTalent[whichPlayer][requirement] < talentMaxPoints[requirement] then
                return false
            end
        end
        return true
    end

    ---@param whichTalent string
    ---@param whichPlayer player
    ---@return boolean
    local function ShouldTalentBeEnabled(whichTalent, whichPlayer)
        if playerTalentIsHardDisabled[whichPlayer][whichTalent] then
            return false
        end
        if REQUIRE_CURRENCY_INSTEAD_OF_POINTS then
            return not playerTalentIsEnabled[whichPlayer][whichTalent]
            and HasAllRequirements(whichTalent, whichPlayer)
            and (talentRow[whichTalent] - 1)*POINTS_IN_TREE_REQUIRED_PER_ROW <= playerCurrencyInTree[whichPlayer][talentParentTree[whichTalent]]
            and (talentRow[whichTalent] - 1)*POINTS_TOTAL_REQUIRED_PER_ROW <= playerCurrencyTotal[whichPlayer]
        else
            return not playerTalentIsEnabled[whichPlayer][whichTalent]
            and HasAllRequirements(whichTalent, whichPlayer)
            and (talentRow[whichTalent] - 1)*POINTS_IN_TREE_REQUIRED_PER_ROW <= playerPointsInTree[whichPlayer][talentParentTree[whichTalent]]
            and (talentRow[whichTalent] - 1)*POINTS_TOTAL_REQUIRED_PER_ROW <= playerPointsTotal[whichPlayer]
        end
    end

    local function DisableTalent(whichTalent, whichPlayer)
        BlzFrameSetEnable(talentFrame[whichTalent], false)
        if playerUnspentPoints[whichPlayer] == 0 and playerPointsInTalent[whichPlayer][whichTalent] == 0 then
            BlzFrameSetVisible(talentRankBoxFrame[whichTalent], false)
            BlzFrameSetVisible(talentRankFrame[whichTalent], false)
            if talentRequirement[whichTalent] then
                for k = 1, #talentRequirement[whichTalent] do
                    if talentArrowHeadFrame[whichTalent][k] then
                        BlzFrameSetTexture(talentArrowHeadFrame[whichTalent][k], "TalentArrowHead" .. talentRequirementTexture[whichTalent][k] .. "Disabled.blp", 0, true)
                        BlzFrameSetTexture(talentArrowBodyFrame[whichTalent][k], "TalentArrowBody" .. talentRequirementTexture[whichTalent][k] .. "Disabled.blp", 0, true)
                    end
                end
            end
        elseif playerPointsInTalent[whichPlayer][whichTalent] < talentMaxPoints[whichTalent] then
            BlzFrameSetTexture(talentIconDisabledFrame[whichTalent], talentIconPath[whichTalent], 0, true)
        end
    end

    ---@param whichPlayer player
    local function DisableButtonsOnLastPointSpent(whichPlayer)
        if localPlayer == whichPlayer then
            for __, tree in ipairs(playerTalentTrees[whichPlayer]) do
                for i = 1, NUMBER_OF_TALENT_COLUMNS do
                    for j = 1, NUMBER_OF_TALENT_ROWS do
                        if talentFromPosition[tree][i][j] then
                            DisableTalent(talentFromPosition[tree][i][j], whichPlayer)
                        end
                    end
                end
            end
        end
    end

    ---@param whichPlayer player
    local function EnableButtonsOnFirstPointGained(whichPlayer)
        local talent

        if playerTalentTrees[whichPlayer] == nil then
            return
        end

        if localPlayer == whichPlayer then
            for __, tree in ipairs(playerTalentTrees[whichPlayer]) do
                for i = 1, NUMBER_OF_TALENT_COLUMNS do
                    for j = 1, NUMBER_OF_TALENT_ROWS do
                        talent = talentFromPosition[tree][i][j]
                        if talent then
                            if playerTalentIsEnabled[whichPlayer][talent] then
                                if playerPointsInTalent[whichPlayer][talent] == 0 then
                                    BlzFrameSetEnable(talentFrame[talent], true)
                                    BlzFrameSetVisible(talentRankBoxFrame[talent], true)
                                    BlzFrameSetVisible(talentRankFrame[talent], true)
                                elseif playerPointsInTalent[whichPlayer][talent] < talentMaxPoints[talent] then
                                    BlzFrameSetEnable(talentFrame[talent], true)
                                    BlzFrameSetTexture(talentIconDisabledFrame[talent], GetTalentDisabledIconPath(talentIconPath[talent]:gsub(".blp", "")), 0, true)
                                end
                                if talentRequirement[talent] then
                                    for index, requirement in ipairs(talentRequirement[talent]) do
                                        if talentArrowHeadFrame[talent][index] and playerPointsInTalent[whichPlayer][requirement] == talentMaxPoints[requirement] then
                                            BlzFrameSetTexture(talentArrowHeadFrame[talent][index], "TalentArrowHead" .. talentRequirementTexture[talent][index] .. ".blp", 0, true)
                                            BlzFrameSetTexture(talentArrowBodyFrame[talent][index], "TalentArrowBody" .. talentRequirementTexture[talent][index] .. ".blp", 0, true)
                                        end
                                    end
                                end
                            else
                                BlzFrameSetVisible(talentRankBoxFrame[talent], true)
                                BlzFrameSetVisible(talentRankFrame[talent], true)
                            end
                        end
                    end
                end
            end
        end
    end

    ---@param whichPlayer player
    ---@param whichTree string
    local function SetBottomBarText(whichPlayer, whichTree)
        if localPlayer == whichPlayer then
            BlzFrameSetText(talentTreePointsSpentText[whichTree]    , BOTTOM_LEFT_TEXT
                :gsub("!TREE!", whichTree)
                :gsub("!TREEPOINTS!", playerPointsInTree[whichPlayer][whichTree])
                :gsub("!TREECURRENCY!", playerCurrencyInTree[whichPlayer][whichTree])
                :gsub("!TOTALPOINTS!", playerPointsTotal[whichPlayer])
                :gsub("!TOTALCURRENCY!", playerCurrencyTotal[whichPlayer])
                :gsub("!UNSPENTPOINTS!", playerUnspentPoints[whichPlayer]))
            BlzFrameSetText(talentTreeUnspentPointsText[whichTree]  , BOTTOM_RIGHT_TEXT
                :gsub("!TREE!", whichTree)
                :gsub("!TREEPOINTS!", playerPointsInTree[whichPlayer][whichTree])
                :gsub("!TREECURRENCY!", playerCurrencyInTree[whichPlayer][whichTree])
                :gsub("!TOTALPOINTS!", playerPointsTotal[whichPlayer])
                :gsub("!TOTALCURRENCY!", playerCurrencyTotal[whichPlayer])
                :gsub("!UNSPENTPOINTS!", playerUnspentPoints[whichPlayer]))
        end
    end

    ---@param whichPlayer player
    ---@param whichTree string
    ---@param whichNavigator? framehandle
    local function SwitchToTree(whichPlayer, whichTree, whichNavigator)
        if localPlayer == whichPlayer then
            if whichNavigator then
                BlzFrameSetEnable(whichNavigator, false)
                BlzFrameSetEnable(whichNavigator, true)

                local oldTree = currentTalentTree[whichPlayer]
                if oldTree then
                    BlzFrameSetPoint(treeNavigatorFrame[oldTree], FRAMEPOINT_BOTTOMLEFT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + (treeNavigatorPosition[oldTree] - 1)*(TREE_NAVIGATOR_WIDTH - TREE_NAVIGATOR_OVERLAP), TREE_NAVIGATOR_VERTICAL_SHIFT - TREE_NAVIGATOR_HEIGHT)
                    BlzFrameSetPoint(treeNavigatorFrame[oldTree], FRAMEPOINT_TOPRIGHT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + treeNavigatorPosition[oldTree]*TREE_NAVIGATOR_WIDTH - (treeNavigatorPosition[oldTree] - 1)*TREE_NAVIGATOR_OVERLAP, TREE_NAVIGATOR_VERTICAL_SHIFT)
                    BlzFrameSetLevel(treeNavigatorFrame[oldTree], treeNavigatorPosition[oldTree] - 1)
                    BlzFrameSetText(treeNavigatorTitles[oldTree], TREE_NAVIGATOR_UNSELECTED_COLOR .. oldTree .. "|r")
                    BlzFrameSetScale(treeNavigatorTitles[oldTree], TREE_NAVIGATOR_FONT_SIZE/10)
                    BlzFrameSetVisible(talentTreeParentFrame[oldTree], false)
                    BlzFrameSetEnable(treeNavigatorFrame[oldTree], true)
                end

                BlzFrameSetPoint(treeNavigatorFrame[whichTree], FRAMEPOINT_BOTTOMLEFT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + (treeNavigatorPosition[whichTree] - 1)*(TREE_NAVIGATOR_WIDTH - TREE_NAVIGATOR_OVERLAP) - TREE_NAVIGATOR_SELECTED_SIZE_INCREASE, TREE_NAVIGATOR_VERTICAL_SHIFT - TREE_NAVIGATOR_HEIGHT - TREE_NAVIGATOR_SELECTED_SIZE_INCREASE)
                BlzFrameSetPoint(treeNavigatorFrame[whichTree], FRAMEPOINT_TOPRIGHT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + treeNavigatorPosition[whichTree]*TREE_NAVIGATOR_WIDTH - (treeNavigatorPosition[whichTree] -1)*TREE_NAVIGATOR_OVERLAP + TREE_NAVIGATOR_SELECTED_SIZE_INCREASE, TREE_NAVIGATOR_VERTICAL_SHIFT)
                BlzFrameSetLevel(treeNavigatorFrame[whichTree], treeNavigatorPosition[whichTree] + 1)
                BlzFrameSetText(treeNavigatorTitles[whichTree], TREE_NAVIGATOR_SELECTED_COLOR .. whichTree .. "|r")
                BlzFrameSetScale(treeNavigatorTitles[whichTree], (TREE_NAVIGATOR_FONT_SIZE/10)*(TREE_NAVIGATOR_WIDTH + 2*TREE_NAVIGATOR_SELECTED_SIZE_INCREASE)/TREE_NAVIGATOR_WIDTH)
                if oldTree then
                    BlzFrameSetVisible(talentTreeParentFrame[whichTree], true)
                end
                BlzFrameSetEnable(treeNavigatorFrame[whichTree], false)
            end

            SetBottomBarText(whichPlayer, whichTree)
            currentTalentTree[whichPlayer] = whichTree
        end
    end

    local function OnNavigatorClick()
        local whichPlayer = GetTriggerPlayer()
        local whichNavigator = BlzGetTriggerFrame()
        local whichTree = treeFromNavigator[whichNavigator]

        SwitchToTree(whichPlayer, whichTree, whichNavigator)
    end

	---@param whichTalent string
    ---@param whichPlayer player
	local function EnableTalent(whichTalent, whichPlayer)
        playerTalentIsEnabled[whichPlayer][whichTalent] = true

        if localPlayer == whichPlayer then
            if playerPointsInTalent[whichPlayer][whichTalent] < talentMaxPoints[whichTalent] then
                BlzFrameSetEnable(talentFrame[whichTalent], true)
                BlzFrameSetText(talentRankFrame[whichTalent], AVAILABLE_COLOR .. playerPointsInTalent[whichPlayer][whichTalent] .. "/" .. talentMaxPoints[whichTalent])
            end

            if talentArrowHeadFrame[whichTalent] then
                for index, __ in ipairs(talentRequirement[whichTalent]) do
                    BlzFrameSetTexture(talentArrowHeadFrame[whichTalent][index], "TalentArrowHead" .. talentRequirementTexture[whichTalent][index] .. ".blp", 0, true)
                    BlzFrameSetTexture(talentArrowBodyFrame[whichTalent][index], "TalentArrowBody" .. talentRequirementTexture[whichTalent][index] .. ".blp", 0, true)
                end
            end
        end

        if talentSuccessors[whichTalent] then
            for __, successor in ipairs(talentSuccessors[whichTalent]) do
                if ShouldTalentBeEnabled(successor, whichPlayer) then
                    EnableTalent(successor, whichPlayer)
                end
            end
        end
	end

    ---@param whichPlayer player
    ---@param whichTalent string
    ---@return string
    local function GetRequirementsText(whichPlayer, whichTalent)
        local text = ""
        local whichTree = talentParentTree[whichTalent]

        if talentRequirement[whichTalent] then
            for __, requirement in ipairs(talentRequirement[whichTalent]) do
                if requirement and playerPointsInTalent[whichPlayer][requirement] < talentMaxPoints[requirement] then
                    text = text .. REQUIREMENT_NOT_MET_TEXT:gsub("!REQUIREMENT!", requirement):gsub("!MAXPOINTS!", talentMaxPoints[requirement]):gsub("\x25(s\x25)", talentMaxPoints[requirement] > 1 and "s" or "") .. "|n"
                end
            end
        end

        local pointsRequired = (talentRow[whichTalent] - 1)*POINTS_IN_TREE_REQUIRED_PER_ROW
        if (REQUIRE_CURRENCY_INSTEAD_OF_POINTS and pointsRequired > playerCurrencyInTree[whichPlayer][whichTree]) or (not REQUIRE_CURRENCY_INSTEAD_OF_POINTS and pointsRequired > playerPointsInTree[whichPlayer][whichTree]) then
            text = text .. NOT_ENOUGH_POINTS_IN_TREE_TEXT:gsub("!TREEPOINTS!", pointsRequired):gsub("!TREE!", whichTree):gsub("\x25(s\x25)", pointsRequired > 1 and "s" or "") .. "|n"
        end

        pointsRequired = (talentRow[whichTalent] - 1)*POINTS_TOTAL_REQUIRED_PER_ROW
        if (REQUIRE_CURRENCY_INSTEAD_OF_POINTS and pointsRequired > playerCurrencyTotal[whichPlayer]) or (not REQUIRE_CURRENCY_INSTEAD_OF_POINTS and pointsRequired > playerPointsTotal[whichPlayer]) then
            text = text .. NOT_ENOUGH_POINTS_TOTAL_TEXT:gsub("!TOTALPOINTS!", pointsRequired):gsub("\x25(s\x25)", pointsRequired > 1 and "s" or "") .. "|n"
        end
        return text
    end

    local function GetAffectsText(whichTalent)
        if not ADD_AFFECTED_OBJECTS_TO_TOOLTIP then
            return ""
        end

        if talentAffects[whichTalent] then
            local text = "|n|n" .. AFFECTS_HEADER
            for __, value in ipairs(talentAffects[whichTalent]) do
                text = text .. "|n" .. AFFECTED_ITEM_COLOR .. GetObjectName(value) .. "|r"
            end
            return text
        else
            return ""
        end
    end

    ---@param whichPlayer player
    ---@param whichTalent string
    ---@return string
	local function GetTalentTooltip(whichPlayer, whichTalent)
        local currentLevel = playerPointsInTalent[whichPlayer][whichTalent]
        local maxPoints = talentMaxPoints[whichTalent]
        local requirementsText = playerTalentRequirementText[whichPlayer][whichTalent]
        local overwrite = playerTalentOverwriteText[whichPlayer][whichTalent]

        if talentTooltip[whichTalent][0] and currentLevel == 0 then
            return ((requirementsText and requirementsText .. "|n" .. (overwrite and "" or GetRequirementsText(whichPlayer, whichTalent))) or GetRequirementsText(whichPlayer, whichTalent)) .. TALENT_TITLE:gsub("!TREE!", talentParentTree[whichTalent]) .. "|n" .. NEXT_RANK_TEXT:gsub("!POINTS!", 1):gsub("!MAXPOINTS!", maxPoints) .. "|n" .. talentTooltip[whichTalent][0] .. GetAffectsText(whichTalent)
        elseif maxPoints == 1 then
			return ((requirementsText and requirementsText .. "|n" .. (overwrite and "" or GetRequirementsText(whichPlayer, whichTalent))) or GetRequirementsText(whichPlayer, whichTalent)) .. TALENT_TITLE:gsub("!TREE!", talentParentTree[whichTalent]) .. "|n" .. talentTooltip[whichTalent][1] .. GetAffectsText(whichTalent)
		elseif currentLevel == maxPoints then
			return ((requirementsText and requirementsText .. "|n" .. (overwrite and "" or GetRequirementsText(whichPlayer, whichTalent))) or GetRequirementsText(whichPlayer, whichTalent)) .. TALENT_TITLE:gsub("!TREE!", talentParentTree[whichTalent]) .. "|n" .. CURRENT_RANK_TEXT:gsub("!POINTS!", currentLevel):gsub("!MAXPOINTS!", maxPoints) .. "|n" .. talentTooltip[whichTalent][maxPoints] .. GetAffectsText(whichTalent)
		elseif currentLevel == 0 then
			return ((requirementsText and requirementsText .. "|n" .. (overwrite and "" or GetRequirementsText(whichPlayer, whichTalent))) or GetRequirementsText(whichPlayer, whichTalent)) .. TALENT_TITLE:gsub("!TREE!", talentParentTree[whichTalent]) .. "|n" .. NEXT_RANK_TEXT:gsub("!POINTS!", 1):gsub("!MAXPOINTS!", maxPoints) .. "|n" .. talentTooltip[whichTalent][1] .. GetAffectsText(whichTalent)
		else
			return ((requirementsText and requirementsText .. "|n" .. (overwrite and "" or GetRequirementsText(whichPlayer, whichTalent))) or GetRequirementsText(whichPlayer, whichTalent)) .. TALENT_TITLE:gsub("!TREE!", talentParentTree[whichTalent]) .. "|n" .. CURRENT_RANK_TEXT:gsub("!POINTS!", currentLevel):gsub("!MAXPOINTS!", maxPoints) .. "|n"  .. talentTooltip[whichTalent][currentLevel] .. "|n|n" .. NEXT_RANK_TEXT:gsub("!POINTS!", currentLevel + 1):gsub("!MAXPOINTS!", maxPoints) .. "|n"  .. talentTooltip[whichTalent][currentLevel + 1] .. GetAffectsText(whichTalent)
		end
	end

    ---@param whichPlayer player
    ---@param whichTalent string
    local function SetTalentTooltip(whichPlayer, whichTalent)
        if localPlayer == whichPlayer then
            BlzFrameSetText(talentTooltipTextFrame[whichTalent], GetTalentTooltip(whichPlayer, whichTalent))
            BlzFrameSetSize(talentTooltipTextFrame[whichTalent], 0.28, 0.0)
            BlzFrameSetSize(talentTooltipFrame[whichTalent], 0.29, BlzFrameGetHeight(talentTooltipTextFrame[whichTalent]) + TALENT_TOOLTIP_HEIGHT_BUFFER)
        end
    end

    ---@param whichPlayer player
    ---@param whichTalent string
    local function ResetTalent(whichPlayer, whichTalent)
        if localPlayer == whichPlayer then
            BlzFrameSetEnable(talentFrame[whichTalent], false)
            BlzFrameSetTexture(talentIconDisabledFrame[whichTalent], GetTalentDisabledIconPath(talentIconPath[whichTalent]:gsub(".blp", "")), 0, true)
            BlzFrameSetVisible(talentRankBoxFrame[whichTalent], true)
            BlzFrameSetVisible(talentRankFrame[whichTalent], true)
            BlzFrameSetText(talentRankFrame[whichTalent], UNAVAILABLE_COLOR .. "0/" .. talentMaxPoints[whichTalent] .. "|r")
            if VARIABLE_TALENT_COST then
                BlzFrameSetVisible(talentTooltipIconFrame[whichTalent], true)
                BlzFrameSetVisible(talentTooltipCostFrame[whichTalent], true)
            end
            if talentArrowHeadFrame[whichTalent] then
                for i = 1, #talentRequirement[whichTalent] do
                    if talentArrowHeadFrame[whichTalent][i] then
                        BlzFrameSetTexture(talentArrowHeadFrame[whichTalent][i], "TalentArrowHead" .. talentRequirementTexture[whichTalent][i] .. "Disabled.blp", 0, true)
                        BlzFrameSetTexture(talentArrowBodyFrame[whichTalent][i], "TalentArrowBody" .. talentRequirementTexture[whichTalent][i] .. "Disabled.blp", 0, true)
                    end
                end
            end
        end

        SetTalentTooltip(whichPlayer, whichTalent)
    end

    ---@param whichPlayer player
    ---@param whichTree string
    ---@param whichRow integer
    local function EnableRow(whichPlayer, whichTree, whichRow)
        local talent
        for i = 1, NUMBER_OF_TALENT_COLUMNS do
            talent = talentFromPosition[whichTree][i][whichRow]
            if talent then
                SetTalentTooltip(whichPlayer, talent)
                if ShouldTalentBeEnabled(talent, whichPlayer) then
                    EnableTalent(talent, whichPlayer)
                end
            end
        end
    end

    ---@param whichPlayer player
    local function CheckRowsForEnabledTalents(whichPlayer)
        for __, tree in ipairs(playerTalentTrees[whichPlayer]) do
            if REQUIRE_CURRENCY_INSTEAD_OF_POINTS then
                while playerCurrencyInTree[whichPlayer][tree] >= playerRowsInTreeEnabled[whichPlayer][tree]*POINTS_IN_TREE_REQUIRED_PER_ROW and playerCurrencyTotal[whichPlayer] >= playerRowsInTreeEnabled[whichPlayer][tree]*POINTS_TOTAL_REQUIRED_PER_ROW do
                    playerRowsInTreeEnabled[whichPlayer][tree] = playerRowsInTreeEnabled[whichPlayer][tree] + 1
                    EnableRow(whichPlayer, tree, playerRowsInTreeEnabled[whichPlayer][tree])
                end
            else
                while playerPointsInTree[whichPlayer][tree] >= playerRowsInTreeEnabled[whichPlayer][tree]*POINTS_IN_TREE_REQUIRED_PER_ROW and playerPointsTotal[whichPlayer] >= playerRowsInTreeEnabled[whichPlayer][tree]*POINTS_TOTAL_REQUIRED_PER_ROW do
                    playerRowsInTreeEnabled[whichPlayer][tree] = playerRowsInTreeEnabled[whichPlayer][tree] + 1
                    EnableRow(whichPlayer, tree, playerRowsInTreeEnabled[whichPlayer][tree])
                end
            end
        end
    end

    ---@param whichPlayer player
    ---@param whichTalent string
	local function SelectTalent(whichPlayer, whichTalent)
        if playerPointsInTalent[whichPlayer][whichTalent] == talentMaxPoints[whichTalent] then
            return
        end

        local whichTree = talentParentTree[whichTalent]

        if REQUIRE_CURRENCY_INSTEAD_OF_POINTS then
            local cost = GetTalentCost(whichTalent, talentMaxPoints[whichTalent], playerPointsInTalent[whichPlayer][whichTalent])
            playerCurrencyInTree[whichPlayer][whichTree] = playerCurrencyInTree[whichPlayer][whichTree] + cost
            playerCurrencyTotal[whichPlayer] = playerCurrencyTotal[whichPlayer]
        end
		playerPointsInTalent[whichPlayer][whichTalent] = playerPointsInTalent[whichPlayer][whichTalent] + 1
        playerPointsInTree[whichPlayer][whichTree] = playerPointsInTree[whichPlayer][whichTree] + 1
        playerPointsTotal[whichPlayer] = playerPointsTotal[whichPlayer] + 1

		if talentOnLearn[whichTalent] then
			talentOnLearn[whichTalent](whichPlayer, whichTalent, whichTree, playerPointsInTalent[whichPlayer][whichTalent] - 1, playerPointsInTalent[whichPlayer][whichTalent])
		end

        if GLOBAL_CALLBACK then
            GLOBAL_CALLBACK(whichPlayer, whichTalent, whichTree, playerPointsInTalent[whichPlayer][whichTalent] - 1, playerPointsInTalent[whichPlayer][whichTalent])
        end

        if playerPointsInTalent[whichPlayer][whichTalent] == talentMaxPoints[whichTalent] then
            if localPlayer == whichPlayer then
                BlzFrameSetEnable(talentFrame[whichTalent], false)
                BlzFrameSetTexture(talentIconDisabledFrame[whichTalent], GetTalentMaxedIconPath(talentIconPath[whichTalent]:gsub(".blp", "")), 0, true)
                BlzFrameSetText(talentRankFrame[whichTalent], MAXED_COLOR .. talentMaxPoints[whichTalent] .. "/" .. talentMaxPoints[whichTalent] .. "|r")
                BlzFrameSetVisible(talentTooltipIconFrame[whichTalent], false)
                BlzFrameSetVisible(talentTooltipCostFrame[whichTalent], false)
            end
            if talentSuccessors[whichTalent] then
                for __, successor in ipairs(talentSuccessors[whichTalent]) do
                    SetTalentTooltip(whichPlayer, successor)
                    if ShouldTalentBeEnabled(successor, whichPlayer) then
                        EnableTalent(successor, whichPlayer)
                    end
                end
            end
        else
            if localPlayer == whichPlayer then
                BlzFrameSetText(talentRankFrame[whichTalent], AVAILABLE_COLOR .. playerPointsInTalent[whichPlayer][whichTalent] .. "/" .. talentMaxPoints[whichTalent] .. "|r")
                if VARIABLE_TALENT_COST then
                    BlzFrameSetText(talentTooltipCostFrame[whichTalent], tostring(GetTalentCost(whichTalent, talentMaxPoints[whichTalent], playerPointsInTalent[whichPlayer][whichTalent])))
                end
            end
        end

        SetTalentTooltip(whichPlayer, whichTalent)

        SetBottomBarText(whichPlayer, whichTree)

        CheckRowsForEnabledTalents(whichPlayer)

        if not VARIABLE_TALENT_COST and playerUnspentPoints[whichPlayer] == 0 then
            DisableButtonsOnLastPointSpent(whichPlayer)
        end
	end

    local function TalentOnClick()
        local whichFrame = BlzGetTriggerFrame()
		local whichTalent = talentFromFrame[whichFrame]
		local whichPlayer = GetTriggerPlayer()

        if localPlayer == whichPlayer then
            BlzFrameSetEnable(whichFrame, false)
        end
        if not playerTalentIsEnabled[whichPlayer][whichTalent] then
            return
        end
        if localPlayer == whichPlayer then
            BlzFrameSetEnable(whichFrame, true)
        end

        local cost = VARIABLE_TALENT_COST and GetTalentCost(whichTalent, talentMaxPoints[whichTalent], playerPointsInTalent[whichPlayer][whichTalent]) or 1

		if playerUnspentPoints[whichPlayer] < cost then
			return
		else
			playerUnspentPoints[whichPlayer] = playerUnspentPoints[whichPlayer] - cost
		end

        SelectTalent(whichPlayer, whichTalent)
    end

    --===========================================================================================================================================================
    --Init
    --===========================================================================================================================================================

    ---Returns textureType, anchorFramepoint, dxBottomLeftHead, dyBottomLeftHead, dxTopRightHead, dyTopRightHead, dxBottomLeftBody, dyBottomLeftBody, dxTopRightBody, dyTopRightBody
    ---@param whichTalent string
    ---@param requirement string
    ---@return string|nil, framepointtype|nil, number|nil, number|nil, number|nil, number|nil, number | nil, number|nil, number|nil, number|nil
    local function GetArrowFrameParameters(whichTalent, requirement)
        if talentRow[whichTalent] == talentRow[requirement] then
            if talentColumn[whichTalent] == talentColumn[requirement] - 1 then
                return "Left", FRAMEPOINT_BOTTOMRIGHT,
                -REQUIREMENT_ARROW_BUTTON_OVERLAP, TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2,
                -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH, TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2,
                -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH, TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2,
                TALENT_HORIZONTAL_SPACING - TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2
            elseif talentColumn[whichTalent] == talentColumn[requirement] + 1 then
                return "Right", FRAMEPOINT_BOTTOMLEFT,
                REQUIREMENT_ARROW_BUTTON_OVERLAP - REQUIREMENT_ARROW_WIDTH, TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2,
                REQUIREMENT_ARROW_BUTTON_OVERLAP, TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2,
                -TALENT_HORIZONTAL_SPACING + TALENT_BUTTON_SIZE, TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2,
                REQUIREMENT_ARROW_BUTTON_OVERLAP - REQUIREMENT_ARROW_WIDTH, TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2
            end
        elseif talentColumn[whichTalent] == talentColumn[requirement] then
            if TALENT_TREE_BOTTOM_TO_TOP then
                if talentRow[whichTalent] == talentRow[requirement] + 1 then
                    return "Up", FRAMEPOINT_BOTTOMLEFT,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP - REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -TALENT_VERTICAL_SPACING + TALENT_BUTTON_SIZE,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP - REQUIREMENT_ARROW_WIDTH
                elseif talentRow[whichTalent] == talentRow[requirement] + 2 then
                    return "Up", FRAMEPOINT_BOTTOMLEFT,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP - REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -2*TALENT_VERTICAL_SPACING + TALENT_BUTTON_SIZE - REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, REQUIREMENT_ARROW_BUTTON_OVERLAP
                end
            else
                if talentRow[whichTalent] == talentRow[requirement] + 1 then
                    return "Down", FRAMEPOINT_TOPLEFT,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, TALENT_VERTICAL_SPACING - TALENT_BUTTON_SIZE
                elseif talentRow[whichTalent] == talentRow[requirement] + 2 then
                    return "Down", FRAMEPOINT_TOPLEFT,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 - REQUIREMENT_ARROW_WIDTH/2, -REQUIREMENT_ARROW_BUTTON_OVERLAP + REQUIREMENT_ARROW_WIDTH,
                    TALENT_BUTTON_SIZE/2 + REQUIREMENT_ARROW_WIDTH/2, 2*TALENT_VERTICAL_SPACING - TALENT_BUTTON_SIZE
                end
            end
        end
    end

	---@param whichTree string
	local function AddTalentsToTree(whichTree)
		local parent = talentTreeParentFrame[whichTree]

		for i = 1, NUMBER_OF_TALENT_COLUMNS do
			for j = 1, NUMBER_OF_TALENT_ROWS do
				local whichTalent = talentFromPosition[whichTree][i][j]
				if whichTalent ~= nil then
					local x, y
                    x = TALENT_X_OFFSET + TALENT_HORIZONTAL_SPACING*(i-1)
                    if TALENT_TREE_BOTTOM_TO_TOP then
                        y = TALENT_Y_OFFSET + TALENT_VERTICAL_SPACING*(j-1)
                    else
                        y = TREE_MENU_HEIGHT - TALENT_BUTTON_SIZE - TALENT_Y_OFFSET - TALENT_VERTICAL_SPACING*(j-1)
                    end

					talentFrame[whichTalent] = BlzCreateFrame("TalentButton", parent, 0, 0)
					BlzFrameSetPoint( talentFrame[whichTalent], FRAMEPOINT_BOTTOMLEFT, parent, FRAMEPOINT_BOTTOMLEFT, x, y)
					BlzFrameSetPoint( talentFrame[whichTalent], FRAMEPOINT_TOPRIGHT, parent, FRAMEPOINT_BOTTOMLEFT, x + TALENT_BUTTON_SIZE, y + TALENT_BUTTON_SIZE)
					BlzTriggerRegisterFrameEvent( talentTrigger, talentFrame[whichTalent], FRAMEEVENT_CONTROL_CLICK)
                    BlzFrameSetLevel(talentFrame[whichTalent], talentColumn[whichTalent])

					talentFromFrame[talentFrame[whichTalent]] = whichTalent

					talentIconFrame[whichTalent] = BlzFrameGetChild(talentFrame[whichTalent], 0)
					talentIconClickedFrame[whichTalent] = BlzFrameGetChild(talentFrame[whichTalent], 1)
					talentIconDisabledFrame[whichTalent] = BlzFrameGetChild(talentFrame[whichTalent], 2)

					BlzFrameClearAllPoints(talentIconClickedFrame[whichTalent])
					BlzFrameSetPoint(talentIconClickedFrame[whichTalent], FRAMEPOINT_BOTTOMLEFT, talentFrame[whichTalent], FRAMEPOINT_BOTTOMLEFT, 0.001, 0.001)
					BlzFrameSetPoint(talentIconClickedFrame[whichTalent], FRAMEPOINT_TOPRIGHT, talentFrame[whichTalent], FRAMEPOINT_TOPRIGHT, -0.001, -0.001)

					BlzFrameSetTexture(talentIconFrame[whichTalent], talentIconPath[whichTalent], 0, true)
					BlzFrameSetTexture(talentIconClickedFrame[whichTalent], talentIconPath[whichTalent], 0, true)
					BlzFrameSetTexture(talentIconDisabledFrame[whichTalent], GetTalentDisabledIconPath(talentIconPath[whichTalent]:gsub(".blp", "")), 0, true)

					talentTooltipFrame[whichTalent] = BlzCreateFrame("TalentTooltip", talentFrame[whichTalent], 0, 0)
					BlzFrameSetAbsPoint(talentTooltipFrame[whichTalent], FRAMEPOINT_BOTTOMLEFT, math.min(TREE_MENU_X - TREE_MENU_WIDTH/2 + x + TALENT_BUTTON_SIZE, 0.51), TREE_MENU_Y - TREE_MENU_HEIGHT/2 + y + TALENT_BUTTON_SIZE)
					BlzFrameSetTooltip(talentFrame[whichTalent], talentTooltipFrame[whichTalent])
					BlzFrameSetSize( talentTooltipFrame[whichTalent], 0.29, 0.0)

					talentTooltipTitleFrame[whichTalent] = BlzFrameGetChild(talentTooltipFrame[whichTalent], 0)
					talentTooltipTextFrame[whichTalent] = BlzFrameGetChild(talentTooltipFrame[whichTalent], 1)
					talentTooltipIconFrame[whichTalent] = BlzFrameGetChild(talentTooltipFrame[whichTalent], 2)
					talentTooltipCostFrame[whichTalent] = BlzFrameGetChild(talentTooltipFrame[whichTalent], 3)

					BlzFrameSetText(talentTooltipTitleFrame[whichTalent], whichTalent)
                    SetTalentTooltip(localPlayer, whichTalent)

					BlzFrameSetSize(talentTooltipTextFrame[whichTalent], 0.28, 0.0)
					BlzFrameSetSize(talentTooltipFrame[whichTalent], 0.29, BlzFrameGetHeight(talentTooltipTextFrame[whichTalent]) + TALENT_TOOLTIP_HEIGHT_BUFFER)

                    talentRankBoxFrame[whichTalent] = BlzFrameGetChild(talentFrame[whichTalent], 3)
                    BlzFrameSetPoint(talentRankBoxFrame[whichTalent], FRAMEPOINT_BOTTOMLEFT, talentFrame[whichTalent], FRAMEPOINT_BOTTOMRIGHT, -RANK_INDICATOR_HORIZONTAL_OVERLAP, RANK_INDICATOR_VERTICAL_OVERLAP - RANK_INDICATOR_HEIGHT)
                    BlzFrameSetPoint(talentRankBoxFrame[whichTalent], FRAMEPOINT_TOPRIGHT, talentFrame[whichTalent], FRAMEPOINT_BOTTOMRIGHT, -RANK_INDICATOR_HORIZONTAL_OVERLAP + RANK_INDICATOR_WIDTH, RANK_INDICATOR_VERTICAL_OVERLAP)

					talentRankFrame[whichTalent] = BlzFrameGetChild(talentFrame[whichTalent], 4)
					BlzFrameSetTextAlignment(talentRankFrame[whichTalent], TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
                    BlzFrameSetAllPoints(talentRankFrame[whichTalent], talentRankBoxFrame[whichTalent])
                    BlzFrameSetScale(talentRankFrame[whichTalent], RANK_INDICATOR_FONT_SIZE/10)

                    local whichPlayer
                    for p = 0, 23 do
                        whichPlayer = Player(p)
                        if ShouldTalentBeEnabled(whichTalent, whichPlayer) then
                            BlzFrameSetText(talentRankFrame[whichTalent], AVAILABLE_COLOR .. "0/" .. talentMaxPoints[whichTalent] .. "|r")
                            playerTalentIsEnabled[whichPlayer][whichTalent] = true
                        else
                            BlzFrameSetText(talentRankFrame[whichTalent], UNAVAILABLE_COLOR .. "0/" .. talentMaxPoints[whichTalent] .. "|r")
                            BlzFrameSetEnable(talentFrame[whichTalent], false)
                        end
                    end

                    if VARIABLE_TALENT_COST then
					    BlzFrameSetTextAlignment(talentTooltipCostFrame[whichTalent], TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_RIGHT)
					    BlzFrameSetText(talentTooltipCostFrame[whichTalent], tostring(GetTalentCost(whichTalent, talentMaxPoints[whichTalent], 0)))
                    else
                        BlzFrameSetVisible(talentTooltipCostFrame[whichTalent], false)
                        BlzFrameSetVisible(talentTooltipIconFrame[whichTalent], false)
                    end

                    if talentRequirement[whichTalent] then
                        talentArrowHeadFrame[whichTalent] = {}
                        talentArrowBodyFrame[whichTalent] = {}
                        talentRequirementTexture[whichTalent] = {}
                        for index, requirement in ipairs(talentRequirement[whichTalent]) do
                            local texture, framepoint, x1h, y1h, x2h, y2h, x1b, y1b, x2b, y2b = GetArrowFrameParameters(whichTalent, requirement)
                            if texture then
                                talentRequirementTexture[whichTalent][index] = texture

                                talentArrowHeadFrame[whichTalent][index] = BlzCreateFrameByType("BACKDROP", "talentArrowHeadFrame", talentFrame[whichTalent], "", 0)
                                BlzFrameSetTexture(talentArrowHeadFrame[whichTalent][index], "TalentArrowHead" .. texture .. "Disabled.blp", 0, true)
                                BlzFrameSetPoint(talentArrowHeadFrame[whichTalent][index], FRAMEPOINT_BOTTOMLEFT, talentFrame[whichTalent], framepoint, x1h, y1h)
                                BlzFrameSetPoint(talentArrowHeadFrame[whichTalent][index], FRAMEPOINT_TOPRIGHT, talentFrame[whichTalent], framepoint, x2h, y2h)
                                BlzFrameSetEnable(talentArrowHeadFrame[whichTalent][index], false)

                                talentArrowBodyFrame[whichTalent][index] = BlzCreateFrameByType("BACKDROP", "talentArrowBodyFrame", talentFrame[whichTalent], "", 0)
                                BlzFrameSetTexture(talentArrowBodyFrame[whichTalent][index], "TalentArrowBody" .. texture .. "Disabled.blp", 0, true)
                                BlzFrameSetPoint(talentArrowBodyFrame[whichTalent][index], FRAMEPOINT_BOTTOMLEFT, talentFrame[whichTalent], framepoint, x1b, y1b)
                                BlzFrameSetPoint(talentArrowBodyFrame[whichTalent][index], FRAMEPOINT_TOPRIGHT, talentFrame[whichTalent], framepoint, x2b, y2b)
                                BlzFrameSetEnable(talentArrowBodyFrame[whichTalent][index], false)
                            end
                        end
                    end
				end
			end
		end
	end

	---@param whichString string
	---@return string
	local function ReplaceTooltipStrings(whichString)
		for i = 1, #REPLACEMENTS, 2 do
			whichString = whichString:gsub(REPLACEMENTS[i], REPLACEMENTS[i+1])
		end
		return whichString
	end

	---@param data table
	local function CreateTalent(data)
        local tree = data.tree
        local column = data.column
        local row = data.row
        local requirement = data.requirement
        local learnCallback = data.onLearn
        local maxPoints = data.maxPoints or 1
        local values = data.values
        local fourCC = data.fourCC
        local name = data.name
        local rawTooltip = data.tooltip
        local prelearnTooltip = data.prelearnTooltip
        local icon = data.icon
        local affects = data.affects
        local ability = data.ability

        if fourCC then
            local abilityId = type(fourCC) == "string" and FourCC(fourCC) or fourCC
            name = BlzGetAbilityTooltip(abilityId, 0)
            rawTooltip = BlzGetAbilityExtendedTooltip(abilityId, 0)
            icon = BlzGetAbilityIcon(abilityId)
        end

        if not TALENT_TREES[tree] then
            print("|cffff0000Warning: |r" .. tree .. " talent tree not recognized.")
            return
        end

        if row > NUMBER_OF_TALENT_ROWS then
            print("|cffff0000Warning:|r Talent " .. name .. "'s row is greater than NUMBER_OF_TALENT_ROWS.")
            return
        end

        if column > NUMBER_OF_TALENT_COLUMNS then
            print("|cffff0000Warning:|r Talent " .. name .. "'s column is greater than NUMBER_OF_TALENT_COLUMNS.")
            return
        end

		if talentTooltip[name] ~= nil then
			print("|cffff0000Warning:|r Talent " .. name .. " multiply declared.")
            return
		end

        if talentFromPosition[tree][column][row] then
            print("|cffff0000Warning:|r Multiple talents declared for column " .. column .. ", row " .. row .. " in talent tree " .. tree .. ".")
            return
        end

        if requirement then
            if type(requirement) == "table" then
                talentRequirement[name] = requirement
            else
                talentRequirement[name] = {requirement}
            end

            for __, req in ipairs(talentRequirement[name]) do
                if talentTooltip[req] == nil then
                    print("|cffff0000Warning:|r Requirement talent " .. req .. "  not recognized. Defined before requirement?")
                    return
                end
            end
        end

        talentTooltip[name] = {}

        if rawTooltip == nil then
            print("|cffff0000Warning:|r Invalid ability " .. fourCC .. " specified in RegisterTalent function.")
            return
        end
        rawTooltip = ReplaceTooltipStrings(rawTooltip)

        for i = 1, maxPoints do
            talentTooltip[name][i] = rawTooltip
        end

        if prelearnTooltip then
            talentTooltip[name][0] = ReplaceTooltipStrings(prelearnTooltip)
        end

        if values then
            talentValues[name] = {}

            talentAbility[name] = type(ability) == "string" and FourCC(ability) or ability

            local isPercent, isStatic, isFromField, fieldValue
            for key, value in pairs(values) do
                isPercent = rawTooltip:find("!" .. key .. ",\x25$?\x25\x25") ~= nil
                isStatic = rawTooltip:find("!" .. key .. ",\x25\x25?\x25$") ~= nil
                isFromField = ability and type(value) == "string" and value:len() == 4

                talentValues[name][key] = {}

                local v
                --Prelearn tooltip is stored at index 0, but uses values of index 1.
                for i = 0, maxPoints do
                    if talentTooltip[name][i] then
                        v = i < 1 and 1 or i
                        if type(value) == "table" then
                            if isPercent then
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25\x25!", TOOLTIP_VALUE_COLOR .. math.floor(100*value[v] + 0.5) .. "\x25\x25|r")
                            else
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. "!", TOOLTIP_VALUE_COLOR .. (math.tointeger(value[v]) or value[v]) .. "|r")
                            end
                            talentValues[name][key][i] = value[v]
                        elseif isFromField then
                            fieldValue = GetAbilityField(talentAbility[name], value, v)
                            if isPercent then
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25\x25!", TOOLTIP_VALUE_COLOR .. math.floor(100*fieldValue + 0.5) .. "\x25\x25|r")
                            else
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. "!", TOOLTIP_VALUE_COLOR .. (math.tointeger(fieldValue) or fieldValue) .. "|r")
                            end
                            talentValues[name][key][i] = fieldValue
                        elseif isPercent then
                            if isStatic then
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25\x25\x25$", TOOLTIP_VALUE_COLOR .. math.floor(100*value + 0.5) .. "\x25\x25|r")
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25$\x25\x25", TOOLTIP_VALUE_COLOR .. math.floor(100*value + 0.5) .. "\x25\x25|r")
                                talentValues[name][key][i] = value
                            else
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25\x25!", TOOLTIP_VALUE_COLOR .. math.floor(100*v*value + 0.5) .. "\x25\x25|r")
                                talentValues[name][key][i] = v*value
                            end
                        else
                            if isStatic then
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. ",\x25$!", TOOLTIP_VALUE_COLOR .. (math.tointeger(value) or value) .. "|r")
                                talentValues[name][key][i] = value
                            else
                                talentTooltip[name][i] = talentTooltip[name][i]:gsub("!" .. key .. "!", TOOLTIP_VALUE_COLOR .. (math.tointeger(v*value) or v*value) .. "|r")
                                talentValues[name][key][i] = v*value
                            end
                        end
                    end
                end
            end
        end

        local id
        if affects then
            if type(affects) == "table" then
                talentAffects[name] = {}
                for index, value in ipairs(affects) do
                    id = type(value) == "string" and FourCC(value) or value
                    talentAffects[name][index] = id
                    affectedByTalents[id] = affectedByTalents[id] or {}
                    table.insert(affectedByTalents[id], name)
                end
            else
                id = type(affects) == "string" and FourCC(affects) or affects
                talentAffects[name] = {id}
                affectedByTalents[id] = affectedByTalents[id] or {}
                table.insert(affectedByTalents[id], name)
            end
        end

        talentFromPosition[tree][column][row] = name

		talentIconPath[name] = icon
		talentParentTree[name] = tree
		talentColumn[name] = column
		talentRow[name] = row
		talentMaxPoints[name] = maxPoints

        if requirement then
            for __, req in ipairs(talentRequirement[name]) do
                if talentSuccessors[req] == nil then
                    talentSuccessors[req] = {name}
                else
                    talentSuccessors[req][#talentSuccessors[req] + 1] = name
                end
            end
		end
		talentOnLearn[name] = learnCallback
	end

	---@param treeName string
    local function CreateTalentTree(treeName)
        talentTreeParentFrame[treeName] = BlzCreateFrame("TalentTreeParentFrame", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(talentTreeParentFrame[treeName], FRAMEPOINT_TOPLEFT, TREE_MENU_X - TREE_MENU_WIDTH/2, TREE_MENU_Y + TREE_MENU_HEIGHT/2)
        BlzFrameSetAbsPoint(talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMRIGHT, TREE_MENU_X + TREE_MENU_WIDTH/2, TREE_MENU_Y - TREE_MENU_HEIGHT/2)
        BlzFrameSetVisible(talentTreeParentFrame[treeName], false)
        BlzFrameSetEnable(talentTreeParentFrame[treeName], false)
        BlzFrameSetTexture(talentTreeParentFrame[treeName], "transparentMask.blp", 0, true)

        local backdrop = BlzFrameGetChild(talentTreeParentFrame[treeName], 0)
        BlzFrameSetTexture(backdrop, "TalentTreeBackground" .. ToPascalCase(treeName), 0, true)
        BlzFrameSetPoint(backdrop, FRAMEPOINT_BOTTOMLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMLEFT, BACKGROUND_HORIZONTAL_INSET, BACKGROUND_INSET_BOTTOM)
        BlzFrameSetPoint(backdrop, FRAMEPOINT_TOPRIGHT, talentTreeParentFrame[treeName], FRAMEPOINT_TOPRIGHT, -BACKGROUND_HORIZONTAL_INSET, -BACKGROUND_INSET_TOP)
        BlzFrameSetEnable(backdrop, false)

        local bottomBar = BlzFrameGetChild(talentTreeParentFrame[treeName], 1)
        BlzFrameSetPoint(bottomBar, FRAMEPOINT_BOTTOMLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMLEFT, BOTTOM_BAR_HORIZONTAL_INSET, BOTTOM_BAR_VERTICAL_SHIFT)
        BlzFrameSetPoint(bottomBar, FRAMEPOINT_TOPRIGHT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMRIGHT, -BOTTOM_BAR_HORIZONTAL_INSET, BOTTOM_BAR_HEIGHT + BOTTOM_BAR_VERTICAL_SHIFT)
        BlzFrameSetEnable(bottomBar, false)

        local topBar = BlzFrameGetChild(talentTreeParentFrame[treeName], 2)
        BlzFrameSetPoint(topBar, FRAMEPOINT_BOTTOMLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_TOPLEFT, TOP_BAR_HORIZONTAL_INSET, TOP_BAR_VERTICAL_SHIFT - TOP_BAR_HEIGHT)
        BlzFrameSetPoint(topBar, FRAMEPOINT_TOPRIGHT, talentTreeParentFrame[treeName], FRAMEPOINT_TOPRIGHT, -TOP_BAR_HORIZONTAL_INSET, TOP_BAR_VERTICAL_SHIFT)
        BlzFrameSetEnable(topBar, false)

        local header = BlzCreateFrameByType("TEXT", "talentMenuHeader", topBar, "", 0)
        BlzFrameSetPoint(header, FRAMEPOINT_BOTTOMLEFT, topBar, FRAMEPOINT_BOTTOMLEFT, 0, TOP_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPRIGHT, topBar, FRAMEPOINT_TOPRIGHT, 0, TOP_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetTextAlignment(header, TEXT_JUSTIFY_BOTTOM, TEXT_JUSTIFY_CENTER)
        BlzFrameSetText(header, TOP_BAR_TEXT)
        BlzFrameSetScale(header, TOP_BAR_FONT_SIZE/10)

		local closeButton = BlzCreateFrameByType("GLUETEXTBUTTON", "closeButton", header, "ScriptDialogButton", 0)
		BlzFrameSetPoint(closeButton, FRAMEPOINT_BOTTOMLEFT, header, FRAMEPOINT_BOTTOMRIGHT, CLOSE_BUTTON_HORIZONTAL_SHIFT - CLOSE_BUTTON_SIZE, CLOSE_BUTTON_VERTICAL_SHIFT)
		BlzFrameSetPoint(closeButton, FRAMEPOINT_TOPRIGHT, header, FRAMEPOINT_BOTTOMRIGHT, CLOSE_BUTTON_HORIZONTAL_SHIFT, CLOSE_BUTTON_VERTICAL_SHIFT + CLOSE_BUTTON_SIZE)
        local icon = BlzFrameGetChild(closeButton, 0)
        local iconClicked = BlzFrameGetChild(closeButton, 1)
        BlzFrameSetAllPoints(icon, closeButton)
		BlzFrameSetPoint(iconClicked, FRAMEPOINT_BOTTOMLEFT, closeButton, FRAMEPOINT_BOTTOMLEFT, 0.001, 0.001)
		BlzFrameSetPoint(iconClicked, FRAMEPOINT_TOPRIGHT, closeButton, FRAMEPOINT_TOPRIGHT, -0.001, -0.001)
		BlzFrameSetTexture(icon, CLOSE_BUTTON_TEXTURE, 0, true)
		BlzFrameSetTexture(iconClicked, CLOSE_BUTTON_TEXTURE, 0, true)

        local closeTrigger = CreateTrigger()
        BlzTriggerRegisterFrameEvent(closeTrigger, closeButton, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(closeTrigger, PressCloseButton)

        local border = BlzFrameGetChild(talentTreeParentFrame[treeName], 3)
        BlzFrameSetAbsPoint(border, FRAMEPOINT_TOPLEFT, TREE_MENU_X - TREE_MENU_WIDTH/2, TREE_MENU_Y + TREE_MENU_HEIGHT/2)
        BlzFrameSetAbsPoint(border, FRAMEPOINT_BOTTOMRIGHT, TREE_MENU_X + TREE_MENU_WIDTH/2, TREE_MENU_Y - TREE_MENU_HEIGHT/2)
        BlzFrameSetEnable(border, false)

        talentTreePointsSpentText[treeName] = BlzCreateFrameByType("TEXT", "talentTreePointsSpent" .. treeName, border, "", 0)
        BlzFrameSetPoint(talentTreePointsSpentText[treeName], FRAMEPOINT_BOTTOMLEFT, border, FRAMEPOINT_BOTTOMLEFT, BOTTOM_LEFT_TEXT_HORIZONTAL_INSET, BOTTOM_BAR_VERTICAL_SHIFT + BOTTOM_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetPoint(talentTreePointsSpentText[treeName], FRAMEPOINT_TOPRIGHT, border, FRAMEPOINT_BOTTOMRIGHT, -BOTTOM_LEFT_TEXT_HORIZONTAL_INSET, BOTTOM_BAR_HEIGHT + BOTTOM_BAR_VERTICAL_SHIFT + BOTTOM_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetTextAlignment(talentTreePointsSpentText[treeName], TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(talentTreePointsSpentText[treeName], false)

        talentTreeUnspentPointsText[treeName] = BlzCreateFrameByType("TEXT", "talentTreePointsSpent" .. treeName, border, "", 0)
        BlzFrameSetPoint(talentTreeUnspentPointsText[treeName], FRAMEPOINT_BOTTOMLEFT, border, FRAMEPOINT_BOTTOMRIGHT, -BOTTOM_RIGHT_TEXT_HORIZONTAL_INSET, BOTTOM_BAR_VERTICAL_SHIFT + BOTTOM_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetPoint(talentTreeUnspentPointsText[treeName], FRAMEPOINT_TOPRIGHT, border, FRAMEPOINT_BOTTOMRIGHT, 0, BOTTOM_BAR_HEIGHT + BOTTOM_BAR_VERTICAL_SHIFT + BOTTOM_BAR_TEXT_VERTICAL_SHIFT)
        BlzFrameSetTextAlignment(talentTreeUnspentPointsText[treeName], TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(talentTreeUnspentPointsText[treeName], false)

        treeNavigatorFrame[treeName] = BlzCreateFrame("TalentNavigator", talentBackdrop, 0, 0)
        treeNavigatorTitles[treeName] = BlzFrameGetChild(treeNavigatorFrame[treeName], 3)
        BlzFrameSetText(treeNavigatorTitles[treeName], TREE_NAVIGATOR_UNSELECTED_COLOR .. treeName .. "|r")
        BlzFrameSetAllPoints(treeNavigatorTitles[treeName], treeNavigatorFrame[treeName])
        BlzFrameSetTextAlignment(treeNavigatorTitles[treeName], TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetEnable(treeNavigatorTitles[treeName], false)
        BlzFrameSetScale(treeNavigatorTitles[treeName], TREE_NAVIGATOR_FONT_SIZE/10)

        if BLACK_FADE_CORNER_SIZE > 0 then
            local blackFadeFrames = {}
            for i = 1, 4 do
                blackFadeFrames[i] = BlzCreateFrameByType("BACKDROP", "blackFadeFrame" .. i, talentTreeParentFrame[treeName], "", 0)
                BlzFrameSetTexture(blackFadeFrames[i], "TalentTreeFade" .. i .. ".blp", 0, true)
                BlzFrameSetEnable(blackFadeFrames[i], false)
            end
            BlzFrameSetSize(blackFadeFrames[1], BLACK_FADE_CORNER_SIZE, TREE_MENU_HEIGHT - BACKGROUND_INSET_BOTTOM - BACKGROUND_INSET_TOP)
            BlzFrameSetPoint(blackFadeFrames[1], FRAMEPOINT_BOTTOMRIGHT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMRIGHT, -BACKGROUND_HORIZONTAL_INSET, BACKGROUND_INSET_BOTTOM)

            BlzFrameSetSize(blackFadeFrames[2], TREE_MENU_WIDTH - BACKGROUND_HORIZONTAL_INSET - BACKGROUND_HORIZONTAL_INSET, BLACK_FADE_CORNER_SIZE)
            BlzFrameSetPoint(blackFadeFrames[2], FRAMEPOINT_TOPLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_TOPLEFT, BACKGROUND_HORIZONTAL_INSET, -BACKGROUND_INSET_TOP)

            BlzFrameSetSize(blackFadeFrames[3], BLACK_FADE_CORNER_SIZE, TREE_MENU_HEIGHT - BACKGROUND_INSET_BOTTOM - BACKGROUND_INSET_TOP)
            BlzFrameSetPoint(blackFadeFrames[3], FRAMEPOINT_BOTTOMLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMLEFT, BACKGROUND_HORIZONTAL_INSET, BACKGROUND_INSET_BOTTOM)

            BlzFrameSetSize(blackFadeFrames[4], TREE_MENU_WIDTH - BACKGROUND_HORIZONTAL_INSET - BACKGROUND_HORIZONTAL_INSET, BLACK_FADE_CORNER_SIZE)
            BlzFrameSetPoint(blackFadeFrames[4], FRAMEPOINT_BOTTOMLEFT, talentTreeParentFrame[treeName], FRAMEPOINT_BOTTOMLEFT, BACKGROUND_HORIZONTAL_INSET, BACKGROUND_INSET_BOTTOM)
        end

        BlzFrameSetVisible(treeNavigatorFrame[treeName], false)

        local trig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trig, treeNavigatorFrame[treeName], FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trig, OnNavigatorClick)

        treeFromNavigator[treeNavigatorFrame[treeName]] = treeName
	end

    OnInit.final("TalentTree", function()
        localPlayer = GetLocalPlayer()

        GetOwner = ALICE_GetOwner or GetOwningPlayer

        if not BlzLoadTOCFile("TalentTreeTemplates.toc") then
            print("|cffff0000Warning:|r TalentTreeTemplates.toc failed to load.")
            return
        end

        talentBackdrop = BlzCreateFrameByType("FRAME", "heroIconFrame", BlzGetFrameByName("ConsoleUIBackdrop",0), "", 0)
        BlzFrameSetAbsPoint(talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_MENU_X - TREE_MENU_WIDTH/2, TREE_MENU_Y - TREE_MENU_HEIGHT/2)
        BlzFrameSetAbsPoint(talentBackdrop, FRAMEPOINT_TOPRIGHT, TREE_MENU_X + TREE_MENU_WIDTH/2, TREE_MENU_Y + TREE_MENU_HEIGHT/2)
        BlzFrameSetTexture(talentBackdrop, "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp", 0, true)
        BlzFrameSetEnable(talentBackdrop, false)
        BlzFrameSetVisible(talentBackdrop, false)

        talentTrigger = CreateTrigger()
        TriggerAddAction(talentTrigger, TalentOnClick)

        for i = 1, #TALENT_TREES do
            CreateTalentTree(TALENT_TREES[i])
        end

        local trig = CreateTrigger()
        TriggerAddAction(trig, PressCloseButton)

        local zeroTable = {__index = function() return 0 end}
        local player
        for i = 0, 23 do
            player = Player(i)
            playerPointsInTalent[player] = setmetatable({}, zeroTable)
            playerPointsInTree[player] = setmetatable({}, zeroTable)
            playerCurrencyInTree[player] = setmetatable({}, zeroTable)
            playerRowsInTreeEnabled[player] = setmetatable({}, {__index = function() return 1 end})
            playerPointsTotal[player] = 0
            playerCurrencyTotal[player] = 0
            playerUnspentPoints[player] = 0
            playerTalentIsEnabled[player] = {}
            playerTalentIsHardDisabled[player] = {}
            playerTalentRequirementText[player] = {}
            playerTalentOverwriteText[player] = {}
            BlzTriggerRegisterPlayerKeyEvent(trig, player, OSKEY_ESCAPE, 0, true)
        end

        for i = 1, #TALENT_TREES do
            AddTalentsToTree(TALENT_TREES[i])
        end

        buttonPressSound = CreateSound("Sound\\Interface\\BigButtonClick.flac", false, false, false, 0, 0, "DefaultEAXON")

        talentTreesInitialized = true
    end)

    --===========================================================================================================================================================
    --API
    --===========================================================================================================================================================

    CTT = {}

    ---Registers a talent from the data provided in the data table. The recognized fields for data table are fourCC, name, icon, tooltip, tree, column, row, maxPoints, callback, requirement, and values. For details, see hiveworkshop resource page.
    ---@param data table
    CTT.RegisterTalent = function(data)
        if talentTreesInitialized then
            print("|cffff0000Warning:|r Register talents only before talent trees are initialized.")
            return
        end
        for key, __ in pairs(data) do
            if not RECOGNIZED_FLAGS[key] then
                print("|cffff0000Warning:|r Unrecognized flag " .. key .. " in data table passed into RegisterTalent function.")
            end
        end
        for key, __ in ipairs(REQUIRED_FLAGS) do
            if not data[key] then
                print("|cffff000Warning:|r Required flag " .. key .. " missing in data table passed into RegisterTalent function.")
                return
            end
        end

        if not data.fourCC and not (data.name and data.icon and data.tooltip) then
            print("|cffff000Warning:|r Data table for RegisterTalent function requires either fourCC or name, tooltip, and icon.")
            return
        end

        CreateTalent(data)
    end

    ---Sets the talent trees for the specified player to the provided list of talent trees. The talent trees will be arranged according to their order in the arguments.
    ---@param who player | unit
    ---@vararg string
    CTT.SetTrees = function(who, ...)
        who = HandleType[who] == "player" and who or GetOwner(who)
        if playerTalentTrees[who] == nil then
            playerTalentTrees[who] = {}
        else
            for key, __ in pairs(playerTalentTrees[who]) do
                playerTalentTrees[key] = nil
                BlzFrameSetVisible(treeNavigatorFrame[key], false)
            end
        end

        local tree
        for i = 1, select("#", ...) do
            tree = select(i, ...)
            if not treeNavigatorFrame[tree] then
                print("|cffff0000Warning:|r Attempt to set unrecognized talent tree " .. tree .. " for player.")
                return
            end
            playerTalentTrees[who][i] = tree
            BlzFrameSetVisible(treeNavigatorFrame[tree], true)
            BlzFrameSetLevel(treeNavigatorFrame[tree], 0)
            BlzFrameSetPoint(treeNavigatorFrame[tree], FRAMEPOINT_BOTTOMLEFT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + (i-1)*(TREE_NAVIGATOR_WIDTH - TREE_NAVIGATOR_OVERLAP), TREE_NAVIGATOR_VERTICAL_SHIFT - TREE_NAVIGATOR_HEIGHT)
            BlzFrameSetPoint(treeNavigatorFrame[tree], FRAMEPOINT_TOPRIGHT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + i*TREE_NAVIGATOR_WIDTH - (i-1)*TREE_NAVIGATOR_OVERLAP, TREE_NAVIGATOR_VERTICAL_SHIFT)
            if localPlayer == who then
                treeNavigatorPosition[tree] = i
            end
        end

        if not VARIABLE_TALENT_COST and playerUnspentPoints[who] == 0 then
            DisableButtonsOnLastPointSpent(who)
        end

        SwitchToTree(who, playerTalentTrees[who][1], treeNavigatorFrame[playerTalentTrees[who][1]])
    end

    ---Adds the provided list of talent trees to the talents trees of the specified player. The talent trees will be arranged according to their order in the arguments.
    ---@param who player | unit
    ---@vararg string
    CTT.AddTrees = function(who, ...)
        who = HandleType[who] == "player" and who or GetOwner(who)
        if playerTalentTrees[who] == nil then
            playerTalentTrees[who] = {}
        end

        local tree
        for i = 1, select("#", ...) do
            tree = select(i, ...)
            if not treeNavigatorFrame[tree] then
                print("|cffff0000Warning:|r Attempt to set unrecognized talent tree " .. tree .. " for player.")
                return
            end
            playerTalentTrees[who][i] = tree
            BlzFrameSetVisible(treeNavigatorFrame[tree], true)
            BlzFrameSetLevel(treeNavigatorFrame[tree], 0)
            BlzFrameSetPoint(treeNavigatorFrame[tree], FRAMEPOINT_BOTTOMLEFT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + (i-1)*(TREE_NAVIGATOR_WIDTH - TREE_NAVIGATOR_OVERLAP), TREE_NAVIGATOR_VERTICAL_SHIFT - TREE_NAVIGATOR_HEIGHT)
            BlzFrameSetPoint(treeNavigatorFrame[tree], FRAMEPOINT_TOPRIGHT, talentBackdrop, FRAMEPOINT_BOTTOMLEFT, TREE_NAVIGATOR_HORIZONTAL_SHIFT + i*TREE_NAVIGATOR_WIDTH + (i-1)*TREE_NAVIGATOR_OVERLAP, TREE_NAVIGATOR_VERTICAL_SHIFT)
            if localPlayer == who then
                treeNavigatorPosition[tree] = i
            end
        end

        if not VARIABLE_TALENT_COST and playerUnspentPoints[who] == 0 then
            DisableButtonsOnLastPointSpent(who)
        end

        if currentTalentTree[who] == nil then
            SwitchToTree(who, playerTalentTrees[who][1], treeNavigatorFrame[playerTalentTrees[who][1]])
        end
    end

    ---Adds the specified amount, or 1 if not specified, to the player's unspent talent points.
    ---@param who player | unit
    ---@param howMany? integer
    CTT.GrantPoints = function(who, howMany)
        who = HandleType[who] == "player" and who or GetOwner(who)
        if not VARIABLE_TALENT_COST and playerUnspentPoints[who] == 0 and howMany > 0 then
            EnableButtonsOnFirstPointGained(who)
        end
        playerUnspentPoints[who] = playerUnspentPoints[who] + (howMany or 1)
        if currentTalentTree[who] then
            SetBottomBarText(who, currentTalentTree[who])
        end
    end

    ---Sets the unspent talent points of the specified player to the provided amount.
    ---@param who player | unit
    ---@param howMany integer
    CTT.SetPoints = function(who, howMany)
        who = HandleType[who] == "player" and who or GetOwner(who)
        if not VARIABLE_TALENT_COST and playerUnspentPoints[who] == 0 and howMany > 0 then
            EnableButtonsOnFirstPointGained(who)
        elseif playerUnspentPoints[who] > 0 and howMany == 0 then
            DisableButtonsOnLastPointSpent(who)
        end
        playerUnspentPoints[who] = howMany
        if currentTalentTree[who] then
            SetBottomBarText(who, currentTalentTree[who])
        end
    end

    ---Selects the specified talent for a player. If the optional subtractCost argument is not set, the player will not lose unspent talent points and all requirements of the talent will be ignored.
    ---@param who player | unit
    ---@param whichTalent string
    ---@param subtractCost? boolean
    CTT.ForceSelectTalent = function(who, whichTalent, subtractCost)
        who = HandleType[who] == "player" and who or GetOwner(who)
        if subtractCost then
            local cost = VARIABLE_TALENT_COST and GetTalentCost(whichTalent, talentMaxPoints[whichTalent], playerPointsInTalent[who][whichTalent]) or 1

            if playerUnspentPoints[who] < cost then
                return
            else
                playerUnspentPoints[who] = playerUnspentPoints[who] - cost
            end
        end

        SelectTalent(who, whichTalent)
    end

    ---Resets all talents and refunds their cost for the specified player.
    ---@param who player | unit
    CTT.ResetAllTalents = function(who)
        who = HandleType[who] == "player" and who or GetOwner(who)
        local numPoints = 0
        local talent
        for __, tree in ipairs(playerTalentTrees[who]) do
            for i = 1, NUMBER_OF_TALENT_COLUMNS do
                for j = 1, NUMBER_OF_TALENT_ROWS do
                    talent = talentFromPosition[tree][i][j]
                    if talent then
                        if VARIABLE_TALENT_COST then
                            for k = playerPointsInTalent[who][talent] - 1, 0, -1 do
                                numPoints = numPoints + GetTalentCost(talent, talentMaxPoints[talent], k)
                            end
                        else
                            numPoints = numPoints + playerPointsInTalent[who][talent]
                        end

                        if playerPointsInTalent[who][talent] > 0 and talentOnLearn[talent] then
                            talentOnLearn[talent](who, talent, tree, playerPointsInTalent[who][talent], 0)
                        end

                        playerPointsInTalent[who][talent] = 0
                        playerTalentIsEnabled[who][talent] = nil

                        ResetTalent(who, talent)
                    end
                end
            end
            playerPointsInTree[who][tree] = 0
            playerCurrencyInTree[who][tree] = 0
            playerRowsInTreeEnabled[who][tree] = 0
        end

        playerPointsTotal[who] = 0
        playerCurrencyTotal[who] = 0
        playerUnspentPoints[who] = playerUnspentPoints[who] + numPoints

        if who == localPlayer then
            for __, tree in ipairs(playerTalentTrees[who]) do
                SetBottomBarText(who, tree)
            end
        end

        CheckRowsForEnabledTalents(who)
    end

    ---Returns the amount of unspent talent points the specified player has.
    ---@param who player | unit
    ---@return integer
    CTT.GetUnspentPoints = function(who)
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerUnspentPoints[who]
    end

    ---Returns the rank of the specified talent for a player.
    ---@param who player | unit
    ---@param whichTalent string
    ---@return integer
    CTT.GetTalentRank = function(who, whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return 0
        end
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerPointsInTalent[who][whichTalent]
    end

    ---Returns whether a player has one or more talent points invested in the specified talent.
    ---@param who player | unit
    ---@param whichTalent string
    ---@return boolean
    CTT.HasTalent = function(who, whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return false
        end
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerPointsInTalent[who][whichTalent] > 0
    end

    ---Returns whether a player has invested the maximum number of points in the specified talent.
    ---@param who player | unit
    ---@param whichTalent string
    ---@return boolean
    CTT.IsTalentMaxed = function(who, whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return false
        end
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerPointsInTalent[who][whichTalent] == talentMaxPoints[whichTalent]
    end

    ---Disables the specified talent for a player. The requirements text will be inserted on top of the tooltip while it is disabled. If the optional overwriteRequirements flag is set, the text for other missing requirements will be removed from the tooltip.
    ---@param who player | unit
    ---@param whichTalent string
    ---@param requirementsText? string
    ---@param overwriteRequirements? boolean
    CTT.DisableTalent = function(who, whichTalent, requirementsText, overwriteRequirements)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return
        end
        who = HandleType[who] == "player" and who or GetOwner(who)

        if playerPointsInTalent[who][whichTalent] > 0 then
            return
        end

        if not playerTalentIsHardDisabled[who][whichTalent] then
            playerTalentIsHardDisabled[who][whichTalent] = true
            playerTalentIsEnabled[who][whichTalent] = nil
            BlzFrameSetText(talentRankFrame[whichTalent], UNAVAILABLE_COLOR .. playerPointsInTalent[who][whichTalent] .. "/" .. talentMaxPoints[whichTalent])
            DisableTalent(whichTalent, who)
        end

        playerTalentRequirementText[who][whichTalent] = requirementsText
        playerTalentOverwriteText[who][whichTalent] = overwriteRequirements == true
        SetTalentTooltip(who, whichTalent)
    end

    ---Enables for the specified player a talent which has been previously disabled with CTT.DisableTalent.
    ---@param who player | unit
    ---@param whichTalent string
    CTT.EnableTalent = function(who, whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return
        end
        who = HandleType[who] == "player" and who or GetOwner(who)
        if not playerTalentIsHardDisabled[who][whichTalent] then
            return
        end

        playerTalentIsHardDisabled[who][whichTalent] = nil
        playerTalentRequirementText[who][whichTalent] = nil
        playerTalentOverwriteText[who][whichTalent] = nil
        SetTalentTooltip(who, whichTalent)

        if ShouldTalentBeEnabled(whichTalent, who) then
            EnableTalent(whichTalent, who)
        end
    end

    ---Returns the number of talent points a player has invested into the specified talent tree.
    ---@param who player | unit
    ---@param whichTree string
    CTT.GetPointsInTree = function(who, whichTree)
        if talentTreeParentFrame[whichTree] == nil then
            print("|cffff0000Warning:|r Unrecognized talent tree " .. whichTree .. ".")
            return 0
        end
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerPointsInTree[who][whichTree]
    end

    ---Returns the total number of talent points a player has distributed among talents. Does not include unspent talent points.
    ---@param who player | unit
    ---@return integer
    CTT.GetTotalPoints = function(who)
        who = HandleType[who] == "player" and who or GetOwner(who)
        return playerPointsTotal[who]
    end

    ---Returns the value with the whichValue key in the values table stored for the specified talent at the talent rank of a player. Returns 0, "", or false if the talent rank is zero.
    ---@param who player | unit
    ---@param whichTalent string
    ---@param whichValue string
    ---@return number | string | boolean
    CTT.GetValue = function(who, whichTalent, whichValue)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return 0
        end
        if talentValues[whichTalent][whichValue] == nil then
            print("|cffff0000Warning:|r Unrecognized value " .. whichValue .. " for talent " .. whichTalent .. ".")
            return 0
        end

        who = HandleType[who] == "player" and who or GetOwner(who)
        local points = playerPointsInTalent[who][whichTalent]
        if points == 0 then
            local valueType = type(talentValues[whichTalent][whichValue][1])
            if valueType == "number" then
                return 0
            elseif valueType == "string" then
                return ""
            else
                return false
            end
        else
            return talentValues[whichTalent][whichValue][points]
        end
    end

    ---Returns the tooltip for the specified talent at the talent rank of a player.
    ---@param who player | unit
    ---@param whichTalent any
    CTT.GetTooltip = function(who, whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return ""
        end

        who = HandleType[who] == "player" and who or GetOwner(who)
        local points = playerPointsInTalent[who][whichTalent]
        if points == 0 then
            return ""
        end
        return talentTooltip[whichTalent][points]
    end

    ---Returns the parent tree, the row, and the column of the specified talent.
    ---@param whichTalent string
    ---@return string, integer, integer
    CTT.GetTalentPosition = function(whichTalent)
        if talentFrame[whichTalent] == nil then
            print("|cffff0000Warning:|r Unrecognized talent " .. whichTalent .. ".")
            return "", 0, 0
        end
        return talentParentTree[whichTalent], talentRow[whichTalent], talentColumn[whichTalent]
    end

    ---Returns a table containing all talents that affect the specified object. Object can be a fourCC code or id.
    ---@param object string | integer
    ---@return table
    CTT.AffectedBy = function(object)
        local id = type(object) == "string" and FourCC(object) or object
        return affectedByTalents[id] or {}
    end

    ---Prints out the optimal image size ratio for the talent tree background images. You can specify either width or height to get the other.
    ---@param width? integer
    ---@param height? integer
    CTT.GetImageSizeRatio = function(width, height)
        local ratio = (TREE_MENU_HEIGHT - BOTTOM_BAR_HEIGHT - TOP_BAR_HEIGHT - BOTTOM_BAR_VERTICAL_SHIFT + TOP_BAR_VERTICAL_SHIFT - 2*BACKGROUND_VERTICAL_INSET) / (TREE_MENU_WIDTH - 2*BACKGROUND_HORIZONTAL_INSET)
        local text = "The optimal image size ratio is: |cffffcc00" .. string.format("\x25.3f", ratio) .. "|r."
        if width and not height then
            text = text .. " At a fixed width of " .. width .. ", this requires a height of |cffffcc00" .. math.floor(width*ratio + 0.5) .. "|r."
        elseif height and not width then
            text = text .. " At a fixed height of " .. height .. ", this requires a width of |cffffcc00" .. math.floor(height/ratio + 0.5) .. "|r."
        elseif height and width then
            text = text .. " Do not specify both width and height."
        end
        print(text)
    end

    ---Opens the talent menu for the specified player, or for all players if no player is specified. Set the optional enable parameter to false to instead force players to close the talent menu.
    ---@param who? player | unit
    ---@param enable? boolean
    CTT.Show = function(who, enable)
        who = who and (HandleType[who] == "player" and who or GetOwner(who))
        enable = enable ~= false
        if who == nil then
            BlzFrameSetVisible(talentBackdrop, enable)
            for i = 0, 23 do
                who = Player(i)
                if currentTalentTree[who] and localPlayer == who then
                    BlzFrameSetVisible(talentTreeParentFrame[currentTalentTree[who]], enable)
                    if currentTalentTree[who] then
                        SetBottomBarText(who, currentTalentTree[who])
                    end
                    if #playerTalentTrees[localPlayer] == 1 then
                        BlzFrameSetVisible(treeNavigatorFrame[playerTalentTrees[localPlayer][1]], false)
                    end
                end
                talentTreeOpen[who] = enable
            end
        else
            talentTreeOpen[who] = enable
            if who == localPlayer then
                BlzFrameSetVisible(talentTreeParentFrame[currentTalentTree[who]], enable)
                BlzFrameSetVisible(talentBackdrop, enable)
                if currentTalentTree[who] then
                    SetBottomBarText(who, currentTalentTree[who])
                end
                if #playerTalentTrees[who] == 1 then
                    BlzFrameSetVisible(treeNavigatorFrame[playerTalentTrees[who][1]], false)
                end
            end
        end
    end

    ---Returns whether the specified player has the talent tree opened.
    ---@param who player | unit
    ---@return boolean
    CTT.IsOpened = function(who)
        who = who and (HandleType[who] == "player" and who or GetOwner(who))
        return talentTreeOpen[who] or false
    end

    ---Returns a table containing a sequence with the ranks of each talent for the specified player as well as the number of unspent talent points as the last entry. Empty slots in the talent trees are included as a 0.
    ---@param who player | unit
    ---@return table
    CTT.Compile = function(who)
        who = HandleType[who] == "player" and who or GetOwner(who)
        local returnTable = {}
        for __, tree in ipairs(playerTalentTrees[who]) do
            for i = 1, NUMBER_OF_TALENT_COLUMNS do
                for j = 1, NUMBER_OF_TALENT_ROWS do
                    returnTable[#returnTable + 1] = playerPointsInTalent[who][talentFromPosition[tree][i][j]] or 0
                end
            end
        end
        returnTable[#returnTable + 1] = playerUnspentPoints[who]
        return returnTable
    end

    ---Loads the specified player's talent build from the provided data table which has been generated with the Compile function. Returns false if the load was not successful.
    ---@param who player | unit
    ---@param data table
    ---@return boolean
    CTT.LoadBuild = function(who, data)
        who = HandleType[who] == "player" and who or GetOwner(who)
        local expectedLength = #playerTalentTrees[who]*NUMBER_OF_TALENT_COLUMNS*NUMBER_OF_TALENT_ROWS + 1
        if expectedLength ~= #data then
            return false
        end

        local index = 1
        local mathType = math.type
        local entry
        for __, tree in ipairs(playerTalentTrees[who]) do
            for i = 1, NUMBER_OF_TALENT_COLUMNS do
                for j = 1, NUMBER_OF_TALENT_ROWS do
                    entry = data[index]
                    if type(entry) ~= "number" or mathType(entry) ~= "integer" or entry < 0 or entry > (talentMaxPoints[talentFromPosition[tree][i][j]] or 0) then
                        return false
                    end
                    index = index + 1
                end
            end
        end
        if type(data[#data]) ~= "number" or mathType(data[#data]) ~= "integer" or data[#data] < 0 then
            return false
        end

        CTT.ResetAllTalents(who)

        index = 1
        for __, tree in ipairs(playerTalentTrees[who]) do
            for i = 1, NUMBER_OF_TALENT_COLUMNS do
                for j = 1, NUMBER_OF_TALENT_ROWS do
                    for k = 1, data[index] do
                        SelectTalent(who, talentFromPosition[tree][i][j])
                    end
                    index = index + 1
                end
            end
        end

        CTT.SetPoints(who, data[#data])

        return true
    end

    ---Loads the talent build from the provided table and refunds all acquired talents for the specified player. This function should be used if the talent build load from the Load function was not successful.
    ---@param who player | unit
    ---@param data table
    CTT.ResetSavedBuild = function(who, data)
        who = HandleType[who] == "player" and who or GetOwner(who)
        local unspentTalents = 0
        for i = 1, #data do
            unspentTalents = unspentTalents + data[i]
        end
        CTT.ResetAllTalents(who)
        CTT.SetPoints(who, unspentTalents)
    end
end
if Debug then Debug.endFile() end