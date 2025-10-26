if Debug and Debug.beginFile then Debug.beginFile("ShopCatalog.lua") end
--==================================================
-- ShopCatalog.lua (WC3-safe)
-- Central data source for all vendor/shop listings.
-- Supports hub-based filtering and companion unlocks.
--==================================================

if not ShopCatalog then ShopCatalog = {} end
_G.ShopCatalog = ShopCatalog

do
    local DATA = {}

    --------------------------------------------------
    -- Registration
    --------------------------------------------------
    function ShopCatalog.Register(entry)
        if not entry or not entry.id then
            print("[ShopCatalog] Invalid registration (missing id)")
            return
        end
        DATA[entry.id] = entry
    end

    function ShopCatalog.Get(id)
        return DATA[id]
    end

    function ShopCatalog.ListForHub(hub)
        local results = {}
        for id, e in pairs(DATA) do
            if e.enabled ~= false then
                if e.hubs == "*" then
                    results[#results + 1] = e
                elseif type(e.hubs) == "table" then
                    for _, h in ipairs(e.hubs) do
                        if h == hub then
                            results[#results + 1] = e
                            break
                        end
                    end
                end
            end
        end
        return results
    end

    --------------------------------------------------
    -- Safe table.contains
    --------------------------------------------------
    if not table.contains then
        function table.contains(tbl, val)
            if not tbl then return false end
            for _, v in pairs(tbl) do
                if v == val then return true end
            end
            return false
        end
    end

    --------------------------------------------------
    -- Yemma Test Entries (Companion Unlocks)
    --------------------------------------------------
    ShopCatalog.Register({
        id = "merc_healer_unlock",
        name = "Unlock Companion: Healer",
        desc = "Unlocks the Healer companion for your team.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNHeal.blp",
        price = { gold = 0, fragments = 0, souls = 0 },
        kind = "unlock",
        payload = { companionId = "Healer_Default" },
        unique = true,
        requirements = {},
        hubs = { "YEMMA" },
        enabled = true,
    })

    ShopCatalog.Register({
        id = "merc_tank_unlock",
        name = "Unlock Companion: Tank",
        desc = "Unlocks the Tank companion for your team.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp",
        price = { gold = 0, fragments = 0, souls = 0 },
        kind = "unlock",
        payload = { companionId = "Tank_Default" },
        unique = true,
        requirements = {},
        hubs = { "YEMMA" },
        enabled = true,
    })

    --------------------------------------------------
    -- Global list accessor
    --------------------------------------------------
    function ShopCatalog.All()
        local list = {}
        for _, e in pairs(DATA) do
            list[#list + 1] = e
        end
        return list
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ShopCatalog")
        end
        local total = 0
        for _ in pairs(DATA) do total = total + 1 end
        print("[ShopCatalog] Ready with " .. tostring(total) .. " entries")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
