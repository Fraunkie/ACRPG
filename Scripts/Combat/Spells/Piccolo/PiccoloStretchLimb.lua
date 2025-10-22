if Debug and Debug.beginFile then Debug.beginFile("Piccolo_StretchLimb.lua") end
--==================================================
-- Piccolo_StretchLimb.lua  (A2PS)
-- Hand leads, arm links trail at fixed spacing (carry-over accurate).
-- On retract, links behind the hand are removed as the hand passes them.
-- Prioritizes enemies; ally-jump fallback (no stun on allies).
-- Low damage; uses SpellSystemInit if available. Stun via Modifier/StatSystem.
-- Pulls Piccolo slightly toward enemy on hit. Obeys pathing blockers.
--==================================================

do
    local ABIL_ID         = FourCC('A2PS')

    -- Models
    local MODEL_HAND      = "war3mapImported\\SlappyHand.mdx"
    local MODEL_ARM       = "war3mapImported\\SlappyArm.mdx"

    --==================  Tuning (VISUAL + GAMEPLAY)  ==================
    local RANGE           = 700.0
    local TICK            = 0.03
    local HAND_SPEED      = 2400.0
    local HAND_RADIUS     = 90.0            -- generous contact

    -- Keep your visual scale exactly as you had it:
    local HAND_SCALE      = 4.60            -- hand scale
    local ARM_SCALE       = 2.80            -- arm link scale

    -- Spacing fix:
    -- We place links at exact multiples of SEG_SPACING along the path,
    -- carrying leftover distance to the next tick so links stay "attached".
    local SEG_SPACING     = 26.0            -- tightened from 32 so links butt together
    local SEG_REMOVE_RADIUS = 22.0          -- removal threshold on retract
    -- (You can nudge ±2 if you want them tighter/looser without gaps.)

    -- Gameplay nudges
    local PULL_SELF_ENEMY = 120.0           -- small tug toward enemy on hit
    local ALLY_STOP_DIST  = 100.0
    local ALLOW_ALLY_JUMP = true
    --===============================================================

    local DEBUG_LOG       = false
    local function dprint(s) if DEBUG_LOG then print("[StretchLimb] " .. tostring(s)) end end

    -- Pathing
    local PT_WALK = PATHING_TYPE_WALKABILITY or ConvertPathingType(0)

    -- Helpers
    local function unitAlive(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end
    local function pathable(x, y)
        return not IsTerrainPathable(x, y, PT_WALK)
    end
    local function clamp(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end
    local function dist2(ax, ay, bx, by)
        local dx, dy = ax - bx, ay - by
        return dx*dx + dy*dy
    end
    local function norm(dx, dy)
        local len = SquareRoot(dx*dx + dy*dy)
        if len <= 0.0001 then return 1.0, 0.0, 0.0001 end
        return dx / len, dy / len, len
    end
    local function isNeutralPassive(p)
        return p == Player(PLAYER_NEUTRAL_PASSIVE)
    end
    local DUMY_ID = FourCC('DUMY')
    local function isDumyUnit(u) return GetUnitTypeId(u) == DUMY_ID end

    local function fx_segment(x, y, yaw)
        local fx = AddSpecialEffect(MODEL_ARM, x, y)
        if BlzSetSpecialEffectYaw   then BlzSetSpecialEffectYaw(fx, yaw or 0.0) end
        if BlzSetSpecialEffectScale then BlzSetSpecialEffectScale(fx, ARM_SCALE) end
        return fx
    end
    local function fx_hand_attach(u)
        local fx = AddSpecialEffectTarget(MODEL_HAND, u, "origin")
        if BlzSetSpecialEffectScale then BlzSetSpecialEffectScale(fx, HAND_SCALE) end
        return fx
    end

    local function damageAmount(pid, level)
        if _G.SpellSystemInit and SpellSystemInit.GetDamageForSpell then
            local v = SpellSystemInit.GetDamageForSpell(pid, ABIL_ID, level or 1, nil)
            if type(v) == "number" then return math.max(0, v) end
        end
        return 35.0 -- fallback
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
        if _G.StatSystem then
            if StatSystem.GetCrowdControlResist then
                local ok, ccr = pcall(StatSystem.GetCrowdControlResist, GetPlayerId(GetOwningPlayer(target)))
                if ok and type(ccr) == "number" then dur = dur * clamp(1.0 - ccr, 0.0, 1.0) end
            elseif StatSystem.GetCCR then
                local ok2, ccr2 = pcall(StatSystem.GetCCR, GetPlayerId(GetOwningPlayer(target)))
                if ok2 and type(ccr2) == "number" then dur = dur * clamp(1.0 - ccr2, 0.0, 1.0) end
            end
        end
        if dur <= 0.01 then return end

        if _G.Modifier and Modifier.Apply then
            pcall(Modifier.Apply, target, "Stunned", dur, { source = source, id = "StretchLimb" })
            return
        end

        PauseUnit(target, true)
        TimerStart(CreateTimer(), dur, false, function()
            if unitAlive(target) then PauseUnit(target, false) end
            DestroyTimer(GetExpiredTimer())
        end)
    end

    -- Move owner safely along vector up to maxDist, obeying blockers
    local function moveOwnerSafe(u, dx, dy, maxDist)
        if maxDist <= 0 or not unitAlive(u) then return 0.0 end
        local dirX, dirY, len = norm(dx, dy)
        local remain = math.min(maxDist, len)
        local step   = 24.0
        local moved  = 0.0
        while remain > 0.0 do
            local take = math.min(step, remain)
            local nx = GetUnitX(u) + dirX * take
            local ny = GetUnitY(u) + dirY * take
            if pathable(nx, ny) then
                SetUnitPosition(u, nx, ny)
                moved  = moved + take
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

    -- Prioritize enemies, ally fallback
    local function firstHitAround(x, y, pid, caster)
        local bestEnemy, bestEnemyD2 = nil, 9e30
        local bestAlly,  bestAllyD2  = nil, 9e30
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, x, y, HAND_RADIUS, nil)
        ForGroup(g, function()
            local u = GetEnumUnit()
            if unitAlive(u) and not isDumyUnit(u) and u ~= caster then
                if not isNeutralPassive(GetOwningPlayer(u)) then
                    local d2 = dist2(x, y, GetUnitX(u), GetUnitY(u))
                    if IsUnitEnemy(u, Player(pid)) then
                        if d2 < bestEnemyD2 then bestEnemy, bestEnemyD2 = u, d2 end
                    elseif IsPlayerAlly(GetOwningPlayer(u), Player(pid)) then
                        if d2 < bestAllyD2 then bestAlly, bestAllyD2 = u, d2 end
                    end
                end
            end
        end)
        DestroyGroup(g)
        if bestEnemy then return bestEnemy, "enemy" end
        if ALLOW_ALLY_JUMP and bestAlly then return bestAlly, "ally" end
        return nil, nil
    end

    -- Active state
    local timer = nil
    local casts = {}

    -- Per-cast:
    -- s = {
    --   caster, pid, level,
    --   hand, handFx, dirX, dirY, phase="out"|"retract",
    --   prevX, prevY, traveled, hitType, hitUnit,
    --   segs = { {fx,x,y}, ... }, segAccum, segIndex
    -- }
    local function newCast(caster)
        local pid   = GetPlayerId(GetOwningPlayer(caster))
        local cx, cy= GetUnitX(caster), GetUnitY(caster)
        local facing= GetUnitFacing(caster) * bj_DEGTORAD
        local dirX, dirY = math.cos(facing), math.sin(facing)

        local hand = CreateUnit(GetOwningPlayer(caster), DUMY_ID, cx, cy, bj_RADTODEG * facing)
        UnitAddAbility(hand, FourCC('Aloc'))
        SetUnitPathing(hand, false)
        PauseUnit(hand, false)
        ShowUnit(hand, true)

        local fx = fx_hand_attach(hand)

        return {
            caster   = caster,
            pid      = pid,
            level    = GetUnitAbilityLevel(caster, ABIL_ID),
            hand     = hand,
            handFx   = fx,
            dirX     = dirX,
            dirY     = dirY,
            prevX    = cx,
            prevY    = cy,
            traveled = 0.0,
            phase    = "out",
            hitType  = nil,
            hitUnit  = nil,
            segs     = {},
            segAccum = 0.0,  -- carry-over distance for exact spacing
            segIndex = 0,
        }
    end

    local function destroyCast(s)
        if s then
            if s.handFx then DestroyEffect(s.handFx) end
            if s.hand and GetUnitTypeId(s.hand) ~= 0 then RemoveUnit(s.hand) end
            if s.segs then
                for i = 1, #s.segs do
                    local k = s.segs[i]
                    if k and k.fx then DestroyEffect(k.fx) end
                end
            end
        end
    end

    -- Fixed-spacing placement along a segment [A->B] with accumulator
    local function laySegmentsProgress(s, ax, ay, bx, by)
        local dx, dy, len = norm(bx - ax, by - ay)
        if len <= 0.001 then return end
        local yaw = Atan2(dy, dx)

        local remain = len
        local offset = SEG_SPACING - s.segAccum  -- distance to the next placement
        -- place first one if we've accumulated enough from previous tick
        if s.segAccum > 0.0 and remain >= offset then
            local px = ax + dx * offset
            local py = ay + dy * offset
            local fx = fx_segment(px, py, yaw)
            table.insert(s.segs, { fx = fx, x = px, y = py })
            s.segIndex = #s.segs
            ax = px; ay = py
            remain = len - offset
            s.segAccum = 0.0
        end
        -- place full-spacing links
        while remain >= SEG_SPACING do
            ax = ax + dx * SEG_SPACING
            ay = ay + dy * SEG_SPACING
            local fx = fx_segment(ax, ay, yaw)
            table.insert(s.segs, { fx = fx, x = ax, y = ay })
            s.segIndex = #s.segs
            remain = remain - SEG_SPACING
        end
        -- store leftover distance toward the next link
        s.segAccum = remain
    end

    local function pullTowardUnit(caster, target, dist)
        if not unitAlive(caster) or not unitAlive(target) or dist <= 0 then return 0.0 end
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local tx, ty = GetUnitX(target), GetUnitY(target)
        local dx, dy = tx - cx, ty - cy
        return moveOwnerSafe(caster, dx, dy, dist)
    end
    local function jumpTowardUnitStopShort(caster, ally, stopDist)
        if not unitAlive(caster) or not unitAlive(ally) then return 0.0 end
        local cx, cy = GetUnitX(caster), GetUnitY(caster)
        local ax, ay = GetUnitX(ally), GetUnitY(ally)
        local dx, dy, len = norm(ax - cx, ay - cy)
        if len <= stopDist then return 0.0 end
        local want = len - stopDist
        return moveOwnerSafe(caster, dx * want, dy * want, want)
    end

    local function stepCast(s)
        if not unitAlive(s.caster) then return false end
        if not s.hand or GetUnitTypeId(s.hand) == 0 then return false end

        local targetX, targetY = GetUnitX(s.caster), GetUnitY(s.caster)
        local hx, hy = GetUnitX(s.hand), GetUnitY(s.hand)

        if s.phase == "out" then
            local step = HAND_SPEED * TICK
            local nx, ny, moved = tryStepPoint(hx, hy, s.dirX, s.dirY, step)
            if moved > 0.0 then
                SetUnitPosition(s.hand, nx, ny)
                s.traveled = s.traveled + moved
                -- fixed-spacing trail
                laySegmentsProgress(s, hx, hy, nx, ny)
            end

            local hit, typ = firstHitAround(nx, ny, s.pid, s.caster)
            if hit then
                s.hitType = typ
                s.hitUnit = hit

                if typ == "enemy" then
                    local amt = damageAmount(s.pid, s.level)
                    dealDamage(s.caster, hit, amt)
                    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(ABIL_ID)
                    local dur = (cfg and cfg.stunDur) or 0.75
                    applyStun(hit, dur, s.caster, s.pid)
                    local pull = (cfg and cfg.pullSelf) or PULL_SELF_ENEMY
                    pullTowardUnit(s.caster, hit, pull)
                else
                    local cfg = SpellSystemInit and SpellSystemInit.GetSpellConfig(ABIL_ID)
                    local stop = (cfg and cfg.allyStop) or ALLY_STOP_DIST
                    jumpTowardUnitStopShort(s.caster, hit, stop)
                end

                s.phase = "retract"
            else
                if moved <= 0.0 or s.traveled >= RANGE then
                    s.phase = "retract"
                end
            end

        else
            -- RETRACT
            local dx, dy = targetX - hx, targetY - hy
            local dirX, dirY, len = norm(dx, dy)
            local step = HAND_SPEED * TICK
            local nx, ny, mv = tryStepPoint(hx, hy, dirX, dirY, step)
            if mv > 0.0 then
                SetUnitPosition(s.hand, nx, ny)
            end

            -- Remove any links the hand has passed
            while s.segIndex >= 1 do
                local seg = s.segs[s.segIndex]
                if not seg then s.segIndex = s.segIndex - 1
                else
                    local d2 = dist2(nx, ny, seg.x, seg.y)
                    if d2 <= (SEG_REMOVE_RADIUS * SEG_REMOVE_RADIUS) then
                        DestroyEffect(seg.fx)
                        s.segs[s.segIndex] = nil
                        s.segIndex = s.segIndex - 1
                    else
                        break
                    end
                end
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
        local s = newCast(ctx.caster)
        table.insert(casts, s)
        if not timer then timer = CreateTimer() end
        TimerStart(timer, TICK, true, tick)
        dprint("Cast Stretch Limb")
    end

    OnInit.final(function()
        if _G.SpellEngine and SpellEngine.RegisterScripted then
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
        print("[StretchLimb] Ready (fixed-spacing links + clean retract)")
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
