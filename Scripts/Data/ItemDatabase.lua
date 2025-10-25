if Debug and Debug.beginFile then Debug.beginFile("ItemDatabase") end
--==================================================
-- ItemDatabase.lua (clean core)
--  • Keeps an internal DATA table (empty by default)
--  • Exposes Register / RegisterEx / BulkRegister
--  • Safe getters: GetData, GetName, GetCategory, GetTooltip, GetIconPath
--  • Accepts ids as integer (FourCC result) or rawcode string ("I00G")
--   stats = { str=5, agi=2, hp=50, mp=0, spellPowerPct=0.10, physPowerPct=0.05, ... }
--   allowedHeroTypes = "SAIYAN" | {"SAIYAN","NAMEKIAN"} | { SAIYAN=true, NAMEKIAN=true }
--   requiredPowerLevel = 500
--   requiredSoulEnergy = 1000
--   required = { powerLevel=500, soulEnergy=1000 }  -- alternative nested form
--   slot = "Weapon"                                 -- optional explicit UI slot
--   category / categories                           -- used for GetCategory fallback & slot mapping
--==================================================

do
  ItemDatabase = ItemDatabase or {}
  _G.ItemDatabase = ItemDatabase

  --------------------------------------------------
  -- Store (now empty; content registered elsewhere)
  --------------------------------------------------
  local DATA = {}                 -- [id:int] = { name=..., description=..., iconpath=..., category=..., slot=..., stats={...} }
  local CATEGORY = {              -- simple grouping container if you use it elsewhere
    WEAPON = {}, OFFHAND = {}, HEAD = {}, NECKLACE = {},
    CHEST = {}, LEGS = {}, BOOTS = {}, ACCESSORY = {},
    HANDS = {}, BELT = {}, FOOD = {},
  }

  --------------------------------------------------
  -- Utils
  --------------------------------------------------
  local function asId(id)
    if type(id) == "number" then return id end
    if type(id) == "string" and #id == 4 then
      local ok, val = pcall(FourCC, id)
      if ok and type(val) == "number" then return val end
    end
    return nil
  end

  local function shallowCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = v end
    return o
  end

  --------------------------------------------------
  -- Registration
  --------------------------------------------------
  -- RegisterEx: table form
  -- { id=FourCC or "I00G", name=..., description=..., iconpath=..., category=..., slot=..., stats={...} }
  function ItemDatabase.RegisterEx(tbl)
    if type(tbl) ~= "table" then return false end
    local id = asId(tbl.id or tbl.typeId)  -- allow id or typeId
    if not id then return false end

    local rec = {
      name        = tbl.name or ("Item "..tostring(id)),
      description = tbl.description or "",
      iconpath    = tbl.iconpath or "",
      category    = tbl.category or "MISC",
      slot        = tbl.slot or "",
      stats       = shallowCopy(tbl.stats or {}),
    }

    DATA[id] = rec

    -- optional: index by category for quick lookups
    local cat = rec.category
    if type(cat) == "string" then
      CATEGORY[cat] = CATEGORY[cat] or {}
      CATEGORY[cat][id] = true
    end

    return true
  end

  -- Simple Register (id, name, iconpath, category, slot, stats, description)
  function ItemDatabase.Register(id, name, iconpath, category, slot, stats, description)
    return ItemDatabase.RegisterEx({
      id = id, name = name, iconpath = iconpath, category = category,
      slot = slot, stats = stats, description = description
    })
  end

  -- BulkRegister({ [id]=record, ... }) where each record is same shape as RegisterEx (minus id)
  function ItemDatabase.BulkRegister(map)
    if type(map) ~= "table" then return false end
    for k, v in pairs(map) do
      local rec = shallowCopy(v or {})
      rec.id = k
      ItemDatabase.RegisterEx(rec)
    end
    return true
  end

  --------------------------------------------------
  -- Getters
  --------------------------------------------------
  function ItemDatabase.GetData(id)
    id = asId(id); if not id then return nil end
    return DATA[id]
  end

  function ItemDatabase.GetName(id)
    local d = ItemDatabase.GetData(id); return d and d.name or ""
  end

  function ItemDatabase.GetIconPath(id)
    local d = ItemDatabase.GetData(id); return d and d.iconpath or ""
  end

  function ItemDatabase.GetCategory(id)
    local d = ItemDatabase.GetData(id); return d and d.category or ""
  end

  function ItemDatabase.GetSlot(id)
    local d = ItemDatabase.GetData(id); return d and d.slot or ""
  end

  -- Very plain tooltip so it never crashes, even if fields are missing
  function ItemDatabase.GetTooltip(id)
    local d = ItemDatabase.GetData(id)
    if not d then return "|cffaaaaaaUnknown item|r" end

    local lines = {}
    if d.name and d.name ~= "" then table.insert(lines, "|cffffee88"..d.name.."|r") end
    if d.description and d.description ~= "" then table.insert(lines, d.description) end

    -- stats block
    if type(d.stats) == "table" then
      for k, v in pairs(d.stats) do
        if type(v) == "number" then
          table.insert(lines, k .. ": " .. tostring(v))
        end
      end
    end

    if #lines == 0 then return "|cffaaaaaaItem|r" end
    local out = lines[1]
    for i = 2, #lines do out = out .. "\n" .. lines[i] end
    return out
  end

  --------------------------------------------------
  -- Debug helper (optional)
  --------------------------------------------------
  function ItemDatabase.DebugList()
    print("[ItemDatabase] total items: "..tostring((function()
      local n=0; for _ in pairs(DATA) do n=n+1 end; return n
    end)()))
  end

  -- expose for outside debug if you want to inspect
  function ItemDatabase._Raw() return DATA, CATEGORY end
end

if Debug and Debug.endFile then Debug.endFile() end
