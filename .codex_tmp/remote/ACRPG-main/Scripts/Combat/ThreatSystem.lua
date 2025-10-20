if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem.lua") end
--==================================================
-- ThreatSystem.lua  (proxy + nil-safe ignores)
-- • Nil-safe Bag detection (no hard dependency)
-- • Thin wrapper that forwards threat to AggroManager
-- • Wires to ProcBus: OnDealtDamage, OnKill
--==================================================

if not ThreatSystem then ThreatSystem = {} end
_G.ThreatSystem = ThreatSystem

do
    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM and type(DM.IsOn) == "function" then return DM.IsOn() end
        if DM and type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        return false
    end
    local function dprint(s) if DEV_ON() then print("[ThreatSystem] " .. tostring(s)) end end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function pidOf(u) local p = u and GetOwningPlayer(u) return p and GetPlayerId(p) end

    -- Nil-safe "Bag" ignore and a couple of fallbacks
    local function isIgnored(u)
        if not validUnit(u) then return true end

        -- 1) Optional Bag system (guarded)
        do
            local B = rawget(_G, "Bag")
            if B then
                if type(B.IsBagUnit) == "function" then
                    local ok, res = pcall(B.IsBagUnit, u)
                    if ok and res then return true end
                elseif type(B.IsBag) == "function" then
                    local ok, res = pcall(B.IsBag, u)
                    if ok and res then return true end
                end
            end
        end

        -- 2) Optional hard filter via GameBalance.THREAT_IGNORE_TYPES
        do
            local GB = rawget(_G, "GameBalance")
            local ignore = GB and GB.THREAT_IGNORE_TYPES
            if ignore then
                local ut = GetUnitTypeId(u)
                if ignore[ut] then return true end
            end
        end

        -- 3) Best-effort name sniff (plain, case-insensitive)
        do
            local nm = GetUnitName(u)
            if nm then
                local s = string.lower(nm)
                if string.find(s, "bag", 1, true) then
                    return true
                end
            end
        end

        return false
    end

    --------------------------------------------------
    -- Public API (forward to AggroManager)
    --------------------------------------------------
    function ThreatSystem.AddThreat(source, target, amount)
        if not validUnit(source) or not validUnit(target) then return end
        if isIgnored(source) or isIgnored(target) then return end
        local pid = pidOf(source)
        if pid == nil then return end
        local amt = tonumber(amount or 0) or 0
        if amt <= 0 then return end

        if _G.AggroManager and AggroManager.AddThreat then
            AggroManager.AddThreat(target, pid, amt)
        end
    end

    function ThreatSystem.ClearTarget(target)
        if not validUnit(target) then return end
        if _G.AggroManager and AggroManager.ClearTarget then
            AggroManager.ClearTarget(target)
        end
    end

    -- Optional: expose top threat query (proxy)
    function ThreatSystem.GetTop(target)
        if _G.AggroManager and AggroManager.GetTop then
            return AggroManager.GetTop(target)
        end
        return nil
    end

    --------------------------------------------------
    -- ProcBus wiring
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if not PB or type(PB.On) ~= "function" then
            dprint("ProcBus not found; threat will not auto-update")
            return
        end

        PB.On("OnDealtDamage", function(e)
            -- e.pid (attacker pid), e.source (unit), e.target (unit), e.amount (number)
            local src  = e and e.source
            local tgt  = e and e.target
            local amt  = e and e.amount or 0
            if not validUnit(src) or not validUnit(tgt) then return end
            if isIgnored(src) or isIgnored(tgt) then return end
            if amt <= 0 then return end
            ThreatSystem.AddThreat(src, tgt, amt)
        end)

        PB.On("OnKill", function(e)
            local tgt = e and e.target
            if validUnit(tgt) then
                ThreatSystem.ClearTarget(tgt)
            end
        end)

        dprint("wired to ProcBus")
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
