if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua
-- Bridges DamageEngine phases to ProcBus + systems:
--   • Emits: OnDealtDamage, OnKill, OnHeroDeath
--   • Threat: ThreatSystem + AggroManager (scaled, clamped, gated)
--   • SD: melee-only on hit (gated), bonus on kill
--   • Souls: reward on kill
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    --------------------------------------------------
    -- Tunables (GameBalance with safe defaults)
    --------------------------------------------------
    local THREAT_PER_DAMAGE     = (GameBalance and GameBalance.THREAT_PER_DAMAGE)     or 0.5
    local DAMAGE_TRACK_CLAMP    = (GameBalance and GameBalance.DAMAGE_TRACK_CLAMP)    or 35
    local RECORD_MIN_GAP        = (GameBalance and GameBalance.DAMAGE_RECORD_MIN_GAP) or 0.20
    local SD_ON_HIT             = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_HIT)   or 3
    local SD_ON_KILL            = (GameBalance and GameBalance.SPIRIT_DRIVE_ON_KILL)  or 10
    local SD_GATE_SEC           = (GameBalance and GameBalance.SPIRIT_DRIVE_GATE_SEC) or 0.60
    local OOC_TIMEOUT           = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local lastHitAt   = {}   -- pid -> time
    local recordGate  = {}   -- pid -> targetH -> last record time
    local sdGate      = {}   -- pid -> targetH -> last sd time
    local recentDeath = {}   -- handle -> bool

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

    local function markCombat(pid)
        if pid then lastHitAt[pid] = now() end
    end

    function CombatEventsBridge.IsInCombat(pid)
        local t = lastHitAt[pid]
        if not t then return false end
        return (now() - t) < OOC_TIMEOUT
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
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

    local function RewardXP(killer, dead)
        if not ValidUnit(dead) or not ValidUnit(killer) then return end
        local base = 0
        if rawget(_G, "SoulEnergyLogic") and SoulEnergyLogic.GetReward then
            base = SoulEnergyLogic.GetReward(GetUnitTypeId(dead)) or 0
        elseif GameBalance and GameBalance.XP_PER_KILL_BASE then
            base = GameBalance.XP_PER_KILL_BASE
        end
        if base <= 0 then return end
        local kpid = pidOf(killer); if not kpid then return end
        if _G.SoulEnergy and SoulEnergy.Add then pcall(SoulEnergy.Add, kpid, base) end
    end

    local function markOnce(u)
        local id = GetHandleId(u)
        if recentDeath[id] then return true end
        recentDeath[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function() recentDeath[id] = nil; DestroyTimer(t) end)
        return false
    end

    --------------------------------------------------
    -- Hook DamageEngine
    --------------------------------------------------
    local function hookDE()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            return false
        end

        DamageEngine.registerEvent(DamageEngine.BEFORE, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then return end
            local src, tgt = d.source, d.target
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            if IsBag(src) or IsBag(tgt) then return end

            local pid = pidOf(src); if pid then markCombat(pid) end
            if pid == nil or not passRecordGate(pid, tgt) then return end

            local amt = sanitizeAmount(d.amount)
            if amt <= 0 then return end

            -- HUD / DPS bus
            emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

            -- Threat
            local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
            if threatAdd > 0 then
                AddThreatTS(src, tgt, threatAdd)
                if _G.AggroManager and AggroManager.AddThreat then
                    pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
                end
            end

            -- SD: melee-only, gated
            if SD_ON_HIT ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
                local melee = isMeleeAttacker(src)
                local isAtk = (d.isAttack == nil) and true or (d.isAttack == true)
                if melee and isAtk and passSDGate(pid, tgt) then
                    pcall(SpiritDrive.Add, pid, SD_ON_HIT)
                end
            end
        end)

        DamageEngine.registerEvent(DamageEngine.LETHAL, function()
            local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
            if not d then return end
            local dead, killer = d.target, d.source
            if not ValidUnit(dead) then return end
            if IsBag(dead) or IsBag(killer) then return end
            if markOnce(dead) then return end

            local kpid = ValidUnit(killer) and pidOf(killer) or nil
            if kpid then markCombat(kpid) end

            emit("OnKill",      { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOf(dead), unit = dead })

            RewardXP(killer, dead)

            if SD_ON_KILL ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
            end
        end)

        return true
    end

    --------------------------------------------------
    -- Fallback native wiring
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
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            if IsBag(src) or IsBag(tgt) then return end

            local pid = pidOf(src); if pid then markCombat(pid) end
            if pid == nil or not passRecordGate(pid, tgt) then return end

            local amt = sanitizeAmount(GetEventDamage() or 0)
            if amt <= 0 then return end

            emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

            local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
            AddThreatTS(src, tgt, threatAdd)
            if _G.AggroManager and AggroManager.AddThreat then
                pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
            end

            if SD_ON_HIT ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
                if isMeleeAttacker(src) and passSDGate(pid, tgt) then
                    pcall(SpiritDrive.Add, pid, SD_ON_HIT)
                end
            end
        end)

        -- Death
        local tk = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tk, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(tk, function()
            local dead   = GetTriggerUnit()
            local killer = GetKillingUnit()
            if not ValidUnit(dead) then return end
            if IsBag(dead) or IsBag(killer) then return end
            if markOnce(dead) then return end

            local kpid = ValidUnit(killer) and pidOf(killer) or nil
            if kpid then markCombat(kpid) end

            emit("OnKill",      { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOf(dead), unit = dead })

            RewardXP(killer, dead)

            if SD_ON_KILL ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
            end
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local ok = hookDE()
        if not ok then hookNative() end
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatEventsBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
