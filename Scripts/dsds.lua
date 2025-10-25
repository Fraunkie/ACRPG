
--BlzHideOriginFrames(true) 
--BlzFrameSetSize(BlzGetFrameByName("ConsoleUIBackdrop",0), 0, 0.0001)
--BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_HERO_BAR,0), false)
--BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP,0), false)
--BlzFrameSetVisible(BlzGetFrameByName("ResourceBarFrame",0), false)
--BlzFrameSetVisible(BlzGetFrameByName("UpperButtonBarFrame",0), false)
--BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0), false)
--BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_CHAT_MSG, 0), false)

if not Bootflow then Bootflow = {} end
_G.Bootflow = Bootflow

do
    local GB = GameBalance or {}
    local BG_TEX  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local BAR_TEX = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-slider"
    local BTN_TEX = "UI\\Widgets\\Console\\Human\\human-inventory-slotfiller"

    local BAR_DURATION = (GB.STARTUI and GB.STARTUI.BAR_DURATION) or 3.50
    local EXTRA_DELAY  = 2.00
    local TICK         = 0.03
    local PANEL_W, PANEL_H, PAD = 0.44, 0.11, 0.010

    local root, barFill, btn = {}, {}, {}
    local tAccum, barDone = {}, {}
    local timerBar = {}
    local fogMod = {}

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

    -- helpers to safely hide/move stock UI bits
    local function MoveOffscreenFrame(f)
        if f then
            BlzFrameClearAllPoints(f)
            BlzFrameSetAbsPoint(f, FRAMEPOINT_TOPLEFT, 999.0, 999.0)
            BlzFrameSetAbsPoint(f, FRAMEPOINT_BOTTOMRIGHT, 999.0, 999.0)
        end
    end
    local function MoveOffscreenByName(name, ctx) MoveOffscreenFrame(BlzGetFrameByName(name, ctx or 0)) end
    local function ShrinkByName(name, ctx)
        local f = BlzGetFrameByName(name, ctx or 0)
        if f then BlzFrameSetScale(f, 0.0001) end
    end
    local function ZeroAlphaByName(name, ctx)
        local f = BlzGetFrameByName(name, ctx or 0)
        if f then BlzFrameSetAlpha(f, 0) end
    end

    local function HideCommandButtons()
        for i = 0, 11 do MoveOffscreenByName("CommandButton_" .. i, 0) end
    end

    local function HideInfoPanelStuff()
        ZeroAlphaByName("SimpleInventoryCover", 0)
        ZeroAlphaByName("Inventory Cover", 0)
        ZeroAlphaByName("InventoryCover", 0)

        ShrinkByName("SimpleNameValue", 0)
        ShrinkByName("SimpleClassValue", 0)
        ShrinkByName("SimpleItemNameValue", 3)
        ShrinkByName("SimpleItemDescriptionValue", 3)
        ShrinkByName("SimpleDestructableNameValue", 4)
        ShrinkByName("SimpleBuildingNameValue", 1)
        ShrinkByName("SimpleBuildingActionLabel", 1)
        ShrinkByName("SimpleHoldNameValue", 2)
        ShrinkByName("SimpleHoldDescriptionNameValue", 2)

        ShrinkByName("InfoPanelIconHeroStrengthLabel", 6)
        ShrinkByName("InfoPanelIconHeroAgilityLabel", 6)
        ShrinkByName("InfoPanelIconHeroIntellectLabel", 6)

        local lbl = BlzGetOriginFrame(ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR_LABEL, 0)
        if lbl then BlzFrameSetScale(lbl, 0.0001) end
    end

    local function RepositionPortrait()
        local gui   = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        local portr = BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0)
        if portr and gui then
            BlzFrameClearAllPoints(portr)
            BlzFrameSetPoint(portr, FRAMEPOINT_TOPLEFT, gui, FRAMEPOINT_TOPLEFT, 0.018, -0.018)
            BlzFrameSetSize(portr, 0.16, 0.16)
            BlzFrameSetVisible(portr, true)
        end
    end

    local function DoUISurgeryOnce(pid)
        if GetLocalPlayer() ~= Player(pid) then return false end
        if not BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0) then return false end
        if not BlzGetFrameByName("CommandButton_0", 0) then return false end

        local upper = BlzGetFrameByName("UpperButtonBarFrame", 0)
        if upper then BlzFrameSetVisible(upper, false) end
        local resBar = BlzGetFrameByName("ResourceBarFrame", 0)
        if resBar then BlzFrameSetVisible(resBar, false) end

        HideCommandButtons()
        HideInfoPanelStuff()
        RepositionPortrait()
        BlzEnableUIAutoPosition(false)
        return true
    end

    -- ===== Bootflow UI =====
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

            if GetLocalPlayer() == Player(pid) then ClearTextMessages() end
            DisplayTextToPlayer(Player(pid), 0, 0,
                "Welcome to the Spirit Realm!\n\n" ..
                "• Talk to King Yemma to begin.\n" ..
                "• F = Travel Menu near a Hub Crystal.\n" ..
                "• L = Player Menu.  P = DPS/Threat meter.")

            local u = pd.hero or (PlayerHero and PlayerHero[pid])
            if ValidUnit(u) then SelectUnitAddForPlayer(u, Player(pid)) end

            pd.bootflow_active = false
            if ProcBus and ProcBus.Emit then
                ProcBus.Emit("OnBootflowFinished", { pid = pid, created = true })
            end
        end)
    end

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
            BlzFrameSetSize(barFill[pid], (PANEL_W - PAD * 2) * v, 0.02) -- fixed line
        end
    end

    -- fixed: no 'private' keyword in Lua
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

    function Bootflow.Show(pid)
        mkBar(pid)
        startBar(pid)
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
        if SetSkyModel then
            SetSkyModel("Environment\\Sky\\LordaeronSummerSky\\LordaeronSummerSky.mdx")
        end

        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    -- soft distant fog; guarded so the linter stops whining
                    if FogMaskEnable then FogMaskEnable(true) end
                    if FogEnable then FogEnable(true) end
                    local r = GetPlayableMapRect()
                    fogMod[pid] = CreateFogModifierRect(Player(pid), FOG_OF_WAR_FOGGED, r, true, false)
                    FogModifierStart(fogMod[pid])
                    if SetTerrainFogColor then SetTerrainFogColor(140,165,205,255) end
                    if SetTerrainFogEx then SetTerrainFogEx(0, 1000.0, 4000.0, 0.0, 140,165,205) end

                    -- apply UI surgery once frames exist
                    local poll = CreateTimer()
                    TimerStart(poll, 0.05, true, function()
                        if DoUISurgeryOnce(pid) then
                            DestroyTimer(poll)
                        end
                    end)
                end
                Bootflow.Show(pid)
            end
        end

        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("Bootflow")
        end
    end)
end

