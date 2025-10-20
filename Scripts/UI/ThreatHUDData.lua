if Debug and Debug.beginFile then Debug.beginFile("ThreatHUDData.lua") end
--==================================================
-- ThreatHUDData.lua
-- Data backend for the on-screen threat HUD.
--   • Tracks rolling DPS per pid → target
--   • Reads live threat from AggroManager when available
--   • Resets cleanly on kill
-- Exposed helpers:
--   ThreatHUDData.GetCurrentTarget(pid) -> unit|nil
--   ThreatHUDData.GetDPS(pid, target)   -> number
--   ThreatHUDData.GetThreat(pid, target)-> integer
--   ThreatHUDData.BuildSnapshot(pid)    -> { targetName, rows = { {pid,name,dps,threat}, ... } }
--==================================================

if not ThreatHUDData then ThreatHUDData = {} end
_G.ThreatHUDData = ThreatHUDData

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local WINDOW_SEC = 3.0         -- rolling DPS window
    local MIN_GAP    = 0.05        -- ignore events tighter than this per pid+target

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- damageLog[targetH][pid] = array of {t, amt}
    local damageLog = {}
    -- lastSeenTarget[pid] = unit
    local lastSeenTarget = {}
    -- event gate: last time recorded per pid+target
    local lastRecord = {}          -- lastRecord[pid][targetH] = time

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function handle(u) return GetHandleId(u) end

    local function nameOfPid(pid)
        local p = Player(pid)
        if p then
            local n = GetPlayerName(p)
            if n and n ~= "" then return n end
        end
        return "Player " .. tostring(pid)
    end

    local function pruneOld(h, pid, tnow)
        local tab = damageLog[h] and damageLog[h][pid]
        if not tab then return end
        local i = 1
        while i <= #tab do
            if (tnow - (tab[i].t or 0)) > WINDOW_SEC then
                table.remove(tab, i)
            else
                i = i + 1
            end
        end
    end

    local function addDamage(pid, target, amt)
        if pid == nil or not ValidUnit(target) then return end
        local tnow = now()
        -- gate to avoid spammy duplicate sub-hits
        lastRecord[pid] = lastRecord[pid] or {}
        local h = handle(target)
        local last = lastRecord[pid][h] or -1000
        if (tnow - last) < MIN_GAP then return end
        lastRecord[pid][h] = tnow

        damageLog[h] = damageLog[h] or {}
        damageLog[h][pid] = damageLog[h][pid] or {}
        local arr = damageLog[h][pid]

        arr[#arr + 1] = { t = tnow, amt = tonumber(amt or 0) or 0 }
        pruneOld(h, pid, tnow)

        lastSeenTarget[pid] = target
    end

    local function clearTarget(u)
        if not ValidUnit(u) then return end
        local h = handle(u)
        damageLog[h] = nil
        -- clean lastSeen for any players pointing to this target
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if lastSeenTarget[pid] and GetHandleId(lastSeenTarget[pid]) == h then
                lastSeenTarget[pid] = nil
            end
            if lastRecord[pid] then lastRecord[pid][h] = nil end
        end
    end

    local function dpsFor(pid, target)
        if pid == nil or not ValidUnit(target) then return 0 end
        local h = handle(target)
        local tnow = now()
        pruneOld(h, pid, tnow)
        local arr = damageLog[h] and damageLog[h][pid]
        if not arr or #arr == 0 then return 0 end
        local sum = 0
        for i = 1, #arr do
            sum = sum + (arr[i].amt or 0)
        end
        -- divide by fixed window for stability
        return sum / WINDOW_SEC
    end

    local function threatFor(pid, target)
        if pid == nil or not ValidUnit(target) then return 0 end
        local AM = rawget(_G, "AggroManager")
        if not AM or not AM.GetThreatList then return 0 end
        local list = AM.GetThreatList(target)
        if not list then return 0 end
        for i = 1, #list do
            local row = list[i]
            if row and row.pid == pid then
                return math.floor((row.value or 0) + 0.5)
            end
        end
        return 0
    end

    local function pickTarget(pid)
        -- Prefer AggroManager’s remembered primary
        local AM = rawget(_G, "AggroManager")
        if AM and AM.GetPlayerPrimaryTarget then
            local u = AM.GetPlayerPrimaryTarget(pid)
            if ValidUnit(u) then return u end
        end
        -- Fallback to any target with highest recent DPS
        local best, bestDps = nil, 0
        for h, byPid in pairs(damageLog) do
            local u = nil
            -- reconstruct unit by scanning lastSeen (safer than havehandle)
            for p = 0, bj_MAX_PLAYERS - 1 do
                if lastSeenTarget[p] and GetHandleId(lastSeenTarget[p]) == h then
                    u = lastSeenTarget[p]; break
                end
            end
            if ValidUnit(u) then
                local d = dpsFor(pid, u)
                if d > bestDps then bestDps, best = d, u
                end
            end
        end
        if best then return best end
        -- Finally, remember last seen
        local ls = lastSeenTarget[pid]
        if ValidUnit(ls) then return ls end
        return nil
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function ThreatHUDData.GetCurrentTarget(pid)
        return pickTarget(pid)
    end

    function ThreatHUDData.GetDPS(pid, target)
        return dpsFor(pid, target)
    end

    function ThreatHUDData.GetThreat(pid, target)
        return threatFor(pid, target)
    end

    -- Builds a snapshot for HUD text
    function ThreatHUDData.BuildSnapshot(pid)
        local tgt = pickTarget(pid)
        local tgtName = (tgt and GetUnitName(tgt)) or "No Target"
        local rows = {}

        if tgt then
            -- Build from AggroManager list when available; otherwise include only self
            local AM = rawget(_G, "AggroManager")
            if AM and AM.GetThreatList then
                local list = AM.GetThreatList(tgt)
                if list then
                    for i = 1, #list do
                        local r = list[i]
                        local p = r and r.pid
                        if p ~= nil then
                            rows[#rows + 1] = {
                                pid = p,
                                name = nameOfPid(p),
                                dps = dpsFor(p, tgt),
                                threat = math.floor(((r.value or 0)) + 0.5),
                            }
                        end
                    end
                end
            else
                -- self only
                rows[#rows + 1] = {
                    pid = pid,
                    name = nameOfPid(pid),
                    dps = dpsFor(pid, tgt),
                    threat = 0,
                }
            end

            -- Sort: self first, then threat desc
            table.sort(rows, function(a, b)
                if a.pid == pid and b.pid ~= pid then return true end
                if b.pid == pid and a.pid ~= pid then return false end
                if a.threat ~= b.threat then return a.threat > b.threat end
                return a.dps > b.dps
            end)
        end

        return { targetName = tgtName, rows = rows }
    end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    local function onDealtDamage(e)
        if not e then return end
        local pid   = e.pid
        local tgt   = e.target
        local amt   = e.amount
        if pid == nil or not ValidUnit(tgt) then return end
        addDamage(pid, tgt, amt)
    end

    local function onKill(e)
        if not e or not e.target then return end
        clearTarget(e.target)
    end

    OnInit.final(function()
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDealtDamage)
            PB.On("OnKill", onKill)
        end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatHUDData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
