if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua
-- Canonical per-player runtime store and helpers
-- • Includes soul progression mirrors and XP bonus knob
-- • ASCII only
--==================================================

do
    PlayerData = PlayerData or {}
    _G.PlayerData = PlayerData

    -- Default per-player table
    local function defaultTable()
        return {
            hero = nil,
            tier = 0,
            role = "NONE",
            zone = "YEMMA",
            powerLevel = 0,

            -- Soul progression mirrors (Runescape-like)
            soulEnergy = 0,     -- total lifetime soul points (for now)
            soulLevel  = 1,
            soulXP     = 0,
            soulNextXP = 200,

            -- Tunables and bonuses
            xpBonusPercent = 0,          -- numeric percent
            statChanceBonusPermil = 0,   -- out of 1000
            dropLuckBonusPermil = 0,

            -- Currency / ownership
            fragments    = 0,
            ownedShards  = {},

            -- Spirit Drive
            spiritDrive  = 0,

            -- UX toggles
            lootChatEnabled = true,

            -- capsule bags
            capsulebag = nil,

            -- Intro / Yemma flow
            hasStarted            = false,
            introChoice           = nil,
            introCompleted        = false,
            introStyle            = nil,
            yemmaPromptShown      = false,
            yemmaPromptMinimized  = false,

            -- Tasks (legacy mirror; safe defaults)
            hfilTask = { active=false, id=nil, name="", desc="", goalType="", need=0, have=0, rarity="Common" },
            activeTask = nil,

            -- Misc session
            teleports  = {},
            killCounts = {},
            lastKillAt = 0,
            statFinds  = 0,
            pity       = { stat=0, shard=0, fragment=0 },
            xpShareEnabled = true,
        }
    end

    -- Public API
    function PlayerData.Get(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
        return PLAYER_DATA[pid]
    end

    function PlayerData.Set(pid, key, val)
        local t = PlayerData.Get(pid)
        t[key] = val
        return t[key]
    end

    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then return defaultValue end
        return v
    end

    -- Legacy task helpers (kept for UI safety)
    function PlayerData.SetActiveTask(pid, task)
        local pd = PlayerData.Get(pid)
        local ht = pd.hfilTask
        ht.active   = true
        ht.id       = task.id or ht.id
        ht.name     = task.name or ""
        ht.desc     = task.desc or ""
        ht.goalType = task.goalType or ""
        ht.rarity   = task.rarity or "Common"
        ht.need     = task.goal or task.need or 1
        ht.have     = task.progress or 0
        pd.activeTask = { name=ht.name, rarity=ht.rarity, goal=ht.need, progress=ht.have }
        return ht
    end

    function PlayerData.GetActiveTask(pid)
        local pd = PlayerData.Get(pid)
        local ht = pd.hfilTask
        if ht and ht.active then
            return { name=ht.name, rarity=ht.rarity, goal=ht.need, progress=ht.have }
        end
        return nil
    end

    function PlayerData.AddTaskProgress(pid, amount)
        local pd = PlayerData.Get(pid)
        local ht = pd.hfilTask
        if not ht or not ht.active then return end
        ht.have = math.min((ht.have or 0) + (amount or 1), ht.need or 1)
        pd.activeTask = { name=ht.name, rarity=ht.rarity, goal=ht.need, progress=ht.have }
    end

    function PlayerData.ClearTask(pid)
        local pd = PlayerData.Get(pid)
        pd.hfilTask = { active=false, id=nil, name="", desc="", goalType="", need=0, have=0, rarity="Common" }
        pd.activeTask = nil
    end

    -- Boot-time ensure for all human slots
    OnInit.final(function()
        if not PLAYER_DATA then PLAYER_DATA = {} end
        for pid=0,bj_MAX_PLAYERS-1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
            end
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
