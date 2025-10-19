if Debug and Debug.beginFile then Debug.beginFile("DamageEngine.lua") end
--==================================================
-- DamageEngine.lua
-- Lightweight local adapter for damage / death events
-- Fires ProcBus hooks so systems like ThreatSystem,
-- SoulEnergy, SpiritDrive, etc. can listen uniformly.
--==================================================

if not DamageEngine then DamageEngine = {} end
_G.DamageEngine = DamageEngine

do
    --------------------------------------------------
    -- Config
    --------------------------------------------------
    local TICK = 0.00 -- we don’t need a delay, instant emit

    --------------------------------------------------
    -- Helpers
    --------------------------------------------------
    local function ValidUnit(u) return u and GetUnitTypeId(u) ~= 0 end
    local function emit(name, e)
        local PB = rawget(_G, "ProcBus")
        if PB and PB.Emit then PB.Emit(name, e) end
    end

    --------------------------------------------------
    -- Events (local simulation)
    --------------------------------------------------
    DamageEngine.BEFORE = "BEFORE"
    DamageEngine.AFTER  = "AFTER"
    DamageEngine.LETHAL = "LETHAL"

    --------------------------------------------------
    -- Current damage context (for compatibility)
    --------------------------------------------------
    local current = {}
    function DamageEngine.getCurrentDamage() return current end

    --------------------------------------------------
    -- Registration (just stored, not required by this stub)
    --------------------------------------------------
    function DamageEngine.registerEvent(eventName, fn)
        if type(fn) ~= "function" then return end
        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            if eventName == DamageEngine.LETHAL then
                PB.On("OnKill", fn)
            elseif eventName == DamageEngine.AFTER or eventName == DamageEngine.BEFORE then
                PB.On("OnDealtDamage", fn)
            end
        end
    end

    --------------------------------------------------
    -- Native fallback: wire to Warcraft events
    --------------------------------------------------
    local function wireNative()
        local tDmg = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tDmg, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end
        TriggerAddAction(tDmg, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then return end
            local amt = GetEventDamage() or 0
            current = { source = src, target = tgt, amount = amt }
            emit("OnDealtDamage", { source = src, target = tgt, amount = amt })
        end)

        local tKill = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(tKill, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(tKill, function()
            local dead   = GetTriggerUnit()
            local killer = GetKillingUnit()
            if not ValidUnit(dead) then return end
            current = { source = killer, target = dead, amount = 0 }
            emit("OnKill", { source = killer, target = dead })
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    if OnInit and OnInit.final then
        OnInit.final(function()
            wireNative()
            local IB = rawget(_G, "InitBroker")
            if IB and IB.SystemReady then IB.SystemReady("DamageEngine") end
            print("[DamageEngine] ready (native fallback)")
        end)
    end
end

if Debug and Debug.endFile then Debug.endFile() end
