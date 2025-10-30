if Debug and Debug.beginFile then Debug.beginFile("AnimationControl.lua") end
--==================================================
-- AnimationControl.lua
-- Version: v1.00 (2025-10-24)
-- Per player mute and short hold for animation writes
--==================================================

do
    AnimControl = AnimControl or {}
    local MUTE = {}
    local HOLD = {}

    function AnimControl.IsMuted(pid)
        if HOLD[pid] and HOLD[pid] > 0 then return true end
        return MUTE[pid] == true
    end

    function AnimControl.SetMuted(pid, flag)
        MUTE[pid] = (flag == true)
    end

    function AnimControl.Hold(pid, ticks)
        local t = ticks or 6
        if t < 0 then t = 0 end
        HOLD[pid] = t
    end

    local function tick()
        for pid = 0, bj_MAX_PLAYER_SLOTS - 1 do
            local h = HOLD[pid]
            if h and h > 0 then HOLD[pid] = h - 1 end
        end
    end

    OnInit.final(function()
        local t = CreateTimer()
        TimerStart(t, 0.03, true, tick)

        if _G.ProcBus and ProcBus.On then
            ProcBus.On("AnimOverrideOn",  function(p) if type(p)=="table" and type(p.pid)=="number" then AnimControl.SetMuted(p.pid, true)  end end)
            ProcBus.On("AnimOverrideOff", function(p) if type(p)=="table" and type(p.pid)=="number" then AnimControl.SetMuted(p.pid, false) end end)
            ProcBus.On("AnimHold",        function(p) if type(p)=="table" and type(p.pid)=="number" and type(p.ticks)=="number" then AnimControl.Hold(p.pid, p.ticks) end end)
        end

        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("AnimationControl")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
