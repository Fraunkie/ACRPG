if Debug and Debug.beginFile then Debug.beginFile("SlotPicker.lua") end

do
  SlotPicker = SlotPicker or {}
  _G.SlotPicker = SlotPicker

  local BTN_W   = 0.020
  local BTN_H   = 0.020
  local BTN_GAP = 0.006
  local PAD_X   = 0.008
  local PAD_Y   = 0.000
  local TEX_BTN = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller.blp"

  local ST = {}   -- ST[pid] = { root, btns[1..9], onPick }

  local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

  local function getHero(pid)
    if _G.PlayerData and PlayerData[pid] and validUnit(PlayerData[pid].hero) then
      return PlayerData[pid].hero
    end
    if _G.PlayerHero and validUnit(PlayerHero[pid]) then
      return PlayerHero[pid]
    end
    return nil
  end

  local function ensureLoadout(pid)
    _G.PlayerData = _G.PlayerData or {}
    _G.PlayerData[pid] = _G.PlayerData[pid] or {}
    _G.PlayerData[pid].loadout = _G.PlayerData[pid].loadout or {}
    return _G.PlayerData[pid].loadout
  end

  local function destroy(pid)
    local st = ST[pid]; if not st then return end
    if st.btns then
      for i=1,#st.btns do
        if st.btns[i] then BlzFrameSetVisible(st.btns[i], false) end
      end
    end
    if st.root then BlzFrameSetVisible(st.root, false) end
    ST[pid] = nil
  end

  function SlotPicker.Show(pid, parentFrame, anchorFrame, onPick)
    destroy(pid)

    if not parentFrame or not anchorFrame then
      DisplayTextToPlayer(Player(pid), 0, 0, "[SlotPicker] Missing parent or anchor")
      return
    end

    local root = BlzCreateFrameByType("FRAME", "SP_Row"..tostring(pid), parentFrame, "", 0)
    BlzFrameSetLevel(root, 60)
    local totalW = 9*BTN_W + 8*BTN_GAP
    BlzFrameSetSize(root, totalW, BTN_H)
    BlzFrameSetPoint(root, FRAMEPOINT_LEFT, anchorFrame, FRAMEPOINT_RIGHT, PAD_X, PAD_Y)

    local st = { root = root, btns = {}, onPick = onPick }
    ST[pid] = st

    local labels = { "Q","E","R","T","Z","X","C","V","G" }

    for i=1,9 do
      local b = BlzCreateFrameByType("BUTTON", "SP_Btn"..tostring(i), root, "", 0)
      BlzFrameSetSize(b, BTN_W, BTN_H)
      local x = (i-1) * (BTN_W + BTN_GAP)
      BlzFrameSetPoint(b, FRAMEPOINT_LEFT, root, FRAMEPOINT_LEFT, x, 0.0)

      local bg = BlzCreateFrameByType("BACKDROP","", b, "", 0)
      BlzFrameSetAllPoints(bg, b)
      BlzFrameSetTexture(bg, TEX_BTN, 0, true)

      local t = BlzCreateFrameByType("TEXT","", b, "", 0)
      BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
      BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
      BlzFrameSetText(t, labels[i])

      local trig = CreateTrigger()
      BlzTriggerRegisterFrameEvent(trig, b, FRAMEEVENT_CONTROL_CLICK)
      local idxCap = i
      TriggerAddAction(trig, function()
        local ok = true
        if type(st.onPick) == "function" then
          local status = pcall(st.onPick, idxCap)
          ok = status and true or false
          if not status then
            DisplayTextToPlayer(Player(pid), 0, 0, "[SlotPicker] onPick error")
          end
        end
        SlotPicker.Hide(pid)
      end)

      st.btns[i] = b
    end

    if GetLocalPlayer() == Player(pid) then
      BlzFrameSetVisible(root, true)
    end
  end

  function SlotPicker.Hide(pid)
    destroy(pid)
  end

  -- Convenience: assign direct and refresh

  function SlotPicker.ClearLoadout(pid)
    local loadout = ensureLoadout(pid)
    for i = 1, 9 do
        loadout[i] = nil  -- Clear each slot
    end
    if CustomSpellBar.Refresh then
        CustomSpellBar.Refresh(pid)  -- Refresh the spell bar UI
    end
  end

  function SlotPicker.AssignSlot(pid, slotIdx, abilString)  -- Use abilString instead of abilRaw
    local u = getHero(pid)
    if not validUnit(u) then
      DisplayTextToPlayer(Player(pid), 0, 0, "[SlotPicker] No hero assigned")
      return
    end

    local loadout = ensureLoadout(pid)
    loadout[slotIdx] = abilString  -- Store the ability string (not raw ID)

    if _G.CustomSpellBar and CustomSpellBar.SetSlot then
      CustomSpellBar.SetSlot(pid, slotIdx, abilString)  -- Pass ability string to CustomSpellBar
      if CustomSpellBar.Refresh then CustomSpellBar.Refresh(pid) end
    end

    local name = GetAbilityName(abilString) or tostring(abilString)
    DisplayTextToPlayer(Player(pid), 0, 0, "Assigned "..name.." to slot "..tostring(slotIdx))
  end
end

if Debug and Debug.endFile then Debug.endFile() end
