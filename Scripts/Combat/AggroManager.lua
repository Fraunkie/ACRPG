if Debug and Debug.beginFile then Debug.beginFile("AggroManager.lua") end
--==================================================
-- AggroManager.lua
-- Lightweight per-target threat manager keyed by pid.
-- • Listens to ProcBus damage/heal/kill events.
-- • Maintains threat tables with decay.
-- • Exposes helpers used by HUD/AI:
--     GetAnyTargetForPid(pid)
--     GetThreatList(target) -> { {pid,value}, ... } sorted
--     AddThreatPid(target, pid, amount)
--     ClearForTarget(target)
--==================================================

if not AggroManager then AggroManager = {} end
_G.AggroManager = AggroManager

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local BASE_PER_HIT    = 1.0     -- flat threat per damaging hit
    local SCALE_PER_DMG   = 0.5     -- threat per raw damage point
    local SCALE_PER_HEAL  = 0.5     -- threat per effective healing point
    local DECAY_PER_TICK  = 1.0     -- threat decay each tick
    local TICK_SECONDS    = 1.0     -- decay cadence

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- tables[targetH] = { total, byPid = { [pid]=value }, target=u }
    local tables = {}
    local lastTargetByPid = {}  -- remembers player’s most recent target that they damaged/healed
    local tickTimer = nil

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Aggro] " .. tostring(s)) end
    end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function hid(h) return h and GetHandleId(h) or nil end

    local function isIgnoredUnit(u)
        -- Bag / purely cosmetic followers should be ignored
        if rawget(_G, "Bag") and Bag.IsBag and pcall(Bag.IsBag, u) then
            local ok, res = pcall(Bag.IsBag, u)
            if ok and res then return true end
        end
        return false
    end

    local function tableForTarget(tgt)
        local k = hid(tgt); if not k then return nil end
        local tab = tables[k]
        if not tab then
            tab = { total = 0, byPid = {}, target = tgt }
            tables[k] = tab
        end
        return tab
    end

    local function recomputeTotal(tab)
        local sum = 0
        for _,v in pairs(tab.byPid) do sum = sum + v end
        tab.total = sum
    end

    local function addThreatInternal(tgt, pid, val)
        if not validUnit(tgt) or pid == nil then return end
        if isIgnoredUnit(tgt) then return end
        if val == 0 then return end
        local tab = tableForTarget(tgt); if not tab then return end
        local cur = tab.byPid[pid] or 0
        local nv = cur + val
        if nv < 0 then nv = 0 end
        tab.byPid[pid] = nv
        recomputeTotal(tab)
        lastTargetByPid[pid] = tgt
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function AggroManager.AddThreatPid(target, pid, amount)
        local a = tonumber(amount or 0) or 0
        if a ~= 0 then addThreatInternal(target, pid, a) end
    end

    function AggroManager.ClearForTarget(target)
        local k = hid(target); if not k then return end
        tables[k] = nil
    end

    -- Sorted snapshot of threat on a target
    function AggroManager.GetThreatList(target)
        local tab = tables[hid(target)]
        if not tab then return {} end
        local out = {}
        for pid,v in pairs(tab.byPid or {}) do
            out[#out+1] = { pid = pid, value = v }
        end
        table.sort(out, function(a,b) return (a.value or 0) > (b.value or 0) end)
        return out
    end

    -- Player’s current target (best guess = last unit they affected)
    function AggroManager.GetAnyTargetForPid(pid)
        local tgt = lastTargetByPid[pid]
        if validUnit(tgt) then return tgt end
        return nil
    end

    -- Debug: total threat value a pid has on a given target
    function AggroManager.GetThreatValue(pid, target)
        local tab = tables[hid(target)]
        if not tab then return 0 end
        return tab.byPid[pid] or 0
    end

    --------------------------------------------------
    -- Decay
    --------------------------------------------------
    local function decayOne(tab)
        local changed = false
        for pid,v in pairs(tab.byPid) do
            local nv = v - DECAY_PER_TICK
            if nv <= 0 then
                tab.byPid[pid] = nil
                changed = true
            else
                if nv ~= v then changed = true end
                tab.byPid[pid] = nv
            end
        end
        if changed then recomputeTotal(tab) end
        return changed
    end

    local function ensureDecayTimer()
        if tickTimer then return end
        tickTimer = CreateTimer()
        TimerStart(tickTimer, TICK_SECONDS, true, function()
            for k,tab in pairs(tables) do
                if tab and validUnit(tab.target) then
                    decayOne(tab)
                    -- purge empty
                    local empty = true
                    for _ in pairs(tab.byPid) do empty = false break end
                    if empty then tables[k] = nil end
                else
                    tables[k] = nil
                end
            end
        end)
    end

    --------------------------------------------------
    -- Wiring: ProcBus
    --------------------------------------------------
    local function onDealtDamage(e)
        if not e then return end
        local pid   = e.pid
        local tgt   = e.target
        local amt   = tonumber(e.amount or 0) or 0
        if pid == nil or not validUnit(tgt) then return end
        if amt <= 0 then
            -- still count a ping for target memory (no threat change)
            lastTargetByPid[pid] = tgt
            return
        end
        local add = BASE_PER_HIT + SCALE_PER_DMG * amt
        addThreatInternal(tgt, pid, add)
    end

    local function onHeal(e)
        -- Optional: if you emit healing events via ProcBus
        -- Expect e.pid healer pid, e.target the healed unit, e.amount effective heal
        if not e then return end
        local pid = e.pid
        local tgt = e.target
        local amt = tonumber(e.amount or 0) or 0
        if pid == nil or not validUnit(tgt) then return end
        if amt <= 0 then return end
        local add = SCALE_PER_HEAL * amt
        addThreatInternal(tgt, pid, add)
    end

    local function onKill(e)
        if not e then return end
        local dead = e.target or e.dead
        if validUnit(dead) then AggroManager.ClearForTarget(dead) end
    end

    local function wireBus()
        local PB = rawget(_G, "ProcBus")
        if not PB or not PB.On then return end
        PB.On("OnDealtDamage", onDealtDamage)
        PB.On("OnHeal",        onHeal)   -- only if you emit it
        PB.On("OnKill",        onKill)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        ensureDecayTimer()
        wireBus()
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("AggroManager")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
