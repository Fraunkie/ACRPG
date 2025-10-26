if Debug and Debug.beginFile then Debug.beginFile("CompanionCatalog.lua") end
--==================================================
-- CompanionCatalog.lua (v1.1 MAIN)
-- Passive data registry for companion templates.
-- Provides unitTypeId for spawning.
--==================================================

do
  CompanionCatalog = CompanionCatalog or {}
  _G.CompanionCatalog = CompanionCatalog

  local REG = REG or {}

  local function clone(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k,v in pairs(t) do
      if type(v) == "table" then r[k] = clone(v) else r[k] = v end
    end
    return r
  end

  function CompanionCatalog.Register(id, data)
    if type(id) ~= "string" or id == "" then return false end
    if type(data) ~= "table" then return false end
    REG[id] = clone(data)
    return true
  end

  function CompanionCatalog.Get(id)
    local d = REG[id]
    if not d then return nil end
    return clone(d)
  end

  function CompanionCatalog.Has(id)
    return REG[id] ~= nil
  end

  function CompanionCatalog.ListIds()
    local out, i = {}, 1
    for k,_ in pairs(REG) do out[i]=k; i=i+1 end
    table.sort(out)
    return out
  end

  --==================================================
  -- Defaults (placeholders; no auto-unlock anywhere)
  -- Using Footman (hfoo) for both until real units exist.
  --==================================================
  local FOOTMAN = FourCC("hfoo")

  CompanionCatalog.Register("Healer_Default", {
    name = "Little Angel",
    role = "Healer",
    icon = "ReplaceableTextures\\CommandButtons\\BTNHeal.blp",
    desc = "A basic support unit that follows its owner and provides healing.",
    unitTypeId = FourCC("h00O"),
    threatPolicy = {
      threatMode = "split",
      splitToOwner = 0.90,
      threatMultSelf = 0.25,
      threatMultOwner = 1.00,
      healThreatMult = 0.50,
      discardIfOwnerInvalid = true,
      countForLoot = true
    },
    unitstats = { maxhp = { base = 200, coefSTR = 25 },
                  damage = { base = 5, coefINT = 0.01 } },
    healAbilityId = OrderId("heal"),
    abilityDefs = { heal = { base = 100, coefINT = 0.25, coefSpell = 0.50, cd = 10.0, range = 600 } }
  })

  CompanionCatalog.Register("Tank_Default", {
    name = "Guardian Drone",
    role = "Tank",
    icon = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp",
    desc = "A defensive unit that holds enemy focus and protects its owner.",
    unitTypeId = FOOTMAN,           -- TEMP: Footman
  })

  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("CompanionCatalog")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
