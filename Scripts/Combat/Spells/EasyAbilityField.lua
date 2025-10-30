if Debug then Debug.beginFile "EasyAbilityFields" end
do
    --[[
    =============================================================================================================================================================
                                                                    Easy Ability Fields
                                                                        by Antares

                                          Call SetAbilityField and GetAbilityField functions without headaches.

                                Requires:
                                TotalInitialization			    https://www.hiveworkshop.com/threads/total-initialization.317099/
                            
    =============================================================================================================================================================
                                                                          A P I
    =============================================================================================================================================================

    GetUnitAbilityField(whichUnit, whichAbility, whichField, level?)
    GetAbilityField(whichAbility, whichField, level?)
    SetUnitAbilityField(whichUnit, whichAbility, whichField, level?)

    whichAbility can be a fourCC code or abilityId.

    whichField can be a string or an abilityfield such as ABILITY_RF_ARF_MISSILE_ARC. For strings, the best way to use it is to look up the fourCC code of the
    ability field in the Object Editor (such as "aran", "slo1") and pass that as the argument. You can also pass the field name, which, for example, for
    ABILITY_IF_BUTTON_POSITION_NORMAL_X would be "buttonPositionNormalX" (capitalization is arbitrary). However, the name is not unique for many fields and the
    may return the wrong value.

    Level is an optional argument. It defaults to the current level of the unit's ability for GetUnitAbilityField and SetUnitAbilityField and to 1 for
    GetAbilityField. The level starts at 1, unlike with native ability field functions.

    =============================================================================================================================================================
    ]]

    local DUMMY_TYPE = "ueaf"

    ---@alias Field string | abilityintegerfield | abilityintegerlevelfield | abilityrealfield | abilityreallevelfield | abilitystringfield | abilitystringlevelfield | abilitybooleanfield | abilitybooleanlevelfield

    local GETTER_FUNCTION_OF_FIELD = {}
    local SETTER_FUNCTION_OF_FIELD = {}

    local GETTER_FUNCTIONS
    local SETTER_FUNCTIONS
    local IS_LEVEL_FUNCTION
    local DEFAULT_RETURN

    local ABILITY_DUMMY

    local abilityFieldValues = setmetatable({}, {
        __index = function(self, key)
            self[key] = {}
            return self[key]
        end
    })
    local abilityLevelFieldValues = setmetatable({}, {
        __index = function(parent, parentKey)
            parent[parentKey] = setmetatable({}, {
                __index = function(child, childKey)
                    child[childKey] = {}
                    return child[childKey]
                end
            })
            return parent[parentKey]
        end
    })
    local unitAbilityFieldValues = setmetatable({}, {
        __mode = "k",
        __index = function(parent, parentKey)
            parent[parentKey] = setmetatable({}, {
                __index = function(child, childKey)
                    child[childKey] = {}
                    return child[childKey]
                end
            })
            return parent[parentKey]
        end
    })
    local unitAbilityLevelFieldValues = setmetatable({}, {
        __mode = "k",
        __index = function(grandParent, grandParentKey)
            grandParent[grandParentKey] = setmetatable({}, {
                __index = function(parent, parentKey)
                    parent[parentKey] = setmetatable({}, {
                        __index = function(child, childKey)
                            child[childKey] = {}
                            return child[childKey]
                        end
                    })
                    return parent[parentKey]
                end
            })
            return grandParent[grandParentKey]
        end
    })

    OnInit.global("EasyAbilityFields", function()
        Require "AbilityFields"

        GETTER_FUNCTIONS = {
            IF = BlzGetAbilityIntegerField,
            ILF = BlzGetAbilityIntegerLevelField,
            RF = BlzGetAbilityRealField,
            RLF = BlzGetAbilityRealLevelField,
            BF = BlzGetAbilityBooleanField,
            BLF = BlzGetAbilityBooleanLevelField,
            SF = BlzGetAbilityStringField,
            SLF = BlzGetAbilityStringLevelField
        }

        SETTER_FUNCTIONS = {
            IF = BlzSetAbilityIntegerField,
            ILF = BlzSetAbilityIntegerLevelField,
            RF = BlzSetAbilityRealField,
            RLF = BlzSetAbilityRealLevelField,
            BF = BlzSetAbilityBooleanField,
            BLF = BlzSetAbilityBooleanLevelField,
            SF = BlzSetAbilityStringField,
            SLF = BlzSetAbilityStringLevelField
        }

        IS_LEVEL_FUNCTION = {
            [BlzGetAbilityIntegerField] = false,
            [BlzGetAbilityIntegerLevelField] = true,
            [BlzGetAbilityRealField] = false,
            [BlzGetAbilityRealLevelField] = true,
            [BlzGetAbilityBooleanField] = false,
            [BlzGetAbilityBooleanLevelField] = true,
            [BlzGetAbilityStringField] = false,
            [BlzGetAbilityStringLevelField] = true,
            [BlzSetAbilityIntegerField] = false,
            [BlzSetAbilityIntegerLevelField] = true,
            [BlzSetAbilityRealField] = false,
            [BlzSetAbilityRealLevelField] = true,
            [BlzSetAbilityBooleanField] = false,
            [BlzSetAbilityBooleanLevelField] = true,
            [BlzSetAbilityStringField] = false,
            [BlzSetAbilityStringLevelField] = true
        }

        DEFAULT_RETURN = {
            [BlzGetAbilityIntegerField] = 0,
            [BlzGetAbilityIntegerLevelField] = 0,
            [BlzGetAbilityRealField] = 0,
            [BlzGetAbilityRealLevelField] = 0,
            [BlzGetAbilityBooleanField] = false,
            [BlzGetAbilityBooleanLevelField] = false,
            [BlzGetAbilityStringField] = "",
            [BlzGetAbilityStringLevelField] = "",
        }

        local lastUnderscore
        local startPos
        local lastWord
        local fieldName
        local fieldType

        for key, value in pairs(_G) do
            if key:find("ABILITY_") and tostring(value):find("field") then
                fieldType = key:sub(9, key:sub(9):find("_") + 7)
                startPos = 0
                repeat
                    startPos = key:find("_", startPos + 1)
                    if startPos then
                        lastUnderscore = startPos
                    end
                until startPos == nil

                lastWord = key:sub(lastUnderscore + 1, key:len()):lower()
                if ABILITY_FIELD_OF_STRING[lastWord:lower()] then
                    fieldName = key:sub(10 + fieldType:len(), key:len() - 5):lower():gsub("_", "")
                else
                    fieldName = key:sub(10 + fieldType:len(), key:len()):lower():gsub("_", "")
                end

                ABILITY_FIELD_OF_STRING[fieldName] = value
                GETTER_FUNCTION_OF_FIELD[value] = GETTER_FUNCTIONS[fieldType]
                SETTER_FUNCTION_OF_FIELD[value] = SETTER_FUNCTIONS[fieldType]
            end
        end

        ABILITY_DUMMY = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC(DUMMY_TYPE), GetRectCenterX(bj_mapInitialPlayableArea), GetRectCenterY(bj_mapInitialPlayableArea), 0)
        ShowUnit(ABILITY_DUMMY, false)
    end)

    ---@param whichUnit unit
    ---@param whichAbility string | integer
    ---@param whichField Field
    ---@param level? integer
    ---@return number | boolean | string | nil
    function GetUnitAbilityField(whichUnit, whichAbility, whichField, level)
        local field = type(whichField) == "string" and ABILITY_FIELD_OF_STRING[whichField:lower()] or whichField
        if field == nil then
            error("Attempted to retrieve unrecognized ability field " .. whichField ".")
        end
        local func = GETTER_FUNCTION_OF_FIELD[field]

        local id = type(whichAbility) == "string" and FourCC(whichAbility) or whichAbility
        local ability = BlzGetUnitAbility(whichUnit, id)
        if ability == nil then
            return DEFAULT_RETURN[func]
        end

        if IS_LEVEL_FUNCTION[func] then
            level = level or GetUnitAbilityLevel(whichUnit, id)
            if unitAbilityLevelFieldValues[whichUnit][id][field][level] == nil then
                unitAbilityLevelFieldValues[whichUnit][id][field][level] = func(ability, field, level - 1)
            end
            return unitAbilityLevelFieldValues[whichUnit][id][field][level]
        else
            if unitAbilityFieldValues[whichUnit][id][field] == nil then
                unitAbilityFieldValues[whichUnit][id][field] = func(ability, field)
            end
            return unitAbilityFieldValues[whichUnit][id][field]
        end
    end

    ---@param whichAbility string | integer
    ---@param whichField Field
    ---@param level? integer
    ---@return number | boolean | string
    function GetAbilityField(whichAbility, whichField, level)
        local field = type(whichField) == "string" and ABILITY_FIELD_OF_STRING[whichField:lower()] or whichField
        if field == nil then
            error("Attempted to retrieve unrecognized ability field " .. whichField ".")
        end
        local func = GETTER_FUNCTION_OF_FIELD[field]

        local id = type(whichAbility) == "string" and FourCC(whichAbility) or whichAbility

        if IS_LEVEL_FUNCTION[func] then
            level = level or 1
            if abilityLevelFieldValues[id][field][level] == nil then
                UnitAddAbility(ABILITY_DUMMY, id)
                local ability = BlzGetUnitAbility(ABILITY_DUMMY, id)
                if ability == nil then
                    error("Invalid ability identifier.")
                end
                abilityLevelFieldValues[id][field][level] = func(ability, field, level - 1)
                UnitRemoveAbility(ABILITY_DUMMY, id)
            end
            return abilityLevelFieldValues[id][field][level]
        else
            if abilityFieldValues[id][field] == nil then
                UnitAddAbility(ABILITY_DUMMY, id)
                local ability = BlzGetUnitAbility(ABILITY_DUMMY, id)
                if ability == nil then
                    error("Invalid ability identifier.")
                end
                abilityFieldValues[id][field] = func(ability, field)
                UnitRemoveAbility(ABILITY_DUMMY, id)
            end
            return abilityFieldValues[id][field]
        end
    end

    ---@param whichUnit unit
    ---@param whichAbility string | integer
    ---@param whichField Field
    ---@param value number | string | boolean
    ---@param level? integer
    function SetUnitAbilityField(whichUnit, whichAbility, whichField, value, level)
        local field = type(whichField) == "string" and ABILITY_FIELD_OF_STRING[whichField:lower()] or whichField
        if field == nil then
            error("Attempted to retrieve unrecognized ability field " .. whichField ".")
        end

        local func = SETTER_FUNCTION_OF_FIELD[field]

        local id = type(whichAbility) == "string" and FourCC(whichAbility) or whichAbility
        local ability = BlzGetUnitAbility(whichUnit, id)
        if ability == nil then
            return
        end

        if IS_LEVEL_FUNCTION[func] then
            level = level or GetUnitAbilityLevel(whichUnit, id)
            if level == 0 then
                return
            end
            func(ability, field, level - 1, value)
            unitAbilityLevelFieldValues[whichUnit][id][field][level] = value
        else
            func(ability, field, value)
            unitAbilityFieldValues[whichUnit][id][field] = value
        end
    end
end
if Debug then Debug.endFile() end