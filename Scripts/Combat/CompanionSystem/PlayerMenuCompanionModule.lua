if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_CompanionsModule.lua") end
--==================================================
-- PlayerMenu_CompanionsModule.lua  (v1.1 MAIN)
-- Matches Inventory look but uses smaller tiles.
-- • Gate: requires license item I00H
-- • Shows ONLY unlocked companions from PlayerData
-- • 3x6 grid of 0.022 tiles, gap 0.005
-- • Tooltip identical to Inventory behavior
-- • Summon square button under grid (calls CompanionSystem)
--==================================================

do
  PlayerMenu_CompanionsModule = PlayerMenu_CompanionsModule or {}
  _G.PlayerMenu_CompanionsModule = PlayerMenu_CompanionsModule

  --------------------------------------------------
  -- Style (reuse Inventory vibes)
  --------------------------------------------------
  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
  local TEX_SLOT       = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller.blp"
  local TEX_ICON_FALL  = "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp" -- temp
  local TEX_BTN_SUMMON = TEX_SLOT

  local TITLE_OFF_X, TITLE_OFF_Y = 0.012, -0.012
  local DESC_OFF_X,  DESC_OFF_Y  = 0.012, -0.042

  local SLOT_W, SLOT_H = 0.022, 0.022
  local GAP            = 0.005
  local GRID_ROWS, GRID_COLS = 3, 6
  local GRID_BOTTOM_OFFSET   = 0.010
  local SUMMON_W, SUMMON_H   = 0.024, 0.024

  --------------------------------------------------
  -- License gate (strict check)
  --------------------------------------------------
  local ITEM_COMPANION_LICENSE = "I00H"

  local function HasCompanionLicense(pid)
    -- Strict check: only return true if I00H is actually in the custom inventory
    local svc = rawget(_G, "InventoryService")
    if not (svc and svc.List and FourCC) then return false end

    local wantNum = FourCC(ITEM_COMPANION_LICENSE)
    local list = svc.List(pid)
    if type(list) ~= "table" then return false end

    local function normEntry(e)
      if type(e) == "number" then return e end
      if type(e) == "table" then
        if type(e.typeId) == "number" then return e.typeId end
        if type(e.id)     == "number" then return e.id end
        if type(e.rawcode)== "string" then return FourCC(e.rawcode) end
        if type(e.code)   == "string" then return FourCC(e.code) end
      end
      if type(e) == "string" then return FourCC(e) end
      return nil
    end

    for _, entry in pairs(list) do
      local tid = normEntry(entry)
      if tid and tid == wantNum then
        return true
      end
    end
    return false
  end

  --------------------------------------------------
  -- Tooltip (identical to Inventory)
  --------------------------------------------------
  local TIP = {}

  local function ensureTooltip(pid, parent)
    local t = TIP[pid]
    if t then return t end

    local box = BlzCreateFrameByType("BACKDROP", "PM_Comp_TipBox", parent, "", 0)
    BlzFrameSetSize(box, 0.26, 0.14)
    BlzFrameSetTexture(box, TEX_PANEL_DARK, 0, true)
    BlzFrameSetAlpha(box, 230)
    BlzFrameSetLevel(box, 50)
    BlzFrameSetEnable(box, false)
    BlzFrameSetVisible(box, false)

    local txt = BlzCreateFrameByType("TEXT", "PM_Comp_TipText", box, "", 0)
    BlzFrameSetPoint(txt, FRAMEPOINT_TOPLEFT,     box, FRAMEPOINT_TOPLEFT,     0.008, -0.008)
    BlzFrameSetPoint(txt, FRAMEPOINT_BOTTOMRIGHT, box, FRAMEPOINT_BOTTOMRIGHT, -0.008,  0.008)
    BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetEnable(txt, false)

    t = { box = box, text = txt }
    TIP[pid] = t
    return t
  end

  local function tooltipShow(pid, anchor, text, parent)
    local tip = ensureTooltip(pid, parent)
    BlzFrameSetText(tip.text, text or "")
    BlzFrameClearAllPoints(tip.box)
    BlzFrameSetPoint(tip.box, FRAMEPOINT_LEFT, anchor, FRAMEPOINT_RIGHT, 0.010, 0.0)
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(tip.box, true) end
  end

  local function tooltipHide(pid)
    local t = TIP[pid]; if not t then return end
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(t.box, false) end
  end

  --------------------------------------------------
  -- Catalog helpers
  --------------------------------------------------
  local function getCompanionData(id)
    local CC = rawget(_G, "CompanionCatalog")
    if CC and CC.Get then
      local ok, d = pcall(CC.Get, id)
      if ok and type(d) == "table" then return d end
    end
    return nil
  end

  local function iconFor(id)
    local d = getCompanionData(id)
    if d and d.icon and d.icon ~= "" then return d.icon end
    return TEX_ICON_FALL
  end

  local function tipFor(id)
    local d = getCompanionData(id)
    local title = (d and d.name) or tostring(id)
    local role  = (d and d.role) and ("Role: "..tostring(d.role)) or "Role: Unknown"
    local desc  = (d and d.desc) or "No details"
    return "|cffffee88"..title.."|r\n"..role.."\n"..desc
  end

  --------------------------------------------------
  -- UI cache
  --------------------------------------------------
  local UI = {}

  local function debounce(btn)
    if not btn then return end
    BlzFrameSetEnable(btn, false)
    BlzFrameSetEnable(btn, true)
  end

  local function ensureTitle(pid, parent)
    local ui = UI[pid]
    if ui.title then return ui.title end
    local t = BlzCreateFrameByType("TEXT", "PM_Comp_Title", parent, "", 0)
    BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, TITLE_OFF_X, TITLE_OFF_Y)
    BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetText(t, "Companions")
    BlzFrameSetEnable(t, false)
    ui.title = t
    return t
  end

  local function ensureDesc(pid, parent)
    local ui = UI[pid]
    if ui.desc then return ui.desc end
    local d = BlzCreateFrameByType("TEXT", "PM_Comp_Desc", parent, "", 0)
    BlzFrameSetSize(d, 0.46, 0.28)
    BlzFrameSetPoint(d, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, DESC_OFF_X, DESC_OFF_Y)
    BlzFrameSetTextAlignment(d, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetEnable(d, false)
    ui.desc = d
    return d
  end

  local function clearGrid(pid)
    local ui = UI[pid]; if not ui then return end
    if ui.tiles then
      if GetLocalPlayer() == Player(pid) then
        for _, t in ipairs(ui.tiles) do
          if t.btn then BlzFrameSetVisible(t.btn, false) end
          if t.icon then BlzFrameSetVisible(t.icon, false) end
          if t.cell then BlzFrameSetVisible(t.cell, false) end
        end
      end
      ui.tiles = {}
    end
    if ui.gridHolder and GetLocalPlayer() == Player(pid) then
      BlzFrameSetVisible(ui.gridHolder, false)
    end
    ui.gridHolder = nil
  end

  local function setSelected(pid, id)
    local ui = UI[pid]; if not ui then return end
    ui.selectedId = id
    for _, t in ipairs(ui.tiles or {}) do
      if t.btn then BlzFrameSetScale(t.btn, (t.id == id) and 1.06 or 1.00) end
    end
    if ui.summonBtn then
      local on = (id ~= nil)
      if GetLocalPlayer() == Player(pid) then BlzFrameSetEnable(ui.summonBtn, on) end
    end
    local PD = rawget(_G, "PlayerData")
    if PD and PD.SetActiveCompanionId then PD.SetActiveCompanionId(pid, id) end
  end

  local function ensureSummon(pid, parent)
    local ui = UI[pid]
    if ui.summonBtn then return ui.summonBtn end
    local b = BlzCreateFrameByType("BUTTON", "PM_Comp_Summon", parent, "", 0)
    BlzFrameSetSize(b, SUMMON_W, SUMMON_H)
    BlzFrameSetPoint(b, FRAMEPOINT_BOTTOMLEFT, parent, FRAMEPOINT_BOTTOMLEFT, 0.012, 0.012)

    local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
    BlzFrameSetAllPoints(bg, b)
    BlzFrameSetTexture(bg, TEX_BTN_SUMMON, 0, true)
    BlzFrameSetEnable(bg, false)

    local txt = BlzCreateFrameByType("TEXT", "", b, "", 0)
    BlzFrameSetPoint(txt, FRAMEPOINT_LEFT, b, FRAMEPOINT_RIGHT, 0.008, 0.0)
    BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetText(txt, "Summon")

    local trig = CreateTrigger()
    BlzTriggerRegisterFrameEvent(trig, b, FRAMEEVENT_CONTROL_CLICK)
    TriggerAddAction(trig, function()
      debounce(b)
      local id = UI[pid] and UI[pid].selectedId or nil
      if not id then
        DisplayTextToPlayer(Player(pid), 0, 0, "Select a companion first")
        return
      end
      -- Call the live system to summon; it will despawn an existing one if present.
      if _G.CompanionSystem and CompanionSystem.Summon then
        local ok = CompanionSystem.Summon(pid, id)
        if ok then
          DisplayTextToPlayer(Player(pid), 0, 0, "Summoned "..tostring(id))
        else
          DisplayTextToPlayer(Player(pid), 0, 0, "Failed to summon "..tostring(id))
        end
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Companion system not available")
      end
    end)

    local ti, to = CreateTrigger(), CreateTrigger()
    BlzTriggerRegisterFrameEvent(ti, b, FRAMEEVENT_MOUSE_ENTER)
    BlzTriggerRegisterFrameEvent(to, b, FRAMEEVENT_MOUSE_LEAVE)
    TriggerAddAction(ti, function() tooltipShow(pid, b, "Summon the selected companion", parent) end)
    TriggerAddAction(to, function() tooltipHide(pid) end)

    ui.summonBtn = b
    if GetLocalPlayer() == Player(pid) then BlzFrameSetEnable(b, false) end
    return b
  end

  private = private or {}
  local function buildGrid(pid, parent, unlocked)
    clearGrid(pid)
    local ui = UI[pid]
    local holder = BlzCreateFrameByType("BACKDROP", "PM_Comp_GridHolder", parent, "", 0)
    local totalW = GRID_COLS * SLOT_W + (GRID_COLS - 1) * GAP
    local totalH = GRID_ROWS * SLOT_H + (GRID_ROWS - 1) * GAP
    BlzFrameSetSize(holder, totalW, totalH)
    BlzFrameSetPoint(holder, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, 0.0, GRID_BOTTOM_OFFSET)
    BlzFrameSetTexture(holder, TEX_PANEL_DARK, 0, true)
    BlzFrameSetAlpha(holder, 160)
    BlzFrameSetEnable(holder, false)
    ui.gridHolder = holder
    ui.tiles = {}

    local index = 1
    for r = 1, GRID_ROWS do
      for c = 1, GRID_COLS do
        local id = unlocked[index]
        local cell = BlzCreateFrameByType("BACKDROP", "", holder, "", 0)
        BlzFrameSetSize(cell, SLOT_W, SLOT_H)
        local x = (c - 1) * (SLOT_W + GAP)
        local y = (r - 1) * (SLOT_H + GAP)
        BlzFrameSetPoint(cell, FRAMEPOINT_BOTTOMLEFT, holder, FRAMEPOINT_BOTTOMLEFT, x, y)
        BlzFrameSetTexture(cell, TEX_SLOT, 0, true)
        BlzFrameSetEnable(cell, false)

        local btn = BlzCreateFrameByType("BUTTON", "", cell, "", 0)
        BlzFrameSetAllPoints(btn, cell)

        local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
        BlzFrameSetAllPoints(icon, btn)
        BlzFrameSetTexture(icon, id and iconFor(id) or TEX_SLOT, 0, true)
        BlzFrameSetEnable(icon, false)

        local rec = { id = id, cell = cell, btn = btn, icon = icon }
        ui.tiles[#ui.tiles+1] = rec

        if id then
          local ti, to, tc = CreateTrigger(), CreateTrigger(), CreateTrigger()
          BlzTriggerRegisterFrameEvent(ti, btn, FRAMEEVENT_MOUSE_ENTER)
          BlzTriggerRegisterFrameEvent(to, btn, FRAMEEVENT_MOUSE_LEAVE)
          BlzTriggerRegisterFrameEvent(tc, btn, FRAMEEVENT_CONTROL_CLICK)
          TriggerAddAction(ti, function() tooltipShow(pid, btn, tipFor(id), parent) end)
          TriggerAddAction(to, function() tooltipHide(pid) end)
          TriggerAddAction(tc, function()
            debounce(btn)
            setSelected(pid, id)
            DisplayTextToPlayer(Player(pid), 0, 0, "Selected "..tostring(id))
          end)
        else
          if GetLocalPlayer() == Player(pid) then BlzFrameSetEnable(btn, false) end
        end

        index = index + 1
      end
    end

    ensureSummon(pid, parent)
    setSelected(pid, nil)
  end

  --------------------------------------------------
  -- Rendering
  --------------------------------------------------
  local function renderLocked(pid)
    local ui = UI[pid]; if not ui then return end
    ensureTitle(pid, ui.root)
    local d = ensureDesc(pid, ui.root)
    BlzFrameSetText(d,
      "Requires the Companion License to use this panel.\n" ..
      "Obtain the license and reopen the menu.")
    clearGrid(pid)
    if ui.summonBtn and GetLocalPlayer() == Player(pid) then BlzFrameSetEnable(ui.summonBtn, false) end
  end

  local function renderUnlocked(pid)
    local ui = UI[pid]; if not ui then return end
    ensureTitle(pid, ui.root)
    local d = ensureDesc(pid, ui.root)
    BlzFrameSetText(d, "Select a companion, then press Summon.")

    local PD = rawget(_G, "PlayerData")
    local unlocked = {}
    if PD and PD.ListCompanions then
      local ok, list = pcall(PD.ListCompanions, pid)
      if ok and type(list) == "table" then unlocked = list end
    end

    if #unlocked == 0 then
      BlzFrameSetText(d, "You have not unlocked any companions yet.")
      clearGrid(pid)
      if ui.summonBtn and GetLocalPlayer() == Player(pid) then BlzFrameSetEnable(ui.summonBtn, false) end
      return
    end

    local pageCap = GRID_ROWS * GRID_COLS
    if #unlocked > pageCap then
      local slim = {}
      for i = 1, pageCap do slim[i] = unlocked[i] end
      unlocked = slim
    end

    buildGrid(pid, ui.root, unlocked)
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function PlayerMenu_CompanionsModule.ShowInto(pid, contentFrame)
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetTexture(contentFrame, TEX_PANEL_DARK, 0, true)
      BlzFrameSetVisible(contentFrame, true)
    end

    local ui = UI[pid]
    if not ui then
      ui = { root = contentFrame, title = nil, desc = nil, tiles = {}, gridHolder = nil, summonBtn = nil, selectedId = nil }
      UI[pid] = ui
    else
      ui.root = contentFrame
    end

    if HasCompanionLicense(pid) then
      renderUnlocked(pid)
    else
      renderLocked(pid)
    end
  end

  function PlayerMenu_CompanionsModule.Hide(pid)
    local ui = UI[pid]; if not ui then return end
    tooltipHide(pid)
    clearGrid(pid)
    if GetLocalPlayer() == Player(pid) then
      if ui.title then BlzFrameSetVisible(ui.title, false) end
      if ui.desc  then BlzFrameSetVisible(ui.desc,  false) end
      if ui.summonBtn then BlzFrameSetVisible(ui.summonBtn, false) end
      BlzFrameSetVisible(ui.root, false)
    end
    UI[pid] = nil
  end

  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("PlayerMenu_CompanionsModule")
    end
    if Debug and Debug.printf then Debug.printf("[PlayerMenu_CompanionsModule v1.1] ready") end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
