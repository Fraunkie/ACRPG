if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD.lua") end
--==================================================
-- ThreatHUD.lua
-- Minimal threat + DPS overlay (toggle with P)
-- • Uses AggroManager for threat and DPS
-- • Top-right corner, small footprint
-- • Total-initialization safe (OnInit.final)
--==================================================

if not ThreatHUD then ThreatHUD = {} end
_G.ThreatHUD = ThreatHUD

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local PANEL_W      = 0.20
    local PANEL_H      = 0.12
    local LINE_H       = 0.015
    local PADDING      = 0.006
    local MAX_LINES    = 6       -- header + up to 5 entries
    local TICK_SEC     = 0.25

    local HEADER_COLOR = "|cffffff88"  -- pale yellow
    local TEXT_COLOR   = "|cffffffff"  -- white
    local DIM_COLOR    = "|cffcccccc"  -- light gray
    local RESET_COLOR  = "|r"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local parent = nil
    local st     = {}        -- st[pid] = { root, lines[], visible, timer }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dev() return rawget(_G,"DevMode") and DevMode.IsEnabled and DevMode.IsEnabled() end
    local function dprint(s) if dev() then print("[ThreatHUD] "..tostring(s)) end end

    local function ensure(pid)
        if st[pid] then return st[pid] end

        local ui = parent or BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root = BlzCreateFrameByType("FRAME", "ThreatHUDRoot"..pid, ui, "", 0)
        BlzFrameSetSize(root, PANEL_W, PANEL_H)
        -- top-right with padding
        BlzFrameSetPoint(root, FRAMEPOINT_TOPRIGHT, ui, FRAMEPOINT_TOPRIGHT, -0.020, -0.105)
        BlzFrameSetVisible(root, false)

        -- Optional: simple translucent back panel (uses stock tooltip backdrop)
        local back = BlzCreateFrameByType("BACKDROP", "ThreatHUDBack"..pid, root, "", 0)
        BlzFrameSetAllPoints(back, root)
        BlzFrameSetTexture(back, "UI\\Widgets\\ToolTips\\Human\\human-tooltip-background.blp", 0, true)
        BlzFrameSetAlpha(back, 180)

        local lines = {}
        for i = 1, MAX_LINES do
            local t = BlzCreateFrameByType("TEXT", "ThreatHUDText"..pid.."_"..i, root, "", 0)
            BlzFrameSetSize(t, PANEL_W - PADDING * 2, LINE_H)
            local yOff = -PADDING - (i - 1) * (LINE_H + 0.002)
            BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT, root, FRAMEPOINT_TOPLEFT, PADDING, yOff)
            BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
            BlzFrameSetText(t, "")
            lines[i] = t
        end

        st[pid] = { root = root, lines = lines, visible = false, timer = nil }
        return st[pid]
    end

    local function setVisible(pid, on)
        local S = ensure(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(S.root, on and true or false)
        end
        S.visible = on and true or false
    end

    local function fmtThreatLine(rank, pid, value, youPid)
        local name = "P"..tostring(pid)
        local val  = math.floor(value or 0)
        local you  = (pid == youPid)
        local color = you and HEADER_COLOR or TEXT_COLOR
        return color .. tostring(rank) .. ". " .. name .. "  " .. tostring(val) .. RESET_COLOR
    end

    local function avgGroupDPSForList(list)
        if not list or #list == 0 then return 0 end
        local have, sum = 0, 0
        for i = 1, #list do
            local pid = list[i].pid
            if _G.AggroManager and AggroManager.GetGroupDPS then
                sum = sum + (AggroManager.GetGroupDPS(pid) or 0)
                have = have + 1
            end
        end
        if have == 0 then return 0 end
        return sum / have
    end

    local function updateOne(pid)
        local S = st[pid]
        if not S or not S.visible then return end

        local tgt = nil
        if _G.AggroManager and AggroManager.GetPlayerPrimaryTarget then
            tgt = AggroManager.GetPlayerPrimaryTarget(pid)
        end
        if not tgt or GetUnitTypeId(tgt) == 0 then
            -- no valid target
            BlzFrameSetText(S.lines[1], DIM_COLOR .. "Threat HUD (no target)" .. RESET_COLOR)
            for i = 2, MAX_LINES do BlzFrameSetText(S.lines[i], "") end
            return
        end

        local list = {}
        if _G.AggroManager and AggroManager.GetThreatList then
            list = AggroManager.GetThreatList(tgt) or {}
        end

        -- header: unit name and yours + group dps
        local myDPS = (_G.AggroManager and AggroManager.GetGroupDPS) and math.floor(AggroManager.GetGroupDPS(pid) + 0.5) or 0
        local grpDPS = math.floor(avgGroupDPSForList(list) + 0.5)
        local unitName = GetUnitName(tgt) or "Target"
        BlzFrameSetText(S.lines[1],
            HEADER_COLOR .. unitName .. RESET_COLOR ..
            DIM_COLOR .. "  your dps " .. tostring(myDPS) .. "  avg dps " .. tostring(grpDPS) .. RESET_COLOR)

        -- top entries
        for i = 1, MAX_LINES - 1 do
            local row = list[i]
            local line = S.lines[i + 1]
            if row then
                BlzFrameSetText(line, fmtThreatLine(i, row.pid, row.value, pid))
            else
                BlzFrameSetText(line, "")
            end
        end
    end

    local function ensureTicker(pid)
        local S = ensure(pid)
        if S.timer then return end
        local t = CreateTimer()
        S.timer = t
        TimerStart(t, TICK_SEC, true, function()
            local ok, err = pcall(updateOne, pid)
            if not ok then
                if dev() then print("[ThreatHUD] update error "..tostring(err)) end
            end
        end)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function ThreatHUD.Show(pid)
        ensure(pid)
        setVisible(pid, true)
        ensureTicker(pid)
    end

    function ThreatHUD.Hide(pid)
        local S = ensure(pid)
        setVisible(pid, false)
    end

    function ThreatHUD.Toggle(pid)
        local S = ensure(pid)
        setVisible(pid, not S.visible)
        ensureTicker(pid)
    end

    --------------------------------------------------
    -- Keybind (P)
    --------------------------------------------------
    local function bindKey()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local trig = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P, 0, true)
            TriggerAddAction(trig, function()
                local p = GetTriggerPlayer()
                local id = GetPlayerId(p)
                ThreatHUD.Toggle(id)
            end)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        bindKey()
        dprint("ready")
        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUD")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
