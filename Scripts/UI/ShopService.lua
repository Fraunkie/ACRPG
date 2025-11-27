if Debug and Debug.beginFile then Debug.beginFile("ShopService.lua") end
--==================================================
-- ShopService.lua
-- Service layer for shop logic:
-- • Lists shop entries for a hub
-- • Validates requirements and currency
-- • Applies purchases (unlock companion or grant item)
--==================================================

if not ShopService then ShopService = {} end
_G.ShopService = ShopService

do
  --------------------------------------------------
  -- Utils
  --------------------------------------------------

  local function dbg(msg)
    if Debug and Debug.printf then Debug.printf("[ShopService] " .. tostring(msg)) end
  end

  local function contains(tbl, val)
    if not tbl then return false end
    for _, v in pairs(tbl) do if v == val then return true end end
    return false
  end

  local function getZone(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetZone then
      local ok, z = pcall(PD.GetZone, pid)
      if ok and type(z) == "string" then return z end
    end
    return "YEMMA"
  end

  local function getHeroTypeUpper(pid)
    local PD = rawget(_G, "PlayerData")
    local ht = PD and PD.GetHeroType and PD.GetHeroType(pid) or nil
    if type(ht) ~= "string" then return nil end
    local r = ""
    for i = 1, string.len(ht) do
      local c = string.sub(ht, i, i)
      local b = string.byte(c)
      r = r .. ((b >= 97 and b <= 122) and string.char(b - 32) or c)
    end
    return r
  end

  local function getGold(pid)
    return GetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD)
  end

  local function addGold(pid, delta)
    SetPlayerState(Player(pid), PLAYER_STATE_RESOURCE_GOLD, math.max(0, getGold(pid) + (delta or 0)))
  end

  -- Get CapsuleCoins
  local function getCapsuleCoin(pid)
    -- Ensure PlayerData is being accessed correctly
    local playerData = PlayerData.Get(pid)
    if playerData and playerData.currency then
      return playerData.currency.capsuleCoins or 0 -- Return 0 if undefined
    end
    return 0 -- Fallback
  end

  -- Add CapsuleCoins
  local function addCapsuleCoin(pid, delta)
    -- Ensure PlayerData is being updated correctly
    local playerData = PlayerData.Get(pid)
    if playerData and playerData.currency then
      playerData.currency.capsuleCoins = playerData.currency.capsuleCoins + delta
    end
  end

  -- Get Fragments (adjusted to use fragmentsByKind)
  local function getFragments(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetField then
      return PD.GetField(pid, "fragmentsByKind", {})
    end
    return {}
  end

  -- Add fragments for each type
  local function addFragments(pid, fragType, delta)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.AddFragmentsByType then
      PD.AddFragmentsByType(pid, fragType, delta or 0)
      return
    end
  end

  local function getSouls(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetSoulEnergy then return PD.GetSoulEnergy(pid) end
    return 0
  end

  local function addSouls(pid, delta)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.AddSoul then PD.AddSoul(pid, delta or 0) end
  end

  -- Strict check for the Companion License (I00H) in custom inventory
  local function hasCompanionLicense(pid)
    local svc = rawget(_G, "InventoryService")
    if not (svc and svc.List and FourCC) then return false end
    local want = FourCC("I00H")
    local list = svc.List(pid)
    if type(list) ~= "table" then return false end

    local function norm(e)
      if type(e) == "number" then return e end
      if type(e) == "string" then return FourCC(e) end
      if type(e) == "table" then
        if type(e.typeId) == "number" then return e.typeId end
        if type(e.id)     == "number" then return e.id end
        if type(e.rawcode)== "string" then return FourCC(e.rawcode) end
        if type(e.code)   == "string" then return FourCC(e.code) end
      end
      return nil
    end

    for _, v in pairs(list) do
      local id = norm(v)
      if id and id == want then return true end
    end
    return false
  end

  -- Companion ownership
  local function hasCompanionUnlocked(pid, compId)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.HasCompanionUnlocked then
      local ok, res = pcall(PD.HasCompanionUnlocked, pid, compId)
      return ok and res == true
    end
    return false
  end

  --------------------------------------------------
  -- Visibility helpers
  --------------------------------------------------
  function ShopService.ListForHub(pid, hub, vendorId)
    local cat = rawget(_G, "ShopCatalog")
    if not (cat and cat.ListForHub) then return {} end
    local h = hub or getZone(pid)
    local list = cat.ListForHub(h) or {}
    if vendorId == nil then return list end
    local out = {}
    for _, e in ipairs(list) do
      if not e.vendorId or e.vendorId == vendorId then
        out[#out + 1] = e
      end
    end
    return out
  end

  --------------------------------------------------
  -- Requirement checks
  --------------------------------------------------
  local function checkRequirements(pid, entry)
    local req = entry and entry.requirements
    if not req then return true, nil end

    -- soul level
    if type(req.soulLevel) == "number" then
      local PD = rawget(_G, "PlayerData")
      local have = 0
      if PD and PD.GetField then
        have = PD.GetField(pid, "soulLevel", 1) or 1
      end
      if have < req.soulLevel then
        return false, "Need higher soul level"
      end
    end

    -- zone / hub requirement
    if type(req.zone) == "string" then
      if getZone(pid) ~= req.zone then
        return false, "Wrong hub"
      end
    end

    -- hero type
    if type(req.heroType) == "string" then
      local want = req.heroType
      local have = getHeroTypeUpper(pid)
      local up = ""
      for i=1,string.len(want) do
        local c=string.sub(want,i,i)
        local b=string.byte(c)
        up = up .. ((b>=97 and b<=122) and string.char(b-32) or c)
      end
      if have ~= up then
        return false, "Wrong hero"
      end
    end

    -- needs license
    if req.hasLicense == true then
      if not hasCompanionLicense(pid) then
        return false, "License required"
      end
    end

    return true, nil
  end

  --------------------------------------------------
  -- Ownership / uniqueness
  --------------------------------------------------
  local function alreadyOwned(pid, entry)
    if not entry or entry.unique ~= true then return false end
    if entry.kind == "unlock" and entry.payload and entry.payload.companionId then
      return hasCompanionUnlocked(pid, entry.payload.companionId)
    end
    if entry.kind == "item" and entry.payload and entry.payload.rawcode then
      local svc = rawget(_G, "InventoryService")
      if not (svc and svc.List and FourCC) then return false end
      local want = FourCC(entry.payload.rawcode)
      local list = svc.List(pid)
      if type(list) ~= "table" then return false end
      for _, v in pairs(list) do
        if type(v) == "number" and v == want then return true end
        if type(v) == "string" and FourCC(v) == want then return true end
        if type(v) == "table" then
          if v.typeId == want then return true end
          if type(v.rawcode) == "string" and FourCC(v.rawcode) == want then return true end
          if type(v.code) == "string" and FourCC(v.code) == want then return true end
        end
      end
      return false
    end
    return false
  end

  --------------------------------------------------
  -- Currency checks
  --------------------------------------------------
  local function canAfford(pid, price)
    price = price or {}
    local needGold      = price.gold      or 0
    local needFragments = price.fragments or {}
    local needSouls     = price.souls     or 0
    local needcc        = price.capsuleCoin and price.capsuleCoin > 0 -- CapsuleCoins check

 

    if getGold(pid) < needGold then return false, "Not enough gold" end

    if needcc  then 
        print("Player doesn't have enough CapsuleCoins.")
        return false, "Not enough CapsuleCoins"  
    end

    for fragType, fragAmount in pairs(needFragments) do
        if getFragments(pid)[fragType] < fragAmount then
            return false, "Not enough " .. fragType
        end
    end

    if getSouls(pid) < needSouls then 
        return false, "Not enough souls" 
    end

    return true, nil
end

  local function pay(pid, price)
    price = price or {}
    if (price.gold or 0) > 0 then 
        addGold(pid, -price.gold) 
    end
    if (price.capsuleCoins or 0) > 0 then 
        addCapsuleCoin(pid, -price.capsuleCoins) 
    end
    if (price.fragments or {}) then
      for fragType, fragAmount in pairs(price.fragments) do
        addFragments(pid, fragType, -fragAmount)
      end
    end
    if (price.souls or 0) > 0 then addSouls(pid, -price.souls) end
  end

  --------------------------------------------------
  -- Delivery
  --------------------------------------------------
  local function deliver(pid, entry)
    if not entry then return false, "Invalid product" end

    if entry.kind == "unlock" then
      local compId = entry.payload and entry.payload.companionId
      if not compId then return false, "Invalid unlock" end
      if hasCompanionUnlocked(pid, compId) then
        return false, "Already unlocked"
      end
      local PD = rawget(_G, "PlayerData")
      if PD and PD.UnlockCompanion then
        local ok = pcall(PD.UnlockCompanion, pid, compId)
        if ok then return true, "Unlocked companion" end
      end
      return false, "Unlock failed"
    end

    if entry.kind == "item" then
      local rawcode = entry.payload and entry.payload.rawcode
      if not rawcode then return false, "Invalid item" end
      local svc = rawget(_G, "InventoryService")
      if not (svc and svc.Add and svc.IsFull and FourCC) then
        return false, "Inventory missing"
      end
      if svc.IsFull(pid) then
        return false, "Inventory full"
      end
      local idx = svc.Add(pid, FourCC(rawcode))
      if idx then return true, "Item granted" end
      return false, "Add failed"
    end

    return false, "Unknown kind"
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function ShopService.CanBuy(pid, productId)
    local cat = rawget(_G, "ShopCatalog"); if not cat then return false, "Catalog missing" end
    local entry = cat.Get and cat.Get(productId) or nil
    if not entry then return false, "Not found" end

    if alreadyOwned(pid, entry) then
      return false, "Already owned"
    end

    local ok, reason = checkRequirements(pid, entry)
    if not ok then return false, reason or "Requirements not met" end

    local ok2, reason2 = canAfford(pid, entry.price or {})
    if not ok2 then return false, reason2 or "Insufficient currency" end

    return true, nil
  end

  function ShopService.Buy(pid, productId)
    local cat = rawget(_G, "ShopCatalog"); if not cat then return false, "Catalog missing" end
    local entry = cat.Get and cat.Get(productId) or nil
    if not entry then return false, "Not found" end

    -- Ownership and requirements
    if alreadyOwned(pid, entry) then
      return false, "Already owned"
    end
    local okReq, whyReq = checkRequirements(pid, entry)
    if not okReq then return false, whyReq or "Requirements not met" end

    -- Currency
    local okFunds, whyFunds = canAfford(pid, entry.price or {})
    if not okFunds then return false, whyFunds or "Insufficient currency" end

    -- Commit payment
    pay(pid, entry.price or {})

    -- Deliver
    local okDeliv, whyDeliv = deliver(pid, entry)
    if not okDeliv then
      -- Refund on failure
      local pr = entry.price or {}
      if (pr.gold or 0) > 0 then addGold(pid, pr.gold) end
      if (pr.fragments or {}) then
        for fragType, fragAmount in pairs(pr.fragments) do
          addFragments(pid, fragType, fragAmount)
        end
      end
      if (pr.souls or 0) > 0 then addSouls(pid, pr.souls) end
      return false, whyDeliv or "Delivery failed"
    end

    -- Notify
    local PB = rawget(_G, "ProcBus")
    if PB and PB.Emit then
      PB.Emit("ShopPurchase", { pid = pid, productId = productId, ok = true })
    end

    -- Friendly text
    local msg = "Purchased"
    if entry.kind == "unlock" and entry.payload and entry.payload.companionId then
      msg = "Unlocked " .. tostring(entry.payload.companionId)
    elseif entry.kind == "item" then
      msg = "Item granted"
    end
    DisplayTextToPlayer(Player(pid), 0, 0, msg)
    dbg("ok buy id=" .. tostring(productId))
    return true, msg
  end

  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("ShopService")
    end
    dbg("ready")
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
