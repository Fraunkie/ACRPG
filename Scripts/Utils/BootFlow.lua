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

    -- keep a handle so fog modifiers don't get GC'd
    local fogMod = {}

    local function PD(pid)
        PlayerData = PlayerData or {}
        PlayerData[pid] = PlayerData[pid] or {}
        return PlayerData[pid]
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

    ----------------------------------------------------------------
    -- Robust hide for the inventory cover (multi-context safe)
    ----------------------------------------------------------------
    local function HideInventoryCoverSafely(pid)
        if GetLocalPlayer() ~= Player(pid) then return end
        local names = { "SimpleInventoryCover", "InventoryCover", "Inventory Cover" }
        for _, n in ipairs(names) do
            for ctx = 0, 7 do
                local c = BlzGetFrameByName(n, ctx)
                if c then
                    local dummy = BlzCreateFrameByType("FRAME", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI,0), "", 0)
                    BlzFrameSetParent(c, dummy)
                    BlzFrameClearAllPoints(c)
                    BlzFrameSetAbsPoint(c, FRAMEPOINT_CENTER, 1.5, -1.5)
                    BlzFrameSetSize(c, 0.0001, 0.0001)
                    BlzFrameSetAlpha(c, 0)
                    BlzFrameSetVisible(c, false)
                end
            end
        end
        BlzEnableUIAutoPosition(false)
    end

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

            if GetLocalPlayer() == Player(pid) then
                ClearTextMessages()
            end

            DisplayTextToPlayer(Player(pid), 0, 0,
            "Welcome to the Spirit Realm!\n\n" ..
            "• Speak with *King Yemma* at the desk to begin your first task.\n" ..
            "• Press **F** near a Hub Crystal to open the Travel Menu.\n" ..
            "• Press **L** to open your Player Menu (Stats, Inventory, Save).\n" ..
            "• Press **P** to toggle your DPS / Threat meter.\n\n" ..
            "Your journey starts here — prove your spirit’s strength and earn your way back to the living world!")

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

            -- Load the sky (per player), then convert black → gray fog, and add atmospheric fog
            if GetLocalPlayer() == Player(pid) then
                if SetSkyModel then
                    SetSkyModel("Environment\\Sky\\LordaeronSummerSky\\LordaeronSummerSky.mdx")
                end

                -- keep FoW systems enabled
                if FogMaskEnable then FogMaskEnable(true) end
                if FogEnable then FogEnable(true) end

                -- mark entire map as explored (gray fog instead of black)
                local r = GetPlayableMapRect()
                fogMod[pid] = CreateFogModifierRect(Player(pid), FOG_OF_WAR_FOGGED, r, true, false)
                FogModifierStart(fogMod[pid])

                -- gentle blue atmospheric fog from 1000 to 4000
                if SetTerrainFogColor then SetTerrainFogColor(140, 165, 205, 255) end
                if SetTerrainFogEx then SetTerrainFogEx(0, 1000.0, 4000.0, 1.0, 140, 165, 205) end
            end

            -- Remove the inventory cover reliably
            HideInventoryCoverSafely(pid)

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
                if GetLocalPlayer() == Player(pid) then
                    BlzHideOriginFrames(true) 
                    BlzFrameSetSize(BlzGetFrameByName("ConsoleUIBackdrop",0), 0, 0.0001)
                    BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_HERO_BAR,0), false)
                    BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP,0), false)
                    BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_COMMAND_BUTTON, 0), false)
                    BlzFrameSetVisible(BlzGetFrameByName("ResourceBarFrame",0), false)
                    BlzFrameSetVisible(BlzGetFrameByName("UpperButtonBarFrame",0), false)
                    BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0), false)
                    BlzFrameSetVisible(BlzGetOriginFrame(ORIGIN_FRAME_CHAT_MSG, 0), false)
                    BlzFrameSetVisible(BlzGetFrameByName("SimpleInfoPanelIconHeroText", 6), false)
                    BlzFrameSetSize(BlzGetFrameByName("InfoPanelIconHeroIcon", 6), 0.00001, 0.00001)
                    BlzFrameSetSize(BlzGetFrameByName("SimpleInfoPanelIconHero", 6), 0.00001, 0.00001)
                    BlzFrameSetSize(BlzGetFrameByName("InfoPanelIconBackdrop", 6), 0.00001, 0.00001)
                    BlzFrameSetScale(BlzGetOriginFrame(ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR_LABEL, 0), 0.00001)
                    BlzFrameSetScale(BlzGetOriginFrame(ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR, 0), 0.00001)
                    -- Shrink leftover info panel elements safely
                    BlzFrameSetScale(BlzGetFrameByName("SimpleHeroLevelBar", 0), 0.0001)
                                        -- Reposition the Buff bar
                    handle = BlzGetOriginFrame(ORIGIN_FRAME_UNIT_PANEL_BUFF_BAR, 0)
                    BlzFrameSetAbsPoint(handle, FRAMEPOINT_TOPLEFT, -0.123456, -0.045000)
                    BlzFrameSetAbsPoint(handle, FRAMEPOINT_BOTTOMRIGHT, -0.482620, -0.100000)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleNameValue", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconDamage", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconDamageValue", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconArmor", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconArmorValue", 0), 0.0001)
                    -- Hide Armor icon/value
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconArmor", 2), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelIconArmorValue", 2), 0.0001)

                    -- Hide Hero Level bar text (XP / name)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleHeroLevelBar", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleNameValue", 0), 0.0001)
                    -- hide the inventory title ("Inventory")
                    BlzFrameSetScale(BlzGetFrameByName("InventoryText", 0), 0.0001)

                    -- hide the hero name + the grey class line that appears beside it
                    BlzFrameSetScale(BlzGetFrameByName("SimpleNameValue", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleClassValue", 0), 0.0001)

                    -- hide the XP/level bar under the name
                    BlzFrameSetScale(BlzGetFrameByName("SimpleHeroLevelBar", 0), 0.0001)

                    -- HIDE ARMOR block (icon, value, label)
                    -- note: “armor” is index 2 of the generic InfoPanel icon rows
                    BlzFrameSetScale(BlzGetFrameByName("InfoPanelIconValue",    2), 0.0001)
                   BlzFrameSetScale(BlzGetFrameByName("InfoPanelIconLabel",    2), 0.0001)



                    -- Hide native WC3 inventory (covers all 6 slots)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_0", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_1", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_2", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_3", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_4", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("InventoryButton_5", 0), 0.0001)

                    -- hide command buttons 
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_0", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_1", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_2", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_3", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_4", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_5", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_6", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_7", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_8", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_9", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_10", 0), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("CommandButton_11", 0), 0.0001)

                    -- Hide item info panel (center)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleItemNameValue", 3), 0.0001)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleItemDescriptionValue", 3), 0.0001)  
                    -- Hide unit info panel (center)
                    BlzFrameSetScale(BlzGetFrameByName("SimpleInfoPanelUnitDetail", 0), 0.0001)
                    --hide whole bottom info panel
                    BlzFrameSetScale(BlzGetFrameByName("InfoPanel", 0), 0.0001)


                    -- Portrait (top-left corner, keep current size)
                    local ui     = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
                    local handle = BlzGetOriginFrame(ORIGIN_FRAME_PORTRAIT, 0)

                    BlzEnableUIAutoPosition(false)
                    BlzFrameSetVisible(handle, true)

                    -- keep its current size
                    local w = BlzFrameGetWidth(handle)
                    local h = BlzFrameGetHeight(handle)

                    BlzFrameClearAllPoints(handle)
                    BlzFrameSetPoint(handle, FRAMEPOINT_TOPLEFT, ui, FRAMEPOINT_TOPLEFT, 0.012, -0.012) -- tweak padding as desired
                    BlzFrameSetSize(handle, w, h)

                    handle = nil


                    BlzFrameSetAlpha( BlzGetFrameByName("SimpleInventoryCover", 0), 0)
                    BlzFrameSetVisible(BlzFrameGetChild(BlzGetFrameByName("ConsoleUI", 0), 5), false)
                    if CommandUIKiller and CommandUIKiller.Apply then
                        CommandUIKiller.Apply(pid)
                    end
                    BlzEnableUIAutoPosition(false)
                end
                Bootflow.Show(pid)
            end
        end
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("Bootflow")
        end
    end)
end
