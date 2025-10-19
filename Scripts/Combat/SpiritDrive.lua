if Debug and Debug.beginFile then Debug.beginFile("SpiritDrive.lua") end
--==================================================
-- SpiritDrive.lua
-- Rage/Spirit meter with out-of-combat drain.
-- Gains are applied by CombatEventsBridge (on hit/kill)
-- This module tracks, clamps, drains, and emits events.
--==================================================

if not SpiritDrive then SpiritDrive = {} end
_G.SpiritDrive = SpiritDrive

do
    --------------------------------------------------
    -- Config knobs (read from GameBalance when present)
    --------------------------------------------------
    local GB             = rawget(_G, "GameBalance") or {}
    local MAX_DEFAULT    = GB.SD_MAX_DEFAULT           or 100
    local OOC_DELAY_SEC  = GB.SD_OUT_OF_COMBAT_DELAY   or 5.0
    local DRAIN_RATE     = GB.SD_DRAIN_RATE            or 4.0   -- per second
    local TICK_SEC       = 0.25

    --------------------------------------------------
    -- Dev prints (gated)
    --------------------------------------------------
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(0) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return false
    end
    local function dprint(msg) if DEV_ON() then print("[SpiritDrive] " .. tostring(msg)) end end

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- P[pid] = { v = value, m = max, paused = bool, lastHit = os.clock, drainT = timer }
    local P = {}

    local function PD(pid)
        local t = P[pid]
        if not t then
            t = { v = 0, m = MAX_DEFAULT, paused = false, lastHit = 0, drainT = nil }
            P[pid] = t
        end
        return t
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function inCombat(pid)
        -- Prefer central bridge if present
        if _G.CombatEventsBridge and CombatEventsBridge.IsInCombat then
            return CombatEventsBridge.IsInCombat(pid)
        end
        -- Fallback to local timestamp
        local t = PD(pid)
        if not os or not os.clock then return false end
        return (os.clock() - (t.lastHit or 0)) < OOC_DELAY_SEC
    end

    local function bumpHit(pid)
        local t = PD(pid)
        if os and os.clock then t.lastHit = os.clock() end
    end

    local function maybeFull(pid, before, after)
        -- Only emit when crossing from below to at-or-above max
        local t = PD(pid)
        if before < t.m and after >= t.m then
            emit("OnSpiritDriveFull", { pid = pid, value = t.v, max = t.m })
            dprint("pid " .. tostring(pid) .. " full at " .. tostring(t.v) .. " of " .. tostring(t.m))
        end
    end

    local function updateLabel(pid)
        if _G.SpiritPowerLabelBridge and SpiritPowerLabelBridge.SetSpirit then
            local t = PD(pid)
            pcall(SpiritPowerLabelBridge.SetSpirit, pid, t.v, t.m)
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function SpiritDrive.Get(pid)
        local t = PD(pid)
        return t.v, t.m
    end

    function SpiritDrive.GetMax(pid)
        return PD(pid).m
    end

    function SpiritDrive.Set(pid, value)
        local t = PD(pid)
        local before = t.v
        t.v = clamp(math.floor(value or 0), 0, t.m)
        emit("OnSpiritDriveChanged", { pid = pid, value = t.v, max = t.m })
        updateLabel(pid)
        maybeFull(pid, before, t.v)
        dprint("Set pid " .. tostring(pid) .. " = " .. tostring(t.v))
        return t.v
    end

    function SpiritDrive.Add(pid, delta)
        local t = PD(pid)
        if t.paused then return t.v end
        local before = t.v
        t.v = clamp(t.v + (delta or 0), 0, t.m)
        emit("OnSpiritDriveChanged", { pid = pid, value = t.v, max = t.m })
        updateLabel(pid)
        maybeFull(pid, before, t.v)
        dprint("Add pid " .. tostring(pid) .. " +" .. tostring(delta or 0) .. " -> " .. tostring(t.v))
        return t.v
    end

    function SpiritDrive.Reset(pid)
        local t = PD(pid)
        local before = t.v
        t.v = 0
        emit("OnSpiritDriveChanged", { pid = pid, value = t.v, max = t.m })
        updateLabel(pid)
        maybeFull(pid, before, t.v)
        dprint("Reset pid " .. tostring(pid))
        return 0
    end

    function SpiritDrive.SetPaused(pid, flag)
        PD(pid).paused = flag and true or false
        dprint("Paused pid " .. tostring(pid) .. " = " .. (flag and "true" or "false"))
    end

    function SpiritDrive.SetMax(pid, newMax, keepRatio)
        local t = PD(pid)
        local oldMax = t.m
        t.m = math.max(1, math.floor(newMax or MAX_DEFAULT))
        if keepRatio and oldMax > 0 then
            local ratio = t.v / oldMax
            t.v = clamp(math.floor(ratio * t.m + 0.5), 0, t.m)
        else
            t.v = clamp(t.v, 0, t.m)
        end
        emit("OnSpiritDriveChanged", { pid = pid, value = t.v, max = t.m })
        updateLabel(pid)
        dprint("Max pid " .. tostring(pid) .. " = " .. tostring(t.m))
    end

    --------------------------------------------------
    -- Wiring (ProcBus)
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then return end

        -- Do NOT add here on hit; CombatEventsBridge already adds SpiritDrive.Add
        PB.On("OnDealtDamage", function(e)
            if not e or e.pid == nil then return end
            bumpHit(e.pid)
        end)

        PB.On("OnKill", function(e)
            if not e or e.pid == nil then return end
            bumpHit(e.pid)
        end)

        -- Sample pause gates many systems emit
        PB.On("OnTeleportStart", function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, true)  end end)
        PB.On("OnTeleportArrive",function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, false) end end)

        PB.On("OnAscensionChallengeStart",   function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, true)  end end)
        PB.On("OnAscensionChallengeSuccess", function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, false) end end)
        PB.On("OnAscensionChallengeFail",    function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, false) end end)
        PB.On("OnAscensionChallengeCancel",  function(e) if e and e.pid ~= nil then SpiritDrive.SetPaused(e.pid, false) end end)
    end

    --------------------------------------------------
    -- OOC Drain
    --------------------------------------------------
    local function ensureDrain(pid)
        local t = PD(pid)
        if t.drainT then return end
        t.drainT = CreateTimer()
        TimerStart(t.drainT, TICK_SEC, true, function()
            local td = PD(pid)
            if td.paused or inCombat(pid) then return end
            if td.v <= 0 then return end
            local delta = DRAIN_RATE * TICK_SEC
            td.v = clamp(td.v - delta, 0, td.m)
            emit("OnSpiritDriveChanged", { pid = pid, value = td.v, max = td.m })
            updateLabel(pid)
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            -- Seed tables and start per-player drain
            PD(pid)
            ensureDrain(pid)
            updateLabel(pid)
        end
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("SpiritDrive")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
