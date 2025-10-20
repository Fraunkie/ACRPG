if Debug and Debug.beginFile then Debug.beginFile("LootSystem.lua") end
--==================================================
-- LootSystem.lua
-- Handles reward drops, chest creation, and roll logic.
-- • Ignores bag units completely.
-- • Supports group roll chest for rare items.
--==================================================

if not LootSystem then LootSystem = {} end
_G.LootSystem = LootSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local CHEST_UNIT_ID = FourCC("nCHT") -- loot chest dummy
    local ROLL_DURATION = 10.0            -- seconds before auto drop
    local ROLL_RADIUS   = 1000.0
    local FX_CHEST      = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local activeChests = {} -- chest -> {item, timer, rolls, players}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function validItem(i) return i and GetItemTypeId(i) ~= 0 end

    local function isBag(u)
        return _G.BagSystem and BagSystem.IgnoreInCombat and BagSystem.IgnoreInCombat(u)
    end

    local function pidOf(u)
        local p = GetOwningPlayer(u)
        return p and GetPlayerId(p) or nil
    end

    local function rollItemForPlayer(pid, itemId)
        local u = PlayerData.Get(pid).hero
        if validUnit(u) then
            if UnitAddItemById(u, itemId) then
                DisplayTextToPlayer(Player(pid), 0, 0, "|cff88ff88Loot received:|r " .. GetObjectName(itemId))
                return true
            else
                -- fallback: drop at hero feet if bag full
                local x, y = GetUnitX(u), GetUnitY(u)
                CreateItem(itemId, x, y)
            end
        end
    end

    --------------------------------------------------
    -- Group roll system
    --------------------------------------------------
    local function finishRoll(chest)
        local data = activeChests[chest]
        if not data then return end

        local bestPid, bestRoll = nil, -1
        for pid, roll in pairs(data.rolls) do
            if roll > bestRoll then
                bestRoll = roll
                bestPid = pid
            end
        end

        if bestPid then
            DisplayTextToForce(bj_FORCE_ALL_PLAYERS,
                "|cff88ff88Loot:|r " .. GetObjectName(data.item) .. " → " .. GetPlayerName(Player(bestPid)) ..
                " (Roll " .. bestRoll .. ")")
            rollItemForPlayer(bestPid, data.item)
        else
            -- no rolls, drop item at chest
            CreateItem(data.item, GetUnitX(chest), GetUnitY(chest))
        end

        DestroyEffect(AddSpecialEffect(FX_CHEST, GetUnitX(chest), GetUnitY(chest)))
        RemoveUnit(chest)
        activeChests[chest] = nil
    end

    local function startRoll(chest, itemId, players)
        local t = CreateTimer()
        local rolls = {}
        activeChests[chest] = { item = itemId, timer = t, rolls = rolls, players = players }

        DisplayTextToForce(bj_FORCE_ALL_PLAYERS,
            "|cffffff00Roll for loot:|r " .. GetObjectName(itemId) ..
            " (type -roll) |cffffcc00" .. ROLL_DURATION .. "s|r")

        TimerStart(t, ROLL_DURATION, false, function()
            finishRoll(chest)
            DestroyTimer(t)
        end)
    end

    --------------------------------------------------
    -- Drop handler
    --------------------------------------------------
    function LootSystem.DropLoot(dead, players)
        if not validUnit(dead) then return end
        local id = GetUnitTypeId(dead)
        local config = _G.HFILUnitConfig and HFILUnitConfig.GetByFour(id)
        if not config then return end

        -- Common item roll
        local fragChance = config.fragChancePermil or 0
        if math.random(1, 1000) <= fragChance then
            for _, pid in ipairs(players or {}) do
                local u = PlayerData.Get(pid).hero
                if validUnit(u) then
                    local x, y = GetUnitX(u), GetUnitY(u)
                    CreateItem(FourCC("I010"), x, y) -- fragment drop
                end
            end
        end

        -- Rare roll chest (shared)
        local shardChance = config.shardChancePermil or 0
        if math.random(1, 1000) <= shardChance then
            local x, y = GetUnitX(dead), GetUnitY(dead)
            local chest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), CHEST_UNIT_ID, x, y, 0)
            startRoll(chest, FourCC("I00W"), players or {})
        end
    end

    --------------------------------------------------
    -- Roll command
    --------------------------------------------------
    local function regRoll()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), "-roll", true)
        end
        TriggerAddAction(t, function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p)
            for chest, data in pairs(activeChests) do
                if data.players and table.contains and table.contains(data.players, pid) then
                    if not data.rolls[pid] then
                        data.rolls[pid] = math.random(1, 100)
                        DisplayTextToPlayer(p, 0, 0, "You rolled " .. data.rolls[pid])
                    else
                        DisplayTextToPlayer(p, 0, 0, "You already rolled.")
                    end
                end
            end
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        regRoll()
        print("[LootSystem] ready (group roll and per-player drops)")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("LootSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
