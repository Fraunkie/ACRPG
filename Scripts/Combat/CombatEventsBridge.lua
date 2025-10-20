if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua
-- Wires DamageEngine -> ProcBus, ThreatSystem, AggroManager, Souls, SpiritDrive.
-- Adds scaling/clamping for HUD DPS/threat so values are stable.
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    local OOC_TIMEOUT = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6
    local THREAT_PER_DAMAGE = (GameBalance and GameBalance.THREAT_PER_DAMAGE) or 1.0
    local DAMAGE_TRACK_CLAMP = (GameBalance and GameBalance.DAMAGE_TRACK_CLAMP) or 250

    local lastHitAt   = {}   -- pid -> time

    local function DEV_ON()
        local D = rawget(_G, "DevMode")
        if D then
            if type(D.IsOn) == "function" then local ok,v=pcall(D.IsOn); if ok and v then return true end end
            if type(D.IsEnabled) == "function" then local ok,v=pcall(D.IsEnabled); if ok and v then return true end end
        end
        return false
    end
    local function dprint(msg) if DEV_ON() then print("[CombatBridge] " .. tostring(msg)) end end

    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function IsBag(u)
        if not ValidUnit(u) then return false end
        if _G.BagIgnore and BagIgnore.IsBag then
            local ok,res=pcall(BagIgnore.IsBag,u); if ok and res then return true end
        end
        return false
    end
    local function pidOfUnit(u)
        if not u then return nil end
        local p = GetOwningPlayer(u); if not p then return nil end
        return GetPlayerId(p)
    end
    local function now() if os and os.clock then return os.clock() end return 0 end
    local function markCombat(pid) if pid then lastHitAt[pid] = now() end end
    local function emit(name, e) local PB=rawget(_G,"ProcBus"); if PB and PB.Emit then PB.Emit(name,e) end end

    function CombatEventsBridge.IsInCombat(pid)
        local t = lastHitAt[pid]; if not t then return false end
        return (now() - t) < OOC_TIMEOUT
    end

    -- ThreatSystem shim
    local function AddThreatTS(source, target, amount)
        local TS = rawget(_G, "ThreatSystem")
        if TS and type(TS.AddThreat) == "function" then
            pcall(TS.AddThreat, source, target, amount or 0)
        elseif TS and type(TS.OnDamage) == "function" then
            pcall(TS.OnDamage, source, target, amount or 0)
        end
    end

    -- Souls helper
    local function RewardXP(killer, dead)
        if not ValidUnit(dead) or not ValidUnit(killer) then return end
        local base = 0
        if rawget(_G, "SoulEnergyLogic") and SoulEnergyLogic.GetReward then
            base = SoulEnergyLogic.GetReward(GetUnitTypeId(dead)) or 0
        elseif GameBalance and GameBalance.XP_PER_KILL_BASE then
            base = GameBalance.XP_PER_KILL_BASE
        end
        if base <= 0 then return end
        local kpid = pidOfUnit(killer); if not kpid then return end
        if _G.SoulEnergy and SoulEnergy.Add then SoulEnergy.Add(kpid, base) end
    end

    -- Dedup death
    local recent = {}
    local function markOnce(u)
        local id = GetHandleId(u)
        if recent[id] then return true end
        recent[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function() recent[id] = nil; DestroyTimer(t) end)
        return false
    end

    -- Sanity layer: clamp and scale amount that we record for HUD/threat
    local function sanitizeAmount(rawAmt)
        local amt = tonumber(rawAmt or 0) or 0
        if amt <= 0 then return 0 end
        if DAMAGE_TRACK_CLAMP and DAMAGE_TRACK_CLAMP > 0 then
            if amt > DAMAGE_TRACK_CLAMP then amt = DAMAGE_TRACK_CLAMP end
        end
        return amt
    end

    --------------------------------------------------
    -- DamageEngine wiring
    --------------------------------------------------
    local function hookDamageEngine()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            dprint("DamageEngine not found, using native fallback")
            return false
        end

        local evBefore = DamageEngine.BEFORE
        local evLethal = DamageEngine.LETHAL
        local evAfter  = DamageEngine.AFTER

        if evBefore then
            DamageEngine.registerEvent(evBefore, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                local src, tgt = d.source, d.target
                if not ValidUnit(src) or not ValidUnit(tgt) then return end
                if IsBag(src) or IsBag(tgt) then return end

                local rawAmt = d.damage or d.amount or 0
                local amt = sanitizeAmount(rawAmt)
                local pid = pidOfUnit(src)
                if pid then markCombat(pid) end

                -- Always emit for DPS tracker with the sanitized amount
                if amt > 0 then
                    emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

                    -- Threat goes to both systems (TS + AggroManager) with scaling
                    local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
                    if threatAdd > 0 then
                        AddThreatTS(src, tgt, threatAdd)
                        if _G.AggroManager and AggroManager.AddThreat then
                            pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
                        elseif _G.AggroManager and AggroManager.AddDamage then
                            pcall(AggroManager.AddDamage, tgt, pid, threatAdd)
                        end
                    end

                    -- Optional SD gain on any melee/basic hit (kept simple)
                    local onHitSD = (GameBalance and GameBalance.SD_ON_HIT) or 0
                    if onHitSD ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
                        pcall(SpiritDrive.Add, pid, onHitSD)
                    end
                end
            end)
        end

        local function handleLethal(d)
            if not d then return end
            local dead, killer = d.target, d.source
            if not ValidUnit(dead) then return end
            if IsBag(dead) or IsBag(killer) then return end
            if markOnce(dead) then return end

            local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
            if kpid then markCombat(kpid) end

            emit("OnKill", { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })

            RewardXP(killer, dead)

            local bonus = (GameBalance and GameBalance.SD_ON_KILL) or 0
            if bonus ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, bonus)
            end
        end

        if evLethal then
            DamageEngine.registerEvent(evLethal, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                handleLethal(d)
            end)
        elseif evAfter then
            DamageEngine.registerEvent(evAfter, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d or not ValidUnit(d.target) then return end
                if GetWidgetLife(d.target) > 0.405 then return end
                handleLethal(d)
            end)
        end

        dprint("wired to DamageEngine")
        return true
    end

    --------------------------------------------------
    -- Native fallback
    --------------------------------------------------
    local function hookNative()
        local td = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(td, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end
        TriggerAddAction(td, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            if IsBag(src) or IsBag(tgt) then return end

            local pid = pidOfUnit(src)
            if pid then markCombat(pid) end

            -- Native gives no amount, so use 1 and scale/clamp path (still stable)
            local amt = sanitizeAmount(1)
            emit("OnDealtDamage", { pid = pid, source = src, target = tgt, amount = amt })

            local threatAdd = math.floor(amt * (THREAT_PER_DAMAGE or 1.0))
            AddThreatTS(src, tgt, threatAdd)
            if _G.AggroManager and AggroManager.AddThreat then
                pcall(AggroManager.AddThreat, tgt, pid, threatAdd)
            elseif _G.AggroManager and AggroManager.AddDamage then
                pcall(AggroManager.AddDamage, tgt, pid, threatAdd)
            end

            local onHitSD = (GameBalance and GameBalance.SD_ON_HIT) or 0
            if onHitSD ~= 0 and pid and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, pid, onHitSD)
            end
        end)

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
            local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
            if kpid then markCombat(kpid) end

            emit("OnKill", { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })
            RewardXP(killer, dead)

            local bonus = (GameBalance and GameBalance.SD_ON_KILL) or 0
            if bonus ~= 0 and kpid and _G.SpiritDrive and SpiritDrive.Add then
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
