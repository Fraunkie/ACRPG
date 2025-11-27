if Debug and Debug.beginFile then Debug.beginFile("ItemDatabase.lua") end
--==================================================
-- ItemDatabase.lua
-- Canonical registry for item categories, teleport keys, and item text/icons.
--  • TeleportNodeByItem(id) -> node|nil
--  • GetCategory(id) -> string
--  • GetName/GetDescription/GetIconPath/GetData
--  • GetTooltip(id) -> formatted text (no % chars)
--  • SetData(id, fields) / Register(id, name, desc, extra)
--  • RegisterEx(id, dataTbl) / BulkRegister({ [id]=dataTbl, ... })
--
-- New supported fields per item (all optional):
--   stats = { str=5, agi=2, hp=50, mp=0, spellPowerPct=0.10, physPowerPct=0.05, ... }
--   allowedHeroTypes = "SAIYAN" | {"SAIYAN","NAMEKIAN"} | { SAIYAN=true, NAMEKIAN=true }
--   requiredPowerLevel = 500
--   requiredSoulEnergy = 1000
--   required = { powerLevel=500, soulEnergy=1000 }  -- alternative nested form
--   slot = "Weapon"                                 -- optional explicit UI slot
--   category / categories                           -- used for GetCategory fallback & slot mapping
--==================================================

if not ItemDatabase then ItemDatabase = {} end
_G.ItemDatabase = ItemDatabase

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TP = {}

    -- If an item id is present in these sets, that wins as the category.
    local CATEGORIES = {
        FRAGMENT = { },
        SHARD    = { },
        MISC     = { },

        HEAD     = { },
        HANDS    = { },
        CHEST    = { },
        WEAPON   = { },
        OFFHAND  = { },
        LEGS     = { },
        BOOTS    = { },
        NECKLACE = { },
        RING     = { },
        SOULS    = { },
        ACCESSORY= { },
        FOOD     = { },
    }

    --------------------------------------------------
    -- Data store (keep your existing seed data)
    --------------------------------------------------
    local DATA = {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function has(tbl, key) return tbl and tbl[key] == true end
    local function ensure(tbl) if not tbl then tbl = {} end return tbl end

    local function upper(s)
        if type(s) ~= "string" then return "" end
        local out = ""
        local i = 1
        while i <= string.len(s) do
            local c = string.sub(s, i, i)
            local b = string.byte(c)
            if b >= 97 and b <= 122 then out = out .. string.char(b - 32) else out = out .. c end
            i = i + 1
        end
        return out
    end

    local function normalizeCategories(cat, cats)
        -- returns one best category string if possible
        if type(cat) == "string" and cat ~= "" then
            return upper(cat)
        end
        if type(cats) == "table" then
            for k, v in pairs(cats) do
                if type(k) == "string" and v == true then return upper(k) end
            end
            for _, v in pairs(cats) do
                if type(v) == "string" then return upper(v) end
            end
        end
        return nil
    end

    local function getReqNumbers(d)
        local needPower, needSoul = 0, 0
        if type(d.requiredPowerLevel) == "number" then needPower = d.requiredPowerLevel end
        if type(d.requiredSoulEnergy) == "number" then needSoul = d.requiredSoulEnergy end
        local r = rawget(d, "required")
        if type(r) == "table" then
            if type(r.powerLevel) == "number" then needPower = r.powerLevel end
            if type(r.soulEnergy) == "number" then needSoul = r.soulEnergy end
        end
        return needPower, needSoul
    end

    local function round(x)
        if type(x) ~= "number" then return 0 end
        if x >= 0 then return math.floor(x + 0.5) else return -math.floor(-x + 0.5) end
    end

    local function appendLine(buf, text)
        if text == "" then return end
        if buf.v == "" then buf.v = text else buf.v = buf.v .. "\n" .. text end
    end

    local STAT_ORDER = {
        "str","agi","int","hp","mp","defense","armor","attack","speed",
        "critChancePct","critDamagePct","lifestealPct",
        "spellPowerPct","physPowerPct",
    }
    local STAT_LABEL = {
        str="Strength", agi="Agility", int="Intellect",
        hp="Health", mp="Mana",
        defense="Defense", armor="Armor", attack="Attack", speed="Speed",
        critChancePct="Critical Chance", critDamagePct="Critical Damage", lifestealPct="Lifesteal",
        spellPowerPct="Spell Power", physPowerPct="Physical Power",
    }
    local function isPercentKey(k)
        if type(k) ~= "string" then return false end
        local n = string.len(k)
        if n >= 3 then return string.sub(k, n-2, n) == "Pct" end
        return false
    end

    local function buildStatsLines(stats)
        if type(stats) ~= "table" then return "" end
        local buf = { v = "" }
        -- known order first
        local i = 1
        while i <= #STAT_ORDER do
            local k = STAT_ORDER[i]
            local val = stats[k]
            if type(val) == "number" and val ~= 0 then
                local label = STAT_LABEL[k] or k
                if isPercentKey(k) then
                    local pct = round(val * 100)
                    appendLine(buf, "+" .. tostring(pct) .. " " .. label .. " percent")
                else
                    appendLine(buf, "+" .. tostring(val) .. " " .. label)
                end
            end
            i = i + 1
        end
        -- extras not in order
        for k, v in pairs(stats) do
            local known = false
            local j = 1
            while j <= #STAT_ORDER do if STAT_ORDER[j] == k then known = true; break end; j = j + 1 end
            if not known and type(v) == "number" and v ~= 0 then
                local label = STAT_LABEL[k] or k
                if isPercentKey(k) then
                    local pct = round(v * 100)
                    appendLine(buf, "+" .. tostring(pct) .. " " .. label .. " percent")
                else
                    appendLine(buf, "+" .. tostring(v) .. " " .. label)
                end
            end
        end
        return buf.v
    end

    local function buildRequirementsLines(d)
        local lines = { v = "" }
        -- hero types
        local allowed = rawget(d, "allowedHeroTypes")
        if allowed then
            if type(allowed) == "string" then
                appendLine(lines, "|cffff8888Requires: " .. upper(allowed) .. " hero|r")
            elseif type(allowed) == "table" then
                local tmp = {}
                for k, v in pairs(allowed) do
                    if type(k) == "string" and v == true then tmp[#tmp+1] = upper(k)
                    elseif type(v) == "string" then tmp[#tmp+1] = upper(v) end
                end
                if #tmp > 0 then appendLine(lines, "|cffff8888Requires: " .. table.concat(tmp, ", ") .. " hero|r") end
            end
        end
        local needPower, needSoul = getReqNumbers(d)
        if needPower and needPower > 0 then appendLine(lines, "|cffffcc00Needs Power Level " .. tostring(needPower) .. "|r") end
        if needSoul  and needSoul  > 0 then appendLine(lines, "|cffffcc00Needs Soul Energy " .. tostring(needSoul) .. "|r") end
        return lines.v
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function ItemDatabase.TeleportNodeByItem(id)
        return TP[id]
    end

    -- Extended: checks CATEGORIES first, then falls back to DATA[id].category/categories
    function ItemDatabase.GetCategory(id)
        if has(CATEGORIES.FRAGMENT, id) then return "FRAGMENT" end
        if has(CATEGORIES.SHARD,    id) then return "SHARD"    end
        if has(CATEGORIES.MISC,     id) then return "MISC"     end
        if has(CATEGORIES.HEAD,     id) then return "HEAD"     end
        if has(CATEGORIES.HANDS,    id) then return "HANDS"    end
        if has(CATEGORIES.CHEST,    id) then return "CHEST"    end
        if has(CATEGORIES.WEAPON,   id) then return "WEAPON"   end
        if has(CATEGORIES.OFFHAND,  id) then return "OFFHAND"  end
        if has(CATEGORIES.LEGS,     id) then return "LEGS"     end
        if has(CATEGORIES.BOOTS,    id) then return "BOOTS"    end
        if has(CATEGORIES.NECKLACE, id) then return "NECKLACE" end
        if has(CATEGORIES.RING,     id) then return "RING"     end
        if has(CATEGORIES.SOULS,    id) then return "SOULS"    end
        if has(CATEGORIES.ACCESSORY,id) then return "ACCESSORY"end
        if has(CATEGORIES.FOOD,     id) then return "FOOD"     end
        -- fallback to per-item data
        local d = DATA[id]
        if d then
            local cat = normalizeCategories(d.category, d.categories)
            if cat then return cat end
        end
        return "UNKNOWN"
    end

    --------------------------------------------------
    -- Getters
    --------------------------------------------------
    function ItemDatabase.GetData(id)
        return DATA[id]
    end

    function ItemDatabase.GetName(id)
        local d = DATA[id]
        if d and d.name and d.name ~= "" then return d.name end
        return "Item " .. tostring(id)
    end

    function ItemDatabase.GetDescription(id)
        local d = DATA[id]
        if d and d.description and d.description ~= "" then return d.description end
        local cat = ItemDatabase.GetCategory(id)
        return "Category: " .. cat
    end

    function ItemDatabase.GetIconPath(id)
        local d = DATA[id]
        if d and d.iconpath and d.iconpath ~= "" then return d.iconpath end
        return "ReplaceableTextures\\CommandButtons\\BTNTemp.blp"
    end

    --------------------------------------------------
    -- Mutators
    --------------------------------------------------
    function ItemDatabase.SetData(id, fields)
        if type(id) ~= "number" or type(fields) ~= "table" then return end
        DATA[id] = ensure(DATA[id])
        for k, v in pairs(fields) do
            DATA[id][k] = v
        end
    end

    -- Backward-compatible Register (name/desc + extra table)
    function ItemDatabase.Register(id, name, description, extra)
        if type(id) ~= "number" then return end
        DATA[id] = {
            name = name or ("Item " .. tostring(id)),
            description = description or ""
        }
        if type(extra) == "table" then
            for k, v in pairs(extra) do DATA[id][k] = v end
        end
    end

    -- New: Register with a single data table
    function ItemDatabase.RegisterEx(id, dataTbl)
        if type(id) ~= "number" or type(dataTbl) ~= "table" then return end
        DATA[id] = {}
        for k, v in pairs(dataTbl) do DATA[id][k] = v end
        if not DATA[id].name then DATA[id].name = "Item " .. tostring(id) end
        if not DATA[id].description then DATA[id].description = "" end
    end

    -- New: Bulk registration { [id] = dataTbl, ... }
    function ItemDatabase.BulkRegister(map)
        if type(map) ~= "table" then return end
        for id, data in pairs(map) do
            ItemDatabase.RegisterEx(id, data)
        end
    end
    ItemDatabase.RegisterMany = ItemDatabase.BulkRegister

    --------------------------------------------------
    -- Tooltip
    --------------------------------------------------
    function ItemDatabase.GetTooltip(id)
        if not id then return "|cffaaaaaaEmpty|r\nNo details." end
        local d = DATA[id]
        if not d then
            return "|cffffee88Item " .. tostring(id) .. "|r\n|cffaaaaaaNo data.|r"
        end

        local name = ItemDatabase.GetName(id)
        local desc = ItemDatabase.GetDescription(id)
        local stats = buildStatsLines(d.stats)
        local reqs  = buildRequirementsLines(d)

        local buf = { v = "" }
        appendLine(buf, "|cffffee88" .. name .. "|r")
        if desc ~= "" then appendLine(buf, desc) end
        if stats ~= "" then appendLine(buf, stats) end
        if reqs  ~= "" then appendLine(buf, reqs)  end

        return buf.v
    end

    function ItemDatabase.DebugList(pid)
        local p = Player(pid)
        DisplayTextToPlayer(p, 0, 0, "== Item Database ==")
        for id, node in pairs(DATA) do
            DisplayTextToPlayer(p, 0, 0, tostring(id) .. ": " .. (node.name or "?"))
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        print("[ItemDatabase] ready (teleport, categories, text/icons, stats/reqs online)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ItemDatabase")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
