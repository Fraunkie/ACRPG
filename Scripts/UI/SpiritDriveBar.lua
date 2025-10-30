if Debug and Debug.beginFile then Debug.beginFile("CustomSpiritDriveBar.lua") end
--==================================================
-- CustomSpiritDriveBar.lua
-- Purple Spirit Drive bar (WORLD_FRAME)
--  • Half size of HP bar
--  • Positioned above HP bar
--  • Default max 100
--  • Shows orange "XX / MAX"
--  • Exposes Set(pid, current, max) for external updates
--==================================================

if not CustomSpiritDriveBar then CustomSpiritDriveBar = {} end
_G.CustomSpiritDriveBar = CustomSpiritDriveBar

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local BAR_W        = 0.11
    local BAR_H        = 0.015
    local FILL_PAD     = 0.004
    local BOTTOM_Y     = 0.105
    local LEVEL        = 13

    local TEXT_SCALE   = 0.85
    local POLL_DT      = 0.05
    local SD_MAX_DEF   = 100

    local TEX_BACK     = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_FILL     = "ReplaceableTextures\\TeamColor\\TeamColor15" -- purple

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root, back, bar, label = {}, {}, {}, {}
    local curVal, maxVal = {}, {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function uiWorld() return BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0) end
    local function uiRoot()  return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

    -- Try multiple schemas/APIs so we don't get stuck at 0
    local function readSpiritDrive(pid)
        -- Preferred: dedicated module function
        if _G.SpiritDrive then
            if type(SpiritDrive.Get) == "function" then
                local ok, v = pcall(SpiritDrive.Get, pid)
                if ok and type(v) == "number" then return v end
            end
            if type(SpiritDrive.GetCurrent) == "function" then
                local ok, v = pcall(SpiritDrive.GetCurrent, pid)
                if ok and type(v) == "number" then return v end
            end
        end
        -- PlayerData helpers
        if _G.PlayerData then
            if type(PlayerData.GetSpiritDrive) == "function" then
                local ok, v = pcall(PlayerData.GetSpiritDrive, pid)
                if ok and type(v) == "number" then return v end
            end
            local pd = PlayerData[pid]
            if pd then
                if type(pd.spiritDrive) == "number" then return pd.spiritDrive end
                if type(pd.SpiritDrive) == "table" and type(pd.SpiritDrive.value) == "number" then
                    return pd.SpiritDrive.value
                end
            end
        end
        -- Raw mirror
        if _G.PLAYER_DATA and PLAYER_DATA[pid] then
            local pd = PLAYER_DATA[pid]
            if type(pd.spiritDrive) == "number" then return pd.spiritDrive end
            if type(pd.SpiritDrive) == "table" and type(pd.SpiritDrive.value) == "number" then
                return pd.SpiritDrive.value
            end
        end
        return 0
    end

    local function ensure(pid)
        if root[pid] then return end
        local parent = uiWorld()

        local r = BlzCreateFrameByType("FRAME", "SDRoot"..pid, parent, "", 0)
        root[pid] = r
        BlzFrameSetLevel(r, LEVEL)
        BlzFrameSetSize(r, BAR_W, BAR_H)
        BlzFrameSetPoint(r, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, 0.0, BOTTOM_Y)

        local bg = BlzCreateFrameByType("BACKDROP", "SDBack"..pid, r, "", 0)
        back[pid] = bg
        BlzFrameSetAllPoints(bg, r)
        BlzFrameSetTexture(bg, TEX_BACK, 0, true)
        BlzFrameSetAlpha(bg, 180)

        local sb = BlzCreateFrameByType("SIMPLESTATUSBAR", "SDFill"..pid, r, "", 0)
        bar[pid] = sb
        BlzFrameSetPoint(sb, FRAMEPOINT_TOPLEFT,     r, FRAMEPOINT_TOPLEFT,     FILL_PAD, -FILL_PAD)
        BlzFrameSetPoint(sb, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -FILL_PAD,  FILL_PAD)
        BlzFrameSetTexture(sb, TEX_FILL, 0, false)
        BlzFrameSetMinMaxValue(sb, 0, SD_MAX_DEF)
        BlzFrameSetValue(sb, 0)

        local t = BlzCreateFrameByType("TEXT", "SDText"..pid, uiRoot(), "", 0)
        label[pid] = t
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetScale(t, TEXT_SCALE)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, "|cffffaa000 / " .. tostring(SD_MAX_DEF) .. "|r")

        curVal[pid] = 0
        maxVal[pid] = SD_MAX_DEF
    end

    local function apply(pid, cur, mx)
        cur = math.max(0, math.floor(cur or 0))
        mx  = math.max(1, math.floor(mx or SD_MAX_DEF))
        curVal[pid], maxVal[pid] = cur, mx

        if bar[pid] then
            -- Only touch min/max when needed
            if mx ~= maxVal[pid] then
                BlzFrameSetMinMaxValue(bar[pid], 0, mx)
            else
                BlzFrameSetMinMaxValue(bar[pid], 0, mx)
            end
            BlzFrameSetValue(bar[pid], cur)
        end
        if label[pid] then
            BlzFrameSetText(label[pid], "|cffffaa00" .. tostring(cur) .. " / " .. tostring(mx) .. "|r")
        end
    end

    local function poll(pid)
        -- Keep polling so it still updates even if no events fire
        local cur = readSpiritDrive(pid)
        local mx  = maxVal[pid] or SD_MAX_DEF
        apply(pid, cur, mx)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CustomSpiritDriveBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) and root[pid] then
            poll(pid)
        end
    end

    function CustomSpiritDriveBar.Set(pid, current, max)
        if GetLocalPlayer() ~= Player(pid) then return end
        ensure(pid)
        apply(pid, current or 0, max or (maxVal[pid] or SD_MAX_DEF))
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensure(pid)
                end
            end
        end

        local t = CreateTimer()
        TimerStart(t, POLL_DT, true, function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER
                   and GetLocalPlayer() == Player(pid)
                   and root[pid] then
                    poll(pid)
                end
            end
        end)

        -- Optional: react to events if your SD system emits them
        if rawget(_G, "ProcBus") and ProcBus.On then
            ProcBus.On("OnSpiritDriveChanged", function(e)
                if not e or type(e.pid) ~= "number" then return end
                if GetLocalPlayer() ~= Player(e.pid) then return end
                ensure(e.pid)
                local cur = tonumber(e.current) or readSpiritDrive(e.pid)
                local mx  = tonumber(e.max) or (maxVal[e.pid] or SD_MAX_DEF)
                apply(e.pid, cur, mx)
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CustomSpiritDriveBar")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
