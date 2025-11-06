if Debug and Debug.beginFile then Debug.beginFile("ShardChargeSystem.lua") end
--==================================================
-- ShardChargeSystem.lua (per-shard conditions)
-- • CURRENT: only Goku shard (I00W)
-- • Cond: player has it in CUSTOM inventory AND Spirit Drive hits 100
-- • Effect: mark charged in PLAYER_DATA and tell the player
-- • No WC3 item charges, no fragment cost
--==================================================

if not ShardChargeSystem then ShardChargeSystem = {} end
_G.ShardChargeSystem = ShardChargeSystem

do
    --------------------------------------------------
    -- CONFIG
    --------------------------------------------------
    local GOKU_SHARD_ID = FourCC("I00W")

    -- later we can add more:
    -- [FourCC("I0XY")] = { id=FourCC("I0XY"), cond="boss_killed:garlicjr" },
    local SHARD_RULES = {
        [GOKU_SHARD_ID] = {
            id   = GOKU_SHARD_ID,
            name = "Goku Ascension Shard",
            mode = "spirit_full",  -- current mode
        },
    }

    --------------------------------------------------
    -- INTERNAL HELPERS
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardCharge] " .. tostring(s)) end
    end

    local function PD(pid)
        PLAYER_DATA = PLAYER_DATA or {}
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.chargedShards = pd.chargedShards or {}
        return pd
    end

    -- read custom inventory (NOT WC3 inventory)
    local function listCustomInv(pid)
        if _G.InventoryService and InventoryService.List then
            local ok, list = pcall(InventoryService.List, pid)
            if ok and type(list) == "table" then
                return list
            end
        end
        return {}
    end

    -- does player have this itemId in custom inv?
    local function hasCustomItem(pid, itemId)
        local list = listCustomInv(pid)
        for _, v in ipairs(list) do
            if v == itemId then
                return true
            end
        end
        return false
    end

    -- mark charged + notify + tell UI (if exists)
    local function markCharged(pid, itemId, niceName)
        local pd = PD(pid)
        pd.chargedShards[itemId] = true

        local p = Player(pid)
        if niceName and niceName ~= "" then
            DisplayTextToPlayer(p, 0, 0, niceName .. " (Charged)")
        else
            DisplayTextToPlayer(p, 0, 0, "Shard charged.")
        end

        -- if your inventory UI has a refresh, call it
        if _G.PlayerMenu_InventoryModule and PlayerMenu_InventoryModule.Render then
            pcall(PlayerMenu_InventoryModule.Render, pid)
        end

        -- let other systems know
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit("OnShardCharged", { pid = pid, itemId = itemId })
        end

        dprint("charged shard " .. tostring(itemId) .. " for p" .. tostring(pid))
    end

    --------------------------------------------------
    -- PUBLIC QUERY (so UI can check)
    --------------------------------------------------
    function ShardChargeSystem.IsCharged(pid, itemId)
        local pd = PD(pid)
        return pd.chargedShards[itemId] == true
    end

    --------------------------------------------------
    -- CORE: handle spirit-drive-full
    --------------------------------------------------
    local function onSpiritDriveFull(e)
        if not e or e.pid == nil then return end
        local pid = e.pid

        -- scan all defined shards
        for itemId, rule in pairs(SHARD_RULES) do
            -- only process spirit-full ones here
            if rule.mode == "spirit_full" then
                -- must own the shard in CUSTOM inventory
                if hasCustomItem(pid, itemId) then
                    -- must NOT be already charged
                    if not ShardChargeSystem.IsCharged(pid, itemId) then
                        markCharged(pid, itemId, rule.name)
                    end
                end
            end
        end
    end

    --------------------------------------------------
    -- INIT
    --------------------------------------------------
    OnInit.final(function()
        -- hook into ProcBus
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSpiritDriveFull", onSpiritDriveFull)
            dprint("wired to ProcBus.OnSpiritDriveFull")
        else
            dprint("WARNING: ProcBus missing, shard auto-charge will not run.")
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ShardChargeSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
