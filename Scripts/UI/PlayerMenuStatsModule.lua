if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_StatsModule.lua") end
--==================================================
-- PlayerMenu_StatsModule.lua
-- WoW style character sheet inside PlayerMenu content.
-- Linked to StatSystem + PlayerData updates.
--==================================================

if not PlayerMenu_StatsModule then PlayerMenu_StatsModule = {} end
_G.PlayerMenu_StatsModule = PlayerMenu_StatsModule

do
    --------------------------------------------------
    -- Style constants
    --------------------------------------------------
    local TEX_BG_LIGHT = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BG_DARK  = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background"
    local PAD_OUT, PAD_IN, COL_GAP = 0.012, 0.010, 0.016
    local PANEL_W, PANEL_H, PANEL_H_TALL = 0.27, 0.16, 0.19
    local ROW_H, TITLE_H = 0.018, 0.020

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local INST = {}  -- INST[pid] = {root=frame, labels={labelName=frameRef}}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function mkBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end

    local function mkText(parent, s, justifyRight)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(
            t,
            justifyRight and TEXT_JUSTIFY_RIGHT or TEXT_JUSTIFY_LEFT,
            TEXT_JUSTIFY_MIDDLE
        )
        BlzFrameSetText(t, s or "")
        return t
    end

    local function getPD(pid)
        if _G.PlayerData and PlayerData.Get then return PlayerData.Get(pid) end
        _G.PLAYER_DATA = _G.PLAYER_DATA or {}
        _G.PLAYER_DATA[pid] = _G.PLAYER_DATA[pid] or {}
        return _G.PLAYER_DATA[pid]
    end

    local function getStats(pid)
        if _G.PlayerData and PlayerData.GetStats then
            return PlayerData.GetStats(pid)
        end
        local pd = getPD(pid)
        pd.stats = pd.stats or { power=0, defense=0, speed=0, crit=0 }
        return pd.stats
    end

    --------------------------------------------------
    -- Refresh logic
    --------------------------------------------------
    function PlayerMenu_StatsModule.Refresh(pid)
        local ref = INST[pid]
        if not ref or not ref.root then return end
        local pd  = getPD(pid)
        local u   = pd.hero
        local st  = getStats(pid)
        local hpCur, hpMax = 0, 0
        if u and GetUnitTypeId(u) ~= 0 then
            hpCur = math.floor(GetWidgetLife(u))
            hpMax = BlzGetUnitMaxHP(u) or 0
        end

        -- Update core stats (safe-check all)
        local function set(frame, txt)
            if frame and GetLocalPlayer() == Player(pid) then
                BlzFrameSetText(frame, txt or "")
            end
        end

        local L = ref.labels
        if not L then return end
        set(L["Power"],        tostring(st.power or 0))
        set(L["Defense"],      tostring(st.defense or 0))
        set(L["Speed"],        tostring(st.speed or 0))
        set(L["Crit Chance"],  tostring(st.crit or 0))
        set(L["Health"],       tostring(hpCur) .. " / " .. tostring(hpMax))
        set(L["Spirit Drive"], tostring(pd.spiritDrive or 0) .. " / 100")
        set(L["Soul Energy"],  tostring(pd.soulEnergy or 0))
        set(L["Fragments"],    tostring(pd.fragments or 0))
        set(L["Lives"],        tostring(pd.lives or 0))
    end

    --------------------------------------------------
    -- Build (unchanged layout)
    --------------------------------------------------
    function PlayerMenu_StatsModule.ShowInto(pid, contentFrame)
        -- destroy old
        if INST[pid] and INST[pid].root then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(INST[pid].root, false)
            end
            INST[pid] = nil
        end

        local labels = {}
        local inner = mkBackdrop(contentFrame, 0.001, 0.001, TEX_BG_LIGHT)
        BlzFrameSetPoint(inner, FRAMEPOINT_TOPLEFT, contentFrame, FRAMEPOINT_TOPLEFT, PAD_OUT, -PAD_OUT)
        BlzFrameSetPoint(inner, FRAMEPOINT_BOTTOMRIGHT, contentFrame, FRAMEPOINT_BOTTOMRIGHT, -PAD_OUT, PAD_OUT)

        local pd  = getPD(pid)
        local u   = pd.hero
        local name = GetHeroProperName(u) or GetUnitName(u) or "Unknown"
        local role = pd.role or "None"
        local lvl  = pd.soulLevel or 1
        local pwr  = pd.powerLevel or 0
        local zone = pd.zone or "Unknown"

        local header = mkBackdrop(inner, 0.001, 0.048, TEX_BG_DARK)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPLEFT, inner, FRAMEPOINT_TOPLEFT, PAD_IN, -PAD_IN)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPRIGHT, inner, FRAMEPOINT_TOPRIGHT, -PAD_IN, -PAD_IN)
        local hdrLeft = mkText(header, "Name: " .. name .. "   Role: " .. role)
        BlzFrameSetPoint(hdrLeft, FRAMEPOINT_LEFT, header, FRAMEPOINT_LEFT, PAD_IN, 0)
        local hdrRight = mkText(header, "Soul Lv " .. tostring(lvl) .. "   Power " .. tostring(pwr) .. "   Zone " .. zone, true)
        BlzFrameSetPoint(hdrRight, FRAMEPOINT_RIGHT, header, FRAMEPOINT_RIGHT, -PAD_IN, 0)

        local colL = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colL, FRAMEPOINT_TOPLEFT, header, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        local colR = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colR, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPRIGHT, COL_GAP, 0)

        -- Primary stats (linked labels)
        local pPrimary = mkBackdrop(colL, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pPrimary, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPLEFT, 0, 0)
        BlzFrameSetText(mkText(pPrimary, "Primary"), "Primary")
        local y = TITLE_H + 0.006
        for _, key in ipairs({"Power","Defense","Speed","Crit Chance"}) do
            local l = mkText(pPrimary, key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pPrimary, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pPrimary, "", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pPrimary, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        -- Resources panel (linked)
        local pRes = mkBackdrop(colR, PANEL_W, PANEL_H_TALL, TEX_BG_DARK)
        BlzFrameSetPoint(pRes, FRAMEPOINT_TOPLEFT, colR, FRAMEPOINT_TOPLEFT, 0, 0)
        BlzFrameSetText(mkText(pRes, "Resources"), "Resources")
        y = TITLE_H + 0.006
        for _, key in ipairs({"Health","Spirit Drive","Soul Energy","Fragments"}) do
            local l = mkText(pRes, key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pRes, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pRes, "", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pRes, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        -- Progression panel (linked)
        local pProg = mkBackdrop(colR, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pProg, FRAMEPOINT_TOPLEFT, pRes, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        BlzFrameSetText(mkText(pProg, "Progression"), "Progression")
        y = TITLE_H + 0.006
        for _, key in ipairs({"Lives"}) do
            local l = mkText(pProg, key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pProg, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pProg, "", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pProg, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        INST[pid] = { root = inner, labels = labels }
        PlayerMenu_StatsModule.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(inner, true)
        end
    end

    --------------------------------------------------
    -- Auto-refresh on stat events
    --------------------------------------------------
    OnInit.final(function()
        local function refreshEvent(payload)
            local pid = payload and payload.pid
            if pid ~= nil then
                PlayerMenu_StatsModule.Refresh(pid)
            end
        end
        if ProcBus and (ProcBus.Subscribe or ProcBus.On) then
            local on = ProcBus.Subscribe or ProcBus.On
            on("STAT_CHANGED", refreshEvent)
            on("STATS_RECALCULATED", refreshEvent)
            on("STATS_SNAPSHOT_READY", refreshEvent)
            on("SOUL_ENERGY_AWARDED", refreshEvent)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerMenu_StatsModule")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
