if Debug and Debug.beginFile then Debug.beginFile("TargetingSystem.lua") end
--==================================================
-- TargetingSystem.lua
-- Version: v1.13 (2025-10-26)
--  • TAB cycles nearest hostile targets (front-biased)
--  • Optional RMB click sets target under cursor (hostile only)
--  • Persistent overhead marker on the locked target
--  • Top-center target HP bar + text (updates live)
--  • Auto-clears on death or leaving range
--  • Emits ProcBus "OnTargetChanged"
--  • FIX: Fully hide HUD (root, backdrop, bar, text) when no target
--==================================================

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local CYCLE_RADIUS            = 1500.0   -- search radius from hero
    local FRONT_CONE_DEG          = 150.0   -- prefer units roughly in front
    local CLEAR_RADIUS            = 1900.0   -- clear lock if beyond this
    local RETAIN_ON_OUT_OF_CONE   = true     -- keep lock even if it leaves cone

    -- RMB pick under cursor (merge convenience)
    local ENABLE_RIGHT_CLICK_PICK = true
    local PICK_RADIUS             = 96.0     -- screen-ground pick radius

    -- Marker model (arrow / target reticle)
    -- Path requested in screenshot:
    local FX_MODEL_FALLBACK       = "Abilities\\Spells\\Other\\Aneu\\AneuTarget.mdl"
    local FX_ATTACH_POINT         = "overhead"
    local FX_SCALE                = 0.90

    -- Target HUD (top-center) – anchored to GAME_UI
    local HUD_W                   = 0.28
    local HUD_H                   = 0.030
    local HUD_PAD                 = 0.006
    local HUD_TOP_Y_OFFSET        = -0.060   -- from the very top of the screen
    local HUD_LEVEL               = 12
    local HUD_TEXT_SCALE          = 0.96
    local HUD_BACK_TEX            = "UI\\Widgets\\EscMenu\\Human\\blank-background.blp"
    local HUD_FILL_TEX            = "ReplaceableTextures\\TeamColor\\TeamColor00" -- red

    -- Timings
    local POLL_DT                 = 0.15     -- live HP updates
    local MAINT_DT                = 0.20     -- range/death checks

    --------------------------------------------------
    -- Locals / State
    --------------------------------------------------
    TargetingSystem = TargetingSystem or {}

    local MARKER     = {}                -- pid -> effect/fx id
    local ENUM_GROUP = CreateGroup()

    -- Target HUD per-pid
    local thRoot  = {}  -- FRAME (container in GAME_UI)
    local thBack  = {}  -- BACKDROP (underlay)
    local thBar   = {}  -- SIMPLESTATUSBAR (fill)
    local thText  = {}  -- TEXT (label)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and not IsUnitType(u, UNIT_TYPE_DEAD)
    end
    local function isHostile(a, b)
        return IsPlayerEnemy(GetOwningPlayer(a), GetOwningPlayer(b))
    end

    local function uiRoot()  return BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0) end

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

    local function dist2(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return dx*dx + dy*dy
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

        local parent = uiRoot()
        local r = BlzCreateFrameByType("FRAME", "TargetHUDRoot"..pid, parent, "", 0)
        thRoot[pid] = r
        BlzFrameSetLevel(r, HUD_LEVEL)
        BlzFrameSetSize(r, HUD_W, HUD_H)
        -- anchor to the top center of GAME_UI, nudge downward
        BlzFrameSetPoint(r, FRAMEPOINT_TOP, parent, FRAMEPOINT_TOP, 0.0, HUD_TOP_Y_OFFSET)

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

        local t = BlzCreateFrameByType("TEXT", "TargetHUDText"..pid, parent, "", 0)
        thText[pid] = t
        BlzFrameSetPoint(t, FRAMEPOINT_CENTER, r, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetTextAlignment(t, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
        BlzFrameSetScale(t, HUD_TEXT_SCALE)
        BlzFrameSetText(t, "")
        BlzFrameSetVisible(t, false)

        BlzFrameSetVisible(r, false)
    end

    -- Be explicit: hide every subframe to avoid any linger
    local function hideHUD(pid)
        if thBack[pid] then BlzFrameSetVisible(thBack[pid], false) end
        if thBar[pid]  then BlzFrameSetVisible(thBar[pid],  false) end
        if thText[pid] then BlzFrameSetVisible(thText[pid], false) end
        if thRoot[pid] then BlzFrameSetVisible(thRoot[pid], false) end
    end

    local function showHUD(pid)
        ensureHUD(pid)
        BlzFrameSetVisible(thRoot[pid], true)
        if thBack[pid] then BlzFrameSetVisible(thBack[pid], true) end
        if thBar[pid]  then BlzFrameSetVisible(thBar[pid],  true) end
        if thText[pid] then BlzFrameSetVisible(thText[pid], true) end
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
        local nm = GetUnitName(tgt) or "Target"
        BlzFrameSetText(thText[pid], nm .. "  HP " .. tostring(cur) .. " / " .. tostring(max))
        showHUD(pid)
    end

    --------------------------------------------------
    -- Candidate building / cycling (hostile only)
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
        local h = heroOf(pid); if not validUnit(h) then return end
        local inCone, all = buildCandidates(pid, h)
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
    -- RMB pick under cursor (hostile only)
    --------------------------------------------------
    local function rmbPick(pid)
        if not ENABLE_RIGHT_CLICK_PICK then return end
        local h = heroOf(pid); if not validUnit(h) then return end

        -- world position under cursor
        local mx = BlzGetTriggerPlayerMouseX()
        local my = BlzGetTriggerPlayerMouseY()

        local best, bestd2 = nil, nil
        GroupEnumUnitsInRange(ENUM_GROUP, mx, my, PICK_RADIUS, nil)
        local u = FirstOfGroup(ENUM_GROUP)
        while u ~= nil do
            GroupRemoveUnit(ENUM_GROUP, u)
            if validUnit(u) and isHostile(u, h) then
                local d2 = dist2(mx, my, GetUnitX(u), GetUnitY(u))
                if not bestd2 or d2 < bestd2 then
                    best, bestd2 = u, d2
                end
            end
            u = FirstOfGroup(ENUM_GROUP)
        end

        if best then setTarget(pid, best) end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
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
                        local d2 = dx*dx + dy*dy
                        if d2 > (CLEAR_RADIUS * CLEAR_RADIUS) then
                            setTarget(pid, nil)
                        else
                            if RETAIN_ON_OUT_OF_CONE then
                                updateHUD(pid, tgt)
                            else
                                local ang = math.deg(math.atan(dy, dx))
                                local off = angleDiffDeg(ang, GetUnitFacing(h))
                                if off > (FRONT_CONE_DEG * 0.5) then
                                    setTarget(pid, nil)
                                else
                                    updateHUD(pid, tgt)
                                end
                            end
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
        -- Ensure HUD exists per-player (local)
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                if GetLocalPlayer() == Player(pid) then
                    ensureHUD(pid)
                end
            end
        end

        -- ProcBus request hook
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("RequestTargetCycle", function(payload)
                if not payload then return end
                local pid = payload.pid
                if type(pid) == "number" then pickNext(pid) end
            end)
        end

        -- TAB fallback (works even if not wired elsewhere)
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local trig = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(trig, Player(pid), OSKEY_TAB, 0, true)
            TriggerAddAction(trig, function()
                local p = GetTriggerPlayer()
                local id = GetPlayerId(p)
                if GetLocalPlayer() == p then pickNext(id) end
            end)
        end

        -- RMB pick
        if ENABLE_RIGHT_CLICK_PICK then
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
                local t = CreateTrigger()
                TriggerRegisterPlayerMouseEventBJ(t, Player(pid), bj_MOUSEEVENTTYPE_DOWN)
                TriggerAddAction(t, function()
                    if BlzGetTriggerPlayerMouseButton() == MOUSE_BUTTON_TYPE_RIGHT then
                        rmbPick(GetPlayerId(GetTriggerPlayer()))
                    end
                end)
            end
        end

        -- maintenance timers
        TimerStart(CreateTimer(), MAINT_DT, true, maintenance)
        TimerStart(CreateTimer(), POLL_DT,  true, pollHP)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("TargetingSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
