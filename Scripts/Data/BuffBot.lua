if Debug then Debug.beginFile "BuffBot" end
do
    --[[
    =============================================================================================================================================================
                                                                       Buff Bot
                                                                      by Antares
                                                                         v1.3

                                        A versatile system to improve the UI and API of buffs, including auras.

                                Requires:
                                TotalInitialization			        https://www.hiveworkshop.com/threads/.317099/
                                ALICE or MINACE                     https://www.hiveworkshop.com/threads/.353126/
                                FrameRecycler (optional)            https://www.hiveworkshop.com/threads/.355967/
                                    BuffIcon.fdf                    Included in Test Map.
                                    BuffIconTooltip.fdf             Included in Test Map.
                                    BuffBot.toc                     Included in Test Map.
                                ValidateTable (optional)            Included in Test Map.
                            
    =============================================================================================================================================================
                                                                          A P I
    =============================================================================================================================================================

    BuffBot
        .SetMainUnit = function(whichPlayer, newUnit)           Sets the specified unit to the unit for which buffs are shown in the buff bar for the specified
                                                                player.

        .Apply(whichUnit, buffData)                             Applies a buff to the specified unit with the data provided in the buffData table. Returns whether
                                                                the buff was successfully applied.
        .GetData(whichUnit, whichBuff)                          Returns the data table of a specific buff active on the specified unit. The buff is referenced by
                                                                its name.
        .GetAllBuffs(whichUnit)                                 Returns the table containing all buffs that are active on the specified unit.
        .GetLevel(whichUnit, whichBuff)                         Returns the level of a specific buff active on the specified unit. The buff is referenced by its
                                                                name.
        .HasBuff(whichUnit, whichBuff)                          Returns whether the specified unit has a specific buff. The buff is referenced by its name.
        .HasBuffWithValue(whichUnit, valueKey, valueAmount)     Returns whether the specified unit has a buff that has a value with the specified key in its values
                                                                table. If valueAmount is set, the value must be exactly the specified amount. Otherwise, it suffices
                                                                if it is neither false or nil. The buff is referenced by its name.
        .GetStacks(whichUnit, whichBuff)                        Returns the number of stacks of a specific buff active on the specified unit. The buff is referenced 
                                                                by its name.
        .AddStack(whichUnit, whichBuff)                         Add a stack to a specific buff on a unit without resetting the buff duration. Does not work for buffs
                                                                that use individualFallOff. The buff is referenced by its name.
        .SetStacks(whichUnit, whichBuff, howMany)               Sets the number of stacks of a specific buff on a unit to the specified amount without resetting the
                                                                buff duration. Does not work for buffs that use individualFallOff. The buff is referenced by its name.
        .GetValue(whichUnit, whichBuff, whichValue)             Returns the value with the whichValue key in the values table stored for the specified buff at the
                                                                current level of that buff on the specified unit, multiplied by the number of stacks. Returns 0 if
                                                                that buff is not active on that unit. The buff is referenced by its name.
        .GetTotalValue(whichUnit, whichValue)                   Loops through all buffs active on the specified unit, retrieves the values stored under the specified
                                                                key in their values tables, and returns their sum.
        .GetRemainingDuration(whichUnit, whichBuff)             Returns the remaining duration of a buff on a unit. Returns 0 if that buff is not active on that unit.
                                                                Returns inf if the buff is eternal.
        .GetFullDuration(whichUnit, whichBuff)                  Returns the total duration of a buff on a unit. Returns 0 if that buff is not active on that unit.
                                                                Returns inf if the buff is eternal. The buff is referenced by its name.
        .GetSource(whichUnit, whichBuff)                        Returns the source of a buff on a unit.
        .Dispel(whichUnit, whichBuff, reduceStacks?)            Dispels a specific buff from the specified unit. The optional reduceStacks flag controls whether only
                                                                one stack should be removed from that unit if multiple stacks are applied. The buff is referenced by
                                                                its name. Returns whether a buff was dispelled.
        .DispelAll(whichUnit, type?, reduceStacks?)             Dispels from the specified unit all buffs of the specified type or of all types if type is not set.
                                                                The optional reduceStacks flag controls whether only one stack of each buff should be removed from
                                                                that unit if multiple stacks are applied. Returns the number of buffs that were dispelled.
        .DispelRandom(whichUnit, type?, reduceStacks?)          Dispels a random buff from the specified unit. If the optional type flag is set, only buffs of that
                                                                type will be considered. The optional reduceStacks flag controls whether only one stack should be
                                                                removed from that unit if multiple stacks are applied. Returns whether a buff was dispelled.
        .DefineStat(statName, statData)                         Define a custom stat that can thereafter be used in the buffData tables. The statData table defines
                                                                up to three callback functions: onFirstApply is executed when a buff with the defined stat is first
                                                                applied, onApply everytime the buff is applied, and onExpire when the buff expires. They are called
                                                                with the parameters (target, source, value), where value is the stat's value specified in the buffData
                                                                table. If value is a function, it is evaluated with the parameters (target, source, level, stacks)
                                                                and the return value used.
        .CreateAura(source, auraData, buffData)                 Creates an aura from the auraData table for the specified unit that automatically applies the buff
                                                                provided in the buffData table to nearby units. The condition is a function that is called with the
                                                                arguments (source, target) and should return a boolean that controls whether the target unit is
                                                                affected by the aura.
        .DestroyAura(whichUnit, auraName)                       Destroys the aura with the specified name attached to the specified unit.
        .ModifyAura(                                            Modifies the aura with auraName attached to the specified unit, overwriting all fields in its data
            whichUnit,                                          tables with the new data provided in the auraData and buffData tables, leaving all unset fields
            auraName,                                           unchanged. To nil a field, pass BuffBot.SET_TO_NIL.
            auraData?,
            buffData?,
            level?
        )
        .GetAuraData(whichUnit, auraName)                       Returns the data table of an aura for which the specified unit is the source.

        .DefineStat(statName, statData)                         Define a custom stat that will automatically invoke callback functions when present in a buff's values
                                                                table. The statData table defines up to three callback functions:
                                                                onFirstApply(whichUnit, source, amount, buffName): Invoked when a buff with the defined stat is first
                                                                applied.
                                                                onApply(whichUnit, source, amount, oldAmount, buffName): Invoked every time the buff is applied.
                                                                oldAmount is set if the buff is already present on the unit.
                                                                onExpire(whichUnit, source, amount, buffName): Invoked when the buff expires.

    =============================================================================================================================================================
																	    C O N F I G
    =============================================================================================================================================================
    ]]

    --Enable the custom UI.
    local USE_BUFF_BAR                      = true              ---@constant boolean
    --Include the time remaining text below each buff in the custom buff bar.
    local USE_BUFF_BAR_TIME_REMAINING_TEXT  = true              ---@constant boolean
    --Include the time remaining text in the mouse-over tooltip of each buff.
    local USE_TOOLTIP_TIME_REMAINING_TEXT   = true              ---@constant boolean

    --If the time remaining of a buff is less than this value, it starts to flicker.
    local FLICKER_DURATION                  = 30                ---@constant number
    --Will flicker twice as fast if the remaining buff duration is less than this value.
    local FLICKER_FAST_DURATION             = 10                ---@constant number
    --Duration of one flicker animation.
    local FLICKER_CYCLE_LENGTH              = 1.6               ---@constant number
    --The alpha value of the frame will alternate between 255 and this value.
    local FLICKER_MIN_ALPHA                 = 100               ---@constant integer

    --These constants control the layout of the custom UI buff bar.
    local BUFF_BAR_ALIGNMENT                = "center"          ---@constant "left" | "center" | "right"
    local BUFF_BAR_X                        = 0.4               ---@constant number
    local BUFF_BAR_Y                        = 0.52              ---@constant number
    local BUFF_BAR_ICON_SIZE                = 0.03155           ---@constant number
    --The distance between the time remaining text and the icons.
    local BUFF_BAR_TEXT_HEIGHT              = 0.015             ---@constant number

    --Width of the mouse-over tooltips of each buff in the custom UI.
    local TOOLTIP_WIDTH                     = 0.24              ---@constant number

    --When a buff has multiple stacks, a number overlay appears. These constants control the position.
    local STACKS_FRAME_HORIZONTAL_INSET     = 0.0035            ---@constant number
    local STACKS_FRAME_VERTICAL_INSET       = 0.0025            ---@constant number

    --The text color of the buff type and time remaining text.
    local SPECIAL_TEXT_COLOR                = "|cffffcc00"      ---@constant string
    --The text color of the stacks overlay.
    local STACKS_COLOR                      = "|cffffffff"      ---@constant string
    --The color of the level text after the buff name.
    local LEVEL_COLOR                       = "|cffaaaaaa"      ---@constant string

    --Controls how many frames are allocated. If a unit has more buffs than this number, new buffs will not be shown.
    local MAX_NUMBER_OF_BUFFS               = 15                ---@constant integer

    --The maximum time the system waits for a native buff to be applied after BuffBot.Apply is invoked before it stops checking.
    local MAXIMUM_NATIVE_BUFF_WAIT_TIME     = 0.5               ---@constant number

    ---This is the function that orders a dummy to cast the buff on a unit. You should replace this with the dummy system you're using.
    ---@param whichUnit unit
    ---@param ability integer
    ---@param order string | integer
    ---@param level integer
    local function CastDummyAbility(whichUnit, ability, order, level)
        DummyTargetUnit(whichUnit, whichUnit, ability, order, level)
    end

    ---The text that is shown in the time remaining text below the buff icons.
    ---@param remaining number
    ---@return string
    local function GetDurationText(remaining)
        if remaining > 3600 then
            return SPECIAL_TEXT_COLOR .. math.floor(remaining/3600) .. " h|r"
        elseif remaining > 60 then
            return SPECIAL_TEXT_COLOR .. math.floor(remaining/60) .. " m|r"
        else
            return SPECIAL_TEXT_COLOR .. math.floor(remaining) .. " s|r"
        end
    end

    ---The text that is shown in the time remaining text in the buff tooltips.
    ---@param remaining number
    ---@return string
    local function GetDurationTextExtended(remaining)
        local amount, unit
        if remaining > 3600 then
            amount = math.floor(remaining/3600)
            unit = "hour"
        elseif remaining > 60 then
            amount = math.floor(remaining/60)
            unit = "minute"
        else
            amount = math.floor(remaining)
            unit = "second"
        end
        if amount ~= 1 then
            return SPECIAL_TEXT_COLOR .. amount .. " " .. unit .. "s remaining|r"
        else
            return SPECIAL_TEXT_COLOR .. amount .. " " .. unit .. " remaining|r"
        end
    end

    --===========================================================================================================================================================
    --Define custom stats here
    --===========================================================================================================================================================

    do
        local movementSpeedBonus = setmetatable({}, {__index = function(self, key) self[key] = 0 return 0 end, __mode = "k"})
        local movementSpeedMultiplier = setmetatable({}, {__index = function(self, key) self[key] = 1 return 1 end, __mode = "k"})

        local unitVertexColor = setmetatable({}, {__index = function(self, key) self[key] = {1, 1, 1, 1} return self[key] end, __mode = "k"})

        OnInit.global(function()
            BuffBot.DefineStat("movementSpeedPercent", {
                onApply = function(whichUnit, source, amount, oldAmount)
                    if oldAmount then
                        if oldAmount > 0 then
                            movementSpeedBonus[whichUnit] = movementSpeedBonus[whichUnit] - oldAmount
                        else
                            movementSpeedMultiplier[whichUnit] = movementSpeedMultiplier[whichUnit]/(1 + oldAmount)
                        end
                    end
                    if amount > 0 then
                        movementSpeedBonus[whichUnit] = movementSpeedBonus[whichUnit] + amount
                    else
                        movementSpeedMultiplier[whichUnit] = movementSpeedMultiplier[whichUnit]*(1 + amount)
                    end
                    local default = GetUnitDefaultMoveSpeed(whichUnit)
                    SetUnitMoveSpeed(whichUnit, default*(1 + movementSpeedBonus[whichUnit])*movementSpeedMultiplier[whichUnit])
                end,
                onExpire = function(whichUnit, source, amount)
                    if amount > 0 then
                        movementSpeedBonus[whichUnit] = movementSpeedBonus[whichUnit] - amount
                    else
                        movementSpeedMultiplier[whichUnit] = movementSpeedMultiplier[whichUnit]/(1 + amount)
                    end
                    local default = GetUnitDefaultMoveSpeed(whichUnit)
                    SetUnitMoveSpeed(whichUnit, default*(1 + movementSpeedBonus[whichUnit])*movementSpeedMultiplier[whichUnit])
                end
            })

            BuffBot.DefineStat("vertexColor", {
                onFirstApply = function(whichUnit, source, colorTable)
                    for i = 1, 4 do
                        unitVertexColor[whichUnit][i] = unitVertexColor[whichUnit][i]*colorTable[i]/255
                    end
                    SetUnitVertexColor(whichUnit,
                        math.floor(unitVertexColor[whichUnit][1]*255),
                        math.floor(unitVertexColor[whichUnit][2]*255),
                        math.floor(unitVertexColor[whichUnit][3]*255),
                        math.floor(unitVertexColor[whichUnit][4]*255)
                    )
                end,
                onExpire = function(whichUnit, source, colorTable)
                    for i = 1, 4 do
                        unitVertexColor[whichUnit][i] = unitVertexColor[whichUnit][i]/(colorTable[i]/255)
                    end
                    SetUnitVertexColor(whichUnit,
                        math.floor(unitVertexColor[whichUnit][1]*255),
                        math.floor(unitVertexColor[whichUnit][2]*255),
                        math.floor(unitVertexColor[whichUnit][3]*255),
                        math.floor(unitVertexColor[whichUnit][4]*255)
                    )
                end
            })
        end)
    end

    --[[
    =============================================================================================================================================================
                                                                  E N D   O F   C O N F I G
    =============================================================================================================================================================
    ]]

    local wt2D = {
        __index = function(self, key)
            self[key] = {}
            return self[key]
        end,
        __mode = "k"
    }

    local numberOfBuffs = setmetatable({}, {    ---@type table
        __index = function(self, key)
            return 0
        end,
        __mode = "k"
    })
    local buffList = setmetatable({}, wt2D)     ---@type table

    local buffCheckers                          ---@type table
        = setmetatable({}, wt2D)
    local activeAura = setmetatable({}, wt2D)

    local tooltipOfIcon         = {}            ---@type table
    local buffBarParent                         ---@type framehandle

    local customStats           = {}            ---@type table
    local thisUnit                              ---@type unit
    local thisBuffData                          ---@type table
    local tempCustomStatValues  = {}            ---@type table<string,any>

    local mainUnit                              ---@async unit

    local cos                   = math.cos
    local floor                 = math.floor
    local tointeger             = math.tointeger

    local localPlayer

    local AURA_INTERACTIONS

    local BUFF_RECOGNIZED_FIELDS = {
        tooltip = true,
        name = true,
        buff = true,
        ability = true,
        order = true,
        duration = true,
        type = true,
        icon = true,
        color = true,
        values = true,
        onApply = true,
        onFirstApply = true,
        onExpire = true,
        onPeriodic = true,
        cooldown = true,
        delay = true,
        isEternal = true,
        cannotOverwrite = true,
        effect = true,
        attachPoint = true,
        showLevel = true,
        maxStacks = true,
        individualFallOff = true,
        isHidden = true,
        auraBuff = true
    }

    local BUFF_IGNORED_FIELDS = {
        buff = true,
        level = true,
        tooltip = true,
        icon = true,
        name = true,
        isEternal = true,
        duration = true,
        delay = true,
        auraBuff = true
    }

    local AURA_REQUIRED_FIELDS = {
        name = true,
        range = true
    }

    local AURA_RECOGNIZED_FIELDS = {
        name = true,
        range = true,
        condition = true,
        effect = true,
        attachPoint = true,
        accuracy = true,
        effectOnSelf = true
    }

    local function ApplyAuraOnReset(source, target)
        local anchor = ALICE_GetAnchor(target)
        if source == activeAura[anchor][source.buffData.name] then
            BuffBot.Dispel(ALICE_GetAnchor(target), source.buffData.name)
            activeAura[anchor][source.buffData.name] = nil
        end
    end

    local function ApplyAura(source, target)
        local targetAnchor = ALICE_GetAnchor(target)
        local sourceAnchor = ALICE_GetAnchor(source)
        local buffData = source.buffData

        if source.condition == nil or source.condition(sourceAnchor, targetAnchor, source.level) then
            local dist = ALICE_PairGetDistance2D()
            if dist < source.range then
                local applied
                if ALICE_PairIsFirstContact() then
                    if not source.effectOnSelf and source == target and source.visual then
                        local effectPath = buffData.effect
                        buffData.effect = nil
                        applied = BuffBot.Apply(targetAnchor, buffData, sourceAnchor, source.level)
                        buffData.effect = effectPath
                    else
                        applied = BuffBot.Apply(targetAnchor, buffData, sourceAnchor, source.level)
                    end
                    if applied then
                        activeAura[targetAnchor][buffData.name] = source
                    end
                end
                if source ~= activeAura[targetAnchor][buffData.name] then
                    ALICE_PairReset()
                end
            else
                ALICE_PairReset()
            end
            if dist < source.range then
                return math.min(1, (source.range - dist)/(750*source.accuracy))
            else
                return math.min(1, (dist - source.range)/(750*source.accuracy))
            end
        else
            ALICE_PairReset()
            return 1.0/source.accuracy
        end
    end

    local function ToUpperCase(__, letter)
        return letter:upper()
    end

    local function ToCamelCase(whichString)
        whichString = whichString:gsub("(\x25s)(\x25a)", ToUpperCase)                       --remove spaces and convert to upper case after space
        whichString = whichString:gsub("[^\x25w]", "")                                      --remove special characters
        whichString = string.lower(whichString:sub(1,1)) .. string.sub(whichString,2)       --converts first character to lower case
        return whichString
    end

    local function GetForBuff(value, source, target, level, stacks, scaleWithStacks)
        local type = type(value)
        if type == "table" then
            if type(value[level]) == "number" then
                return value[level]*(scaleWithStacks and stacks or 1)
            else
                return value[level]
            end
        elseif type == "function" then
            return value(target, source, level, stacks)
        elseif type == "number" then
            return value*(scaleWithStacks and stacks or 1) or nil
        else
            return value
        end
    end

    local function GetForAura(value, source, level)
        local type = type(value)
        if type == "table" then
            return value[level]
        elseif type == "function" then
            return value(source, level)
        else
            return value
        end
    end

    local function GetIconX(i, unit)
        local iconPosition = 1
        local numVisibleBuffs = 0
        for j = 1, numberOfBuffs[unit] do
            if not buffList[unit][j].isHidden then
                if j < i then
                    iconPosition = iconPosition + 1
                end
                numVisibleBuffs = numVisibleBuffs + 1
            end
        end
        if BUFF_BAR_ALIGNMENT == "left" then
            return BUFF_BAR_X + (iconPosition-1)*BUFF_BAR_ICON_SIZE
        elseif BUFF_BAR_ALIGNMENT == "center" then
            return BUFF_BAR_X + (iconPosition-1)*BUFF_BAR_ICON_SIZE - numVisibleBuffs*BUFF_BAR_ICON_SIZE/2
        else
            return BUFF_BAR_X - iconPosition*BUFF_BAR_ICON_SIZE
        end
    end

    local function SetBuffFrame(buffData, unit)
        buffData.parentFrame = FrameRecycler.Get("buffIcon")
        if not buffData.parentFrame then
            buffData.isHidden = true
            return
        end
        buffData.iconFrame = BlzFrameGetChild(buffData.parentFrame, 0)
        buffData.textFrame = BlzFrameGetChild(buffData.parentFrame, 1)
        buffData.stacksFrame = BlzFrameGetChild(buffData.parentFrame, 2)

        BlzFrameSetAlpha(buffData.parentFrame, 255)

        local x, y = GetIconX(buffData.buffNumber, unit), BUFF_BAR_Y
        BlzFrameSetAbsPoint(buffData.parentFrame, FRAMEPOINT_BOTTOMLEFT, x, y)
        BlzFrameSetTexture(buffData.iconFrame, buffData.icon, 0, true)

        BlzFrameSetVisible(buffData.textFrame, buffData.fallOffPoint ~= nil)

        buffData.tooltipParent = tooltipOfIcon[buffData.parentFrame]
        buffData.tooltipTitle = BlzFrameGetChild(buffData.tooltipParent, 0)
        buffData.tooltipType = BlzFrameGetChild(buffData.tooltipParent, 1)
        buffData.tooltipText = BlzFrameGetChild(buffData.tooltipParent, 2)
        BlzFrameSetText(buffData.tooltipTitle, (buffData.color and buffData.color .. buffData.name .. "|r" or buffData.name) .. (buffData.showLevel and LEVEL_COLOR .. " (Level " .. buffData.level .. ")|r" or ""))
        BlzFrameSetText(buffData.tooltipText, buffData.tooltip)
        if buffData.type then
            if type(buffData.type) == "table" then
                local typeText = SPECIAL_TEXT_COLOR
                local first = true
                for __, subtype in ipairs(buffData.type) do
                    if first then
                        first = false
                    else
                        typeText = typeText .. "|r" .. LEVEL_COLOR .. ",|r " .. SPECIAL_TEXT_COLOR
                    end
                    typeText = typeText .. subtype
                end
                BlzFrameSetText(buffData.tooltipType, typeText .. "|r")
            else
                BlzFrameSetText(buffData.tooltipType, SPECIAL_TEXT_COLOR .. buffData.type .. "|r")
            end
        else
            BlzFrameSetText(buffData.tooltipType, "")
        end
        BlzFrameSetSize(buffData.tooltipText, TOOLTIP_WIDTH, 0.0)
        BlzFrameSetSize(buffData.tooltipParent, TOOLTIP_WIDTH + 0.01, BlzFrameGetHeight(buffData.tooltipText) + 0.031)

        BlzFrameSetVisible(buffData.stacksFrame, false)
    end

    local function GetBuffTooltip(buffData)
        local tooltip = buffData.rawTooltip
        if buffData.adjustedValues then
            local isPercent, isNegative, isMinute
            for key, value in pairs(buffData.adjustedValues) do
                if type(value) == "string" then
                    tooltip = tooltip:gsub("!" .. key .. "!")
                elseif type(value) == "number" then
                    isPercent = tooltip:find("!\x25-?" .. key .. ",m?\x25$?m?\x25\x25") ~= nil
                    isMinute = buffData.rawTooltip:find("!" .. key .. ",\x25\x25?\x25$?\x25\x25?m") ~= nil
                    isNegative = tooltip:find("!\x25-" .. key) ~= nil

                    if isPercent then
                        if isNegative then
                            tooltip = tooltip:gsub("!\x25-" .. key .. ",.?.?!", floor(-100*value + 0.5) .. "\x25\x25|r")
                        else
                            tooltip = tooltip:gsub("!" .. key .. ",.?.?!", floor(100*value + 0.5) .. "\x25\x25|r")
                        end
                    else
                        if isNegative then
                            tooltip = tooltip:gsub("!\x25-" .. key .. ",?.?.?!", (-tointeger(value) or -value) .. "|r")
                        elseif isMinute then
                            tooltip = tooltip:gsub("!" .. key .. ",?.?.?!", (tointeger(value/60) or value/60) .. "|r")
                        else
                            tooltip = tooltip:gsub("!" .. key .. ",?.?.?!", (tointeger(value) or value) .. "|r")
                        end
                    end
                end
            end
        end
        return tooltip
    end

    local function SetBuffValues(buffData)
        if buffData.values then
            buffData.adjustedValues = buffData.adjustedValues or {}
            local adjustedValues = buffData.adjustedValues

            local isStatic, isFromField, fieldValue, valueType
            local level = buffData.level
            local stacks = buffData.stacks
            for key, value in pairs(buffData.values) do
                isStatic = buffData.rawTooltip:find("!\x25-?" .. key .. ",m?\x25\x25?m?\x25$") ~= nil or key:find("Const") ~= nil or key == "duration"
                isFromField = buffData.ability and type(value) == "string" and value:len() == 4

                valueType = type(value)
                if valueType == "table" then
                    adjustedValues[key] = stacks*(tointeger(value[level]) or value[level])
                elseif valueType == "function" then
                    adjustedValues[key] = value(buffData.unit, buffData.source, level, stacks)
                elseif isFromField then
                    fieldValue = GetAbilityField(buffData.ability, value, level)
                    adjustedValues[key] = stacks*(tointeger(fieldValue) or fieldValue)
                elseif isStatic then
                    adjustedValues[key] = tointeger(value) or value
                elseif valueType == "number" then
                    adjustedValues[key] = stacks*(tointeger(level*value) or level*value)
                else
                    adjustedValues[key] = value
                end
            end
        end
    end

    local function ExpireBuff(buffData)
        local unit = buffData.unit

        buffCheckers[unit][buffData.name] = nil

        if buffData.buff then
            if buffData.buffApplied then
                UnitRemoveAbility(unit, buffData.buff)
            else
                buffData.danglingBuff = true
                return
            end
        end

        for i = buffData.buffNumber + 1, numberOfBuffs[unit] do
            buffList[unit][i - 1] = buffList[unit][i]
            buffList[unit][i].buffNumber = i - 1
        end

        buffList[unit][numberOfBuffs[unit]] = nil
        numberOfBuffs[unit] = numberOfBuffs[unit] - 1

        if buffData.isShownInBuffBar then
            FrameRecycler.Return(buffData.parentFrame)
            for i = 1, numberOfBuffs[unit] do
                if not buffList[unit][i].isHidden then
                    BlzFrameSetAbsPoint(buffList[unit][i].parentFrame, FRAMEPOINT_BOTTOMLEFT, GetIconX(i, unit), BUFF_BAR_Y)
                end
            end
        end

        thisUnit = unit
        thisBuffData = buffData
        if buffData.onExpire then
            buffData.onExpire(unit, buffData.source, buffData.adjustedValues, buffData.level, buffData.stacks)
        end
        if buffData.adjustedValues then
            for __, statData in ipairs(customStats) do
                if buffData.adjustedValues[statData.name] then
                    if statData.onExpire then
                        statData.onExpire(unit, buffData.source, buffData.adjustedValues[statData.name], buffData.name)
                    end
                end
            end
        end

        if buffData.visual then
            if type(buffData.visual) == "table" then
                for __, effect in ipairs(buffData.visual) do
                    DestroyEffect(effect)
                end
            else
                DestroyEffect(buffData.visual)
            end
        end
    end

    local function ApplyEffects(buffData, unit)
        if type(buffData.effect) == "table" then
            buffData.visual = {}
            for index, effectPath in ipairs(buffData.effect) do
                buffData.visual[index] = AddSpecialEffectTarget(effectPath, unit, buffData.attachPoint and (type(buffData.attachPoint) == "table" and buffData.attachPoint[index] or buffData.attachPoint) or "origin")
            end
        elseif type(buffData.attachPoint) == "table" then
            buffData.visual = {}
            for index, attachPoint in ipairs(buffData.attachPoint) do
                buffData.visual[index] = AddSpecialEffectTarget(buffData.effect, unit, attachPoint)
            end
        else
            buffData.visual = AddSpecialEffectTarget(buffData.effect, unit, buffData.attachPoint or "origin")
        end
    end

    local function ApplyBuff(buffData)
        local unit = buffData.unit

        buffData.buffApplied = true
        local owner = GetOwningPlayer(unit)

        numberOfBuffs[unit] = numberOfBuffs[unit] + 1
        buffData.buffNumber = numberOfBuffs[unit]
        buffList[unit][numberOfBuffs[unit]] = buffData

        if USE_BUFF_BAR and unit == mainUnit and not buffData.isHidden then
            if localPlayer == owner then
                buffData.isShownInBuffBar = true
                SetBuffFrame(buffData, unit)

                if BUFF_BAR_ALIGNMENT == "center" then
                    for i = 1, numberOfBuffs[unit] - 1 do
                        BlzFrameSetAbsPoint(buffList[unit][i].parentFrame, FRAMEPOINT_BOTTOMLEFT, GetIconX(i, unit), BUFF_BAR_Y)
                    end
                end
            end
        end

        thisUnit = unit
        thisBuffData = buffData
        if buffData.onFirstApply then
            buffData.onFirstApply(unit, buffData.source, buffData.adjustedValues, buffData.level)
        end
        if buffData.onApply then
            buffData.onApply(unit, buffData.source, buffData.adjustedValues, buffData.level, buffData.stacks)
        end
        if buffData.adjustedValues then
            for __, statData in ipairs(customStats) do
                if buffData.adjustedValues[statData.name] then
                    if statData.onFirstApply then
                        statData.onFirstApply(unit, buffData.source, buffData.adjustedValues[statData.name], buffData.name)
                    end
                    if statData.onApply then
                        statData.onApply(unit, buffData.source, buffData.adjustedValues[statData.name], 0, buffData.name)
                    end
                end
            end
        end

        if buffData.effect then
            ApplyEffects(buffData, unit)
        end

        if buffData.danglingBuff then
            ExpireBuff(buffData)
        end
    end

    local function CheckBuff(buffData)
        if buffData.buff and not buffData.buffApplied then
            if GetUnitAbilityLevel(buffData.unit, buffData.buff) > 0 then
                ApplyBuff(buffData)
            else
                buffData.waitingForBuffTime = (buffData.waitingForBuffTime or 0) + ALICE_Config.MIN_INTERVAL
                if buffData.waitingForBuffTime > MAXIMUM_NATIVE_BUFF_WAIT_TIME then
                    buffCheckers[buffData.unit][buffData.name] = nil
                    ALICE_DisableCallback()
                end
            end
        elseif buffData.buff and GetUnitAbilityLevel(buffData.unit, buffData.buff) == 0 then
            ExpireBuff(buffData)
            ALICE_DisableCallback()
        else
            if buffData.isShownInBuffBar and buffData.fallOffPoint and ALICE_TimeElapsed > buffData.fallOffPoint - FLICKER_DURATION then
                local alpha = FLICKER_MIN_ALPHA + ((255 - FLICKER_MIN_ALPHA)*(1 + cos(2*bj_PI*buffData.counter*ALICE_Config.MIN_INTERVAL/FLICKER_CYCLE_LENGTH))/2) // 1
                BlzFrameSetAlpha(buffData.parentFrame, alpha)
                if ALICE_TimeElapsed > buffData.fallOffPoint - FLICKER_FAST_DURATION then
                    buffData.counter = buffData.counter + 2
                else
                    buffData.counter = buffData.counter + 1
                end
            end
            if buffData.stackFallOffPoints then
                local max
                for i = buffData.stacks, 1, -1 do
                    max = max and math.max(max, buffData.stackFallOffPoints[i]) or buffData.stackFallOffPoints[i]
                    if ALICE_TimeElapsed > buffData.stackFallOffPoints[i] then
                        if buffData.stacks == 1 then
                            ExpireBuff(buffData)
                            ALICE_DisableCallback()
                            return
                        else
                            buffData.stackFallOffPoints[i] = buffData.stackFallOffPoints[buffData.stacks]
                            buffData.stackFallOffPoints[buffData.stacks] = nil
                            buffData.stacks = buffData.stacks - 1
                            SetBuffValues(buffData)
                            buffData.tooltip = GetBuffTooltip(buffData)
                            if buffData.isShownInBuffBar then
                                if buffData.stacks == 1 then
                                    BlzFrameSetVisible(buffData.stacksFrame, false)
                                else
                                    BlzFrameSetText(buffData.stacksFrame, STACKS_COLOR .. buffData.stacks .. "|r")
                                end
                            end
                        end
                    end
                end

                if buffData.isShownInBuffBar then
                    if USE_BUFF_BAR_TIME_REMAINING_TEXT then
                        BlzFrameSetText(buffData.textFrame, GetDurationText(max - ALICE_TimeElapsed))
                    end
                    BlzFrameSetText(buffData.tooltipText, USE_TOOLTIP_TIME_REMAINING_TEXT and (buffData.tooltip .. "|n" .. GetDurationTextExtended(max - ALICE_TimeElapsed)) or buffData.tooltip)
                    BlzFrameSetSize(buffData.tooltipText, TOOLTIP_WIDTH, 0.0)
                    BlzFrameSetSize(buffData.tooltipParent, TOOLTIP_WIDTH + 0.01, BlzFrameGetHeight(buffData.tooltipText) + 0.031)
                end
            elseif buffData.fallOffPoint then
                if ALICE_TimeElapsed > buffData.fallOffPoint then
                    ExpireBuff(buffData)
                    ALICE_DisableCallback()
                    return
                end
                if buffData.isShownInBuffBar then
                    if USE_BUFF_BAR_TIME_REMAINING_TEXT then
                        BlzFrameSetText(buffData.textFrame, GetDurationText(buffData.fallOffPoint - ALICE_TimeElapsed))
                    end
                    BlzFrameSetText(buffData.tooltipText, USE_TOOLTIP_TIME_REMAINING_TEXT and (buffData.tooltip .. "|n" .. GetDurationTextExtended(buffData.fallOffPoint - ALICE_TimeElapsed)) or buffData.tooltip)
                    BlzFrameSetSize(buffData.tooltipText, TOOLTIP_WIDTH, 0.0)
                    BlzFrameSetSize(buffData.tooltipParent, TOOLTIP_WIDTH + 0.01, BlzFrameGetHeight(buffData.tooltipText) + 0.031)
                end
            end
            if buffData.onPeriodic and (buffData.cooldown == nil or ALICE_PairCooldown(buffData.cooldown) == 0) and buffData.firstPeriodic <= ALICE_TimeElapsed then
                thisUnit = buffData.unit
                thisBuffData = buffData
                buffData.onPeriodic(buffData.unit, buffData.source, buffData.adjustedValues, buffData.level, buffData.stacks)
            end
        end
    end

    OnInit.final(function()
        if USE_BUFF_BAR and not BlzLoadTOCFile("BuffBot.toc") then
            print("|cffff0000Warning:|r Failed to load BuffBot.toc.")
            return
        end

        localPlayer = GetLocalPlayer()

        AURA_INTERACTIONS = {
            unit = ApplyAura,
            self = ApplyAura
        }

        if USE_BUFF_BAR then
            buffBarParent = BlzCreateFrameByType("FRAME", "buffBarParent", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
            BlzFrameSetLevel(buffBarParent, 1)
            BlzFrameSetEnable(buffBarParent, false)

            FrameRecycler.Define("buffIcon", true, function()
                local frame = BlzCreateFrame("BuffIcon", buffBarParent, 0, 0)

                local iconFrame = BlzFrameGetChild(frame, 0)
                local textFrame = BlzFrameGetChild(frame, 1)
                local stacksFrame = BlzFrameGetChild(frame, 2)

                BlzFrameSetAbsPoint(frame, FRAMEPOINT_BOTTOMLEFT, BUFF_BAR_X, BUFF_BAR_Y)
                BlzFrameSetSize(frame, BUFF_BAR_ICON_SIZE, BUFF_BAR_ICON_SIZE)
                BlzFrameSetPoint(iconFrame, FRAMEPOINT_BOTTOMLEFT, frame, FRAMEPOINT_BOTTOMLEFT, 0, 0)
                BlzFrameSetPoint(iconFrame, FRAMEPOINT_TOPRIGHT, frame, FRAMEPOINT_TOPRIGHT, 0, 0)

                BlzFrameSetTextAlignment(textFrame, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
                BlzFrameSetPoint(textFrame, FRAMEPOINT_BOTTOMLEFT, frame, FRAMEPOINT_BOTTOMLEFT, 0, -BUFF_BAR_TEXT_HEIGHT)
                BlzFrameSetPoint(textFrame, FRAMEPOINT_TOPRIGHT, frame, FRAMEPOINT_BOTTOMRIGHT, 0, 0)
                BlzFrameSetEnable(textFrame, false)

                BlzFrameSetTextAlignment(stacksFrame, TEXT_JUSTIFY_BOTTOM, TEXT_JUSTIFY_RIGHT)
                BlzFrameSetPoint(stacksFrame, FRAMEPOINT_BOTTOMLEFT, iconFrame, FRAMEPOINT_BOTTOMLEFT, 0, STACKS_FRAME_VERTICAL_INSET)
                BlzFrameSetPoint(stacksFrame, FRAMEPOINT_TOPRIGHT, iconFrame, FRAMEPOINT_TOPRIGHT, -STACKS_FRAME_HORIZONTAL_INSET, 0)
                BlzFrameSetEnable(stacksFrame, false)

                local tooltip = BlzCreateFrame("BuffIconTooltip", frame, 0, 0)
                local tooltipType = BlzFrameGetChild(tooltip, 1)
                BlzFrameSetPoint(tooltip, FRAMEPOINT_TOPLEFT, iconFrame, FRAMEPOINT_BOTTOMRIGHT, 0, 0)
                BlzFrameSetTextAlignment(tooltipType, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_RIGHT)
                BlzFrameSetTooltip(frame, tooltip)
                tooltipOfIcon[frame] = tooltip

                return frame
            end)

            FrameRecycler.Allocate("buffIcon", MAX_NUMBER_OF_BUFFS)
        end

        local trig = CreateTrigger()
        TriggerRegisterAnyUnitEventBJ(trig, EVENT_PLAYER_UNIT_DEATH)
        TriggerAddAction(trig, function()
            BuffBot.DispelAll(GetTriggerUnit())
        end)

        if ALICE_FuncSetOnReset then
            ALICE_FuncSetOnReset(ApplyAura, ApplyAuraOnReset)
            ALICE_FuncSetName(ApplyAura, "ApplyAura")
        end
    end)

    BuffBot = {
        ---Sets the specified unit to the unit for which buffs are shown in the buff bar for the specified player.
        ---@param whichPlayer player
        ---@param newUnit unit
        SetMainUnit = function(whichPlayer, newUnit)
            if whichPlayer ~= localPlayer then
                return
            end

            if mainUnit then
                for __, buffData in ipairs(buffList[mainUnit]) do
                    if buffData.isShownInBuffBar then
                        FrameRecycler.Return(buffData.parentFrame)
                    end
                    buffData.isShownInBuffBar = nil
                end
            end

            mainUnit = newUnit

            for __, buffData in ipairs(buffList[newUnit]) do
                if not buffData.isHidden then
                    buffData.isShownInBuffBar = true
                    SetBuffFrame(buffData, newUnit)
                end
            end
            for i, buffData in ipairs(buffList[newUnit]) do
                if not buffData.isHidden then
                    BlzFrameSetAbsPoint(buffData.parentFrame, FRAMEPOINT_BOTTOMLEFT, GetIconX(i, newUnit), BUFF_BAR_Y)
                end
            end
        end,

        ---Applies a buff to the specified unit with the data provided in the data table. Returns whether the buff was successfully applied. The recognized fields are:
        -- - tooltip?            string
        -- - name?               string
        -- - buff?               string | integer
        -- - ability?            string | integer
        -- - order?              string | integer
        -- - duration?           number
        -- - type?               string | string[]
        -- - icon?               string
        -- - color?              string
        -- - values?             table<string, any>
        -- - onApply?            function(target, source, values, level, stacks)
        -- - onFirstApply?       function(target, source, values, level)
        -- - onExpire?           function(target, source, values, level, stacks)
        -- - onPeriodic?         function(target, source, values, level, stacks)
        -- - cooldown?           number
        -- - delay?              number
        -- - isEternal?          boolean
        -- - cannotOverwrite?    boolean
        -- - effect?             string | string[]
        -- - attachPoint?        string | string[]
        -- - showLevel?          boolean
        -- - maxStacks?          integer
        -- - individualFallOff?  boolean
        -- - isHidden?           boolean
        ---@param whichUnit unit
        ---@param data table
        ---@param source? unit
        ---@param level? integer
        ---@return boolean
        Apply = function(whichUnit, data, source, level)
            if whichUnit == nil or not UnitAlive(whichUnit) then
                return false
            end
            if ValidateTable then
                ValidateTable(data, nil, BUFF_RECOGNIZED_FIELDS, nil)
            end

            local ability = type(data.ability) == "string" and FourCC(data.ability) or data.ability
            local name = data.name or ability and BlzGetAbilityTooltip(ability, 0) or error("Required field name missing in data table.")
            level = level or (ability and (source and GetUnitAbilityLevel(source, ability) > 0 and GetUnitAbilityLevel(source, ability) or GetUnitAbilityLevel(whichUnit, ability) > 0 and GetUnitAbilityLevel(whichUnit, ability))) or 1

            if buffCheckers[whichUnit][name] == nil then
                local buff = type(data.buff) == "string" and FourCC(data.buff) or data.buff
                local icon = data.icon or ability and BlzGetAbilityIcon(ability) or nil
                local duration
                if not data.isEternal then
                    duration = GetForBuff(data.duration, source, whichUnit, level, 1)
                    if not duration then
                        if data.values then
                            duration = GetForBuff(data.values.duration, source, whichUnit, level, 1)
                        end
                        if data.ability and GetUnitAbilityField then
                            if not duration then
                                duration = GetUnitAbilityField(source or whichUnit, data.ability, IsUnitType(whichUnit, UNIT_TYPE_HERO) and "ahdu" or "adur")
                            end
                            if not duration or duration == 0 then
                                duration = GetAbilityField(data.ability, IsUnitType(whichUnit, UNIT_TYPE_HERO) and "ahdu" or "adur", level)
                            end
                        end
                    end
                end

                local buffData = {
                    unit = whichUnit,
                    source = source,
                    fallOffPoint = duration and (ALICE_TimeElapsed + duration) or nil,
                    counter = 0,
                    buff = buff,
                    level = level,
                    rawTooltip = GetForBuff(data.tooltip or "", source, whichUnit, level, 1),
                    stacks = 1,
                    icon = icon or "ReplaceableTextures\\CommandButtons\\BTNTemp.blp",
                    name = name,
                    firstPeriodic = ALICE_TimeElapsed + (data.delay or 0)
                }

                if duration then
                    if data.individualFallOff then
                        buffData.stackFallOffPoints = {ALICE_TimeElapsed + duration}
                    end
                    buffData.fallOffPoint = ALICE_TimeElapsed + duration
                end

                for field, value in pairs(data) do
                    if not BUFF_IGNORED_FIELDS[field] then
                        buffData[field] = value
                    end
                end

                if data.type then
                    buffData.types = {}
                    if type(data.type) == "table" then
                        for subtype, __ in pairs(data.type) do
                            buffData.types[subtype] = true
                        end
                    else
                        buffData.types[data.type] = true
                    end
                end

                SetBuffValues(buffData)
                buffData.tooltip = GetBuffTooltip(buffData)

                if not buffData.buff then
                    ApplyBuff(buffData)
                end

                buffCheckers[whichUnit][name] = ALICE_CallPeriodic(CheckBuff, nil, buffData)
            else
                local buffData = buffCheckers[whichUnit][name][1]
                if (buffData.duration == nil or buffData.cannotOverwrite) and buffData.level > level then
                    return false
                end

                if buffData.maxStacks and buffData.stacks < buffData.maxStacks then
                    buffData.stacks = buffData.stacks + 1
                    if buffData.isShownInBuffBar then
                        BlzFrameSetText(buffData.stacksFrame, STACKS_COLOR .. buffData.stacks .. "|r")
                        BlzFrameSetVisible(buffData.stacksFrame, true)
                    end
                end

                local duration
                if not data.isEternal then
                    duration = GetForBuff(data.duration, source, whichUnit, level, 1)
                    if not duration then
                        if data.values then
                            duration = GetForBuff(data.values.duration, source, whichUnit, level, 1)
                        end
                        if data.ability and GetUnitAbilityField then
                            if not duration then
                                duration = GetUnitAbilityField(source or whichUnit, data.ability, IsUnitType(whichUnit, UNIT_TYPE_HERO) and "ahdu" or "adur")
                            end
                            if not duration or duration == 0 then
                                duration = GetAbilityField(data.ability, IsUnitType(whichUnit, UNIT_TYPE_HERO) and "ahdu" or "adur", level)
                            end
                        end
                    end
                end

                if duration then
                    if buffData.individualFallOff then
                        table.insert(buffData.stackFallOffPoints, ALICE_TimeElapsed + duration)
                    end
                    buffData.fallOffPoint = ALICE_TimeElapsed + duration
                end

                buffData.duration = duration
                buffData.level = level
                if buffData.isShownInBuffBar then
                    BlzFrameSetAlpha(buffData.parentFrame, 255)
                end

                if buffData.adjustedValues then
                    for __, customStat in ipairs(customStats) do
                        tempCustomStatValues[customStat.name] = buffData.adjustedValues[customStat.name]
                    end
                end

                for field, value in pairs(data) do
                    if not BUFF_IGNORED_FIELDS[field] then
                        buffData[field] = value
                    end
                end

                BlzFrameSetText(buffData.tooltipTitle, (buffData.color and buffData.color .. buffData.name .. "|r" or buffData.name) .. (buffData.showLevel and LEVEL_COLOR .. " (Level " .. buffData.level .. ")|r" or ""))

                SetBuffValues(buffData)
                buffData.tooltip = GetBuffTooltip(buffData)
                if buffData.fallOffPoint then
                    BlzFrameSetText(buffData.tooltipText, USE_TOOLTIP_TIME_REMAINING_TEXT and (buffData.tooltip .. "|n" .. GetDurationTextExtended(buffData.fallOffPoint - ALICE_TimeElapsed)) or data.tooltip)
                else
                    BlzFrameSetText(buffData.tooltipText, buffData.tooltip)
                end
                BlzFrameSetSize(buffData.tooltipText, TOOLTIP_WIDTH, 0.0)
                BlzFrameSetSize(buffData.tooltipParent, TOOLTIP_WIDTH + 0.01, BlzFrameGetHeight(buffData.tooltipText) + 0.031)

                if buffData.effect and not data.auraBuff then
                    if type(buffData.visual) == "table" then
                        for __, effect in ipairs(buffData.visual) do
                            DestroyEffect(effect)
                        end
                    else
                        DestroyEffect(buffData.visual)
                    end
                    ApplyEffects(buffData, whichUnit)
                end

                if buffData.onApply then
                    buffData.onApply(whichUnit, buffData.source, buffData.values, buffData.level, buffData.stacks)
                end
                if buffData.adjustedValues then
                    for __, statData in ipairs(customStats) do
                        if buffData.adjustedValues[statData.name] then
                            if statData.onApply then
                                statData.onApply(whichUnit, buffData.source, buffData.adjustedValues[statData.name], tempCustomStatValues[statData.name], buffData.name)
                            end
                        end
                    end
                end
            end

            if data.ability and data.order then
                CastDummyAbility(whichUnit, ability, data.order, level)
            end

            return true
        end,

        ---Returns the data table of a specific buff active on the specified unit. The buff is referenced by its name. If called from a buff callback function, parameters can be omitted.
        ---@param whichUnit? unit
        ---@param whichBuff? string
        ---@return table | nil
        GetData = function(whichUnit, whichBuff)
            whichUnit = whichUnit or thisUnit
            if whichUnit == nil then
                return nil
            end
            if whichBuff then
                if buffCheckers[whichUnit][whichBuff] == nil then
                    return nil
                else
                    return buffCheckers[whichUnit][whichBuff][1]
                end
            else
                return thisBuffData
            end
        end,

        ---Returns the level of a specific buff active on the specified unit. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return integer
        GetLevel = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return 0
            end
            if buffCheckers[whichUnit][whichBuff] == nil then
                return 0
            else
                return buffCheckers[whichUnit][whichBuff][1].level
            end
        end,

        ---Returns whether the specified unit has a specific buff. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return boolean
        HasBuff = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return false
            end
            return buffCheckers[whichUnit][whichBuff] ~= nil
        end,

        ---Returns whether the specified unit has a buff that has a value with the specified key in its values table. If valueAmount is set, the value must be exactly the specified amount. Otherwise, it suffices if it is neither false or nil. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param valueKey string
        ---@param valueAmount? any
        ---@return boolean
        HasBuffWithValue = function(whichUnit, valueKey, valueAmount)
            if whichUnit == nil then
                return false
            end

            for __, buffData in ipairs(buffList[whichUnit]) do
                if buffData.adjustedValues and (valueAmount and buffData.adjustedValues[valueKey] == valueAmount or buffData.adjustedValues[valueKey]) then
                    return true
                end
            end
            return false
        end,

        ---Returns the number of stacks of a specific buff active on the specified unit. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return integer
        GetStacks = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return 0
            end
            if buffCheckers[whichUnit][whichBuff] == nil then
                return 0
            else
                return buffCheckers[whichUnit][whichBuff][1].stacks
            end
        end,

        ---Add a stack to a specific buff on a unit without resetting the buff duration. Does not work for buffs that use individualFallOff. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        AddStack = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return
            end
            local buffData = buffChecker[1]

            if buffData.stacks == buffData.maxStacks then
                return
            end
            buffData.stacks = buffData.stacks + 1

            if buffData.isShownInBuffBar then
                BlzFrameSetText(buffData.stacksFrame, STACKS_COLOR .. buffData.stacks .. "|r")
                BlzFrameSetVisible(buffData.stacksFrame, true)
            end
            SetBuffValues(buffData)
            buffData.tooltip = GetBuffTooltip(buffData)
        end,

        ---Sets the number of stacks of a specific buff on a unit to the specified amount without resetting the buff duration. Does not work for buffs that use individualFallOff. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@param howMany integer
        SetStacks = function(whichUnit, whichBuff, howMany)
            if whichUnit == nil then
                return
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return
            end
            local buffData = buffChecker[1]

            if howMany == 0 then
                BuffBot.Dispel(whichUnit, whichBuff)
            else
                howMany = math.min(buffData.maxStacks, howMany)
                buffData.stacks = howMany

                if buffData.isShownInBuffBar then
                    BlzFrameSetText(buffData.stacksFrame, STACKS_COLOR .. buffData.stacks .. "|r")
                    BlzFrameSetVisible(buffData.stacksFrame, howMany > 1)
                end
                SetBuffValues(buffData)
                buffData.tooltip = GetBuffTooltip(buffData)
            end
        end,

        ---Returns the table containing all buffs that are active on the specified unit.
        ---@param whichUnit unit
        ---@return table
        GetAllBuffs = function(whichUnit)
            if whichUnit == nil then
                return {}
            end
            return buffList[whichUnit]
        end,

        ---Returns the value with the whichValue key in the values table stored for the specified buff at the current level of that buff on the specified unit, multiplied by the number of stacks. Returns 0 if that buff is not active on that unit. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@param whichValue string
        ---@return any
        GetValue = function(whichUnit, whichBuff, whichValue)
            if whichUnit == nil then
                return 0
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return 0
            else
                return buffChecker[1].adjustedValues[whichValue]
            end
        end,

        ---Loops through all buffs active on the specified unit, retrieves the values stored under the specified key in their values tables, and returns their sum.
        ---@param whichUnit unit
        ---@param whichValue string
        ---@return any
        GetTotalValue = function(whichUnit, whichValue)
            if whichUnit == nil then
                return 0
            end

            local total = 0
            for __, buffData in ipairs(buffList[whichUnit]) do
                if buffData.adjustedValues and buffData.adjustedValues[whichValue] then
                    total = total + buffData.adjustedValues[whichValue]
                end
            end
            return total
        end,

        ---Returns the remaining duration of a buff on a unit. Returns 0 if that buff is not active on that unit. Returns inf if the buff is eternal. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return number
        GetRemainingDuration = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return 0
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return 0
            else
                local buffData = buffChecker[1]
                if buffData.fallOffPoint then
                    return buffData.fallOffPoint - ALICE_TimeElapsed
                else
                    return math.huge
                end
            end
        end,

        ---Returns the total duration of a buff on a unit. Returns 0 if that buff is not active on that unit. Returns inf if the buff is eternal. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return number
        GetFullDuration = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return 0
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return 0
            else
                local buffData = buffChecker[1]
                if buffData.fallOffPoint then
                    return buffData.duration
                else
                    return math.huge
                end
            end
        end,

        ---Returns the source of a buff on a unit. The buff is referenced by its name.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@return unit | nil
        GetSource = function(whichUnit, whichBuff)
            if whichUnit == nil then
                return nil
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return nil
            else
                return buffChecker[1].source
            end
        end,

        ---Dispels a specific buff from the specified unit. The optional reduceStacks flag controls whether only one stack should be removed from that unit if multiple stacks are applied. The buff is referenced by its name. Returns whether a buff was dispelled.
        ---@param whichUnit unit
        ---@param whichBuff string
        ---@param reduceStacks? boolean
        Dispel = function(whichUnit, whichBuff, reduceStacks)
            if whichUnit == nil then
                return
            end
            local buffChecker = buffCheckers[whichUnit][whichBuff]
            if buffChecker == nil then
                return false
            else
                local buffData = buffChecker[1]
                if not reduceStacks or buffData.stacks == 1 then
                    ExpireBuff(buffData)
                    ALICE_DisableCallback(buffChecker)
                else
                    buffData.stacks = buffData.stacks - 1
                    BlzFrameSetText(buffData.stacksFrame, STACKS_COLOR .. buffData.stacks .. "|r")
                    BlzFrameSetVisible(buffData.stacksFrame, buffData.stacks > 1)
                    SetBuffValues(buffData)
                    buffData.tooltip = GetBuffTooltip(buffData)
                end

                return true
            end
        end,

        ---Dispels from the specified unit all buffs of the specified type or of all types if type is not set. The optional reduceStacks flag controls whether only one stack of each buff should be removed from that unit if multiple stacks are applied. Returns the number of buffs that were dispelled.
        ---@param whichUnit unit
        ---@param type? string
        ---@param reduceStacks? boolean
        ---@return integer
        DispelAll = function(whichUnit, type, reduceStacks)
            if whichUnit == nil then
                return 0
            end
            local buffs = {}
            local numDispels = 0
            local i = 1
            for name, __ in pairs(buffCheckers[whichUnit]) do
                buffs[i] = name
                i = i + 1
            end
            table.sort(buffs)

            local buffData
            for __, name in ipairs(buffs) do
                buffData = buffCheckers[whichUnit][name][1]
                if type == nil or buffData.types and buffData.types[type] then
                    BuffBot.Dispel(whichUnit, name, reduceStacks)
                    numDispels = numDispels + 1
                end
            end
            return numDispels
        end,

        ---Dispels a random buff from the specified unit. If the optional type flag is set, only buffs of that type will be considered. The optional reduceStacks flag controls whether only one stack should be removed from that unit if multiple stacks are applied. Returns whether a buff was dispelled.
        ---@param whichUnit unit
        ---@param type? string
        ---@param reduceStacks? boolean
        ---@return boolean
        DispelRandom = function(whichUnit, type, reduceStacks)
            if whichUnit == nil then
                return false
            end
            local buffs = {}
            local eligibleBuffs = {}
            local i = 1
            for name, __ in pairs(buffCheckers[whichUnit]) do
                buffs[i] = name
                i = i + 1
            end
            table.sort(buffs[i])

            local buffData
            for __, name in ipairs(buffs) do
                buffData = buffCheckers[whichUnit][name][1]
                if type == nil or buffData.types and buffData.types[type] then
                    eligibleBuffs[#eligibleBuffs + 1] = name
                end
            end

            if #eligibleBuffs > 0 then
                BuffBot.Dispel(whichUnit, eligibleBuffs[GetRandomInt(1, #eligibleBuffs)], reduceStacks)
                return true
            else
                return false
            end
        end,

        ---Shows or hides the buff bar for the specified player or for all players if not specified.
        ---@param enable? boolean
        ---@param whichPlayer? player
        ShowBar = function(enable, whichPlayer)
            if whichPlayer and localPlayer ~= whichPlayer then
                return
            end

            BlzFrameSetVisible(buffBarParent, enable ~= false)
        end,

        ---Define a custom stat that will automatically invoke callback functions when present in a buff's values table. The statData table defines up to three callback functions:
        -- - onFirstApply(whichUnit, source, amount, buffName): Invoked when a buff with the defined stat is first applied.
        -- - onApply(whichUnit, source, amount, oldAmount, buffName): Invoked everytime the buff is applied. oldAmount is set if the buff is already present on the unit.
        -- - onExpire(whichUnit, source, amount, buffName): Invoked when the buff expires.
        ---@param statName string
        ---@param statData table<"onFirstApply" | "onApply" | "onExpire", fun(target, source, value, oldAmount?, buffName)>
        DefineStat = function(statName, statData)
            customStats[#customStats + 1] = {
                name = statName,
                onFirstApply = statData.onFirstApply,
                onApply = statData.onApply,
                onExpire = statData.onExpire
            }
        end,

        ---Creates an aura from the auraData table for the specified unit that automatically applies the buff provided in the buffData table to nearby units. The condition is a function that is called with the arguments (source, target) and should return a boolean that controls whether the target unit is affected by the aura.
        ---
        ---The recognized fields for auraData are:
        -- - name                string
        -- - range               number | function(source, level)
        -- - condition?          function(source, target, level)
        -- - effect?             string
        -- - attachPoint?        string
        -- - accuracy?           number
        -- - effectOnSelf?       boolean
        ---
        ---The recognized fields for buffData are:
        -- - tooltip             string
        -- - buff?               string | integer
        -- - ability?            string | integer
        -- - order?              string | integer
        -- - source?             unit
        -- - type?               string | string[]
        -- - icon?               string
        -- - color?              string
        -- - values?             table<string, number|string>
        -- - onApply?            function(target, source, values, level, stacks)
        -- - onFirstApply?       function(target, source, values, level)
        -- - onExpire?           function(target, source, values, level, stacks)
        -- - onPeriodic?         function(target, source, values, level, stacks)
        -- - cooldown?           number
        -- - delay?              number
        -- - effect?             string | string[]
        -- - attachPoint?        string | string[]
        -- - showLevel?          boolean
        ---@param source Object
        ---@param auraData table
        ---@param buffData table
        ---@param level? integer
        CreateAura = function(source, auraData, buffData, level)
            if ValidateTable then
                ValidateTable(auraData, AURA_REQUIRED_FIELDS, AURA_RECOGNIZED_FIELDS, nil)
                ValidateTable(buffData, nil, BUFF_RECOGNIZED_FIELDS, nil)
            end

            local range = GetForAura(auraData.range, source, level)
            local self = {
                identifier = {"auraSource", ToCamelCase(auraData.name)},
                interactions = AURA_INTERACTIONS,
                anchor = source,
                radius = range,
                range = range,
                condition = auraData.condition,
                accuracy = auraData.accuracy or 1,
                visual = auraData.effect and AddSpecialEffectTarget(auraData.effect, source, auraData.attachPoint or "origin") or nil,
                buffData = {},
                level = level or 1,
                auraBuff = true
            }

            for field, value in pairs(buffData) do
                self.buffData[field] = value
            end

            self.buffData.isEternal = true
            self.buffData.name = auraData.name

            ALICE_Create(self)
        end,

        ---Destroys the aura with the specified name attached to the specified unit.
        ---@param whichUnit unit
        ---@param auraName string
        DestroyAura = function(whichUnit, auraName)
            ALICE_Kill(ALICE_GetAnchoredObject(whichUnit, ToCamelCase(auraName)))
        end,

        ---Modifies the aura with auraName attached to the specified unit, overwriting all fields in its data tables with the new data provided in the auraData and buffData tables, leaving all unset fields unchanged. To nil a field, pass BuffBot.SET_TO_NIL.
        ---@param whichUnit unit
        ---@param auraName string
        ---@param auraData? table
        ---@param buffData? table
        ---@param level? integer
        ModifyAura = function(whichUnit, auraName, auraData, buffData, level)
            local identifier = ToCamelCase(auraName)
            local auraSource = ALICE_GetAnchoredObject(whichUnit, identifier)

            if auraSource == nil then
                return
            end

            ValidateTable(buffData, nil, BUFF_RECOGNIZED_FIELDS, nil)

            local range = auraData and GetForAura(auraData.range, whichUnit, level) or nil
            if range then
                auraSource.range = range
                ALICE_SetFlag(auraSource, "radius", range)
            end
            local condition = auraData and GetForAura(auraData.condition, whichUnit, level) or nil
            auraSource.condition = condition or auraSource.condition

            auraSource.level = level or auraSource.level

            if auraData then
                auraSource.accuracy = auraData.accuracy or auraSource.accuracy

                if auraData.effect or auraData.attachPoint then
                    DestroyEffect(auraSource.visual)
                    if auraData.effect ~= BuffBot.SET_TO_NIL then
                        auraSource.visual = AddSpecialEffectTarget(auraData.effect, whichUnit, auraData.attachPoint or auraSource.attachPoint or "origin")
                    end
                end
            end

            if buffData then
                for key, value in pairs(buffData) do
                    if value == BuffBot.SET_TO_NIL then
                        auraSource.buffData[key] = nil
                    else
                        auraSource.buffData[key] = value
                    end
                end
            end

            ALICE_ForAllPairsDo(ALICE_PairReset, auraSource, ApplyAura, false, identifier)
        end,

        ---Returns the data table of an aura for which the specified unit is the source. The aura is referenced by its name.
        ---@param whichUnit unit
        ---@param auraName string
        GetAuraData = function(whichUnit, auraName)
            return ALICE_GetAnchoredObject(whichUnit, ToCamelCase(auraName))
        end,

        SET_TO_NIL = {},
    }
end
if Debug then Debug.endFile() end