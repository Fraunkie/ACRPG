if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem_Sanity.lua") end
--==================================================
-- ThreatSystem_Sanity.lua
-- Safe wrappers and utilities layered on top of ThreatSystem.
-- • No rewrites, only guards and helper functions
-- • Adds group summaries and healing threat adapter
-- • Ignores bag units for any threat math
--==================================================

if not ThreatSystem_Sanity then ThreatSystem_Sanity = {} end
_G.ThreatSystem_Sanity = ThreatSystem_Sanity

do
    local CU = _G.CoreUtils or {}

    local function log(msg) if CU.Log then CU.Log("ThreatSanity", msg) end end
    local function valid(u) return CU.ValidUnit and CU.ValidUnit(u) or (u and GetUnitTypeId(u) ~= 0) end

    -- Optional knob for healing threat multiplier (classic 0.5x)
    local HEAL_THREAT_MULT = 0.50

    -- Return threat value if available, else 0 (bag-safe)
    local function safeGetThreat(source, target)
        if not valid(source) or not valid(target) then return 0 end
        if CU.IsBag and CU.IsBag(source) then return 0 end
        local TS = rawget(_G, "ThreatSystem")
        if TS and type(TS.GetThreat) == "function" then
            local ok, v = pcall(TS.GetThreat, source, target)
            if ok and type(v) == "number" then return v end
        end
        return 0
    end

    -- Add threat safely (bag-safe)
    local function safeAddThreat(source, target, amount)
        if not valid(source) or not valid(target) then return end
        if CU.IsBag and CU.IsBag(source) then return end
        local TS = rawget(_G, "ThreatSystem")
        if TS and type(TS.AddThreat) == "function" then
            local ok, err = pcall(TS.AddThreat, source, target, amount or 0)
            if not ok then log("AddThreat error " .. tostring(err)) end
        end
    end

    -- Public: build ranked list of pids by threat on target
    function ThreatSystem_Sanity.BuildThreatRanking(target)
        local out = {}   -- { { pid=0, threat=123 }, ... }
        if not valid(target) then return out end

        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                local hero = CU.SafeGetHero and CU.SafeGetHero(pid) or nil
                if valid(hero) then
                    local v = safeGetThreat(hero, target)
                    if v > 0 then
                        out[#out + 1] = { pid = pid, threat = v }
                    end
                end
            end
        end

        table.sort(out, function(a, b) return a.threat > b.threat end)
        return out
    end

    -- Public: get the current top threat pid and value (or nil)
    function ThreatSystem_Sanity.GetCurrentTank(target)
        local list = ThreatSystem_Sanity.BuildThreatRanking(target)
        if #list > 0 then
            return list[1].pid, list[1].threat
        end
        return nil, 0
    end

    -- Public: compute group totals and average threat
    function ThreatSystem_Sanity.Summary(target)
        local list = ThreatSystem_Sanity.BuildThreatRanking(target)
        local total = 0
        for i = 1, #list do total = total + (list[i].threat or 0) end
        local avg = (#list > 0) and (total / #list) or 0
        return { entries = list, total = total, average = avg }
    end

    -- Optional heal adapter: map healing into threat
    function ThreatSystem_Sanity.OnHealed(healer, target, healedAmount)
        if not valid(healer) or not valid(target) then return end
        if (healedAmount or 0) <= 0 then return end
        local gain = math.floor((healedAmount or 0) * HEAL_THREAT_MULT + 0.5)
        if gain > 0 then
            safeAddThreat(healer, target, gain)
        end
    end

    -- Dev toast for quick checks
    function ThreatSystem_Sanity.DevToastTop(target)
        if not valid(target) then return end
        local pid, val = ThreatSystem_Sanity.GetCurrentTank(target)
        local who = (pid ~= nil) and ("P" .. tostring(pid)) or "None"
        DisplayTextToPlayer(GetLocalPlayer(), 0, 0, "[Threat] top " .. who .. " value " .. tostring(val))
    end

    -- ProcBus listeners: OPTIONAL heal mapping if your pipeline emits heals
    local function wireHealIfPresent()
        local PB = rawget(_G, "ProcBus")
        if not (PB and PB.On) then return end
        PB.On("OnHealed", function(e)
            if not e then return end
            ThreatSystem_Sanity.OnHealed(e.healer, e.target, e.amount or 0)
        end)
    end

    OnInit.final(function()
        wireHealIfPresent()
        log("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem_Sanity")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
