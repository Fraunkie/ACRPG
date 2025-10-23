if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD.lua") end
--==================================================
-- ThreatHUD.lua
-- Single text display for threat/DPS, top-right corner.
--==================================================

if not CombatThreatHUD then CombatThreatHUD = {} end
_G.CombatThreatHUD = CombatThreatHUD

do
    local TICK = 0.25
    -- Top-right corner position
    local POS_X, POS_Y = 0.79, 0.56
    local FONT_SIZE = 0.018
    local BG = "war3mapImported\\DpsBoard.blp"

    local frames   = {}
    local enabled  = {}
    local timerObj = nil

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function ensureFrame(pid)
        if frames[pid] then return frames[pid] end
        local parent = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local root   = BlzCreateFrameByType("BACKDROP", "th_root_" .. pid, parent, "", 0)
        BlzFrameSetSize(root, 0.28, 0.06)
        -- Top-right corner placement
        BlzFrameSetAbsPoint(root, FRAMEPOINT_TOPRIGHT, POS_X, POS_Y)
        BlzFrameSetVisible(root, false)
        BlzFrameSetTexture(root, BG, 0, true)

        local text = BlzCreateFrameByType("TEXT", "th_text_" .. pid, root, "", 0)
        BlzFrameSetPoint(text, FRAMEPOINT_CENTER, root, FRAMEPOINT_CENTER, 0.0, -0.010)
        BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_TOP)
        BlzFrameSetScale(text, 1.0)
        BlzFrameSetVisible(text, true)
        BlzFrameSetText(text, "Threat HUD")

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

    local function oneDec(x)
        if x ~= x or x == math.huge or x == -math.huge then return 0 end
        local v = math.floor((x or 0) * 10 + 0.5) / 10
        return v
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
                    local row = snap.rows[1]
                    if row then
                        dps = tonumber(row.dps or 0) or 0
                        threat = tonumber(row.threat or 0) or 0
                    end
                end
            end
        else
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

        return "[Target] " .. tostring(tgtName)
            .. " | " .. tostring(playerName)
            .. " | DPS " .. tostring(oneDec(dps))
            .. " | Threat " .. tostring(math.floor(threat + 0.5))
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

    OnInit.final(function()
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
