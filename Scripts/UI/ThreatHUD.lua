if Debug and Debug.beginFile then Debug.beginFile("CombatThreatHUD.lua") end
--==================================================
-- CombatThreatHUD.lua
-- Minimal on-screen threat readout for each player.
-- • Tracks the player's "current target" from ProcBus:
--   - when you damage a unit, that unit becomes your target
--   - when you are damaged, the source becomes your target
-- • Shows: Target name, Your Threat, Top Threat, % of top.
-- • Toggle: Chat "-thud" (via ChatTriggerRegistry) or key P.
-- • Editor-safe (no FourCC at top-level).
--==================================================

if not CombatThreatHUD then CombatThreatHUD = {} end
_G.CombatThreatHUD = CombatThreatHUD

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local POS_X        = 0.78   -- top-right-ish
    local POS_Y        = 0.56
    local PANEL_W      = 0.20
    local PANEL_H      = 0.06
    local PAD          = 0.006
    local BAR_H        = 0.010
    local BG           = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local BAR_TEX      = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TICK_SEC     = 0.20

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- per-player
    local root   = {}   -- frame
    local title  = {}   -- text: target name
    local line1  = {}   -- text: your threat and %
    local barBG  = {}   -- frame
    local barFG  = {}   -- frame (width scaled by your% vs top)
    local visible= {}   -- bool
    local lastTarget = {} -- unit (tracked from events)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprintf(s)
        if Debug and Debug.printf then Debug.printf("[THUD] " .. tostring(s)) end
    end

    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function PD(pid)
        if _G.PlayerData and PlayerData.Get then return PlayerData.Get(pid) end
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end
    local function getHero(pid)
        local pd = PD(pid)
        if pd.hero and valid(pd.hero) then return pd.hero end
        if _G.PlayerHero and valid(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    local function clamp01(x)
        if x < 0 then return 0 end
        if x > 1 then return 1 end
        return x
    end

    --------------------------------------------------
    -- UI build
    --------------------------------------------------
    local function ensureFrames(pid)
        if root[pid] then return end
        local ui = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)

        local r = BlzCreateFrameByType("BACKDROP", "THUD_Root_"..pid, ui, "", 0)
        root[pid] = r
        BlzFrameSetSize(r, PANEL_W, PANEL_H)
        BlzFrameSetAbsPoint(r, FRAMEPOINT_TOPRIGHT, POS_X, POS_Y)
        BlzFrameSetTexture(r, BG, 0, true)
        BlzFrameSetVisible(r, false)

        local t0 = BlzCreateFrameByType("TEXT", "THUD_Title_"..pid, r, "", 0)
        title[pid] = t0
        BlzFrameSetPoint(t0, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, PAD, -PAD)
        BlzFrameSetTextAlignment(t0, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
        BlzFrameSetText(t0, "Target: none")

        local t1 = BlzCreateFrameByType("TEXT", "THUD_Line1_"..pid, r, "", 0)
        line1[pid] = t1
        BlzFrameSetPoint(t1, FRAMEPOINT_LEFT, r, FRAMEPOINT_LEFT, PAD, -0.028)
        BlzFrameSetTextAlignment(t1, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t1, "You: 0 / Top: 0 (0%)")

        local bbg = BlzCreateFrameByType("BACKDROP", "THUD_BarBG_"..pid, r, "", 0)
        barBG[pid] = bbg
        BlzFrameSetSize(bbg, PANEL_W - PAD*2, BAR_H)
        BlzFrameSetPoint(bbg, FRAMEPOINT_BOTTOMLEFT, r, FRAMEPOINT_BOTTOMLEFT, PAD, PAD)
        BlzFrameSetTexture(bbg, BG, 0, true)

        local bfg = BlzCreateFrameByType("BACKDROP", "THUD_BarFG_"..pid, bbg, "", 0)
        barFG[pid] = bfg
        BlzFrameSetSize(bfg, 0.001, BAR_H) -- start tiny
        BlzFrameSetPoint(bfg, FRAMEPOINT_LEFT, bbg, FRAMEPOINT_LEFT, 0.0, 0.0)
        BlzFrameSetTexture(bfg, BAR_TEX, 0, true)

        -- respect local visibility
        if GetLocalPlayer() ~= Player(pid) then
            BlzFrameSetVisible(r, false)
        end
    end

    local function show(pid)
        ensureFrames(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], true)
        end
        visible[pid] = true
    end

    local function hide(pid)
        if root[pid] and GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(root[pid], false)
        end
        visible[pid] = false
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function CombatThreatHUD.Show(pid) show(pid) end
    function CombatThreatHUD.Hide(pid) hide(pid) end
    function CombatThreatHUD.Toggle(pid)
        if visible[pid] then hide(pid) else show(pid) end
    end
    CombatThreatHUD.visible = visible

    --------------------------------------------------
    -- Threat math (uses ThreatSystem APIs we added)
    --------------------------------------------------
    local function getThreatForUnit(source, target)
        if not _G.ThreatSystem or not ThreatSystem.GetThreat then return 0 end
        return ThreatSystem.GetThreat(source, target) or 0
    end

    local function getTopThreatForTarget(target)
        if not _G.ThreatSystem then return nil, 0 end
        if not ThreatSystem.GetTopSourceHandle or not ThreatSystem.GetThreatByHandle then return nil, 0 end
        local handle, val = ThreatSystem.GetTopSourceHandle(target)
        if not handle then return nil, 0 end
        local top = ThreatSystem.GetThreatByHandle(handle, target) or (val or 0)
        return handle, top
    end

    --------------------------------------------------
    -- Update per player
    --------------------------------------------------
    local function updateOne(pid)
        if not visible[pid] then return end
        ensureFrames(pid)

        local tgt = lastTarget[pid]
        if not valid(tgt) then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetText(title[pid], "Target: none")
                BlzFrameSetText(line1[pid],  "You: 0 / Top: 0 (0%)")
                BlzFrameSetSize(barFG[pid], 0.001, BAR_H)
            end
            return
        end

        local hero = getHero(pid)
        local your = (valid(hero) and getThreatForUnit(hero, tgt)) or 0
        local _, top = getTopThreatForTarget(tgt)
        if top < your then top = your end
        local pct = (top > 0) and math.floor((your / top) * 100 + 0.5) or 0

        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetText(title[pid], "Target: " .. GetUnitName(tgt))
            BlzFrameSetText(line1[pid],  "You: " .. tostring(your) .. " / Top: " .. tostring(top) .. " (" .. tostring(pct) .. " percent)")
            local maxW = PANEL_W - PAD*2
            local w = maxW * clamp01((top > 0) and (your / top) or 0)
            BlzFrameSetSize(barFG[pid], math.max(0.001, w), BAR_H)
        end
    end

    --------------------------------------------------
    -- Wiring: track "current target" from combat events
    --------------------------------------------------
    local function onDealtDamage(e)
        if not e then return end
        local src, tgt, pid = e.source, e.target, e.pid
        if pid ~= nil and valid(tgt) then
            lastTarget[pid] = tgt
        end
    end

    local function onDamagedYou(e)
        if not e then return end
        local src, tgt = e.source, e.target
        if not valid(src) or not valid(tgt) then return end
        local p = GetOwningPlayer(tgt)
        if not p then return end
        local pid = GetPlayerId(p)
        lastTarget[pid] = src
    end

    --------------------------------------------------
    -- Key binding: P to toggle
    --------------------------------------------------
    local function bindKeyP(pid)
        local trig = CreateTrigger()
        BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_P, 0, true)
        TriggerAddAction(trig, function()
            CombatThreatHUD.Toggle(GetPlayerId(GetTriggerPlayer()))
        end)
    end

    --------------------------------------------------
    -- Ticker
    --------------------------------------------------
    local function tick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            updateOne(pid)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- Build frames and default hidden
        for pid = 0, bj_MAX_PLAYERS - 1 do
            ensureFrames(pid)
            hide(pid)
            bindKeyP(pid)
        end

        -- Wire ProcBus (from CombatEventsBridge / DamageEngine)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDealtDamage)
            PB.On("OnDamaged",     onDamagedYou)   -- optional if you emit this; safe if never fired
        end

        -- Periodic refresh
        local t = CreateTimer()
        TimerStart(t, TICK_SEC, true, tick)

        dprintf("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatThreatHUD")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
