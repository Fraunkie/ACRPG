if Debug and Debug.beginFile then Debug.beginFile("ShardChargeSystem.lua") end
--==================================================
-- ShardChargeSystem.lua
-- Marks shard items as charged and manages consumption.
-- Integrates with SpiritDrive full events.
--==================================================

if not ShardChargeSystem then ShardChargeSystem = {} end
_G.ShardChargeSystem = ShardChargeSystem

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local CHARGE_ON_FULL_SD       = true
    local ONE_CHARGE_PER_FULL     = true
    local SET_ITEM_CHARGES_VISUAL = true

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardCharge] " .. tostring(s)) end
    end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function PD(pid)
        if not PLAYER_DATA then PLAYER_DATA = {} end
        PLAYER_DATA[pid] = PLAYER_DATA[pid] or {}
        local pd = PLAYER_DATA[pid]
        pd.chargedShards   = pd.chargedShards   or {}
        pd.chargedFamilies = pd.chargedFamilies or {}
        return pd
    end

    local function getHero(pid)
        local pd = PD(pid)
        if validUnit(pd.hero) then return pd.hero end
        if _G.PlayerHero and validUnit(_G.PlayerHero[pid]) then return _G.PlayerHero[pid] end
        return nil
    end

    local function familyKeyForItemType(itemTypeId)
        if _G.GameBalance and GameBalance.FamilyKeyForItem then
            local fk = GameBalance.FamilyKeyForItem(itemTypeId)
            if fk then return fk end
        end
        if _G.ShardFamilySystem and ShardFamilySystem.GetFamilyByItemId then
            local ok, fk = pcall(ShardFamilySystem.GetFamilyByItemId, itemTypeId)
            if ok and fk then return fk end
        end
        if _G.ShardSystem and ShardSystem.GetFamilyKeyByItem then
            local ok2, fk2 = pcall(ShardSystem.GetFamilyKeyByItem, itemTypeId)
            if ok2 and fk2 then return fk2 end
        end
        return nil
    end

    local function isShardItemHandle(it)
        if not it then return false end
        if _G.ShardSystem and ShardSystem.IsShardItemHandle then
            local ok, res = pcall(ShardSystem.IsShardItemHandle, it)
            if ok then return res == true end
        end
        -- fallback heuristic: look for a known family mapping
        local id = GetItemTypeId(it)
        if id == 0 then return false end
        return familyKeyForItemType(id) ~= nil
    end

    --------------------------------------------------
    -- Public queries
    --------------------------------------------------
    function ShardChargeSystem.IsCharged(pid, itemTypeId)
        local pd = PD(pid)
        return pd.chargedShards[itemTypeId] == true
    end

    function ShardChargeSystem.HasChargedShard(pid)
        local pd = PD(pid)
        -- check inventory
        local u = getHero(pid)
        if not validUnit(u) then return false end
        for slot = 0, 5 do
            local it = UnitItemInSlot(u, slot)
            if it then
                local id = GetItemTypeId(it)
                if id ~= 0 and pd.chargedShards[id] then
                    return true
                end
            end
        end
        return false
    end

    --------------------------------------------------
    -- Charging and consuming
    --------------------------------------------------
    local function markCharged(pid, itemTypeId, famKey, itemHandle)
        local pd = PD(pid)
        pd.chargedShards[itemTypeId] = true
        if famKey then pd.chargedFamilies[famKey] = true end
        if SET_ITEM_CHARGES_VISUAL and itemHandle and SetItemCharges then
            pcall(SetItemCharges, itemHandle, 1)
        end
        dprint("charged item " .. tostring(itemTypeId) .. " for p" .. tostring(pid))
    end

    function ShardChargeSystem.TryChargeOne(pid)
        local u = getHero(pid)
        if not validUnit(u) then return false end
        for slot = 0, 5 do
            local it = UnitItemInSlot(u, slot)
            if it and isShardItemHandle(it) then
                local id = GetItemTypeId(it)
                if id ~= 0 and not ShardChargeSystem.IsCharged(pid, id) then
                    local fam = familyKeyForItemType(id)
                    markCharged(pid, id, fam, it)
                    return true
                end
            end
        end
        return false
    end

    function ShardChargeSystem.TryChargeAll(pid)
        local u = getHero(pid)
        if not validUnit(u) then return 0 end
        local count = 0
        for slot = 0, 5 do
            local it = UnitItemInSlot(u, slot)
            if it and isShardItemHandle(it) then
                local id = GetItemTypeId(it)
                if id ~= 0 and not ShardChargeSystem.IsCharged(pid, id) then
                    local fam = familyKeyForItemType(id)
                    markCharged(pid, id, fam, it)
                    count = count + 1
                end
            end
        end
        return count
    end

    -- Consume any one charged shard in inventory
    function ShardChargeSystem.ConsumeChargedShard(pid)
        local pd = PD(pid)
        local u = getHero(pid)
        if not validUnit(u) then return false end
        for slot = 0, 5 do
            local it = UnitItemInSlot(u, slot)
            if it then
                local id = GetItemTypeId(it)
                if id ~= 0 and pd.chargedShards[id] then
                    pd.chargedShards[id] = nil
                    if SetItemCharges then pcall(SetItemCharges, it, 0) end
                    dprint("consumed charged shard " .. tostring(id) .. " for p" .. tostring(pid))
                    return true
                end
            end
        end
        return false
    end

    function ShardChargeSystem.ClearAll(pid)
        local pd = PD(pid)
        pd.chargedShards = {}
        pd.chargedFamilies = {}
        dprint("cleared all charges for p" .. tostring(pid))
    end

    --------------------------------------------------
    -- Wiring: auto charge when SpiritDrive is full
    --------------------------------------------------
    local function wireSpiritDrive()
        if not CHARGE_ON_FULL_SD then return end
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnSpiritDriveFull", function(e)
                if not e or e.pid == nil then return end
                local pid = e.pid
                if ONE_CHARGE_PER_FULL then
                    ShardChargeSystem.TryChargeOne(pid)
                else
                    ShardChargeSystem.TryChargeAll(pid)
                end
            end)
            return
        end
        -- direct subscription fallback if SpiritDrive has its own subscribe
        if _G.SpiritDrive and SpiritDrive.Subscribe then
            SpiritDrive.Subscribe("OnFull", function(pid)
                if ONE_CHARGE_PER_FULL then
                    ShardChargeSystem.TryChargeOne(pid)
                else
                    ShardChargeSystem.TryChargeAll(pid)
                end
            end)
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            wireSpiritDrive()
            dprint("ready")
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("ShardChargeSystem")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
