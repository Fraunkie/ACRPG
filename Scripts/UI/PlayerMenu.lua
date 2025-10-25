if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu.lua") end
--==================================================
-- PlayerMenu.lua
-- Main menu with a left button rail and a right content pane.
-- • L toggles menu (KeyEventHandler calls PlayerMenu.Toggle(pid))
-- • Opening one module hides the others
-- • Fixed texture paths (.blp) to remove green backdrops
--==================================================

do
  PlayerMenu = PlayerMenu or {}
  _G.PlayerMenu = PlayerMenu

  --------------------------------------------------
  -- Global UI helper (bounce frame to release focus)
  --------------------------------------------------
  UIUtil = UIUtil or {}
  function UIUtil.BounceFrame(frame, pid)
    if frame and GetLocalPlayer() == Player(pid) then
      BlzFrameSetEnable(frame, false)
      BlzFrameSetEnable(frame, true)
    end
  end

  --------------------------------------------------
  -- Style
  --------------------------------------------------
  local TEX_BG_LIGHT   = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
  local TEX_BTN        = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller.blp"

  local W_OUT, H_OUT   = 0.58, 0.40
  local RAIL_W         = 0.18
  local PAD            = 0.012
  local BTN_H          = 0.050
  local BTN_GAP        = 0.012

  --------------------------------------------------
  -- State
  --------------------------------------------------
  local S = {} -- S[pid] = {root, rail, content, open, activeId}
  local parent

  local function ensure(pid)
    local t = S[pid]; if t then return t end
    t = { open = false, activeId = nil }
    S[pid] = t

    parent = parent or BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

    -- outer light bg
    local root = BlzCreateFrameByType("BACKDROP", "PM_Root", parent, "", 0)
    BlzFrameSetSize(root, W_OUT, H_OUT)
    BlzFrameSetPoint(root, FRAMEPOINT_CENTER, parent, FRAMEPOINT_CENTER, 0, 0.12)
    BlzFrameSetTexture(root, TEX_BG_LIGHT, 0, true)
    BlzFrameSetEnable(root, false)
    BlzFrameSetVisible(root, false)
    BlzFrameSetLevel(root, 4)
    t.root = root

    -- left rail
    local rail = BlzCreateFrameByType("BACKDROP", "PM_Rail", root, "", 0)
    BlzFrameSetSize(rail, RAIL_W, H_OUT - PAD * 2)
    BlzFrameSetPoint(rail, FRAMEPOINT_TOPLEFT, root, FRAMEPOINT_TOPLEFT, PAD, -PAD)
    BlzFrameSetTexture(rail, TEX_PANEL_DARK, 0, true)
    BlzFrameSetEnable(rail, false)
    BlzFrameSetLevel(rail, 5)
    t.rail = rail

    -- right content
    local content = BlzCreateFrameByType("BACKDROP", "PM_Content", root, "", 0)
    BlzFrameSetSize(content, W_OUT - RAIL_W - PAD * 3, H_OUT - PAD * 2)
    BlzFrameSetPoint(content, FRAMEPOINT_TOPLEFT, rail, FRAMEPOINT_TOPRIGHT, PAD, 0)
    BlzFrameSetTexture(content, TEX_PANEL_DARK, 0, true)
    BlzFrameSetEnable(content, false)
    BlzFrameSetLevel(content, 6)
    t.content = content

    -- titles
    local titleMenu = BlzCreateFrameByType("TEXT", "", root, "", 0)
    BlzFrameSetPoint(titleMenu, FRAMEPOINT_TOPLEFT, rail, FRAMEPOINT_TOPLEFT, 0.012, -0.012)
    BlzFrameSetTextAlignment(titleMenu, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetText(titleMenu, "Menu")

    local titleInfo = BlzCreateFrameByType("TEXT", "", root, "", 0)
    BlzFrameSetPoint(titleInfo, FRAMEPOINT_TOPLEFT, content, FRAMEPOINT_TOPLEFT, 0.012, -0.012)
    BlzFrameSetTextAlignment(titleInfo, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
    BlzFrameSetText(titleInfo, "Info")

    -- small helper to make a button on the rail
    local function makeButton(yOff, label, onClick)
      local b = BlzCreateFrameByType("BUTTON", "", rail, "", 0)
      BlzFrameSetSize(b, RAIL_W - PAD * 2, BTN_H)
      BlzFrameSetPoint(b, FRAMEPOINT_TOPLEFT, rail, FRAMEPOINT_TOPLEFT, PAD, -yOff)

      local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
      BlzFrameSetAllPoints(bg, b)
      BlzFrameSetTexture(bg, TEX_BTN, 0, true)

      local txt = BlzCreateFrameByType("TEXT", "", b, "", 0)
      BlzFrameSetPoint(txt, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
      BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
      BlzFrameSetText(txt, label)

      local trig = CreateTrigger()
      BlzTriggerRegisterFrameEvent(trig, b, FRAMEEVENT_CONTROL_CLICK)
      TriggerAddAction(trig, function()
        onClick()
        UIUtil.BounceFrame(b, pid)
      end)
      return b
    end

    local y = 0.036 + BTN_H

    -- Save / Load
    makeButton(y, "Load  Save", function()
      PlayerMenu.ShowModule(pid, "save")
    end)
    y = y + BTN_H + BTN_GAP

    -- Stats
    makeButton(y, "Character Stats", function()
      PlayerMenu.ShowModule(pid, "stats")
    end)
    y = y + BTN_H + BTN_GAP

    -- Inventory
    makeButton(y, "Inventory", function()
      PlayerMenu.ShowModule(pid, "inventory")
    end)

    return t
  end

  --------------------------------------------------
  -- Module plumbing
  --------------------------------------------------
  local function hideAll(pid)
    local t = S[pid]; if not t then return end

    if _G.PlayerMenu_SaveModule and PlayerMenu_SaveModule.Hide then
      pcall(PlayerMenu_SaveModule.Hide, pid)
    end
    if _G.PlayerMenu_StatsModule and PlayerMenu_StatsModule.Hide then
      pcall(PlayerMenu_StatsModule.Hide, pid)
    end
    if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.Hide then
      pcall(PlayerMenu_InventoryModule.Hide, pid)
    end

    t.activeId = nil
  end

  function PlayerMenu.ShowModule(pid, which)
    local t = ensure(pid)
    if t.activeId == which then return end
    hideAll(pid)
    t.activeId = which

    if which == "save" then
      if _G.PlayerMenu_SaveModule and PlayerMenu_SaveModule.ShowInto then
        pcall(PlayerMenu_SaveModule.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Save/Load panel not available.")
      end

    elseif which == "stats" then
      if _G.PlayerMenu_StatsModule and PlayerMenu_StatsModule.ShowInto then
        pcall(PlayerMenu_StatsModule.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Stats panel not available.")
      end

    elseif which == "inventory" then
      if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.ShowInto then
        pcall(PlayerMenu_InventoryModule.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Inventory panel not available.")
      end
    end
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function PlayerMenu.Show(pid)
    local t = ensure(pid)
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetVisible(t.root, true)
    end
    t.open = true
  end

  function PlayerMenu.Hide(pid)
    local t = ensure(pid)
    hideAll(pid)
    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetVisible(t.root, false)
    end
    t.open = false
  end

  function PlayerMenu.Toggle(pid)
    local t = ensure(pid)
    if t.open then PlayerMenu.Hide(pid) else PlayerMenu.Show(pid) end
  end

  OnInit.final(function()
    if rawget(_G, "InitBroker") and InitBroker.SystemReady then
      InitBroker.SystemReady("PlayerMenu")
    end
  end)
end

if Debug and Debug.endFile then Debug.endFile() end
