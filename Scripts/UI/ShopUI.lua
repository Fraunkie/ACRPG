if Debug and Debug.beginFile then Debug.beginFile("ShopUI.lua") end
--==================================================
-- ShopUI.lua (v1.4)
-- Universal Hub Shop UI for all hubs
-- 3x2 grid with tooltips and click-select
-- Pulls from ShopService or ShopCatalog (fallback)
-- Bottom Buy button uses ui.selected and payload.companionId
-- Safe for Warcraft 3 text
--==================================================

do
  ShopUI = ShopUI or {}
  _G.ShopUI = ShopUI

  --------------------------------------------------
  -- Config
  --------------------------------------------------
  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
  local TEX_SLOT       = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller.blp"
  local TEX_BUY_ICON   = "ReplaceableTextures\\CommandButtons\\BTNGoldCoin.blp" -- temp icon

  local ICON_W, ICON_H = 0.036, 0.036
  local ICON_GAP_X     = 0.010
  local ICON_GAP_Y     = 0.012
  local GRID_COLS      = 3
  local GRID_ROWS      = 2
  local PANEL_PAD      = 0.020
  local PAGE_SIZE      = GRID_COLS * GRID_ROWS

  -- Buy button layout
  local BUY_W, BUY_H   = 0.032, 0.032
  local BUY_OFF_X      = 0.000
  local BUY_OFF_Y      = 0.010
  local BUY_TEXT_OFF_X = 0.040
  local BUY_LABEL      = "Buy"

  -- Behavior
  local DEV_FREE_BUY   = true   -- free unlock in dev/test
  local DEBUG_MSGS     = true

  --------------------------------------------------
  -- State
  --------------------------------------------------
  local UI = {}

  local function dbg(pid, s)
    if DEBUG_MSGS then
      DisplayTextToPlayer(Player(pid), 0, 0, "[Shop] "..tostring(s))
    end
  end

  local function debounce(btn)
    if not btn then return end
    BlzFrameSetEnable(btn, false)
    BlzFrameSetEnable(btn, true)
  end

  local function getZone(pid)
    local PD = rawget(_G, "PlayerData")
    if PD and PD.GetZone then
      local ok, z = pcall(PD.GetZone, pid)
      if ok and type(z) == "string" and z ~= "" then return z end
    end
    return "YEMMA"
  end

  local function imod(a, b)
    if not b or b == 0 then return 0 end
    local q = math.floor(a / b)
    return a - q * b
  end
local function getprettyitemname(id)
    if id == "db" then 
        return "Dragonball Fragments"
    elseif id == "digi" then 
        return "Digi Fragments"
    elseif id == "poke" then 
        return "Poke Fragments"
    elseif id == "chakra" then 
        return "Chakra Fragments"
    elseif id == "capsuleCoins" then 
        return "Capsule Coins"
    else
        return id  -- Return the id if no match is found
    end
  end

  --------------------------------------------------
  -- Shared CustomTooltip (TOC-based, global)
  --------------------------------------------------
  local function getSharedTooltip()
    -- we keep our own copy under index 1 so we do not clash with ALICE (which uses 0)
    if not _G.Tooltip then
      BlzLoadTOCFile("CustomTooltip.toc")
      local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
      local box   = BlzCreateFrame("CustomTooltip", parent, 0, 1)
      local title = BlzGetFrameByName("CustomTooltipTitle", 1)
      local text  = BlzGetFrameByName("CustomTooltipValue", 1)

      -- keep it above most UI
      BlzFrameSetLevel(box, 10)
      BlzFrameSetVisible(box, false)

      -- base colors (quotes / cost block use color codes)
      if title then
        BlzFrameSetTextColor(title, BlzConvertColor(255, 255, 230, 128)) -- warm gold
      end
      if text then
        BlzFrameSetTextColor(text, BlzConvertColor(255, 255, 180, 80))   -- soft orange
      end

      _G.Tooltip = { box = box, title = title, text = text }
    end
    return _G.Tooltip.box,
           _G.Tooltip.title,
           _G.Tooltip.text
  end

  -- Title + body + optional green cost block + dynamic sizing
  local function showTooltipFor(pid, headline, body, anchor, costText)
    if not anchor then return end
    local box, title, text = getSharedTooltip()
    if not box or not text then return end

    if GetLocalPlayer() ~= Player(pid) then
      return
    end

    headline = headline or ""
    body     = body or ""
    costText = costText or ""

    local finalText = body
    if costText ~= "" then
      -- Cost rendered in the "quote" slot as green block
      finalText = body .. "\n\n" .. "|cff00ff00" .. costText .. "|r" .. "\n "
    else
      finalText = body .. "\n "
    end

    if title then
      BlzFrameSetText(title, headline)
    end
    BlzFrameSetText(text, finalText)

    -- pick width based on length of composed text
    local composedLen = string.len(finalText)
    local textWidth = 0.26
    if composedLen > 220 then
      textWidth = 0.34
    elseif composedLen > 120 then
      textWidth = 0.30
    end

    BlzFrameSetSize(text, textWidth, 0.0)
    local h = BlzFrameGetHeight(text)
    -- little padding around the text
    BlzFrameSetSize(box, textWidth + 0.02, h + 0.036)

    BlzFrameClearAllPoints(box)
    -- hover style: box near the button, below and to the right
    BlzFrameSetPoint(box, FRAMEPOINT_TOPLEFT, anchor, FRAMEPOINT_BOTTOMRIGHT, 0.004, -0.004)

    BlzFrameSetVisible(box, true)
  end

  local function hideTooltipFor(pid)
    local t = _G.Tooltip
    if not t or not t.box then return end
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetVisible(t.box, false)
    end
  end

  --------------------------------------------------
  -- Tooltip text helpers (headline handled separately)
  --------------------------------------------------
  local function buildTooltipBody(entry)
    local desc = entry.desc or "No details"
    return desc
  end

  -- Updated Tooltip cost builder to handle multi-fragments from ShopCatalog
local function buildTooltipCost(entry)
    local price = entry.price or {}
    local hasGold      = price.gold and price.gold > 0
    local hasFragments = false
    local fragmentTypes = {}
    local hasSouls     = price.souls and price.souls > 0
    local hasCC        = price.capsuleCoin and price.capsuleCoin > 0  -- Check for Capsule Coins

    -- Check for each fragment type in the fragmentsByKind table
    for fragType, fragAmount in pairs(price.fragments or {}) do
      if fragAmount > 0 then
        hasFragments = true
        table.insert(fragmentTypes, getprettyitemname(fragType) .. " " .. tostring(fragAmount))
      end
    end

    -- If no explicit cost: treat as free
    if not (hasGold or hasFragments or hasSouls or hasCC) then
      return "Cost\n  Free"
    end

    local lines = {}
    lines[#lines+1] = "Cost"
    if hasGold then lines[#lines+1] = "  Gold " .. tostring(price.gold) end
    if hasCC then lines[#lines+1] = "  CapsuleCoins " .. tostring(price.capsuleCoin) end  -- Display Capsule Coins
    if hasFragments then
      for _, frag in ipairs(fragmentTypes) do
        lines[#lines+1] = "  " .. frag
      end
    end
    if hasSouls then lines[#lines+1] = "  Souls " .. tostring(price.souls) end

    return table.concat(lines, "\n")
  end


  local function getItemsFor(pid, zone)
    if _G.ShopService and ShopService.ListForHub then
      local ok, res = pcall(ShopService.ListForHub, pid, zone)
      if ok and type(res) == "table" and #res > 0 then return res end
    end
    if _G.ShopCatalog and ShopCatalog.ListForHub then
      local ok, res = pcall(ShopCatalog.ListForHub, zone)
      if ok and type(res) == "table" and #res > 0 then return res end
    end
    -- fallback items for bring-up: include payload.companionId
    return {
      {
        id      = "merc_healer_unlock",
        name    = "Healer Mercenary",
        desc    = "Unlocks the healer companion",
        price = { gold = 0, fragments = { db = 1, digi = 1, poke = 1, chakra = 1 }, souls = 0 },
        icon    = TEX_SLOT,
        payload = { companionId = "Healer_Default" },
      },
      {
        id      = "merc_tank_unlock",
        name    = "Tank Mercenary",
        desc    = "Unlocks the tank companion",
        price = { gold = 0, fragments = { db = 1, digi = 1, poke = 1, chakra = 1 }, souls = 0 },
        icon    = TEX_SLOT,
        payload = { companionId = "Tank_Default" },
      },
    }
  end

  local function clear(pid)
    local ui = UI[pid]; if not ui then return end
    if GetLocalPlayer() == Player(pid) then
      for _, slot in ipairs(ui.icons or {}) do
        if slot.root then BlzFrameSetVisible(slot.root, false) end
      end
      if ui.tip and ui.tip.box then BlzFrameSetVisible(ui.tip.box, false) end
      if ui.noLabel then BlzFrameSetVisible(ui.noLabel, false) end
      if ui.header then BlzFrameSetVisible(ui.header, false) end
    end
    ui.icons, ui.selected = {}, nil
  end

  local function ensureHeader(pid)
    local ui = UI[pid]; if not ui then return end
    if ui.header then return ui.header end
    local h = BlzCreateFrameByType("TEXT", "Shop_Header", ui.root, "", 0)
    BlzFrameSetPoint(h, FRAMEPOINT_TOPLEFT, ui.root, FRAMEPOINT_TOPLEFT, 0.010, -0.010)
    BlzFrameSetEnable(h, false)
    ui.header = h
    return h
  end

  local function showEmpty(pid)
    local ui = UI[pid]; if not ui then return end
    if not ui.noLabel then
      ui.noLabel = BlzCreateFrameByType("TEXT", "Shop_EmptyText", ui.root, "", 0)
      BlzFrameSetPoint(ui.noLabel, FRAMEPOINT_CENTER, ui.root, FRAMEPOINT_CENTER, 0.0, 0.0)
      BlzFrameSetEnable(ui.noLabel, false)
    end
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetText(ui.noLabel, "No items available for this hub")
      BlzFrameSetVisible(ui.noLabel, true)
    end
  end

  -- Find the full catalog entry matching current selection
  local function getSelectedEntry(ui)
    if not ui or not ui.items or not ui.selected then return nil end
    for i = 1, #ui.items do
      local e = ui.items[i]
      if e and e.id == ui.selected then return e end
    end
    return nil
  end

  -- Buy action (uses payload.companionId)
  local function doBuy(pid)
  local ui = UI[pid]
  if not ui then return end

  local entry = getSelectedEntry(ui)
  if not entry then 
    dbg(pid, "No item selected")
    return
  end

  local compId = entry.payload and entry.payload.companionId
  if not compId or compId == "" then
    dbg(pid, "Catalog entry missing payload.companionId for "..tostring(entry.id))
    return
  end

  -- Check if the player can afford the item
  local okFunds, whyFunds = ShopService.CanBuy(pid, entry.id)
  if not okFunds then
    dbg(pid, "Cannot afford: " .. (whyFunds or "Insufficient currency"))
    DisplayTextToPlayer(Player(pid), 0, 0, "Cannot afford: " .. (whyFunds or "Insufficient currency"))
    return
  end

  -- Proceed with the purchase
  if _G.ShopService and ShopService.Buy then
    local ok, why = ShopService.Buy(pid, entry.id)
    dbg(pid, ok and ("Purchased " .. compId) or (why or "Buy failed"))
    if ok then
      DisplayTextToPlayer(Player(pid), 0, 0, "Purchased " .. (compId or "Item"))
    else
      DisplayTextToPlayer(Player(pid), 0, 0, "Purchase failed")
    end
  else
    dbg(pid, "ShopService not available")
  end
end

  local function buildGrid(pid)
    local ui = UI[pid]; if not ui then return end
    clear(pid)

    local zone = getZone(pid)
    local items = getItemsFor(pid, zone)
    ui.items = items

    local hdr = ensureHeader(pid)
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetText(hdr, "Shop")
      BlzFrameSetVisible(hdr, true)
    end

    if #items == 0 then
      showEmpty(pid)
      return
    end

    local startIdx = ((ui.page or 1) - 1) * PAGE_SIZE + 1
    local endIdx   = math.min(#items, startIdx + PAGE_SIZE - 1)
    local shown = 0

    for i = startIdx, endIdx do
      shown = shown + 1
      local e = items[i]

      local zero = shown - 1
      local col  = imod(zero, GRID_COLS)
      local row  = math.floor(zero / GRID_COLS)

      local x = PANEL_PAD + col * (ICON_W + ICON_GAP_X)
      local y = -PANEL_PAD - row * (ICON_H + ICON_GAP_Y)

      local btn = BlzCreateFrameByType("BUTTON", "Shop_ItemBtn_"..tostring(i), ui.root, "", 0)
      BlzFrameSetSize(btn, ICON_W, ICON_H)
      BlzFrameSetPoint(btn, FRAMEPOINT_TOPLEFT, ui.root, FRAMEPOINT_TOPLEFT, x, y)
      BlzFrameSetLevel(btn, 40)
      if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(btn, true) end

      local bg = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
      BlzFrameSetAllPoints(bg, btn)
      BlzFrameSetTexture(bg, TEX_SLOT, 0, true)
      BlzFrameSetEnable(bg, false)

      local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
      BlzFrameSetAllPoints(icon, btn)
      BlzFrameSetTexture(icon, e.icon or TEX_SLOT, 0, true)
      BlzFrameSetEnable(icon, false)

      local bodyText = buildTooltipBody(e)
      local costText = buildTooltipCost(e)
      local headline = e.name or e.id or "Item"

      local trigIn, trigOut = CreateTrigger(), CreateTrigger()
      BlzTriggerRegisterFrameEvent(trigIn, btn, FRAMEEVENT_MOUSE_ENTER)
      BlzTriggerRegisterFrameEvent(trigOut, btn, FRAMEEVENT_MOUSE_LEAVE)
      TriggerAddAction(trigIn,  function()
        showTooltipFor(pid, headline, bodyText, btn, costText)
      end)
      TriggerAddAction(trigOut, function()
        hideTooltipFor(pid)
      end)

      local trigClick = CreateTrigger()
      BlzTriggerRegisterFrameEvent(trigClick, btn, FRAMEEVENT_CONTROL_CLICK)
      TriggerAddAction(trigClick, function()
        debounce(btn)
        ui.selected = e.id
        DisplayTextToPlayer(Player(pid), 0, 0, "Selected "..tostring(e.name or e.id))
      end)

      ui.icons[#ui.icons+1] = { root = btn, id = e.id }
    end

    -- Ensure Buy button exists once
    if not ui.buyBtn then
      local buyBtn = BlzCreateFrameByType("BUTTON", "Shop_BuyBtn", ui.root, "", 0)
      BlzFrameSetSize(buyBtn, BUY_W, BUY_H)
      BlzFrameSetPoint(buyBtn, FRAMEPOINT_BOTTOM, ui.root, FRAMEPOINT_BOTTOM, BUY_OFF_X, BUY_OFF_Y)
      BlzFrameSetLevel(buyBtn, 50)

      local plate = BlzCreateFrameByType("BACKDROP", "", buyBtn, "", 0)
      BlzFrameSetAllPoints(plate, buyBtn)
      BlzFrameSetTexture(plate, TEX_SLOT, 0, true)
      BlzFrameSetEnable(plate, false)

      local ico = BlzCreateFrameByType("BACKDROP", "", buyBtn, "", 0)
      BlzFrameSetAllPoints(ico, buyBtn)
      BlzFrameSetTexture(ico, TEX_BUY_ICON, 0, true)
      BlzFrameSetEnable(ico, false)

      local txt = BlzCreateFrameByType("TEXT", "Shop_BuyText", ui.root, "", 0)
      BlzFrameSetPoint(txt, FRAMEPOINT_LEFT, buyBtn, FRAMEPOINT_RIGHT, BUY_TEXT_OFF_X, 0.0)
      BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
      BlzFrameSetText(txt, BUY_LABEL)
      BlzFrameSetLevel(txt, 51)
      BlzFrameSetEnable(txt, false)

      local trigBuy = CreateTrigger()
      BlzTriggerRegisterFrameEvent(trigBuy, buyBtn, FRAMEEVENT_CONTROL_CLICK)
      TriggerAddAction(trigBuy, function() doBuy(pid) end)

      ui.buyBtn, ui.buyTxt, ui.buyIcon = buyBtn, txt, ico
    else
      if GetLocalPlayer() == Player(pid) then
        BlzFrameSetVisible(ui.buyBtn, true)
        BlzFrameSetVisible(ui.buyTxt, true)
      end
    end
  end

  function ShopUI.RenderIn(pid, parent)
    local ui = UI[pid]
    if not ui then
      ui = { root = parent, page = 1, icons = {}, tip = nil, noLabel = nil, header = nil, buyBtn = nil }
      UI[pid] = ui
    else
      ui.root = parent
      ui.page = 1
    end
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetTexture(parent, TEX_PANEL_DARK, 0, true)
      BlzFrameSetVisible(parent, true)
    end
    buildGrid(pid)
  end

  function ShopUI.Hide(pid)
    local ui = UI[pid]; if not ui then return end
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(ui.root, false) end
    UI[pid] = nil
  end

  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("ShopUI")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end