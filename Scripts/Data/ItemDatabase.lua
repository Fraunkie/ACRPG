if Debug and Debug.beginFile then Debug.beginFile("ItemDatabase.lua") end
--==================================================
-- ItemDatabase.lua
-- Canonical registry for item categories and teleport keys.
-- Used by loot, teleport, and pickup systems.
--==================================================

if not ItemDatabase then ItemDatabase = {} end
_G.ItemDatabase = ItemDatabase

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TP = {
        -- Example teleport items
        [FourCC("I020")] = "YEMMA",        -- Form 47-B
        [FourCC("I021")] = "KAMI_LOOKOUT", -- Soul Tag
        [FourCC("I022")] = "SPIRIT_REALM", -- Celestial Paperclip
    }

    local CATEGORIES = {
        FRAGMENT = { [FourCC("I010")] = true, [FourCC("I011")] = true, [FourCC("I012")] = true },
        SHARD    = { [FourCC("I00W")] = true, [FourCC("I014")] = true, [FourCC("I015")] = true },
        MISC     = { [FourCC("I024")] = true, [FourCC("I025")] = true },
    }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validItem(i)
        return i and GetItemTypeId(i) ~= 0
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function ItemDatabase.TeleportNodeByItem(id)
        return TP[id]
    end

    function ItemDatabase.IsFragment(id)
        return CATEGORIES.FRAGMENT[id] or false
    end

    function ItemDatabase.IsShard(id)
        return CATEGORIES.SHARD[id] or false
    end

    function ItemDatabase.IsMisc(id)
        return CATEGORIES.MISC[id] or false
    end

    function ItemDatabase.GetCategory(id)
        if CATEGORIES.FRAGMENT[id] then return "FRAGMENT" end
        if CATEGORIES.SHARD[id] then return "SHARD" end
        if CATEGORIES.MISC[id] then return "MISC" end
        return "UNKNOWN"
    end

    function ItemDatabase.DebugList(pid)
        local p = Player(pid)
        DisplayTextToPlayer(p, 0, 0, "== Item Database ==")
        for id, node in pairs(TP) do
            DisplayTextToPlayer(p, 0, 0, "Teleport key: " .. node .. " (" .. id .. ")")
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        print("[ItemDatabase] ready (teleport + shard/fragments loaded)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ItemDatabase")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
