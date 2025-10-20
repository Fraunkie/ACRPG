if Debug and Debug.beginFile then Debug.beginFile("CombatEventsBridge.lua") end
--==================================================
-- CombatEventsBridge.lua
-- Wires DamageEngine → ProcBus, ThreatSystem, SpiritDrive, LivesSystem.
-- • Souls are NOT granted here; SoulEnergyLogic listens to ProcBus OnKill.
-- • Emits pid with all payloads.
--==================================================

if not CombatEventsBridge then CombatEventsBridge = {} end
_G.CombatEventsBridge = CombatEventsBridge

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local OOC_TIMEOUT = (GameBalance and GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC) or 6
    local SD_ON_HIT   = (GameBalance and GameBalance.SD_ON_HIT) or 0
    local SD_ON_KILL  = (GameBalance and GameBalance.SD_ON_KILL) or 0

    --------------------------------------------------
    -- State
    --------------------------------------------------
    local lastHitAt = {}   -- pid -> os.clock
    local recentDeath = {} -- handleId -> true for one tick

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function DEV_ON()
        local DM = rawget(_G, "DevMode")
        if DM then
            if type(DM.IsOn) == "function" then return DM.IsOn(0) end
            if type(DM.IsEnabled) == "function" then return DM.IsEnabled() end
        end
        return false
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

    local function markOnce(u)
        local id = GetHandleId(u)
        if recentDeath[id] then return true end
        recentDeath[id] = true
        local t = CreateTimer()
        TimerStart(t, 0.00, false, function()
            recentDeath[id] = nil
            DestroyTimer(t)
        end)
        return false
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
    -- DamageEngine wiring (preferred)
    --------------------------------------------------
    local function hookDamageEngine()
        if not rawget(_G, "DamageEngine") or not DamageEngine.registerEvent then
            dprint("DamageEngine not present")
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

                if SD_ON_HIT ~= 0 and pid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                    pcall(SpiritDrive.Add, pid, SD_ON_HIT)
                end
            end)
        end

        local function lethalHandler(dead, killer)
            if not ValidUnit(dead) then return end
            if markOnce(dead) then return end
            local kpid = ValidUnit(killer) and pidOfUnit(killer) or nil
            if kpid ~= nil then markCombat(kpid) end

            emit("OnKill", { pid = kpid, source = killer, target = dead })
            emit("OnHeroDeath", { pid = pidOfUnit(dead), unit = dead })

            if SD_ON_KILL ~= 0 and kpid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
            end
        end

        if evLethal then
            DamageEngine.registerEvent(evLethal, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                lethalHandler(d.target, d.source)
            end)
        elseif evAfter then
            DamageEngine.registerEvent(evAfter, function()
                local d = DamageEngine.getCurrentDamage and DamageEngine.getCurrentDamage() or nil
                if not d then return end
                if GetWidgetLife(d.target) > 0.405 then return end
                lethalHandler(d.target, d.source)
            end)
        end

        dprint("wired to DamageEngine")
        return true
    end

    --------------------------------------------------
    -- Native fallback
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

            if SD_ON_HIT ~= 0 and pid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, pid, SD_ON_HIT)
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

            if SD_ON_KILL ~= 0 and kpid ~= nil and _G.SpiritDrive and SpiritDrive.Add then
                pcall(SpiritDrive.Add, kpid, SD_ON_KILL)
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
