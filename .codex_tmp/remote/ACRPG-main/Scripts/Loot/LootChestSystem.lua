if Debug and Debug.beginFile then Debug.beginFile("LootChestSystem.lua") end
--==================================================
-- LootChestSystem.lua
-- Multiplayer-safe chest roll system.
-- One shared loot roll per chest.
--==================================================

if not LootChestSystem then LootChestSystem = {} end
_G.LootChestSystem = LootChestSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local ROLL_TIME     = 15.0
    local CHEST_MODEL   = "Objects\\InventoryItems\\TreasureChest\\treasurechest.mdl"
    local FX_REWARD     = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"
    local TEXT_COLOR    = "|cff88ff88"
    local ROLL_COLOR    = "|cffffee55"
    local DEFAULT_ITEM  = "I020"

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local activeChests = {} -- chest -> { itemId, timer, rolls = {pid=result}, timeout }
    local rollEnabled  = {} -- pid -> bool (toggle visibility)

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function validItem(i) return i and GetItemTypeId(i) ~= 0 end

    local function announceAll(msg)
        for i = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerSlotState(Player(i)) == PLAYER_SLOT_STATE_PLAYING then
                DisplayTextToPlayer(Player(i), 0, 0, msg)
            end
        end
    end

    local function dropItemAt(itemId, x, y)
        if not itemId then return end
        local item = ItemDatabase.CreateItem(itemId, x, y)
        if item then
            DestroyEffect(AddSpecialEffect(FX_REWARD, x, y))
        end
    end

    --------------------------------------------------
    -- Core chest roll logic
    --------------------------------------------------
    local function startRoll(chest, itemId)
        if not validUnit(chest) or not itemId then return end
        local x, y = GetUnitX(chest), GetUnitY(chest)
        local data = { itemId = itemId, rolls = {}, timeout = ROLL_TIME }
        activeChests[chest] = data

        announceAll(ROLL_COLOR .. "A loot chest has appeared! Type -roll to participate (" .. ROLL_TIME .. "s)")
        DestroyEffect(AddSpecialEffect(CHEST_MODEL, x, y))

        local t = CreateTimer()
        TimerStart(t, 1.0, true, function()
            data.timeout = data.timeout - 1
            if data.timeout <= 0 then
                DestroyTimer(t)
                local winner, high = nil, -1
                for pid, roll in pairs(data.rolls) do
                    if roll > high then
                        winner, high = pid, roll
                    end
                end
                if winner then
                    local wp = Player(winner)
                    local hero = PlayerData.Get(winner).hero
                    if validUnit(hero) then
                        UnitAddItemById(hero, FourCC(itemId))
                        DisplayTextToPlayer(wp, 0, 0, TEXT_COLOR .. "You won " .. ItemDatabase.GetName(itemId) .. " with " .. high .. "!")
                        DestroyEffect(AddSpecialEffect(FX_REWARD, GetUnitX(hero), GetUnitY(hero)))
                    end
                    announceAll(TEXT_COLOR .. GetPlayerName(wp) .. " won " .. ItemDatabase.GetName(itemId) .. " (" .. high .. ")")
                else
                    announceAll(ROLL_COLOR .. "No rolls made — item dropped on ground.")
                    dropItemAt(itemId, x, y)
                end
                RemoveUnit(chest)
                activeChests[chest] = nil
            end
        end)
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function LootChestSystem.Spawn(itemId, x, y)
        local chest = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FourCC("nCST"), x, y, 0)
        startRoll(chest, itemId or DEFAULT_ITEM)
        return chest
    end

    function LootChestSystem.OnRoll(p)
        local pid = GetPlayerId(p)
        for chest, data in pairs(activeChests) do
            if data.timeout and data.timeout > 0 then
                if data.rolls[pid] then
                    DisplayTextToPlayer(p, 0, 0, "You already rolled.")
                else
                    local val = GetRandomInt(1, 100)
                    data.rolls[pid] = val
                    announceAll(ROLL_COLOR .. GetPlayerName(p) .. " rolled " .. val)
                end
            end
        end
    end

    function LootChestSystem.ToggleRolls(pid)
        rollEnabled[pid] = not rollEnabled[pid]
        DisplayTextToPlayer(Player(pid), 0, 0, "Global roll messages " .. (rollEnabled[pid] and "on" or "off"))
    end

    --------------------------------------------------
    -- Chat command hook
    --------------------------------------------------
    local function reg(cmd, fn)
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(t, Player(i), cmd, true)
        end
        TriggerAddAction(t, function()
            fn(GetTriggerPlayer())
        end)
    end
    reg("-roll", LootChestSystem.OnRoll)
    reg("-rolltoggle", function(p) LootChestSystem.ToggleRolls(GetPlayerId(p)) end)

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        print("[LootChestSystem] ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("LootChestSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
