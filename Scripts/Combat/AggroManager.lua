if Debug and Debug.beginFile then Debug.beginFile("AggroManager.lua") end
--==================================================
-- AggroManager.lua
-- Simple threat tables per target.
-- • AddThreat/AddDamage/AddHeal
-- • GetThreatList(target) -> { {pid,value}, ... }
-- • GetAnyTargetForPid(pid)
-- • GetPlayerPrimaryTarget(pid)
-- • Taunt soft-lock (optional)
-- Emits ProcBus "AggroChanged" when a target's threat changes.
--==================================================

if not AggroManager then AggroManager = {} end
_G.AggroManager = AggroManager

do
    local threat   = {}   -- target_handle -> { pid -> value }
    local lastSeen = {}   -- pid -> last target unit
    local softLock = {}   -- target_handle -> { pid = X, ["until"] = time }

    local TAUNT_DURATION = 3.0

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function hid(u) return GetHandleId(u) end
    local function pbEmitTarget(t)
        local PB = rawget(_G,"ProcBus")
        if PB and PB.Emit then PB.Emit("AggroChanged", { target = t }) end
    end

    local function ensureTableForTarget(t)
        local h = hid(t)
        if not threat[h] then threat[h] = {} end
        return threat[h]
    end

    local function add(t, pid, amt)
        if not valid(t) or pid == nil or amt == nil or amt == 0 then return end
        local tab = ensureTableForTarget(t)
        tab[pid] = math.max(0, (tab[pid] or 0) + amt)
        lastSeen[pid] = t
        pbEmitTarget(t)
    end

    -- Public: main entry points
    function AggroManager.AddThreat(target, pid, amount) add(target, pid, amount or 0) end
    function AggroManager.AddDamage(target, pid, amount) add(target, pid, amount or 0) end
    function AggroManager.AddHeal(target, pid, amount)
        add(target, pid, math.floor((amount or 0) * 0.5))
    end

    -- Public: list for a target (array of {pid,value})
    function AggroManager.GetThreatList(target)
        if not valid(target) then return {} end
        local tab = ensureTableForTarget(target)
        local out, i = {}, 1
        for pid, val in pairs(tab) do
            out[i] = { pid = pid, value = val or 0 }
            i = i + 1
        end
        return out
    end

    -- Public: any target a pid has threat on (fallback for HUD)
    function AggroManager.GetAnyTargetForPid(pid)
        local best, bestVal = nil, 0
        for h, tab in pairs(threat) do
            local val = tab[pid]
            if val and val > bestVal then
                bestVal = val
                best = h
            end
        end
        if best then
            local t = lastSeen[pid]
            if t and GetHandleId(t) == best then return t end
        end
        return lastSeen[pid]
    end

    -- Public: the "primary" target we remember you last interacted with
    function AggroManager.GetPlayerPrimaryTarget(pid)
        return lastSeen[pid]
    end

    -- Optional: Taunt soft lock
    function AggroManager.Taunt(target, pid, value, duration)
        if not valid(target) then return end
        duration = duration or TAUNT_DURATION
        value    = value or 1000
        local h  = hid(target)
        softLock[h] = { pid = pid, ["until"] = now() + duration }  -- FIXED: quote the key
        AggroManager.AddThreat(target, pid, value)
    end

    function AggroManager.IsLocked(target, pid)
        local h = hid(target)
        local lock = softLock[h]
        return lock and lock.pid == pid and (lock["until"] or 0) > now()
    end

    OnInit.final(function()
        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("AggroManager")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
