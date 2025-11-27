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
    local ROLL_DURATION = 10.0           -- seconds before auto drop
    local ROLL_RADIUS   = 1000.0
    local FX_CHEST      = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"

    -- Text Colors
    local COLOR_GOLD        = "|cffffee88"  -- Gold text (for important info)
    local COLOR_RED         = "|cffff5555"  -- Red text (for warnings or errors)
    local COLOR_ORANGE      = "|cffffaa00"  -- Orange text (for general use)
    local COLOR_GREEN       = "|cff33ff66"  -- Green text (for success messages)
    local COLOR_BLUE        = "|cff3399ff"  -- Blue text (for info or hints)
    local COLOR_PURPLE      = "|cffcc33ff"  -- Purple text (for special items or titles)
    local COLOR_WHITE       = "|cffffffff"  -- White text (for neutral text)
    local COLOR_YELLOW      = "|cffffff00"  -- Yellow text (for highlights or prompts)

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local activeChests = {} -- chest -> {item, timer, rolls, players}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function validItem(i)
        return i and GetItemTypeId(i) ~= 0
    end

    local function isBag(u)
        return _G.BagSystem and BagSystem.IgnoreInCombat and BagSystem.IgnoreInCombat(u)
    end

    local function pidOf(u)
        local p = GetOwningPlayer(u)
        return p and GetPlayerId(p) or nil
    end

    local function rollItemForPlayer(pid, itemId)
        local pdata = PlayerData.Get(pid)
        if not pdata then
            return
        end

        local u = pdata.hero
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
    -- Global item drop helpers (uses GameBalance.ITEMGLOBALDROPS)
    --------------------------------------------------
    local function LootSystem_PickGlobalRarity()
        -- chance is 0.0–1.0:
        -- 1.0 = 100%, 0.20 = 20%, 0.01 = 1%, 0.001 = 0.1%
        local function testChance(chance)
            if not chance or chance <= 0 then
                return false
            end
            if chance >= 1 then
                -- 1.0 or more = always true
                return true
            end
            local threshold = math.floor(chance * 10000 + 0.5)
            local roll = math.random(1, 10000)
            return roll <= threshold
        end

        -- Try rare first
        if testChance(GameBalance.ITEMGLOBALCHANCE_RARE) then
            return "rare"
        end

        -- Then uncommon
        if testChance(GameBalance.ITEMGLOBALCHANCE_UNCOMMON) then
            return "uncommon"
        end

        -- Then common
        if testChance(GameBalance.ITEMGLOBALCHANCE_COMMON) then
            return "common"
        end

        return nil
    end

    local function LootSystem_PickGlobalItemForZone(rarity, zone)
        local drops = GameBalance.ITEMGLOBALDROPS
        if not drops then
            return nil
        end

        local pool = drops[rarity]
        if not pool then
            return nil
        end

        -- First pass: compute total weight of eligible entries
        local totalWeight = 0
        for typeId, entry in pairs(pool) do
            if entry then
                if not entry.zone or (zone and entry.zone == zone) then
                    local w = entry.weight or 1
                    if w > 0 then
                        totalWeight = totalWeight + w
                    end
                end
            end
        end

        if totalWeight <= 0 then
            return nil
        end

        -- Second pass: weighted roll
        local roll = math.random(1, totalWeight)
        local running = roll

        for typeId, entry in pairs(pool) do
            if entry then
                if not entry.zone or (zone and entry.zone == zone) then
                    local w = entry.weight or 1
                    if w > 0 then
                        running = running - w
                        if running <= 0 then
                            return typeId
                        end
                    end
                end
            end
        end

        return nil
    end

    local function LootSystem_MaybeDropGlobalItem(dead, zone)
        local rarity = LootSystem_PickGlobalRarity()
        if not rarity then
            return
        end

        local itemTypeId = LootSystem_PickGlobalItemForZone(rarity, zone)
        if not itemTypeId then
            return
        end

        local x = GetUnitX(dead)
        local y = GetUnitY(dead)
        CreateItem(itemTypeId, x, y)
    end

    --------------------------------------------------
    -- Group roll system
    --------------------------------------------------
    local function finishRoll(chest)
        local data = activeChests[chest]
        if not data then
            return
        end

        local bestPid, bestRoll = nil, -1
        for pid, roll in pairs(data.rolls) do
            if roll > bestRoll then
                bestRoll = roll
                bestPid = pid
            end
        end

        if bestPid then
            DisplayTextToForce(
                bj_FORCE_ALL_PLAYERS,
                "|cff88ff88Loot:|r " .. GetObjectName(data.item) ..
                " → " .. GetPlayerName(Player(bestPid)) ..
                " (Roll " .. bestRoll .. ")"
            )
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

        DisplayTextToForce(
            bj_FORCE_ALL_PLAYERS,
            "|cffffff00Roll for loot:|r " .. GetObjectName(itemId) ..
            " (type -roll) |cffffcc00" .. ROLL_DURATION .. "s|r"
        )

        TimerStart(t, ROLL_DURATION, false, function()
            finishRoll(chest)
            DestroyTimer(t)
        end)
    end

    --------------------------------------------------
    -- Single-kill handler (per-killer)
    --------------------------------------------------
    function LootSystem.OnKill(killer, dead)
        if not validUnit(dead) then
            return
        end

        local id = GetUnitTypeId(dead)
        local config = _G.HFILUnitConfig and HFILUnitConfig.GetByTypeId(id)
        if not config then
            return
        end

        -- currency drop (Capsule Coins)
        local clow = config.cclow
        local chigh = config.cchigh

        local pdata = PlayerData.Get(killer)
        if pdata and validUnit(pdata.hero) then
            local old = pdata.currency.capsuleCoins
            local gain = math.random(clow, chigh)
            pdata.currency.capsuleCoins = old + gain

            NeatMessageToPlayerTimed(
                Player(killer),
                3,
                "Gained Capsule Coins " .. COLOR_BLUE .. tostring(gain) ..
                "|r" .. "+ New total " .. COLOR_BLUE .. tostring(pdata.currency.capsuleCoins)
            )

            -- Global item drop using player's current zone
            local zone = PlayerData.GetZone(killer)
            LootSystem_MaybeDropGlobalItem(dead, zone)
        end
    end

    --------------------------------------------------
    -- Main loot entry point (group loot)
    --------------------------------------------------
    function LootSystem.DropLoot(dead, players)
        if not validUnit(dead) then
            return
        end

        local id = GetUnitTypeId(dead)
        local config = _G.HFILUnitConfig and HFILUnitConfig.GetByFour(id)
        if not config then
            return
        end

        local clow = config.cclow
        local chigh = config.cchigh

        -- Coins for all contributing players
        for _, pid in ipairs(players or {}) do
            local pdata = PlayerData.Get(pid)
            if pdata and validUnit(pdata.hero) then
                local old = pdata.currency.capsuleCoins
                local gain = math.random(clow, chigh)
                pdata.currency.capsuleCoins = old + gain
            end
        end

        -- Determine zone from the first player in the list (player's current zone)
        local dropZone = nil
        if players and players[1] ~= nil then
            dropZone = PlayerData.GetZone(players[1])
        end

        -- Single global item roll per kill, using player's zone
        LootSystem_MaybeDropGlobalItem(dead, dropZone)
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
