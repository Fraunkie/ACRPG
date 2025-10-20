if Debug and Debug.beginFile then Debug.beginFile("ThreatHUDData.lua") end
--==================================================
-- ThreatHUDData.lua
-- Rolling DPS tracker per target and per pid.
-- Uses its own game clock (timer-based), not os.clock().
-- Listens to ProcBus "OnDealtDamage".
-- API:
--   ThreatHUDData.GetSnapshot(target) -> { [pid] = { dps=, last=time } }
--==================================================

if not ThreatHUDData then ThreatHUDData = {} end
_G.ThreatHUDData = ThreatHUDData

do
    local WINDOW = 5.0         -- seconds of history
    local TICK   = 0.25        -- game-clock tick
    local CLOCK  = 0.0         -- monotonic game time (seconds)

    local logs   = {}          -- logs[targetH][pid] = { {t,amt}, ... }

    local function now() return CLOCK end
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function hid(u) return GetHandleId(u) end

    -- prune old entries; return sum of remaining
    local function prune(list, tnow)
        if not list then return 0 end
        local sum, j = 0, 1
        for i = 1, #list do
            local e = list[i]
            if (tnow - (e.t or 0)) <= WINDOW then
                list[j] = e; j = j + 1
                sum = sum + (e.amt or 0)
            end
        end
        for k = j, #list do list[k] = nil end
        return sum
    end

    -- public: snapshot { pid -> { dps, last } }
    function ThreatHUDData.GetSnapshot(target)
        if not valid(target) then return {} end
        local tH = hid(target)
        local targetLogs = logs[tH]
        if not targetLogs then return {} end
        local tnow = now()
        local snap = {}
        for pid, lst in pairs(targetLogs) do
            local sum = prune(lst, tnow)
            local dps = sum / (WINDOW > 0 and WINDOW or 1)
            snap[pid] = { dps = dps, last = (#lst > 0) and (lst[#lst].t or 0) or 0 }
        end
        return snap
    end

    -- events
    local function onDealtDamage(e)
        if not e or e.pid == nil or not valid(e.target) then return end
        local amt = tonumber(e.amount or 0) or 0
        if amt <= 0 then return end
        local tnow = now()
        local tH = hid(e.target)
        logs[tH] = logs[tH] or {}
        local L = logs[tH]
        L[e.pid] = L[e.pid] or {}
        local lst = L[e.pid]
        lst[#lst + 1] = { t = tnow, amt = amt }
        -- soft prune to cap growth
        if #lst > 40 then prune(lst, tnow) end
    end

    local function onKill(e)
        if not e or not e.target then return end
        logs[hid(e.target)] = nil
    end

    OnInit.final(function()
        -- build our game clock
        local tm = CreateTimer()
        TimerStart(tm, TICK, true, function()
            CLOCK = CLOCK + TICK
        end)

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDealtDamage)
            PB.On("OnKill", onKill)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUDData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
