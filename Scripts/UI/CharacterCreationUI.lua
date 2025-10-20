if Debug and Debug.beginFile then Debug.beginFile("CharacterCreationUI.lua") end
--==================================================
-- CharacterCreationUI.lua
-- • Main menu: Create (New Soul) + Load (opens slot picker)
-- • Slot picker: 6 slots, each with LOAD and SAVE buttons
-- • Local-only visibility, safe reuse if already created
--==================================================

if not CharacterCreation_UI then CharacterCreation_UI = {} end
_G.CharacterCreation_UI = CharacterCreation_UI

do
    --------------------------------------------------
    -- Textures (match your TeleportShop look)
    --------------------------------------------------
    local BTN_TEX = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local BG_TEX  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"

    --------------------------------------------------
    -- Per-player UI state
    --------------------------------------------------
    local rootMain   = {}  -- main menu frame per pid
    local rootSlots  = {}  -- slot menu frame per pid
    local trigCreate = {}
    local trigOpen   = {}
    local trigClose  = {}
    local trigSlot   = {}  -- trigSlot[pid] = { load = {t1..t6}, save = {t1..t6}, back = t }

    local SLOT_COUNT = 6

    local function isLocal(pid) return GetLocalPlayer() == Player(pid) end

    local function setVisible(frame, vis, pid)
        if not frame then return end
        if isLocal(pid) then BlzFrameSetVisible(frame, vis) end
    end

    local function hideAll(pid)
        setVisible(rootMain[pid], false, pid)
        setVisible(rootSlots[pid], false, pid)
    end

    --------------------------------------------------
    -- BUILD: Main Menu (Create + Load)
    --------------------------------------------------
    local function ensureMain(pid)
        if rootMain[pid] then return rootMain[pid] end

        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root = BlzCreateFrameByType("BACKDROP", "AC_CreateMenuRoot", ui, "", 0)
        BlzFrameSetSize(root, 0.30, 0.20)
        BlzFrameSetPoint(root, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0.00, 0.00)
        BlzFrameSetTexture(root, BG_TEX, 0, true)
        BlzFrameSetEnable(root, false)
        rootMain[pid] = root

        -- Title
        local title = BlzCreateFrameByType("TEXT", "AC_CreateTitle", root, "", 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0.00, -0.015)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(title, "Soul Menu")

        -- Create Button
        local btnCreate = BlzCreateFrameByType("GLUETEXTBUTTON", "AC_BtnCreate", root, "ScriptDialogButton", 0)
        BlzFrameSetSize(btnCreate, 0.24, 0.06)
        BlzFrameSetPoint(btnCreate, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0.00, 0.03)
        local bgCreate = BlzCreateFrameByType("BACKDROP", "", btnCreate, "", 0)
        BlzFrameSetAllPoints(bgCreate, btnCreate)
        BlzFrameSetTexture(bgCreate, BTN_TEX, 0, true)
        local txtCreate = BlzCreateFrameByType("TEXT", "", btnCreate, "", 0)
        BlzFrameSetPoint(txtCreate, FRAMEPOINT_CENTER, btnCreate, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(txtCreate, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtCreate, "Create New Soul")

        -- Load Button (opens slot picker)
        local btnOpen = BlzCreateFrameByType("GLUETEXTBUTTON", "AC_BtnOpenLoad", root, "ScriptDialogButton", 0)
        BlzFrameSetSize(btnOpen, 0.24, 0.06)
        BlzFrameSetPoint(btnOpen, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0.00, -0.04)
        local bgOpen = BlzCreateFrameByType("BACKDROP", "", btnOpen, "", 0)
        BlzFrameSetAllPoints(bgOpen, btnOpen)
        BlzFrameSetTexture(bgOpen, BTN_TEX, 0, true)
        local txtOpen = BlzCreateFrameByType("TEXT", "", btnOpen, "", 0)
        BlzFrameSetPoint(txtOpen, FRAMEPOINT_CENTER, btnOpen, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(txtOpen, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtOpen, "Load / Save Slots")

        -- Triggers
        trigCreate[pid] = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigCreate[pid], btnCreate, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigCreate[pid], function()
            hideAll(pid)
            if CharacterCreation and CharacterCreation.Begin then
                pcall(CharacterCreation.Begin, pid)
            end
        end)

        trigOpen[pid] = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigOpen[pid], btnOpen, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigOpen[pid], function()
            setVisible(rootMain[pid], false, pid)
            local sroot = ensureSlots(pid)
            setVisible(sroot, true, pid)
        end)

        return root
    end

    --------------------------------------------------
    -- BUILD: Slot Menu (6 slots with Load/Save)
    --------------------------------------------------
    function ensureSlots(pid)
        if rootSlots[pid] then return rootSlots[pid] end

        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root = BlzCreateFrameByType("BACKDROP", "AC_SlotMenuRoot", ui, "", 0)
        BlzFrameSetSize(root, 0.36, 0.32)
        BlzFrameSetPoint(root, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0.00, 0.00)
        BlzFrameSetTexture(root, BG_TEX, 0, true)
        BlzFrameSetEnable(root, false)
        rootSlots[pid] = root

        local title = BlzCreateFrameByType("TEXT", "AC_SlotTitle", root, "", 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, root, FRAMEPOINT_TOP, 0.00, -0.015)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(title, "Slots")

        trigSlot[pid] = { load = {}, save = {}, back = nil }

        -- Grid layout: 3 rows x 2 cols
        local startY = -0.06
        local rowH   = 0.08
        local colX   = { -0.12, 0.12 }

        local idx = 1
        for r = 1, 3 do
            for c = 1, 2 do
                if idx <= SLOT_COUNT then
                    local rowY = startY - (r - 1) * rowH
                    local col  = colX[c]

                    -- Label
                    local lbl = BlzCreateFrameByType("TEXT", "AC_SlotLabel_"..idx, root, "", 0)
                    BlzFrameSetPoint(lbl, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, col, rowY + 0.028)
                    BlzFrameSetTextAlignment(lbl, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
                    BlzFrameSetText(lbl, "Slot " .. tostring(idx))

                    -- LOAD button
                    local btnL = BlzCreateFrameByType("GLUETEXTBUTTON", "AC_SlotLoad_"..idx, root, "ScriptDialogButton", 0)
                    BlzFrameSetSize(btnL, 0.10, 0.036)
                    BlzFrameSetPoint(btnL, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, col - 0.05, rowY - 0.002)
                    local bgL = BlzCreateFrameByType("BACKDROP", "", btnL, "", 0)
                    BlzFrameSetAllPoints(bgL, btnL)
                    BlzFrameSetTexture(bgL, BTN_TEX, 0, true)
                    local txtL = BlzCreateFrameByType("TEXT", "", btnL, "", 0)
                    BlzFrameSetPoint(txtL, FRAMEPOINT_CENTER, btnL, FRAMEPOINT_CENTER, 0, 0)
                    BlzFrameSetTextAlignment(txtL, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
                    BlzFrameSetText(txtL, "Load")

                    -- SAVE button
                    local btnS = BlzCreateFrameByType("GLUETEXTBUTTON", "AC_SlotSave_"..idx, root, "ScriptDialogButton", 0)
                    BlzFrameSetSize(btnS, 0.10, 0.036)
                    BlzFrameSetPoint(btnS, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, col + 0.05, rowY - 0.002)
                    local bgS = BlzCreateFrameByType("BACKDROP", "", btnS, "", 0)
                    BlzFrameSetAllPoints(bgS, btnS)
                    BlzFrameSetTexture(bgS, BTN_TEX, 0, true)
                    local txtS = BlzCreateFrameByType("TEXT", "", btnS, "", 0)
                    BlzFrameSetPoint(txtS, FRAMEPOINT_CENTER, btnS, FRAMEPOINT_CENTER, 0, 0)
                    BlzFrameSetTextAlignment(txtS, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
                    BlzFrameSetText(txtS, "Save")

                    -- Trigger: LOAD
                    local tL = CreateTrigger()
                    BlzTriggerRegisterFrameEvent(tL, btnL, FRAMEEVENT_CONTROL_CLICK)
                    TriggerAddAction(tL, (function(slotIndex)
                        return function()
                            hideAll(pid)
                            if CharacterCreation_Adapter and CharacterCreation_Adapter.LoadSoul then
                                pcall(CharacterCreation_Adapter.LoadSoul, pid, slotIndex)
                            end
                        end
                    end)(idx))
                    trigSlot[pid].load[idx] = tL

                    -- Trigger: SAVE
                    local tS = CreateTrigger()
                    BlzTriggerRegisterFrameEvent(tS, btnS, FRAMEEVENT_CONTROL_CLICK)
                    TriggerAddAction(tS, (function(slotIndex)
                        return function()
                            if CharacterCreation_Adapter and CharacterCreation_Adapter.SaveSoul then
                                pcall(CharacterCreation_Adapter.SaveSoul, pid, slotIndex)
                            end
                        end
                    end)(idx))
                    trigSlot[pid].save[idx] = tS

                    idx = idx + 1
                end
            end
        end

        -- Back button
        local btnBack = BlzCreateFrameByType("GLUETEXTBUTTON", "AC_SlotBack", root, "ScriptDialogButton", 0)
        BlzFrameSetSize(btnBack, 0.14, 0.04)
        BlzFrameSetPoint(btnBack, FRAMEPOINT_BOTTOM, root, FRAMEPOINT_BOTTOM, 0.00, 0.012)
        local bgB = BlzCreateFrameByType("BACKDROP", "", btnBack, "", 0)
        BlzFrameSetAllPoints(bgB, btnBack)
        BlzFrameSetTexture(bgB, BTN_TEX, 0, true)
        local txtB = BlzCreateFrameByType("TEXT", "", btnBack, "", 0)
        BlzFrameSetPoint(txtB, FRAMEPOINT_CENTER, btnBack, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(txtB, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(txtB, "Back")

        trigClose[pid] = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trigClose[pid], btnBack, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trigClose[pid], function()
            setVisible(rootSlots[pid], false, pid)
            setVisible(rootMain[pid], true, pid)
        end)

        return root
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CharacterCreation_UI.ShowMenu(pid)
        local m = ensureMain(pid)
        hideAll(pid)
        setVisible(m, true, pid)
    end

    function CharacterCreation_UI.HideAll(pid)
        hideAll(pid)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CharacterCreation_UI")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
