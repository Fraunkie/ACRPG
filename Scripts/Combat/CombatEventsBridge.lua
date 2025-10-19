if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua
-- Wires DamageEngine → ProcBus, ThreatSystem, SoulEnergy, SpiritDrive.
-- Emits pid in payloads and also OnHeroDeath for LivesSystem.
-- • Souls: on KILL only
-- • SpiritDrive: on HIT and on KILL bonus via GameBalance knobs
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local OOC_TIMEOUT = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local lastHitAt = {}   -- pid -> os.clock time of last hit

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function DEV_ON()
        return (rawget(_G, "DevMode") and type(DevMode.IsOn) == "function" and DevMode.IsOn()) or false
    end
    local function dprint(msg) if DEV_ON() then print("[CombatBridge] " .. tostring(msg)) end end

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end

    local function pidOfUnit(u)
        if not u then return nil end
        local p = GetOwningPlayer(u)
        if not p then return nil end
        return GetPlayerId(p)
    end

    local function markCombat(pid)
        if pid == nil then return end
        if os and os.clock then
            lastHitAt[pid] = os.clock()
        else
            lastHitAt[pid] = 0
        end
    end

    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    --------------------------------------------------
    -- Public
    --------------------------------------------------
    function CombatEventsBridge.IsInCombat(pid)
        local t = lastHitAt[pid]
        if not t then return false end
        if os and os.clock then
            return (os.clock() - t) < OOC_TIMEOUT
        end
        return true
    end

    --------------------------------------------------
    -- Threat hook
    --------------------------------------------------
    local function AddThreat(source, target, amount)
        local TS = rawget(_G, "ThreatSystem")
        if not TS then return end
        if type(TS.AddThreat) == "function" then
            local val = math.max(1, math.floor((amount or 0) * 0.5))
            pcall(TS.AddThreat, source, target, val)
        elseif type(TS.OnDamage) == "function" then
            pcall(TS.OnDamage, source, target, amount or 0)
        end
    end

    --------------------------------------------------
    -- XP helper (per-unit via SoulEnergyLogic / HFIL_UnitConfig)
    --------------------------------------------------
    local function RewardXP(killer, dead)
        if not ValidUnit(dead) or not ValidUnit(killer) then return end
        local base = 0
        local raw = GetUnitTypeId(dead) -- numeric
        if rawget(_G, "SoulEnergyLogic") and SoulEnergyLogic.GetReward then
            base = SoulEnergyLogic.GetReward(raw)
        elseif rawget(_G, "HFILUnitConfig") and HFILUnitConfig.GetByFour then
            local row = HFILUnitConfig.GetByFour(raw)
            if row and row.baseSoul then base = row.baseSoul end
        elseif GameBalance and GameBalance.XP_PER_KILL_BASE then
            base = GameBalance.XP_PER_KILL_BASE
        end
        if base <= 0 then
            dprint("no soul reward for raw " .. tostring(raw))
            return
        end

        local kpid = pidOfUnit(killer)
        if kpid == nil then return end

        -- Hand off to logic which applies player bonus and emits UI events
        if rawget(_G, "SoulEnergyLogic") and SoulEnergy.Add then
            SoulEnergy.Add(kpid, base)
        else
            -- Fallback same path
            if _G.SoulEnergy and SoulEnergy.Add then
                SoulEnergy.Add(kpid, base)
            end
        end
        dprint("rewarded soul base " .. tostring(base) .. " for pid " .. tostring(kpid))
    end

    --------------------------------------------------
    -- Dedup death
    --------------------------------------------------
    local recent = {} -- handleId -> true for one tick
    local function markOnce(u)
        local id = GetHandleId(u)
        if recent[id] then return true end
        recent[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function()
            recent[id] = nil
            DestroyTimer(t)
        end)
        return false
    end

    --------------------------------------------------
    -- DamageEngine wiring
    --------------------------------------------------
    local function hookDamageEngine()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            dprint("DamageEngine not present, using native fallback")
            return false
        end

        local evBefore = DamageEngine.BEFORE
        local evAfter  = DamageEngine.AFTER
        local evLethal = DamageEngine.LETHAL

        if evBefore then
            DamageEngine.registerEvent(evBefore, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                local src, tgt = d.source, d.target
                if not ValidUnit(src) or not ValidUnit(tgt) then return end
                local amt = tonumber(d.damage or d.amount or 0) or 0
                local pid = pidOfUnit(src)
                if pid ~= nil then markCombat(pid) end

                emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })
                AddThreat(src, tgt, amt)

                local onHitSD = (GameBalance and GameBalance.SD_ON_HIT) or 0
                if onHitSD ~= 0 and pid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                    pcall(SpiritDrive.Add, pid, onHitSD)
                end
            end)
        end

        if evLethal then
            DamageEngine.registerEvent(evLethal, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                local dead, killer = d.target, d.source
                if not ValidUnit(dead) then return end
                if markOnce(dead) then return end

                local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
                if kpid ~= nil then markCombat(kpid) end

                emit("OnKill", { pid = kpid, source = killer, target = dead })
                emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })

                RewardXP(killer, dead)

                local bonus = (GameBalance and GameBalance.SD_ON_KILL) or 0
                if bonus ~= 0 and kpid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                    pcall(SpiritDrive.Add, kpid, bonus)
                end
            end)
        elseif evAfter then
            DamageEngine.registerEvent(evAfter, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                local dead, killer = d.target, d.source
                if not ValidUnit(dead) then return end
                if GetWidgetLife(dead) > 0.405 then return end
                if markOnce(dead) then return end

                local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
                if kpid ~= nil then markCombat(kpid) end

                emit("OnKill", { pid = kpid, source = killer, target = dead })
                emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })

                RewardXP(killer, dead)

                local bonus = (GameBalance and GameBalance.SD_ON_KILL) or 0
                if bonus ~= 0 and kpid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                    pcall(SpiritDrive.Add, kpid, bonus)
                end
            end)
        end

        dprint("wired to DamageEngine")
        return true
    end

    --------------------------------------------------
    -- Native fallback if no DamageEngine
    --------------------------------------------------
    local function hookNative()
        -- damage proxy
        local td = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(td, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end
        TriggerAddAction(td, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            local pid = pidOfUnit(src)
            if pid ~= nil then markCombat(pid) end
            emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = 0 })
            AddThreat(src, tgt, 1)

            local onHitSD = (GameBalance and GameBalance.SD_ON_HIT) or 0
            if onHitSD ~= 0 and pid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, pid, onHitSD)
            end
        end)

        -- death
        local tk = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tk, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(tk, function()
            local dead   = GetTriggerUnit()
            local killer = GetKillingUnit()
            if not ValidUnit(dead) then return end
            if markOnce(dead) then return end
            local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
            if kpid ~= nil then markCombat(kpid) end

            emit("OnKill", { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })

            RewardXP(killer, dead)

            local bonus = (GameBalance and GameBalance.SD_ON_KILL) or 0
            if bonus ~= 0 and kpid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, bonus)
            end
        end)

        dprint("wired native events")
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        local ok = hookDamageEngine()
        if not ok then hookNative() end
        dprint("ready")
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("CombatEventsBridge")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
