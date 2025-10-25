if Debug and Debug.beginFile then Debug.beginFile("MouseMovement.lua") end
--==================================================
-- MouseMovement.lua
-- Version: v1.22 (2025-10-24)
-- Tracks RMB/LMB per player using TriggerRegisterPlayerMouseEvent2.
-- Emits ProcBus "RightMouseReleased" on RMB up for native orders.
--==================================================

do
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

    local function onMouseDown(pid, button)
        local c = ensureControl(pid); if not c then return end
        if button == MOUSE_BUTTON_TYPE_RIGHT then
            c.rmb = true
        elseif button == MOUSE_BUTTON_TYPE_LEFT then
            c.lmb = true
        end
    end

    local function onMouseUp(pid, button)
        local c = ensureControl(pid); if not c then return end
        if button == MOUSE_BUTTON_TYPE_RIGHT then
            c.rmb = false
            if _G.ProcBus and ProcBus.Emit then
                ProcBus.Emit("RightMouseReleased", { pid = pid })
            end
        elseif button == MOUSE_BUTTON_TYPE_LEFT then
            c.lmb = false
        end
    end

    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local p = Player(pid)

            -- Mouse DOWN
            local tDown = CreateTrigger()
            TriggerRegisterPlayerMouseEvent(tDown, p, bj_MOUSEEVENTTYPE_DOWN)
            TriggerAddAction(tDown, function()
                onMouseDown(GetPlayerId(GetTriggerPlayer()), BlzGetTriggerPlayerMouseButton())
            end)

            -- Mouse UP
            local tUp = CreateTrigger()
            TriggerRegisterPlayerMouseEvent(tUp, p, bj_MOUSEEVENTTYPE_UP)
            TriggerAddAction(tUp, function()
                onMouseUp(GetPlayerId(GetTriggerPlayer()), BlzGetTriggerPlayerMouseButton())
            end)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("MouseMovement")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
