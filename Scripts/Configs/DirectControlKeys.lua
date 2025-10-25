if Debug and Debug.beginFile then Debug.beginFile("DirectControlKeys.lua") end
--==================================================
-- DirectControlKeys.lua
-- Version: v1.06 (2025-10-24)
-- Feeds W/A/S/D + RMB/LMB state into PLAYER_DATA[pid].control
-- Works alongside KeyEventHandler (menus) and DirectControlMotor (movement)
--==================================================

do
    local function ensureControl(pid)
        local pd = _G.PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return nil end
        pd.control = pd.control or {
            direct=false, holdW=false, holdA=false, holdS=false, holdD=false,
            rmb=false, lmb=false, yaw=nil, pitch=nil, dist=nil,
        }
        return pd.control
    end

    local function setKey(pid, key, isDown)
        local c = ensureControl(pid); if not c then return end
        if key == OSKEY_W then c.holdW = isDown
        elseif key == OSKEY_A then c.holdA = isDown
        elseif key == OSKEY_S then c.holdS = isDown
        elseif key == OSKEY_D then c.holdD = isDown
        end
    end

    local function onMouse(pid, isDown)
        local c = ensureControl(pid); if not c then return end
        local btn = BlzGetTriggerPlayerMouseButton()
        if btn == MOUSE_BUTTON_TYPE_RIGHT then
            c.rmb = isDown
            -- give WC3 a frame to clear native orders when you press RMB
            -- (DirectControlMotor has orderGrace too)
        elseif btn == MOUSE_BUTTON_TYPE_LEFT then
            c.lmb = isDown
        end
    end

    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            -- Keyboard: W A S D (down/up)
            local t = CreateTrigger()
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_W, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_A, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_S, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_D, 0, true)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_W, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_A, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_S, 0, false)
            BlzTriggerRegisterPlayerKeyEvent(t, Player(pid), OSKEY_D, 0, false)
            TriggerAddAction(t, function()
                local p    = GetTriggerPlayer()
                local id   = GetPlayerId(p)
                local key  = BlzGetTriggerPlayerKey()
                local down = BlzGetTriggerPlayerIsKeyDown()
                setKey(id, key, down)
            end)

            -- Mouse: right/left (down/up)
            local m = CreateTrigger()
            TriggerRegisterPlayerEvent(m, Player(pid), EVENT_PLAYER_MOUSE_DOWN)
            TriggerRegisterPlayerEvent(m, Player(pid), EVENT_PLAYER_MOUSE_UP)
            TriggerAddAction(m, function()
                local p    = GetTriggerPlayer()
                local id   = GetPlayerId(p)
                local ev   = GetTriggerEventId()
                local down = (ev == EVENT_PLAYER_MOUSE_DOWN)
                onMouse(id, down)
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("DirectControlKeys")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
