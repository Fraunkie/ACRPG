--==================================================
-- HFILQuests.lua
-- See original .wct for full comments and implementation details
--==================================================

-- ...existing code from the extracted HFILQuests block...
if Debug and Debug.beginFile then Debug.beginFile("HFILQuests.lua") end
--==================================================
-- HFILQuests.lua
-- Task logic only. No UI here.
-- • ProposeTwo(pid) -> two choices for YemmaTaskMenu
-- • CommitChosen(pid, choice) -> saves currentTask on player
-- • GetCurrent(pid), ClearCurrent(pid)
-- • AddProgress(pid, n), CanTurnIn(pid), TurnInAtYemma(pid)
-- • Dev: -taskc to auto complete current task
--==================================================

if not HFILQuests then HFILQuests = {} end
_G.HFILQuests = HFILQuests

do
    --------------------------------------------------
    -- Safe PlayerData access
    --------------------------------------------------
    local function PD(pid)
        if _G.PlayerData and PlayerData.Get then
            local ok, t = pcall(PlayerData.Get, pid)
            if ok and t then return t end
        end
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        return PLAYER_DATA[pid]
    end

    --------------------------------------------------
    -- Minimal RNG wrappers
    --------------------------------------------------
    local function rnd(lo, hi)
        return GetRandomInt(lo, hi)
    end

    --------------------------------------------------
    -- Task handler pools
    -- Add your own entries following the same shape.
    -- Fields:
    --  id       unique key
    --  title    display name
    --  typeTag  common or special or rare
    --  eligible(pid) -> bool
    --  make(pid) -> table with task data fields like goal, target, etc
    --  reward(pid, task) -> { soul = n, frags = m }
    --==================================================

    HFILQuests._POOL_REGULAR = HFILQuests._POOL_REGULAR or {
        {
            id = "cull_restless",
            title = "Cull the Restless",
            typeTag = "common",
            eligible = function(pid) return true end,
            make = function(pid)
                return { kind = "kill", target = "spirit", goal = 6 }
            end,
            reward = function(pid, task)
                return { soul = 10, frags = 1 }
            end,
        },
        {
            id = "gather_soulshards",
            title = "Gather Shards",
            typeTag = "common",
            eligible = function(pid) return true end,
            make = function(pid)
                return { kind = "collect", item = "soul_shard", goal = 6 }
            end,
            reward = function(pid, task)
                return { soul = 8, frags = 2 }
            end,
        },
        {
            id = "clean_up",
            title = "Clean Up Stragglers",
            typeTag = "common",
            eligible = function(pid) return true end,
            make = function(pid)
                return { kind = "kill", target = "minor_spirit", goal = 12 }
            end,
            reward = function(pid, task)
                return { soul = 12, frags = 1 }
            end,
        },
    }

    HFILQuests._POOL_SPECIAL = HFILQuests._POOL_SPECIAL or {
        {
            id = "cleanse_shrine",
            title = "Cleanse a Shrine",
            typeTag = "special",
            eligible = function(pid)
                local pow = PD(pid).powerLevel or 0
                return pow >= 5
            end,
            make = function(pid)
                return { kind = "interact", target = "shrine", goal = 1 }
            end,
            reward = function(pid, task)
                return { soul = 16, frags = 2 }
            end,
        },
        {
            id = "escort_spirit",
            title = "Guide a Lost Spirit",
            typeTag = "special",
            eligible = function(pid)
                local pow = PD(pid).powerLevel or 0
                return pow >= 6
            end,
            make = function(pid)
                return { kind = "escort", target = "lost_spirit", goal = 1 }
            end,
            reward = function(pid, task)
                return { soul = 18, frags = 2 }
            end,
        },
    }

    HFILQuests._POOL_RARE = HFILQuests._POOL_RARE or {
        {
            id = "ancient_echo",
            title = "Answer the Ancient Echo",
            typeTag = "rare",
            eligible = function(pid)
                local pow = PD(pid).powerLevel or 0
                return pow >= 12
            end,
            make = function(pid)
                return { kind = "boss", target = "echo", goal = 1 }
            end,
            reward = function(pid, task)
                return { soul = 30, frags = 4 }
            end,
        },
        {
            id = "rift_seal",
            title = "Seal a Minor Rift",
            typeTag = "rare",
            eligible = function(pid)
                local pow = PD(pid).powerLevel or 0
                return pow >= 14
            end,
            make = function(pid)
                return { kind = "channel", target = "rift", goal = 1 }
            end,
            reward = function(pid, task)
                return { soul = 28, frags = 5 }
            end,
        },
    }

    --------------------------------------------------
    -- Internal pick helper
    --------------------------------------------------
    local function pickFrom(pool, pid, avoidId)
        local cands = {}
        for i = 1, #pool do
            local h = pool[i]
            if h and h.eligible and h.eligible(pid) and h.id ~= avoidId then
                cands[#cands + 1] = h
            end
        end
        if #cands == 0 then return nil end
        local i = rnd(1, #cands)
        local h = cands[i]
        return { id = h.id, title = h.title or h.id, typeTag = h.typeTag or "common", _handler = h }
    end

    --------------------------------------------------
    -- Public: propose two choices
    -- A is regular. B rolls rare, then special, else regular.
    --------------------------------------------------
    function HFILQuests.ProposeTwo(pid)
        local A = pickFrom(HFILQuests._POOL_REGULAR, pid, nil)

        local B = nil
        local roll = rnd(1, 100)
        if roll <= 10 then
            B = pickFrom(HFILQuests._POOL_RARE, pid, A and A.id or nil)
        end
        if not B and roll <= 45 then
            B = pickFrom(HFILQuests._POOL_SPECIAL, pid, A and A.id or nil)
        end
        if not B then
            B = pickFrom(HFILQuests._POOL_REGULAR, pid, A and A.id or nil)
        end

        if not A then
            A = pickFrom(HFILQuests._POOL_REGULAR, pid, B and B.id or nil)
        end

        return A, B
    end

    --------------------------------------------------
    -- Public: commit chosen task to player state
    --------------------------------------------------
    function HFILQuests.CommitChosen(pid, choice)
        if not choice or not choice._handler then
            DisplayTextToPlayer(Player(pid), 0, 0, "No valid task choice")
            return nil
        end

        local made = {}
        if choice._handler.make then
            local ok, res = pcall(choice._handler.make, pid)
            if ok and type(res) == "table" then made = res end
        end

        local pd = PD(pid)
        pd.currentTask = {
            id = choice.id,
            title = choice.title or choice.id,
            typeTag = choice.typeTag or "common",
            data = made,
            progress = 0,
            goal = made.goal or 0,
        }
        return pd.currentTask
    end

    --------------------------------------------------
    -- Public: read or clear current task
    --------------------------------------------------
    function HFILQuests.GetCurrent(pid)
        local pd = PD(pid)
        return pd.currentTask
    end

    function HFILQuests.ClearCurrent(pid)
        local pd = PD(pid)
        pd.currentTask = nil
    end

    --------------------------------------------------
    -- Progress helpers
    --------------------------------------------------
    function HFILQuests.AddProgress(pid, n)
        local pd = PD(pid)
        local t = pd.currentTask
        if not t then return 0, 0 end
        local p = t.progress or 0
        local g = t.goal or 0
        p = p + (n or 0)
        if g > 0 and p > g then p = g end
        t.progress = p
        return p, g
    end

    function HFILQuests.CanTurnIn(pid)
        local t = HFILQuests.GetCurrent(pid)
        if not t then return false end
        local g = t.goal or 0
        local p = t.progress or 0
        if g == 0 then return true end
        return p >= g
    end

    --------------------------------------------------
    -- Turn in and rewards
    --------------------------------------------------
    local function resolveHandlerById(pool, id)
        for i = 1, #pool do
            if pool[i].id == id then return pool[i] end
        end
        return nil
    end
    local function findHandler(id)
        local h = resolveHandlerById(HFILQuests._POOL_REGULAR, id)
        if h then return h end
        h = resolveHandlerById(HFILQuests._POOL_SPECIAL, id)
        if h then return h end
        h = resolveHandlerById(HFILQuests._POOL_RARE, id)
        return h
    end

    function HFILQuests.TurnInAtYemma(pid)
        local pd = PD(pid)
        local t = pd.currentTask
        if not t then
            DisplayTextToPlayer(Player(pid), 0, 0, "No active task")
            return false
        end
        if not HFILQuests.CanTurnIn(pid) then
            DisplayTextToPlayer(Player(pid), 0, 0, "Task is not complete")
            return false
        end

        local h = findHandler(t.id)
        local soul, frags = 0, 0
        if h and h.reward then
            local ok, r = pcall(h.reward, pid, t)
            if ok and r then
                soul = r.soul or 0
                frags = r.frags or 0
            end
        end

        pd.soulEnergy = (pd.soulEnergy or 0) + soul
        pd.fragments  = (pd.fragments or 0) + frags

        DisplayTextToPlayer(Player(pid), 0, 0, "Task turned in")
        if soul > 0 then
            DisplayTextToPlayer(Player(pid), 0, 0, "Soul Energy gained " .. tostring(soul))
        end
        if frags > 0 then
            DisplayTextToPlayer(Player(pid), 0, 0, "Fragments gained " .. tostring(frags))
        end

        pd.currentTask = nil
        return true
    end

    --------------------------------------------------
    -- Dev command: auto complete current task
    --------------------------------------------------
    OnInit.final(function()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-taskc", true)
        end
        TriggerAddAction(trig, function()
            local pid = GetPlayerId(GetTriggerPlayer())
            local t = HFILQuests.GetCurrent(pid)
            if not t then
                DisplayTextToPlayer(Player(pid), 0, 0, "No active task")
                return
            end
            local g = t.goal or 0
            t.progress = g
            DisplayTextToPlayer(Player(pid), 0, 0, "Task set to complete")
        end)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("HFILQuests")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
