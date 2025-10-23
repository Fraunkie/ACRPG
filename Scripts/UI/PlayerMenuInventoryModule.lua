if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_InventoryModule.lua") end
--==================================================
-- PlayerMenu_InventoryModule.lua  (Click-to-Equip, WC3-safe)
-- • Uses InventoryService for all data logic
-- • Adds proper Hands slot mapped to Bracers
-- • Restores AddItem / IsFull delegates for ItemPickupBridge
-- • No use of % anywhere
--==================================================

do
  PlayerMenu_InventoryModule = PlayerMenu_InventoryModule or {}
  _G.PlayerMenu_InventoryModule = PlayerMenu_InventoryModule

  --------------------------------------------------
  -- Config
  --------------------------------------------------
  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background"
  local TEX_SLOT       = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
  local TEX_EMPTY_EQ   = "ReplaceableTextures\\CommandButtons\\PASEmptyEQSlot.blp"
  local TEX_EMPTY_INV  = "ReplaceableTextures\\CommandButtons\\PASEmptyInvSlot.blp"

  local GRID_ROWS, GRID_COLS = 4, 6
  local SLOT_W,   SLOT_H     = 0.028, 0.028
  local GAP                  = 0.006

  local EQUIP_W, EQUIP_H = 0.036, 0.036
  local EQUIP_GAP        = 0.008
  local PAPER_W, PAPER_H = 0.22,  0.22
  local PAPER_OFF_X, PAPER_OFF_Y = 0.00, -0.02

  -- UI-visible slots (Hands added)
  local EQUIP_SLOTS_LEFT  = { "Weapon", "Offhand", "Head", "Necklace" }
  local EQUIP_SLOTS_RIGHT = { "Chest", "Legs", "Boots", "Accessory", "Hands" }

  local CATEGORY_TO_SLOT = {
    WEAPON   = "Weapon",
    OFFHAND  = "Offhand",
    HEAD     = "Head",
    NECKLACE = "Necklace",
    CHEST    = "Chest",
    LEGS     = "Legs",
    BOOTS    = "Boots",
    ACCESSORY= "Accessory",
    RING     = "Accessory",
    HANDS    = "Hands",
  }

  -- Map UI names -> service names
  local function toServiceSlot(uiSlot)
    if uiSlot == "Offhand"  then return "Shield"  end
    if uiSlot == "Necklace" then return "Amulet"  end
    if uiSlot == "Hands"    then return "Bracers" end
    return uiSlot
  end

  --------------------------------------------------
  -- State (UI only)
  --------------------------------------------------
  local UI = {}
  local ItemIcons = rawget(_G, "ItemIcons")

  --------------------------------------------------
  -- Helpers
  --------------------------------------------------
  local function debounce(btn)
    BlzFrameSetEnable(btn, false)
    BlzFrameSetEnable(btn, true)
  end

  local function idxWrap(n, k)
    if n <= 0 then return 1 end
    local v = k
    while v > n do v = v - n end
    while v <= 0 do v = v + n end
    return v
  end

  local function iconForItemId(id, pick)
    if _G.ItemDatabase and ItemDatabase.GetData then
      local d = ItemDatabase.GetData(id)
      if d and d.iconpath and d.iconpath ~= "" then return d.iconpath end
    end
    if ItemIcons and ItemIcons.Get then
      local ok, tex = pcall(ItemIcons.Get, id)
      if ok and type(tex) == "string" and tex ~= "" then return tex end
    end
    local samples = {
      "ReplaceableTextures\\CommandButtons\\BTNClawsOfAttack.blp",
      "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp",
      "ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp",
      "ReplaceableTextures\\CommandButtons\\BTNGloves.blp",
      "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
      "ReplaceableTextures\\CommandButtons\\BTNThunderClap.blp",
    }
    return samples[idxWrap(#samples, math.abs(pick or id or 1))]
  end

  local function makeItemTooltip(id)
    if not id then return "|cffaaaaaaEmpty|r\nNo details." end
    if _G.ItemDatabase and ItemDatabase.GetTooltip then
      local ok, tip = pcall(ItemDatabase.GetTooltip, id)
      if ok and type(tip) == "string" and tip ~= "" then return tip end
    end
    return "|cffffee88Item|r " .. tostring(id)
  end

  --------------------------------------------------
  -- Tooltip UI
  --------------------------------------------------
  local function ensureTooltip(pid, parent)
    local ui = UI[pid]; if not ui then return end
    if ui.tip then return ui.tip end
    local box = BlzCreateFrameByType("BACKDROP", "PM_TooltipBox", parent, "", 0)
    BlzFrameSetSize(box, 0.24, 0.12)
    BlzFrameSetTexture(box, TEX_PANEL_DARK, 0, true)
    BlzFrameSetAlpha(box, 230)
    BlzFrameSetLevel(box, 50)

    local txt = BlzCreateFrameByType("TEXT", "PM_TooltipText", box, "", 0)
    BlzFrameSetPoint(txt, FRAMEPOINT_TOPLEFT, box, FRAMEPOINT_TOPLEFT, 0.008, -0.008)
    BlzFrameSetPoint(txt, FRAMEPOINT_BOTTOMRIGHT, box, FRAMEPOINT_BOTTOMRIGHT, -0.008, 0.008)
    BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetEnable(box, false)
    BlzFrameSetVisible(box, false)

    local tipObj = { box = box, text = txt }
    ui.tip = tipObj
    return tipObj
  end

  local function tooltipShow(pid, anchor, text)
    local ui = UI[pid]; if not ui then return end
    local tip = ensureTooltip(pid, ui.root)
    BlzFrameSetText(tip.text, text or "")
    BlzFrameClearAllPoints(tip.box)
    BlzFrameSetPoint(tip.box, FRAMEPOINT_LEFT, anchor, FRAMEPOINT_RIGHT, 0.010, 0.0)
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(tip.box, true) end
  end

  local function tooltipHide(pid)
    local ui = UI[pid]; if not ui or not ui.tip then return end
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(ui.tip.box, false) end
  end

  --------------------------------------------------
  -- UI Builders
  --------------------------------------------------
  local function buildPaperAnchor(parent)
    local paper = BlzCreateFrameByType("BACKDROP", "PM_InvPaperAnchor", parent, "", 0)
    BlzFrameSetSize(paper, PAPER_W, PAPER_H)
    BlzFrameSetPoint(paper, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, PAPER_OFF_X, PAPER_OFF_Y)
    BlzFrameSetTexture(paper, TEX_PANEL_DARK, 0, true)
    BlzFrameSetAlpha(paper, 128)
    return paper
  end

  local function buildEquipStrip(pid, parent, paper)
    local slots = {}

    local function makeSlot(name, point, relPoint, dx, rowIndex)
      local btn = BlzCreateFrameByType("BUTTON", "PM_Equip_" .. name, parent, "", 0)
      BlzFrameSetSize(btn, EQUIP_W, EQUIP_H)
      local yoff = 0.08 - (rowIndex - 1) * (EQUIP_H + EQUIP_GAP)
      BlzFrameSetPoint(btn, point, paper, relPoint, dx, yoff)

      local bg = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
      BlzFrameSetAllPoints(bg, btn)
      BlzFrameSetTexture(bg, TEX_SLOT, 0, true)

      local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
      BlzFrameSetAllPoints(icon, btn)
      BlzFrameSetTexture(icon, TEX_EMPTY_EQ, 0, true)

      local trig = CreateTrigger()
      BlzTriggerRegisterFrameEvent(trig, btn, FRAMEEVENT_CONTROL_CLICK)
      TriggerAddAction(trig, function()
        debounce(btn)
        local serviceSlot = toServiceSlot(name)
        local ok = false
        if _G.InventoryService and InventoryService.Unequip then
          ok = InventoryService.Unequip(pid, serviceSlot)
        end
        if not ok then
          local list = _G.InventoryService and InventoryService.List and InventoryService.List(pid)
          local free = 0
          if list then
            for i = 1, (GRID_ROWS * GRID_COLS) do
              if not list[i] then free = 1; break end
            end
          end
          local reason = (free == 0) and "bag is full" or "slot is empty"
          DisplayTextToPlayer(Player(pid), 0, 0, "[Unequip] " .. name .. " failed: " .. reason)
        end
        PlayerMenu_InventoryModule.Render(pid)
      end)

      local trigIn, trigOut = CreateTrigger(), CreateTrigger()
      BlzTriggerRegisterFrameEvent(trigIn,  btn, FRAMEEVENT_MOUSE_ENTER)
      BlzTriggerRegisterFrameEvent(trigOut, btn, FRAMEEVENT_MOUSE_LEAVE)
      TriggerAddAction(trigIn,  function()
        local equippedId = nil
        if _G.InventoryService and InventoryService.GetEquipped then
          local eq = InventoryService.GetEquipped(pid)
          equippedId = eq[toServiceSlot(name)]
        end
        tooltipShow(pid, btn, makeItemTooltip(equippedId))
      end)
      TriggerAddAction(trigOut, function() tooltipHide(pid) end)

      slots[name] = { btn = btn, icon = icon }
    end

    for i = 1, #EQUIP_SLOTS_LEFT  do makeSlot(EQUIP_SLOTS_LEFT[i],  FRAMEPOINT_RIGHT, FRAMEPOINT_LEFT,  -PAPER_W * 0.05, i) end
    for i = 1, #EQUIP_SLOTS_RIGHT do makeSlot(EQUIP_SLOTS_RIGHT[i], FRAMEPOINT_LEFT,  FRAMEPOINT_RIGHT,  PAPER_W * 0.05, i) end
    return slots
  end

  local function buildGrid(pid, parent)
    local grid = {}

    local holder = BlzCreateFrameByType("BACKDROP", "PM_InvGridHolder", parent, "", 0)
    local totalW = GRID_COLS * SLOT_W + (GRID_COLS - 1) * GAP
    local totalH = GRID_ROWS * SLOT_H + (GRID_ROWS - 1) * GAP
    BlzFrameSetSize(holder, totalW, totalH)
    BlzFrameSetPoint(holder, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, 0.0, 0.019)
    BlzFrameSetTexture(holder, TEX_PANEL_DARK, 0, true)
    BlzFrameSetAlpha(holder, 160)

    local idx = 1
    for r = 1, GRID_ROWS do
      for c = 1, GRID_COLS do
        local cell = BlzCreateFrameByType("BACKDROP", "", holder, "", 0)
        BlzFrameSetSize(cell, SLOT_W, SLOT_H)
        local x = (c - 1) * (SLOT_W + GAP)
        local y = (r - 1) * (SLOT_H + GAP)
        BlzFrameSetPoint(cell, FRAMEPOINT_BOTTOMLEFT, holder, FRAMEPOINT_BOTTOMLEFT, x, y)
        BlzFrameSetTexture(cell, TEX_SLOT, 0, true)

        local btn = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
        BlzFrameSetAllPoints(btn, cell)
        local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
        BlzFrameSetAllPoints(icon, btn)
        BlzFrameSetTexture(icon, TEX_EMPTY_INV, 0, true)
        grid[idx] = { btn = btn, icon = icon }

        local idxCap = idx
        local trigClick = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigClick, btn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigClick, function()
          debounce(btn)
          local ok = false
          if _G.InventoryService and InventoryService.Equip then
            ok = InventoryService.Equip(pid, idxCap)
          end
          if not ok then
            DisplayTextToPlayer(Player(pid), 0, 0, "Cannot equip this item")
          end
          PlayerMenu_InventoryModule.Render(pid)
        end)
        idx = idx + 1
      end
    end
    return holder, grid
  end

  --------------------------------------------------
  -- Rendering
  --------------------------------------------------
  local function renderEquipsFromService(pid)
    local ui = UI[pid]; if not ui then return end
    local eq = _G.InventoryService and InventoryService.GetEquipped and InventoryService.GetEquipped(pid) or {}
    for _, name in ipairs(EQUIP_SLOTS_LEFT) do
      local sid = toServiceSlot(name)
      local id = eq[sid]
      BlzFrameSetTexture(ui.equipSlots[name].icon, id and iconForItemId(id, 900) or TEX_EMPTY_EQ, 0, true)
    end
    for _, name in ipairs(EQUIP_SLOTS_RIGHT) do
      local sid = toServiceSlot(name)
      local id = eq[sid]
      BlzFrameSetTexture(ui.equipSlots[name].icon, id and iconForItemId(id, 901) or TEX_EMPTY_EQ, 0, true)
    end
  end

  local function renderGridFromService(pid)
    local ui = UI[pid]; if not ui then return end
    local list = _G.InventoryService and InventoryService.List and InventoryService.List(pid)
    local total = GRID_ROWS * GRID_COLS
    for i = 1, total do
      local id = list and list[i] or nil
      BlzFrameSetTexture(ui.grid[i].icon, id and iconForItemId(id, i) or TEX_EMPTY_INV, 0, true)
    end
  end

  local function rerenderAll(pid)
    renderEquipsFromService(pid)
    renderGridFromService(pid)
  end

  --------------------------------------------------
  -- Public API (delegates used by ItemPickupBridge)
  --------------------------------------------------
  function PlayerMenu_InventoryModule.IsFull(pid)
    if _G.InventoryService and InventoryService.IsFull then
      return InventoryService.IsFull(pid)
    end
    return true
  end

  function PlayerMenu_InventoryModule.AddItem(pid, itemId)
    if not (_G.InventoryService and InventoryService.Add) then return false end
    local idx = InventoryService.Add(pid, itemId)
    if UI[pid] then renderGridFromService(pid) end
    return idx ~= nil
  end

  function PlayerMenu_InventoryModule.Render(pid)
    if UI[pid] then rerenderAll(pid) end
  end

  --------------------------------------------------
  -- Show / Hide
  --------------------------------------------------
  function PlayerMenu_InventoryModule.ShowInto(pid, contentFrame)
    if UI[pid] then
      if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(UI[pid].root, true) end
      rerenderAll(pid)
      return
    end

    local ui = { root = contentFrame }
    UI[pid] = ui
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(contentFrame, true) end
    BlzFrameSetTexture(contentFrame, TEX_PANEL_DARK, 0, true)

    ui.paper = buildPaperAnchor(contentFrame)
    ui.equipSlots = buildEquipStrip(pid, contentFrame, ui.paper)
    ui.gridHolder, ui.grid = buildGrid(pid, contentFrame)

    rerenderAll(pid)
  end

  function PlayerMenu_InventoryModule.Hide(pid)
    local ui = UI[pid]; if not ui then return end
    if GetLocalPlayer() == Player(pid) then
      if ui.paper then BlzFrameSetVisible(ui.paper, false) end
      if ui.gridHolder then BlzFrameSetVisible(ui.gridHolder, false) end
      if ui.equipSlots then
        for _, slot in pairs(ui.equipSlots) do BlzFrameSetVisible(slot.btn, false) end
      end
      if ui.tip then BlzFrameSetVisible(ui.tip.box, false) end
      BlzFrameSetVisible(ui.root, false)
    end
    UI[pid] = nil
  end
end

if Debug and Debug.endFile then Debug.endFile() end
