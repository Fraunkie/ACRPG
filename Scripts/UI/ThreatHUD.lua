if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD.lua") end
--==================================================
-- ThreatHUD.lua
-- Minimal, editor-safe threat HUD with heartbeat.
-- • uses AggroManager helpers
-- • listens to ProcBus "AggroChanged" (optional)
-- • toggle with -thud (ChatTriggerRegistry)
--==================================================

if not ThreatHUD then ThreatHUD = {} end
_G.ThreatHUD = ThreatHUD

do
    -- Position / size
    local POS_X, POS_Y = 0.79, 0.58
    local WIDTH, HEIGHT = 0.18, 0.10
    local TICK = 0.25

    local COLOR_SELF, COLOR_OTH, COLOR_END = "|cff00ff00", "|cffffcc00", "|r"

    local frames = {}      -- pid -> frame
    local visible = {}     -- pid -> bool
    ThreatHUD.visible = visible

    local function DEV_ON()
        return (rawget(_G,"DevMode") and type(DevMode.IsEnabled)=="function" and DevMode.IsEnabled()) or false
    end
    local function dprint(s) if DEV_ON() then print("[ThreatHUD] "..tostring(s)) end end
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function ensureFrame(pid)
        if frames[pid] then return frames[pid] end
        local f = BlzCreateFrameByType("TEXT","ThreatHUDText"..pid,BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI,0),"",0)
        BlzFrameSetAbsPoint(f, FRAMEPOINT_TOPRIGHT, POS_X, POS_Y)
        BlzFrameSetSize(f, WIDTH, HEIGHT)
        BlzFrameSetText(f, "")
        BlzFrameSetEnable(f, false)
        BlzFrameSetVisible(f, false)
        frames[pid] = f
        return f
    end

    local function fmtLine(name, val, isSelf)
        local col = isSelf and COLOR_SELF or COLOR_OTH
        return col .. name .. COLOR_END .. " " .. tostring(val)
    end

    local function pickTarget(pid)
        if _G.AggroManager then
            if AggroManager.GetPlayerPrimaryTarget then
                local t = AggroManager.GetPlayerPrimaryTarget(pid)
                if ValidUnit(t) then return t end
            end
            if AggroManager.GetAnyTargetForPid then
                local t = AggroManager.GetAnyTargetForPid(pid)
                if ValidUnit(t) then return t end
            end
        end
        return nil
    end

    local function buildText(pid, target)
        if not _G.AggroManager or not target then return "" end
        local list = AggroManager.GetThreatList and AggroManager.GetThreatList(target)
        if not list or #list == 0 then return "" end
        table.sort(list, function(a,b) return (a.value or 0) > (b.value or 0) end)
        local txt = "Threat\n"
        for i = 1, math.min(#list, 4) do
            local e = list[i]
            local name = GetPlayerName(Player(e.pid))
            txt = txt .. fmtLine(name, math.floor(e.value or 0), e.pid == pid) .. "\n"
        end
        return txt
    end

    local function update(pid)
        local fr = ensureFrame(pid)
        if not visible[pid] then
            if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(fr, false) end
            return
        end
        local tgt = pickTarget(pid)
        local text = buildText(pid, tgt)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetText(fr, text)
            BlzFrameSetVisible(fr, text ~= "")
        end
    end

    function ThreatHUD.Show(pid)  visible[pid] = true;  update(pid) end
    function ThreatHUD.Hide(pid)
        visible[pid] = false
        local fr = ensureFrame(pid)
        if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(fr, false) end
    end
    function ThreatHUD.Toggle(pid)
        visible[pid] = not visible[pid]
        if visible[pid] then ThreatHUD.Show(pid) else ThreatHUD.Hide(pid) end
    end

    OnInit.final(function()
        local t = CreateTimer()
        TimerStart(t, TICK, true, function()
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                    update(pid)
                end
            end
        end)

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("AggroChanged", function()
                for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                    if visible[pid] then update(pid) end
                end
            end)
        end

        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUD")
        end
        dprint("ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
