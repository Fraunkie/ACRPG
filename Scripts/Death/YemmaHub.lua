if Debug and Debug.beginFile then Debug.beginFile("YemmaHub.lua") end
--==================================================
-- YemmaHub.lua
-- Hub panel (nav @ left, content @ right).
-- Safe: panes are created once and toggled (no destroy).
-- Tasks page embeds YemmaTaskMenu into its pane.
--==================================================

if not YemmaHub then YemmaHub = {} end
_G.YemmaHub = YemmaHub

do
    --------------------------------------------------
    -- Config / style
    --------------------------------------------------
    local GB       = GameBalance or {}
    local BG_TEX   = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"
    local BTN_TEX  = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"

    local PANEL_W  = 0.46
    local PANEL_H  = 0.28
    local PAD      = 0.016
    local NAV_W    = 0.16
    local BTN_H    = 0.018
    local GAP      = 0.010

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root   = {}   -- pid -> root frame
    local slot   = {}   -- pid -> persistent content slot container (right side)
    local panes  = {}   -- pid -> { tasks=frame, travel=frame, services=frame, intro=frame }
    local wired  = {}   -- pid -> true when nav wired

    --------------------------------------------------
    -- UI helpers
    --------------------------------------------------
    local function makeBackdrop(parent, w, h, tex, a)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex or BG_TEX, 0, true)
        if a then BlzFrameSetAlpha(f, a) end
        return f
    end

    local function makeButton(parent, w, h, label)
        local btn = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(btn, w, h)
        local plate = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
        BlzFrameSetAllPoints(plate, btn)
        BlzFrameSetTexture(plate, BTN_TEX, 0, true)
        local txt = BlzCreateFrameByType("TEXT", "", btn, "", 0)
        BlzFrameSetPoint(txt, FRAMEPOINT_CENTER, btn, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(txt, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(txt, 1.00)
        BlzFrameSetText(txt, label or "")
        return btn
    end

    local function makeHeader(parent, text)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(t, 1.10)
        BlzFrameSetText(t, text or "")
        return t
    end

    local function makeText(parent, text)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        BlzFrameSetScale(t, 0.96)
        BlzFrameSetText(t, text or "")
        return t
    end

    --------------------------------------------------
    -- Core builders
    --------------------------------------------------
    local function ensureUI(pid)
        if root[pid] then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        -- Root black panel
        local r = makeBackdrop(ui, PANEL_W, PANEL_H, BG_TEX, 230)
        root[pid] = r
        BlzFrameSetPoint(r, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0.0, 0.02)
        BlzFrameSetVisible(r, false)

        -- Close button
        local closeBtn = makeButton(r, 0.022, 0.022, "X")
        BlzFrameSetPoint(closeBtn, FRAMEPOINT_TOPRIGHT, r, FRAMEPOINT_TOPRIGHT, -PAD, -PAD)
        local tc = CreateTrigger()
        BlzTriggerRegisterFrameEvent(tc, closeBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(tc, function()
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(r, false)
            end
        end)

        -- Left nav column
        local left = makeBackdrop(r, NAV_W, PANEL_H - PAD*2, BG_TEX, 230)
        BlzFrameSetPoint(left, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, PAD, -PAD)

        -- Persistent content slot on the right (never destroyed)
        local cont = makeBackdrop(r, PANEL_W - NAV_W - PAD*3, PANEL_H - PAD*2, BG_TEX, 230)
        BlzFrameSetPoint(cont, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, NAV_W + PAD*2, -PAD)
        slot[pid] = cont

        -- Prepare pane table
        panes[pid] = panes[pid] or {}

        -- Wire nav once
        if not wired[pid] then
            local y = -0.012
            local function addNav(name, onClick)
                local b = makeButton(left, NAV_W - PAD*2, BTN_H, name)
                BlzFrameSetPoint(b, FRAMEPOINT_TOPLEFT, left, FRAMEPOINT_TOPLEFT, PAD, y)
                y = y - (BTN_H + GAP)
                local t = CreateTrigger()
                BlzTriggerRegisterFrameEvent(t, b, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(t, onClick)
            end

            -- Tasks (pane created lazily)
            addNav("Tasks", function()
                YemmaHub.ShowTasks(pid)
            end)

            -- Travel (pane created lazily)
            addNav("Travel", function()
                YemmaHub.ShowTravel(pid)
            end)

            -- Services (static text)
            addNav("Services", function()
                YemmaHub.ShowServices(pid)
            end)

            -- Intro (static text)
            addNav("Intro", function()
                YemmaHub.ShowIntro(pid)
            end)

            wired[pid] = true
        end
    end

    local function hideAllPanes(pid)
        local p = panes[pid]; if not p then return end
        if p.tasks   then BlzFrameSetVisible(p.tasks,   false) end
        if p.travel  then BlzFrameSetVisible(p.travel,  false) end
        if p.services then BlzFrameSetVisible(p.services, false) end
        if p.intro   then BlzFrameSetVisible(p.intro,   false) end
    end

    -- Create a new empty pane under the persistent slot; we don't destroy panes
    local function makePane(pid)
        local parent = slot[pid]
        local pane = makeBackdrop(parent, 0.001, 0.001, BG_TEX, 0) -- transparent holder
        BlzFrameSetAllPoints(pane, parent)
        return pane
    end

    --------------------------------------------------
    -- Pages (show/hide panes; create once)
    --------------------------------------------------
    function YemmaHub.ShowTasks(pid)
        ensureUI(pid)
        hideAllPanes(pid)
        local p = panes[pid]
        if not p.tasks then
            p.tasks = makePane(pid)
            -- Embed the task module into this pane
            if _G.YemmaTaskMenu and YemmaTaskMenu.RenderIn then
                YemmaTaskMenu.RenderIn(pid, p.tasks)
            else
                local hdr = makeHeader(p.tasks, "Tasks")
                BlzFrameSetPoint(hdr, FRAMEPOINT_TOPLEFT, p.tasks, FRAMEPOINT_TOPLEFT, PAD, -PAD)
                local tip = makeText(p.tasks, "Task menu module not found")
                BlzFrameSetPoint(tip, FRAMEPOINT_TOPLEFT, p.tasks, FRAMEPOINT_TOPLEFT, PAD, -0.045)
            end
        else
            -- Pane exists: just ask the module to refresh in-place
            if _G.YemmaTaskMenu and YemmaTaskMenu.Refresh then
                YemmaTaskMenu.Refresh(pid)
            end
        end
        BlzFrameSetVisible(p.tasks, true)
    end

    function YemmaHub.ShowTravel(pid)
        ensureUI(pid)
        hideAllPanes(pid)
        local p = panes[pid]
        if not p.travel then
            p.travel = makePane(pid)
            if _G.YemmaTravel and YemmaTravel.RenderIn then
                YemmaTravel.RenderIn(pid, p.travel)
            else
                local hdr = makeHeader(p.travel, "Yemma Teleports")
                BlzFrameSetPoint(hdr, FRAMEPOINT_TOPLEFT, p.travel, FRAMEPOINT_TOPLEFT, PAD, -PAD)
                local tip = makeText(p.travel, "Travel module not found")
                BlzFrameSetPoint(tip, FRAMEPOINT_TOPLEFT, p.travel, FRAMEPOINT_TOPLEFT, PAD, -0.045)
            end
        end
        BlzFrameSetVisible(p.travel, true)
    end

    function YemmaHub.ShowServices(pid)
        ensureUI(pid)
        hideAllPanes(pid)
        local p = panes[pid]
        if not p.services then
            p.services = makePane(pid)
            local hdr = makeHeader(p.services, "Services")
            BlzFrameSetPoint(hdr, FRAMEPOINT_TOPLEFT, p.services, FRAMEPOINT_TOPLEFT, PAD, -PAD)
            local tip = makeText(p.services, "Mark hub, teleport menu, more coming.")
            BlzFrameSetPoint(tip, FRAMEPOINT_TOPLEFT, p.services, FRAMEPOINT_TOPLEFT, PAD, -0.045)
        end
        BlzFrameSetVisible(p.services, true)
    end

    function YemmaHub.ShowIntro(pid)
        ensureUI(pid)
        hideAllPanes(pid)
        local p = panes[pid]
        if not p.intro then
            p.intro = makePane(pid)
            local hdr = makeHeader(p.intro, "Intro")
            BlzFrameSetPoint(hdr, FRAMEPOINT_TOPLEFT, p.intro, FRAMEPOINT_TOPLEFT, PAD, -PAD)
            local tip = makeText(p.intro, "Watch or skip intro.")
            BlzFrameSetPoint(tip, FRAMEPOINT_TOPLEFT, p.intro, FRAMEPOINT_TOPLEFT, PAD, -0.045)
        end
        BlzFrameSetVisible(p.intro, true)
    end

    --------------------------------------------------
    -- Public open/close
    --------------------------------------------------
    function YemmaHub.Open(pid)
        ensureUI(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], true)
        end
        -- Optional: default to Tasks or last opened pane
        YemmaHub.ShowTasks(pid)
    end

    function YemmaHub.Close(pid)
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], false)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("YemmaHub")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
