if Debug and Debug.beginFile then Debug.beginFile("TeleportHub.lua") end
--==================================================
-- TeleportHub.lua
-- Simple travel selector for unlocked nodes.
-- • No FDF; pure frames
-- • Reads GameBalance.NODE_PRETTY and TeleportSystem.IsUnlocked
-- • Click to teleport
-- • Bootflow-gated and NO auto-popup on unlock events
--==================================================

if not TeleportHub then TeleportHub = {} end
_G.TeleportHub = TeleportHub

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local GB      = GameBalance or {}
    local BG_TEX  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local BTN_TEX = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"

    local PANEL_W = 0.45
    local PANEL_H = 0.32
    local PAD     = 0.016

    local BTN_W   = 0.20
    local BTN_H   = 0.034
    local GAP     = 0.008

    local ROWS    = 6
    local COLS    = 2
    local PERPAGE = ROWS * COLS

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root    = {}      -- pid -> frame
    local grid    = {}      -- pid -> {buttons}
    local pageLbl = {}      -- pid -> frame
    local page    = {}      -- pid -> current page
    local listing = {}      -- pid -> array of node ids
    local idCache = nil     -- shared, filled on first use

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[TeleportHub] " .. tostring(s)) end
    end

    local function bootLocked(pid)
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        return pd and pd.bootflow_active == true
    end

    local function ensureIds()
        if idCache then return idCache end
        local ids = {}
        if GB and GB.TELEPORT_NODE_IDS then
            for k, v in pairs(GB.TELEPORT_NODE_IDS) do
                if type(v) == "string" then
                    ids[#ids+1] = v
                elseif type(k) == "string" then
                    ids[#ids+1] = k
                end
            end
        end
        idCache = ids
        return ids
    end

    local function pretty(id)
        if GB and GB.NODE_PRETTY and GB.NODE_PRETTY[id] then
            return GB.NODE_PRETTY[id]
        end
        return tostring(id)
    end

    local function isUnlocked(pid, id)
        if _G.TeleportSystem and TeleportSystem.IsUnlocked then
            local ok = TeleportSystem.IsUnlocked(pid, id)
            if ok then return true end
        end
        return false
    end

    local function gatherUnlocked(pid)
        local out = {}
        local ids = ensureIds()
        for i = 1, #ids do
            local id = ids[i]
            if isUnlocked(pid, id) then
                out[#out+1] = id
            end
        end
        table.sort(out, function(a, b) return pretty(a) < pretty(b) end)
        return out
    end

    local function makeBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex or BG_TEX, 0, true)
        BlzFrameSetAlpha(f, 230)
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
        BlzFrameSetScale(txt, 0.96)
        BlzFrameSetText(txt, label or "")
        return btn, txt
    end

    local function ensureUI(pid)
        if root[pid] then return end

        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local r = makeBackdrop(ui, PANEL_W, PANEL_H, BG_TEX)
        root[pid] = r
        BlzFrameSetPoint(r, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0.0, 0.00)
        BlzFrameSetVisible(r, false)

        -- Title
        local title = BlzCreateFrameByType("TEXT", "", r, "", 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, PAD, -PAD)
        BlzFrameSetScale(title, 1.10)
        BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(title, "Teleport Hub")

        -- Close
        local closeBtn, _ = makeButton(r, 0.022, 0.022, "X")
        BlzFrameSetPoint(closeBtn, FRAMEPOINT_TOPRIGHT, r, FRAMEPOINT_TOPRIGHT, -PAD, -PAD)
        local tClose = CreateTrigger()
        BlzTriggerRegisterFrameEvent(tClose, closeBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(tClose, function()
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(r, false)
            end
        end)

        -- Page label and arrows
        local prevBtn, _ = makeButton(r, 0.032, 0.028, "<")
        BlzFrameSetPoint(prevBtn, FRAMEPOINT_BOTTOMLEFT, r, FRAMEPOINT_BOTTOMLEFT, PAD, PAD)
        local nextBtn, _ = makeButton(r, 0.032, 0.028, ">")
        BlzFrameSetPoint(nextBtn, FRAMEPOINT_BOTTOMLEFT, prevBtn, FRAMEPOINT_RIGHT, GAP, 0.0)

        local lbl = BlzCreateFrameByType("TEXT", "", r, "", 0)
        pageLbl[pid] = lbl
        BlzFrameSetPoint(lbl, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -PAD, PAD)
        BlzFrameSetScale(lbl, 0.94)
        BlzFrameSetTextAlignment(lbl, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(lbl, "Page 1")

        -- Grid buttons
        grid[pid] = {}
        local left = PAD
        local top  = -0.050
        local x, y = 0, 0
        for i = 1, PERPAGE do
            local b, txt = makeButton(r, BTN_W, BTN_H, "")
            grid[pid][i] = { btn = b, txt = txt, node = nil }
            local cx = left + (x * (BTN_W + GAP))
            local cy = top - (y * (BTN_H + GAP))
            BlzFrameSetPoint(b, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, cx, cy)
            x = x + 1
            if x >= COLS then x = 0; y = y + 1 end
        end

        -- Page turns
        local tPrev = CreateTrigger()
        BlzTriggerRegisterFrameEvent(tPrev, prevBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(tPrev, function()
            TeleportHub.SetPage(pid, (page[pid] or 1) - 1)
        end)

        local tNext = CreateTrigger()
        BlzTriggerRegisterFrameEvent(tNext, nextBtn, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(tNext, function()
            TeleportHub.SetPage(pid, (page[pid] or 1) + 1)
        end)
    end

    local function bindGrid(pid)
        if not grid[pid] then return end
        for i = 1, PERPAGE do
            local cell = grid[pid][i]
            if cell and cell.btn then
                local trig = CreateTrigger()
                BlzTriggerRegisterFrameEvent(trig, cell.btn, FRAMEEVENT_CONTROL_CLICK)
                TriggerAddAction(trig, function()
                    local node = cell.node
                    if node and _G.TeleportSystem and TeleportSystem.TeleportToNode then
                        TeleportSystem.TeleportToNode(pid, node, { reason = "teleport_hub" })
                    end
                end)
            end
        end
    end

    local function render(pid)
        ensureUI(pid)
        local r = root[pid]
        local items = listing[pid] or {}
        local pg = page[pid] or 1
        if pg < 1 then pg = 1 end

        local count = #items
        local maxPg = math.max(1, math.ceil(count / PERPAGE))
        if pg > maxPg then pg = maxPg end
        page[pid] = pg

        -- do NOT force visible here; only Show controls visibility
        if pageLbl[pid] then
            BlzFrameSetText(pageLbl[pid], "Page " .. tostring(pg) .. " of " .. tostring(maxPg))
        end

        local startIndex = (pg - 1) * PERPAGE + 1
        local endIndex   = math.min(count, startIndex + PERPAGE - 1)

        local ci = 1
        for i = startIndex, endIndex do
            local node = items[i]
            local cell = grid[pid][ci]
            cell.node = node
            BlzFrameSetText(cell.txt, pretty(node))
            BlzFrameSetVisible(cell.btn, true)
            ci = ci + 1
        end
        for i = ci, PERPAGE do
            local cell = grid[pid][i]
            cell.node = nil
            BlzFrameSetText(cell.txt, "")
            BlzFrameSetVisible(cell.btn, false)
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function TeleportHub.Refresh(pid)
        if bootLocked(pid) then return end
        ensureUI(pid)
        listing[pid] = gatherUnlocked(pid)
        if not page[pid] or page[pid] < 1 then page[pid] = 1 end
        bindGrid(pid)
        render(pid)
    end

    function TeleportHub.SetPage(pid, newPage)
        if bootLocked(pid) then return end
        page[pid] = newPage
        render(pid)
    end

    function TeleportHub.Show(pid)
        if bootLocked(pid) then return end
        TeleportHub.Refresh(pid)
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], true)
        end
    end

    function TeleportHub.Hide(pid)
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], false)
        end
    end

    --------------------------------------------------
    -- Bus wiring (refresh when nodes unlock) – no auto show
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnTeleportUnlock", function(e)
                if not e or e.pid == nil then return end
                TeleportHub.Refresh(e.pid)  -- update silently
            end)
            PB.On("OnBootflowStart", function(e)
                if not e or e.pid == nil then return end
                TeleportHub.Hide(e.pid)
            end)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TeleportHub")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
