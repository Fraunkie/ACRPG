if Debug and Debug.beginFile then Debug.beginFile("DirectControlMotor.lua") end
--==================================================
-- DirectControlMotor.lua
-- Version: v1.62 (WC3-safe, no percent symbols)
--==================================================

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local DT = 0.03
    local SPEED_MULT_FWD    = 1.00
    local SPEED_MULT_BACK   = 0.62
    local SPEED_MULT_STRAFE = 0.90
    local TURN_DEG_PER_SEC  = 300.0

    local CAM_DIST_DEFAULT  = 460.0
    local MIN_CAM_DIST      = 360.0
    local MAX_CAM_DIST      = 600.0
    local CAM_AOA_DEFAULT   = 352.0
    local CAM_ZOFFSET       = 140.0
    local CAM_LERP_TIME     = 0.10
    local FARZ              = 10000.0
    local ORDER_GRACE_TICKS = 8
    local DEBUG = false

    --------------------------------------------------
    local function dbg(pid, msg)
        if not DEBUG then return end
        if GetLocalPlayer() ~= Player(pid) then return end
        DisplayTextToPlayer(Player(pid), 0, 0, "[Motor] " .. tostring(msg))
    end

    local function clamp(v, lo, hi)
        if v < lo then return lo elseif v > hi then return hi else return v end
    end

    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and not IsUnitType(u, UNIT_TYPE_DEAD)
    end

    local function heroOf(pid)
        if _G.PLAYER_DATA and PLAYER_DATA[pid] and validUnit(PLAYER_DATA[pid].hero) then
            return PLAYER_DATA[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]; if not pd then return nil end
        pd.control = pd.control or {}
        local c = pd.control
        c.direct = c.direct or false
        c.holdW, c.holdA, c.holdS, c.holdD = c.holdW or false, c.holdA or false, c.holdS or false, c.holdD or false
        c.rmb, c.lmb = c.rmb or false, c.lmb or false
        c.camYawOffset = c.camYawOffset or 0.0
        c.camPitchOffset = c.camPitchOffset or 0.0
        c.camDist = c.camDist or CAM_DIST_DEFAULT
        c.orderGrace = c.orderGrace or 0
        c.isMoving = c.isMoving or false
        c.idleDelay = c.idleDelay or 0
        return c, pd
    end

    local function setCommandCardEnabled(pid, enabled)
        if GetLocalPlayer() ~= Player(pid) then return end
        for i = 0, 11 do
            local h = BlzGetFrameByName("CommandButton_" .. i, 0)
            if h then
                BlzFrameSetEnable(h, enabled)
                BlzFrameSetVisible(h, enabled)
            end
        end
    end

    local function setDirectMode(pid, enabled)
        local c = ensureControl(pid); if not c then return end
        c.direct = enabled and true or false
        setCommandCardEnabled(pid, not c.direct)
        dbg(pid, c.direct and "Direct ON" or "Direct OFF")
    end

    local function clearTags(u)
        if _G.AnimRegistry and AnimRegistry.ClearCommonTags then
            AnimRegistry.ClearCommonTags(u)
        end
    end

    local function playWalk(u)
        clearTags(u)
        if _G.AnimRegistry and AnimRegistry.PlayWalk then AnimRegistry.PlayWalk(u)
        else SetUnitAnimation(u, "Walk") end
    end

    local function playIdle(u)
        clearTags(u)
        if _G.AnimRegistry and AnimRegistry.PlayIdle then AnimRegistry.PlayIdle(u)
        else SetUnitAnimation(u, "Stand") end
    end

    local function setMoving(u, pid, c, moving)
        if moving then
            if not c.isMoving then
                c.isMoving  = true
                c.idleDelay = 6
                if (c.orderGrace or 0) <= 0 then IssueImmediateOrder(u, "stop") end
                ResetUnitAnimation(u)
                playWalk(u)
            else
                c.idleDelay = 6
            end
        else
            if c.isMoving then
                c.isMoving = false
                ResetUnitAnimation(u)
            end
            if c.idleDelay > 0 then
                c.idleDelay = c.idleDelay - 1
            else
                playIdle(u)
            end
        end
    end

    --------------------------------------------------
    -- Tick
    --------------------------------------------------
    local function tick(pid)
        local c, pd = ensureControl(pid); if not c or not c.direct then return end
        local u = pd.hero; if not validUnit(u) then return end

        local rmb = c.rmb
        local lmb = c.lmb
        local facing = GetUnitFacing(u)
        local yawRad = facing * bj_DEGTORAD
        local base = GetUnitMoveSpeed(u); if base <= 0 then base = 300.0 end

        local dx, dy, moved = 0.0, 0.0, false

        if c.holdW then
            dx = dx + base * SPEED_MULT_FWD * math.cos(yawRad)
            dy = dy + base * SPEED_MULT_FWD * math.sin(yawRad)
            moved = true
        elseif c.holdS then
            dx = dx - base * SPEED_MULT_BACK * math.cos(yawRad)
            dy = dy - base * SPEED_MULT_BACK * math.sin(yawRad)
            moved = true
        end

        if rmb then
            local side = (facing - 90.0) * bj_DEGTORAD
            if c.holdA then
                dx = dx - base * SPEED_MULT_STRAFE * math.cos(side)
                dy = dy - base * SPEED_MULT_STRAFE * math.sin(side)
                moved = true
            elseif c.holdD then
                dx = dx + base * SPEED_MULT_STRAFE * math.cos(side)
                dy = dy + base * SPEED_MULT_STRAFE * math.sin(side)
                moved = true
            end
        else
            local step = TURN_DEG_PER_SEC * DT
            if c.holdA then SetUnitFacing(u, facing + step) end
            if c.holdD then SetUnitFacing(u, facing - step) end
        end

        if moved then
            SetUnitPosition(u, GetUnitX(u) + dx * DT, GetUnitY(u) + dy * DT)
            setMoving(u, pid, c, true)
        else
            setMoving(u, pid, c, false)
        end

        if c.orderGrace and c.orderGrace > 0 then c.orderGrace = c.orderGrace - 1 end

        local dist = clamp(c.camDist, MIN_CAM_DIST, MAX_CAM_DIST)
        local yawOffset = c.camYawOffset
        local aoa = CAM_AOA_DEFAULT
        local zoff = CAM_ZOFFSET

        if GetLocalPlayer() == Player(pid) then
            SetCameraTargetController(u, 0.0, 0.0, false)
            SetCameraField(CAMERA_FIELD_FARZ, FARZ, CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ROTATION, GetUnitFacing(u) + yawOffset, CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_TARGET_DISTANCE, dist, CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ANGLE_OF_ATTACK, aoa, CAM_LERP_TIME)
            SetCameraField(CAMERA_FIELD_ZOFFSET, zoff, CAM_LERP_TIME)
        end

        if DEBUG and math.random(1, 60) == 1 then
            dbg(pid, "WASD=" .. tostring(c.holdW) .. tostring(c.holdA) .. tostring(c.holdS) .. tostring(c.holdD) ..
                " RMB=" .. tostring(rmb) .. " LMB=" .. tostring(lmb))
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local t = CreateTimer()
        TimerStart(t, DT, true, function()
            for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do tick(pid) end
        end)

        if _G.ProcBus and ProcBus.On then
            ProcBus.On("RightMouseReleased", function(e)
                if e and type(e.pid) == "number" then
                    local c = ensureControl(e.pid)
                    if c then c.orderGrace = ORDER_GRACE_TICKS end
                    dbg(e.pid, "RMB released")
                end
            end)
            ProcBus.On("DirectControlToggled", function(e)
                if e and type(e.pid) == "number" then
                    setDirectMode(e.pid, e.enabled)
                end
            end)
        end

        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                setDirectMode(pid, true)
            end
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("DirectControlMotor")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
