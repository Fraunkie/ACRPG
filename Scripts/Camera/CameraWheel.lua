if Debug and Debug.beginFile then Debug.beginFile("CameraWheel.lua") end
--==================================================
-- CameraWheel.lua  v1.15
-- Classic 3rd-Person Camera (JASS-style) with:
-- • True mouse-delta look (no auto-spin)
-- • Deadzone + clamp + smoothing + click-suppression
-- • Centered behind hero (no shoulder)
-- • L+R zoom DISABLED
-- • Selection + RMB orders suppressed while looking
-- • Idle recenter after a short grace period
-- • Terrain-aware via GetLocZ (precomputed map height compatible)
--==================================================

CameraWheel = CameraWheel or {}
_G.CameraWheel = CameraWheel

do
    --------------------------------------------------
    -- CONFIGURATION — edit these freely
    --------------------------------------------------
    -- Distance / angle (baseline)
    local DIST_MIN            = 360.0
    local DIST_MAX            = 600.0
    local DEFAULT_DIST        = 460.0
    local DEFAULT_PITCH       = 352.0
    local PITCH_MIN           = 348.0
    local PITCH_MAX           = 356.0

    -- Height handling (baseline vs final eye lift)
    local HEIGHT_TERRAIN      = -180.0
    local EYE_LIFT            = -220.0

    -- Camera feel
    local CAM_SMOOTH          = 0.20
    local FOV                 = 100.0
    local FACE_RATE           = 0.00   -- 0 = instant hero face-turn while RMB

    -- Mouse-look shaping
    local LMB_SENS            = 0.045  -- deg per pixel (camera-only look)
    local RMB_SENS            = 0.030  -- deg per pixel (hero-turn look)
    local DEADZONE_PX         = 8      -- ignore |dx| below this (prevents drift on click/hold)
    local MAX_PX              = 12     -- clamp per-move |dx|
    local YAW_SMOOTH          = 0.28   -- 0..1, lerp toward target yaw (higher = snappier)

    -- Click suppression (prevents the initial jump when you press but don’t move)
    local CLICK_SUPPRESS_TIME = 0.12   -- seconds to ignore deltas right after mouse-down

    -- Idle recenter (prevents snap-back flicker on brief releases)
    local IDLE_RECENTER_DELAY = 0.12   -- seconds after last held before recentering to hero

    -- Cursor recenter policy
    local RECENTER_MODE       = "timed"   -- "every-move" | "timed"
    local RECENTER_PERIOD     = 0.016     -- seconds (only if "timed")
    local CENTER_ON_DOWN      = true      -- immediately center on mouse-down

    -- Terrain clearance behavior
    local TERRAIN_BUFFER      = 40.0
    local TERRAIN_MARGIN      = 25.0

    -- Selection / RMB order suppression while looking
    local SUPPRESS_SELECTION_WHILE_HELD = true
    local SUPPRESS_RMB_ORDERS           = true

    -- Update cadence
    local UPDATE_INTERVAL     = 0.01   -- camera application tick
    local INPUT_INTERVAL      = 0.02   -- safety tick (keeps cursor hidden / consumes RMB)

    --------------------------------------------------
    -- Internal state
    --------------------------------------------------
    local isLeft, isRight     = {}, {}
    local yaw, pitch          = {}, {}
    local dist, curDist       = {}, {}
    local anyHeld             = {}
    local lastHeldAt          = {}   -- os.clock: last frame a button was held
    local lastRecenterAt      = {}   -- os.clock: last cursor recenter
    local suppressUntil       = {}   -- os.clock: ignore deltas until this time

    -- helpers
    local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
    local function wrap360(a) if a >= 360.0 then return a - 360.0 elseif a < 0.0 then return a + 360.0 else return a end end
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function heroOf(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if pd and valid(pd.hero) then return pd.hero end
        if _G.PlayerHero and valid(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end
    local function now() if os and os.clock then return os.clock() end return 0.0 end
    local function shortestDeltaDeg(a, b) local d = (b - a + 540.0) % 360.0 - 180.0; return d end

    --------------------------------------------------
    -- Selection/command suppression
    --------------------------------------------------
    local lockDepth = {}
    local function lockSelection(pid, hero)
        if not SUPPRESS_SELECTION_WHILE_HELD then return end
        lockDepth[pid] = (lockDepth[pid] or 0) + 1
        if lockDepth[pid] == 1 then
            BlzEnableSelections(false, true)
            BlzEnableTargetIndicator(false)
        end
        if hero then
            ClearSelection()
            SelectUnitForPlayerSingle(hero, Player(pid))
        end
    end
    local function unlockSelection(pid)
        if not SUPPRESS_SELECTION_WHILE_HELD then return end
        lockDepth[pid] = math.max(0, (lockDepth[pid] or 0) - 1)
        if lockDepth[pid] == 0 then
            BlzEnableSelections(true,  true)
            BlzEnableTargetIndicator(true)
        end
    end
    local function suppressRMB(pid, hero)
        if not SUPPRESS_RMB_ORDERS then return end
        if hero and valid(hero) and BlzGetMouseFocusUnit() == nil then
            IssueImmediateOrder(hero, "stop") -- consume default right-click move
        end
    end

    --------------------------------------------------
    -- Mouse button handlers
    --------------------------------------------------
    local function onMouseDown()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p)
        local btn = BlzGetTriggerPlayerMouseButton()
        local u   = heroOf(pid)

        if btn == MOUSE_BUTTON_TYPE_LEFT  then isLeft[pid]  = true end
        if btn == MOUSE_BUTTON_TYPE_RIGHT then isRight[pid] = true end

        anyHeld[pid]      = isLeft[pid] or isRight[pid]
        lastHeldAt[pid]   = now()
        suppressUntil[pid]= lastHeldAt[pid] + CLICK_SUPPRESS_TIME

        if anyHeld[pid] then
            if GetLocalPlayer() == p and BlzGetMouseFocusUnit() == nil then
                BlzEnableCursor(false)
                if CENTER_ON_DOWN then
                    BlzSetMousePos(BlzGetLocalClientWidth()/2, BlzGetLocalClientHeight()/2)
                    lastRecenterAt[pid] = now()
                end
            end
            lockSelection(pid, u)
            if isRight[pid] then suppressRMB(pid, u) end
        end
    end

    local function onMouseUp()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p)
        local btn = BlzGetTriggerPlayerMouseButton()

        if btn == MOUSE_BUTTON_TYPE_LEFT  then isLeft[pid]  = false end
        if btn == MOUSE_BUTTON_TYPE_RIGHT then isRight[pid] = false end

        anyHeld[pid] = isLeft[pid] or isRight[pid]
        if not anyHeld[pid] then
            if GetLocalPlayer() == p then BlzEnableCursor(true) end
        end
        unlockSelection(pid)
    end

    --------------------------------------------------
    -- Mouse move → yaw delta (with deadzone, clamp, smoothing, suppression)
    --------------------------------------------------
    local function onMouseMove()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p)
        if not (isLeft[pid] or isRight[pid]) then return end

        -- Suppress initial deltas right after mouse-down
        if now() < (suppressUntil[pid] or 0.0) then return end

        -- pixel delta relative to screen center
        local mx  = BlzGetTriggerPlayerMouseX()
        local cx  = BlzGetLocalClientWidth()/2
        local dx  = mx - cx

        -- deadzone + clamp
        local adx = math.abs(dx)
        if adx < DEADZONE_PX then
            lastHeldAt[pid] = now()
            return
        end
        if dx > 0 then dx = math.min(dx,  MAX_PX) else dx = -math.min(adx, MAX_PX) end

        -- sensitivity: RMB calmer
        local sens   = (isRight[pid] and not isLeft[pid]) and RMB_SENS or LMB_SENS
        local current= yaw[pid] or 0.0
        local target = wrap360(current - dx * sens)

        -- smooth toward target
        local delta  = shortestDeltaDeg(current, target)
        yaw[pid]     = wrap360(current + delta * YAW_SMOOTH)
        lastHeldAt[pid] = now()

        -- recenter policy
        if GetLocalPlayer() == p then
            if RECENTER_MODE == "every-move" then
                BlzSetMousePos(cx, BlzGetLocalClientHeight()/2)
                lastRecenterAt[pid] = now()
            else
                local t = now()
                if (t - (lastRecenterAt[pid] or 0)) >= RECENTER_PERIOD then
                    BlzSetMousePos(cx, BlzGetLocalClientHeight()/2)
                    lastRecenterAt[pid] = t
                end
            end
        end
    end

    --------------------------------------------------
    -- Safety input tick (keeps cursor hidden / consumes RMB while held)
    --------------------------------------------------
    local function inputTick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if anyHeld[pid] then
                local p = Player(pid)
                if GetLocalPlayer() == p then
                    BlzEnableCursor(false)
                end
                if isRight[pid] then
                    suppressRMB(pid, heroOf(pid))
                end
            end
        end
    end

    --------------------------------------------------
    -- Camera tick (terrain-aware, centered behind hero)
    --------------------------------------------------
    local function camTick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local u = heroOf(pid)
            if not u then goto continue end

            yaw[pid]   = yaw[pid]   or GetUnitFacing(u)
            pitch[pid] = clamp(pitch[pid] or DEFAULT_PITCH, PITCH_MIN, PITCH_MAX)
            dist[pid]  = clamp(dist[pid]  or DEFAULT_DIST,  DIST_MIN,  DIST_MAX)
            curDist[pid] = curDist[pid] or dist[pid]

            -- Recenter behind hero only after a small idle delay
            if not isLeft[pid] and not isRight[pid] then
                local tlast = lastHeldAt[pid] or 0.0
                if (now() - tlast) >= IDLE_RECENTER_DELAY then
                    yaw[pid] = GetUnitFacing(u)
                end
            end

            -- RMB-only: have hero face camera yaw
            if isRight[pid] and not isLeft[pid] then
                SetUnitFacingTimed(u, yaw[pid], FACE_RATE)
            end

            -- Terrain-aware heights via GetLocZ
            local ux, uy = GetUnitX(u), GetUnitY(u)
            local z1 = GetLocZ(ux, uy)

            local ox = ux - curDist[pid] * Cos(yaw[pid]*bj_DEGTORAD) * Cos(-pitch[pid]*bj_DEGTORAD)
            local oy = uy - curDist[pid] * Sin(yaw[pid]*bj_DEGTORAD) * Cos(-pitch[pid]*bj_DEGTORAD)
            local z2 = GetLocZ(ox, oy)

            -- Baseline offset for clearance math
            local zoffset_base = z1 + HEIGHT_TERRAIN
            local H = (curDist[pid] * Sin(pitch[pid]*bj_DEGTORAD) - zoffset_base + z2) * (-1)

            -- Distance slide to respect terrain
            if H < 0 and curDist[pid] - TERRAIN_BUFFER > DIST_MIN then
                curDist[pid] = curDist[pid] - TERRAIN_BUFFER
            elseif curDist[pid] < dist[pid] and H > TERRAIN_MARGIN then
                curDist[pid] = curDist[pid] + TERRAIN_BUFFER
            elseif curDist[pid] > dist[pid] then
                curDist[pid] = curDist[pid] - TERRAIN_BUFFER
            end

            if GetLocalPlayer() == Player(pid) then
                SetCameraField(CAMERA_FIELD_ZOFFSET,         zoffset_base + EYE_LIFT, CAM_SMOOTH)
                SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, pitch[pid],              CAM_SMOOTH)
                SetCameraField(CAMERA_FIELD_ROTATION,        yaw[pid],                CAM_SMOOTH)
                SetCameraField(CAMERA_FIELD_FIELD_OF_VIEW,   FOV,                     CAM_SMOOTH)
                SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, curDist[pid],            CAM_SMOOTH)
                SetCameraTargetController(u, 0.0, 0.0, false)
                CameraSetSmoothingFactor(1)
            end
            ::continue::
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function CameraWheel.IsLeft(pid)   return isLeft[pid]  and true or false end
    function CameraWheel.IsRight(pid)  return isRight[pid] and true or false end
    function CameraWheel.GetYaw(pid)   return yaw[pid]     or 0.0 end
    function CameraWheel.GetPitch(pid) return pitch[pid]   or DEFAULT_PITCH end
    function CameraWheel.GetDist(pid)  return curDist[pid] or dist[pid] or DEFAULT_DIST end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- Strongly discourage drag selection globally
        EnableDragSelect(false, false)

        -- Mouse down/up
        local md, mu = CreateTrigger(), CreateTrigger()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerMouseEventBJ(md, Player(pid), bj_MOUSEEVENTTYPE_DOWN)
            TriggerRegisterPlayerMouseEventBJ(mu, Player(pid), bj_MOUSEEVENTTYPE_UP)
        end
        TriggerAddAction(md, onMouseDown)
        TriggerAddAction(mu, onMouseUp)

        -- True mouse-delta look
        local mm = CreateTrigger()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerEvent(mm, Player(pid), EVENT_PLAYER_MOUSE_MOVE)
        end
        TriggerAddAction(mm, onMouseMove)

        -- Ticks
        TimerStart(CreateTimer(), UPDATE_INTERVAL, true, camTick)
        TimerStart(CreateTimer(), INPUT_INTERVAL,  true, inputTick)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CameraWheel")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
