if Debug and Debug.beginFile then Debug.beginFile("DirectControlMotor.lua") end
--==================================================
-- DirectControlMotor.lua
-- Version: v1.50 (auto-direct & disable command card on start)
-- WASD movement, RMB strafe, shoulder camera
--==================================================

do
    local DT = 0.03
    local SPEED_MULT_FWD, SPEED_MULT_BACK, SPEED_MULT_STRAFE = 1.00, 0.62, 0.90
    local TURN_DEG_PER_SEC = 300.0

    local CAM_DIST_DEFAULT, MIN_CAM_DIST, MAX_CAM_DIST = 460.0, 360.0, 600.0
    local CAM_AOA_DEFAULT, CAM_ZOFFSET, CAM_LERP_TIME = 352.0, 140.0, 0.10

    -- Long draw distance so sky/horizon render
    local FARZ = 10000.0

    local ORDER_GRACE_TICKS = 8

    local function clamp(v, lo, hi) if v<lo then return lo elseif v>hi then return hi else return v end end
    local function validUnit(u) return u and GetUnitTypeId(u)~=0 and not IsUnitType(u, UNIT_TYPE_DEAD) end
    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]; if not pd then return end
        pd.control = pd.control or {
            direct=false, holdW=false, holdA=false, holdS=false, holdD=false,
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil,
            orderGrace=0, isMoving=false, idleDelay=0
        }
        return pd.control, pd
    end

    -- Per-player enable/disable of the stock command buttons (safe + local)
    local function setCommandCardEnabled(pid, enabled)
        if GetLocalPlayer() ~= Player(pid) then return end
        -- Buttons 0..11 (grid), plus basic (move/stop/etc.) occupy the same range.
        for i = 0, 11 do
            local h = BlzGetFrameByName("CommandButton_"..i, 0)
            if h then
                BlzFrameSetEnable(h, enabled)
                BlzFrameSetVisible(h, enabled)
            end
        end
        -- If you also want to neuter inventory clicks (kept visible elsewhere), guard here:
        -- for i=0,5 do local inv = BlzGetFrameByName("InventoryButton_"..i,0); if inv then BlzFrameSetEnable(inv, enabled) end end
    end

    -- Centralized toggle so O-key and auto-start use the same path
    local function setDirectMode(pid, enabled)
        local c = ensureControl(pid); if not c then return end
        c.direct = enabled and true or false
        -- Disable command card when entering direct mode; re-enable when leaving
        setCommandCardEnabled(pid, not c.direct)
    end

    local function clearTags(u)
        if _G.AnimRegistry and AnimRegistry.ClearCommonTags then
            AnimRegistry.ClearCommonTags(u)
        end
    end
    local function playWalk(u)
        clearTags(u)
        if _G.AnimRegistry and AnimRegistry.PlayWalk then AnimRegistry.PlayWalk(u)
        else SetUnitAnimation(u, "Walk"); SetUnitTimeScale(u, 1.0); SetUnitAnimation(u, "walk") end
    end
    local function playIdle(u)
        clearTags(u)
        if _G.AnimRegistry and AnimRegistry.PlayIdle then AnimRegistry.PlayIdle(u)
        else SetUnitAnimation(u, "Stand"); SetUnitTimeScale(u, 1.0); SetUnitAnimation(u, "stand") end
    end

    local function setMoving(u, pid, c, moving)
        if moving then
            if not c.isMoving then
                c.isMoving  = true
                c.idleDelay = 6
                if (c.orderGrace or 0) <= 0 then IssueImmediateOrder(u, "stop") end
                ResetUnitAnimation(u)
                if not (AnimControl and AnimControl.IsMuted and AnimControl.IsMuted(pid)) then
                    playWalk(u)
                end
            else
                c.idleDelay = 6
            end
        else
            if c.isMoving then
                c.isMoving = false
                ResetUnitAnimation(u)
            end
            if c.idleDelay and c.idleDelay > 0 then
                c.idleDelay = c.idleDelay - 1
            else
                if not (AnimControl and AnimControl.IsMuted and AnimControl.IsMuted(pid)) then
                    playIdle(u)
                end
            end
        end
    end

    local function tick(pid)
        local c, pd = ensureControl(pid); if not c or not c.direct then return end
        local u = pd.hero; if not validUnit(u) then return end

        local facing = GetUnitFacing(u)
        local yawRad = facing * bj_DEGTORAD
        local base = GetUnitMoveSpeed(u); if base<=0 then base=300.0 end

        local dx, dy, moved = 0.0, 0.0, false

        if c.holdW then
            dx, dy, moved = dx + base*SPEED_MULT_FWD*math.cos(yawRad), dy + base*SPEED_MULT_FWD*math.sin(yawRad), true
        elseif c.holdS then
            dx, dy, moved = dx - base*SPEED_MULT_BACK*math.cos(yawRad), dy - base*SPEED_MULT_BACK*math.sin(yawRad), true
        end

        if c.rmb then
            local side = (facing - 90.0)*bj_DEGTORAD
            if c.holdA then dx, dy, moved = dx - base*SPEED_MULT_STRAFE*math.cos(side), dy - base*SPEED_MULT_STRAFE*math.sin(side), true
            elseif c.holdD then dx, dy, moved = dx + base*SPEED_MULT_STRAFE*math.cos(side), dy + base*SPEED_MULT_STRAFE*math.sin(side), true end
        else
            local step = TURN_DEG_PER_SEC*DT
            if c.holdA then SetUnitFacing(u, facing + step) end
            if c.holdD then SetUnitFacing(u, facing - step) end
        end

        if moved then
            SetUnitPosition(u, GetUnitX(u)+dx*DT, GetUnitY(u)+dy*DT)
            setMoving(u, pid, c, true)
        else
            setMoving(u, pid, c, false)
        end

        if c.orderGrace and c.orderGrace>0 then c.orderGrace = c.orderGrace-1 end

        if GetLocalPlayer()==Player(pid) then
            SetCameraTargetController(u, 0.0, 0.0, false)
            SetCameraField(CAMERA_FIELD_FARZ, FARZ, CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ROTATION,        GetUnitFacing(u), CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, clamp(CAM_DIST_DEFAULT, MIN_CAM_DIST, MAX_CAM_DIST), CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, CAM_AOA_DEFAULT,  CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ZOFFSET,         CAM_ZOFFSET,      CAM_LERP_TIME)
        end
    end

    OnInit.final(function()
        -- Start ticking logic
        local t = CreateTimer()
        TimerStart(t, DT, true, function()
            for pid=0, bj_MAX_PLAYER_SLOTS-1 do tick(pid) end
        end)

        -- When RMB is released, give a brief grace period before issuing native orders
        if _G.ProcBus and ProcBus.On then
            ProcBus.On("RightMouseReleased", function(p)
                if type(p)=="table" and type(p.pid)=="number" then
                    local c = ensureControl(p.pid); if c then c.orderGrace = ORDER_GRACE_TICKS end
                end
            end)
            -- Let the O-key toggle reuse our unified setter
            ProcBus.On("DirectControlToggled", function(e)
                if not e or type(e.pid)~="number" then return end
                setDirectMode(e.pid, e.enabled and true or false)
            end)
        end

        -- Auto-enter direct mode on game start for all user-controlled players
        for pid=0, bj_MAX_PLAYER_SLOTS-1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                setDirectMode(pid, true)
            end
        end

        if rawget(_G,"InitBroker") and InitBroker.SystemReady then InitBroker.SystemReady("DirectControlMotor") end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
