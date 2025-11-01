if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua  v1.0
-- Bridges DamageEngine phases to ProcBus plus systems
--   • Emits: OnDealtDamage, OnKill, OnHeroDeath
--   • Threat: ThreatSystem plus AggroManager (scaled, clamped, gated)
--   • Spirit Drive: melee only on hit, bonus on kill
--   • Souls or XP: reward on kill
--
-- Hybrid combat state model
--   • Enter on damage or kill immediately
--   • Also enter on enemy aggro signals with a short grace window
--   • If no real damage occurs before grace expiry, revert to out of combat
--   • Leave after OOC_TIMEOUT seconds since last combat event
--
-- Public helpers
--   CombatEventsBridge.IsInCombat(pid) -> bool
--   CombatEventsBridge.GetCombatSeconds(pid) -> number
--   CombatEventsBridge.TouchCombat(pid, reason) -> nil
--   CombatEventsBridge.ForceOutOfCombat(pid) -> nil
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    --------------------------------------------------
    -- Tunables with safe fallbacks
    --------------------------------------------------
    local THREAT_PER_DAMAGE     = (GameBalance and GameBalance.THREAT_PER_DAMAGE)     or 0.5
    local DAMAGE_TRACK_CLAMP    = (GameBalance and GameBalance.DAMAGE_TRACK_CLAMP)    or 35
    local RECORD_MIN_GAP        = (GameBalance and GameBalance.DAMAGE_RECORD_MIN_GAP) or 0.20
    local SD_ON_HIT             = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_HIT)   or 3
    local SD_ON_KILL            = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_KILL)  or 10
    local SD_GATE_SEC           = (GameBalance and GameBalance.SPIRIT_DRIVE_GATE_SEC) or 0.60
    local OOC_TIMEOUT           = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6

    -- Hybrid aggro window
    local AGGRO_GRACE_SEC       = 2.50   -- time from aggro to confirm with real damage
    local STATE_TICK            = 0.15   -- periodic maintenance tick

    --------------------------------------------------
    -- State
    --------------------------------------------------
    -- Damage and state timing
    local lastHitAt      = {}   -- pid -> time of last real combat contact
    local enterAt        = {}   -- pid -> time of most recent enter
    local inCombat       = {}   -- pid -> bool

    -- Pending early aggro
    local pendingAggro   = {}   -- pid -> until time
    local lastAggroAt    = {}   -- pid -> time of last aggro signal

    -- Gates
    local recordGate     = {}   -- pid -> targetH -> last record time
    local sdGate         = {}   -- pid -> targetH -> last sd time
    local recentDeath    = {}   -- handle -> bool

    -- Periodic timer
    local stateTimer     = nil

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function IsBag(u)
        if not ValidUnit(u) then return false end
        if _G.BagIgnore and BagIgnore.IsBag then
            local ok, res = pcall(BagIgnore.IsBag, u)
            if ok and res then return true end
        end
        return false
    end

    local function pidOf(u)
        if not u then return nil end
        local p = GetOwningPlayer(u); if not p then return nil end
        return GetPlayerId(p)
    end

    local function now()
        if os and os.clock then return os.clock() end
        return 0
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    local function markOnce(u)
        local id = GetHandleId(u)
        if recentDeath[id] then return true end
        recentDeath[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function() recentDeath[id] = nil; DestroyTimer(t) end)
        return false
    end

    local function passRecordGate(pid, target)
        local h = GetHandleId(target)
        recordGate[pid] = recordGate[pid] or {}
        local t = now()
        local last = recordGate[pid][h] or -1000
        if (t - last) >= RECORD_MIN_GAP then
            recordGate[pid][h] = t
            return true
        end
        return false
    end

    local function passSDGate(pid, target)
        local h = GetHandleId(target)
        sdGate[pid] = sdGate[pid] or {}
        local t = now()
        local last = sdGate[pid][h] or -1000
        if (t - last) >= SD_GATE_SEC then
            sdGate[pid][h] = t
            return true
        end
        return false
    end

    local function isMeleeAttacker(u)
        if not ValidUnit(u) then return false end
        if type(IsUnitType) == "function" then
            return not IsUnitType(u, UNIT_TYPE_RANGED_ATTACKER)
        end
        return true
    end

    local function sanitizeAmount(a)
        local amt = tonumber(a or 0) or 0
        if amt <= 0 then return 0 end
        local cap = DAMAGE_TRACK_CLAMP or 0
        if cap > 0 and amt > cap then amt = cap end
        return amt
    end

    local function AddThreatTS(source, target, amount)
        local TS = rawget(_G, "ThreatSystem")
        if not TS then return end
        if type(TS.AddThreat) == "function" then
            pcall(TS.AddThreat, source, target, amount or 0)
        elseif type(TS.OnDamage) == "function" then
            pcall(TS.OnDamage, source, target, amount or 0)
        end
    end

    --------------------------------------------------
    -- Public combat state API
    --------------------------------------------------
    local function enterCombat(pid, reason)
        if not pid then return end
        local already = inCombat[pid] == true
        inCombat[pid] = true
        enterAt[pid] = enterAt[pid] or now()
        pendingAggro[pid] = nil
        if not already then
            enterAt[pid] = now()
            emit("CombatEnter", { pid = pid, reason = reason or "enter" })
        end
    end

    local function leaveCombat(pid, reason)
        if not pid then return end
        if inCombat[pid] then
            inCombat[pid] = false
            pendingAggro[pid] = nil
            emit("CombatLeave", { pid = pid, reason = reason or "timeout" })
        end
    end

    -- External touch from systems if needed
    function CombatEventsBridge.TouchCombat(pid, reason)
        if not pid then return end
        lastHitAt[pid] = now()
        enterCombat(pid, reason or "touch")
    end

    function CombatEventsBridge.IsInCombat(pid)
        if not pid then return false end
        -- Hard in combat
        if inCombat[pid] then
            return true
        end
        -- Pending aggro is not hard combat
        local t = pendingAggro[pid]
        if t and now() < t then
            return true
        end
        return false
    end

    function CombatEventsBridge.GetCombatSeconds(pid)
        if not pid then return 0 end
        local base = enterAt[pid]
        if not base then return 0 end
        return math.max(0, now() - base)
    end

    function CombatEventsBridge.ForceOutOfCombat(pid)
        leaveCombat(pid, "force")
    end

    --------------------------------------------------
    -- Early aggro detection
    --------------------------------------------------
    local function startAggroWindowFor(pid)
        if not pid then return end
        local tnow = now()
        lastAggroAt[pid] = tnow
        pendingAggro[pid] = tnow + AGGRO_GRACE_SEC
        emit("CombatAggroStart", { pid = pid, untilTime = pendingAggro[pid] })
    end

    local function cancelAggroWindow(pid)
        if pendingAggro[pid] then
            pendingAggro[pid] = nil
            emit("CombatAggroCancelled", { pid = pid })
        end
    end

    -- When an enemy issues an attack or smart order against a hero, mark aggro for that hero
    local function hookAggroOrders()
        local function isAttackOrder(oid)
            -- Common attack and smart orders
            return oid == 851983 or oid == 851971
        end

        -- Enemy issued target order on our hero
        local trigEnemyTarget = CreateTrigger()
        for p = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trigEnemyTarget, Player(p), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        end
        TriggerAddAction(trigEnemyTarget, function()
            local src = GetTriggerUnit()
            local tgt = GetOrderTargetUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            if IsBag(src) or IsBag(tgt) then return end

            local oid = GetIssuedOrderId()
            if not isAttackOrder(oid) then return end

            local tgtPid = pidOf(tgt)
            if not tgtPid then return end
            -- Only consider if src owner is an enemy of tgt owner
            if IsPlayerEnemy(GetOwningPlayer(src), GetOwningPlayer(tgt)) then
                -- Do not force hard enter yet, begin grace window
                startAggroWindowFor(tgtPid)
            end
        end)

        -- Player issues an attack or offensive order, optional soft pre enter
        local trigPlayerIssued = CreateTrigger()
        for p = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trigPlayerIssued, Player(p), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        end
        TriggerAddAction(trigPlayerIssued, function()
            local src = GetTriggerUnit()
            if not ValidUnit(src) or IsBag(src) then return end
            local oid = GetIssuedOrderId()
            if not isAttackOrder(oid) then return end
            local p = pidOf(src); if not p then return end
            -- Begin window so followers can react slightly earlier
            startAggroWindowFor(p)
        end)
    end

    --------------------------------------------------
    -- Core damage and kill hooks
    --------------------------------------------------
    local function onDamageCurrent(d)
    local src, tgt = d.source, d.target
    if not ValidUnit(src) or not ValidUnit(tgt) then return end
    if IsBag(src) or IsBag(tgt) then return end

    local pid = pidOf(src)
    if pid then
        lastHitAt[pid] = now()
        -- Confirm combat on real contact
        enterCombat(pid, "damage")
        -- Any pending aggro is satisfied by real damage
        cancelAggroWindow(pid)
    end

    if pid == nil or not passRecordGate(pid, tgt) then return end

    local amt = sanitizeAmount(d.amount)
    if amt <= 0 then return end

    -- Debug: Output damage being dealt
    DisplayTextToPlayer(GetOwningPlayer(src), 0, 0, "Damage Dealt: " .. tostring(amt))

    -- HUD and DPS bus
    emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

    -- Threat
    local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
    if threatAdd > 0 then
        AddThreatTS(src, tgt, threatAdd)
        if _G.AggroManager and AggroManager.AddThreat then
            pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
        end
    end

    -- Spirit Drive
    if SD_ON_HIT ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
        local melee = isMeleeAttacker(src)
        local isAtk = (d.isAttack == nil) and true or (d.isAttack == true)
        if melee and isAtk and passSDGate(pid, tgt) then
            pcall(SpiritDrive.Add, pid, SD_ON_HIT)
        end
    end

    -- Apply damage dynamically based on damage type
    if d.isAttack then
        -- Apply physical damage if it's an attack (melee or ranged)
        DamageEngine.applyPhysicalDamage(src, tgt, amt)
        DamageEngine.showArcingDamageText(src, tgt, amt, DAMAGE_TYPE_NORMAL)
    elseif d.isAttack == false then
        -- Apply spell or energy-based damage
        DamageEngine.applySpellDamage(src, tgt, amt, DAMAGE_TYPE_MAGIC)
        DamageEngine.showArcingDamageText(src, tgt, amt, DAMAGE_TYPE_MAGIC)
    else
        -- Apply true damage (e.g., critical)
        DamageEngine.applyTrueDamage(src, tgt, amt)
    end

    -- Show the arcing damage text after damage is applied
end


    local function onKillCurrent(d)
        local dead, killer = d.target, d.source
        if not ValidUnit(dead) then return end
        if IsBag(dead) or IsBag(killer) then return end
        if markOnce(dead) then return end

        local kpid = ValidUnit(killer) and pidOf(killer) or nil
        if kpid then
            lastHitAt[kpid] = now()
            enterCombat(kpid, "kill")
        end

        emit("OnKill",      { pid = kpid, source = killer, target = dead })
        emit("OnHeroDeath", { pid = pidOf(dead), unit = dead })

       AwardXPFromHFILUnitConfig(kpid, dead)

        if SD_ON_KILL ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
            pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
        end
    end

    -- Hook DamageEngine if present
    local function hookDE()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            return false
        end

        DamageEngine.registerEvent(DamageEngine.BEFORE, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then return end
            onDamageCurrent(d)
        end)

        DamageEngine.registerEvent(DamageEngine.LETHAL, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then return end
            onKillCurrent(d)
        end)

        return true
    end

    -- Fallback native wiring if no DamageEngine
    local function hookNative()
        -- Damage
        local td = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(td, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end
        TriggerAddAction(td, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not src then return end
            local d = {
                source = src,
                target = tgt,
                amount = GetEventDamage() or 0,
                isAttack = true
            }
            onDamageCurrent(d)
        end)

        -- Death
        local tk = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tk, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(tk, function()
            local d = { target = GetTriggerUnit(), source = GetKillingUnit() }
            onKillCurrent(d)
        end)
    end

    --------------------------------------------------
    -- Periodic state maintenance
    --------------------------------------------------
    local function stateMaintenance()
        local tnow = now()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            -- Pending aggro expiration without confirmation
            local pa = pendingAggro[pid]
            if pa and tnow >= pa then
                pendingAggro[pid] = nil
                emit("CombatAggroCancelled", { pid = pid })
                -- Do not force leave here, just end the early window
            end

            -- Hard leave on inactivity
            if inCombat[pid] then
                local last = lastHitAt[pid]
                if not last or (tnow - last) >= OOC_TIMEOUT then
                    leaveCombat(pid, "timeout")
                end
            end
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        -- Order listeners for early aggro
        hookAggroOrders()

        -- Damage and kill
        local ok = hookDE()
        if not ok then hookNative() end

        -- Periodic state timer
        stateTimer = CreateTimer()
        TimerStart(stateTimer, STATE_TICK, true, stateMaintenance)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatEventsBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
