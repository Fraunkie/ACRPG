if Debug and Debug.beginFile then Debug.beginFile("AscensionChallenge.lua") end
--==================================================
-- AscensionChallenge.lua
-- Handles timed ascension trials started from gates or dev commands.
--==================================================

if not AscensionChallenge then AscensionChallenge = {} end
_G.AscensionChallenge = AscensionChallenge

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local GB = GameBalance or {}
    local DEFAULT_SECONDS = GB.ASCENSION_CHALLENGE_DEFAULT_SECONDS or 15

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local active = {} -- pid -> { tier, familyKey, gate, challenge_id, ends, timer }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Challenge] " .. tostring(s)) end
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    local function stopTimer(pid)
        local a = active[pid]
        if a and a.timer then
            DestroyTimer(a.timer)
            a.timer = nil
        end
    end

    --------------------------------------------------
    -- Internal flow
    --------------------------------------------------
    local function finish(pid, success, reason)
        local a = active[pid]
        if not a then return end
        stopTimer(pid)

        if _G.SpiritDrive and SpiritDrive.SetPaused then
            SpiritDrive.SetPaused(pid, false)
        end

        if success then
            dprint("challenge success for p" .. tostring(pid))
            emit("OnAscensionChallengeSuccess", { pid = pid, tier = a.tier, familyKey = a.familyKey })
            if _G.AscensionSystem and AscensionSystem.TryAscend then
                AscensionSystem.TryAscend(pid, a.tier)
            end
        else
            dprint("challenge failed for p" .. tostring(pid))
            emit("OnAscensionChallengeFail", { pid = pid, reason = reason })
        end

        active[pid] = nil
    end

    local function tick(pid)
        local a = active[pid]
        if not a then return end
        if os.clock and a.ends and os.clock() >= a.ends then
            finish(pid, true)
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function AscensionChallenge.Begin(pid, data)
        if not pid then return false end
        stopTimer(pid)

        local dur = (data and data.duration) or DEFAULT_SECONDS
        local fam = (data and data.familyKey) or "GENERIC"
        local tier = (data and data.tier) or 1
        local cid = (data and data.challenge_id) or "GENERIC"

        active[pid] = {
            tier = tier,
            familyKey = fam,
            gate = (data and data.gate) or nil,
            challenge_id = cid,
            ends = os.clock and (os.clock() + dur) or nil
        }

        if _G.SpiritDrive and SpiritDrive.SetPaused then
            SpiritDrive.SetPaused(pid, true)
        end

        emit("OnAscensionChallengeStart", { pid = pid, tier = tier, familyKey = fam, challenge_id = cid })
        dprint("start p" .. tostring(pid) .. " dur " .. tostring(dur))

        local t = CreateTimer()
        active[pid].timer = t
        TimerStart(t, 1.0, true, function()
            tick(pid)
        end)
        return true
    end

    function AscensionChallenge.Succeed(pid)
        finish(pid, true)
    end

    function AscensionChallenge.Fail(pid, reason)
        finish(pid, false, reason or "fail")
    end

    function AscensionChallenge.Cancel(pid, reason)
        stopTimer(pid)
        if _G.SpiritDrive and SpiritDrive.SetPaused then
            SpiritDrive.SetPaused(pid, false)
        end
        emit("OnAscensionChallengeCancel", { pid = pid, reason = reason })
        active[pid] = nil
    end

    --------------------------------------------------
    -- Query
    --------------------------------------------------
    function AscensionChallenge.IsActive(pid)
        return active[pid] ~= nil
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("AscensionChallenge")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
