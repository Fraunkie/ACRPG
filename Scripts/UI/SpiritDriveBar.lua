if Debug and Debug.beginFile then Debug.beginFile("CustomSpiritDriveBar.lua") end
--==================================================
-- CustomSpiritDriveBar.lua
-- Purple Spirit Drive bar (WORLD_FRAME)
--  • Half size of HP bar
--  • Positioned above HP bar
--  • Max 100
--  • Shows "XX / 100"
--==================================================

if not CustomSpiritDriveBar then CustomSpiritDriveBar = {} end
_G.CustomSpiritDriveBar = CustomSpiritDriveBar

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local BAR_W        = 0.11       -- width (half HP)
    local BAR_H        = 0.015      -- height (half HP)
    local FILL_PAD     = 0.004
    local BOTTOM_Y     = 0.105      -- slightly above HP bar
    local LEVEL        = 13         -- draw above HP bar

    local TEXT_SCALE   = 0.85
    local POLL_DT      = 0.05
    local SD_MAX       = 100

    local TEX_BACK     = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local TEX_FILL     = "ReplaceableTextures\\TeamColor\\TeamColor15" -- purple

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root, back, bar, label = {}, {}, {}, {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function uiWorld() return BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0) end
    local function uiRoot()  return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

    local function getHero(pid)
        local pd = rawget(_G, "PLAYER_DATA") and PLAYER_DATA[pid]
        if pd and pd.hero then return pd.hero end
        if rawget(_G, "PlayerHero") and PlayerHero[pid] then return PlayerHero[pid] end
        return nil
    end

    local function getSpiritDrive(pid)
        local pd = rawget(_G, "PLAYER_DATA") and PLAYER_DATA[pid]
        if pd and pd.spiritDrive then
            return math.min(pd.spiritDrive, SD_MAX)
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
        BlzFrameSetPoint(sb, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, FILL_PAD, -FILL_PAD)
        BlzFrameSetPoint(sb, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -FILL_PAD, FILL_PAD)
        BlzFrameSetTexture(sb, TEX_FILL, 0, false)
        BlzFrameSetMinMaxValue(sb, 0, SD_MAX)
        BlzFrameSetValue(sb, 0)

        local t = BlzCreateFrameByType("TEXT", "SDText"..pid, uiRoot(), "", 0)
        label[pid] = t
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetScale(t, TEXT_SCALE)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetText(t, "0 / 100")
    end

    local function update(pid)
        local val = getSpiritDrive(pid)
        if bar[pid] then
            BlzFrameSetValue(bar[pid], val)
        end
        if label[pid] then
            BlzFrameSetText(label[pid], tostring(val) .. " / 100")
        end
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function CustomSpiritDriveBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then update(pid) end
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
                    update(pid)
                end
            end
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CustomSpiritDriveBar")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
