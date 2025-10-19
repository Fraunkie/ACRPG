if Debug and Debug.beginFile then Debug.beginFile("ThreatSystem.lua") end
--==================================================
-- ThreatSystem.lua
-- Lightweight per-target threat tables with decay.
-- • Damage → threat scaling + flat per-hit.
-- • Healing → threat (coeff, no over-heal reduction).
-- • Group DPS helpers per target.
-- • Ignores bag/inventory helpers if provided.
-- • Safe to load before other systems.
--==================================================

if not ThreatSystem then ThreatSystem = {} end
_G.ThreatSystem = ThreatSystem

do
    --------------------------------------------------
    -- Config (tweak via GameBalance if present)
    --------------------------------------------------
    local GB = rawget(_G, "GameBalance") or {}
    local BASE_PER_HIT      = GB.THREAT_BASE_PER_HIT      or 1        -- flat threat on any hit
    local SCALE_PER_DAMAGE  = GB.THREAT_PER_DAMAGE        or 0.50     -- threat per raw damage
    local HEAL_THREAT_COEFF = GB.THREAT_HEAL_COEFF        or 0.50     -- threat per healed point
    local DECAY_PER_TICK    = GB.THREAT_DECAY_PER_TICK    or 1        -- decay amount per tick
    local TICK_SECONDS      = GB.THREAT_TICK_SECONDS      or 1.00     -- decay tick seconds
    local RESET_IF_EMPTY    = true

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- tables[targetHandle] = {
    --   target = unit,
    --   totalThreat = number,
    --   sources = { [srcHandle] = { threat=number, damage=number, heals=number } },
    --   firstAt = os.clock(),
    --   lastAt  = os.clock()
    -- }
    local tables = {}
    local tickTimer = nil
    

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function dprint(s)
        if Debug and Debug.printf then Debug.printf("[Threat] " .. tostring(s)) end
    end

    local function validUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function hid(h) return h and GetHandleId(h) end

    -- Allow external systems to declare "ignore" units (bag, pets, etc.)
    local function isIgnored(u)
        -- Bag system opt-in
        if _G.Bag and (Bag.IsBagUnit or Bag.IsBag) then
            local ok, res = pcall(Bag.IsBagUnit or Bag.IsBag, u)
            if ok and res then return true end
        end
        -- Fallback: best-effort name check (case-insensitive, ASCII)
        local nm = GetUnitName(u)
        if nm then
            local s = string.lower(nm)
            if string.find(s, "bag", 1, true) or string.find(s, "inventory", 1, true) then
                return true
            end
        end
        return false
    end

    local function getTableForTarget(tgt)
        local key = hid(tgt); if not key then return nil end
        local tab = tables[key]
        if not tab then
            tab = {
                target = tgt,
                totalThreat = 0,
                sources = {},
                firstAt = (os and os.clock and os.clock()) or 0,
                lastAt  = (os and os.clock and os.clock()) or 0,
            }
            tables[key] = tab
        end
        return tab
    end

    local function addThreatRaw(tgt, src, threatAdd, dmgAdd, healAdd)
        if threatAdd == 0 and (dmgAdd or 0) == 0 and (healAdd or 0) == 0 then return end
        local tab = getTableForTarget(tgt); if not tab then return end
        local sh = hid(src); if not sh then return end
        local rec = tab.sources[sh]
        if not rec then
            rec = { threat = 0, damage = 0, heals = 0 }
            tab.sources[sh] = rec
        end
        if threatAdd ~= 0 then
            rec.threat = math.max(0, rec.threat + threatAdd)
        end
        if dmgAdd and dmgAdd ~= 0 then
            rec.damage = rec.damage + dmgAdd
        end
        if healAdd and healAdd ~= 0 then
            rec.heals = rec.heals + healAdd
        end

        -- recompute total
        local total = 0
        for _, v in pairs(tab.sources) do total = total + (v.threat or 0) end
        tab.totalThreat = total

        if os and os.clock then tab.lastAt = os.clock() end
    end

    local function decayOne(tab)
        local changed = false
        for k, v in pairs(tab.sources) do
            local nv = (v.threat or 0) - DECAY_PER_TICK
            if nv <= 0 then
                tab.sources[k] = nil
                changed = true
            else
                if nv ~= v.threat then changed = true end
                v.threat = nv
            end
        end
        if changed then
            local total = 0
            for _, x in pairs(tab.sources) do total = total + (x.threat or 0) end
            tab.totalThreat = total
        end
        return changed
    end

    local function purgeIfEmpty(key)
        local tab = tables[key]
        if not tab then return end
        if next(tab.sources) == nil and RESET_IF_EMPTY then
            tables[key] = nil
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    -- Direct threat injection (rare; prefer damage/heal helpers)
    function ThreatSystem.AddThreat(source, target, amount)
        if not validUnit(source) or not validUnit(target) then return end
        if isIgnored(source) or isIgnored(target) then return end
        local val = math.max(0, math.floor(amount or 0))
        addThreatRaw(target, source, val, 0, 0)
    end

    -- Damage → threat (BASE_PER_HIT + SCALE_PER_DAMAGE * dmg)
    function ThreatSystem.AddThreatFromDamage(source, target, rawDamage)
        if not validUnit(source) or not validUnit(target) then return end
        if isIgnored(source) or isIgnored(target) then return end
        local dmg = math.max(0, rawDamage or 0)
        local threatAdd = BASE_PER_HIT + (SCALE_PER_DAMAGE * dmg)
        addThreatRaw(target, source, threatAdd, dmg, 0)
    end

    -- Healing → threat (HEAL_THREAT_COEFF * healed); overheal does not reduce
    -- Call with actual healed amount (post-cap), not requested.
    function ThreatSystem.AddThreatFromHeal(healer, targetEnemy, healedAmount)
        if not validUnit(healer) or not validUnit(targetEnemy) then return end
        if isIgnored(healer) or isIgnored(targetEnemy) then return end
        local healed = math.max(0, healedAmount or 0)
        if healed == 0 then return end
        local threatAdd = HEAL_THREAT_COEFF * healed
        addThreatRaw(targetEnemy, healer, threatAdd, 0, healed)
    end

    -- Query per-source threat against a target
    function ThreatSystem.GetThreat(source, target)
        if not source or not target then return 0 end
        local tab = tables[hid(target)]
        if not tab then return 0 end
        local rec = tab.sources[hid(source)]
        return (rec and rec.threat) or 0
    end

    -- Return handle id of top threat source and its value (or nil, 0)
    function ThreatSystem.GetTopSourceHandle(target)
        local tab = tables[hid(target)]
        if not tab then return nil, 0 end
        local bestK, bestV = nil, -1
        for k, v in pairs(tab.sources) do
            local t = v.threat or 0
            if t > bestV then bestV, bestK = t, k end
        end
        return bestK, bestV
    end

    -- Snapshot for HUDs: shallow table { totalThreat, firstAt, lastAt, sources = { [hid]={threat,damage,heals} } }
    function ThreatSystem.Snapshot(target)
        local tab = tables[hid(target)]
        if not tab then return { totalThreat=0, firstAt=0, lastAt=0, sources={} } end
        local out = { totalThreat = tab.totalThreat or 0, firstAt = tab.firstAt or 0, lastAt = tab.lastAt or 0, sources = {} }
        for k, v in pairs(tab.sources) do
            out.sources[k] = { threat = v.threat or 0, damage = v.damage or 0, heals = v.heals or 0 }
        end
        return out
    end

    -- Simple average DPS for the whole group on this target
    function ThreatSystem.GetGroupDPS(target)
        local tab = tables[hid(target)]
        if not tab then return 0 end
        local t0, t1 = tab.firstAt or 0, tab.lastAt or 0
        local dt = math.max(0.001, t1 - t0)
        local totalDamage = 0
        for _, v in pairs(tab.sources) do totalDamage = totalDamage + (v.damage or 0) end
        return totalDamage / dt
    end

    -- Housekeeping
    function ThreatSystem.ClearForTarget(target) tables[hid(target)] = nil end
    function ThreatSystem.ClearAll() tables = {} end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    local function onDealtDamage(e)
        if not e then return end
        local src  = e.source
        local tgt  = e.target
        local amt  = tonumber(e.amount or e.damage or 0) or 0
        if not validUnit(src) or not validUnit(tgt) then return end
        if isIgnored(src) or isIgnored(tgt) then return end
        ThreatSystem.AddThreatFromDamage(src, tgt, amt)
    end

    local function onKill(e)
        if not e then return end
        local dead = e.target or e.dead
        if validUnit(dead) then
            ThreatSystem.ClearForTarget(dead)
        end
    end

    -- Hook healing from DamageEngine if present (AFTER is enough; we need actual healed)
    local function hookHealingFromDamageEngine()
        if not rawget(_G, "DamageEngine") then return end
        if not DamageEngine.registerHealEvent then return end
        local AFTER = DamageEngine.HEAL_AFTER
        if not AFTER then return end
        local ok = pcall(function()
            DamageEngine.registerHealEvent(AFTER, function()
                local h = DamageEngine.getCurrentHeal and DamageEngine.getCurrentHeal() or nil
                if not h then return end
                local source = h.source
                local healedEnemy = nil

                -- Map heal threat to the current combat target. If AggroManager provides a "currentTarget" for healer, use it.
                if _G.AggroManager and AggroManager.GetPrimaryTargetForHealer then
                    healedEnemy = AggroManager.GetPrimaryTargetForHealer(source)
                end

                -- As a conservative fallback, do nothing if we cannot attribute to an enemy.
                if not healedEnemy or not validUnit(healedEnemy) then return end

                local actual = tonumber(h.actualHealed or h.amount or 0) or 0
                ThreatSystem.AddThreatFromHeal(source, healedEnemy, actual)
            end)
        end)
        if ok then dprint("healing hook active") else dprint("healing hook skipped") end
    end

    local function onDeathCleanup()
        local t = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(t, function()
            local dead = GetTriggerUnit()
            if validUnit(dead) then
                ThreatSystem.ClearForTarget(dead)
            end
        end)
    end

    --------------------------------------------------
    -- Decay timer
    --------------------------------------------------
    local function ensureTick()
        if tickTimer then return end
        tickTimer = CreateTimer()
        TimerStart(tickTimer, TICK_SECONDS, true, function()
            for key, tab in pairs(tables) do
                if tab and validUnit(tab.target) then
                    decayOne(tab)
                    purgeIfEmpty(key)
                else
                    tables[key] = nil
                end
            end
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        ensureTick()
        -- Wire ProcBus (damage and kill)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("OnDealtDamage", onDealtDamage)
            PB.On("OnKill", onKill)
        end
        -- Optional: healing threat via DamageEngine
        hookHealingFromDamageEngine()
        onDeathCleanup()

        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("ThreatSystem")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
