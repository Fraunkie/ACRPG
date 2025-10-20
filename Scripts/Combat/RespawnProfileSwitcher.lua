if Debug and Debug.beginFile then Debug.beginFile("BagIgnore.lua") end
--==================================================
-- BagIgnore.lua
-- Tiny helper so other systems can skip the Bag unit.
-- • Central place to decide "is this the bag?"
-- • Editor-safe (no natives at top level)
--==================================================

if not BagIgnore then BagIgnore = {} end
_G.BagIgnore = BagIgnore

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    -- Option A: by rawcode (recommended if your Bag is a distinct unit type)
    --   Put your bag unit rawcode here once you know it. Example: "oBag".
    local BAG_RAWCODE = nil  -- e.g., "oBag"

    -- Option B: by unit name (fallback if type is reused)
    local BAG_NAME = "Player Bag"  -- set to your bag’s in-game name, or leave as impossible name

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function isLive(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    -- Returns true if the given unit is the Bag and should be ignored by combat/threat systems.
    function BagIgnore.IsBag(u)
        if not isLive(u) then return false end

        -- Match by rawcode when configured
        if BAG_RAWCODE and type(BAG_RAWCODE) == "string" and #BAG_RAWCODE == 4 and type(FourCC) == "function" then
            local ok, id = pcall(FourCC, BAG_RAWCODE)
            if ok and id and GetUnitTypeId(u) == id then
                return true
            end
        end

        -- Fallback: match by unit name (case sensitive)
        local n = GetUnitName(u)
        if n and BAG_NAME ~= "" and n == BAG_NAME then
            return true
        end

        return false
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- No-op, kept for consistency/logging
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("BagIgnore")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
