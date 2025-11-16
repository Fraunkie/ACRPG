if Debug and Debug.beginFile then Debug.beginFile("CustomSEBar.lua") end
--@debug
--==================================================
-- CustomSEBar.lua  (Soul Energy XP Bar)
-- Bottom-centered SE bar (WORLD_FRAME; not clipped by console)
-- Format: "XP <cur> / <next>  —  Soul Energy Lv <level>"
-- Safe against missing APIs (uses tolerant fallbacks)
--==================================================

if not CustomSEBar then CustomSEBar = {} end
_G.CustomSEBar = CustomSEBar

do
    --------------------------------------------------
    -- TUNABLES
    --------------------------------------------------
    local BAR_W        = 0.25      -- overall width
    local BAR_H        = 0.040     -- overall height
    local FILL_W_PAD   = 0.04     -- padding for width of the fill
    local FILL_H_PAD   = 0.011     -- padding for height of the fill
    local FILL_PAD     = 0.006     -- inner padding from backdrop to fill
    local BOTTOM_Y     = 0.030     -- distance from bottom of screen       -- z-order of the container frame

    local TEXT_SCALE   = 0.90
    local POLL_DT      = 0.05

    -- Textures
    local TEX_BACK     = "ui\\SoulEnergyBar.blp"
    local TEX_FILL     = "ReplaceableTextures\\TeamColor\\TeamColor01"  -- 01 = blue

    --------------------------------------------------
    -- STATE
    --------------------------------------------------
    local root   = {}  -- pid -> FRAME (container in WORLD_FRAME)
    local back   = {}  -- pid -> BACKDROP (underlay)
    local bar    = {}  -- pid -> SIMPLESTATUSBAR (fill)
    local label  = {}  -- pid -> TEXT
    local bound  = {}  -- pid -> unit (current hero, optional)

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function uiWorld()  return BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0) end
    local function uiRoot()   return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

    -- Robust getters that tolerate different API names
    local function se_getLevel(pid)
        local L = _G.SoulEnergyLogic
        local A = _G.SoulEnergy
        if L and L.GetLevel then
            local ok, v = pcall(L.GetLevel, pid); if ok and type(v)=="number" then return v end
        end
        if A and A.GetLevel then
            local ok, v = pcall(A.GetLevel, pid); if ok and type(v)=="number" then return v end
        end
        -- legacy field in PLAYER_DATA
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and type(PLAYER_DATA[pid].soulLevel)=="number" then
            return PLAYER_DATA[pid].soulLevel
        end
        return 0
    end

    local function se_getXP(pid)
        local L = _G.SoulEnergyLogic
        local A = _G.SoulEnergy
        if L and (L.GetXP or L.GetExperience) then
            local fn = L.GetXP or L.GetExperience
            local ok, v = pcall(fn, pid); if ok and type(v)=="number" then return v end
        end
        if A and (A.GetXP or A.GetExperience) then
            local fn = A.GetXP or A.GetExperience
            local ok, v = pcall(fn, pid); if ok and type(v)=="number" then return v end
        end
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and type(PLAYER_DATA[pid].SoulEnergyExperience)=="number" then
            return PLAYER_DATA[pid].SoulEnergyExperience
        end
        return 0
    end

    local function se_getNextXP(pid)
        -- Prefer a direct "next level XP" API if present
        local L = _G.SoulEnergyLogic
        local A = _G.SoulEnergy
        if L and (L.GetNextXP or L.GetNextLevelXP or L.GetXPForNextLevel) then
            local fn = L.GetNextXP or L.GetNextLevelXP or L.GetXPForNextLevel
            local ok, v = pcall(fn, pid); if ok and type(v)=="number" then return v end
        end
        if A and (A.GetNextXP or A.GetNextLevelXP or A.GetXPForNextLevel) then
            local fn = A.GetNextXP or A.GetNextLevelXP or A.GetXPForNextLevel
            local ok, v = pcall(fn, pid); if ok and type(v)=="number" then return v end
        end
        -- Fallback: if we only know current XP, make a sane non-zero cap so bar renders
        local cur = se_getXP(pid)
        return cur + 100
    end

    local function ensureFrames(pid)
        if root[pid] then return end

        local parent = uiWorld()
        local r = BlzCreateFrameByType("FRAME", "SEBarRoot"..pid, parent, "", 0)
        root[pid] = r
        BlzFrameSetLevel(r, 1)
        BlzFrameSetSize(r, BAR_W, BAR_H)
        -- center bottom
        BlzFrameSetPoint(r, FRAMEPOINT_BOTTOM, parent, FRAMEPOINT_BOTTOM, 0.0, BOTTOM_Y)

        -- Backdrop
        local bg = BlzCreateFrameByType("BACKDROP", "SEBarBg"..pid, uiRoot(), "", 0)
        back[pid] = bg
        BlzFrameSetAllPoints(bg, r)
        BlzFrameSetTexture(bg, TEX_BACK, 0, true)
        BlzFrameSetAlpha(bg, 180)
        BlzFrameSetLevel(bg, 15)

        -- Fill
        local sb = BlzCreateFrameByType("SIMPLESTATUSBAR", "SEBarFill"..pid, r, "", 0)
        bar[pid] = sb
        BlzFrameSetPoint(sb, FRAMEPOINT_TOPLEFT, r, FRAMEPOINT_TOPLEFT, FILL_W_PAD, -FILL_H_PAD)
        BlzFrameSetPoint(sb, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -FILL_W_PAD, FILL_H_PAD)
        BlzFrameSetSize(sb, FILL_W_PAD, FILL_H_PAD)
        BlzFrameSetTexture(sb, TEX_FILL, 0, false)
        BlzFrameSetMinMaxValue(sb, 0, 1)
        BlzFrameSetValue(sb, 0)
        BlzFrameSetLevel(sb, 3)

        -- Text (parented to GAME_UI so it renders crisp)
        local t = BlzCreateFrameByType("TEXT", "SEBarText"..pid, uiRoot(), "", 0)
        label[pid] = t
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(t, TEXT_SCALE)
        BlzFrameSetText(t, "XP 0 / 1  —  Soul Energy Lv 0")
    end

    local function currentHero(pid)
        local pd = rawget(_G, "PlayerData") and PlayerData[pid]
        if pd and pd.hero then return pd.hero end
        if rawget(_G, "PlayerHero") and PlayerHero[pid] then return PlayerHero[pid] end
        return nil
    end

    local function update(pid)
        local r = root[pid]; if not r then return end

        -- Binding hero isn’t strictly needed here, but we keep it in case you want to gate updates by validity.
        local u = currentHero(pid)
        if validUnit(u) then bound[pid] = u else bound[pid] = nil end

        local cur = se_getXP(pid)
        local nxt = se_getNextXP(pid)
        if nxt <= cur then nxt = cur + 1 end

        BlzFrameSetMinMaxValue(bar[pid], 0, nxt)
        BlzFrameSetValue(bar[pid], cur)

        local lvl = se_getLevel(pid)
        BlzFrameSetText(label[pid], "XP " .. tostring(cur) .. " / " .. tostring(nxt) .. "  —  Soul Energy Lv " .. tostring(lvl))
    end

    --------------------------------------------------
    -- PUBLIC API
    --------------------------------------------------
    function CustomSEBar.Refresh(pid)
        if GetLocalPlayer() == Player(pid) then update(pid) end
    end

    function CustomSEBar.BindHero(pid, u)
        if GetLocalPlayer() ~= Player(pid) then return end
        bound[pid] = u
        update(pid)
    end

    --------------------------------------------------
    -- INIT / POLLING
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureFrames(pid)
                end
            end
        end

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

        if rawget(_G, "ProcBus") and ProcBus.On then
            ProcBus.On("OnBootflowFinished", function(e)
                if e and type(e.pid)=="number" and GetLocalPlayer()==Player(e.pid) then
                    ensureFrames(e.pid)
                    update(e.pid)
                end
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CustomSEBar")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
