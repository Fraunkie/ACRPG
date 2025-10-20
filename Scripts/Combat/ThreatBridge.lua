if Debug and Debug.beginFile then Debug.beginFile("ThreatBridge.lua") end
--==================================================
-- ThreatBridge.lua
-- Connects CombatEventsBridge to ThreatSystem safely.
-- • Listens to OnDealtDamage and OnKill from ProcBus
-- • Ignores bags and invalid units
--==================================================

if not ThreatBridge then ThreatBridge = {} end
_G.ThreatBridge = ThreatBridge

do
    local CU = _G.CoreUtils or {}

    local function valid(u) return CU.ValidUnit and CU.ValidUnit(u) or (u and GetUnitTypeId(u) ~= 0) end
    local function isBag(u) return CU.IsBag and CU.IsBag(u) end

    local function onDamage(e)
        if not e then return end
        local src, tgt, amt = e.source, e.target, e.amount or 0
        if not valid(src) or not valid(tgt) or isBag(src) or isBag(tgt) then return end
        local TS = rawget(_G, "ThreatSystem")
        if TS and TS.AddThreat then
            pcall(TS.AddThreat, src, tgt, amt)
        end
    end

    local function onKill(e)
        if not e then return end
        local src, tgt = e.source, e.target
        if not valid(src) or not valid(tgt) then return end
        local TS = rawget(_G, "ThreatSystem")
        if TS and TS.OnTargetDeath then
            pcall(TS.OnTargetDeath, tgt, src)
        end
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDamage)
            PB.On("OnKill", onKill)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
