if not Bootflow then Bootflow = {} end
_G.Bootflow = Bootflow

do
    local GB = GameBalance or {}
    local BG_TEX  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local BAR_TEX = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-slider"
    local BTN_TEX = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"

    local BAR_DURATION = (GB.STARTUI and GB.STARTUI.BAR_DURATION) or 3.50
    local EXTRA_DELAY  = 2.00          -- wait 2 s after bar completes
    local TICK         = 0.03
    local PANEL_W, PANEL_H, PAD = 0.44, 0.11, 0.010

    local root, barFill, btn = {}, {}, {}
    local tAccum, barDone = {}, {}
    local timerBar = {}

    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function mkBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end

    local function enterCine() if CinematicModeBJ then CinematicModeBJ(true, bj_FORCE_ALL_PLAYERS) end end
    local function exitCine()  if CinematicModeBJ then CinematicModeBJ(false, bj_FORCE_ALL_PLAYERS) end end

    --------------------------------------------------
    -- Button creation (safe backdrop+text method)
    --------------------------------------------------
    local function ensureUI(pid)
        if btn[pid] then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        local b = BlzCreateFrameByType("BUTTON", "", ui, "", 0)
        BlzFrameSetSize(b, 0.22, 0.045)
        BlzFrameSetPoint(b, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0, -0.04)
        btn[pid] = b

        local bg = BlzCreateFrameByType("BACKDROP", "", b, "", 0)
        BlzFrameSetAllPoints(bg, b)
        BlzFrameSetTexture(bg, BTN_TEX, 0, true)

        local t = BlzCreateFrameByType("TEXT", "", b, "", 0)
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, b, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, "Create Soul")

        BlzFrameSetVisible(b, false)
        BlzFrameSetEnable(b, true)

        local trig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trig, b, FRAMEEVENT_CONTROL_CLICK)
        TriggerAddAction(trig, function()
            if not barDone[pid] then return end
            BlzFrameSetVisible(b, false)

            if CharacterCreation and CharacterCreation.Begin then
                pcall(CharacterCreation.Begin, pid)
            end

            local pd = PD(pid)
            if pd.yemmaIntroSeen ~= true then pd.yemmaIntroPending = true end

            DisplayTextToPlayer(Player(pid), 0, 0, "Maybe I should talk to the big man at the desk")

            local u = pd.hero or (PlayerHero and PlayerHero[pid])
            if ValidUnit(u) then SelectUnitAddForPlayer(u, Player(pid)) end

            pd.bootflow_active = false
            if ProcBus and ProcBus.Emit then
                ProcBus.Emit("OnBootflowFinished", { pid = pid, created = true })
            end
        end)
    end

    --------------------------------------------------
    -- Loading bar logic
    --------------------------------------------------
    local function mkBar(pid)
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local r = mkBackdrop(ui, PANEL_W, PANEL_H, BG_TEX)
        root[pid] = r
        BlzFrameSetPoint(r, FRAMEPOINT_CENTER, ui, FRAMEPOINT_CENTER, 0, 0)
        BlzFrameSetEnable(r, false)
        if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(r, true) end

        local fi = mkBackdrop(r, 0, 0.02, BAR_TEX)
        barFill[pid] = fi
        BlzFrameSetPoint(fi, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, PAD, -PAD)
        BlzFrameSetAlpha(fi, 230)
    end

    local function setProgress(pid, v)
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        if barFill[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetSize(barFill[pid], (PANEL_W - PAD * 2) * v, 0.02)
        end
    end

    local function startBar(pid)
        if timerBar[pid] then DestroyTimer(timerBar[pid]) end
        tAccum[pid] = 0
        barDone[pid] = false

        local pd = PD(pid)
        pd.bootflow_active = true
        if ProcBus and ProcBus.Emit then ProcBus.Emit("OnBootflowStart", { pid = pid }) end

        enterCine()
        timerBar[pid] = CreateTimer()
        TimerStart(timerBar[pid], TICK, true, function()
            tAccum[pid] = tAccum[pid] + TICK
            local v = tAccum[pid] / BAR_DURATION
            if v > 1 then v = 1 end
            setProgress(pid, v)
            if v >= 1 then
                DestroyTimer(timerBar[pid]); timerBar[pid] = nil
                barDone[pid] = true
                if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(root[pid], false) end
                exitCine()
            end
        end)
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function Bootflow.Show(pid)
        -- 1. Show loading bar
        mkBar(pid)
        startBar(pid)

        -- 2. After bar + 2 s delay, create button
        TimerStart(CreateTimer(), BAR_DURATION + EXTRA_DELAY, false, function()
            ensureUI(pid)
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(btn[pid], true)
            end
            DestroyTimer(GetExpiredTimer())
        end)
    end

    function Bootflow.Hide(pid)
        if timerBar[pid] then DestroyTimer(timerBar[pid]); timerBar[pid] = nil end
        if root[pid] and GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(root[pid], false) end
        if btn[pid] and GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(btn[pid], false) end
        barDone[pid] = false
        PD(pid).bootflow_active = false
        exitCine()
    end

    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                Bootflow.Show(pid)
            end
        end
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("Bootflow")
        end
    end)
end
