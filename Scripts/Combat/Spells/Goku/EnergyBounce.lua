if Debug and Debug.beginFile then Debug.beginFile("EnergyBounce.lua") end
--==================================================
-- Goku - Energy Bounce (unit-target, chains up to 3)
-- • Head unit chases targets with BlzSetUnitPosition
-- • Single-hit per target, never damages caster/allies
-- • Small "no-hit window" after launch to prevent self-tap
--==================================================

local M = {}
_G.EnergyBounce = M

-- CONFIG -------------------------------------------------------------
local ABIL_ID             = FourCC('A0EB')   -- your ability rawcode
local MAX_BOUNCES         = 3                -- total hits including first
local SEARCH_RADIUS       = 500.0
local SPEED               = 900.0            -- units/sec
local TICK                = 0.03
local NO_HIT_TIME         = 0.20             -- grace window after launch
local IMPACT_FX           = "Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl"
local TRAIL_PERIOD        = 0.06
local TRAIL_UNIT          = FourCC('e001')   -- trail puff unit
local HEAD_UNIT           = FourCC('e001')   -- projectile head model unit
local HEAD_SCALE          = 0.20
local HEAD_LIFETIME_GUARD = 3.5
local SPAWN_OFFSET        = 80.0             -- push the head out from caster so it doesn't spawn on top
local DEBUG_PRINT         = true
local DAMAGE_FALLOFF      = 0.15              -- Damage reduction per bounce (0.15 = 15 percent)

-- UTILS --------------------------------------------------------------
local function unitAlive(u)
    return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
end

local function dprint(msg)
    if DEBUG_PRINT then print("[EnergyBounce] " .. tostring(msg)) end
end

local function faceUnit(a, b)
    if not unitAlive(a) or not unitAlive(b) then return end
    local dx = GetUnitX(b) - GetUnitX(a)
    local dy = GetUnitY(b) - GetUnitY(a)
    SetUnitFacing(a, bj_RADTODEG * Atan2(dy, dx))
end

local function isEnemyOfPid(u, pid)
    return unitAlive(u) and IsUnitEnemy(u, Player(pid))
end

-- damage (prefer your DamageEngine "energy" path if present)
local function dealDamage(caster, target, amount)
    if not unitAlive(target) or amount <= 0 then return 0 end
    local before = GetWidgetLife(target)

    if DamageEngine and (DamageEngine.applyEnergyDamage or DamageEngine.applySpellDamage) then
        local ok = false
        if DamageEngine.applyEnergyDamage then
            ok = pcall(DamageEngine.applyEnergyDamage, caster, target, amount)
        elseif DamageEngine.applySpellDamage then
            ok = pcall(DamageEngine.applySpellDamage, caster, target, amount, DAMAGE_TYPE_MAGIC)
        end
        if not ok then
            UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
        end
    else
        UnitDamageTarget(caster, target, amount, false, false, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_NONE)
    end

    local after = GetWidgetLife(target)
    return math.max(0, before - after)
end

-- PROJECTILE STATE ---------------------------------------------------
-- s = { caster, pid, abil, lvl, head, target, hits, visited={}, bornT, lastTrail, noHitUntil }
local function newState(caster, target, abil)
    local pid   = GetPlayerId(GetOwningPlayer(caster))
    local cx,cy = GetUnitX(caster), GetUnitY(caster)
    local ang   = GetUnitFacing(caster) * bj_DEGTORAD
    local sx    = cx + math.cos(ang) * SPAWN_OFFSET
    local sy    = cy + math.sin(ang) * SPAWN_OFFSET

    local head = CreateUnit(GetOwningPlayer(caster), HEAD_UNIT, sx, sy, bj_RADTODEG*ang)
    UnitAddAbility(head, FourCC('Aloc'))
    SetUnitPathing(head, false)
    PauseUnit(head, false)
    SetUnitScale(head, HEAD_SCALE, HEAD_SCALE, HEAD_SCALE)

    return {
        caster  = caster,
        pid     = pid,
        abil    = abil,
        lvl     = GetUnitAbilityLevel(caster, abil),
        head    = head,
        target  = target,
        hits    = 0,
        visited = {},
        bornT   = 0.0,
        lastTrail = 0.0,
        noHitUntil = NO_HIT_TIME,  -- delay before any hit can register
    }
end

local function destroyState(s)
    if s and s.head and GetUnitTypeId(s.head) ~= 0 then
        RemoveUnit(s.head)
    end
end

-- Replace the debug helper functions
local function debugTarget(s, target, dmg)
    if not DEBUG_PRINT then return end
    local msg = "Hit " .. GetUnitName(target) .. " for " .. math.floor(dmg) .. 
                " damage [" .. s.hits .. "/" .. MAX_BOUNCES .. "]"
    dprint(msg)
end

local function debugBounce(from, to)
    if not DEBUG_PRINT then return end
    dprint("Bouncing from " .. GetUnitName(from) .. " to " .. GetUnitName(to))
end

-- next bounce (closest new enemy)
local function findNextBounce(fromUnit, casterPid, visited)
    local best, bestD2 = nil, 9e30
    local fx, fy = GetUnitX(fromUnit), GetUnitY(fromUnit)
    local g = CreateGroup()
    GroupEnumUnitsInRange(g, fx, fy, SEARCH_RADIUS, nil)
    
    ForGroup(g, function()
        local u = GetEnumUnit()
        -- Don't check visited here, do it in the state check
        if isEnemyOfPid(u, casterPid) then
            local dx, dy = GetUnitX(u)-fx, GetUnitY(u)-fy
            local d2 = dx*dx + dy*dy
            if d2 < bestD2 and not visited[GetHandleId(u)] then 
                bestD2, best = d2, u
            end
        end
    end)
    DestroyGroup(g)
    return best
end

-- TICKER -------------------------------------------------------------
local active, timer = {}, nil

local function stepMove(s, dt)
    -- Update timers
    s.noHitUntil = math.max(0, s.noHitUntil - dt)
    
    -- Guard checks
    if not unitAlive(s.head) or not unitAlive(s.caster) then 
        dprint("Head or caster died")
        return false 
    end

    -- Target validation and bouncing
    if not unitAlive(s.target) or not isEnemyOfPid(s.target, s.pid) then
        local newTarget = findNextBounce(s.head, s.pid, s.visited)
        if not newTarget then
            dprint("No valid targets found")
            return false
        end
        debugBounce(s.target, newTarget)
        s.target = newTarget
    end

    -- Movement
    local hx, hy = GetUnitX(s.head), GetUnitY(s.head)
    local tx, ty = GetUnitX(s.target), GetUnitY(s.target)
    local dx, dy = tx - hx, ty - hy
    local dist = SquareRoot(dx*dx + dy*dy)
    local step = SPEED * dt

    -- Not yet at target
    if dist > step then
        local nx = hx + dx*(step/dist)
        local ny = hy + dy*(step/dist)
        SetUnitPosition(s.head, nx, ny)
        
        -- Trail effect
        s.lastTrail = s.lastTrail + dt
        if s.lastTrail >= TRAIL_PERIOD then
            s.lastTrail = 0.0
            local puff = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), TRAIL_UNIT, nx, ny, 0)
            UnitApplyTimedLife(puff, FourCC('BTLF'), 0.40)
        end
        return true
    end

    -- Impact handling
    if s.noHitUntil <= 0 then
        -- Get base damage
        local baseDmg = SpellSystemInit and SpellSystemInit.GetDamageForSpell(s.pid, s.abil, s.lvl) or 100
        
        -- Apply falloff based on bounce count
        local falloffMultiplier = 1.0 - (DAMAGE_FALLOFF * s.hits)
        local dmg = baseDmg * falloffMultiplier
        
        -- Apply damage and show debug
        local applied = dealDamage(s.caster, s.target, dmg)
        debugTarget(s, s.target, applied)
        
        -- Visual feedback
        if FX and FX.play then
            FX.play(IMPACT_FX, { x = tx, y = ty })
        end

        -- Add debug message showing falloff
        if DEBUG_PRINT then
            dprint("Damage falloff: Hit " .. s.hits .. " reduced by " .. (DAMAGE_FALLOFF * s.hits * 100) .. " points")
        end

        -- Mark target as hit
        s.hits = s.hits + 1
        s.visited[GetHandleId(s.target)] = true

        -- Check for next bounce
        if s.hits < MAX_BOUNCES then
            local nextTarget = findNextBounce(s.target, s.pid, s.visited)
            if nextTarget then
                debugBounce(s.target, nextTarget)
                s.target = nextTarget
                return true
            end
        end
        dprint("Chain ended after " .. s.hits .. " hits")
        return false
    end

    return true
end

local function tick()
    if not timer then return end
    local i = 1
    while i <= #active do
        local s = active[i]
        if not s then
            table.remove(active, i)
        else
            s.bornT = s.bornT + TICK
            local alive = stepMove(s, TICK)
            if (not alive) or (s.bornT > HEAD_LIFETIME_GUARD) then
                destroyState(s)
                table.remove(active, i)
            else
                i = i + 1
            end
        end
    end
    if #active == 0 and timer then PauseTimer(timer) end
end

-- CAST HOOK ----------------------------------------------------------
local function onCast()
    if GetTriggerEventId() ~= EVENT_PLAYER_UNIT_SPELL_EFFECT then return end
    local caster = GetTriggerUnit()
    local abil   = GetSpellAbilityId()
    if abil ~= ABIL_ID then return end

    local target = GetSpellTargetUnit()
    if not target or not unitAlive(target) then return end

    -- Face target and spawn slightly in front so we never clip the caster
    faceUnit(caster, target)

    local s = newState(caster, target, abil)
    table.insert(active, s)

    if not timer then timer = CreateTimer() end
    TimerStart(timer, TICK, true, tick)
    dprint("Cast Energy Bounce")
end

local function hook()
    local t = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerUnitEvent(t, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
    end
    TriggerAddAction(t, onCast)
end

OnInit.final(function()
    hook()
    print("[EnergyBounce] Ready")
end)

if Debug and Debug.endFile then Debug.endFile() end
