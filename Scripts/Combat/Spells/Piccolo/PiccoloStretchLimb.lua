if Debug and Debug.beginFile then Debug.beginFile("Piccolo_StretchLimb.lua") end
--==================================================
-- Piccolo_StretchLimb.lua (A2PS) – Flipped Arm Test + Visible Hand
-- • Hand is a standalone SFX that follows the head each tick (so it always renders)
-- • Arm segments rotated 180° for tighter forward visual
--==================================================

do
    local ABIL_ID         = FourCC('A2PS')

    local MODEL_HAND      = "war3mapImported\\SlappyHand.mdx"   -- Will-2 hand
    local MODEL_ARM       = "war3mapImported\\SlappyArm.mdx"

    -- Tuning
    local RANGE           = 700.0
    local TICK            = 0.03
    local HAND_SPEED      = 2400.0
    local HAND_RADIUS     = 90.0

    local SEG_SPACING     = 20.0       -- keep your current feel; we flipped yaw to hide gaps
    local SEG_LIFE        = 0.50
    local HAND_SCALE      = 4.60
    local ARM_SCALE       = 2.80

    local PULL_SELF_ENEMY = 120.0
    local ALLY_STOP_DIST  = 100.0
    local ALLOW_ALLY_JUMP = true

    local DUMY_ID         = FourCC('DUMY')
    local PT_WALK         = PATHING_TYPE_WALKABILITY or ConvertPathingType(0)

    -- helpers
    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end
    local function pathable(x, y)
        return not IsTerrainPathable(x, y, PT_WALK)
    end
    local function norm(dx, dy)
        local len = SquareRoot(dx*dx + dy*dy)
        if len <= 0.0001 then return 1.0, 0.0, 0.0001 end
        return dx / len, dy / len, len
    end
    local function dist2(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return dx*dx + dy*dy
    end
    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    -- arm segments (flipped 180°)
    local function fx_segment_at(x, y, yaw)
        local fx = AddSpecialEffect(MODEL_ARM, x, y)
        if BlzSetSpecialEffectYaw   then BlzSetSpecialEffectYaw(fx, (yaw or 0.0) + bj_PI) end
        if BlzSetSpecialEffectScale then BlzSetSpecialEffectScale(fx, ARM_SCALE) end
        TimerStart(CreateTimer(), SEG_LIFE, false, function()
            DestroyEffect(fx)
            DestroyTimer(GetExpiredTimer())
        end)
    end

    -- hand as a movable SFX (not attached to DUMY)
    local function fx_hand_create(x, y, yaw)
        local fx = AddSpecialEffect(MODEL_HAND, x, y)
        if BlzSetSpecialEffectScale then BlzSetSpecialEffectScale(fx, HAND_SCALE) end
        if BlzSetSpecialEffectYaw   then BlzSetSpecialEffectYaw(fx, yaw or 0.0) end
        return fx
    end
    local function fx_hand_move(fx, x, y, yaw)
        if not fx then return end
        if BlzSetSpecialEffectPosition then
            BlzSetSpecialEffectPosition(fx, x, y, 0.0)
        else
            -- fallback: destroy+recreate if old patch (unlikely)
            -- but we assume Reforged natives are available
        end
        if BlzSetSpecialEffectYaw and yaw then
            BlzSetSpecialEffectYaw(fx, yaw)
        end
    end

    local function damageAmount(pid, level)
        if SpellSystemInit and SpellSystemInit.GetDamageForSpell then
            local v = SpellSystemInit.GetDamageForSpell(pid, ABIL_ID, level or 1, nil)
            if type(v) == "number" then return math.max(0, v) end
        end
        return 35.0
    end

    local function dealDamage(caster, target, amount)
        if amount <= 0 or not unitAlive(target) then return end
        if DamageEngine and DamageEngine.applySpellDamage then
            local ok = pcall(DamageEngine.applySpellDamage, caster, target, amount, DAMAGE_TYPE_MAGIC)
            if not ok then
                UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
            end
        else
            UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
        end
    end

    local function applyStun(target, baseDur, source, pid)
        if not unitAlive(target) or baseDur <= 0 then return end
        local dur = baseDur
        if _G.StatSystem and StatSystem.GetCrowdControlResist then
            local ok, ccr = pcall(StatSystem.GetCrowdControlResist, GetPlayerId(GetOwningPlayer(target)))
            if ok and type(ccr) == "number" then dur = dur * clamp(1.0 - ccr, 0.0, 1.0) end
        end
        if dur <= 0.01 then return end
        if ModifierSystem and ModifierSystem.Apply then
            ModifierSystem.Apply(target, "Stunned", { duration = dur, source = source, reason = "StretchLimb" })
        else
            PauseUnit(target, true)
            TimerStart(CreateTimer(), dur, false, function()
                if unitAlive(target) then PauseUnit(target, false) end
                DestroyTimer(GetExpiredTimer())
            end)
        end
    end

    local function moveOwnerSafe(u, dx, dy, maxDist)
        if maxDist <= 0 or not unitAlive(u) then return 0.0 end
        local dirX, dirY, len = norm(dx, dy)
        local remain = math.min(maxDist, len)
        local step = 24.0
        local moved = 0.0
        while remain > 0.0 do
            local take = math.min(step, remain)
            local nx = GetUnitX(u) + dirX * take
            local ny = GetUnitY(u) + dirY * take
            if pathable(nx, ny) then
                SetUnitPosition(u, nx, ny)
                moved = moved + take
                remain = remain - take
            else
                break
            end
        end
        return moved
    end

    local function tryStepPoint(x, y, dirX, dirY, want)
        local step = want
        while step >= 6.0 do
            local nx = x + dirX * step
            local ny = y + dirY * step
            if pathable(nx, ny) then
                return nx, ny, step
            end
            step = step * 0.5
        end
        return x, y, 0.0
    end

    local function laySegmentsBetween(ax, ay, bx, by)
        local dx, dy, len = norm(bx - ax, by - ay)
        if len < 1.0 then return end
        local yaw = Atan2(dy, dx)
        local t = 0.0
        while t + SEG_SPACING <= len do
            t = t + SEG_SPACING
            local px = ax + dx * t
            local py = ay + dy * t
            fx_segment_at(px, py, yaw)
        end
    end

    local function pullTowardUnit(caster, target, dist)
        if not unitAlive(caster) or not unitAlive(target) or dist <= 0 then return 0.0 end
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local tx, ty = GetUnitX(target), GetUnitY(target)
        local dx, dy = tx - cx, ty - cy
        return moveOwnerSafe(caster, dx, dy, dist)
    end

    -- collisions: prefer enemies, fallback to ally
    local function firstHitAround(x, y, pid, caster)
        local bestEnemy, bestEnemyD2 = nil, 9e30
        local bestAlly,  bestAllyD2  = nil, 9e30
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, x, y, HAND_RADIUS, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if unitAlive(u) and GetUnitTypeId(u) ~= DUMY_ID and u ~= caster then
                local d2 = dist2(x, y, GetUnitX(u), GetUnitY(u))
                if IsUnitEnemy(u, Player(pid)) then
                    if d2 < bestEnemyD2 then bestEnemy, bestEnemyD2 = u, d2 end
                elseif IsPlayerAlly(GetOwningPlayer(u), Player(pid)) then
                    if d2 < bestAllyD2 then bestAlly, bestAllyD2 = u, d2 end
                end
            end
        end)
        DestroyGroup(g)
        if bestEnemy then return bestEnemy, "enemy" end
        if ALLOW_ALLY_JUMP and bestAlly then return bestAlly, "ally" end
        return nil, nil
    end

    -- active casts
    local timer, casts = nil, {}

    local function destroyCast(s)
        if s.handFx then DestroyEffect(s.handFx) end
        if s.hand and GetUnitTypeId(s.hand) ~= 0 then RemoveUnit(s.hand) end
    end

    local function stepCast(s)
        if not unitAlive(s.caster) then return false end
        local targetX, targetY = GetUnitX(s.caster), GetUnitY(s.caster)
        local hx, hy = GetUnitX(s.hand), GetUnitY(s.hand)

        if s.phase == "out" then
            local step = HAND_SPEED * TICK
            local nx, ny, moved = tryStepPoint(hx, hy, s.dirX, s.dirY, step)
            if moved > 0.0 then
                SetUnitPosition(s.hand, nx, ny)
                laySegmentsBetween(s.prevX, s.prevY, nx, ny)
                s.traveled = s.traveled + moved
                s.prevX, s.prevY = nx, ny
                -- move hand sfx and face forward yaw
                local yaw = Atan2(s.dirY, s.dirX)
                fx_hand_move(s.handFx, nx, ny, yaw)
            end

            local hit, typ = firstHitAround(nx, ny, s.pid, s.caster)
            if hit then
                s.hitType, s.hitUnit = typ, hit
                if typ == "enemy" then
                    dealDamage(s.caster, hit, damageAmount(s.pid, s.level))
                    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(ABIL_ID)
                    local dur = (cfg and cfg.stunDur) or 0.75
                    applyStun(hit, dur, s.caster, s.pid)
                    local pull = (cfg and cfg.pullSelf) or PULL_SELF_ENEMY
                    pullTowardUnit(s.caster, hit, pull)
                else
                    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(ABIL_ID)
                    local stop = (cfg and cfg.allyStop) or ALLY_STOP_DIST
                    -- jump close to ally, no stun/dmg
                    local cx, cy = GetUnitX(s.caster), GetUnitY(s.caster)
                    local ax, ay = GetUnitX(hit), GetUnitY(hit)
                    local dx, dy, len = norm(ax - cx, ay - cy)
                    local want = math.max(0.0, len - stop)
                    moveOwnerSafe(s.caster, dx * want, dy * want, want)
                end
                s.phase = "retract"
            else
                if moved <= 0.0 or s.traveled >= RANGE then
                    s.phase = "retract"
                end
            end

        else
            -- retract toward caster
            local dx, dy = targetX - hx, targetY - hy
            local dirX, dirY, _ = norm(dx, dy)
            local step = HAND_SPEED * TICK
            local nx, ny, mv = tryStepPoint(hx, hy, dirX, dirY, step)
            if mv > 0.0 then
                SetUnitPosition(s.hand, nx, ny)
                laySegmentsBetween(hx, hy, nx, ny)
                -- face yaw toward caster while retracting
                local yaw = Atan2(dirY, dirX)
                fx_hand_move(s.handFx, nx, ny, yaw)
            end
            if dist2(nx, ny, targetX, targetY) <= (48.0 * 48.0) then
                return false
            end
        end

        return true
    end

    local function tick()
        local i = 1
        while i <= #casts do
            local s = casts[i]
            if not s then
                table.remove(casts, i)
            else
                local alive = stepCast(s)
                if not alive then
                    destroyCast(s)
                    table.remove(casts, i)
                else
                    i = i + 1
                end
            end
        end
        if #casts == 0 and timer then PauseTimer(timer) end
    end

    local function onCast(ctx)
        if ctx.abilityId ~= ABIL_ID then return end
        local caster = ctx.caster
        local pid    = GetPlayerId(GetOwningPlayer(caster))
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local facing = GetUnitFacing(caster) * bj_DEGTORAD
        local dirX, dirY = math.cos(facing), math.sin(facing)

        -- movable head (DUMY for pathing + scan)
        local hand = CreateUnit(GetOwningPlayer(caster), DUMY_ID, cx, cy, bj_RADTODEG * facing)
        UnitAddAbility(hand, FourCC('Aloc'))
        SetUnitPathing(hand, false); PauseUnit(hand, false); ShowUnit(hand, true)

        -- visible hand SFX (follows head)
        local yaw = Atan2(dirY, dirX)
        local fx = fx_hand_create(cx, cy, yaw)

        table.insert(casts, {
            caster=caster, pid=pid, level=ctx.level or 1,
            hand=hand, handFx=fx,
            dirX=dirX, dirY=dirY,
            prevX=cx, prevY=cy,
            traveled=0.0, phase="out"
        })

        if not timer then timer = CreateTimer() end
        TimerStart(timer, TICK, true, tick)
    end

    OnInit.final(function()
        if SpellEngine and SpellEngine.RegisterScripted then
            SpellEngine.RegisterScripted(ABIL_ID, onCast)
        else
            local t = CreateTrigger()
            for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
                TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
            end
            TriggerAddAction(t, function()
                if GetSpellAbilityId() == ABIL_ID then
                    onCast({
                        caster    = GetTriggerUnit(),
                        abilityId = ABIL_ID,
                        level     = GetUnitAbilityLevel(GetTriggerUnit(), ABIL_ID)
                    })
                end
            end)
        end
        print("[StretchLimb Flipped + Visible Hand] Ready")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
