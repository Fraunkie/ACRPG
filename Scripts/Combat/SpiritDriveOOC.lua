if Debug and Debug.beginFile then Debug.beginFile("SpiritDriveOOC.lua") end
--==================================================
-- SpiritDriveOOC.lua
-- Back-compat wrapper for out-of-combat checks.
-- Emits OnCombatStateChanged { pid, inCombat }.
--==================================================

if not SpiritDriveOOC then SpiritDriveOOC = {} end
_G.SpiritDriveOOC = SpiritDriveOOC

do
    local last = {} -- pid -> bool

    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[SD-OOC] " .. tostring(s)) end
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    function SpiritDriveOOC.IsInCombat(pid)
        if _G.CombatEventsBridge and CombatEventsBridge.IsInCombat then
            return CombatEventsBridge.IsInCombat(pid)
        end
        return false
    end

    local function tick()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local now = SpiritDriveOOC.IsInCombat(pid)
            if last[pid] ~= now then
                last[pid] = now
                emit("OnCombatStateChanged", { pid = pid, inCombat = now })
            end
        end
    end

    if OnInit and OnInit.final then
        OnInit.final(function()
            local t = CreateTimer()
            TimerStart(t, 0.50, true, tick)
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("SpiritDriveOOC")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
