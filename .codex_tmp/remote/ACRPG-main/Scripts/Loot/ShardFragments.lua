if Debug and Debug.beginFile then Debug.beginFile("ShardSystem.lua") end
--==================================================
-- ShardSystem.lua
-- Families, fragment tallies, and charge state.
-- Minimal core with safe integrations.
--==================================================

if not ShardSystem then ShardSystem = {} end
_G.ShardSystem = ShardSystem

do
    --------------------------------------------------
    -- Config / Aliases
    --------------------------------------------------
    local GB = GameBalance or {}

    -- Optional: how many fragments needed for a charge if not defined elsewhere
    local DEFAULT_FRAGMENTS_TO_CHARGE = 10

    --------------------------------------------------
    -- Per-player state
    --------------------------------------------------
    -- P[pid] = {
    --   fragments = { [familyKey] = count },
    --   charged   = { [itemTypeId] = true },
    -- }
    local P = {}

    local function PD(pid)
        P[pid] = P[pid] or { fragments = {}, charged = {} }
        return P[pid]
    end

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardSystem] " .. tostring(s)) end
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function idOfRaw(raw)
        if not raw or raw == "" then return 0 end
        return FourCC(raw)
    end

    local function validItem(i) return i ~= nil end

    local function clamp(n, lo, hi)
        if n < lo then return lo end
        if n > hi then return hi end
        return n
    end

    --------------------------------------------------
    -- Family resolution
    --------------------------------------------------
    local function FamilyKeyForItem(itemTypeId)
        -- Preferred: GameBalance helper
        if GB and GB.FamilyKeyForItem then
            local ok, fk = pcall(GB.FamilyKeyForItem, itemTypeId)
            if ok and fk then return fk end
        end
        -- Fallback: ShardFamilySystem (if provided)
        if _G.ShardFamilySystem and ShardFamilySystem.GetFamilyKeyByItem then
            local ok, fk = pcall(ShardFamilySystem.GetFamilyKeyByItem, itemTypeId)
            if ok and fk then return fk end
        end
        return nil
    end

    local function FragmentsRequiredForFamily(fk)
        if _G.ShardFamilySystem and ShardFamilySystem.GetFragmentsToCharge then
            local ok, need = pcall(ShardFamilySystem.GetFragmentsToCharge, fk)
            if ok and type(need) == "number" and need > 0 then
                return need
            end
        end
        return DEFAULT_FRAGMENTS_TO_CHARGE
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    -- Returns true if this item handle looks like a shard (family-resolvable)
    function ShardSystem.IsShardItemHandle(item)
        if not validItem(item) then return false end
        local it = GetItemTypeId(item)
        if it == 0 then return false end
        local fk = FamilyKeyForItem(it)
        return fk ~= nil
    end

    function ShardSystem.GetFamilyKeyByItem(itemTypeId)
        return FamilyKeyForItem(itemTypeId)
    end

    function ShardSystem.GetFamilyKeyByRaw(raw)
        return FamilyKeyForItem(idOfRaw(raw))
    end

    -- Fragments
    function ShardSystem.AddFragments(pid, familyKey, amount)
        if not familyKey or familyKey == "" then return 0 end
        local pd = PD(pid)
        local cur = pd.fragments[familyKey] or 0
        local nv = clamp(cur + math.floor(amount or 0), 0, 999999)
        pd.fragments[familyKey] = nv
        emit("OnShardFragmentsChanged", { pid = pid, family = familyKey, value = nv })
        return nv
    end

    function ShardSystem.GetFragments(pid, familyKey)
        local pd = PD(pid)
        return pd.fragments[familyKey] or 0
    end

    -- Charge state
    function ShardSystem.IsCharged(pid, familyKeyOrItemId)
        local pd = PD(pid)
        if type(familyKeyOrItemId) == "number" then
            return pd.charged[familyKeyOrItemId] == true
        end
        -- If given family key, check any charged item belonging to that family
        if _G.ItemDatabase and ItemDatabase.ItemsForFamily then
            local ok, list = pcall(ItemDatabase.ItemsForFamily, familyKeyOrItemId)
            if ok and type(list) == "table" then
                for i = 1, #list do
                    if pd.charged[list[i]] then return true end
                end
            end
        end
        return false
    end

    -- Attempt to charge a shard item type using the player's fragments.
    -- Returns true if charged now (or already charged).
    function ShardSystem.TryCharge(pid, itemTypeId)
        local pd = PD(pid)
        if pd.charged[itemTypeId] then return true end

        local fk = FamilyKeyForItem(itemTypeId)
        if not fk then return false end

        local need = FragmentsRequiredForFamily(fk)
        local have = ShardSystem.GetFragments(pid, fk)
        if have < need then return false end

        pd.fragments[fk] = have - need
        pd.charged[itemTypeId] = true

        emit("OnShardFragmentsChanged", { pid = pid, family = fk, value = pd.fragments[fk] })
        emit("OnShardCharged", { pid = pid, itemTypeId = itemTypeId, family = fk })

        -- Optional: let ShardChargeSystem mirror any extra effects
        if _G.ShardChargeSystem and ShardChargeSystem.OnCharged then
            pcall(ShardChargeSystem.OnCharged, pid, itemTypeId, fk)
        end
        return true
    end

    --------------------------------------------------
    -- Wiring: typical pickup bridge
    --------------------------------------------------
    -- If you are using ShardPickupBridge to funnel item events, it can call:
    --   ShardSystem.OnShardFragmentPickup(pid, itemHandle)
    --   ShardSystem.OnShardCorePickup(pid, itemHandle)
    -- These are safe no-ops when families cannot be resolved.

    function ShardSystem.OnShardFragmentPickup(pid, item)
        if not validItem(item) then return end
        if _G.ShardIgnoreForce and ShardIgnoreForce.IsActive and ShardIgnoreForce.IsActive(pid) then
            return
        end
        local it = GetItemTypeId(item)
        local fk = FamilyKeyForItem(it)
        if not fk then return end

        local add = 1
        if _G.ShardFragments and ShardFragments.ValueForItem then
            local ok, v = pcall(ShardFragments.ValueForItem, it)
            if ok and type(v) == "number" and v > 0 then add = v end
        end

        ShardSystem.AddFragments(pid, fk, add)
        RemoveItem(item)
        dprint("fragment added to " .. tostring(fk))
    end

    function ShardSystem.OnShardCorePickup(pid, item)
        if not validItem(item) then return end
        if _G.ShardIgnoreForce and ShardIgnoreForce.IsActive and ShardIgnoreForce.IsActive(pid) then
            return
        end
        local it = GetItemTypeId(item)
        local charged = ShardSystem.TryCharge(pid, it)
        if charged then
            RemoveItem(item)
            dprint("shard charged for item " .. tostring(it))
        end
    end

    --------------------------------------------------
    -- Init banner
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            for pid = 0, bj_MAX_PLAYERS - 1 do
                PD(pid)
            end
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("ShardSystem")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
