if Debug and Debug.beginFile then Debug.beginFile("ThreatHUD_Data.lua") end
--==================================================
-- ThreatHUD_Data.lua
-- Rolling DPS per player + threat snapshot helpers
-- • Listens to ProcBus.OnDealtDamage (Subscribe fallback)
-- • Queries AggroManager / ThreatSystem when present
-- • Ignores non-human player PIDs for DPS
--==================================================

if not ThreatHUD_Data then ThreatHUD_Data = {} end
_G.ThreatHUD_Data = ThreatHUD_Data

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local WINDOW_SEC   = 10.0     -- DPS window length
    local TICK_SEC     = 0.25     -- cleanup cadence

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- dpsBuf[pid] = { {t, n}, {t, n}, ... } recent hits
    local dpsBuf = {}

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    local function isHumanPid(pid)
        if pid == nil then return false end
        if pid < 0 or pid >= bj_MAX_PLAYERS then return false end
        return GetPlayerController(Player(pid)) == MAP_CONTROL_USER
    end

    local function buf(pid)
        local t = dpsBuf[pid]
        if not t then t = {}; dpsBuf[pid] = t end
        return t
    end

    local function prune(pid, tnow)
        local b = buf(pid)
        local i = 1
        while i <= #b do
            if (tnow - (b[i][1] or 0)) > WINDOW_SEC then
                table.remove(b, i)
            else
                i = i + 1
            end
        end
    end

    --------------------------------------------------
    -- Public: add damage sample (pid = source player id)
    --------------------------------------------------
    function ThreatHUD_Data.AddDamage(pid, amount)
        if not isHumanPid(pid) then return end  -- ignore creeps/neutral
        local n = tonumber(amount or 0) or 0
        if n <= 0 then return end
        local tnow = now()
        local b = buf(pid)
        b[#b+1] = { tnow, n }
        prune(pid, tnow)
    end

    --------------------------------------------------
    -- Public: current DPS for pid
    --------------------------------------------------
    function ThreatHUD_Data.GetDPS(pid)
        if not isHumanPid(pid) then return 0 end
        local tnow = now()
        prune(pid, tnow)
        local b = buf(pid)
        if #b == 0 then return 0 end
        local sum = 0
        for i = 1, #b do sum = sum + (b[i][2] or 0) end
        local span = math.max(0.25, math.min(WINDOW_SEC, tnow - (b[1][1] or tnow)))
        return sum / span
    end

    --------------------------------------------------
    -- Public: top threat list for a target (pid,value pairs)
    -- Prefers AggroManager; falls back to ThreatSystem if it exposes a getter.
    --------------------------------------------------
    function ThreatHUD_Data.TopThreatForTarget(target, maxCount)
        local list = {}

        -- Preferred: AggroManager snapshot (expected shape: { {pid=, value=}, ... })
        local AM = rawget(_G, "AggroManager")
        if AM and AM.GetThreatList then
            local tl = AM.GetThreatList(target) or {}
            for i = 1, #tl do
                list[#list+1] = { pid = tl[i].pid, value = tl[i].value }
            end
        else
            -- Fallback: ThreatSystem public getter if present
            local TS = rawget(_G, "ThreatSystem")
            if TS and TS.GetThreatList then
                local tl = TS.GetThreatList(target) or {}
                for i = 1, #tl do
                    list[#list+1] = { pid = tl[i].pid, value = tl[i].value }
                end
            end
            -- (Intentionally avoiding private tables / handle lookups to keep it safe)
        end

        table.sort(list, function(a,b) return (a.value or 0) > (b.value or 0) end)
        local cap = math.min(#list, maxCount or #list)
        local out = {}
        for i = 1, cap do out[i] = list[i] end
        return out
    end

    --------------------------------------------------
    -- Wiring: ProcBus damage → DPS buffer
    --------------------------------------------------
    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        local handler = function(e)
            if not e then return end
            local pid = e.pid
            local amt = tonumber(e.amount or 0) or 0
            if amt > 0 then ThreatHUD_Data.AddDamage(pid, amt) end
        end
        if PB and PB.Subscribe then
            PB.Subscribe("OnDealtDamage", handler)
        elseif PB and PB.On then
            PB.On("OnDealtDamage", handler)
        end
    end

    --------------------------------------------------
    -- Init (total initialization style)
    --------------------------------------------------
    OnInit.final(function()
        wireBus()
        -- periodic prune in case no damage arrives
        local t = CreateTimer()
        TimerStart(t, TICK_SEC, true, function()
            local tnow = now()
            for pid,_ in pairs(dpsBuf) do prune(pid, tnow) end
        end)
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUD_Data")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
