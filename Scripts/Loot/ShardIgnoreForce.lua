if Debug and Debug.beginFile then Debug.beginFile("ShardIgnoreForce.lua") end
--==================================================
-- ShardIgnorePatch.lua
-- Wraps common shard pickup hooks to ignore teleport tomes
-- Works even if the original shard script wasn't edited
--==================================================

do
    --------------------------------------------------
    -- Ensure ShardIgnore exists and seed IDs
    --------------------------------------------------
    if not _G.ShardIgnore then
        ShardIgnore = {}
        _G.ShardIgnore = ShardIgnore

        local IGN = {}
        local function toId(x)
            if type(x) == "number" then
                return x
            elseif type(x) == "string" and #x == 4 then
                return FourCC(x)
            end
            return nil
        end

        function ShardIgnore.IsIgnoredItem(it)
            if not it or GetItemTypeId(it) == 0 then return false end
            return IGN[GetItemTypeId(it)] == true
        end

        local seeds = { "I006", "I00B", "I017" } -- your teleport tomes
        for _, s in ipairs(seeds) do
            local id = toId(s)
            if id then IGN[id] = true end
        end
    end

    local function ignored()
        return ShardIgnore and ShardIgnore.IsIgnoredItem and ShardIgnore.IsIgnoredItem(GetManipulatedItem())
    end

    --------------------------------------------------
    -- Patch: ShardFragments.OnPickup
    --------------------------------------------------
    OnInit.final(function()
        if _G.ShardFragments and type(ShardFragments.OnPickup) == "function" and not ShardFragments.__ignorePatched then
            local orig = ShardFragments.OnPickup
            ShardFragments.OnPickup = function(...)
                if ignored() then return end
                return orig(...)
            end
            ShardFragments.__ignorePatched = true
        end
    end)

    --------------------------------------------------
    -- Patch: Shard.OnItemAcquired
    --------------------------------------------------
    OnInit.final(function()
        if _G.Shard and type(Shard.OnItemAcquired) == "function" and not Shard.__ignorePatched then
            local orig = Shard.OnItemAcquired
            Shard.OnItemAcquired = function(...)
                if ignored() then return end
                return orig(...)
            end
            Shard.__ignorePatched = true
        end
    end)

    --------------------------------------------------
    -- Patch: ShardPickupBridge.OnPickup
    --------------------------------------------------
    OnInit.final(function()
        if _G.ShardPickupBridge and type(ShardPickupBridge.OnPickup) == "function" and not ShardPickupBridge.__ignorePatched then
            local orig = ShardPickupBridge.OnPickup
            ShardPickupBridge.OnPickup = function(...)
                if ignored() then return end
                return orig(...)
            end
            ShardPickupBridge.__ignorePatched = true
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
