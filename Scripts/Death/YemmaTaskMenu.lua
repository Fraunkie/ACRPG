if Debug and Debug.beginFile then Debug.beginFile("YemmaTaskMenu.lua") end
--==================================================
-- YemmaTaskMenu.lua
-- Task pick / active task panel (embedded-first).
-- Renders INSIDE a provided parent (content slot).
--==================================================

if not YemmaTaskMenu then YemmaTaskMenu = {} end
_G.YemmaTaskMenu = YemmaTaskMenu

do
    --------------------------------------------------
    -- Style
    --------------------------------------------------
    local BG_TEX       = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"
    local BTN_TEX      = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"
    local PAD          = 0.010
    local BTN_W, BTN_H = 0.16, 0.026
    local TITLE_SCALE  = 0.96
    local TEXT_SCALE   = 0.88

    -- Spacing (moved rows further down to avoid header/body overlap)
    local BODY_Y       = -0.050
    local PROG_Y       = -0.090
    local CHOICE_Y1    = -0.130
    local CHOICE_Y2    = -0.176

    --------------------------------------------------
    -- State (embedded instances per player)
    --------------------------------------------------
    -- EMBED[pid] = {
    --   parent, panel, header, body, prog,
    --   btnNew, btnTurn, rowAText, rowAButton, rowBText, rowBButton,
    --   _wired, _mode ("active"|"choices"|"idle")
    -- }
    local EMBED = {}

    --------------------------------------------------
    -- Small UI helpers (all created UNDER the given parent)
    --------------------------------------------------
    local function mkBackdrop(parent, w, h, tex, a)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex or BG_TEX, 0, true)
        if a then BlzFrameSetAlpha(f, a) end
        return f
    end
    local function mkText(parent, txt, scale, alignL, alignV)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetScale(t, scale or TEXT_SCALE)
        BlzFrameSetTextAlignment(t, alignL or TEXT_JUSTIFY_LEFT, alignV or TEXT_JUSTIFY_TOP)
        BlzFrameSetText(t, txt or "")
        return t
    end
    local function mkButton(parent, w, h, label)
        local b = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(b, w, h)
        local plate = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
        BlzFrameSetAllPoints(plate, b)
        BlzFrameSetTexture(plate, BTN_TEX, 0, true)
        local txt = BlzCreateFrameByType("TEXT", "", b, "", 0)
        BlzFrameSetPoint(txt, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(txt, TEXT_SCALE)
        BlzFrameSetText(txt, label or "")
        BlzFrameSetLevel(b, 5)
        return b
    end

    --------------------------------------------------
    -- Data helpers
    --------------------------------------------------
    local function curTask(pid)
        if _G.HFILQuests and HFILQuests.GetCurrent then
            return HFILQuests.GetCurrent(pid)
        end
        return nil
    end

    --------------------------------------------------
    -- Embed lifecycle
    --------------------------------------------------
    local function destroyEmbed(pid)
        local inst = EMBED[pid]
        if not inst then return end
        local fields = {
            "panel","header","body","prog",
            "btnNew","btnTurn",
            "rowAText","rowAButton","rowBText","rowBButton"
        }
        for i=1,#fields do
            local f = inst[fields[i]]
            if f then BlzDestroyFrame(f) end
        end
        EMBED[pid] = nil
    end

    local function ensureEmbed(pid, parent)
        local inst = EMBED[pid]
        if inst and inst.parent == parent then return inst end
        destroyEmbed(pid)

        -- Content panel under the provided parent (single layer holder)
        local panel = mkBackdrop(parent, 0.001, 0.001, BG_TEX, 200)
        BlzFrameSetPoint(panel, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, PAD, -PAD)
        BlzFrameSetPoint(panel, FRAMEPOINT_BOTTOMRIGHT, parent, FRAMEPOINT_BOTTOMRIGHT, -PAD, PAD)

        -- Static text placeholders (reused)
        local header = mkText(panel, "", TITLE_SCALE, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, PAD, -PAD)

        local body = mkText(panel, "", TEXT_SCALE)
        BlzFrameSetPoint(body, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, PAD, BODY_Y)

        local prog = mkText(panel, "", TEXT_SCALE)
        BlzFrameSetPoint(prog, FRAMEPOINT_TOPLEFT, panel, FRAMEPOINT_TOPLEFT, PAD, PROG_Y)

        -- Bottom action buttons parented to the PANEL
        local btnNew  = mkButton(panel, BTN_W, BTN_H, "Get Task")
        BlzFrameSetPoint(btnNew,  FRAMEPOINT_BOTTOMLEFT,  panel, FRAMEPOINT_BOTTOMLEFT,  PAD,  PAD)

        local btnTurn = mkButton(panel, BTN_W, BTN_H, "Turn In")
        BlzFrameSetPoint(btnTurn, FRAMEPOINT_BOTTOMRIGHT, panel, FRAMEPOINT_BOTTOMRIGHT, -PAD,  PAD)

        EMBED[pid] = {
            parent = parent,
            panel  = panel,
            header = header,
            body   = body,
            prog   = prog,
            btnNew = btnNew,
            btnTurn= btnTurn,
            _mode  = "idle",
        }
        return EMBED[pid]
    end

    --------------------------------------------------
    -- Row helpers
    --------------------------------------------------
    local function clearChoiceRows(pid)
        local inst = EMBED[pid]; if not inst then return end
        if inst.rowAText   then BlzDestroyFrame(inst.rowAText)   end
        if inst.rowAButton then BlzDestroyFrame(inst.rowAButton) end
        if inst.rowBText   then BlzDestroyFrame(inst.rowBText)   end
        if inst.rowBButton then BlzDestroyFrame(inst.rowBButton) end
        inst.rowAText, inst.rowAButton, inst.rowBText, inst.rowBButton = nil,nil,nil,nil
    end

    local function setHeader(inst, title, tag)
        BlzFrameSetText(inst.header, (title or "Task") .. (tag and (" ("..tag..")") or ""))
    end
    local function setBody(inst, txt)  BlzFrameSetText(inst.body, txt or "") end
    local function setProg(inst, p, g) BlzFrameSetText(inst.prog, "Progress: " .. tostring(p or 0) .. " / " .. tostring(g or 0)) end

    local function showActive(pid, task)
        local inst = EMBED[pid]; if not inst then return end
        clearChoiceRows(pid)
        setHeader(inst, task.title or task.id, task.typeTag or "common")

        local desc = "Task is active. Complete the objective shown below."
        if task.data and task.data.kind then
            if task.data.kind == "kill" then
                desc = "Defeat the required enemies."
            elseif task.data.kind == "collect" then
                desc = "Collect the required items."
            elseif task.data.kind == "escort" then
                desc = "Escort the target safely."
            end
        end
        setBody(inst, desc)
        setProg(inst, task.progress, task.goal)

        -- Bottom buttons: hide New, show TurnIn
        BlzFrameSetEnable(inst.btnNew, false)
        BlzFrameSetVisible(inst.btnNew, false)
        BlzFrameSetVisible(inst.btnTurn, true)
        inst._mode = "active"
    end

    local function renderChoices(pid)
        local inst = EMBED[pid]; if not inst then return end
        clearChoiceRows(pid)

        local A, B = nil, nil
        if _G.HFILQuests and HFILQuests.ProposeTwo then
            A, B = HFILQuests.ProposeTwo(pid)
        end

        if not A and not B then
            setHeader(inst, "No Tasks", nil)
            setBody(inst, "No tasks are currently available. Try again later.")
            setProg(inst, 0, 0)
            BlzFrameSetVisible(inst.btnNew, true)
            BlzFrameSetEnable(inst.btnNew, true)
            BlzFrameSetVisible(inst.btnTurn, false)
            inst._mode = "idle"
            return
        end

        setHeader(inst, "Choose a Task", nil)
        setBody(inst, "Pick one of the two available tasks below.")
        setProg(inst, 0, 0)

        local function row(y, choice)
            if not choice then return nil,nil end
            local label = (choice.title or choice.id or "Task") .. " (" .. (choice.typeTag or "common") .. ")"
            local t = mkText(inst.panel, label, TEXT_SCALE, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
            BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT, inst.panel, FRAMEPOINT_TOPLEFT, PAD, y)
            local b = mkButton(inst.panel, 0.12, 0.024, "Choose")
            BlzFrameSetPoint(b, FRAMEPOINT_TOPRIGHT, inst.panel, FRAMEPOINT_TOPRIGHT, -PAD, y - 0.002)
            local trig = CreateTrigger()
            BlzTriggerRegisterFrameEvent(trig, b, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(trig, function()
                local committed = _G.HFILQuests and HFILQuests.CommitChosen and HFILQuests.CommitChosen(pid, choice) or nil
                if committed then
                    showActive(pid, committed)
                    DisplayTextToPlayer(Player(pid), 0, 0, "Task accepted")
                else
                    DisplayTextToPlayer(Player(pid), 0, 0, "Failed to accept task")
                end
            end)
            return t, b
        end

        -- moved down
        EMBED[pid].rowAText, EMBED[pid].rowAButton = row(CHOICE_Y1, A)
        EMBED[pid].rowBText, EMBED[pid].rowBButton = row(CHOICE_Y2, B)

        -- Disable Get Task until a selection is made
        BlzFrameSetEnable(inst.btnNew, false)
        BlzFrameSetVisible(inst.btnNew, false)
        BlzFrameSetVisible(inst.btnTurn, false)
        inst._mode = "choices"
    end

    --------------------------------------------------
    -- Public API: Render/Refresh inside a parent
    --------------------------------------------------
    function YemmaTaskMenu.RenderIn(pid, parent)
        local inst = ensureEmbed(pid, parent)

        if not inst._wired then
            local tNew = CreateTrigger()
            BlzTriggerRegisterFrameEvent(tNew, inst.btnNew, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(tNew, function()
                renderChoices(pid)
            end)

            local tIn = CreateTrigger()
            BlzTriggerRegisterFrameEvent(tIn, inst.btnTurn, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(tIn, function()
                local t = curTask(pid)
                if not t then
                    DisplayTextToPlayer(Player(pid), 0, 0, "No active task")
                    return
                end
                if _G.HFILQuests and HFILQuests.CanTurnIn and HFILQuests.TurnInAtYemma then
                    if HFILQuests.CanTurnIn(pid) then
                        if HFILQuests.TurnInAtYemma(pid) then
                            BlzFrameSetText(inst.header, "Task Complete")
                            BlzFrameSetText(inst.body,   "Rewards granted.")
                            setProg(inst, 0, 0)
                            BlzFrameSetVisible(inst.btnTurn, false)
                            BlzFrameSetVisible(inst.btnNew,  true)
                            BlzFrameSetEnable(inst.btnNew,   true)
                            clearChoiceRows(pid)
                            inst._mode = "idle"
                        end
                    else
                        DisplayTextToPlayer(Player(pid), 0, 0, "Task is not complete")
                    end
                end
            end)

            inst._wired = true
        end

        local cur = curTask(pid)
        if cur then
            showActive(pid, cur)
        else
            BlzFrameSetText(inst.header, "HFIL Tasks")
            BlzFrameSetText(inst.body,   "Press Get Task to receive two choices.")
            setProg(inst, 0, 0)
            BlzFrameSetVisible(inst.btnNew,  true)
            BlzFrameSetEnable(inst.btnNew,   true)
            BlzFrameSetVisible(inst.btnTurn, false)
            clearChoiceRows(pid)
            inst._mode = "idle"
        end
    end

    function YemmaTaskMenu.Refresh(pid)
        local inst = EMBED[pid]; if not inst then return end
        local cur = curTask(pid)
        if cur then
            showActive(pid, cur)
        else
            BlzFrameSetText(inst.header, "HFIL Tasks")
            BlzFrameSetText(inst.body,   "Press Get Task to receive two choices.")
            setProg(inst, 0, 0)
            BlzFrameSetVisible(inst.btnNew,  true)
            BlzFrameSetEnable(inst.btnNew,   true)
            BlzFrameSetVisible(inst.btnTurn, false)
            clearChoiceRows(pid)
            inst._mode = "idle"
        end
    end

    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("YemmaTaskMenu")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
