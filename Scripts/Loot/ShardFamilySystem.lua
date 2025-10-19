if Debug and Debug.beginFile then Debug.beginFile("ShardFamilySystem.lua") end
--==================================================
-- ShardFamilySystem.lua
-- Item → family mapping and per-family charge costs.
--==================================================

if not ShardFamilySystem then ShardFamilySystem = {} end
_G.ShardFamilySystem = ShardFamilySystem

do
    --------------------------------------------------
    -- Config tables (extend these as you add items)
    --------------------------------------------------
    -- Families: a small string key per shard family
    -- Example: "EARTH", "FIRE", "WATER", "WIND", "LIGHT", "DARK"
    local FAMILY_PRETTY = {
        EARTH = "Earth Shard",
        FIRE  = "Fire Shard",
        WATER = "Water Shard",
        WIND  = "Wind Shard",
        LIGHT = "Light Shard",
        DARK  = "Dark Shard",
    }

    -- Fragments required to charge one core for a given family
    local FAMILY_FRAG_COST = {
        EARTH = 10,
        FIRE  = 12,
        WATER = 10,
        WIND  = 10,
        LIGHT = 15,
        DARK  = 15,
    }

    -- Item type id → family key
    -- Fill using numeric ids or FourCC("Ixxx")
    local ITEM_TO_FAMILY = {
        -- [FourCC("I0E1")] = "EARTH",
        -- [FourCC("I0F1")] = "FIRE",
        -- [FourCC("I0W1")] = "WATER",
        -- [FourCC("I0N1")] = "WIND",
        -- [FourCC("I0L1")] = "LIGHT",
        -- [FourCC("I0D1")] = "DARK",
    }

    --------------------------------------------------
    -- Optional: expose families → list of item ids
    --------------------------------------------------
    local FAMILY_TO_ITEMS = nil
    local function buildReverse()
        if FAMILY_TO_ITEMS then return end
        FAMILY_TO_ITEMS = {}
        for it, fk in pairs(ITEM_TO_FAMILY) do
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
    function ShardFamilySystem.GetFamilyKeyByItem(itemTypeId)
        return ITEM_TO_FAMILY[itemTypeId]
    end

    function ShardFamilySystem.GetFamilyKeyByRaw(raw)
        return ITEM_TO_FAMILY[idOfRaw(raw)]
    end

    function ShardFamilySystem.GetFragmentsToCharge(familyKey)
        local n = FAMILY_FRAG_COST[familyKey]
        if type(n) == "number" and n > 0 then return n end
        return 10
    end

    function ShardFamilySystem.GetFamilyPretty(familyKey)
        return FAMILY_PRETTY[familyKey] or familyKey
    end

    function ShardFamilySystem.ItemsForFamily(familyKey)
        buildReverse()
        return FAMILY_TO_ITEMS[familyKey] or {}
    end

    --------------------------------------------------
    -- Designer helpers (safe to call at init)
    --------------------------------------------------
    function ShardFamilySystem.MapItem(itemTypeId, familyKey)
        if not itemTypeId or not familyKey or familyKey == "" then return end
        ITEM_TO_FAMILY[itemTypeId] = familyKey
        FAMILY_TO_ITEMS = nil
        dprint("mapped item " .. tostring(itemTypeId) .. " to " .. tostring(familyKey))
    end

    function ShardFamilySystem.SetFamilyCost(familyKey, fragments)
        if not familyKey or fragments == nil then return end
        FAMILY_FRAG_COST[familyKey] = math.max(1, math.floor(fragments))
    end

    --------------------------------------------------
    -- Init banner
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            buildReverse()
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("ShardFamilySystem")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
