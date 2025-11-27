if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu.lua") end
--==================================================
-- PlayerMenu.lua (MAIN)
-- Main menu with a left button rail and a right content pane.
-- • L toggles menu (KeyEventHandler calls PlayerMenu.Toggle(pid))
-- • Opening one module hides the others
-- • Fixed texture paths (.blp) to remove green backdrops
-- • Added: Spellbook button + Show/Hide plumbing
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
  -- Style (using FDF-based borders and backgrounds)
  --------------------------------------------------
  local TEX_BG_LIGHT   = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"  -- Background texture for main menu
  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"  -- Dark panel texture for content
  local TEX_BTN        = "ui\\Button.blp"  -- Button texture
  local TEX_BLANK      = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
  local TEX_STATS      = "ui\\StatsButton.blp"
  local TEX_INV        = "ui\\InventoryButton.blp"
  local TEX_LOAD       = "ui\\LoadandSaveButton.blp"
  local TEX_COMPS      = "ui\\CompanionsButton.blp"
  local TEX_SB         = "ui\\SpellbookButton.blp"

  -- Border Textures (replace these with your border textures)
  local TEX_BORDER_LEFT = "war3mapImported\\SideMenuBorder.blp"
  local TEX_BORDER_RIGHT = "war3mapImported\\SideMenuBorder.blp"
  local TEX_BORDER_TOP = "war3mapImported\\TopMenuBorder.blp"
  local TEX_BORDER_BOTTOM = "war3mapImported\\BottomMenuBorder.blp"

  local W_OUT, H_OUT   = 0.48, 0.42
  local RAIL_W         = 0.12
  local PAD            = 0.013
  local BTN_H          = 0.030
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

    -- root frame (outer light bg with border)
    local root = BlzCreateFrameByType("BACKDROP", "PM_Root", parent, "", 0)
    BlzFrameSetSize(root, W_OUT, H_OUT)
    BlzFrameSetPoint(root, FRAMEPOINT_CENTER, parent, FRAMEPOINT_CENTER, 0, 0)
    BlzFrameSetTexture(root, TEX_BG_LIGHT, 0, true)
    BlzFrameSetEnable(root, false)
    BlzFrameSetVisible(root, false)
    BlzFrameSetLevel(root, 4)
    t.root = root

    -- Set borders for root (apply imported textures)
    local borderTop = BlzCreateFrameByType("BACKDROP", "PM_TopBorder", root, "", 0)
    BlzFrameSetSize(borderTop, W_OUT, 0.02)  -- Thin top border
    BlzFrameSetPoint(borderTop, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0, 0)
    BlzFrameSetTexture(borderTop, TEX_BORDER_TOP, 0, true)
    BlzFrameSetLevel(borderTop, 5)

    local borderBottom = BlzCreateFrameByType("BACKDROP", "PM_BottomBorder", root, "", 0)
    BlzFrameSetSize(borderBottom, W_OUT, 0.02)  -- Thin bottom border
    BlzFrameSetPoint(borderBottom, FRAMEPOINT_BOTTOM, root, FRAMEPOINT_BOTTOM, 0, 0)
    BlzFrameSetTexture(borderBottom, TEX_BORDER_BOTTOM, 0, true)
    BlzFrameSetLevel(borderBottom, 5)

    local borderLeft = BlzCreateFrameByType("BACKDROP", "PM_LeftBorder", root, "", 0)
    BlzFrameSetSize(borderLeft, 0.02, H_OUT)  -- Thin left border
    BlzFrameSetPoint(borderLeft, FRAMEPOINT_LEFT, root, FRAMEPOINT_LEFT, 0, 0)
    BlzFrameSetTexture(borderLeft, TEX_BORDER_LEFT, 0, true)
    BlzFrameSetLevel(borderLeft, 5)

    local borderRight = BlzCreateFrameByType("BACKDROP", "PM_RightBorder", root, "", 0)
    BlzFrameSetSize(borderRight, 0.02, H_OUT)  -- Thin right border
    BlzFrameSetPoint(borderRight, FRAMEPOINT_RIGHT, root, FRAMEPOINT_RIGHT, 0, 0)
    BlzFrameSetTexture(borderRight, TEX_BORDER_RIGHT, 0, true)
    BlzFrameSetLevel(borderRight, 5)

    -- left rail
    local rail = BlzCreateFrameByType("BACKDROP", "PM_Rail", root, "", 0)
    BlzFrameSetSize(rail, RAIL_W, H_OUT - PAD * 2)
    BlzFrameSetPoint(rail, FRAMEPOINT_TOPLEFT, root, FRAMEPOINT_TOPLEFT, PAD, -PAD)
    BlzFrameSetTexture(rail, TEX_PANEL_DARK, 0, true)
    BlzFrameSetEnable(rail, false)
    BlzFrameSetLevel(rail, 6)
    t.rail = rail

    -- right content
    local content = BlzCreateFrameByType("BACKDROP", "PM_Content", root, "", 0)
    BlzFrameSetSize(content, W_OUT - RAIL_W - PAD * 3, H_OUT - PAD * 2)
    BlzFrameSetPoint(content, FRAMEPOINT_TOPLEFT, rail, FRAMEPOINT_TOPRIGHT, PAD, 0)
    BlzFrameSetTexture(content, TEX_BLANK, 0, true)
    BlzFrameSetEnable(content, false)
    BlzFrameSetLevel(content, 7)
    t.content = content

    -- titles
    local titleMenu = BlzCreateFrameByType("TEXT", "", root, "", 0)
    BlzFrameSetPoint(titleMenu, FRAMEPOINT_TOPLEFT, rail, FRAMEPOINT_TOPLEFT, 0.012, -0.012)
    BlzFrameSetTextAlignment(titleMenu, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)

    local titleInfo = BlzCreateFrameByType("TEXT", "", root, "", 0)
    BlzFrameSetPoint(titleInfo, FRAMEPOINT_TOPLEFT, content, FRAMEPOINT_TOPLEFT, 0.012, -0.012)
    BlzFrameSetTextAlignment(titleInfo, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)

    local function makeButton(yOff, label, onClick)
      local b = BlzCreateFrameByType("BUTTON", "", rail, "IconButtonTemplate", 0)
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

    -- Add specific buttons
    local y = 0.025 + BTN_H
    makeButton(y, "Load Save", function() PlayerMenu.ShowModule(pid, "save") end)
    y = y + BTN_H + BTN_GAP

    makeButton(y, "Character Stats", function() PlayerMenu.ShowModule(pid, "stats") end)
    y = y + BTN_H + BTN_GAP

    makeButton(y, "Inventory", function() PlayerMenu.ShowModule(pid, "inventory") end)
    y = y + BTN_H + BTN_GAP

    -- Spellbook button (NEW)
    makeButton(y, "Spellbook", function() PlayerMenu.ShowModule(pid, "spellbook") end)
    y = y + BTN_H + BTN_GAP

    -- Remember next y for optional late-added buttons (Companions)
    t.railNextY = y

    return t
  end

  -- Create / toggle the Companions button each time the menu opens
  local function refreshCompanionsButton(pid, t)
    local shouldShow = HasCompanionLicense(pid)

    if t.btnCompanions then
      if GetLocalPlayer() == Player(pid) then
        BlzFrameSetVisible(t.btnCompanions, shouldShow)
        BlzFrameSetEnable(t.btnCompanions, shouldShow)
      end
      return
    end

    if shouldShow then
      local rail = t.rail
      local function makeButton(yOff, label, onClick)
        local b = BlzCreateFrameByType("BUTTON", "", rail, "IconButtonTemplate", 0)
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

    -- NEW: Spellbook module hide
    local sbMod = rawget(_G, "PlayerMenu_SpellbookModule")
    if sbMod and sbMod.Hide then pcall(sbMod.Hide, pid) end

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

    elseif which == "spellbook" then
      local sbMod = rawget(_G, "PlayerMenu_SpellbookModule")
      if sbMod and sbMod.ShowInto then
        pcall(sbMod.ShowInto, pid, t.content)
      else
        DisplayTextToPlayer(Player(pid), 0, 0, "Spellbook panel not available.")
      end
    end
  end

  --------------------------------------------------
  -- Public API
  --------------------------------------------------
  function PlayerMenu.Show(pid)
    local t = ensure(pid)
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
