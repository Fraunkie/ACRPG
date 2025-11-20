if Debug and Debug.beginFile then Debug.beginFile("CameraWheelGrid.lua") end
--==================================================
-- CameraWheelGrid.lua  (v2.2 no-frames)
-- • Third-person camera that hard-locks behind the hero.
-- • RMB = mouse-look (rotates camera + PlayerData.control.yaw).
-- • Mouse wheel zoom between min and max distance.
-- • NO free-look on LMB (disabled for now).
-- • Obeys Direct Mode toggle (PlayerData.control.direct).
--==================================================

do
    --------------------------------------------------
    -- TUNABLES
    --------------------------------------------------
    local CAMERA_TICK           = 0.01

    -- smoothing and follow
    local CAMERA_EASE           = 0.12
    local CAMERA_LEAD           = 0.0

    -- default view
    local DEFAULT_PITCH         = 352.0
    local DEFAULT_DIST          = 460.0

    -- vertical offset for the rig
    local CAMERA_Z_OFFSET       = 140.0

    -- optional unit->camera yaw offset
    local YAW_UNIT_OFFSET       = 0.0

    -- zoom limits
    local DIST_MIN              = DEFAULT_DIST
    local DIST_MAX              = 900.0
    local ZOOM_STEP_WHEEL       = 40.0

    -- mouse sensitivity
    local MOUSE_YAW_SENS        = 0.05
    local MOUSE_PITCH_SENS      = 0.05
    local MOUSE_DEADZONE        = 0.002   -- ~0.8% of screen; real wiggle room

    --------------------------------------------------
    -- STATE
    --------------------------------------------------
    local function PID_LOCAL()
        for i = 0, bj_MAX_PLAYERS - 1 do
            if GetLocalPlayer() == Player(i) then
                return i
            end
        end
        return 0
    end

    local pidL
    -- live (smoothed) camera values
    local yaw, pitch, dist = {}, {}, {}
    -- targets we ease toward
    local tyaw, tpitch, tdist = {}, {}, {}
    local snappedHero = {}

    local holdR = {}

    -- raw mouse tracking (local player only)
    local capturing = false
    local lastX     = nil
    local lastY     = nil

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function PD()
        return rawget(_G, "PlayerData")
    end

    local function ctrl(pid)
        local P = PD()
        return (P and P.GetControl) and P.GetControl(pid) or nil
    end

    local function isDirect(pid)
        local c = ctrl(pid)
        return c and c.direct == true
    end

    local function heroOf(pid)
        local P = PD()
        if P and P.Get then
            local t = P.Get(pid)
            if t and t.hero and GetUnitTypeId(t.hero) ~= 0 then
                return t.hero
            end
        end
        if _G.PlayerHero and PlayerHero[pid] and GetUnitTypeId(PlayerHero[pid]) ~= 0 then
            return PlayerHero[pid]
        end
        return nil
    end

    local function setPDView(pid)
        local c = ctrl(pid)
        if not c then
            return
        end
        c.yaw    = yaw[pid]
        c.pitch  = pitch[pid]
        c.dist   = dist[pid]
        c.height = CAMERA_Z_OFFSET
    end

    local function clamp(v, lo, hi)
        if v < lo then
            return lo
        end
        if v > hi then
            return hi
        end
        return v
    end

    local function wrap360(a)
        if a < 0.0 then
            a = a + 360.0
        end
        if a >= 360.0 then
            a = a - 360.0
        end
        return a
    end

    local function angDelta(from, to)
        local d = wrap360(to) - wrap360(from)
        if d > 180.0 then
            d = d - 360.0
        end
        if d < -180.0 then
            d = d + 360.0
        end
        return d
    end

    local function easeAngle(curr, target, k)
        return wrap360(curr + angDelta(curr, target) * k)
    end

    local function easeLinear(curr, target, k)
        return curr + (target - curr) * k
    end

    local function mouseOverUI()
        local fn = rawget(_G, "BlzGetMouseFocusFrame")
        if type(fn) == "function" then
            return fn() ~= nil
        end
        return false
    end

    local function worldEligible(pid)
        local c = ctrl(pid)
        if not isDirect(pid) then
            return false
        end
        if c and c.uiFocus then
            return false
        end
        if mouseOverUI() then
            return false
        end
        return true
    end

    --------------------------------------------------
    -- APPLY STEP (mouse delta) -> writes TARGETS
    --------------------------------------------------
    local function applyStep(pid, dPitch, dYaw)
        if not isDirect(pid) then
            return
        end
        if not holdR[pid] then
            return
        end
        if not worldEligible(pid) then
            return
        end

        tyaw[pid]   = (tyaw[pid]   ~= nil) and tyaw[pid]   or yaw[pid]   or 0.0
        tpitch[pid] = (tpitch[pid] ~= nil) and tpitch[pid] or pitch[pid] or DEFAULT_PITCH
        tdist[pid]  = (tdist[pid]  ~= nil) and tdist[pid]  or dist[pid]  or DEFAULT_DIST

        tpitch[pid] = clamp(tpitch[pid] + dPitch, 300.0, 360.0)
        tyaw[pid]   = wrap360((tyaw[pid] or 0.0) + dYaw)
    end

    --------------------------------------------------
    -- INPUT (gated by direct mode)
    --------------------------------------------------
    local function beginHold(pid)
        if GetLocalPlayer() ~= Player(pid) then
            return
        end
        if not isDirect(pid) then
            return
        end
        BlzEnableCursor(false)
        EnableDragSelect(false, false)
        capturing = true
        lastX     = nil
        lastY     = nil
    end

    local function endHold(pid)
        if GetLocalPlayer() ~= Player(pid) then
            return
        end
        capturing = false
        lastX     = nil
        lastY     = nil
        BlzEnableCursor(true)
        EnableDragSelect(true, true)
    end

    local function onMouseDown()
        local pid = GetPlayerId(GetTriggerPlayer())
        if not worldEligible(pid) then
            return
        end

        local btn = BlzGetTriggerPlayerMouseButton()
        -- LMB intentionally ignored for now (no free-look)
        if btn == MOUSE_BUTTON_TYPE_RIGHT then
            holdR[pid] = true
        end

        if holdR[pid] then
            beginHold(pid)
        end
    end

    local function onMouseUp()
        local pid = GetPlayerId(GetTriggerPlayer())
        local btn = BlzGetTriggerPlayerMouseButton()

        if btn == MOUSE_BUTTON_TYPE_RIGHT then
            holdR[pid] = false
        end

        if not holdR[pid] then
            endHold(pid)
        end
    end

    -- raw mouse movement -> camera delta
    local function onMouseMove()
        if GetLocalPlayer() ~= GetTriggerPlayer() then
            return
        end

        local pid = pidL
        if not capturing then
            lastX = nil
            lastY = nil
            return
        end
        if not worldEligible(pid) then
            return
        end

        local x = BlzGetTriggerPlayerMouseX()
        local y = BlzGetTriggerPlayerMouseY()

        if lastX == nil or lastY == nil then
            lastX = x
            lastY = y
            return
        end

        local dx = x - lastX
        local dy = y - lastY
        lastX    = x
        lastY    = y

        local adx = dx
        if adx < 0.0 then
            adx = -adx
        end
        local ady = dy
        if ady < 0.0 then
            ady = -ady
        end

        -- little wiggle room before we start turning
        if adx < MOUSE_DEADZONE and ady < MOUSE_DEADZONE then
            return
        end

        if holdR[pid] then
            -- move mouse RIGHT  -> turn camera right
            -- move mouse UP     -> tilt view up
            local dYaw   = -dx * MOUSE_YAW_SENS
            local dPitch =  dy * MOUSE_PITCH_SENS
            applyStep(pid, dPitch, dYaw)
        end
    end

    -- mouse wheel zoom
    local function onWheel()
        if GetLocalPlayer() ~= GetTriggerPlayer() then
            return
        end
        if not isDirect(pidL) then
            return
        end
        if not worldEligible(pidL) then
            return
        end

        local key = BlzGetTriggerPlayerKey()

        tdist[pidL] = (tdist[pidL] ~= nil) and tdist[pidL] or dist[pidL] or DEFAULT_DIST

        if key == OSKEY_MOUSEWHEELUP then
            tdist[pidL] = clamp(tdist[pidL] - ZOOM_STEP_WHEEL, DIST_MIN, DIST_MAX)
        elseif key == OSKEY_MOUSEWHEELDOWN then
            tdist[pidL] = clamp(tdist[pidL] + ZOOM_STEP_WHEEL, DIST_MIN, DIST_MAX)
        end
    end

    --------------------------------------------------
    -- SNAP + HARD ATTACH
    --------------------------------------------------
    local function trySnap(pid)
        if snappedHero[pid] then
            return
        end
        local u = heroOf(pid)
        if not u then
            return
        end
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
            -- direct mode off: fully release local capture and reset holds
            if capturing then
                capturing = false
                lastX = nil
                lastY = nil
                BlzEnableCursor(true)
                EnableDragSelect(true, true)
            end
            holdR[pidL] = false
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

            -- NOTE: we NO LONGER mirror hero facing every tick.
            -- yaw is purely controlled by mouse (RMB).
            -- DirectControlMotor will use yaw to steer the hero.

            -- ease toward targets
            yaw[pidL]   = easeAngle(yaw[pidL]   or tyaw[pidL],   tyaw[pidL],   CAMERA_EASE)
            pitch[pidL] = easeLinear(pitch[pidL] or tpitch[pidL], tpitch[pidL], CAMERA_EASE)
            dist[pidL]  = easeLinear(dist[pidL]  or tdist[pidL],  tdist[pidL],  CAMERA_EASE)

            -- push camera fields
            SetCameraField(CAMERA_FIELD_ROTATION,        yaw[pidL]   or 0.0,           CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, pitch[pidL] or DEFAULT_PITCH, CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, dist[pidL]  or DEFAULT_DIST,  CAMERA_TICK)
            SetCameraField(CAMERA_FIELD_ZOFFSET,         CAMERA_Z_OFFSET,              CAMERA_TICK)

            -- hard attach every tick
            SetCameraTargetController(u, 0.0, 0.0, false)
            SetCameraTargetControllerNoZForPlayer(Player(pidL), u, 0.0, 0.0, false)

            setPDView(pidL)
        end
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    OnInit.final(function()
        pidL = PID_LOCAL()
        pitch[pidL], dist[pidL] = DEFAULT_PITCH, DEFAULT_DIST
        yaw[pidL]   = yaw[pidL] or 0.0
        tyaw[pidL], tpitch[pidL], tdist[pidL] = yaw[pidL], pitch[pidL], dist[pidL]
        setPDView(pidL)

        -- mouse down / up / move for local player
        local md = CreateTrigger()
        local mu = CreateTrigger()
        local mm = CreateTrigger()
        TriggerRegisterPlayerMouseEventBJ(md, Player(pidL), bj_MOUSEEVENTTYPE_DOWN)
        TriggerRegisterPlayerMouseEventBJ(mu, Player(pidL), bj_MOUSEEVENTTYPE_UP)
        TriggerRegisterPlayerMouseEventBJ(mm, Player(pidL), bj_MOUSEEVENTTYPE_MOVE)
        TriggerAddAction(md, onMouseDown)
        TriggerAddAction(mu, onMouseUp)
        TriggerAddAction(mm, onMouseMove)

        -- mouse wheel zoom
        local wt = CreateTrigger()
        BlzTriggerRegisterPlayerKeyEvent(wt, Player(pidL), OSKEY_MOUSEWHEELUP, 0, true)
        BlzTriggerRegisterPlayerKeyEvent(wt, Player(pidL), OSKEY_MOUSEWHEELDOWN, 0, true)
        TriggerAddAction(wt, onWheel)

        TimerStart(CreateTimer(), CAMERA_TICK, true, camTick)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CameraWheelGrid")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
