if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD.lua") end
--==================================================
-- ThreatHUD.lua
-- Single text display for threat/DPS, centered on screen.
-- Uses ThreatHUDData.BuildSnapshot(pid).
-- API:
--   CombatThreatHUD.Show(pid)
--   CombatThreatHUD.Hide(pid)
--   CombatThreatHUD.Toggle(pid)
--==================================================

if not CombatThreatHUD then CombatThreatHUD = {} end
_G.CombatThreatHUD = CombatThreatHUD

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TICK = 0.25
    -- Center of screen; we will move later when you want
    local POS_X, POS_Y = 0.40, 0.34
    local FONT_SIZE = 0.018  -- about 18 px

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local frames   = {}   -- pid -> { root, text }
    local enabled  = {}   -- pid -> bool
    local timerObj = nil

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function ensureFrame(pid)
        if frames[pid] then return frames[pid] end

        local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root   = BlzCreateFrameByType("BACKDROP", "th_root_" .. pid, parent, "", 0)
        BlzFrameSetSize(root, 0.28, 0.06) -- small box; invisible backdrop
        BlzFrameSetAbsPoint(root, FRAMEPOINT_CENTER, POS_X, POS_Y)
        BlzFrameSetVisible(root, false)
        BlzFrameSetTexture(root, "", 0, true) -- no texture

        local text = BlzCreateFrameByType("TEXT", "th_text_" .. pid, root, "", 0)
        BlzFrameSetPoint(text, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(text, 1.0)
        BlzFrameSetVisible(text, true)
        BlzFrameSetText(text, "Threat HUD")

        -- set font (use default if custom not present)
        if BlzFrameSetFont then
            BlzFrameSetFont(text, "Fonts\\frizqt__.ttf", FONT_SIZE, 0)
        end

        frames[pid] = { root = root, text = text }
        return frames[pid]
    end

    local function setVisibleLocal(pid, flag)
        local f = ensureFrame(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(f.root, flag)
        end
    end

    local function fmtNumber(x)
        local n = tonumber(x or 0) or 0
        -- show one decimal for DPS, integers for threat
        return n
    end

    local function buildLine(pid)
        local D = rawget(_G, "ThreatHUDData")
        local tgt = nil
        local dps = 0
        local threat = 0
        local tgtName = "No Target"
        local playerName = GetPlayerName(Player(pid)) or ("Player " .. tostring(pid))

        if D and D.BuildSnapshot then
            local snap = D.BuildSnapshot(pid)
            if snap then
                tgtName = snap.targetName or tgtName
                if snap.rows and #snap.rows > 0 then
                    -- snapshot rows have current player first
                    local row = snap.rows[1]
                    if row then
                        dps = tonumber(row.dps or 0) or 0
                        threat = tonumber(row.threat or 0) or 0
                    end
                end
            end
        else
            -- Fallback: try AggroManager if data layer is missing
            local AM = rawget(_G, "AggroManager")
            if AM and AM.GetAnyTargetForPid then
                tgt = AM.GetAnyTargetForPid(pid)
                if ValidUnit(tgt) then
                    tgtName = GetUnitName(tgt) or tgtName
                    if AM.GetThreatList then
                        local list = AM.GetThreatList(tgt)
                        if list then
                            for i = 1, #list do
                                local row = list[i]
                                if row and row.pid == pid then
                                    threat = row.value or 0
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Single line of text (no percent symbols)
        -- Example: [Target] Wandering Spirit | Nerdymoney | DPS 125.4 | Threat 230
        return "[Target] " .. tostring(tgtName) ..
               " | " .. tostring(playerName) ..
               " | DPS " .. string.format("%.1f", dps) ..
               " | Threat " .. tostring(math.floor(threat + 0.5))
    end

    local function tick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if enabled[pid] then
                local f = ensureFrame(pid)
                local line = buildLine(pid)
                if GetLocalPlayer() == Player(pid) then
                    BlzFrameSetText(f.text, line)
                end
            end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CombatThreatHUD.Show(pid)
        enabled[pid] = true
        ensureFrame(pid)
        setVisibleLocal(pid, true)
    end

    function CombatThreatHUD.Hide(pid)
        enabled[pid] = false
        setVisibleLocal(pid, false)
    end

    function CombatThreatHUD.Toggle(pid)
        if enabled[pid] then
            CombatThreatHUD.Hide(pid)
        else
            CombatThreatHUD.Show(pid)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- per-player initialize, hidden by default
        for pid = 0, bj_MAX_PLAYERS - 1 do
            ensureFrame(pid)
            enabled[pid] = false
        end

        timerObj = CreateTimer()
        TimerStart(timerObj, TICK, true, tick)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUD")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
