if Debug and Debug.beginFile then Debug.beginFile("YemmaTravel.lua") end
--==================================================
-- YemmaTravel.lua (v2.0)
-- “Yemma’s Teleports” menu
-- • 2x4 grid with no text under icons
-- • Lore / lock text in CustomTooltip box with:
--   - Gold Title
--   - Orange Description
--   - Green Quote
--   - Requirements in White for unlocked & Purple for numbers, Grey for locked
--==================================================

if not YemmaTravel then YemmaTravel = {} end
_G.YemmaTravel = YemmaTravel

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local BG_BLACK = "ReplaceableTextures\\CameraMasks\\Black_mask.blp"
    local BTN_ICON = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp" -- fallback

    local PANEL_W, PANEL_H = 0.44, 0.30
    local PAD = 0.014
    local COLS, ROWS = 4, 2
    local CELL_W, CELL_H = 0.040, 0.050
    local GAP_X, GAP_Y = 0.010, 0.010
    local ICON_W, ICON_H = 0.028, 0.028
    local LABEL_H = 0.014
    local GRID_OFFSET_X, GRID_OFFSET_Y = PAD, -0.048

    -- Display labels in grid order (8 slots) without text under icons
    local TELEPORT_ENTRIES = {
        "Check In", "HFIL", "Kami Lookout", "Neo Capsule City",
        "Forest", "Mountains", "Desert", "Ocean"
    }

    -- Map labels to node ids (extend as nodes go live)
local BUTTON_TO_NODE = {
    ["Check In"]     = "YEMMA",
    ["HFIL"]         = "HFIL",
    ["Neo Capsule City"] = "NEO_CAPSULE_CITY",  -- Ensure this line is correctly mapped
    ["Kami Lookout"] = "KAMI_LOOKOUT",
    ["Forest"]       = "VIRIDIAN",
    ["Mountains"]    = "FILE_ISLAND",
    ["Desert"]       = "LAND_OF_FIRE",
}

    --------------------------------------------------
    -- State per player
    --------------------------------------------------
    local grids = {}

    --------------------------------------------------
    -- Shared CustomTooltip (ALICE style)
    --------------------------------------------------
    local function getSharedTooltip()
        -- we keep our own copy under index 1 so we do not clash with ALICE (which uses 0)
        if not _G.YemmaTravelTooltip then
            BlzLoadTOCFile("CustomTooltip.toc")
            local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
            local box = BlzCreateFrame("CustomTooltip", parent, 0, 1)
            local title = BlzGetFrameByName("CustomTooltipTitle", 1)
            local text  = BlzGetFrameByName("CustomTooltipValue", 1)

            -- keep it above most UI
            BlzFrameSetLevel(box, 10)
            BlzFrameSetVisible(box, false)

            -- base colors (quotes will use color codes)
            if title then
                BlzFrameSetTextColor(title, BlzConvertColor(255, 255, 230, 128)) -- warm gold
            end
            if text then
                BlzFrameSetTextColor(text, BlzConvertColor(255, 255, 180, 80))   -- soft orange
            end

            _G.YemmaTravelTooltip = { box = box, title = title, text = text }
        end
        return _G.YemmaTravelTooltip.box,
               _G.YemmaTravelTooltip.title,
               _G.YemmaTravelTooltip.text
    end

    local function hideTooltipFor(pid)
        local t = _G.YemmaTravelTooltip
        if not t then return end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(t.box, false)
        end
    end

    --------------------------------------------------
    -- Helpers
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
        if not nodeId then
            return { locked = true, reason = "Destination not available." }
        end
        if not _G.TeleportSystem or not TeleportSystem.GetLockInfo then
            return { locked = false, reason = "" }
        end
        return TeleportSystem.GetLockInfo(pid, nodeId)
    end

    local function getNodePretty(nodeId, fallbackLabel)
        if not nodeId then
            return fallbackLabel or "Unknown Destination"
        end
        local GB = GameBalance or {}
        local pretty = GB.NODE_PRETTY or {}
        if pretty[nodeId] then return pretty[nodeId] end
        return nodeId
        
    end

    local function getNodeLore(nodeId)
        if not nodeId then
            return "The route is not yet stabilized. Yemma’s clerks are still arguing over the paperwork."
        end
        local GB = GameBalance or {}
        local desc = GB.NODE_DESC or {}
        return desc[nodeId] or ""
    end

    local function buildBodyText(pid, nodeId)
        local info = getLockInfo(pid, nodeId)
        if info.locked then
            if info.reason and info.reason ~= "" then
                return info.reason
            end
            local GB = GameBalance or {}
            local req = (GB.NODE_REQS or {})[nodeId] or {}
            local parts = {}
            if req.pl_min then
                parts[#parts + 1] = "Requires Power Level " .. tostring(req.pl_min)
            end
            if req.se_min then
                parts[#parts + 1] = "Requires Soul Energy " .. tostring(req.se_min)
            end
            local txt = table.concat(parts, "  ")
            if txt ~= "" then
                return txt
            end
            return "Destination is locked."
        end

        local lore = getNodeLore(nodeId)
        if lore ~= "" then
            return lore
        end
        return "Destination available."
    end

    -- Title + body + quote + dynamic sizing
    local function showTooltipFor(pid, nodeId, anchor, labelTxt)
        if not anchor then return end
        local box, title, text = getSharedTooltip()
        if not box or not text then return end

        if GetLocalPlayer() ~= Player(pid) then
            return
        end

        local headline = getNodePretty(nodeId, labelTxt)
        local body     = buildBodyText(pid, nodeId)

        -- Split off final quote if present (first "—" from the left)
        local mainBody = body
        local quote = nil
        local dashPos = string.find(body, "—", 1, true)
        if dashPos then
            mainBody = string.sub(body, 1, dashPos - 1)
            quote    = string.sub(body, dashPos)
        end

        -- Compose text with extra spacing and colored quote
        local finalText = mainBody
        if quote then
            -- two line breaks, quote in green, then a space line so bottom never clips
            finalText = mainBody .. "\n\n" .. "|cff00ff00" .. quote .. "|r" .. "\n "
        else
            finalText = body .. "\n "
        end

        -- Remove extra white titles and only display one
        if title then
            BlzFrameSetText(title, headline or "")
        end
        BlzFrameSetText(text, finalText or "")

        -- pick width based on length of composed text
        local composedLen = string.len(finalText or "")
        local textWidth = 0.26
        if composedLen > 220 then
            textWidth = 0.34
        elseif composedLen > 120 then
            textWidth = 0.30
        end

        BlzFrameSetSize(text, textWidth, 0.0)
        local h = BlzFrameGetHeight(text)
        -- little padding around the text
        BlzFrameSetSize(box, textWidth + 0.02, h + 0.036)

        BlzFrameClearAllPoints(box)
        -- hover style: box near the button, below and to the right
        BlzFrameSetPoint(box, FRAMEPOINT_TOPLEFT, anchor, FRAMEPOINT_BOTTOMRIGHT, 0.004, -0.004)

        BlzFrameSetVisible(box, true)
    end

    --------------------------------------------------
    -- Refresh grid cells (icons + gray state)
    --------------------------------------------------
    local function refreshGrid(pid)
        local list = grids[pid]
        if not list then return end
        local GB = GameBalance or {}
        local NODE_ICONS = GB.NODE_ICONS or {}

        for i = 1, #list do
            local cell   = list[i]
            local nodeId = cell.nodeId
            if nodeId then
                local info = getLockInfo(pid, nodeId)
                local locked = info.locked and true or false
                setIconGray(cell.icon, locked)

                local tex = NODE_ICONS[nodeId] or BTN_ICON
                BlzFrameSetTexture(cell.icon, tex, 0, true)
            else
                -- future destinations: normal icon, gray state always on
                setIconGray(cell.icon, true)
                BlzFrameSetTexture(cell.icon, BTN_ICON, 0, true)
            end
        end
    end

    --------------------------------------------------
    -- Build grid
    --------------------------------------------------
    local function buildGrid(pid, parent)
        grids[pid] = {}

        local title = makeText(parent, "Teleports", 1.05)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, 0.0, -0.012)

        local startX, startY = GRID_OFFSET_X, GRID_OFFSET_Y
        local index = 0

        for r = 1, ROWS do
            for c = 1, COLS do
                index = index + 1
                local labelTxt = TELEPORT_ENTRIES[index] or ("Slot " .. tostring(index))
                local nodeId   = resolveNodeIdByLabel(labelTxt)
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

                local tEnter = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tEnter, btn, FRAMEEVENT_MOUSE_ENTER)
                TriggerAddAction(tEnter, function()
                    BlzFrameSetAlpha(hover, 200)
                    showTooltipFor(pid, nodeId, btn, labelTxt)
                end)

                local tLeave = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tLeave, btn, FRAMEEVENT_MOUSE_LEAVE)
                TriggerAddAction(tLeave, function()
                    BlzFrameSetAlpha(hover, 0)
                    hideTooltipFor(pid)
                end)

                local tClick = CreateTrigger()
                BlzTriggerRegisterFrameEvent(tClick, btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(tClick, function()
                    if not nodeId then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Destination not available.")
                        return
                    end
                    if not _G.TeleportSystem or not TeleportSystem.TeleportToNode then
                        DisplayTextToPlayer(Player(pid), 0, 0, "Travel system not ready.")
                        return
                    end
                    local info = getLockInfo(pid, nodeId)
                    if info.locked then
                        local msg = info.reason ~= "" and info.reason or "Destination is locked."
                        DisplayTextToPlayer(Player(pid), 0, 0, msg)
                        return
                    end
                    TeleportSystem.TeleportToNode(pid, nodeId, { reason = "yemma_travel", setHub = true })
                    if _G.setUiFocus then
                        setUiFocus(pid, false)
                    end
                    hideTooltipFor(pid)
                end)

                grids[pid][#grids[pid] + 1] = {
                    btn   = btn,
                    icon  = icon,
                    hover = hover,
                    label = label,
                    nodeId = nodeId,
                    labelTxt = labelTxt,
                    frame = cellFrame,
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
