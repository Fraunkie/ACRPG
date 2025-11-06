if not ShardFamilySystem then ShardFamilySystem = {} end
_G.ShardFamilySystem = ShardFamilySystem

do
    --------------------------------------------------
    -- Config / Aliases
    --------------------------------------------------
    -- Fragments (just for currency, no charge cost)
    local FRAGMENT_FAMILIES = {
        DB = "Dragon Ball Fragment",   -- DB
        DIGI = "Digi Fragment",        -- Digi
        POKE = "Poké Fragment",        -- Poke
        CHAKRA = "Chakra Fragment",    -- Chakra
    }

    -- Item type id → fragment family (all DB/Digi/Poke/Chakra)
    local ITEM_TO_FRAGMENT = {
        [FourCC("I00U")] = "DB",     -- Dragon Ball Fragment (I00U)
        [FourCC("I012")] = "DIGI",   -- Digi Fragment (I012)
        [FourCC("I00Z")] = "POKE",   -- Poké Fragment (I00Z)
        [FourCC("I00Y")] = "CHAKRA", -- Chakra Fragment (I00Y)
        [FourCC("I00W")] = "SAIYAN", -- Goku’s Ascension Shard (I00W)
    }

    --------------------------------------------------
    -- Reverse map for FAMILY → ITEMs
    --------------------------------------------------
    local FAMILY_TO_ITEMS = nil
    local function buildReverse()
        if FAMILY_TO_ITEMS then return end
        FAMILY_TO_ITEMS = {}
        for it, fk in pairs(ITEM_TO_FRAGMENT) do
            local list = FAMILY_TO_ITEMS[fk]
            if not list then
                list = {}
                FAMILY_TO_ITEMS[fk] = list
            end
            list[#list + 1] = it
        end
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardFamily] " .. tostring(s)) end
    end

    local function idOfRaw(raw)
        if not raw or raw == "" then return 0 end
        return FourCC(raw)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    -- Get fragment family by item type id
    function ShardFamilySystem.GetFamilyKeyByItem(itemTypeId)
        return ITEM_TO_FRAGMENT[itemTypeId]
    end

    -- Get fragment family by raw item code
    function ShardFamilySystem.GetFamilyKeyByRaw(raw)
        return ITEM_TO_FRAGMENT[idOfRaw(raw)]
    end

    -- Get all items for a given fragment family (DB/Digi/Poke/Chakra)
    function ShardFamilySystem.ItemsForFamily(familyKey)
        buildReverse()
        return FAMILY_TO_ITEMS[familyKey] or {}
    end

    -- Get fragment family pretty name
    function ShardFamilySystem.GetFamilyPretty(familyKey)
        return FRAGMENT_FAMILIES[familyKey] or familyKey
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        buildReverse()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ShardFamilySystem")
        end
    end)
end
