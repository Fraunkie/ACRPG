if Debug and Debug.beginFile then Debug.beginFile("CameraWheelGrid.lua") end
--==================================================
-- CameraWheelGrid.lua  (v1.34)
-- • Third-person camera that hard-locks behind the hero.
-- • Indefinite snap until hero exists.
-- • Mouse-look via hover grid; zoom with LMB+RMB is disabled.
-- • Obeys Direct Mode toggle -> inert when direct=false.
-- • CAMERA_EASE + CAMERA_LEAD for smooth, non-jittery yaw and pitch.
-- • NEW: Free-look hold after LMB release, optional snap on W press.
--==================================================

do
    --------------------------------------------------
    -- TUNABLES
    --------------------------------------------------
    local CAMERA_TICK            = 0.01

    -- smoothing and follow
    local CAMERA_EASE            = 0.12
    local CAMERA_LEAD            = 0.00

    -- default view
    local DEFAULT_PITCH          = 352.0
    local DEFAULT_DIST           = 460.0

    -- vertical offset for the rig
    local CAMERA_Z_OFFSET        = 140.0

    -- optional unit->camera yaw offset
    local YAW_UNIT_OFFSET        = 0.0

    -- mouse-look step sizes (hover grid)
    local TILT_SLOW              = 1.0
    local TILT_FAST_A            = 2.0
    local TILT_XFAST             = 3.0
    local YAW_SLOW               = 1.0
    local YAW_FAST_A             = 3.0
    local YAW_FAST_B             = 5.0

    -- zoom disabled by request
    local ENABLE_LMB_RMB_ZOOM    = false
    local ZOOM_STEP_SLOW         = 50.0
    local ZOOM_STEP_FAST         = 100.0
    local ZOOM_STEP_XFAST        = 150.0
    local DIST_MIN               = 300.0
    local DIST_MAX               = 900.0

    -- hover wheel layout
    local WHEEL_SIZE             = 0.40
    local DOT_SIZE               = 0.020
    local CENTER_NUDGE           = 0.003

    -- cursor recenter cadence while held
    local RECENTER_INTERVAL      = 0.06

    -- NEW: free-look hold after LMB release
    local FREELOOK_HOLD_SEC      = 1.0   -- keep the view you set with LMB for this long
    local FREELOOK_SNAP_ON_MOVE  = true  -- pressing W cancels the hold and snaps behind hero

    --------------------------------------------------
    -- STATE
    --------------------------------------------------
    local function PID_LOCAL()
        for i=0, bj_MAX_PLAYERS-1 do
            if GetLocalPlayer() == Player(i) then return i end
        end
        return 0
    end

    local pidL
    -- live (smoothed) camera values
    local yaw, pitch, dist = {}, {}, {}
    -- targets we ease toward
    local tyaw, tpitch, tdist = {}, {}, {}
    local snappedHero      = {}

    local holdL, holdR = {}, {}
    local lastCenter   = {}

    -- NEW: freelook state
    local freelookUntil = {}   -- os.clock deadline for LMB free-look
    local wHeld         = {}   -- track local W key for snap on move

    local gameUI, wheel
    local ring1, ring2, ring3 = {}, {}, {}

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function PD() return rawget(_G, "PlayerData") end
    local function ctrl(pid)
        local P = PD(); return (P and P.GetControl) and P.GetControl(pid) or nil
    end
    local function isDirect(pid)
        local c = ctrl(pid); return c and c.direct == true
    end
    local function heroOf(pid)
        local P = PD()
        if P and P.Get then
            local t = P.Get(pid)
            if t and t.hero and GetUnitTypeId(t.hero) ~= 0 then return t.hero end
        end
        if _G.PlayerHero and PlayerHero[pid] and GetUnitTypeId(PlayerHero[pid]) ~= 0 then
            return PlayerHero[pid]
        end
        return nil
    end
    local function setPDView(pid)
        local c = ctrl(pid); if not c then return end
        c.yaw    = yaw[pid]
        c.pitch  = pitch[pid]
        c.dist   = dist[pid]
        c.height = CAMERA_Z_OFFSET
    end
    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end
    local function wrap360(a)
        if a < 0.0 then a = a + 360.0 end
        if a >= 360.0 then a = a - 360.0 end
        return a
    end
    local function angDelta(from, to)
        local d = wrap360(to) - wrap360(from)
        if d > 180.0 then d = d - 360.0 end
        if d < -180.0 then d = d + 360.0 end
        return d
    end
    local function easeAngle(curr, target, k)
        return wrap360(curr + angDelta(curr, target) * k)
    end
    local function easeLinear(curr, target, k)
        return curr + (target - curr) * k
    end
    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end
    local function mouseOverUI()
        local fn = rawget(_G, "BlzGetMouseFocusFrame")
        if type(fn) == "function" then return fn() ~= nil end
        return false
    end
    local function worldEligible(pid)
        local c = ctrl(pid)
        if not isDirect(pid) then return false end
        if c and c.uiFocus then return false end
        if mouseOverUI() then return false end
        return true
    end
    local function recenterIfDue(pid)
        if GetLocalPlayer() ~= Player(pid) then return end
        local t = now()
        local last = lastCenter[pid] or 0
        if (t - last) >= RECENTER_INTERVAL then
            BlzSetMousePos(BlzGetLocalClientWidth()/2, BlzGetLocalClientHeight()/2)
            lastCenter[pid] = t
        end
    end

    --------------------------------------------------
    -- INPUT (gated by direct mode)
    --------------------------------------------------
    local function beginHold(pid)
        if GetLocalPlayer() ~= Player(pid) then return end
        if not isDirect(pid) then return end
        BlzEnableCursor(false)
        EnableDragSelect(false, false)
        BlzFrameSetEnable(wheel, true)
        for i=0,15 do BlzFrameSetEnable(ring1[i], true); BlzFrameSetEnable(ring3[i], true) end
        for i=0,11 do BlzFrameSetEnable(ring2[i], true) end
        lastCenter[pid] = 0
        recenterIfDue(pid)
    end
    local function endHold(pid)
        if GetLocalPlayer() ~= Player(pid) then return end
        BlzFrameSetEnable(wheel, false)
        for i=0,15 do BlzFrameSetEnable(ring1[i], false); BlzFrameSetEnable(ring3[i], false) end
        for i=0,11 do BlzFrameSetEnable(ring2[i], false) end
        BlzEnableCursor(true)
        EnableDragSelect(true, true)
    end
    local function onMouseDown()
        local pid = GetPlayerId(GetTriggerPlayer())
        if not worldEligible(pid) then return end
        local btn = BlzGetTriggerPlayerMouseButton()
        if btn == MOUSE_BUTTON_TYPE_LEFT then
            holdL[pid] = true
            -- while LMB is down we are actively free-looking
            freelookUntil[pid] = 0
        elseif btn == MOUSE_BUTTON_TYPE_RIGHT then
            holdR[pid] = true
        end
        if holdL[pid] or holdR[pid] then beginHold(pid) end
    end
    local function onMouseUp()
        local pid = GetPlayerId(GetTriggerPlayer())
        local btn = BlzGetTriggerPlayerMouseButton()
        if btn == MOUSE_BUTTON_TYPE_LEFT  then
            holdL[pid] = false
            -- start the post release free-look hold window
            freelookUntil[pid] = now() + FREELOOK_HOLD_SEC
        end
        if btn == MOUSE_BUTTON_TYPE_RIGHT then
            holdR[pid] = false
        end
        if not holdL[pid] and not holdR[pid] then endHold(pid) end
    end

    -- local W key tracking for snap on move
    local function onKey()
        if GetLocalPlayer() ~= GetTriggerPlayer() then return end
        local key  = BlzGetTriggerPlayerKey()
        local down = BlzGetTriggerPlayerIsKeyDown()
        if key == OSKEY_W then
            wHeld[pidL] = down and true or false
            if FREELOOK_SNAP_ON_MOVE and down then
                freelookUntil[pidL] = 0
            end
        end
    end

    --------------------------------------------------
    -- APPLY STEP (hover grid) -> writes TARGETS
    --------------------------------------------------
    local function applyStep(pid, dPitch, dYaw, dDist)
        if not isDirect(pid) then return end
        if not (holdL[pid] or holdR[pid]) then return end
        if not worldEligible(pid) then return end

        tyaw[pid]   = (tyaw[pid]   ~= nil) and tyaw[pid]   or yaw[pid]   or 0.0
        tpitch[pid] = (tpitch[pid] ~= nil) and tpitch[pid] or pitch[pid] or DEFAULT_PITCH
        tdist[pid]  = (tdist[pid]  ~= nil) and tdist[pid]  or dist[pid]  or DEFAULT_DIST

        if holdL[pid] and holdR[pid] then
            if ENABLE_LMB_RMB_ZOOM then
                tdist[pid] = clamp(tdist[pid] + dDist, DIST_MIN, DIST_MAX)
            end
        else
            tpitch[pid] = clamp(tpitch[pid] + dPitch, 300.0, 360.0)
            tyaw[pid]   = wrap360((tyaw[pid] or 0.0) + dYaw)
        end

        recenterIfDue(pid)
    end

    local function makeDot()
        local f = BlzCreateFrameByType("BUTTON", "gridDot", gameUI, "ScriptDialogButton", 0)
        BlzFrameSetSize(f, DOT_SIZE, DOT_SIZE)
        BlzFrameSetAlpha(f, 0)
        BlzFrameSetEnable(f, false)
        return f
    end

    local function buildWheel()
        gameUI = BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0)
        wheel  = BlzCreateFrameByType("SCROLLBAR", "", gameUI, "StandardFrameTemplate", 0)
        BlzFrameSetSize(wheel, WHEEL_SIZE, WHEEL_SIZE)
        BlzFrameSetPoint(wheel, FRAMEPOINT_CENTER, gameUI, FRAMEPOINT_CENTER, 0.0, 0.0)
        BlzFrameSetEnable(wheel, false)
        BlzFrameSetLevel(wheel, 0)
        BlzFrameSetAlpha(wheel, 0)

        for i=0,15 do ring1[i] = makeDot(); ring3[i] = makeDot() end
        for i=0,11 do ring2[i] = makeDot() end

        local function hook(f, dp, dy, dd)
            local t = CreateTrigger()
            BlzTriggerRegisterFrameEvent(t, f, FRAMEEVENT_MOUSE_ENTER)
            TriggerAddAction(t, function() applyStep(pidL, dp, dy, dd) end)
        end

        -- positions
        local p1 = {
            {  0.0,  CENTER_NUDGE, FRAMEPOINT_BOTTOM       },
            {  0.001,  0.001,      FRAMEPOINT_BOTTOMLEFT   },
            {  CENTER_NUDGE, 0.0,  FRAMEPOINT_LEFT         },
            {  0.001, -0.001,      FRAMEPOINT_TOPLEFT      },
            {  0.0, -CENTER_NUDGE, FRAMEPOINT_TOP          },
            { -0.001,-0.001,       FRAMEPOINT_TOPRIGHT     },
            { -CENTER_NUDGE, 0.0,  FRAMEPOINT_RIGHT        },
            { -0.001, 0.001,       FRAMEPOINT_BOTTOMRIGHT  },
        }
        for i=0,7 do
            local o = p1[i+1]
            BlzFrameSetPoint(ring1[i], o[3], gameUI, FRAMEPOINT_CENTER, o[1], o[2])
        end

        local p2 = {
            { 0.0,  0.020,  FRAMEPOINT_TOP        },
            { 0.004, 0.014, FRAMEPOINT_TOPLEFT    },
            { 0.014, 0.004, FRAMEPOINT_TOPLEFT    },
            { 0.020, 0.0,   FRAMEPOINT_LEFT       },
            { 0.014,-0.004, FRAMEPOINT_BOTTOMLEFT },
            { 0.004,-0.014, FRAMEPOINT_BOTTOMLEFT },
            { 0.0, -0.020,  FRAMEPOINT_BOTTOM     },
            {-0.004,-0.014, FRAMEPOINT_BOTTOMRIGHT},
            {-0.014,-0.004, FRAMEPOINT_BOTTOMRIGHT},
            {-0.020, 0.0,   FRAMEPOINT_RIGHT      },
            {-0.014, 0.004, FRAMEPOINT_TOPRIGHT   },
            {-0.004, 0.014, FRAMEPOINT_TOPRIGHT   },
        }
        for i=0,11 do
            local o = p2[i+1]
            BlzFrameSetPoint(ring2[i], o[3], gameUI, FRAMEPOINT_CENTER, o[1], o[2])
        end

        local p3 = {
            { 0.0,  0.040,  FRAMEPOINT_TOP        }, { 0.006, 0.030, FRAMEPOINT_TOPLEFT    },
            { 0.022, 0.022, FRAMEPOINT_TOPLEFT    }, { 0.030, 0.006, FRAMEPOINT_TOPLEFT    },
            { 0.040, 0.0,   FRAMEPOINT_LEFT       }, { 0.030,-0.006, FRAMEPOINT_LEFT       },
            { 0.022,-0.022, FRAMEPOINT_LEFT       }, { 0.006,-0.030, FRAMEPOINT_BOTTOMLEFT },
            { 0.0, -0.040,  FRAMEPOINT_BOTTOM     }, {-0.006,-0.030, FRAMEPOINT_BOTTOMRIGHT},
            {-0.022,-0.022, FRAMEPOINT_BOTTOMRIGHT}, {-0.030,-0.006, FRAMEPOINT_BOTTOMRIGHT},
            {-0.040, 0.0,   FRAMEPOINT_RIGHT      }, {-0.030, 0.006, FRAMEPOINT_RIGHT      },
            {-0.022, 0.022, FRAMEPOINT_RIGHT      }, {-0.006, 0.030, FRAMEPOINT_TOPRIGHT   },
        }
        for i=0,15 do
            local o = p3[i+1]
            BlzFrameSetPoint(ring3[i], o[3], gameUI, FRAMEPOINT_CENTER, o[1], o[2])
        end

        -- ring 1: slow
        hook(ring1[0],  TILT_SLOW,   0.0,        ZOOM_STEP_SLOW)
        hook(ring1[1],  TILT_SLOW,  -YAW_SLOW,   0.0)
        hook(ring1[2],  0.0,        -YAW_SLOW,   0.0)
        hook(ring1[3], -TILT_SLOW,  -YAW_SLOW,   0.0)
        hook(ring1[4], -TILT_SLOW,   0.0,       -ZOOM_STEP_SLOW)
        hook(ring1[5], -TILT_SLOW,   YAW_SLOW,   0.0)
        hook(ring1[6],  0.0,         YAW_SLOW,   0.0)
        hook(ring1[7],  TILT_SLOW,   YAW_SLOW,   0.0)

        -- ring 2: fast
        hook(ring2[0],  TILT_FAST_A,  0.0,         ZOOM_STEP_FAST)
        hook(ring2[1],  TILT_FAST_A, -YAW_FAST_A,  0.0)
        hook(ring2[2],  TILT_FAST_A, -YAW_FAST_B,  0.0)
        hook(ring2[3],  0.0,         -YAW_FAST_B,  0.0)
        hook(ring2[4], -TILT_FAST_A, -YAW_FAST_B,  0.0)
        hook(ring2[5], -TILT_FAST_A, -YAW_FAST_A,  0.0)
        hook(ring2[6], -TILT_FAST_A,  0.0,        -ZOOM_STEP_FAST)
        hook(ring2[7], -TILT_FAST_A,  YAW_FAST_A,  0.0)
        hook(ring2[8], -TILT_FAST_A,  YAW_FAST_B,  0.0)
        hook(ring2[9],  0.0,          YAW_FAST_B,  0.0)
        hook(ring2[10], TILT_FAST_A,  YAW_FAST_B,  0.0)
        hook(ring2[11], TILT_FAST_A,  YAW_FAST_A,  0.0)

        -- ring 3: xfast
        hook(ring3[0],   TILT_XFAST,  0.0,          ZOOM_STEP_XFAST)
        hook(ring3[1],   TILT_XFAST, -YAW_FAST_A,   0.0)
        hook(ring3[2],   TILT_XFAST, -YAW_FAST_B,   0.0)
        hook(ring3[3],   TILT_XFAST, -YAW_FAST_B,   0.0)
        hook(ring3[4],   0.0,        -YAW_FAST_B,   0.0)
        hook(ring3[5],  -TILT_XFAST, -YAW_FAST_B,   0.0)
        hook(ring3[6],  -TILT_XFAST, -YAW_FAST_B,   0.0)
        hook(ring3[7],  -TILT_XFAST, -YAW_FAST_A,   0.0)
        hook(ring3[8],  -TILT_XFAST,  0.0,         -ZOOM_STEP_XFAST)
        hook(ring3[9],  -TILT_XFAST,  YAW_FAST_A,   0.0)
        hook(ring3[10], -TILT_XFAST,  YAW_FAST_B,   0.0)
        hook(ring3[11], -TILT_XFAST,  YAW_FAST_B,   0.0)
        hook(ring3[12],  0.0,         YAW_FAST_B,   0.0)
        hook(ring3[13],  TILT_XFAST,  YAW_FAST_B,   0.0)
        hook(ring3[14],  TILT_XFAST,  YAW_FAST_B,   0.0)
        hook(ring3[15],  TILT_XFAST,  YAW_FAST_A,   0.0)
    end

    --------------------------------------------------
    -- SNAP + HARD ATTACH (only when direct=true)
    --------------------------------------------------
    local function trySnap(pid)
        if snappedHero[pid] then return end
        local u = heroOf(pid); if not u then return end
        local behind = wrap360(GetUnitFacing(u) + YAW_UNIT_OFFSET + CAMERA_LEAD)
        yaw[pid], pitch[pid], dist[pid] = behind, DEFAULT_PITCH, DEFAULT_DIST
        tyaw[pid], tpitch[pid], tdist[pid] = yaw[pid], pitch[pid], dist[pid]
        setPDView(pid)
        snappedHero[pid] = true
    end

    --------------------------------------------------
    -- CAMERA TICK (applies easing toward targets)
    --------------------------------------------------
    local function camTick()
        if not isDirect(pidL) then
            if GetLocalPlayer() == Player(pidL) then
                BlzFrameSetEnable(wheel, false)
                for i=0,15 do if ring1[i] then BlzFrameSetEnable(ring1[i], false) end
                               if ring3[i] then BlzFrameSetEnable(ring3[i], false) end end
                for i=0,11 do if ring2[i] then BlzFrameSetEnable(ring2[i], false) end end
                BlzEnableCursor(true)
                EnableDragSelect(true, true)
            end
            return
        end

        local u = heroOf(pidL)
        if not snappedHero[pidL] then
            trySnap(pidL)
        end

        if u then
            tyaw[pidL]   = (tyaw[pidL]   ~= nil) and tyaw[pidL]   or yaw[pidL]   or 0.0
            tpitch[pidL] = (tpitch[pidL] ~= nil) and tpitch[pidL] or pitch[pidL] or DEFAULT_PITCH
            tdist[pidL]  = (tdist[pidL]  ~= nil) and tdist[pidL]  or dist[pidL]  or DEFAULT_DIST

            -- decide whether to mirror hero facing
            local mirrorFacing = true

            -- while either button is down, do not mirror
            if holdL[pidL] or holdR[pidL] then
                mirrorFacing = false
            else
                -- after LMB release, honor free-look hold window
                local t = freelookUntil[pidL] or 0
                if t > 0 and now() < t then
                    mirrorFacing = false
                end
                -- if snap on move is enabled and W is down, end hold now
                if FREELOOK_SNAP_ON_MOVE and wHeld[pidL] then
                    freelookUntil[pidL] = 0
                end
            end

            if mirrorFacing then
                tyaw[pidL] = wrap360(GetUnitFacing(u) + YAW_UNIT_OFFSET + CAMERA_LEAD)
            end

            -- ease toward targets
            yaw[pidL]   = easeAngle(yaw[pidL]   or tyaw[pidL],   tyaw[pidL],   CAMERA_EASE)
            pitch[pidL] = easeLinear(pitch[pidL] or tpitch[pidL], tpitch[pidL], CAMERA_EASE)
            dist[pidL]  = easeLinear(dist[pidL]  or tdist[pidL],  tdist[pidL],  CAMERA_EASE)

            -- push camera fields
            SetCameraField(CAMERA_FIELD_ROTATION,        yaw[pidL] or 0.0,               CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, pitch[pidL] or DEFAULT_PITCH,   CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, dist[pidL]  or DEFAULT_DIST,    CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_ZOFFSET,         CAMERA_Z_OFFSET,                CAMERA_TICK)

            -- hard attach every tick
            SetCameraTargetController(u, 0.0, 0.0, false)
            SetCameraTargetControllerNoZForPlayer(Player(pidL), u, 0.0, 0.0, false)

            setPDView(pidL)

            if (holdL[pidL] or holdR[pidL]) and worldEligible(pidL) then
                recenterIfDue(pidL)
            end
        end
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    OnInit.final(function()
        pidL = PID_LOCAL()
        pitch[pidL], dist[pidL] = DEFAULT_PITCH, DEFAULT_DIST
        yaw[pidL] = yaw[pidL] or 0.0
        tyaw[pidL], tpitch[pidL], tdist[pidL] = yaw[pidL], pitch[pidL], dist[pidL]
        setPDView(pidL)

        buildWheel()

        local md = CreateTrigger()
        local mu = CreateTrigger()
        TriggerRegisterPlayerMouseEventBJ(md, Player(pidL), bj_MOUSEEVENTTYPE_DOWN)
        TriggerRegisterPlayerMouseEventBJ(mu, Player(pidL), bj_MOUSEEVENTTYPE_UP)
        TriggerAddAction(md, onMouseDown)
        TriggerAddAction(mu, onMouseUp)

        -- local W key to allow optional snap on move
        local kt = CreateTrigger()
        BlzTriggerRegisterPlayerKeyEvent(kt, Player(pidL), OSKEY_W, 0, true)
        BlzTriggerRegisterPlayerKeyEvent(kt, Player(pidL), OSKEY_W, 0, false)
        TriggerAddAction(kt, onKey)

        TimerStart(CreateTimer(), CAMERA_TICK, true, camTick)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CameraWheelGrid")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
