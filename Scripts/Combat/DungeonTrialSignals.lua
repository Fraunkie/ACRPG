if Debug and Debug.beginFile then Debug.beginFile("DungeonTrialSignals.lua") end
--==================================================
-- DungeonTrialSignals.lua
-- Emits standardized instance signals over ProcBus.
-- Drives RespawnProfileSwitcher (via DUNGEON_* / TRIAL_PHASE_*).
-- • ASCII-only, WC3-safe, no percent symbols
--==================================================

do
    if not InstanceSignals then InstanceSignals = {} end
    _G.InstanceSignals = InstanceSignals

    local function emit(name, payload)
        if ProcBus and ProcBus.Emit then
            ProcBus.Emit(name, payload)
        end
    end

    --------------------------------------------------
    -- Public API (manual signals)
    --------------------------------------------------
    -- Dungeon / Raid
    function InstanceSignals.BossPullStart(dungeonId)
        emit("BOSS_PULL_START", { dungeonId = dungeonId })
    end
    function InstanceSignals.BossPullEnd(dungeonId)
        emit("BOSS_PULL_END", { dungeonId = dungeonId })
    end
    function InstanceSignals.BossDefeated(dungeonId, bossId)
        emit("BOSS_DEFEATED", { dungeonId = dungeonId, bossId = bossId })
    end
    function InstanceSignals.Wipe(dungeonId)
        emit("DUNGEON_WIPE", { dungeonId = dungeonId })
    end

    -- Trials (phases 1–3)
    function InstanceSignals.TrialPhase(trialId, phase)
        if phase == 1 then emit("TRIAL_PHASE_1", { trialId = trialId })
        elseif phase == 2 then emit("TRIAL_PHASE_2", { trialId = trialId })
        elseif phase == 3 then emit("TRIAL_PHASE_3", { trialId = trialId })
        end
    end

    --------------------------------------------------
    -- Dev chat commands (standalone; DevMode-gated)
    --------------------------------------------------
    local function devOn(pid)
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(pid) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return pid == 0
    end

    local function reg(cmd, handler)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, false)
        end
        TriggerAddAction(t, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            if not devOn(pid) then return end
            local msg = GetEventPlayerChatString()
            handler(p, pid, msg)
        end)
    end

    local function parseTail(msg, cmd)
        local s = string.sub(msg, string.len(cmd) + 2)
        local i = 1
        while string.sub(s, i, i) == " " do i = i + 1 end
        return string.sub(s, i)
    end

    -- Boss pull / end / win
    reg("-boss pull", function(p, pid, msg)
        local id = parseTail(msg, "-boss pull")
        InstanceSignals.BossPullStart(id ~= "" and id or "DUNGEON")
        DisplayTextToPlayer(p, 0, 0, "[Signal] Boss pull start")
    end)
    reg("-boss end", function(p, pid, msg)
        local id = parseTail(msg, "-boss end")
        InstanceSignals.BossPullEnd(id ~= "" and id or "DUNGEON")
        DisplayTextToPlayer(p, 0, 0, "[Signal] Boss pull end")
    end)
    reg("-boss win", function(p, pid, msg)
        local id = parseTail(msg, "-boss win")
        InstanceSignals.BossDefeated(id ~= "" and id or "DUNGEON", "BOSS")
        DisplayTextToPlayer(p, 0, 0, "[Signal] Boss defeated")
    end)
    -- Wipe
    reg("-wipe", function(p, pid, msg)
        local id = parseTail(msg, "-wipe")
        InstanceSignals.Wipe(id ~= "" and id or "DUNGEON")
        DisplayTextToPlayer(p, 0, 0, "[Signal] Wipe")
    end)
    -- Trials
    reg("-trial 1", function(p) InstanceSignals.TrialPhase("TRIAL", 1); DisplayTextToPlayer(p,0,0,"[Signal] Trial Phase 1") end)
    reg("-trial 2", function(p) InstanceSignals.TrialPhase("TRIAL", 2); DisplayTextToPlayer(p,0,0,"[Signal] Trial Phase 2") end)
    reg("-trial 3", function(p) InstanceSignals.TrialPhase("TRIAL", 3); DisplayTextToPlayer(p,0,0,"[Signal] Trial Phase 3") end)

    --------------------------------------------------
    -- Init marker
    --------------------------------------------------
    OnInit.final(function()
        if InitBroker and InitBroker.SystemReady then
            InitBroker.SystemReady("DungeonTrialSignals")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
