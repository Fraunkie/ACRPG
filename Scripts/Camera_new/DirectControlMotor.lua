if Debug and Debug.beginFile then Debug.beginFile("DirectControlMotor.lua") end
--@@debug
--==================================================
-- DirectControlMotor.lua  (v1.54)
-- Movement/camera behavior: same as v1.52
-- NEW: Animations routed through AnimRegistry + AnimControl
--  • Idle      -> AnimRegistry.PlayIdle(u)
--  • Walk/Back -> AnimRegistry.PlayWalk(u)
--  • Strafe    -> AnimRegistry.PlayWalk(u)
--  • Honors AnimControl.IsMuted(pid) and keeps timescale sync
--  • Small debounce to avoid re-sending same anim every frame
-- No percent symbols anywhere.
--==================================================

do
    --------------------------------------------------
    -- EDITABLE CONSTANTS
    --------------------------------------------------
    -- Simulation tick rate (seconds)
    local DT = 0.01

    -- Movement speed scales (relative to engine unit Move Speed)
    local FORWARD_SPEED_SCALE   = 1.00
    local BACKWARD_SPEED_SCALE  = 0.60
    local STRAFE_SPEED_SCALE    = 0.90

    -- Turn rates in degrees per second (when RMB NOT held)
    local TURN_RATE_IDLE        = 550.0
    local TURN_RATE_MOVING      = 550.0

    -- How fast unit aligns to camera yaw while RMB held
    local MOUSE_TURN_RATE       = 1500.0  -- degrees per second

    -- Flip A/D behavior if needed (false = A left, D right)
    local AD_INVERT             = true

    -- Input / UI rules
    local HONOR_UI_FOCUS        = true    -- ignore input when PlayerData.control.uiFocus == true
    local CANCEL_GROUND_MOVE    = true    -- cancel WC3 right-click move orders in direct mode

    -- Use local camera rotation if PD.control.yaw missing
    local USE_CAMERA_YAW_FALLBACK = true

    -- Animation behavior
    local ANIM_DEBOUNCE_SEC     = 0.12    -- minimum time between identical state replays
    local SYNC_TIMESCALE_WHILE_MOVING = true

    --------------------------------------------------
    -- INTERNAL STATE
    --------------------------------------------------
    local holdW, holdA, holdS, holdD = {}, {}, {}, {}
    local rmbDown = {}

    -- animation state tracking per player
    local lastKind  = {}   -- "idle","walk","back","strafeL","strafeR"
    local lastStamp = {}   -- os.clock at last animation play

    --------------------------------------------------
    -- HELPERS
    --------------------------------------------------
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end

    local function PD() return rawget(_G, "PlayerData") end
    local function PDC(pid)
        local P = PD(); return (P and P.GetControl) and P.GetControl(pid) or nil
    end
    local function isDirect(pid)
        local c = PDC(pid); return c and c.direct == true
    end
    local function uiFocus(pid)
        if not HONOR_UI_FOCUS then return false end
        local c = PDC(pid); return c and (c.uiFocus == true) or false
    end

    local function hero(pid)
        local P = PD()
        if P and P.Get then
            local t = P.Get(pid)
            if t and valid(t.hero) then return t.hero end
        end
        if _G.PlayerHero and valid(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    local function mouseOverUI()
        local fn = rawget(_G, "BlzGetMouseFocusFrame")
        if type(fn) == "function" then return fn() ~= nil end
        return false
    end

    local function wrap360(a)
        if a < 0.0 then a = a + 360.0 end
        if a >= 360.0 then a = a - 360.0 end
        return a
    end
    local function shortestArcDeg(a, b)
        local d = b - a
        if d > 180.0 then d = d - 360.0 end
        if d < -180.0 then d = d + 360.0 end
        return d
    end

    local function cameraYawDeg(pid)
        local c = PDC(pid)
        local y = c and c.yaw
        if type(y) == "number" then return wrap360(y) end
        if USE_CAMERA_YAW_FALLBACK and GetLocalPlayer() == Player(pid) then
            local rot = GetCameraField(CAMERA_FIELD_ROTATION) or 0.0
            return wrap360(rot)
        end
        local u = hero(pid); if u then return GetUnitFacing(u) end
        return 0.0
    end

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    local function syncTimescale(u)
        if not SYNC_TIMESCALE_WHILE_MOVING then return end
        local cur, def = GetUnitMoveSpeed(u), GetUnitDefaultMoveSpeed(u)
        if def and def > 0 then SetUnitTimeScale(u, cur/def) end
    end

    --------------------------------------------------
    -- ANIMATION ADAPTER (AnimRegistry + AnimControl)
    --------------------------------------------------
    local function playAnim(pid, u, kind)
        -- guard: muted or on hold
        local ACtl = rawget(_G, "AnimControl")
        if ACtl and ACtl.IsMuted and ACtl.IsMuted(pid) then
            return
        end

        -- debounce identical state
        local t = now()
        local prev = lastKind[pid]
        local ps   = lastStamp[pid] or 0
        if prev == kind and (t - ps) < ANIM_DEBOUNCE_SEC then
            return
        end
        lastKind[pid]  = kind
        lastStamp[pid] = t

        local AR = rawget(_G, "AnimRegistry")

        -- Choose registry call
        if kind == "idle" then
            if AR and AR.PlayIdle then AR.PlayIdle(u) else SetUnitAnimation(u, "stand") end
            return
        end

        -- We map walk/back/strafe to PlayWalk for now
        if AR and AR.PlayWalk then
            AR.PlayWalk(u)
        else
            SetUnitAnimation(u, "walk")
        end
    end

    -- Function to simulate jump by moving the hero up and down
    local function startJump(pid)
    local unit = PlayerData.GetHero(pid)  -- Get the player's hero unit
    if not unit then return end

    local jumpHeight = 225  -- The height to raise the hero (adjust as needed)
    local jumpDuration = 0.30  -- Duration of the jump in seconds (lower = faster)
    local fallSpeed = 5.00    -- Speed at which the unit will fall back down (higher = faster)
    PlayerData.isJumping = true

    -- Add Crow Form to enable flying (required for SetUnitFlyHeight)
    UnitAddAbility(unit, FourCC('Amrf'))  -- 'Amrf' is the rawcode for Crow Form

    local currentHeight = 0  -- Start from ground level
    local increment = jumpHeight / (jumpDuration / DT)  -- How much to raise per tick

    -- Use a timer to gradually raise the unit's height
    local riseTimer = CreateTimer()
    TimerStart(riseTimer, DT, true, function()
        -- Increase height incrementally
        currentHeight = currentHeight + increment

        -- Set the unit's fly height to the current height
        SetUnitFlyHeight(unit, currentHeight, 0)

        -- Check if the unit has reached the target height
        if currentHeight >= jumpHeight then
            -- Once the jump reaches the desired height, start the fall immediately
            DestroyTimer(riseTimer)  -- Stop the rise timer

            -- Immediately start the fall after the rise completes
            TimerStart(CreateTimer(), DT, true, function()
                -- Gradually decrease height for falling
                currentHeight = currentHeight - fallSpeed
                SetUnitFlyHeight(unit, currentHeight, 0)

                -- After falling, reset the height back to 0 (ground level)
                if currentHeight <= 0 then
                    SetUnitFlyHeight(unit, 0, 0)  -- Return to ground level
                    UnitRemoveAbility(unit, FourCC('Amrf'))  -- Remove Crow Form after jump
                    DestroyTimer(GetExpiredTimer())
                    PlayerData.isJumping = false-- Stop the fall timer
                end
            end)
        end
    end)
end
    --------------------------------------------------
    -- INPUT
    --------------------------------------------------
    local function onKey(pid, key, isDown)
        if key == OSKEY_W then holdW[pid] = isDown
        elseif key == OSKEY_S then holdS[pid] = isDown
        elseif key == OSKEY_A then holdA[pid] = isDown
        elseif key == OSKEY_D then holdD[pid] = isDown
        end
    end
    -- Define the sbpress table
    local sbpress = {
        isdown = false,      -- Tracks if spacebar is pressed
        jumpstart = false    -- Tracks if the jump has started
    }

    -- Function to handle spacebar press logic
    local function onSBKey(pid, key, isDown)
        if key == OSKEY_SPACE then
            sbpress.isdown = isDown  -- Update spacebar press state
            
            if isDown then
                -- Check if jump has already started
                if not sbpress.jumpstart then
                    sbpress.jumpstart = true  -- Mark jump as started
                        -- Or display a message, etc.
                    startJump(pid)  -- Call the function to initiate jump
                end
            else
                -- Reset jump start when space is released (if needed)
                sbpress.jumpstart = false
            end
        end
    end


    local function onMouse(pid, btn, isDown)
        if btn ~= MOUSE_BUTTON_TYPE_RIGHT then return end
        rmbDown[pid] = isDown and true or false
        if CANCEL_GROUND_MOVE and isDown and isDirect(pid) and not mouseOverUI() then
            local u = hero(pid)
            if u then IssueImmediateOrder(u, "stop") end
        end
    end

    --------------------------------------------------
    -- CORE TICK (movement/camera unchanged from v1.52)
    --------------------------------------------------
    local function tickAll()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) ~= MAP_CONTROL_USER then goto continue end
            if not isDirect(pid) then goto continue end
            if uiFocus(pid) then goto continue end

            local u = hero(pid); if not valid(u) then goto continue end
            local base = GetUnitMoveSpeed(u); if base <= 0 then base = 220 end

            local fdeg = GetUnitFacing(u) * bj_DEGTORAD
            local fx, fy = Cos(fdeg), Sin(fdeg)
            local rx, ry = Cos(fdeg + bj_PI/2), Sin(fdeg + bj_PI/2)

            local vx, vy = 0.0, 0.0
            local movingNow = false
            local moveKind = "idle"


            -- W/S
            if holdW[pid] then
                vx = vx + fx * base * FORWARD_SPEED_SCALE
                vy = vy + fy * base * FORWARD_SPEED_SCALE
                movingNow = true
                moveKind = "walk"
            end
            if holdS[pid] then
                vx = vx - fx * base * BACKWARD_SPEED_SCALE
                vy = vy - fy * base * BACKWARD_SPEED_SCALE
                movingNow = true
                moveKind = "back"
            end

            -- RMB steering: face camera yaw
            if rmbDown[pid] then
                local face      = GetUnitFacing(u)
                local targetYaw = cameraYawDeg(pid)
                local d         = shortestArcDeg(face, targetYaw)
                local step      = MOUSE_TURN_RATE * DT
                if d > step then
                    SetUnitFacingTimed(u, face + step, DT)
                elseif d < -step then
                    SetUnitFacingTimed(u, face - step, DT)
                else
                    SetUnitFacingTimed(u, targetYaw, DT)
                end
            end

            -- A/D
            local invert = AD_INVERT and -1.0 or 1.0
            if rmbDown[pid] then
                -- STRAFE (RMB held)
                if holdA[pid] and not holdD[pid] then
                    vx = vx - invert * rx * base * STRAFE_SPEED_SCALE
                    vy = vy - invert * ry * base * STRAFE_SPEED_SCALE
                    movingNow = true
                    moveKind = "strafeL"
                elseif holdD[pid] and not holdA[pid] then
                    vx = vx + invert * rx * base * STRAFE_SPEED_SCALE
                    vy = vy + invert * ry * base * STRAFE_SPEED_SCALE
                    movingNow = true
                    moveKind = "strafeR"
                end
            else
                -- TURN (RMB up)
                if holdA[pid] ~= holdD[pid] then
                    local rate = movingNow and TURN_RATE_MOVING or TURN_RATE_IDLE
                    local dir  = (holdD[pid] and 1.0 or -1.0) * invert
                    SetUnitFacingTimed(u, GetUnitFacing(u) + dir * rate * DT, DT)
                end
            end

            -- Apply movement with simple collision fallback
            if movingNow then
                local ox, oy = GetUnitX(u), GetUnitY(u)
                local nx, ny = ox + vx * DT, oy + vy * DT
                SetUnitPosition(u, nx, ny)
                if RAbsBJ(GetUnitX(u) - nx) > 0.5 or RAbsBJ(GetUnitY(u) - ny) > 0.5 then
                    SetUnitPosition(u, nx, oy)
                    local okX = RAbsBJ(GetUnitX(u) - nx) <= 0.5
                    SetUnitPosition(u, ox, ny)
                    local okY = RAbsBJ(GetUnitY(u) - ny) <= 0.5
                    if okX and not okY then
                        SetUnitPosition(u, nx, oy)
                    elseif okY and not okX then
                        SetUnitPosition(u, ox, ny)
                    else
                        SetUnitPosition(u, ox, oy)
                    end
                end
            end

            -- Animations (registry + control)
            local prev = lastKind[pid] or "idle"
            if movingNow then
                -- Issue play only on transitions or after debounce, also keep timescale syncing
                if moveKind ~= prev then
                    playAnim(pid, u, moveKind)
                else
                    syncTimescale(u)
                end
            else
                if prev ~= "idle" then
                    playAnim(pid, u, "idle")
                end
            end

            ::continue::
        end
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local p = Player(pid)

            -- WASD keys
            local k = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_W, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_W, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_A, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_A, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_S, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_S, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_D, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(k, p, OSKEY_D, 0, false)
            TriggerAddAction(k, function()
                onKey(pid, BlzGetTriggerPlayerKey(), BlzGetTriggerPlayerIsKeyDown())
            end)
            ------------------------------------------------
            ---SpaceBar
            ------------------------------------------------
            local sb = CreateTrigger()

            BlzTriggerRegisterPlayerKeyEvent(sb, p, OSKEY_SPACE, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(sb, p, OSKEY_SPACE, 0, true)
            TriggerAddAction(sb, function()
                onSBKey(pid, BlzGetTriggerPlayerKey(), BlzGetTriggerPlayerIsKeyDown())
            end)




            -- RMB down/up
            local md = CreateTrigger()
            local mu = CreateTrigger()
            TriggerRegisterPlayerMouseEventBJ(md, p, bj_MOUSEEVENTTYPE_DOWN)
            TriggerRegisterPlayerMouseEventBJ(mu, p, bj_MOUSEEVENTTYPE_UP)
            TriggerAddAction(md, function()
                if BlzGetTriggerPlayerMouseButton() == MOUSE_BUTTON_TYPE_RIGHT then
                    onMouse(pid, MOUSE_BUTTON_TYPE_RIGHT, true)
                end
            end)
            TriggerAddAction(mu, function()
                if BlzGetTriggerPlayerMouseButton() == MOUSE_BUTTON_TYPE_RIGHT then
                    onMouse(pid, MOUSE_BUTTON_TYPE_RIGHT, false)
                end
            end)
        end

        TimerStart(CreateTimer(), DT, true, tickAll)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("DirectControlMotor")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
