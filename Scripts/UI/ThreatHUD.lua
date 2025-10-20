if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD.lua") end
--==================================================
-- ThreatHUD.lua (robust controller)
-- Finds threat list from multiple systems; merges DPS.
-- Falls back to DPS-only when threat data is absent.
-- Prints dev snapshot (Target, Name, DPS, Threat) when DevMode is ON.
--==================================================

if not ThreatHUD then ThreatHUD = {} end
_G.ThreatHUD = ThreatHUD

do
    local ui, visible = {}, {}

    -- remember most recent damaged unit per player (for primary target)
    local recentTarget, TARGET_TTL = {}, 8.0

    local function now() if os and os.clock then return os.clock() end return 0 end
    local function valid(u) return u and GetUnitTypeId(u) ~= 0 end
    local function DEV_ON()
        local D = rawget(_G, "DevMode")
        if D then
            if type(D.IsOn) == "function" then local ok,v=pcall(D.IsOn); if ok and v then return true end end
            if type(D.IsEnabled) == "function" then local ok,v=pcall(D.IsEnabled); if ok and v then return true end end
        end
        return false
    end
    local function builder() return rawget(_G, "ThreatHUDBuild") end

    -- wire damage so we always have a target
    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", function(e)
                if not e or e.pid == nil or not valid(e.target) then return end
                recentTarget[e.pid] = { unit = e.target, t = now() }
            end)
            PB.On("OnKill", function(e)
                if not e or not e.target then return end
                for pid, r in pairs(recentTarget) do
                    if r and r.unit and GetHandleId(r.unit) == GetHandleId(e.target) then
                        recentTarget[pid] = nil
                    end
                end
            end)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUD")
        end
    end)

    -- ---- ThreatSystem probes ----
    local function ts_call(name, ...)  -- safe pcall to TS.fn(...)
        local TS = rawget(_G, "ThreatSystem"); if not TS then return nil end
        local f = TS[name]; if type(f) ~= "function" then return nil end
        local ok, res = pcall(f, ...); if not ok then return nil end
        return res
    end
    local function normalize(list)
        if not list then return {} end
        if type(list) == "table" and #list > 0 and type(list[1]) == "table" and list[1].pid ~= nil then
            return list
        end
        local out = {}
        if type(list) == "table" and #list > 0 and type(list[1]) == "number" then
            for i=1,#list do out[#out+1] = { pid = list[i], value = 0 } end
            return out
        end
        if type(list) == "table" then
            for pid, val in pairs(list) do
                if type(pid) == "number" then out[#out+1] = { pid = pid, value = tonumber(val) or 0 } end
            end
        end
        return out
    end

    local function threatListForTarget(target)
        if not valid(target) then return {} end

        -- AggroManager (preferred)
        if rawget(_G,"AggroManager") and AggroManager.GetThreatList then
            local ok, l = pcall(AggroManager.GetThreatList, target)
            if ok and type(l) == "table" and #l > 0 then return l end
        end

        -- ThreatSystem: try multiple likely names
        local names = {
            "GetThreatList","GetThreatGroup","GetGroupForTarget","GetPlayersForTarget",
            "ListPlayersForTarget","GetPlayers"
        }
        for i=1,#names do
            local raw = ts_call(names[i], target)
            if raw then
                local l = normalize(raw)
                if #l > 0 then return l end
            end
        end

        return {}
    end

    local function primaryTargetFor(pid)
        if rawget(_G, "AggroManager") then
            if AggroManager.GetPlayerPrimaryTarget then
                local t = AggroManager.GetPlayerPrimaryTarget(pid); if valid(t) then return t end
            end
            if AggroManager.GetAnyTargetForPid then
                local t = AggroManager.GetAnyTargetForPid(pid); if valid(t) then return t end
            end
        end
        local r = recentTarget[pid]
        if r and valid(r.unit) and (now() - (r.t or 0)) <= TARGET_TTL then return r.unit end
        return nil
    end

    -- merge threat + DPS; if threat empty, build from DPS snapshot only
    local function buildEntries(target)
        local threat = threatListForTarget(target)
        local snap = (rawget(_G,"ThreatHUDData") and ThreatHUDData.GetSnapshot) and ThreatHUDData.GetSnapshot(target) or {}

        local byPid = {}
        for i=1,#threat do
            local e = threat[i]
            local pid = e.pid
            byPid[pid] = { pid = pid, threat = tonumber(e.value or 0) or 0, dps = 0 }
        end
        -- add DPS; create entries if threat list was empty
        for pid, row in pairs(snap) do
            local n = byPid[pid] or { pid = pid, threat = 0, dps = 0 }
            n.dps = tonumber(row.dps or 0) or 0
            byPid[pid] = n
        end

        local out = {}
        for pid, n in pairs(byPid) do
            local name = "P" .. tostring(pid)
            local ok, nm = pcall(function() return GetPlayerName(Player(pid)) end)
            if ok and nm and nm ~= "" then name = nm end
            out[#out+1] = { pid = pid, name = name, dps = n.dps or 0, threat = n.threat or 0 }
        end

        table.sort(out, function(a,b)
            local ta, tb = a.threat or 0, b.threat or 0
            if ta ~= tb then return ta > tb end
            return (a.dps or 0) > (b.dps or 0)
        end)
        return out
    end

    -- dev print
    local function round2(x) local n=tonumber(x or 0) or 0; return math.floor(n*100+0.5)/100 end
    local function devPrint(pid, target, list)
        if not DEV_ON() then return end
        if GetLocalPlayer() ~= Player(pid) then return end
        local lines = {}
        local tname = valid(target) and GetUnitName(target) or "No Target"
        lines[#lines+1] = "[Threat] Target: " .. tname
        if not list or #list == 0 then
            lines[#lines+1] = "none"
        else
            for i=1,#list do
                local e=list[i]
                lines[#lines+1] = e.name .. "  DPS: " .. tostring(round2(e.dps or 0)) ..
                                  "  Threat: " .. tostring(math.floor(e.threat or 0))
            end
        end
        DisplayTextToPlayer(Player(pid),0,0,table.concat(lines,"|n"))
    end

    -- public API
    function ThreatHUD.IsReady(pid) return ui[pid] ~= nil end

    function ThreatHUD.Create(pid)
        if ui[pid] ~= nil then return ui[pid] end
        local b = builder()
        if b and b.Create then
            local ok,h=pcall(b.Create,pid); if ok then ui[pid]=h or true else ui[pid]=true end
        else ui[pid]=true end
        visible[pid]=false
        return ui[pid]
    end

    function ThreatHUD.Ensure(pid) if not ThreatHUD.IsReady(pid) then ThreatHUD.Create(pid) end return true end

    function ThreatHUD.Update(pid, target)
        ThreatHUD.Ensure(pid)
        local list = buildEntries(target)
        local tgtName = valid(target) and GetUnitName(target) or ""
        local b = builder()
        if b and b.Update then pcall(b.Update, pid, list, tgtName) end
        devPrint(pid, target, list)
    end

    local function setVisible(pid, on)
        visible[pid] = on and true or false
        local b = builder()
        if b and b.SetVisible then pcall(b.SetVisible, pid, visible[pid]) end
    end

    function ThreatHUD.Show(pid, target) ThreatHUD.Ensure(pid); ThreatHUD.Update(pid, target); setVisible(pid, true) end
    function ThreatHUD.Hide(pid) if not ThreatHUD.IsReady(pid) then return end setVisible(pid,false) end
    function ThreatHUD.Toggle(pid) ThreatHUD.Ensure(pid); if visible[pid] then ThreatHUD.Hide(pid) else ThreatHUD.ShowPrimary(pid) end end
    function ThreatHUD.ShowPrimary(pid) ThreatHUD.Ensure(pid); local t=primaryTargetFor(pid); ThreatHUD.Show(pid,t) end

    -- refresh when data changes
    local function refresh()
        for pid=0,bj_MAX_PLAYERS-1 do if visible[pid] then ThreatHUD.ShowPrimary(pid) end end
    end
    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("AggroChanged", refresh); PB.On("ThreatChanged", refresh); PB.On("OnDealtDamage", refresh)
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
