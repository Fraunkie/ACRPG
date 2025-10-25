if Debug and Debug.beginFile then Debug.beginFile("TargetingSystem.lua") end
--==================================================
-- TargetingSystem.lua
-- Version: v1.10 (2025-10-25)
--  TAB cycles nearest hostile targets (front-biased)
--  Lock lives on PLAYER_DATA[pid].control.target
--  Persistent marker above the locked target
--  Top-center target HP bar + text (updates live)
--  Auto-clears on death or leaving range
--  Emits ProcBus "OnTargetChanged"
--==================================================

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local CYCLE_RADIUS            = 1200.0   -- search radius from hero
    local FRONT_CONE_DEG          = 140.0    -- prefer units roughly in front
    local CLEAR_RADIUS            = 1400.0   -- clear lock if beyond this
    local RETAIN_ON_OUT_OF_CONE   = true     -- keep lock even if it leaves cone

    -- Target marker model (arrow over head). This stays while locked.
    -- Common WC3 model: the "TalkToMe" speaking icon or selection arrow.
    -- Pick ONE of these:
    local FX_MODEL_FALLBACK       = "Abilities\\Spells\\Other\\TalkToMe\\TalkToMe.mdl"
    -- local FX_MODEL_FALLBACK    = "Abilities\\Spells\\Items\\AIlb\\AIlbTarget.mdl"
    local FX_ATTACH_POINT         = "overhead"
    local FX_SCALE                = 1.10

    -- Target HUD (top center) visuals
    local HUD_W                   = 0.28
    local HUD_H                   = 0.030
    local HUD_PAD                 = 0.006
    local HUD_Y                   = 0.545      -- distance up from screen center
    local HUD_LEVEL               = 12
    local HUD_TEXT_SCALE          = 0.96
    local HUD_BACK_TEX            = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local HUD_FILL_TEX            = "ReplaceableTextures\\TeamColor\\TeamColor00" -- red

    -- Timings
    local POLL_DT                 = 0.15       -- live HP updates
    local MAINT_DT                = 0.20       -- range/death checks

    --------------------------------------------------
    -- Locals / State
    --------------------------------------------------
    local MARKER    = {}                -- pid -> effect/fx id
    local ENUM_GROUP = CreateGroup()

    -- Target HUD per-pid
    local thRoot  = {}  -- FRAME (container in WORLD_FRAME)
    local thBack  = {}  -- BACKDROP (underlay)
    local thBar   = {}  -- SIMPLESTATUSBAR (fill)
    local thText  = {}  -- TEXT (parented to GAME_UI so it renders above)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and not IsUnitType(u, UNIT_TYPE_DEAD)
    end
    local function isHostile(a, b)
        return IsPlayerEnemy(GetOwningPlayer(a), GetOwningPlayer(b))
    end
    local function uiWorld()  return BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0) end
    local function uiRoot()   return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return nil, nil end
        pd.control = pd.control or {
            direct=false, holdW=false, holdA=false, holdS=false, holdD=false,
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil, target=nil
        }
        return pd.control, pd
    end

    local function heroOf(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if pd and validUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    local function angleDiffDeg(a, b)
        local d = a - b
        while d > 180.0 do d = d - 360.0 end
        while d < -180.0 do d = d + 360.0 end
        if d < 0.0 then d = -d end
        return d
    end

    --------------------------------------------------
    -- Marker helpers (persistent while locked)
    --------------------------------------------------
    local function clearMarker(pid)
        if MARKER[pid] then
            if _G.FXSystem and FXSystem.Destroy then
                pcall(FXSystem.Destroy, MARKER[pid])
            else
                DestroyEffect(MARKER[pid])
            end
            MARKER[pid] = nil
        end
    end

    local function placeMarker(pid, u)
        clearMarker(pid)
        if not validUnit(u) then return end
        if _G.FXSystem and FXSystem.AttachUnit then
            local id = FXSystem.AttachUnit(u, FX_ATTACH_POINT, {
                model = FX_MODEL_FALLBACK, scale = FX_SCALE, z = 0.0
            })
            MARKER[pid] = id
        else
            local e = AddSpecialEffectTarget(FX_MODEL_FALLBACK, u, FX_ATTACH_POINT)
            BlzSetSpecialEffectScale(e, FX_SCALE)
            MARKER[pid] = e
        end
    end

    --------------------------------------------------
    -- Target HUD (top-center bar + text)
    --------------------------------------------------
    local function ensureHUD(pid)
        if thRoot[pid] then return end

        local parent = uiWorld()
        local r = BlzCreateFrameByType("FRAME", "TargetHUDRoot"..pid, parent, "", 0)
        thRoot[pid] = r
        BlzFrameSetLevel(r, HUD_LEVEL)
        BlzFrameSetSize(r, HUD_W, HUD_H)
        -- top-center: anchor relative to world frame center then nudge up
        BlzFrameSetPoint(r, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, 0.0, -0.100)
        -- alternative: center + Y offset
        BlzFrameClearAllPoints(r)
        BlzFrameSetPoint(r, FRAMEPOINT_CENTER, parent, FRAMEPOINT_CENTER, 0.0, HUD_Y)

        local bg = BlzCreateFrameByType("BACKDROP", "TargetHUDBG"..pid, r, "", 0)
        thBack[pid] = bg
        BlzFrameSetAllPoints(bg, r)
        BlzFrameSetTexture(bg, HUD_BACK_TEX, 0, true)
        BlzFrameSetAlpha(bg, 180)

        local sb = BlzCreateFrameByType("SIMPLESTATUSBAR", "TargetHUDFill"..pid, r, "", 0)
        thBar[pid] = sb
        BlzFrameSetPoint(sb, FRAMEPOINT_TOPLEFT,     r, FRAMEPOINT_TOPLEFT,     HUD_PAD, -HUD_PAD)
        BlzFrameSetPoint(sb, FRAMEPOINT_BOTTOMRIGHT, r, FRAMEPOINT_BOTTOMRIGHT, -HUD_PAD,  HUD_PAD)
        BlzFrameSetTexture(sb, HUD_FILL_TEX, 0, false)
        BlzFrameSetMinMaxValue(sb, 0, 1)
        BlzFrameSetValue(sb, 0)

        local t = BlzCreateFrameByType("TEXT", "TargetHUDText"..pid, uiRoot(), "", 0)
        thText[pid] = t
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(t, HUD_TEXT_SCALE)
        BlzFrameSetText(t, "")
        BlzFrameSetVisible(t, false)

        -- hidden by default
        BlzFrameSetVisible(r, false)
    end

    local function hideHUD(pid)
        if thRoot[pid] then
            BlzFrameSetVisible(thRoot[pid], false)
        end
        if thText[pid] then
            BlzFrameSetVisible(thText[pid], false)
        end
    end

    local function showHUD(pid)
        ensureHUD(pid)
        BlzFrameSetVisible(thRoot[pid], true)
        BlzFrameSetVisible(thText[pid], true)
    end

    local function updateHUD(pid, tgt)
        if not thRoot[pid] then return end
        if not validUnit(tgt) then
            hideHUD(pid)
            return
        end
        local cur = math.max(0, R2I(GetWidgetLife(tgt)))
        local max = math.max(1, BlzGetUnitMaxHP(tgt))
        BlzFrameSetMinMaxValue(thBar[pid], 0, max)
        BlzFrameSetValue(thBar[pid], cur)
        -- No percent signs; safe string for WE:
        local nm = GetUnitName(tgt) or "Target"
        BlzFrameSetText(thText[pid], nm .. "  HP " .. tostring(cur) .. " / " .. tostring(max))
        showHUD(pid)
    end

    --------------------------------------------------
    -- Selection logic
    --------------------------------------------------
    local function buildCandidates(pid, uHero)
        GroupClear(ENUM_GROUP)
        local hx = GetUnitX(uHero)
        local hy = GetUnitY(uHero)
        GroupEnumUnitsInRange(ENUM_GROUP, hx, hy, CYCLE_RADIUS, nil)

        local facing = GetUnitFacing(uHero)
        local inCone, all = {}, {}

        local u = FirstOfGroup(ENUM_GROUP)
        while u ~= nil do
            GroupRemoveUnit(ENUM_GROUP, u)
            if validUnit(u) and isHostile(u, uHero) then
                local ux, uy = GetUnitX(u), GetUnitY(u)
                local dx, dy = ux - hx, uy - hy
                local dist = math.sqrt(dx*dx + dy*dy)
                local ang  = math.deg(math.atan(dy, dx))
                local off  = angleDiffDeg(ang, facing)
                local item = { unit = u, dist = dist, off = off }
                all[#all + 1] = item
                if off <= (FRONT_CONE_DEG * 0.5) then
                    inCone[#inCone + 1] = item
                end
            end
            u = FirstOfGroup(ENUM_GROUP)
        end

        local function byDist(a, b) return a.dist < b.dist end
        table.sort(inCone, byDist)
        table.sort(all, byDist)
        return inCone, all
    end

    local function setTarget(pid, tgt)
        local c = ensureControl(pid)
        if not c then return end
        c.target = tgt

        -- marker + HUD
        if tgt then
            placeMarker(pid, tgt)
            updateHUD(pid, tgt)
        else
            clearMarker(pid)
            hideHUD(pid)
        end

        if _G.ProcBus and ProcBus.Emit then
            ProcBus.Emit("OnTargetChanged", { pid = pid, target = tgt })
        end
    end

    local function pickNext(pid)
        local hero = heroOf(pid); if not validUnit(hero) then return end
        local inCone, all = buildCandidates(pid, hero)
        local list = (#inCone > 0) and inCone or all
        if #list == 0 then
            setTarget(pid, nil)
            return
        end

        local c = ensureControl(pid)
        local cur = c and c.target or nil
        if not validUnit(cur) then
            setTarget(pid, list[1].unit)
            return
        end

        -- find current index in list (if current not in list, start from 1)
        local idx = 0
        for i = 1, #list do
            if list[i].unit == cur then
                idx = i
                break
            end
        end

        local nextIdx
        if idx <= 0 or idx >= #list then
            nextIdx = 1
        else
            nextIdx = idx + 1
        end
        setTarget(pid, list[nextIdx].unit)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    TargetingSystem = TargetingSystem or {}
    function TargetingSystem.Cycle(pid) pickNext(pid) end
    function TargetingSystem.Get(pid)
        local c = ensureControl(pid); if not c then return nil end
        return c.target
    end
    function TargetingSystem.Clear(pid) setTarget(pid, nil) end

    --------------------------------------------------
    -- Maintenance: clear when dead / far; keep HUD updated
    --------------------------------------------------
    local function maintenance()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local c = ensureControl(pid)
            if c and c.target then
                local tgt = c.target
                if not validUnit(tgt) then
                    setTarget(pid, nil)
                else
                    local h = heroOf(pid)
                    if validUnit(h) then
                        local dx = GetUnitX(tgt) - GetUnitX(h)
                        local dy = GetUnitY(tgt) - GetUnitY(h)
                        local dist2 = dx*dx + dy*dy
                        if dist2 > (CLEAR_RADIUS * CLEAR_RADIUS) then
                            setTarget(pid, nil)
                        elseif not RETAIN_ON_OUT_OF_CONE then
                            local ang = math.deg(math.atan(dy, dx))
                            local off = angleDiffDeg(ang, GetUnitFacing(h))
                            if off > (FRONT_CONE_DEG * 0.5) then
                                setTarget(pid, nil)
                            else
                                updateHUD(pid, tgt)
                            end
                        else
                            updateHUD(pid, tgt)
                        end
                    else
                        setTarget(pid, nil)
                    end
                end
            else
                hideHUD(pid)
            end
        end
    end

    local function pollHP()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local c = ensureControl(pid)
            if c and c.target and validUnit(c.target) then
                updateHUD(pid, c.target)
            end
        end
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        -- request cycle hook (TAB is wired elsewhere)
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("RequestTargetCycle", function(payload)
                if not payload then return end
                local pid = payload.pid
                if type(pid) == "number" then pickNext(pid) end
            end)
        end

        -- per-player HUD frames
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureHUD(pid)
                end
            end
        end

        -- maintenance timers
        local tA = CreateTimer()
        TimerStart(tA, MAINT_DT, true, maintenance)

        local tB = CreateTimer()
        TimerStart(tB, POLL_DT, true, pollHP)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TargetingSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
