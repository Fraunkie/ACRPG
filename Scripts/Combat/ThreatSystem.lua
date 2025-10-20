if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem.lua") end
--==================================================
-- ThreatSystem.lua
-- Unit-target threat tracking keyed by player pids.
-- • AddThreat(source, target, amount)
-- • GetThreat(source, target) -> number
-- • GetLeader(target) -> handle id of top hero (for AI)
-- • GetList(target) -> { {pid=0, value=123}, ... } sorted
-- • OnCreepSpawn(u, isElite, packId) / OnCreepDeath(u)
-- • OnTargetDeath(target, killer) / ClearUnit(target) / Register(u)
-- Notes:
--  - Ignores Bag units
--  - Emits ProcBus "ThreatChanged" with { target = unit }
--==================================================

if not ThreatSystem then ThreatSystem = {} end
_G.ThreatSystem = ThreatSystem

do
    local CU = _G.CoreUtils or {}

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- threat[handleId(target)] = { [pid] = value }
    local threat = {}
    -- lastAttacker[handleId(target)] = pid
    local lastAttacker = {}

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function valid(u) return CU.ValidUnit and CU.ValidUnit(u) or (u and GetUnitTypeId(u) ~= 0) end
    local function isBag(u) return CU.IsBag and CU.IsBag(u) end
    local function hid(u) return GetHandleId(u) end

    local function ensure(target)
        local h = hid(target)
        if not threat[h] then threat[h] = {} end
        return threat[h]
    end

    local function emitChanged(target)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit("ThreatChanged", { target = target })
        end
    end

    local function pidOf(u)
        if not u then return nil end
        local p = GetOwningPlayer(u)
        return p and GetPlayerId(p) or nil
    end

    --------------------------------------------------
    -- API
    --------------------------------------------------
    function ThreatSystem.AddThreat(source, target, amount)
        if not valid(source) or not valid(target) then return end
        if isBag(source) or isBag(target) then return end
        local pid = pidOf(source); if pid == nil then return end
        local amt = tonumber(amount or 0) or 0
        if amt == 0 then return end
        local tab = ensure(target)
        tab[pid] = math.max(0, (tab[pid] or 0) + amt)
        lastAttacker[hid(target)] = pid
        emitChanged(target)
    end

    -- Back compat
    function ThreatSystem.OnDamage(source, target, amount)
        ThreatSystem.AddThreat(source, target, amount)
    end

    function ThreatSystem.GetThreat(source, target)
        if not valid(source) or not valid(target) then return 0 end
        local pid = pidOf(source); if pid == nil then return 0 end
        local tab = threat[hid(target)]; if not tab then return 0 end
        return tab[pid] or 0
    end

    -- Sorted list for HUDs
    function ThreatSystem.GetList(target)
        if not valid(target) then return {} end
        local tab = threat[hid(target)]; if not tab then return {} end
        local out, i = {}, 1
        for pid, val in pairs(tab) do
            if val and val > 0 then
                out[i] = { pid = pid, value = val }
                i = i + 1
            end
        end
        table.sort(out, function(a, b) return a.value > b.value end)
        return out
    end

    -- For AI: return handle id of current top hero if any
    function ThreatSystem.GetLeader(target)
        if not valid(target) then return nil end
        local list = ThreatSystem.GetList(target)
        if #list == 0 then return nil end
        local topPid = list[1].pid
        if _G.PlayerData and PlayerData.Get then
            local pd = PlayerData.Get(topPid)
            if pd and pd.hero and valid(pd.hero) then
                return GetHandleId(pd.hero)
            end
        end
        -- fallback: return nil if hero not known
        return nil
    end

    function ThreatSystem.GetLastAttackerPid(target)
        if not valid(target) then return nil end
        return lastAttacker[hid(target)]
    end

    function ThreatSystem.ClearUnit(target)
        if not valid(target) then return end
        local h = hid(target)
        threat[h] = nil
        lastAttacker[h] = nil
        emitChanged(target)
    end

    -- Called when a creep spawns so HUDs can start tracking
    function ThreatSystem.Register(u)
        if not valid(u) then return end
        ensure(u)
    end

    function ThreatSystem.OnCreepSpawn(u, isElite, packId)
        ThreatSystem.Register(u)
    end

    function ThreatSystem.OnCreepDeath(u)
        ThreatSystem.ClearUnit(u)
    end

    -- Called when the target dies
    function ThreatSystem.OnTargetDeath(target, killer)
        ThreatSystem.ClearUnit(target)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
