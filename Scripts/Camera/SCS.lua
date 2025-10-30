if Debug and Debug.beginFile then Debug.beginFile("SCS.lua") end
--==================================================
-- SCS.lua  (WASD movement + command prompt lock)
-- • W/S: move along facing (no negative time-scale)
-- • A/D: turn; with RMB held → strafe camera-relative (WoW-style)
-- • Uses Animation Registry + Animation Control per hero
-- • Reads yaw / mouse buttons from CameraWheel
-- • Locks command prompt: consumes RMB context orders while in control
-- Public API (compatible with your JASS init):
--   SCS.Associate(u, player, animIndexIgnored, flagIgnored)
--   SCS.SetControl(player, enabled)
--   SCS.GetUnit(player) -> unit
--==================================================

SCS = SCS or {}
_G.SCS = SCS

do
    --------------------------------------------------
    -- Utilities
    --------------------------------------------------
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function heroOf(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if pd and valid(pd.hero) then return pd.hero end
        if _G.PlayerHero and valid(PlayerHero[pid]) then return PlayerHero[pid] end
        return nil
    end

    --------------------------------------------------
    -- Per-player state
    --------------------------------------------------
    local Units   = {}          -- bound unit (explicit) or resolved from PlayerData
    local Enabled = {}          -- whether WASD applies
    local W,A,S,D = {},{},{},{} -- key holds
    local animSet = {}          -- { idle, walk, run, strafeL, strafeR }

    --------------------------------------------------
    -- Animation interop
    --------------------------------------------------
    local function resolveAnimFor(u)
        local tid  = GetUnitTypeId(u)
        local AR   = rawget(_G,"AnimationRegistry")
        local data = AR and AR.Get and AR.Get(tid) or nil
        local out = { idle=25, walk=22, run=22, strafeL=nil, strafeR=nil }
        if data then
            if data.idle    ~= nil then out.idle    = data.idle end
            if data.walk    ~= nil then out.walk    = data.walk end
            if data.run     ~= nil then out.run     = data.run  end
            if data.strafeL ~= nil then out.strafeL = data.strafeL end
            if data.strafeR ~= nil then out.strafeR = data.strafeR end
        end
        return out
    end

    local function playIndex(pid, u, idx)
        local AC = rawget(_G,"AnimationControl")
        if AC and AC.PlayIndex then AC.PlayIndex(pid, u, idx)
        elseif idx then SetUnitAnimationByIndex(u, idx) end
    end
    local function playIdle(pid, u) local s = animSet[pid]; if s then playIndex(pid,u,s.idle) else SetUnitAnimation(u,"stand") end end
    local function playRun (pid, u) local s = animSet[pid]; if s then playIndex(pid,u,(s.run or s.walk)) end end
    local function playWalk(pid, u) local s = animSet[pid]; if s then playIndex(pid,u,(s.walk or s.run)) end end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SCS.Associate(u, p, _animIndexIgnored, _flagIgnored)
        local pid = GetPlayerId(p)
        Units[pid]   = u
        Enabled[pid] = true
        animSet[pid] = resolveAnimFor(u)
    end

    function SCS.SetControl(p, enabled)
        Enabled[GetPlayerId(p)] = enabled and true or false
    end

    function SCS.GetUnit(p)
        return Units[GetPlayerId(p)]
    end

    --------------------------------------------------
    -- Input: WASD keys
    --------------------------------------------------
    local function onWASD()
        local p    = GetTriggerPlayer()
        local pid  = GetPlayerId(p)
        local key  = BlzGetTriggerPlayerKey()
        local down = BlzGetTriggerPlayerIsKeyDown()
        if key==OSKEY_W then W[pid]=down if not down and Units[pid] then playIdle(pid, Units[pid]) end
        elseif key==OSKEY_S then S[pid]=down if not down and Units[pid] then playIdle(pid, Units[pid]) end
        elseif key==OSKEY_A then A[pid]=down
        elseif key==OSKEY_D then D[pid]=down
        end
    end

    --------------------------------------------------
    -- Command prompt lock (consume RMB orders while in control)
    -- Cancels default “move/attack/harvest” orders from right-click.
    --------------------------------------------------
    local function onMouseDownLock()
        local p    = GetTriggerPlayer()
        local pid  = GetPlayerId(p)
        if not Enabled[pid] then return end
        if BlzGetTriggerPlayerMouseButton() == MOUSE_BUTTON_TYPE_RIGHT then
            local u = Units[pid] or heroOf(pid)
            if u and valid(u) and BlzGetMouseFocusUnit() == nil then
                IssueImmediateOrder(u, "stop")
            end
        end
    end

    --------------------------------------------------
    -- Movement tick
    --------------------------------------------------
    local function moveTick()
        for pid=0,bj_MAX_PLAYERS-1 do
            if not Enabled[pid] then goto next end

            local u = Units[pid] or heroOf(pid)
            if not u or not valid(u) then goto next end
            Units[pid] = u
            if not animSet[pid] then animSet[pid] = resolveAnimFor(u) end

            local yaw = (CameraWheel and CameraWheel.GetYaw and CameraWheel.GetYaw(pid)) or GetUnitFacing(u)
            local rmb = (CameraWheel and CameraWheel.IsRight and CameraWheel.IsRight(pid)) or false

            local fx, fy = GetUnitX(u), GetUnitY(u)
            local step   = GetUnitMoveSpeed(u) / 100.0
            local moving = false

            -- Forward/back
            if W[pid] and not S[pid] then
                local a = GetUnitFacing(u)
                SetUnitPosition(u, fx + step*Cos(a*bj_DEGTORAD), fy + step*Sin(a*bj_DEGTORAD))
                moving = true; playRun(pid, u)
            elseif S[pid] and not W[pid] then
                local a = GetUnitFacing(u)
                SetUnitPosition(u, fx - step*Cos(a*bj_DEGTORAD), fy - step*Sin(a*bj_DEGTORAD))
                moving = true; playWalk(pid, u)
            end

            -- Turn vs strafe on A/D
            local turnRate = 12.0
            if D[pid] and not A[pid] then
                if rmb then
                    if W[pid] then SetUnitFacingTimed(u, yaw - 45.0, 0.01)
                    else BlzSetUnitFacingEx(u, yaw - 90.0) end
                    moving = true; playRun(pid, u)
                else
                    SetUnitFacingTimed(u, GetUnitFacing(u) - turnRate, 0.01)
                end
            elseif A[pid] and not D[pid] then
                if rmb then
                    if W[pid] then SetUnitFacingTimed(u, yaw + 45.0, 0.01)
                    else BlzSetUnitFacingEx(u, yaw + 90.0) end
                    moving = true; playRun(pid, u)
                else
                    SetUnitFacingTimed(u, GetUnitFacing(u) + turnRate, 0.01)
                end
            end

            -- RMB look-turn while standing
            if rmb and not moving and not W[pid] and not S[pid] then
                SetUnitFacingTimed(u, yaw, 0.0)
            end

            -- Idle fallback
            if not moving and not W[pid] and not S[pid] and not A[pid] and not D[pid] then
                playIdle(pid, u)
            end

            ::next::
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- WASD registration
        for pid=0,bj_MAX_PLAYERS-1 do
            local t = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_W, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_W, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_A, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_A, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_S, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_S, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_D, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_D, 0, false)
            TriggerAddAction(t, onWASD)
        end

        -- RMB lock (command prompt guard)
        local md = CreateTrigger()
        for pid=0,bj_MAX_PLAYERS-1 do
            TriggerRegisterPlayerMouseEventBJ(md, Player(pid), bj_MOUSEEVENTTYPE_DOWN)
        end
        TriggerAddAction(md, onMouseDownLock)

        -- Movement tick
        TimerStart(CreateTimer(), 0.01, true, moveTick)

        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SCS")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
