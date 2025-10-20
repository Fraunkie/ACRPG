if Debug and Debug.beginFile then Debug.beginFile("DamageEngine.lua") end
--==================================================
-- DamageEngine.lua
-- Central lightweight adapter for Warcraft III damage events.
-- Fires BEFORE → AFTER → LETHAL phases.
-- Integrates DamageResolver for dodge/parry/block/crit/armor/energy resist.
--==================================================

if not DamageEngine then DamageEngine = {} end
_G.DamageEngine = DamageEngine

do
    --------------------------------------------------
    -- Event keys
    --------------------------------------------------
    DamageEngine.BEFORE = "BEFORE"
    DamageEngine.AFTER  = "AFTER"
    DamageEngine.LETHAL = "LETHAL"

    local subs = { BEFORE = {}, AFTER = {}, LETHAL = {} }
    local current = nil

    local function ValidUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    local function safeCall(fn)
        local ok, err = pcall(fn)
        if not ok then
            -- silent fail; avoids breaking combat loop
        end
    end

    local function has(name) return type(_G[name]) == "function" end

    --------------------------------------------------
    -- Build base damage context
    --------------------------------------------------
    local function buildContext(src, tgt, amt)
        local ctx = {
            source     = src,
            target     = tgt,
            amount     = (tonumber(amt or 0) or 0),
            prevLife   = GetWidgetLife(tgt) or 0,
            postLife   = nil,
            isAttack   = nil,
            damageType = nil,
            attackType = nil,
            weaponType = nil,
            result     = "HIT",
            isCrit     = false,
            isEnergy   = nil,
            isPhysical = nil,
        }

        if has("BlzGetEventIsAttack") then
            local ok, v = pcall(BlzGetEventIsAttack)
            if ok then ctx.isAttack = v end
        end
        if has("BlzGetEventDamageType") then
            local ok, v = pcall(BlzGetEventDamageType)
            if ok then ctx.damageType = v end
        end
        if has("BlzGetEventAttackType") then
            local ok, v = pcall(BlzGetEventAttackType)
            if ok then ctx.attackType = v end
        end
        if has("BlzGetEventWeaponType") then
            local ok, v = pcall(BlzGetEventWeaponType)
            if ok then ctx.weaponType = v end
        end
        return ctx
    end

    local function emitList(list)
        for i = 1, #list do
            local fn = list[i]
            if type(fn) == "function" then safeCall(fn) end
        end
    end

    --------------------------------------------------
    -- Public API
    --------------------------------------------------
    function DamageEngine.registerEvent(eventName, fn)
        if type(fn) ~= "function" then return end
        if subs[eventName] then
            subs[eventName][#subs[eventName] + 1] = fn
        end
    end

    function DamageEngine.getCurrentDamage() return current end

    --------------------------------------------------
    -- Wiring
    --------------------------------------------------
    local function wireDamage()
        local trg = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(trg, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        end

        TriggerAddAction(trg, function()
            local src = GetEventDamageSource()
            local tgt = GetTriggerUnit()
            if not ValidUnit(src) or not ValidUnit(tgt) then return end

            local amt = GetEventDamage() or 0
            if amt < 0 then amt = 0 end

            current = buildContext(src, tgt, amt)

            -- Apply resolver (dodge/block/parry/crit/mitigation)
            local R = rawget(_G, "DamageResolver")
            if R and R.Resolve then
                local out = R.Resolve(current)
                if out then
                    if out.amount ~= nil then current.amount = out.amount end
                    if out.result ~= nil then current.result = out.result end
                    if out.isCrit ~= nil then current.isCrit = out.isCrit and true or false end
                end
            end

            -- BEFORE immediately
            if #subs.BEFORE > 0 then emitList(subs.BEFORE) end

            -- AFTER / LETHAL after short delay
            if #subs.AFTER > 0 or #subs.LETHAL > 0 then
                local t = CreateTimer()
                TimerStart(t, 0.00, false, function()
                    if current and ValidUnit(current.target) then
                        current.postLife = GetWidgetLife(current.target) or 0
                    end

                    if #subs.AFTER > 0 then emitList(subs.AFTER) end
                    if #subs.LETHAL > 0 and current and current.postLife and current.postLife <= 0.405 then
                        emitList(subs.LETHAL)
                    end
                    DestroyTimer(t)
                end)
            end
        end)
    end

    local function wireDeath()
        local trg = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerUnitEvent(trg, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        end
        TriggerAddAction(trg, function()
            local dead = GetTriggerUnit()
            local killer = GetKillingUnit()
            if not ValidUnit(dead) then return end
            current = {
                source = killer,
                target = dead,
                amount = 0,
                prevLife = 0,
                postLife = 0,
                result = "HIT",
                isCrit = false,
                isEnergy = nil,
                isPhysical = nil,
            }
            if #subs.LETHAL > 0 then emitList(subs.LETHAL) end
        end)
    end

    --------------------------------------------------
    -- Init
    --------------------------------------------------
    OnInit.final(function()
        wireDamage()
        wireDeath()
        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("DamageEngine")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
