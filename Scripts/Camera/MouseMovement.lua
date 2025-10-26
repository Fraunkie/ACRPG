if Debug and Debug.beginFile then Debug.beginFile("MouseMovement.lua") end
--==================================================
-- MouseMovement.lua
-- Version: v1.30 (per-player LMB/RMB events + debug)
-- Tracks mouse down/up for LEFT/RIGHT buttons.
-- Updates PLAYER_DATA[pid].control.lmb / .rmb
-- Emits ProcBus events:
--   LeftMouseDown, LeftMouseUp, RightMouseDown, RightMouseUp
-- WC3-safe. No percent symbols.
--==================================================

do
    --------------------------------------------------
    -- Toggleable debug
    --------------------------------------------------
    local DEBUG_LOG = true
    local function log(pid, msg)
        if not DEBUG_LOG then return end
        local who = (pid ~= nil) and ("P" .. tostring(pid)) or "P?"
        DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "[MouseMovement] " .. who .. " " .. tostring(msg))
    end

    --------------------------------------------------
    -- Helpers / control bag
    --------------------------------------------------
    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return nil end
        pd.control = pd.control or {
            direct=false, holdW=false, holdA=false, holdS=false, holdD=false,
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil,
            orderGrace=0, isMoving=false
        }
        return pd.control
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    --------------------------------------------------
    -- Event handlers
    --------------------------------------------------
    local function onMouseDown(pid, button)
        local c = ensureControl(pid); if not c then return end
        if button == MOUSE_BUTTON_TYPE_LEFT then
            if not c.lmb then
                c.lmb = true
                log(pid, "LMB DOWN")
                emit("LeftMouseDown", { pid = pid })
            end
        elseif button == MOUSE_BUTTON_TYPE_RIGHT then
            if not c.rmb then
                c.rmb = true
                log(pid, "RMB DOWN")
                emit("RightMouseDown", { pid = pid })
            end
        end
    end

    local function onMouseUp(pid, button)
        local c = ensureControl(pid); if not c then return end
        if button == MOUSE_BUTTON_TYPE_LEFT then
            if c.lmb then
                c.lmb = false
                log(pid, "LMB UP")
                emit("LeftMouseUp", { pid = pid })
            end
        elseif button == MOUSE_BUTTON_TYPE_RIGHT then
            if c.rmb then
                c.rmb = false
                log(pid, "RMB UP")
                emit("RightMouseUp", { pid = pid })
                -- For native order grace (camera → click), keep this signal too:
                emit("RightMouseReleased", { pid = pid })
            end
        end
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    OnInit.final(function()
        -- Pre-warm control bags for user-controlled players
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                ensureControl(pid)
            end
        end

        -- Register mouse events for every player (safe no-op for computers)
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local p = Player(pid)

            -- DOWN
            local tDown = CreateTrigger()
            TriggerRegisterPlayerMouseEvent(tDown, p, bj_MOUSEEVENTTYPE_DOWN)
            TriggerAddAction(tDown, function()
                local who = GetPlayerId(GetTriggerPlayer())
                local btn = BlzGetTriggerPlayerMouseButton()
                onMouseDown(who, btn)
            end)

            -- UP
            local tUp = CreateTrigger()
            TriggerRegisterPlayerMouseEvent(tUp, p, bj_MOUSEEVENTTYPE_UP)
            TriggerAddAction(tUp, function()
                local who = GetPlayerId(GetTriggerPlayer())
                local btn = BlzGetTriggerPlayerMouseButton()
                onMouseUp(who, btn)
            end)
        end

        if DEBUG_LOG then
            DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "[MouseMovement] ready (v1.30)")
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("MouseMovement")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
