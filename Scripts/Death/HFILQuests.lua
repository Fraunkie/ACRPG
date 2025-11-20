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
    local function rnd(lo, hi) return GetRandomInt(lo, hi) end

    --------------------------------------------------
    -- Internal helpers for power-scaled goals & rewards
    --------------------------------------------------
    local function clamp(v, lo, hi)
        if v < lo then return lo elseif v > hi then return hi else return v end
    end
    local function lerp(a, b, t) return a + (b - a) * t end
    local function pf(pid)
        local pd = PD(pid)
        local power = (pd.powerLevel or 0)
        local GB = GameBalance or {}
        local HR = GB.HFIL_TASK_REWARDS or {}
        local cap = HR.P_CAP or (GB.POWERLEVEL_CAP or 20)
        local t = power / cap
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        return t
    end
    local function rewardScaled(kind, goal, pid)
        local GB = GameBalance or {}
        local HR = GB.HFIL_TASK_REWARDS or {}
        local K  = (kind == "collect") and HR.COLLECT or HR.KILL
        local M  = HR.MULTS or {}
        local party = M.party or 1.0
        local difficulty = M.difficulty or 1.0
        local t  = pf(pid)
        local base  = (K.base or 1)
        local alpha = (K.alpha or 0)
        local soul  = math.floor((goal or 0) * base * (1 + alpha * t) * party * difficulty + 0.5)
        local frags = (K.fragsOnComplete or 0)
        return soul, frags
    end

    --------------------------------------------------
    -- Task handler pools
    -- Fields:
    --  id, title, desc, typeTag, eligible(pid), make(pid) -> data, reward(pid, task) -> { soul, frags }
    --------------------------------------------------
    HFILQuests._POOL_REGULAR = HFILQuests._POOL_REGULAR or {
        {
            id = "cull_restless",
            title = "Cull the Restless",
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
            desc = "Kill Wandering Spirits",
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
    -- New HFIL tasks (power-scaled goals)
    --------------------------------------------------
    ---kills task
    ------------------------------------------------
    HFILQuests._POOL_REGULAR[#HFILQuests._POOL_REGULAR + 1] = {
    id = "cull_n00G",
    title = "Cull Vengeful Wraith",
    desc = "Kill Vengeful Wraith",
    typeTag = "common",
    eligible = function(pid)
        return HFILUnitConfig.IsEligible(pid, "n00G")  -- Use IsEligible to check for Vengeful Wraith
    end,
    make = function(pid)
        local t = pf(pid)
        local minG = math.floor(lerp(6, 18, t))
        local maxG = math.floor(lerp(12, 30, t))
        local goal = rnd(minG, maxG)
        goal = clamp(goal, 1, 30)
        return { kind = "kill", raw = "n00G", goal = goal }
    end,
    reward = function(pid, task)
        local baseSoulPerKill  = 15
        local baseFragsPerKill = 1
        local goal  = (task and task.goal) or 0
        local soul  = baseSoulPerKill  * goal
        local frags = baseFragsPerKill * goal
        return { soul = soul, frags = frags }
    end,
}

HFILQuests._POOL_REGULAR[#HFILQuests._POOL_REGULAR + 1] = {
    id = "cull_n001",
    title = "Cull Wandering Spirits",
    desc = "Kill Wandering Spirits",
    typeTag = "common",
    eligible = function(pid)
        return HFILUnitConfig.IsEligible(pid, "n001")  -- Use IsEligible to check for Wandering Spirits
    end,
    make = function(pid)
        local t = pf(pid)
        local minG = math.floor(lerp(6, 18, t))
        local maxG = math.floor(lerp(12, 30, t))
        local goal = rnd(minG, maxG)
        goal = clamp(goal, 1, 30)
        return { kind = "kill", raw = "n001", goal = goal }
    end,
    reward = function(pid, task)
        local baseSoulPerKill  = 10
        local baseFragsPerKill = 1
        local goal  = (task and task.goal) or 0
        local soul  = baseSoulPerKill  * goal
        local frags = baseFragsPerKill * goal
        return { soul = soul, frags = frags }
    end,
}

HFILQuests._POOL_REGULAR[#HFILQuests._POOL_REGULAR + 1] = {
    id = "collect_spirit_fragments",
    title = "Gather Spirit Fragments",
    desc = "Kill Wandering Spirits",
    typeTag = "common",
    eligible = function(pid)
        return HFILUnitConfig.IsEligible(pid, "n001")  -- Use IsEligible to check for Wandering Spirits
    end,
    make = function(pid)
        local t = pf(pid)
        local minG = math.floor(lerp(8, 16, t))
        local maxG = math.floor(lerp(12, 24, t))
        local goal = rnd(minG, maxG)
        goal = clamp(goal, 1, 24)
        return {
            kind     = "collect",
            item     = "spirit_fragment",  -- Use "spirit_fragment" or your custom item
            sourceRaw = "n001",  -- You can change the raw ID as needed
            goal     = goal,
        }
    end,
    reward = function(pid, task)
        local baseSoulPerFrag  = 10
        local baseFragsPerFrag = 10
        local goal  = (task and task.goal) or 0
        local soul  = baseSoulPerFrag  * goal
        local frags = baseFragsPerFrag * goal
        return { soul = soul, frags = frags }
    end,
}
 HFILQuests._POOL_REGULAR[#HFILQuests._POOL_REGULAR + 1] = {
        id = "collect_vengeful_shards",
        title = "Gather Vengeful Shards",
        desc = "Collect Vengeful Shards from the Vengeful Wraith",
        typeTag = "common",
        eligible = function(pid)
            return HFILUnitConfig.IsEligible(pid, "n00G")  -- Use IsEligible to check for Wandering Spirits
        end,
        make = function(pid)
            local t = pf(pid)
            local minG = math.floor(lerp(6, 18, t))
            local maxG = math.floor(lerp(12, 30, t))
            local goal = rnd(minG, maxG)
            goal = clamp(goal, 1, 30)
            return {
                kind = "collect",
                item = "vengeful_shard",  -- Custom item name for collection
                goal = goal,
            }
        end,
        reward = function(pid, task)
            local baseSoulPerFrag  = 12
            local baseFragsPerFrag = 8
            local goal  = (task and task.goal) or 0
            local soul  = baseSoulPerFrag  * goal
            local frags = baseFragsPerFrag * goal
            return { soul = soul, frags = frags }
        end,
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
        return {
            id       = h.id,
            title    = h.title or h.id,
            typeTag  = h.typeTag or "common",
            _handler = h,
        }
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
            if ok and type(res) == "table" then
                made = res
            end
        end

        local pd = PD(pid)
        pd.currentTask = {
            id       = choice.id,
            title    = choice.title or choice.id,
            desc     = choice.desc or "Did not load Description",
            typeTag  = choice.typeTag or "common",
            data     = made,
            progress = 0,
            goal     = made.goal or 0,
        }
        TaskDisplay.ShowTask(pid)
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
        if g > 0 and p > g then
            p = g
        end
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
            if pool[i].id == id then
                return pool[i]
            end
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
                soul  = r.soul or 0
                frags = r.frags or 0
            end
        end

        --------------------------------------------------
        -- Soul Energy (XP)
        --------------------------------------------------
        if soul > 0 then
            if _G.SoulEnergy and SoulEnergy.AddXp then
                SoulEnergy.AddXp(pid, soul, "QuestTurnIn", { taskId = t.id })
            else
                pd.soulEnergy = (pd.soulEnergy or 0) + soul
            end
        end

        --------------------------------------------------
        -- Fragment currency + physical fragment items
        --------------------------------------------------
        if frags > 0 then
            -- numeric currency mirror
            pd.fragments = (pd.fragments or 0) + frags

            -- physical items: random among 4 fragment item ids
            local fragmentItemIds = {
                FourCC("I00U"), -- Dragon Ball Fragment
                FourCC("I012"), -- Digi Fragment
                FourCC("I00Z"), -- Poké Fragment
                FourCC("I00Y"), -- Chakra Fragment
            }

            local hero = nil
            if _G.PlayerData and PlayerData.GetHero then
                hero = PlayerData.GetHero(pid)
            end

            if hero and GetUnitTypeId(hero) ~= 0 then
                local hx = GetUnitX(hero)
                local hy = GetUnitY(hero)
                for i = 1, frags do
                    local idx = GetRandomInt(1, #fragmentItemIds)
                    local itId = fragmentItemIds[idx]
                    local item = CreateItem(itId, hx, hy)
                    UnitAddItem(hero, item)
                end
            end
        end

        --------------------------------------------------
        -- Feedback
        --------------------------------------------------
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

    --------------------------------------------------
    -- Virtual Spirit Fragment drop + task progress on n001 kills
        --------------------------------------------------
    local function ensureInv(pid, item)
        local pd = PD(pid)
        pd.inv = pd.inv or {}
        pd.inv[item] = pd.inv[item] or 0  -- Dynamically update based on the item parameter
        return pd.inv
    end

    local function isN00G(u)
        if not u or GetUnitTypeId(u) == 0 then return false end
        local ok, id = pcall(FourCC, "n00G")
        if not ok or not id then return false end
        return GetUnitTypeId(u) == id
    end

        local function isN001(u)
        if not u or GetUnitTypeId(u) == 0 then return false end
        local ok, id = pcall(FourCC, "n001")
        if not ok or not id then return false end
        return GetUnitTypeId(u) == id
    end

    local function getDropChance()
        local GB = GameBalance or {}
        local HR = GB.HFIL_TASK_REWARDS or {}
        local C = HR.COLLECT or {}
        local p = C.dropChance or 0.35
        if p < 0 then
            p = 0
        elseif p > 1 then
            p = 1
        end
        return p
    end
    ------------------------------------------------
---Wandering Spirit
------------------------------------------------
local function onKillN001(e)
    -- e.pid = killer pid, e.target = killed unit
    if not e or e.pid == nil or not isN001(e.target) then return end
    local pid = e.pid

    -- 1) Kill task progress (cull_n001)
    local t = HFILQuests.GetCurrent(pid)
    if t and t.id == "cull_n001"
        and t.data and t.data.kind == "kill"
        and (t.data.raw == "n001") then
        HFILQuests.AddProgress(pid, 1)
    end

    -- 2) Virtual fragment drop + collect task progress
    local chance = getDropChance()
    if GetRandomReal(0.0, 1.0) <= chance then
        local inv = ensureInv(pid, "spirit_fragment")  -- Pass the correct item name
        inv.spirit_fragment = (inv.spirit_fragment or 0) + 1

        local cur = HFILQuests.GetCurrent(pid)
        if cur
            and cur.id == "collect_spirit_fragments"
            and cur.data and cur.data.kind == "collect"
            and (cur.data.item == "spirit_fragment") then
            HFILQuests.AddProgress(pid, 1)
        end
    end
end

------------------------------------------------
---Vengeful Spirit
------------------------------------------------
local function onKillN00G(e)
    -- e.pid = killer pid, e.target = killed unit
    if not e or e.pid == nil or not isN00G(e.target) then return end
    local pid = e.pid

    -- 1) Kill task progress (cull_n00G)
    local t = HFILQuests.GetCurrent(pid)
    if t and t.id == "cull_n00G"
        and t.data and t.data.kind == "kill"
        and (t.data.raw == "n00G") then
        HFILQuests.AddProgress(pid, 1)
    end

    -- 2) Virtual fragment drop + collect task progress
    local chance = getDropChance()
    if GetRandomReal(0.0, 1.0) <= chance then
        local inv = ensureInv(pid, "vengeful_shard")  -- Pass the correct item name
        inv.vengeful_shard = (inv.vengeful_shard or 0) + 1

        local cur = HFILQuests.GetCurrent(pid)
        if cur
            and cur.id == "collect_vengeful_shards"
            and cur.data and cur.data.kind == "collect"
            and (cur.data.item == "vengeful_shard") then
            HFILQuests.AddProgress(pid, 1)
        end
    end
end




    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and (PB.On or PB.Subscribe) then
            local on = PB.On or PB.Subscribe
            on("OnKill", onKillN001)
            on("OnKill", onKillN00G)
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
