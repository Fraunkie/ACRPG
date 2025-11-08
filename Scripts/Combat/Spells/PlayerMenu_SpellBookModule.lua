if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_SpellbookModule.lua") end
--==================================================
-- PlayerMenu_SpellbookModule.lua (v3.3b)
-- Mirrors Inventory module lifecycle EXACTLY.
-- • ShowInto/Hide; build once per open; tiles rebuilt on tab/toggle
-- • Uses PlayerMenu contentFrame as root; does NOT destroy contentFrame
-- • No percent symbols anywhere
--==================================================

do
  PlayerMenu_SpellbookModule = PlayerMenu_SpellbookModule or {}
  _G.PlayerMenu_SpellbookModule = PlayerMenu_SpellbookModule

  local TEX_PANEL_DARK = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp"
  local TEX_PANEL_ALT  = "UI\\Widgets\\EscMenu\\NightElf\\nightelf-options-menu-background.blp"
  local TEX_BTN        = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller.blp"
  local TEX_LOCK       = "ReplaceableTextures\\CommandButtons\\BTNHoldPosition.blp"
  local TEX_FALLBACK   = "ReplaceableTextures\\CommandButtons\\BTNInnerFire.blp"

  local PAD            = 0.012
  local TOP_W          = 0.160
  local TOP_H          = 0.028
  local TOP_GAP        = 0.010

  local GRID_COLS      = 3
  local GRID_ROWS      = 5
  local CELL_W         = 0.070
  local CELL_H         = 0.058
  local CELL_GAP_X     = 0.016
  local CELL_GAP_Y     = 0.014
  local ICON_W         = 0.036
  local ICON_H         = 0.036

  -- UI[pid] = { root, bg, tabSpells, tabTalents, toggleBtn, tSpells, tTalents, tToggle, showLocked, tiles={}, tipBox, tipText }
  local UI = {}

  local function four(v) return type(v)=="string" and FourCC(v) or v end
  local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

  local function heroOf(pid)
    if _G.PlayerData and PlayerData[pid] and validUnit(PlayerData[pid].hero) then return PlayerData[pid].hero end
    if _G.PlayerHero and validUnit(PlayerHero[pid]) then return PlayerHero[pid] end
    return nil
  end

  local function getUnlocksForUnit(unitTypeId)
    local GB = rawget(_G,"GameBalance")
    if not GB then return {} end
    local map = (GB.GetSpellUnlocksByUnit and GB.GetSpellUnlocksByUnit()) or GB.SPELL_UNLOCKS_BY_UNIT or {}
    return map[unitTypeId] or {}
  end

  local function isPassiveEntry(entry)
    if not entry then return false end
    if entry.passive == true then return true end
    if entry.type == "passive" then return true end
    if entry.kind == "passive" then return true end
    if entry.category == "passive" then return true end
    if entry.behavior == "passive" then return true end
    if entry.flags and type(entry.flags)=="table" then
      for _,f in ipairs(entry.flags) do if f == "passive" then return true end end
    end
    local GB = rawget(_G,"GameBalance")
    if GB and GB.IsPassiveAbility and entry.abil then
      local ok, res = pcall(GB.IsPassiveAbility, entry.abil)
      if ok and res then return true end
    end
    return false
  end

  local function meetsNeed(pid, need)
    need = need or {}
    if need.pl_min then
      local pl = 0
      if PlayerData and PlayerData[pid] and type(PlayerData[pid].powerLevel)=="number" then
        pl = PlayerData[pid].powerLevel
      end
      if pl < need.pl_min then return false end
    end
    if need.sl_min then
      local sl = 0
      if rawget(_G, "SoulEnergyLogic") and SoulEnergyLogic.GetLevel then
        local ok, lvl = pcall(SoulEnergyLogic.GetLevel, pid)
        if ok and type(lvl)=="number" then sl = lvl end
      end
      if sl == 0 and PlayerData and PlayerData[pid] and type(PlayerData[pid].soulLevel)=="number" then
        sl = PlayerData[pid].soulLevel
      end
      if sl < need.sl_min then return false end
    end
    return true
  end

  local function heroHasAbility(pid, abilStr)
    local u = heroOf(pid); if not validUnit(u) then return false end
    return GetUnitAbilityLevel(u, four(abilStr)) > 0
  end

  -- tooltip
  local uniq = 0
  local function tipHide(pid)
    local ui = UI[pid]; if not ui or not ui.tipBox then return end
    if GetLocalPlayer()==Player(pid) then BlzFrameSetVisible(ui.tipBox,false) end
  end
  local function tipShow(pid, anchor, text)
    local ui = UI[pid]; if not ui then return end
    if not ui.tipBox then
      ui.tipBox  = BlzCreateFrameByType("BACKDROP", "SB_TipBox_"..tostring(uniq), ui.root, "", 0)
      uniq = uniq + 1
      BlzFrameSetSize(ui.tipBox, 0.26, 0.12)
      BlzFrameSetTexture(ui.tipBox, TEX_PANEL_DARK, 0, true)
      BlzFrameSetAlpha(ui.tipBox, 230)
      BlzFrameSetLevel(ui.tipBox, 98)
      ui.tipText = BlzCreateFrameByType("TEXT", "", ui.tipBox, "", 0)
      BlzFrameSetPoint(ui.tipText, FRAMEPOINT_TOPLEFT,     ui.tipBox, FRAMEPOINT_TOPLEFT,     0.008, -0.008)
      BlzFrameSetPoint(ui.tipText, FRAMEPOINT_BOTTOMRIGHT, ui.tipBox, FRAMEPOINT_BOTTOMRIGHT, -0.008,  0.008)
      BlzFrameSetTextAlignment(ui.tipText, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
      if GetLocalPlayer()==Player(pid) then BlzFrameSetVisible(ui.tipBox,false) end
    end
    BlzFrameClearAllPoints(ui.tipBox)
    BlzFrameSetPoint(ui.tipBox, FRAMEPOINT_LEFT, anchor, FRAMEPOINT_RIGHT, 0.010, 0.0)
    BlzFrameSetText(ui.tipText, text or "")
    if GetLocalPlayer()==Player(pid) then BlzFrameSetVisible(ui.tipBox,true) end
  end

  local function setTilesVisible(pid, vis)
    local ui = UI[pid]; if not ui or not ui.tiles then return end
    if GetLocalPlayer()~=Player(pid) then return end
    for _,cell in ipairs(ui.tiles) do if cell.root then BlzFrameSetVisible(cell.root, vis) end end
  end
  local function clearTiles(pid)
    local ui = UI[pid]; if not ui or not ui.tiles then return end
    setTilesVisible(pid, false)
    ui.tiles = {}
  end

  local function rebuildSpells(pid)
    local ui = UI[pid]; if not ui then return end
    clearTiles(pid)
    BlzFrameSetTexture(ui.bg, TEX_PANEL_DARK, 0, true)

    local u = heroOf(pid); if not validUnit(u) then return end
    local list = getUnlocksForUnit(GetUnitTypeId(u))

    local startY = - (TOP_H + PAD + PAD)
    local idx = 0

    for r=1,GRID_ROWS do
      for c=1,GRID_COLS do
        idx = idx + 1
        local entry = list[idx]; if not entry then goto continue end

        local abilId  = four(entry.abil or 0)
        local passive = isPassiveEntry(entry)
        local hasAbil = heroHasAbility(pid, entry.abil)
        local reqOk   = meetsNeed(pid, entry.need)
        local usable  = (not passive) and (hasAbil or reqOk)

        if not UI[pid].showLocked then
          if passive then goto continue end
          if not usable then goto continue end
        end

        local cell = BlzCreateFrameByType("BACKDROP","SB_Cell", ui.root, "", 0)
        BlzFrameSetSize(cell, CELL_W, CELL_H)
        BlzFrameSetPoint(
          cell, FRAMEPOINT_TOPLEFT, ui.root, FRAMEPOINT_TOPLEFT,
          PAD + (c-1)*(CELL_W + CELL_GAP_X),
          startY - (r-1)*(CELL_H + CELL_GAP_Y)
        )
        BlzFrameSetTexture(cell, TEX_PANEL_DARK, 0, true)
        BlzFrameSetLevel(cell, 42)

        local iconBtn = BlzCreateFrameByType("BUTTON","", cell, "", 0)
        BlzFrameSetSize(iconBtn, ICON_W, ICON_H)
        BlzFrameSetPoint(iconBtn, FRAMEPOINT_TOPLEFT, cell, FRAMEPOINT_TOPLEFT, 0.006, -0.006)
        BlzFrameSetLevel(iconBtn, 43)

        local icon = BlzCreateFrameByType("BACKDROP","", iconBtn, "", 0)
        BlzFrameSetAllPoints(icon, iconBtn)
        local ipath = BlzGetAbilityIcon(abilId); if not ipath or ipath=="" then ipath = TEX_FALLBACK end
        BlzFrameSetTexture(icon, ipath, 0, true)

        local name = BlzCreateFrameByType("TEXT","", cell, "", 0)
        BlzFrameSetPoint(name, FRAMEPOINT_TOPLEFT, cell, FRAMEPOINT_TOPLEFT, 0.006, -0.006)
        BlzFrameSetTextAlignment(name, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        BlzFrameSetText(name, entry.name or "Ability")
        BlzFrameSetLevel(name, 44)

        local lbl = BlzCreateFrameByType("TEXT","", cell, "", 0)
        BlzFrameSetPoint(lbl, FRAMEPOINT_BOTTOMLEFT, cell, FRAMEPOINT_BOTTOMLEFT, 0.006, 0.006)
        BlzFrameSetTextAlignment(lbl, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_BOTTOM)
        if passive then BlzFrameSetText(lbl, "Passive") else BlzFrameSetText(lbl, usable and "Active" or "Active (locked)") end
        BlzFrameSetLevel(lbl, 44)

        local lock = BlzCreateFrameByType("BACKDROP","", cell, "", 0)
        BlzFrameSetPoint(lock, FRAMEPOINT_CENTER, cell, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetSize(lock, 0.020, 0.020)
        BlzFrameSetTexture(lock, TEX_LOCK, 0, true)
        BlzFrameSetVisible(lock, (not passive) and (not usable) and UI[pid].showLocked)

        -- Build the tooltip string dynamically for Spirit Vortex
        local parts = {}
        if entry.need then
          if entry.need.pl_min then parts[#parts+1] = "PL "..tostring(entry.need.pl_min) end
          if entry.need.sl_min then parts[#parts+1] = "Soul Lv "..tostring(entry.need.sl_min) end
        end

        -- Now check if it's the Spirit Vortex ability and add its description
        local tip = entry.name or "Ability"
        if #parts > 0 then
          tip = tip.."  ["..table.concat(parts, ", ").."]"
        end
        if passive then
          tip = tip.."\nPassive ability"
        end

        -- Add Spirit Vortex Description and dynamic damage
        if abilId == FourCC("A0SV") then
            local dmg = 40  -- Default damage
            if _G.Spell_SpiritVortex and Spell_SpiritVortex.GetDamage then
                local ok, val = pcall(Spell_SpiritVortex.GetDamage, pid)
                if ok and type(val) == "number" then
                    dmg = val
                end
            end
            tip = tip
            .."\n|cffddddddSummons six spirit orbs that orbit you.|r"
            .."\n|cffff9900Orbs:|r 6"
            .."\n|cffff6666Damage per orb:|r "..tostring(dmg)
        end

        -- Mouse-enter event to show the tooltip
        local tIn, tOut = CreateTrigger(), CreateTrigger()
        BlzTriggerRegisterFrameEvent(tIn,  iconBtn, FRAMEEVENT_MOUSE_ENTER)
        BlzTriggerRegisterFrameEvent(tOut, iconBtn, FRAMEEVENT_MOUSE_LEAVE)
        TriggerAddAction(tIn,  function() tipShow(pid, cell, tip) end)
        TriggerAddAction(tOut, function() tipHide(pid) end)

        -- Click action for the spell
        local trigClick = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigClick, iconBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigClick, function()
          if passive then
            DisplayTextToPlayer(Player(pid), 0, 0, "Passive ability — cannot assign to bar.")
            return
          end
          if not usable then
            DisplayTextToPlayer(Player(pid), 0, 0, "Ability is locked — meet requirements first.")
            return
          end

          -- Open the slot picker for assignment
          local parentForPicker = ui.root
          if parentForPicker and _G.SlotPicker and SlotPicker.Show then
            SlotPicker.Show(pid, parentForPicker, cell, function(slotIdx)
              if _G.SlotPicker and SlotPicker.AssignSlot then
                SlotPicker.AssignSlot(pid, slotIdx, abilId)
              elseif _G.CustomSpellBar and CustomSpellBar.SetSlot then
                CustomSpellBar.SetSlot(pid, slotIdx, abilId)
                if CustomSpellBar.Refresh then CustomSpellBar.Refresh(pid) end
              end
            end)
          else
            DisplayTextToPlayer(Player(pid), 0, 0, "[Spellbook] SlotPicker unavailable.")
          end
        end)

        UI[pid].tiles[#UI[pid].tiles+1] = { root = cell }
        ::continue::
      end
    end
  end


  local function ensureChrome(pid)
    local ui = UI[pid]; if not ui then return end
    if ui.bg then return end

    ui.bg = BlzCreateFrameByType("BACKDROP","SB_BG", ui.root, "", 0)
    BlzFrameSetAllPoints(ui.bg, ui.root)
    BlzFrameSetTexture(ui.bg, TEX_PANEL_DARK, 0, true)
    BlzFrameSetLevel(ui.bg, 40)

    local function makeTop(label, xOff)
      local b = BlzCreateFrameByType("BUTTON", "", ui.root, "", 0)
      BlzFrameSetSize(b, TOP_W, TOP_H)
      BlzFrameSetPoint(b, FRAMEPOINT_TOPLEFT, ui.root, FRAMEPOINT_TOPLEFT, PAD + xOff, -PAD)
      local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
      BlzFrameSetAllPoints(bg, b)
      BlzFrameSetTexture(bg, TEX_BTN, 0, true)
      local t = BlzCreateFrameByType("TEXT","", b, "", 0)
      BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
      BlzFrameSetText(t, label)
      return b, t
    end

    ui.tabSpells,  ui.tSpells  = makeTop("Spells", 0.0)
    ui.tabTalents, ui.tTalents = makeTop("Talents", TOP_W + TOP_GAP)
    ui.toggleBtn,  ui.tToggle  = makeTop("Show Locked: ON", (TOP_W + TOP_GAP) * 2)

    local trigS = CreateTrigger()
    BlzTriggerRegisterFrameEvent(trigS, ui.tabSpells, FRAMEEVENT_CONTROL_CLICK)
    TriggerAddAction(trigS, function()
      tipHide(pid)
      BlzFrameSetTexture(ui.bg, TEX_PANEL_DARK, 0, true)
      rebuildSpells(pid)
      setTilesVisible(pid, true)
    end)

    local trigT = CreateTrigger()
BlzTriggerRegisterFrameEvent(trigT, ui.tabTalents, FRAMEEVENT_CONTROL_CLICK)
TriggerAddAction(trigT, function()
   tipHide(pid)
   BlzFrameSetTexture(ui.bg, TEX_PANEL_ALT, 0, true)
   clearTiles(pid)  -- Clear any previous UI elements

   -- Get the hero unit for this player (pid)
   local heroUnit = heroOf(pid)
   if not validUnit(heroUnit) then return end

   -- Get the unit type ID (e.g., H001 for LostSoul)
   local unitTypeId = GetUnitTypeId(heroUnit)

   -- Get the talent tree(s) for the unit type
   local talentTrees = GameBalance.TALENT_TREES[unitTypeId]
   if not talentTrees then return end  -- If no talent trees are found, exit

   -- Create sub-tab buttons for each talent tree at the bottom
   local startX = PAD  -- Starting X position for the buttons
   local buttonWidth = 0.1
   local buttonHeight = 0.03
   local buttonGap = 0.015  -- Gap between buttons

   for idx, treeName in ipairs(talentTrees) do
       -- Create the button for each talent tree
       local button = BlzCreateFrameByType("BUTTON", "", UI[pid].root, "", 0)
       BlzFrameSetSize(button, buttonWidth, buttonHeight)
       BlzFrameSetPoint(button, FRAMEPOINT_BOTTOMLEFT, UI[pid].root, FRAMEPOINT_BOTTOMLEFT, startX + (buttonWidth + buttonGap) * (idx - 1), PAD)

       -- Set button label (name of the talent tree)
       local text = BlzCreateFrameByType("TEXT", "", button, "", 0)
       BlzFrameSetText(text, treeName)  -- Tree name will be the label

       -- Add action to switch to the selected talent tree when clicked
       local trigClick = CreateTrigger()
       BlzTriggerRegisterFrameEvent(trigClick, button, FRAMEEVENT_CONTROL_CLICK)
       TriggerAddAction(trigClick, function()
           -- Switch to the selected tree
           changeBackgroundForTree(pid, treeName)  -- Change background for the selected tree
           rebuildTalentsForTree(pid, treeName)    -- Rebuild talents for the selected tree
       end)

       -- Increment X position for the next button
       startX = startX + buttonWidth + buttonGap
   end
end)

    local trigToggle = CreateTrigger()
    BlzTriggerRegisterFrameEvent(trigToggle, ui.toggleBtn, FRAMEEVENT_CONTROL_CLICK)
    TriggerAddAction(trigToggle, function()
      UI[pid].showLocked = not UI[pid].showLocked
      BlzFrameSetText(UI[pid].tToggle, UI[pid].showLocked and "Show Locked: ON" or "Show Locked: OFF")
      rebuildSpells(pid)
      setTilesVisible(pid, true)
    end)
  end

  function PlayerMenu_SpellbookModule.ShowInto(pid, contentFrame)
    if UI[pid] then
      if GetLocalPlayer()==Player(pid) then BlzFrameSetVisible(UI[pid].root, true) end
      if UI[pid].tToggle then
        BlzFrameSetText(UI[pid].tToggle, UI[pid].showLocked and "Show Locked: ON" or "Show Locked: OFF")
      end
      rebuildSpells(pid)
      setTilesVisible(pid, true)
      return
    end

    UI[pid] = { root = contentFrame, showLocked = true, tiles = {} }
    local ui = UI[pid]
    if GetLocalPlayer()==Player(pid) then BlzFrameSetVisible(contentFrame, true) end
    BlzFrameSetTexture(contentFrame, TEX_PANEL_DARK, 0, true)
    BlzFrameSetEnable(contentFrame, false)

    ensureChrome(pid)
    BlzFrameSetText(ui.tToggle, "Show Locked: ON")
    rebuildSpells(pid)
    setTilesVisible(pid, true)
  end

  function PlayerMenu_SpellbookModule.Hide(pid)
    local ui = UI[pid]; if not ui then return end
    tipHide(pid)
    setTilesVisible(pid, false)
    if GetLocalPlayer()==Player(pid) then
      if ui.bg then BlzFrameSetVisible(ui.bg, false) end
      if ui.tabSpells then BlzFrameSetVisible(ui.tabSpells, false) end
      if ui.tabTalents then BlzFrameSetVisible(ui.tabTalents, false) end
      if ui.toggleBtn then BlzFrameSetVisible(ui.toggleBtn, false) end
      if ui.tipBox then BlzFrameSetVisible(ui.tipBox, false) end
      BlzFrameSetVisible(ui.root, false)
    end
    UI[pid] = nil
  end
end

if Debug and Debug.endFile then Debug.endFile() end
