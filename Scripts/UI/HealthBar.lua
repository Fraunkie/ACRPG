if Debug and Debug.beginFile then Debug.beginFile("CustomHealthBar.lua") end
--==================================================
--@@debug
-- CustomHealthBar.lua
-- Bottom-centered red HP bar (WORLD_FRAME; not clipped by console)
--==================================================

if not CustomHealthBar then CustomHealthBar = {} end
_G.CustomHealthBar = CustomHealthBar

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local BAR_W        = 0.25      -- overall width
    local BAR_H        = 0.040     -- overall height
    local FILL_W_PAD   = 0.04     -- padding for width of the fill
    local FILL_H_PAD   = 0.011     -- padding for height of the fill
    local FILL_PAD     = 0.006     -- inner padding from backdrop to fill
    local BOTTOM_Y     = 0.2     -- distance from bottom of screen


    local TEXT_SCALE   = 0.90
    local POLL_DT      = 0.05

    -- Textures
    local TEX_BACK     = "ui\\HealthBar.blp"
    local TEX_FILL     = "ReplaceableTextures\\TeamColor\\TeamColor00"  -- 00 = red

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local root   = {}  -- pid -> FRAME (container in WORLD_FRAME)
    local back   = {}  -- pid -> BACKDROP (underlay)
    local bar    = {}  -- pid -> SIMPLESTATUSBAR (red fill)
    local label  = {}  -- pid -> TEXT
    local bound  = {}  -- pid -> unit (current hero)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function uiWorld()  return BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0) end
    local function uiRoot()   return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

    local function wantWidth()  return BAR_W end
    local function wantHeight() return BAR_H end

local function ensureFrames(pid)
    if root[pid] then return end

    local parent = uiWorld()
    local r = BlzCreateFrameByType("FRAME", "HPRoot"..pid, parent, "", 0)
    root[pid] = r
    BlzFrameSetLevel(r, 1)
    BlzFrameSetSize(r, wantWidth(), wantHeight())
    -- Change the point to top-right instead of bottom-center
    BlzFrameSetPoint(r, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, 0.0, 0.0)

    -- Backdrop sits under the simple status bar
    local bg = BlzCreateFrameByType("BACKDROP", "HPBg"..pid, uiRoot(), "", 0)
    back[pid] = bg
    BlzFrameSetAllPoints(bg, r)
    BlzFrameSetTexture(bg, TEX_BACK, 0, true)
    BlzFrameSetAlpha(bg, 180)
    BlzFrameSetLevel(bg, 3)

    -- Fill bar
    local sb = BlzCreateFrameByType("SIMPLESTATUSBAR", "HPFill"..pid, bg, "", 0)
    bar[pid] = sb
    BlzFrameSetPoint(sb, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, FILL_W_PAD, -FILL_H_PAD)
    BlzFrameSetPoint(sb, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -FILL_W_PAD, FILL_H_PAD)
    BlzFrameSetSize(sb, FILL_W_PAD, FILL_H_PAD)
    BlzFrameSetTexture(sb, TEX_FILL, 0, false)  -- Apply the red fill texture
    BlzFrameSetMinMaxValue(sb, 0, 1)  -- Min/max values (will be updated later)
    BlzFrameSetValue(sb, 0)  -- Initial fill value (0)
    BlzFrameSetLevel(sb, 1)  -- Set the fill level (highest, on top)

    -- Text
    local t = BlzCreateFrameByType("TEXT", "HPText"..pid, uiRoot(), "", 0)
    label[pid] = t
    -- anchor in the visual center of the bar
    BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
    BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetScale(t, TEXT_SCALE)
    BlzFrameSetText(t, "HP 0 / 0")
end


    local function currentHero(pid)
        -- prefer PlayerData if present, else global mirror
        local pd = rawget(_G, "PLAYER_DATA") and PLAYER_DATA[pid]
        if pd and pd.hero then return pd.hero end
        if rawget(_G, "PlayerHero") and PlayerHero[pid] then return PlayerHero[pid] end
        return nil
    end

    local function update(pid)
        local r = root[pid]; if not r then return end

        local u = currentHero(pid)
        if validUnit(u) then
            bound[pid] = u
            local cur = math.max(0, R2I(GetWidgetLife(u)))
            local max = math.max(1, BlzGetUnitMaxHP(u))
            -- keep bar’s min/max in sync with real HP pool
            BlzFrameSetMinMaxValue(bar[pid], 0, max)
            BlzFrameSetValue(bar[pid], cur)
            -- update text without using formatting tokens (safer in your editor)
            BlzFrameSetText(label[pid], "HP " .. tostring(cur) .. " / " .. tostring(max))
        else
            bound[pid] = nil
            BlzFrameSetMinMaxValue(bar[pid], 0, 1)
            BlzFrameSetValue(bar[pid], 0)
            BlzFrameSetText(label[pid], "HP 0 / 0")
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CustomHealthBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then update(pid) end
    end

    function CustomHealthBar.BindHero(pid, u)
        -- optional manual bind; normal polling will also catch changes
        if GetLocalPlayer() ~= Player(pid) then return end
        bound[pid] = u
        update(pid)
    end

    --------------------------------------------------
    -- Init / polling
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureFrames(pid)
                end
            end
        end

        -- light polling so we always catch hero creation/swaps and HP changes
        local tim = CreateTimer()
        TimerStart(tim, POLL_DT, true, function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                if GetPlayerController(Player(pid)) == MAP_CONTROL_USER
                   and GetLocalPlayer() == Player(pid)
                   and root[pid] then
                    update(pid)
                end
            end
        end)

        -- Also hook your event bus if present (optional extra reliability)
        if rawget(_G, "ProcBus") and ProcBus.On then
            ProcBus.On("OnBootflowFinished", function(e)
                if e and type(e.pid)=="number" and GetLocalPlayer()==Player(e.pid) then
                    ensureFrames(e.pid)
                    update(e.pid)
                end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CustomHealthBar")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
