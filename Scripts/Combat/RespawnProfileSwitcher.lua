if Debug and Debug.beginFile then Debug.beginFile("RespawnProfileSwitcher.lua") end
--==================================================
-- RespawnProfileSwitcher.lua
-- Hot-swaps respawn timer profiles at runtime.
--==================================================

do
    if not RespawnProfile then RespawnProfile = {} end
    _G.RespawnProfile = RespawnProfile

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function gb() return _G.GameBalance end
    local function copyInto(dst, src)
        for k, _ in pairs(dst) do dst[k] = nil end
        for k, v in pairs(src) do dst[k] = v end
        return dst
    end
    local function ensureDefaultExists()
        local G = gb(); if not G then return end
        G.RespawnProfiles = G.RespawnProfiles or {}
        G.RespawnProfiles.Default = G.RespawnProfiles.Default or { delay = 10.0, jitter = 4.0, batch = 2, throttlePerSec = 8 }
    end
    local function profileById(id)
        local G = gb(); if not G or not G.RespawnProfiles then return nil end
        return G.RespawnProfiles[id]
    end

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local _stack = {}
    local _currentId = "Default"

    local function applyProfile(id)
        ensureDefaultExists()
        local G = gb()
        local src = profileById(id)
        if not (G and src) then return false end
        copyInto(G.RespawnProfiles.Default, src)
        _currentId = id
        if ProcBus and ProcBus.Emit then
            ProcBus.Emit("RESPAWN_PROFILE_CHANGED", { id = id })
        end
        return true
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function RespawnProfile.Set(id)
        if type(id) ~= "string" then return false end
        return applyProfile(id)
    end

    function RespawnProfile.Push(id)
        if type(id) ~= "string" then return false end
        table.insert(_stack, _currentId)
        return applyProfile(id)
    end

    function RespawnProfile.Pop()
        local prev = _stack[#_stack]
        if not prev then return false end
        _stack[#_stack] = nil
        return applyProfile(prev)
    end

    function RespawnProfile.CurrentId()
        return _currentId
    end

    --------------------------------------------------
    -- Event wiring (ProcBus)
    --------------------------------------------------
    local EventToProfile = {
        DUNGEON_WIPE       = "Dungeon_Wipe",
        BOSS_PULL_START    = "Dungeon_NoTrash",
        BOSS_PULL_END      = "Overworld_Default",
        BOSS_DEFEATED      = "Overworld_Default",
        TRIAL_PHASE_1      = "Trial_Phase1",
        TRIAL_PHASE_2      = "Trial_Phase2",
        TRIAL_PHASE_3      = "Trial_Phase3",
    }

    local function onEvent(payload, id)
        local target = EventToProfile[id]
        if not target then return end
        RespawnProfile.Set(target)
    end

    --------------------------------------------------
    -- Init (deferred to guarantee ProcBus + DungeonTrialSignals ready)
    --------------------------------------------------
    OnInit.final(function()
        ensureDefaultExists()
        TimerStart(CreateTimer(), 0.25, false, function()
            if ProcBus and (ProcBus.Subscribe or ProcBus.On) then
                for ev, _ in pairs(EventToProfile) do
                    local fn = function(p) onEvent(p, ev) end
                    if ProcBus.Subscribe then
                        ProcBus.Subscribe(ev, fn)
                    elseif ProcBus.On then
                        ProcBus.On(ev, fn)
                    end
                end
            end
            if InitBroker and InitBroker.SystemReady then
                InitBroker.SystemReady("RespawnProfileSwitcher")
            end
            DestroyTimer(GetExpiredTimer())
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
