if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem.lua") end
--==================================================
-- ThreatSystem.lua
-- Minimal, safe threat tracker used by HUD and SD.
--  • Stores threat per target unit
--  • Accepts source as unit OR pid
--  • Nil / invalid unit guarded everywhere
--  • Compatible with readers:
--      _raw[targetHandle].byPid, bySrcHandle, sum
--  • Optional helpers: Register, ClearUnit, Dump
--  • Spawn/Death shims: OnCreepSpawn / OnCreepDeath
--==================================================

if not ThreatSystem then ThreatSystem = {} end
_G.ThreatSystem = ThreatSystem

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u ~= nil and GetUnitTypeId(u) ~= 0 end

    local function pidOf(src)
        if type(src) == "number" then return src end
        if ValidUnit(src) then
            local p = GetOwningPlayer(src)
            if p then return GetPlayerId(p) end
        end
        return nil
    end

    local function cellFor(target)
        ThreatSystem._raw = ThreatSystem._raw or {}
        local hid = GetHandleId(target)
        local c = ThreatSystem._raw[hid]
        if not c then
            c = { byPid = {}, bySrcHandle = {}, sum = 0 }
            ThreatSystem._raw[hid] = c
        end
        return c
    end

    local function dprint(s)
        if rawget(_G, "DevMode") and DevMode.IsOn and DevMode.IsOn(0) then
            print("[ThreatSystem] " .. tostring(s))
        end
    end

    --------------------------------------------------
    -- API
    --------------------------------------------------

    -- Optional: mark a target as tracked
    function ThreatSystem.Register(target)
        if not ValidUnit(target) then return end
        cellFor(target)
    end

    -- Optional: clear all threat for a target
    function ThreatSystem.ClearUnit(target)
        if not ValidUnit(target) then return end
        if not ThreatSystem._raw then return end
        ThreatSystem._raw[GetHandleId(target)] = nil
    end

    -- Main entry: add threat from source to target
    -- source: unit or pid
    function ThreatSystem.AddThreat(source, target, amount)
        if not ValidUnit(target) then return end
        local pid = pidOf(source); if pid == nil then return end
        local n = tonumber(amount or 0) or 0
        if n == 0 then return end

        local c = cellFor(target)
        c.byPid[pid] = (c.byPid[pid] or 0) + n
        c.sum = (c.sum or 0) + n

        if ValidUnit(source) then
            local sh = GetHandleId(source)
            c.bySrcHandle[sh] = (c.bySrcHandle[sh] or 0) + n
        end
    end

    -- Compatibility shim used by some old code
    function ThreatSystem.OnDamage(source, target, amount)
        ThreatSystem.AddThreat(source, target, amount)
    end

    -- Optional signal from spawn systems
    function ThreatSystem.OnCreepSpawn(u, isElite, packId)
        if ValidUnit(u) then ThreatSystem.Register(u) end
    end

    -- Optional signal from death systems
    function ThreatSystem.OnCreepDeath(u)
        if ValidUnit(u) then ThreatSystem.ClearUnit(u) end
    end

    -- Utility used by ThreatBridge or checks
    function ThreatSystem.IsTracked(u)
        if not ValidUnit(u) then return false end
        local raw = ThreatSystem._raw
        return raw ~= nil and raw[GetHandleId(u)] ~= nil
    end

    -- Debug helper
    function ThreatSystem.Dump()
        dprint("Dump start")
        local raw = ThreatSystem._raw or {}
        for hid, c in pairs(raw) do
            dprint(" target " .. tostring(hid) .. " sum " .. tostring(c.sum or 0))
        end
        dprint("Dump end")
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
