if Debug and Debug.beginFile then Debug.beginFile("YemmaTravel.lua") end
--==================================================
-- YemmaTravel.lua (v1.1)
-- Simple 2x4 grid “Yemma’s Teleports” menu.
-- Updated: “Spirit Realm” renamed to “HFIL”
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

    -- Display labels in grid order (8 slots)
    local TELEPORT_ENTRIES = {
        "Check In", "HFIL", "Kami Lookout", "Tournament",
        "Forest", "Mountains", "Desert", "Ocean"
    }

    -- Map labels to node ids (extend as nodes go live)
    local BUTTON_TO_NODE = {
        ["Check In"]     = "YEMMA",
        ["HFIL"]         = "HFIL",
        ["Kami Lookout"] = "KAMI_LOOKOUT",
        ["Forest"]       = "VIRIDIAN",
        ["Mountains"]    = "FILE_ISLAND",
        ["Desert"]       = "LAND_OF_FIRE",
    }

    --------------------------------------------------
    -- State per player
    --------------------------------------------------
    local root = {}
    local grids = {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function devOn(pid)
        local D = rawget(_G, "Dev")
        if D and D.IsOn then
            local ok, res = pcall(D.IsOn, pid)
            if ok then return res and true or false end
        end
        return false
    end

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

    local function setIconGray(icon, isGray)
        if not icon then return end
        if isGray then
            BlzFrameSetVertexColor(icon, BlzConvertColor(255, 128, 128, 128))
            BlzFrameSetAlpha(icon, 120)
        else
            BlzFrameSetVertexColor(icon, BlzConvertColor(255, 255, 255, 255))
            BlzFrameSetAlpha(icon, 255)
        end
    end

    local function ensureTooltip(parent)
        local tip = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetScale(tip, 0.85)
        BlzFrameSetTextAlignment(tip, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        BlzFrameSetPoint(tip, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_TOP, 0.0, 0.006)
        BlzFrameSetVisible(tip, false)
        return tip
    end

    local function setTooltip(tip, txt)
        if not tip then return end
        BlzFrameSetText(tip, txt or "")
    end

    local function resolveNodeIdByLabel(label)
        if BUTTON_TO_NODE[label] then return BUTTON_TO_NODE[label] end
        local GB = GameBalance or {}
        local pretty = GB.NODE_PRETTY or {}
        for id, name in pairs(pretty) do
            if name == label then return id end
        end
        return nil
    end

    local function getLockInfo(pid, nodeId)
        if not _G.TeleportSystem or not TeleportSystem.GetLockInfo then
            return { locked = false, reason = "" }
        end
        return TeleportSystem.GetLockInfo(pid, nodeId)
    end

    local function buildTooltipText(pid, nodeId, labelTxt)
        local info = getLockInfo(pid, nodeId)
        if not info.locked then return "" end
        local parts = {}
        if info.reason and info.reason ~= "" then
            parts[#parts + 1] = info.reason
        else
            local GB = GameBalance or {}
            local req = (GB.NODE_REQS or {})[nodeId] or {}
            if req.pl_min then parts[#parts + 1] = "Requires Power Level " .. tostring(req.pl_min) end
            if req.se_min then parts[#parts + 1] = "Requires Soul Energy " .. tostring(req.se_min) end
        end
        local txt = table.concat(parts, "  ")
        if txt == "" then txt = "Locked" end
        return txt
    end

    --------------------------------------------------
    -- Refresh grid cells
    --------------------------------------------------
    local function refreshGrid(pid)
        local list = grids[pid]
        if not list then return end
        for i = 1, #list do
            local cell = list[i]
            local nodeId = cell.nodeId
            if nodeId then
                local info = getLockInfo(pid, nodeId)
                local locked = info.locked and true or false
                setIconGray(cell.icon, locked)
                if locked then
                    local tipTxt = buildTooltipText(pid, nodeId, "")
                    setTooltip(cell.tooltip, tipTxt)
                else
                    setTooltip(cell.tooltip, "")
                end
            else
                setIconGray(cell.icon, false)
                setTooltip(cell.tooltip, "")
            end
        end
    end

    --------------------------------------------------
    -- Build grid
    --------------------------------------------------
    local function buildGrid(pid, parent)
        grids[pid] = {}

        local title = makeText(parent, "Yemma's Teleports", 1.05)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, 0.0, -0.012)

        local startX, startY = GRID_OFFSET_X, GRID_OFFSET_Y
        local index = 0
        for r = 1, ROWS do
            for c = 1, COLS do
                index = index + 1
                local labelTxt = TELEPORT_ENTRIES[index] or ("Slot " .. tostring(index))
                local nodeId = resolveNodeIdByLabel(labelTxt)
                local cx = startX + (c - 1) * (CELL_W + GAP_X)
                local cy = startY - (r - 1) * (CELL_H + GAP_Y)

                local cellFrame = makeBackdrop(parent, CELL_W, CELL_H, BG_BLACK)
                BlzFrameSetAlpha(cellFrame, 64)
                BlzFrameSetPoint(cellFrame, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, cx, cy)

                local btn = makeButton(cellFrame, ICON_W, ICON_H)
                BlzFrameSetPoint(btn, FRAMEPOINT_TOP, cellFrame, FRAMEPOINT_TOP, 0.0, -0.002)

                local icon = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(icon, btn)
                BlzFrameSetTexture(icon, BTN_ICON, 0, true)

                local hover = BlzCreateFrameByType("BACKDROP", "", btn, "", 0)
                BlzFrameSetAllPoints(hover, btn)
                BlzFrameSetTexture(hover, "UI\\Feedback\\AutocastButton.blp", 0, true)
                BlzFrameSetAlpha(hover, 0)

                local label = makeText(cellFrame, labelTxt)
                BlzFrameSetPoint(label, FRAMEPOINT_BOTTOM, cellFrame, FRAMEPOINT_BOTTOM, 0.0, 0.004)
                BlzFrameSetSize(label, CELL_W, LABEL_H)

                local tooltip = ensureTooltip(cellFrame)
                setTooltip(tooltip, "")

                local tEnter = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tEnter, btn, FRAMEEVENT_MOUSE_ENTER)
                TriggerAddAction(tEnter, function()
                    BlzFrameSetAlpha(hover, 200)
                    if nodeId then
                        local tipTxt = buildTooltipText(pid, nodeId, labelTxt)
                        if tipTxt ~= "" then
                            if GetLocalPlayer() == Player(pid) then
                                setTooltip(tooltip, tipTxt)
                                BlzFrameSetVisible(tooltip, true)
                            end
                        end
                    end
                end)

                local tLeave = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tLeave, btn, FRAMEEVENT_MOUSE_LEAVE)
                TriggerAddAction(tLeave, function()
                    BlzFrameSetAlpha(hover, 0)
                    if GetLocalPlayer() == Player(pid) then
                        BlzFrameSetVisible(tooltip, false)
                    end
                end)

                local tClick = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tClick, btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(tClick, function()
                    if not nodeId then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Destination not available")
                        return
                    end
                    if not _G.TeleportSystem or not TeleportSystem.TeleportToNode then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Travel system not ready")
                        return
                    end
                    local info = getLockInfo(pid, nodeId)
                    if info.locked then
                        local msg = info.reason ~= "" and info.reason or "Destination is locked"
                        DisplayTextToPlayer(Player(pid), 0, 0, msg)
                        return
                    end
                    TeleportSystem.TeleportToNode(pid, nodeId, { reason = "yemma_travel", setHub = true })
                    setUiFocus(pid, false)
                end)

                grids[pid][#grids[pid] + 1] = {
                    btn = btn, icon = icon, hover = hover, label = label,
                    nodeId = nodeId, tooltip = tooltip
                }
            end
        end

        refreshGrid(pid)
    end

    --------------------------------------------------
    -- Render / Init
    --------------------------------------------------
    function YemmaTravel.RenderIn(pid, parent)
        if not parent then return end
        local bg = makeBackdrop(parent, PANEL_W, PANEL_H, BG_BLACK)
        BlzFrameSetAllPoints(bg, parent)
        BlzFrameSetAlpha(bg, 220)
        buildGrid(pid, parent)
    end

    OnInit.final(function()
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("YemmaTravel")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
