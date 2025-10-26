if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu.lua") end
--==================================================
-- PlayerMenu.lua (MAIN)
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
  -- Companion gate (license check) — STRICT: InventoryService only
  --------------------------------------------------
  local ITEM_COMPANION_LICENSE = "I00H"

  local function HasCompanionLicense(pid)
    if DevMode then return true end

    local svc = rawget(_G, "InventoryService")
    if svc and svc.List and FourCC then
      local want = FourCC(ITEM_COMPANION_LICENSE)
      if want and want ~= 0 then
        local list = svc.List(pid)
        if type(list) == "table" then
          for _, typeId in pairs(list) do
            if type(typeId) == "number" and typeId == want then
              if Debug and Debug.printf then Debug.printf("[PM] License OK via InventoryService") end
              return true
            end
          end
        end
      end
    end

    if Debug and Debug.printf then Debug.printf("[PM] License MISSING") end
    return false
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
  local S = {} -- S[pid] = {root, rail, content, open, activeId, btnCompanions, railNextY}
  local parent

  local function ensure(pid)
    local t = S[pid]; if t then return t end
    t = { open = false, activeId = nil, btnCompanions = nil, railNextY = 0.0 }
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
    y = y + BTN_H + BTN_GAP

    -- Remember next y for optional late-added buttons (Companions)
    t.railNextY = y

    -- NOTE: Do NOT create the Companions button here; we defer to Show() after a fresh license check.
    return t
  end

  -- Create / toggle the Companions button each time the menu opens
  local function refreshCompanionsButton(pid, t)
    local shouldShow = HasCompanionLicense(pid)

    -- Already created? Toggle visibility + enable state.
    if t.btnCompanions then
      if GetLocalPlayer() == Player(pid) then
        BlzFrameSetVisible(t.btnCompanions, shouldShow)
        BlzFrameSetEnable(t.btnCompanions, shouldShow)
      end
      return
    end

    -- Not created yet, and allowed now -> create it
    if shouldShow then
      local rail = t.rail
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
          PlayerMenu.ShowModule(pid, "companions")
          UIUtil.BounceFrame(b, pid)
        end)
        return b
      end

      t.btnCompanions = makeButton(t.railNextY, "Companions", function()
        PlayerMenu.ShowModule(pid, "companions")
      end)
      t.railNextY = t.railNextY + BTN_H + BTN_GAP
    end
  end

  --------------------------------------------------
  -- Module plumbing
  --------------------------------------------------
  local function hideAll(pid)
    local t = S[pid]; if not t then return end

    local saveMod = rawget(_G, "PlayerMenu_SaveModule")
    if saveMod and saveMod.Hide then pcall(saveMod.Hide, pid) end

    local statsMod = rawget(_G, "PlayerMenu_StatsModule")
    if statsMod and statsMod.Hide then pcall(statsMod.Hide, pid) end

    local invMod = rawget(_G, "PlayerMenu_InventoryModule")
    if invMod and invMod.Hide then pcall(invMod.Hide, pid) end

    local compMod = rawget(_G, "PlayerMenu_CompanionsModule")
    if compMod and compMod.Hide then pcall(compMod.Hide, pid) end

    t.activeId = nil
  end

  function PlayerMenu.ShowModule(pid, which)
    local t = ensure(pid)
    if t.activeId == which then return end
    hideAll(pid)
    t.activeId = which

    if which == "save" then
      local saveMod = rawget(_G, "PlayerMenu_SaveModule")
      if saveMod and saveMod.ShowInto then
        pcall(saveMod.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Save Load panel not available.")
      end

    elseif which == "stats" then
      local statsMod = rawget(_G, "PlayerMenu_StatsModule")
      if statsMod and statsMod.ShowInto then
        pcall(statsMod.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Stats panel not available.")
      end

    elseif which == "inventory" then
      local invMod = rawget(_G, "PlayerMenu_InventoryModule")
      if invMod and invMod.ShowInto then
        pcall(invMod.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Inventory panel not available.")
      end

    elseif which == "companions" then
      -- If license was lost mid-session, deny cleanly.
      if not HasCompanionLicense(pid) and not DevMode then
        DisplayTextToPlayer(Player(pid), 0, 0, "Requires Companion License.")
        return
      end
      local compMod = rawget(_G, "PlayerMenu_CompanionsModule")
      if compMod and compMod.ShowInto then
        pcall(compMod.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Companions panel not available.")
      end
    end
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function PlayerMenu.Show(pid)
    local t = ensure(pid)
    -- Decide Companions button *now* based on current license
    refreshCompanionsButton(pid, t)

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
