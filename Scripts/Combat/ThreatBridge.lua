if Debug and Debug.beginFile then Debug.beginFile("ThreatBridge.lua") end
--==================================================
-- ThreatBridge.lua
-- Wires combat events (via ProcBus) into AggroManager.
-- • Ignores "bag" or invalid units safely (no global Bag touch).
--==================================================

if not ThreatBridge then ThreatBridge = {} end
_G.ThreatBridge = ThreatBridge

do
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function isStructure(u) return IsUnitType(u, UNIT_TYPE_STRUCTURE) end

    -- conservative bag ignore: rely on a feature flag if present, otherwise
    -- skip units with Locust or structures.
    local ALOC = FourCC and FourCC('Aloc') or nil
    local function isBagUnit(u)
        if not valid(u) then return true end
        if ALOC and UnitHasBuffBJ and UnitHasBuffBJ(u, ALOC) then return true end
        if isStructure(u) then return true end
        if _G.BagSystem and type(BagSystem.IsBag)=="function" then
            local ok, res = pcall(BagSystem.IsBag, u)
            if ok and res then return true end
        end
        return false
    end

    local function addDamage(pid, target, amount)
        if not _G.AggroManager then return end
        if valid(target) and not isBagUnit(target) then
            AggroManager.AddDamage(target, pid, amount or 0)
        end
    end
    local function addHeal(pid, target, amount)
        if not _G.AggroManager then return end
        if valid(target) and not isBagUnit(target) then
            AggroManager.AddHeal(target, pid, amount or 0)
        end
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then
            print("[ThreatBridge] ProcBus missing; no wiring")
            return
        end

        PB.On("OnDealtDamage", function(e)
            if not e then return end
            local pid = e.pid
            local tgt = e.target
            local amt = tonumber(e.amount or 0) or 0
            if pid ~= nil and amt > 0 then addDamage(pid, tgt, amt) end
        end)

        PB.On("OnHealed", function(e)
            if not e then return end
            local pid = e.pid
            local tgt = e.target
            local amt = tonumber(e.amount or 0) or 0
            if pid ~= nil and amt > 0 then addHeal(pid, tgt, amt) end
        end)

        if rawget(_G,"InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatBridge")
        end
        print("[ThreatBridge] ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
