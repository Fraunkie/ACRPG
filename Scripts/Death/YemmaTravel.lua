if Debug and Debug.beginFile then Debug.beginFile("YemmaTravel.lua") end
--==================================================
-- YemmaTravel.lua
-- Simple 2x4 grid “Yemma’s Teleports” menu.
-- Black background, hover glow, multiplayer-safe.
--==================================================

if not YemmaTravel then YemmaTravel = {} end
_G.YemmaTravel = YemmaTravel

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local BG_BLACK = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"
    local BTN_ICON = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp"

    local PANEL_W, PANEL_H = 0.44, 0.30
    local PAD = 0.014
    local COLS, ROWS = 4, 2
    local CELL_W, CELL_H = 0.040, 0.050
    local GAP_X, GAP_Y = 0.010, 0.010
    local ICON_W, ICON_H = 0.028, 0.028
    local LABEL_H = 0.014
    local GRID_OFFSET_X, GRID_OFFSET_Y = PAD, -0.048

    local TELEPORT_ENTRIES = {
        "Check In", "Spirit Realm", "Kami Lookout", "Tournament",
        "Forest", "Mountains", "Desert", "Ocean"
    }

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root = {}

    --------------------------------------------------
    -- UI helpers
    --------------------------------------------------
    local function makeBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex or BG_BLACK, 0, true)
        BlzFrameSetAlpha(f, 255)
        return f
    end

    local function makeButton(parent, w, h)
        local b = BlzCreateFrameByType("BUTTON", "", parent, "", 0)
        BlzFrameSetSize(b, w, h)
        return b
    end

    local function makeText(parent, txt, scale)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetScale(t, scale or 0.9)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        BlzFrameSetText(t, txt or "")
        return t
    end

    --------------------------------------------------
    -- Grid builder
    --------------------------------------------------
    local function buildGrid(pid, parent)
        local title = makeText(parent, "Yemma's Teleports", 1.05)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, 0.0, -0.012)

        local startX, startY = GRID_OFFSET_X, GRID_OFFSET_Y
        local index = 0
        for r = 1, ROWS do
            for c = 1, COLS do
                index = index + 1
                local labelTxt = TELEPORT_ENTRIES[index] or ("Slot " .. tostring(index))
                local cx = startX + (c - 1) * (CELL_W + GAP_X)
                local cy = startY - (r - 1) * (CELL_H + GAP_Y)

                -- cell
                local cell = makeBackdrop(parent, CELL_W, CELL_H, BG_BLACK)
                BlzFrameSetAlpha(cell, 64)
                BlzFrameSetPoint(cell, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, cx, cy)

                -- button
                local btn = makeButton(cell, ICON_W, ICON_H)
                BlzFrameSetPoint(btn, FRAMEPOINT_TOP, cell, FRAMEPOINT_TOP, 0.0, -0.002)

                local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(icon, btn)
                BlzFrameSetTexture(icon, BTN_ICON, 0, true)

                -- Hover overlay
                local hover = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(hover, btn)
                BlzFrameSetTexture(hover, "UI\\Feedback\\AutocastButton.blp", 0, true)
                BlzFrameSetAlpha(hover, 0)

                local label = makeText(cell, labelTxt)
                BlzFrameSetPoint(label, FRAMEPOINT_BOTTOM, cell, FRAMEPOINT_BOTTOM, 0.0, 0.004)
                BlzFrameSetSize(label, CELL_W, LABEL_H)

                -- Hover effects
                local tEnter = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tEnter, btn, FRAMEEVENT_MOUSE_ENTER)
                TriggerAddAction(tEnter, function() BlzFrameSetAlpha(hover, 200) end)

                local tLeave = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tLeave, btn, FRAMEEVENT_MOUSE_LEAVE)
                TriggerAddAction(tLeave, function() BlzFrameSetAlpha(hover, 0) end)

                local tClick = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tClick, btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(tClick, function()
                    DisplayTextToPlayer(Player(pid), 0, 0, "Clicked " .. labelTxt)
                    -- Optional: wire into TeleportSystem if you want
                    -- local nodeId = ... (resolve by label via GameBalance.NODE_PRETTY)
                    -- TeleportSystem.Unlock(pid, nodeId)
                    -- TeleportSystem.TeleportToNode(pid, nodeId, { reason = "yemma_travel" })
                end)
            end
        end
    end

    --------------------------------------------------
    -- Render inside another frame
    --------------------------------------------------
    function YemmaTravel.RenderIn(pid, parent)
        if not parent then return end
        local bg = makeBackdrop(parent, PANEL_W, PANEL_H, BG_BLACK)
        BlzFrameSetAllPoints(bg, parent)
        BlzFrameSetAlpha(bg, 220)
        buildGrid(pid, parent)
    end

    --------------------------------------------------
    -- Standalone modal (dev only)
    --------------------------------------------------
    local function ensureStandalone(pid)
        if root[pid] then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local r = makeBackdrop(ui, PANEL_W, PANEL_H, BG_BLACK)
        root[pid] = r
        BlzFrameSetPoint(r, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0.0, 0.02)
        BlzFrameSetAlpha(r, 230)
        BlzFrameSetVisible(r, false)

        local close = makeButton(r, 0.024, 0.022)
        BlzFrameSetPoint(close, FRAMEPOINT_TOPRIGHT, r, FRAMEPOINT_TOPRIGHT, -PAD, -PAD)
        local txt = makeText(close, "X", 0.95)
        BlzFrameSetPoint(txt, FRAMEPOINT_CENTER, close, FRAMEPOINT_CENTER, 0.0, 0.0)
        local t = CreateTrigger()
        BlzTriggerRegisterFrameEvent(t, close, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(t, function()
            if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(r, false) end
        end)

        local cont = makeBackdrop(r, PANEL_W - PAD * 2, PANEL_H - PAD * 2, BG_BLACK)
        BlzFrameSetPoint(cont, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, PAD, -PAD)
        buildGrid(pid, cont)
    end

    function YemmaTravel.Show(pid)
        ensureStandalone(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], true)
        end
    end

    function YemmaTravel.Close(pid)
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], false)
        end
    end

    --------------------------------------------------
    -- Dev command
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), "-travel", true)
        end
        TriggerAddAction(t, function()
            local pid = GetPlayerId(GetTriggerPlayer())
            YemmaTravel.Show(pid)
        end)
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("YemmaTravel")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
