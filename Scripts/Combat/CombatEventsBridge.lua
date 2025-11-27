if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua  v1.03
-- • Bridges damage to ProcBus, Threat, SD, DPS HUD
-- • Works with DamageEngine (preferred) OR native fallback
-- • Avoids re-applying damage in native path (no double yellow)
-- • Avoids on-hit infinite loop with OnHitPassives.__inPassive
-- • NO DAMAGE CLAMP; optional bonus physical from PlayerData
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    --------------------------------------------------
    -- Tunables
    --------------------------------------------------
    local THREAT_PER_DAMAGE     = (GameBalance and GameBalance.THREAT_PER_DAMAGE)     or 0.5
    -- DAMAGE_TRACK_CLAMP removed (no cap)
    local RECORD_MIN_GAP        = (GameBalance and GameBalance.DAMAGE_RECORD_MIN_GAP) or 0.20
    local SD_ON_HIT             = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_HIT)   or 3
    local SD_ON_KILL            = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_KILL)  or 10
    local SD_GATE_SEC           = (GameBalance and GameBalance.SPIRIT_DRIVE_GATE_SEC) or 0.60
    local OOC_TIMEOUT           = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6

    local AGGRO_GRACE_SEC       = 2.50
    local STATE_TICK            = 0.15

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local lastHitAt      = {}   -- pid -> time
    local enterAt        = {}   -- pid -> time
    local inCombat       = {}   -- pid -> bool

    local pendingAggro   = {}   -- pid -> untilTime
    local lastAggroAt    = {}   -- pid -> time

    local recordGate     = {}   -- pid -> (targetH -> time)
    local sdGate         = {}   -- pid -> (targetH -> time)
    local recentDeath    = {}   -- unitH -> bool

    local stateTimer     = nil

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function IsBag(u)
        if not ValidUnit(u) then
            return false
        end

        return false
    end

    local function pidOf(u)
        if not u then return nil end
        local p = GetOwningPlayer(u); if not p then return nil end
        return GetPlayerId(p)
    end

    local function now()
        if os and os.clock then
            return os.clock()
        end
        return 0
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then
            PB.Emit(name, e)
        end
    end

    local function markOnce(u)
        local id = GetHandleId(u)
        if recentDeath[id] then
            return true
        end
        recentDeath[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function()
            recentDeath[id] = nil
            DestroyTimer(t)
        end)
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
        if not ValidUnit(u) then
            return false
        end
        if type(IsUnitType) == "function" then
            return not IsUnitType(u, UNIT_TYPE_RANGED_ATTACKER)
        end
        return true
    end

    -- No more damage clamp; only sanitize into a positive number
    local function sanitizeAmount(a)
        local amt = tonumber(a or 0) or 0
        if amt <= 0 then
            return 0
        end
        return amt
    end

    -- Safe helper: bonus physical damage from PlayerData, or 0 if missing / nil
    local function getPhysicalBonus(pid)
        if not pid then
            return 0
        end
        local PD = rawget(_G, "PlayerData")
        if not PD or type(PD.GetPhysicalDamage) ~= "function" then
            return 0
        end
        local ok, val = pcall(PD.GetPhysicalDamage, pid,true)
        if not ok or type(val) ~= "number" then
            return 0
        end
        return val
    end

    local function AddThreatTS(source, target, amount)
        local TS = rawget(_G, "ThreatSystem")
        if not TS then
            return
        end
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
        if not pid then
            return
        end
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
        if not pid then
            return
        end
        if inCombat[pid] then
            inCombat[pid] = false
            pendingAggro[pid] = nil
            emit("CombatLeave", { pid = pid, reason = reason or "timeout" })
        end
    end

    function CombatEventsBridge.TouchCombat(pid, reason)
        if not pid then
            return
        end
        lastHitAt[pid] = now()
        enterCombat(pid, reason or "touch")
    end

    function CombatEventsBridge.IsInCombat(pid)
        if not pid then
            return false
        end
        if inCombat[pid] then
            return true
        end
        local t = pendingAggro[pid]
        if t and now() < t then
            return true
        end
        return false
    end

    function CombatEventsBridge.GetCombatSeconds(pid)
        if not pid then
            return 0
        end
        local base = enterAt[pid]
        if not base then
            return 0
        end
        return math.max(0, now() - base)
    end

    function CombatEventsBridge.ForceOutOfCombat(pid)
        leaveCombat(pid, "force")
    end

    --------------------------------------------------
    -- Early aggro detection
    --------------------------------------------------
    local function startAggroWindowFor(pid)
        if not pid then
            return
        end
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

    local function hookAggroOrders()
        local function isAttackOrder(oid)
            return oid == 851983 or oid == 851971
        end

        -- Enemy attacks hero
        local trigEnemyTarget = CreateTrigger()
        for p = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trigEnemyTarget, Player(p), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        end
        TriggerAddAction(trigEnemyTarget, function()
            local src = GetTriggerUnit()
            local tgt = GetOrderTargetUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then
                return
            end
            if IsBag(src) or IsBag(tgt) then
                return
            end

            local oid = GetIssuedOrderId()
            if not isAttackOrder(oid) then
                return
            end

            local tgtPid = pidOf(tgt)
            if not tgtPid then
                return
            end
            if IsPlayerEnemy(GetOwningPlayer(src), GetOwningPlayer(tgt)) then
                startAggroWindowFor(tgtPid)
            end
        end)

        -- Our unit attacks something
        local trigPlayerIssued = CreateTrigger()
        for p = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(trigPlayerIssued, Player(p), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        end
        TriggerAddAction(trigPlayerIssued, function()
            local src = GetTriggerUnit()
            if not ValidUnit(src) or IsBag(src) then
                return
            end
            local oid = GetIssuedOrderId()
            if not isAttackOrder(oid) then
                return
            end
            local p = pidOf(src)
            if not p then
                return
            end
            startAggroWindowFor(p)
        end)
    end

    --------------------------------------------------
    -- Core damage and kill hooks
    --------------------------------------------------
    local function onDamageCurrent(d)
        local src = d.source
        local tgt = d.target
        if not ValidUnit(src) or not ValidUnit(tgt) then
            return
        end
        if IsBag(src) or IsBag(tgt) then
            return
        end

        local pid = pidOf(src)
        if pid then
            lastHitAt[pid] = now()
            enterCombat(pid, "damage")
            cancelAggroWindow(pid)
        end

        if pid == nil or not passRecordGate(pid, tgt) then
            return
        end

        -- base amount from engine (no clamp)
        local baseAmt = sanitizeAmount(d.amount)
        if baseAmt <= 0 then
            return
        end

        -- figure out flags first
        local meleeFlag = isMeleeAttacker(src)
        local isAtk     = (d.isAttack == nil) and true or (d.isAttack == true)

        -- start from base, then add physical bonus for melee/basic attacks
        local amt = baseAmt
        if isAtk and pid then
            local bonus = getPhysicalBonus(pid)
            if bonus ~= 0 then
                amt = amt + bonus
            end
        end

        --------------------------------------------------
        -- DPS / HUD + Threat use the final amount
        --------------------------------------------------
        emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

        local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
        if threatAdd > 0 then
            AddThreatTS(src, tgt, threatAdd)
            if _G.AggroManager and AggroManager.AddThreat then
                pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
            end
        end

        -- Spirit Drive (melee only, using the same meleeFlag / isAtk)
        if SD_ON_HIT ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
            if meleeFlag and isAtk and passSDGate(pid, tgt) then
                pcall(SpiritDrive.Add, pid, SD_ON_HIT)
            end
        end

        local fromNative = (d.fromNative == true)

        --------------------------------------------------
        -- PHYSICAL (basic attacks)
        --------------------------------------------------
        if isAtk then
            -- only re-apply damage if this did NOT come from native
            if not fromNative then
                if DamageEngine and DamageEngine.applyPhysicalDamage then
                    DamageEngine.applyPhysicalDamage(src, tgt, amt)
                else
                    UnitDamageTarget(src, tgt, amt, true, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_NONE)
                end
            end

            -- always show the tag
            if DamageEngine and DamageEngine.showArcingDamageText then
                DamageEngine.showArcingDamageText(src, tgt, amt, DAMAGE_TYPE_NORMAL)
            end

            -- run passives ONLY on real melee hits, and NOT if we are already inside a passive
            if meleeFlag and _G.OnHitPassives and OnHitPassives.Run and not OnHitPassives.__inPassive then
                OnHitPassives.Run(pid, src, tgt, amt, true)
            end

        --------------------------------------------------
        -- SPELL / ENERGY
        --------------------------------------------------
        elseif d.isAttack == false then
            if not fromNative then
                if DamageEngine and DamageEngine.applySpellDamage then
                    DamageEngine.applySpellDamage(src, tgt, amt, DAMAGE_TYPE_MAGIC)
                else
                    UnitDamageTarget(src, tgt, amt, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
                end
            end
            if DamageEngine and DamageEngine.showArcingDamageText then
                DamageEngine.showArcingDamageText(src, tgt, amt, DAMAGE_TYPE_MAGIC)
            end

        --------------------------------------------------
        -- FALLBACK / TRUE
        --------------------------------------------------
        else
            if not fromNative then
                if DamageEngine and DamageEngine.applyTrueDamage then
                    DamageEngine.applyTrueDamage(src, tgt, amt)
                else
                    UnitDamageTarget(src, tgt, amt, false, false, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_NONE)
                end
            end
        end
    end

    local function onKillCurrent(d)
        local dead   = d.target
        local killer = d.source
        if not ValidUnit(dead) then
            return
        end
        if IsBag(dead) or IsBag(killer) then
            return
        end
        if markOnce(dead) then
            return
        end

        local kpid = ValidUnit(killer) and pidOf(killer) or nil
        if kpid then
            lastHitAt[kpid] = now()
            enterCombat(kpid, "kill")
        end

        emit("OnKill",      { pid = kpid, source = killer, target = dead })
        emit("OnHeroDeath", { pid = pidOf(dead), unit = dead })

        -- XP / souls
        if AwardXPFromHFILUnitConfig then
            AwardXPFromHFILUnitConfig(kpid, dead)
        end

        if SD_ON_KILL ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
            pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
        end
    end

    --------------------------------------------------
    -- DamageEngine hook (preferred)
    --------------------------------------------------
    local function hookDE()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            return false
        end

        DamageEngine.registerEvent(DamageEngine.BEFORE, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then
                return
            end
            onDamageCurrent(d)
        end)

        DamageEngine.registerEvent(DamageEngine.LETHAL, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then
                return
            end
            onKillCurrent(d)
        end)

        return true
    end

    --------------------------------------------------
    -- Native fallback
    --------------------------------------------------
    local function hookNative()
        -- Damage
        local td = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(td, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end
        TriggerAddAction(td, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not src then
                return
            end
            local d = {
                source     = src,
                target     = tgt,
                amount     = GetEventDamage() or 0,
                isAttack   = true,
                fromNative = true,   -- IMPORTANT: so we do NOT re-apply
            }
            onDamageCurrent(d)
        end)

        -- Death
        local tk = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tk, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(tk, function()
            local d = {
                target = GetTriggerUnit(),
                source = GetKillingUnit()
            }
            onKillCurrent(d)
        end)
    end

    --------------------------------------------------
    -- Periodic state maintenance
    --------------------------------------------------
    local function stateMaintenance()
        local tnow = now()
        for pid = 0, bj_MAX_PLAYERS - 1 do
            local pa = pendingAggro[pid]
            if pa and tnow >= pa then
                pendingAggro[pid] = nil
                emit("CombatAggroCancelled", { pid = pid })
            end

            if inCombat[pid] then
                local last = lastHitAt[pid]
                if (not last) or (tnow - last) >= OOC_TIMEOUT then
                    leaveCombat(pid, "timeout")
                end
            end
        end
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        hookAggroOrders()

        local ok = hookDE()
        if not ok then
            hookNative()
        end

        stateTimer = CreateTimer()
        TimerStart(stateTimer, STATE_TICK, true, stateMaintenance)

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatEventsBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
