if Debug and Debug.beginFile then Debug.beginFile("SpellEngine.lua") end
--==================================================
-- Spell Engine (Unified) with charge/beam/ball
-- + Scripted-spell registry (for bespoke spells)
-- Uses SpellSystemInit.GetDamageForSpell
--==================================================

if not SpellEngine then SpellEngine = {} end
_G.SpellEngine = SpellEngine

----------------------------------------------------
-- Scripted spell registry
----------------------------------------------------
do
    local REG = {}  -- [abilityId:number] = function(ctx)

    -- ctx = {
    --   caster, abilityId, level, targetX, targetY,
    --   playerId, player, event (EVENT_* id)
    -- }
    function SpellEngine.RegisterScripted(abilityId, fn)
        if type(abilityId) == "number" and type(fn) == "function" then
            REG[abilityId] = fn
        end
    end

    function SpellEngine._GetScripted(abilityId)
        return REG[abilityId]
    end
end

-- CONFIG
local TICK_INTERVAL       = 0.03
local DEFAULT_SPEED       = 900.0
local DEFAULT_COLLIDE     = 120.0
local TRAIL_PERIOD        = 0.05
local TRAIL_LIFE          = 0.40
local MAX_TRADE_PER_TICK  = 10
local DEBUG               = true

local function dprint(msg)
    if DEBUG then
        print("|cff66ccff[SpellEngine]|r " .. tostring(msg))
    end
end

-- utils
local function unitAlive(u)
    return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
end
local function normDir(dx, dy)
    local len = SquareRoot(dx*dx + dy*dy)
    if len < 0.001 then return 0.001, 0.0 end
    return dx/len, dy/len
end
local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
local function safeNumber(x, fallback)
    if type(x) ~= "number" then return fallback end
    if x ~= x then return fallback end
    if x == math.huge or x == -math.huge then return fallback end
    return x
end

-- easing for charge visuals
local CHARGE_EASE_POW = 1.30
local function easePow01(x, pow)
    if x <= 0 then return 0 end
    if x >= 1 then return 1 end
    return x ^ (pow or 1.0)
end

local function ownerFloatText(u, txt, r, g, b)
    local p = GetOwningPlayer(u)
    if GetLocalPlayer() ~= p then return end
    local t = CreateTextTag()
    SetTextTagText(t, txt, 0.023)
    SetTextTagPosUnit(t, u, 50)
    SetTextTagColor(t, r or 255, g or 255, b or 255, 255)
    SetTextTagVelocity(t, 0.00, 0.03)
    SetTextTagLifespan(t, 0.8)
    SetTextTagFadepoint(t, 0.55)
end

-- active projectiles
-- entry: {head, owner, allyId, mana, maxMana, dirX, dirY, speed, collide,
--         type, range, travel, trailId, lastTrailT, hitFx, dead, spellKey, lvl}
local heads = {}

-- charge state (pre-launch)
local charges = {}
local function key(u) return GetHandleId(u) end

-- damage routing
local function dealSpellDamage(caster, target, amount)
    if amount <= 0 then return end
    if DamageEngine and DamageEngine.applySpellDamage then
        DamageEngine.applySpellDamage(caster, target, amount, DAMAGE_TYPE_MAGIC)
    else
        if not WEAPON_TYPE_WHOKNOWS then WEAPON_TYPE_WHOKNOWS = 0 end
        UnitDamageTarget(caster, target, amount, false, false,
            ATTACK_TYPE_NORMAL, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
    end
end

-- visuals
local function dropTrail(entry, fxUnitId)
    local x = GetUnitX(entry.head)
    local y = GetUnitY(entry.head)
    local u = CreateUnit(Player(entry.allyId), fxUnitId, x, y, 0)
    UnitApplyTimedLife(u, FourCC('BTLF'), TRAIL_LIFE)
    SetUnitVertexColor(u, 255, 255, 255, 200)
end
local function explodeAt(x, y, model)
    local fx = AddSpecialEffect(model or "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl", x, y)
    DestroyEffect(fx)
end

-- create and register projectile head
local function createHead(caster, spellKey, lvl, tx, ty, powerMult, preHead, collideOverride, speedOverride)
    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(spellKey)
    if not cfg then return end

    local cx, cy = GetUnitX(caster), GetUnitY(caster)
    local dx, dy = tx - cx, ty - cy
    local dirX, dirY = normDir(dx, dy)

    local headId   = cfg.projectileUnit or FourCC('e001')
    local trailId  = cfg.trailUnit     or FourCC('e001')
    local speed    = speedOverride or cfg.speed or DEFAULT_SPEED
    local collide  = collideOverride or cfg.collision or DEFAULT_COLLIDE
    local range    = cfg.range or 1200.0
    local typ      = cfg.type or "beam"

    local manaInit = cfg.mana or 0
    if manaInit <= 0 then
        manaInit = math.max(25, GetUnitState(caster, UNIT_STATE_MANA) or 0)
    end
    if powerMult and powerMult > 0 then
        manaInit = manaInit * powerMult
    end

    manaInit = safeNumber(manaInit, 25)
    if manaInit < 1 then manaInit = 1 end
    manaInit = math.floor(manaInit + 0.5)

    local head = preHead
    if not head then
        head = CreateUnit(GetOwningPlayer(caster), headId, cx, cy, Atan2(dy, dx) * bj_RADTODEG)
    end
    if BlzSetUnitMaxMana then BlzSetUnitMaxMana(head, manaInit) end
    SetUnitState(head, UNIT_STATE_MANA, manaInit)
    PauseUnit(head, false)
    SetUnitPathing(head, false)

    local entry = {
        head       = head,
        owner      = caster,
        allyId     = GetPlayerId(GetOwningPlayer(caster)),
        spellKey   = spellKey,
        lvl        = lvl or 1,
        type       = typ,
        range      = range,
        travel     = 0.0,
        mana       = manaInit,
        maxMana    = manaInit,
        dirX       = dirX,
        dirY       = dirY,
        speed      = speed,
        collide    = collide,
        trailId    = trailId,
        lastTrailT = 0.0,
        hitFx      = cfg.hitModel or "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl",
        dead       = false
    }
    table.insert(heads, entry)
    dprint("Head launched typ=" .. typ .. " mana=" .. tostring(manaInit) .. " collide=" .. tostring(collide))
end

-- expose for scripted spells that want engine projectile helpers
SpellEngine._CreateHead = createHead
SpellEngine._DealSpellDamage = dealSpellDamage
SpellEngine._UnitAlive = unitAlive
SpellEngine._Clamp = clamp
SpellEngine._DEFAULT_COLLIDE = DEFAULT_COLLIDE
SpellEngine._DEFAULT_SPEED = DEFAULT_SPEED

-- head vs head trading
local function headsCollide(a, b)
    if a.dead or b.dead then return end
    if a.allyId == b.allyId then return end
    local ax, ay = GetUnitX(a.head), GetUnitY(a.head)
    local bx, by = GetUnitX(b.head), GetUnitY(b.head)
    local dx, dy = ax - bx, ay - by
    local rr = a.collide + b.collide
    if dx*dx + dy*dy <= rr*rr then
        local trade = math.min(a.mana, b.mana, MAX_TRADE_PER_TICK)
        if trade > 0 then
            a.mana = a.mana - trade
            b.mana = b.mana - trade
            SetUnitState(a.head, UNIT_STATE_MANA, math.max(0, a.mana))
            SetUnitState(b.head, UNIT_STATE_MANA, math.max(0, b.mana))
            local mx = (ax + bx) * 0.5
            local my = (ay + by) * 0.5
            local fx = AddSpecialEffect("Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl", mx, my)
            DestroyEffect(fx)
            if a.mana <= 0.0 then a.dead = true end
            if b.mana <= 0.0 then b.dead = true end
        end
    end
end

-- head vs units
local function consumeUnitsInContact(e)
    local x, y = GetUnitX(e.head), GetUnitY(e.head)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, x, y, e.collide, nil)
    ForGroup(g, function()
        if e.dead or e.mana <= 0.0 then return end
        local u = GetEnumUnit()
        if IsUnitEnemy(u, Player(e.allyId)) and unitAlive(u) then
            local lifeBefore = GetWidgetLife(u)
            if lifeBefore > 0.405 then
                -- Damage equals "mana traded" per contact tick
                local planned = math.min(e.mana, lifeBefore)
                dealSpellDamage(e.owner, u, planned)
                local lifeAfter = GetWidgetLife(u)
                local actual = math.max(0.0, lifeBefore - lifeAfter)
                e.mana = math.max(0.0, e.mana - actual)
                SetUnitState(e.head, UNIT_STATE_MANA, e.mana)
                if e.mana <= 0.0 then
                    e.dead = true
                end
            end
        end
    end)
    DestroyGroup(g)
end

-- explosion (on range end or mana zero)
local function explodeEntry(e, reason)
    local x, y = GetUnitX(e.head), GetUnitY(e.head)
    explodeAt(x, y, e.hitFx)

    local cfg     = SpellSystemInit and SpellSystemInit.GetSpellConfig(e.spellKey)
    local aoe     = (cfg and cfg.aoeRange) or (e.collide * 1.5)
    local base    = 0
    if SpellSystemInit and SpellSystemInit.GetDamageForSpell then
        base = SpellSystemInit.GetDamageForSpell(e.allyId, e.spellKey, e.lvl, nil) or 0
    end

    local mult = 1.0
    if reason == "range" then
        local frac = 0.0
        if e.maxMana and e.maxMana > 0 then
            frac = clamp(e.mana / e.maxMana, 0.0, 1.0)
        end
        mult = 1.0 + 0.5 * frac
    elseif reason == "mana0" then
        mult = 0.6
    else
        mult = 1.0
    end
    mult = clamp(mult, 0.4, 2.0)
    local dmg = base * mult

    if aoe and aoe > 0 and dmg and dmg > 0 then
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, x, y, aoe, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if IsUnitEnemy(u, Player(e.allyId)) and unitAlive(u) then
                dealSpellDamage(e.owner, u, dmg)
            end
        end)
        DestroyGroup(g)
    end

    e.dead = true
end

-- tick
local function tick()
    -- charge updates
    for hid, c in pairs(charges) do
        if c and unitAlive(c.caster) then
            c.elapsed = c.elapsed + TICK_INTERVAL

            local fRaw = clamp(c.elapsed / math.max(0.01, c.maxTime), 0.0, 1.0)
            local fVis = easePow01(fRaw, CHARGE_EASE_POW)

            local cx, cy = GetUnitX(c.caster), GetUnitY(c.caster)
            local facing = GetUnitFacing(c.caster) * bj_DEGTORAD
            local ox = c.holdOffsetX * math.cos(facing) - c.holdOffsetY * math.sin(facing)
            local oy = c.holdOffsetX * math.sin(facing) + c.holdOffsetY * math.cos(facing)
            SetUnitX(c.head, cx + ox)
            SetUnitY(c.head, cy + oy)

            local sc = c.sizeFrom + (c.sizeTo - c.sizeFrom) * fVis
            SetUnitScale(c.head, sc, sc, sc)
            c.collideNow = c.baseCollide * sc

            if c.stages and FX and FX.timeline then
                FX.timeline(c.stages, { unit=c.caster, localTo=GetOwningPlayer(c.caster) }, fRaw, c.rawF or 0)
            end

            c.lastUi = c.lastUi + TICK_INTERVAL
            if c.lastUi >= 0.25 then
                c.lastUi = 0.0
                ownerFloatText(c.caster, "|cffffdd55" .. tostring(math.floor(fRaw * 100 + 0.5)) .. "%|r")
            end

            c.rawF = fRaw
            c.easedF = fVis
        else
            if c and c.head and GetUnitTypeId(c.head) ~= 0 then
                RemoveUnit(c.head)
            end
            charges[hid] = nil
        end
    end

    -- flight move
    for i = 1, #heads do
        local e = heads[i]
        if not e.dead and unitAlive(e.head) and unitAlive(e.owner) then
            local step = e.speed * TICK_INTERVAL
            local nx = GetUnitX(e.head) + e.dirX * step
            local ny = GetUnitY(e.head) + e.dirY * step
            SetUnitX(e.head, nx)
            SetUnitY(e.head, ny)
            e.travel = e.travel + step

            if e.type == "beam" then
                e.lastTrailT = e.lastTrailT + TICK_INTERVAL
                if e.lastTrailT >= TRAIL_PERIOD then
                    e.lastTrailT = 0.0
                    dropTrail(e, e.trailId)
                end
            end
        else
            if e and not e.dead then e.dead = true end
        end
    end

    -- head vs head
    for i = 1, #heads do
        local a = heads[i]
        if a and not a.dead then
            for j = i + 1, #heads do
                local b = heads[j]
                if b and not b.dead then
                    headsCollide(a, b)
                end
            end
        end
    end

    -- head vs units and end
    for i = 1, #heads do
        local e = heads[i]
        if e and not e.dead and unitAlive(e.head) and unitAlive(e.owner) then
            consumeUnitsInContact(e)
            if not e.dead and e.travel >= e.range then
                explodeEntry(e, "range")
            elseif not e.dead and e.mana <= 0.0 then
                explodeEntry(e, "mana0")
            end
        end
    end

    -- cleanup
    local k = 1
    while k <= #heads do
        local e = heads[k]
        if not e or e.dead or not unitAlive(e.head) then
            if e and unitAlive(e.head) then RemoveUnit(e.head) end
            table.remove(heads, k)
        else
            k = k + 1
        end
    end
end

-- charge api
function SpellEngine.StartBallCharge(caster, spellKey, aimX, aimY)
    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(spellKey)
    if not cfg or not cfg.charge or not cfg.charge.enabled then return end
    if not cfg.charge.headGrow then return end

    local hid = key(caster)
    if charges[hid] then return end

    local headId = cfg.projectileUnit or FourCC('e001')
    local head = CreateUnit(GetOwningPlayer(caster), headId, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster))
    UnitAddAbility(head, FourCC('Aloc'))
    PauseUnit(head, true)
    SetUnitPathing(head, false)

    local c = {
        caster = caster,
        spellKey = spellKey,
        head = head,
        elapsed = 0.0,
        maxTime = cfg.charge.maxTime or 3.0,
        sizeFrom = cfg.charge.sizeFrom or 1.0,
        sizeTo   = cfg.charge.sizeTo or 2.0,
        baseCollide = cfg.collision or DEFAULT_COLLIDE,
        collideNow  = cfg.collision or DEFAULT_COLLIDE,
        stages   = cfg.charge.stages,
        lastF    = 0.0,
        aimX = aimX, aimY = aimY,
        holdOffsetX = (cfg.ball and cfg.ball.holdOffset and cfg.ball.holdOffset.x) or 50.0,
        holdOffsetY = (cfg.ball and cfg.ball.holdOffset and cfg.ball.holdOffset.y) or 0.0,
        lastUi = 0.0,
        rawF = 0.0,
        easedF = 0.0,
    }
    SetUnitScale(head, c.sizeFrom, c.sizeFrom, c.sizeFrom)
    SetUnitAnimation(caster, "channel")
    charges[hid] = c

    dprint("StartBallCharge head created for " .. (cfg.name or "spell"))
end

function SpellEngine.ReleaseBallCharge(caster)
    local hid = key(caster)
    local c = charges[hid]
    if not c then return end
    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(c.spellKey)
    if not cfg then charges[hid] = nil return end

    local fRaw  = clamp(c.elapsed / math.max(0.01, c.maxTime), 0.0, 1.0)

    local multFrom   = (cfg.charge and cfg.charge.multFrom) or 0.6
    local multTo     = (cfg.charge and cfg.charge.multTo) or 2.5
    local speedBoost = (cfg.charge and cfg.charge.speedBoost) or 0.0

    local powerMult = multFrom + (multTo - multFrom) * fRaw
    local speedMul  = 1.0 + speedBoost * fRaw

    SetUnitAnimation(c.caster, "attack slam")
    if FX and FX.play then
        FX.play("LAUNCH_FLASH", { unit=c.caster, localTo=GetOwningPlayer(c.caster) })
    end

    local tx = c.aimX or (GetUnitX(c.caster) + math.cos(GetUnitFacing(c.caster) * bj_DEGTORAD) * (cfg.range or 900.0))
    local ty = c.aimY or (GetUnitY(c.caster) + math.sin(GetUnitFacing(c.caster) * bj_DEGTORAD) * (cfg.range or 900.0))

    local speed = (cfg.speed or DEFAULT_SPEED) * speedMul
    createHead(c.caster, c.spellKey, GetUnitAbilityLevel(c.caster, c.spellKey), tx, ty, powerMult, c.head, c.collideNow, speed)

    charges[hid] = nil
end

function SpellEngine.CancelBallCharge(caster, reason)
    local hid = key(caster)
    local c = charges[hid]
    if not c then return end
    if c.head and GetUnitTypeId(c.head) ~= 0 then
        RemoveUnit(c.head)
    end
    SetUnitAnimation(caster, "stand")
    charges[hid] = nil
    dprint("Charge canceled reason=" .. tostring(reason))
end

-- back compat helpers
function SpellEngine.CastHeadAt(caster, spellKey, tx, ty, level)
    createHead(caster, spellKey, level or 1, tx, ty)
end
function SpellEngine.CastBeamAt(caster, spellKey, tx, ty, level)
    createHead(caster, spellKey, level or 1, tx, ty)
end
function SpellEngine.ClearAllHeads()
    for i = 1, #heads do
        local e = heads[i]
        if e.head and GetUnitTypeId(e.head) ~= 0 then RemoveUnit(e.head) end
    end
    for i = #heads, 1, -1 do table.remove(heads, i) end
    print("|cff66ccff[SpellEngine]|r cleared all active heads.")
end
function SpellEngine.ClearAllBeams() SpellEngine.ClearAllHeads() end

-- event hooks
local function hookCasts()
    local trig = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerUnitEvent(trig, Player(i), EVENT_PLAYER_UNIT_SPELL_CHANNEL, nil)
        TriggerRegisterPlayerUnitEvent(trig, Player(i), EVENT_PLAYER_UNIT_SPELL_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(trig, Player(i), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        TriggerRegisterPlayerUnitEvent(trig, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
    end
    TriggerAddAction(trig, function()
        local ev  = GetTriggerEventId()
        local u   = GetTriggerUnit()
        local id  = GetSpellAbilityId()
        local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(id)

        -- If a scripted spell is registered for this ability, hand it control
        local scripted = SpellEngine._GetScripted(id)
        if scripted and ev == EVENT_PLAYER_UNIT_SPELL_EFFECT then
            local ctx = {
                caster   = u,
                abilityId= id,
                level    = GetUnitAbilityLevel(u, id),
                targetX  = GetSpellTargetX(),
                targetY  = GetSpellTargetY(),
                playerId = GetPlayerId(GetOwningPlayer(u)),
                player   = GetOwningPlayer(u),
                event    = ev,
            }
            local ok, err = pcall(scripted, ctx)
            if not ok then
                print("|cffff5555[SpellEngine]|r scripted spell error: " .. tostring(err))
            end
            return
        end

        if not cfg then return end

        if ev == EVENT_PLAYER_UNIT_SPELL_CHANNEL then
            if cfg.type == "ball" and cfg.charge and cfg.charge.enabled and cfg.charge.headGrow then
                SpellEngine.StartBallCharge(u, id, GetSpellTargetX(), GetSpellTargetY())
                dprint("CHANNEL start for ball charge " .. (cfg.name or "spell"))
            end

        elseif ev == EVENT_PLAYER_UNIT_SPELL_FINISH then
            if cfg.type == "ball" and cfg.charge and cfg.charge.enabled and cfg.charge.headGrow then
                SpellEngine.ReleaseBallCharge(u)
                dprint("FINISH release for ball charge " .. (cfg.name or "spell"))
                return
            end

        elseif ev == EVENT_PLAYER_UNIT_SPELL_ENDCAST then
            if cfg.type == "ball" and cfg.charge and cfg.charge.enabled and cfg.charge.headGrow then
                SpellEngine.CancelBallCharge(u, "endcast")
            end

        elseif ev == EVENT_PLAYER_UNIT_SPELL_EFFECT then
            -- Beams/balls handled here (non-charging)
            if not (cfg.type == "ball" and cfg.charge and cfg.charge.enabled and cfg.charge.headGrow) then
                local lvl = GetUnitAbilityLevel(u, id)
                local tx, ty = GetSpellTargetX(), GetSpellTargetY()
                dprint("Cast " .. (cfg.name or "spell"))
                createHead(u, id, lvl, tx, ty)
            end
        end
    end)
end

OnInit.final(function()
    dprint("Initializing...")
    local t = CreateTimer()
    TimerStart(t, TICK_INTERVAL, true, tick)
    hookCasts()
    dprint("Ready.")
end)

if Debug and Debug.endFile then Debug.endFile() end
