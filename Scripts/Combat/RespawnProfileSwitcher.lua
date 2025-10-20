if Debug and Debug.beginFile then Debug.beginFile("RespawnProfileSwitcher.lua") end
--==================================================
-- RespawnProfileSwitcher.lua
-- Hot-swaps respawn timer profiles at runtime.
-- • Updates GameBalance.RespawnProfiles.Default (copy of target)
-- • Listens to ProcBus events (dungeon/trial signals)
-- • Exposes a small public API (Set/Push/Pop/CurrentId)
-- • ASCII-only, WC3-safe strings
--==================================================

do
    if not RespawnProfile then RespawnProfile = {} end
    _G.RespawnProfile = RespawnProfile

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function gb() return _G.GameBalance end
    local function copyInto(dst, src)
        for k, v in pairs(dst) do dst[k] = nil end
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
    local _stack = {}  -- push/pop overrides
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
        -- Dungeons
        DUNGEON_WIPE       = "Dungeon_Wipe",
        BOSS_PULL_START    = "Dungeon_NoTrash",
        BOSS_PULL_END      = "Overworld_Default", -- back to normal pacing outside boss
        BOSS_DEFEATED      = "Overworld_Default",

        -- Trials (you can switch per phase)
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
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        ensureDefaultExists()
        if ProcBus and ProcBus.Subscribe then
            for ev, _ in pairs(EventToProfile) do
                ProcBus.Subscribe(ev, function(p) onEvent(p, ev) end)
            end
        elseif ProcBus and ProcBus.On then
            for ev, _ in pairs(EventToProfile) do
                ProcBus.On(ev, function(p) onEvent(p, ev) end)
            end
        end

        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("RespawnProfileSwitcher")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
