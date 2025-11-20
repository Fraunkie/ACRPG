if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_StatsModule.lua") end
--@@debug
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
    local TEX_BG_DARK  = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local PAD_OUT, PAD_IN, COL_GAP = 0.012, 0.005, 0.016
    local PANEL_W, PANEL_H, PANEL_H_TALL = 0.12, 0.12, 0.19
    local ROW_H, TITLE_H = 0.018, 0.020
    local GOLD_COLOR = "|cFFFFD700"
    local WHITE_COLOR = "|cFFFFFFFF"
    local GREEN_COLOR = "|cFF00FF00"
    local PURPLE_COLOR = "|cFF800080"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local UI = {}  -- UI[pid] = {root=frame, labels={labelName=frameRef}}

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
        local ref = UI[pid]
        if not ref or not ref.root then return end
        local pd  = getPD(pid)
        local u   = pd.hero
        local st  = getStats(pid)
        local hpCur, hpMax = 0, 0
        if u and GetUnitTypeId(u) ~= 0 then
            hpCur = math.floor(GetWidgetLife(u))
            hpMax = BlzGetUnitMaxHP(u) or 0
        end

        local function set(frame, txt)
            if frame and GetLocalPlayer() == Player(pid) then
                BlzFrameSetText(frame, txt or "")
            end
        end

        local L = ref.labels
        if not L then return end
        set(L["Power Lv"], GREEN_COLOR .. tostring(pd.stats.power or 0) .. "|r")
        set(L["Endurance"],GREEN_COLOR .. tostring(pd.stats.basestr or 0) .. "|r")
        set(L["Power"],GREEN_COLOR .. tostring(pd.stats.baseagi or 0) .. "|r")
        set(L["Ki"],GREEN_COLOR .. tostring(pd.stats.baseint or 0) .. "|r")
        set(L["Crit Chance"], GREEN_COLOR ..tostring(pd.combat.critChance or 0) .. "|r".."%%")
        set(L["Crit Multi"], GREEN_COLOR ..tostring(pd.combat.critMult or 0) .. "|r".."%%")
        set(L["Soul Energy"], GREEN_COLOR ..tostring(pd.soulEnergy or 0) .. "|r")
        set(L["DB Fragments"], GREEN_COLOR ..tostring(pd.fragmentsByKind.db or 0) .. "|r")
        set(L["Digi Fragments"], GREEN_COLOR ..tostring(pd.fragmentsByKind.digi or 0) .. "|r")
        set(L["Poke Fragments"], GREEN_COLOR ..tostring(pd.fragmentsByKind.poke or 0) .. "|r")
        set(L["Chakra Fragments"], GREEN_COLOR ..tostring(pd.fragmentsByKind.chakra or 0) .. "|r")
        set(L["Energy Bonus"],GREEN_COLOR..tostring(pd.combat.spellBonusPct or 0) .. "|r".."%%")
        set(L["Physical Bonus"],GREEN_COLOR..tostring(pd.combat.physicalBonusPct or 0) .. "|r".."%%")
        set(L["Armor"],GREEN_COLOR..tostring(pd.combat.armor or 0) .. "|r")
        set(L["Energy Resist"],GREEN_COLOR..tostring(pd.combat.energyResist or 0) .. "|r".."%%")
        set(L["Parry"],GREEN_COLOR..tostring(pd.combat.parry or 0) .. "|r".."%%")
        set(L["Block"],GREEN_COLOR..tostring(pd.combat.block or 0) .. "|r".."%%")
        set(L["Dodge"],GREEN_COLOR..tostring(pd.combat.dodge or 0) .. "|r".."%%")
        set(L["Physical Damage"],GREEN_COLOR..tostring(pd.stats.damage or 0) .. "|r")
        set(L["Energy Damage"],GREEN_COLOR..tostring(pd.combat.energyDamage or 0) .. "|r")
        set(L["Soul Xp Bonus"],GREEN_COLOR..tostring(pd.xpBonusPercent or 0) .. "|r".."%%")
    end
    local function rerenderAll(pid)

    end
    --------------------------------------------------
    -- Build
    --------------------------------------------------
    function PlayerMenu_StatsModule.ShowInto(pid, contentFrame)
    if UI[pid] then
      if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(UI[pid].root, true) end
      rerenderAll(pid)
      return
    end

    local ui = { root = contentFrame }
    local labels = {}
    UI[pid] = ui
    if GetLocalPlayer() == Player(pid) then BlzFrameSetVisible(contentFrame, true) end
    BlzFrameSetTexture(contentFrame, TEX_BG_DARK, 0, true)
    BlzFrameSetEnable(contentFrame, true) -- background only
    local inner = mkBackdrop(contentFrame, 0.001, 0.001, TEX_BG_LIGHT)
        BlzFrameSetPoint(inner, FRAMEPOINT_TOPLEFT, contentFrame, FRAMEPOINT_TOPLEFT, PAD_OUT, -PAD_OUT)
        BlzFrameSetPoint(inner, FRAMEPOINT_BOTTOMRIGHT, contentFrame, FRAMEPOINT_BOTTOMRIGHT, -PAD_OUT, PAD_OUT)

        local pd            = getPD(pid)
        local u             = pd.hero
        local name          = (u and (GetHeroProperName(u) or GetUnitName(u))) or "Unknown"
        local role          = pd.role or "None"
        local lvl           = pd.soulLevel or 1
        local pwrlvl        = pd.powerLevel or 0
        local zone          = pd.zone or "Unknown"
        local digi          = pd.fragmentsByKind.digi or 1
        local poke          = pd.fragmentsByKind.poke or 1
        local db            = pd.fragmentsByKind.db or 1
        local chakra        = pd.fragmentsByKind.chakra or 1

        local header = mkBackdrop(inner, 0.001, 0.048, TEX_BG_DARK)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPLEFT, inner, FRAMEPOINT_TOPLEFT, PAD_IN, -PAD_IN)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPRIGHT, inner, FRAMEPOINT_TOPRIGHT, -PAD_IN, -PAD_IN)
        local hdrLeft = mkText(header, "| Name: " ..PURPLE_COLOR.. name.."|r |")
        BlzFrameSetPoint(hdrLeft, FRAMEPOINT_LEFT, header, FRAMEPOINT_LEFT, PAD_IN, 0)
        local hdrRight = mkText(header, "| Soul Lv: " .. PURPLE_COLOR.. tostring(lvl)  .."|r |".. "    | Zone: " ..PURPLE_COLOR.. zone.."|r |", true)
        BlzFrameSetPoint(hdrRight, FRAMEPOINT_RIGHT, header, FRAMEPOINT_RIGHT, -PAD_IN, 0)

        local colL = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colL, FRAMEPOINT_TOPLEFT, header, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        local colR = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colR, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPRIGHT, COL_GAP, 0)

        -- Primary stats
        local pPrimary = mkBackdrop(colL, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pPrimary, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPLEFT, 0, 0)
        mkText(pPrimary, "Primary")
        local y = TITLE_H + 0.006
        for _, key in ipairs({"Power Lv","Endurance","Power","Ki", "Physical Damage", "Physical Bonus", "Energy Damage","Energy Bonus"}) do
            local l = mkText(pPrimary, GOLD_COLOR ..key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pPrimary, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pPrimary, GREEN_COLOR .."", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pPrimary, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        -- Resources
        local pRes = mkBackdrop(colR, PANEL_W, PANEL_H_TALL, TEX_BG_DARK)
        BlzFrameSetPoint(pRes, FRAMEPOINT_TOPLEFT, colR, FRAMEPOINT_TOPLEFT, 0, 0)
        mkText(pRes, "Primary")
        y = TITLE_H + 0.006
        for _, key in ipairs({"Crit Chance", "Crit Multi","Armor","Parry", "Block","Dodge", "Energy Resist", "Soul Xp Bonus"}) do
            local l = mkText(pRes, GOLD_COLOR ..key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pRes, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pRes, "", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pRes, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        -- Progression
        local pProg = mkBackdrop(colR, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pProg, FRAMEPOINT_TOPLEFT, pRes, FRAMEPOINT_BOTTOMLEFT, -0.14, -PAD_IN)
        mkText(pProg, "Currency")
        y = TITLE_H + 0.006
        for _, key in ipairs({"DB Fragments","Digi Fragments","Poke Fragments","Chakra Fragments"}) do
            local l = mkText(pProg, PURPLE_COLOR .. key)
            BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, pProg, FRAMEPOINT_TOPLEFT, PAD_IN, -y)
            local r = mkText(pProg, "", true)
            BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, pProg, FRAMEPOINT_TOPRIGHT, -PAD_IN, -y)
            labels[key] = r
            y = y + ROW_H
        end

        UI[pid] = { root = inner, labels = labels }
        PlayerMenu_StatsModule.Refresh(pid)
    end

    function PlayerMenu_StatsModule.Hide(pid)
        local ref = UI[pid]
        if not ref then return end
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(ref.root, false)
        end
        UI[pid] = nil
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
