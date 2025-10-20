if Debug and Debug.beginFile then Debug.beginFile("PlayerMenu_StatsModule.lua") end
--==================================================
-- PlayerMenu_StatsModule.lua
-- WoW style character sheet inside PlayerMenu content.
-- Call: PlayerMenu_StatsModule.ShowInto(pid, contentFrame)
--==================================================

if not PlayerMenu_StatsModule then PlayerMenu_StatsModule = {} end
_G.PlayerMenu_StatsModule = PlayerMenu_StatsModule

do
    --------------------------------------------------
    -- Style
    --------------------------------------------------
    local TEX_BG_LIGHT = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_BG_DARK  = "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background"

    local PAD_OUT   = 0.012
    local PAD_IN    = 0.010
    local COL_GAP   = 0.016

    local PANEL_W   = 0.27
    local PANEL_H   = 0.16
    local PANEL_H_TALL = 0.19

    local ROW_H     = 0.018
    local TITLE_H   = 0.020

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local INST = {}  -- INST[pid] = {root=...}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function mkBackdrop(parent, w, h, tex)
        local f = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)
        BlzFrameSetSize(f, w, h)
        BlzFrameSetTexture(f, tex, 0, true)
        return f
    end

    local function mkText(parent, s)
        local t = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, s or "")
        return t
    end

    local function mkTitle(parent, label)
        local t = mkText(parent, label or "")
        BlzFrameSetPoint(t, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, PAD_IN, -PAD_IN)
        return t
    end

    local function addRow(parent, yFromTop, leftLabel, rightValue)
        -- left label
        local l = mkText(parent, leftLabel or "")
        BlzFrameSetPoint(l, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, PAD_IN, -yFromTop)
        -- right value
        local r = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        BlzFrameSetTextAlignment(r, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(r, FRAMEPOINT_TOPRIGHT, parent, FRAMEPOINT_TOPRIGHT, -PAD_IN, -yFromTop)
        BlzFrameSetText(r, rightValue or "")
        return l, r
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

    local function getNameAndRole(u, pid)
        local name = "Unknown"
        if u and GetUnitTypeId(u) ~= 0 then
            name = GetHeroProperName(u)
            if name == nil or name == "" then
                name = GetUnitName(u)
            end
        end
        local role = "None"
        local pd = getPD(pid)
        if pd.role and pd.role ~= "" then role = pd.role end
        return name, role
    end

    local function destroyOld(pid)
        local old = INST[pid]
        if old and old.root then
            if GetLocalPlayer() == Player(pid) then
                BlzFrameSetVisible(old.root, false)
            end
            INST[pid] = nil
        end
    end

    --------------------------------------------------
    -- Build
    --------------------------------------------------
    function PlayerMenu_StatsModule.ShowInto(pid, contentFrame)
        destroyOld(pid)

        -- inner canvas with light rim
        local inner = mkBackdrop(contentFrame, 0.001, 0.001, TEX_BG_LIGHT)
        BlzFrameSetPoint(inner, FRAMEPOINT_TOPLEFT, contentFrame, FRAMEPOINT_TOPLEFT, PAD_OUT, -PAD_OUT)
        BlzFrameSetPoint(inner, FRAMEPOINT_BOTTOMRIGHT, contentFrame, FRAMEPOINT_BOTTOMRIGHT, -PAD_OUT, PAD_OUT)

        -- header strip
        local header = mkBackdrop(inner, 0.001, 0.048, TEX_BG_DARK)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPLEFT, inner, FRAMEPOINT_TOPLEFT, PAD_IN, -PAD_IN)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPRIGHT, inner, FRAMEPOINT_TOPRIGHT, -PAD_IN, -PAD_IN)

        local pd  = getPD(pid)
        local u   = pd.hero
        local name, role = getNameAndRole(u, pid)
        local lvl = pd.soulLevel or 1
        local pwr = pd.powerLevel or 0
        local zone= pd.zone or "Unknown"

        local hdrLeft = mkText(header, "Name: " .. name .. "   Role: " .. role)
        BlzFrameSetPoint(hdrLeft, FRAMEPOINT_LEFT, header, FRAMEPOINT_LEFT, PAD_IN, 0)

        local hdrRight = BlzCreateFrameByType("TEXT", "", header, "", 0)
        BlzFrameSetTextAlignment(hdrRight, TEXT_JUSTIFY_RIGHT, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetPoint(hdrRight, FRAMEPOINT_RIGHT, header, FRAMEPOINT_RIGHT, -PAD_IN, 0)
        BlzFrameSetText(hdrRight, "Soul Lv " .. tostring(lvl) .. "   Power " .. tostring(pwr) .. "   Zone " .. zone)

        -- columns anchors
        local colL = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colL, FRAMEPOINT_TOPLEFT, header, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)

        local colR = mkBackdrop(inner, PANEL_W, 0.001, TEX_BG_DARK)
        BlzFrameSetPoint(colR, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPRIGHT, COL_GAP, 0)

        -- panels left
        local pPrimary = mkBackdrop(colL, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pPrimary, FRAMEPOINT_TOPLEFT, colL, FRAMEPOINT_TOPLEFT, 0, 0)
        mkTitle(pPrimary, "Primary")

        local st = getStats(pid)
        local y = TITLE_H + 0.006
        addRow(pPrimary, y, "Power",   tostring(st.power or 0));   y = y + ROW_H
        addRow(pPrimary, y, "Defense", tostring(st.defense or 0)); y = y + ROW_H
        addRow(pPrimary, y, "Speed",   tostring(st.speed or 0));   y = y + ROW_H
        addRow(pPrimary, y, "Crit Chance", tostring(st.crit or 0)); y = y + ROW_H

        local pOff = mkBackdrop(colL, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pOff, FRAMEPOINT_TOPLEFT, pPrimary, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        mkTitle(pOff, "Offensive")
        y = TITLE_H + 0.006
        addRow(pOff, y, "Attack Damage", "min max"); y = y + ROW_H
        addRow(pOff, y, "Attack Speed",  "value");   y = y + ROW_H
        addRow(pOff, y, "Energy Bonus",  "value");   y = y + ROW_H
        addRow(pOff, y, "Crit Damage",   "value")

        local pDef = mkBackdrop(colL, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pDef, FRAMEPOINT_TOPLEFT, pOff, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        mkTitle(pDef, "Defensive")
        y = TITLE_H + 0.006
        addRow(pDef, y, "Armor",            "value"); y = y + ROW_H
        addRow(pDef, y, "Physical Reduce",  "value"); y = y + ROW_H
        addRow(pDef, y, "Energy Resist",    "value"); y = y + ROW_H
        addRow(pDef, y, "Dodge Chance",     "value")

        -- panels right
        local pRes = mkBackdrop(colR, PANEL_W, PANEL_H_TALL, TEX_BG_DARK)
        BlzFrameSetPoint(pRes, FRAMEPOINT_TOPLEFT, colR, FRAMEPOINT_TOPLEFT, 0, 0)
        mkTitle(pRes, "Resources")
        y = TITLE_H + 0.006
        local hpCur, hpMax = 0, 0
        if u and GetUnitTypeId(u) ~= 0 then
            hpCur = math.floor(GetWidgetLife(u))
            hpMax = BlzGetUnitMaxHP(u) or 0
        end
        addRow(pRes, y, "Health", tostring(hpCur) .. " / " .. tostring(hpMax)); y = y + ROW_H
        addRow(pRes, y, "Spirit Drive", tostring(pd.spiritDrive or 0) .. " / 100"); y = y + ROW_H
        addRow(pRes, y, "Soul Energy",  tostring(pd.soulEnergy or 0)); y = y + ROW_H
        addRow(pRes, y, "Fragments",    tostring(pd.fragments or 0))

        local pProg = mkBackdrop(colR, PANEL_W, PANEL_H, TEX_BG_DARK)
        BlzFrameSetPoint(pProg, FRAMEPOINT_TOPLEFT, pRes, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
        mkTitle(pProg, "Progression")
        y = TITLE_H + 0.006
        addRow(pProg, y, "Lives", tostring((pd.lives or 0)) ); y = y + ROW_H
        addRow(pProg, y, "Shard Equipped", "none"); y = y + ROW_H
        addRow(pProg, y, "Teleport Unlocked", "Yemma"); y = y + ROW_H
        addRow(pProg, y, "Task", (pd.hfilTask and pd.hfilTask.name) or "None")

        -- optional dev panel
        if rawget(_G, "DevMode") and type(DevMode.IsOn) == "function" and DevMode.IsOn() then
            local pDev = mkBackdrop(colR, PANEL_W, PANEL_H, TEX_BG_DARK)
            BlzFrameSetPoint(pDev, FRAMEPOINT_TOPLEFT, pProg, FRAMEPOINT_BOTTOMLEFT, 0, -PAD_IN)
            mkTitle(pDev, "Dev")
            y = TITLE_H + 0.006
            addRow(pDev, y, "Threat", "value"); y = y + ROW_H
            addRow(pDev, y, "DPS 5s", "value"); y = y + ROW_H
            addRow(pDev, y, "Last Damage", "value")
        end

        INST[pid] = { root = inner }
        if GetLocalPlayer() == Player(pid) then
            BlzFrameSetVisible(inner, true)
        end
    end
end

if Debug and Debug.endFile then Debug.endFile() end
