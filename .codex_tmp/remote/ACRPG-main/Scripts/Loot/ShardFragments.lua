if Debug and Debug.beginFile then Debug.beginFile("ShardFragments.lua") end
--==================================================
-- ShardFragments.lua
-- Defines fragment values for fragment items.
--==================================================

if not ShardFragments then ShardFragments = {} end
_G.ShardFragments = ShardFragments

do
    --------------------------------------------------
    -- Table of itemTypeId → fragment value
    --------------------------------------------------
    local FRAG_VALUE = {
        -- [FourCC("IFEA")] = 1,  -- small shard fragment
        -- [FourCC("IFEB")] = 3,  -- medium shard fragment
        -- [FourCC("IFEC")] = 5,  -- large shard fragment
    }

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[ShardFrags] " .. tostring(s)) end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function ShardFragments.ValueForItem(itemTypeId)
        local v = FRAG_VALUE[itemTypeId]
        if type(v) == "number" and v > 0 then return v end
        return 1
    end

    function ShardFragments.SetValue(itemTypeId, value)
        if not itemTypeId or not value then return end
        FRAG_VALUE[itemTypeId] = math.max(1, math.floor(value))
        dprint("set frag value for " .. tostring(itemTypeId) .. " to " .. tostring(FRAG_VALUE[itemTypeId]))
    end

    --------------------------------------------------
    -- Init banner
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            if rawget(_G, "InitBroker") and InitBroker.SystemReady then
                InitBroker.SystemReady("ShardFragments")
            end
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
