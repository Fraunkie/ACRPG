if Debug and Debug.beginFile then Debug.beginFile("Spell_SpiritVortex.lua") end
--==================================================
-- Spell_SpiritVortex.lua
-- Ability: A0SV
-- 1) First use -> spawn 6 orbs, start background cooldown
-- 2) While orbs > 0 -> fire one (ignores cooldown) but respects FIRE_GAP
-- 3) When orbs = 0:
--      - if cooldown ready -> respawn 6
--      - else -> show cooldown
--==================================================

Spell_SpiritVortex = Spell_SpiritVortex or {}
_G.Spell_SpiritVortex = Spell_SpiritVortex

do
    -- config
    local ABIL_ID_STR    = "A0SV"
    local ORB_UNIT_STR   = "e00N"
    local ORB_COUNT      = 6
    local ORB_RADIUS     = 180.0
    local ROTATE_DEG_S   = 180.0
    local TICK           = 0.03
    local COOLDOWN_SEC   = 20.0

    -- fire rate between shots
    local FIRE_GAP_SEC   = 0.25

    -- hit visual
    local HIT_FX_PATH    = "Abilities\\Spells\\Human\\Thunderclap\\ThunderClapTarget.mdl"
    local HIT_FX_SCALE   = 1.10

    -- firing
    local SEEK_RANGE     = 900.0
    local FIRE_SPEED     = 900.0
    local FIRE_MAX_TIME  = 1.60

    -- damage
    local BASE_DMG       = 25.0
    local PL_SCALE       = 0.20

    -- state
    -- S[pid] = { caster, orbs={ {unit,angle},... }, baseAngle, cooldownUntil, lastFireAt }
    local S = {}

    local function four(v)
        if type(v) == "string" then
            return FourCC(v)
        end
        return v
    end
    local ABIL_ID  = four(ABIL_ID_STR)
    local ORB_UNIT = four(ORB_UNIT_STR)

    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0
    end

    -- global time
    local gNow = 0.0
    do
        local tim = CreateTimer()
        TimerStart(tim, 0.10, true, function()
            gNow = gNow + 0.10
        end)
    end
    local function now()
        return gNow
    end

    local function getHero(pid)
        if _G.PlayerData and PlayerData[pid] and validUnit(PlayerData[pid].hero) then
            return PlayerData[pid].hero
        end
        if _G.PlayerHero and validUnit(PlayerHero[pid]) then
            return PlayerHero[pid]
        end
        return nil
    end

    local function getPowerLevel(pid)
        if _G.PlayerData and PlayerData[pid] and type(PlayerData[pid].powerLevel) == "number" then
            return PlayerData[pid].powerLevel
        end
        return 0
    end

    local function calcDamage(pid)
        local dmg = BASE_DMG + getPowerLevel(pid) * PL_SCALE
        if _G.PlayerData and PlayerData[pid]
        and PlayerData[pid].combat
        and type(PlayerData[pid].combat.spellBonusPct) == "number" then
            dmg = dmg * (1.0 + PlayerData[pid].combat.spellBonusPct)
        end
        return dmg
    end

    local function dealSpellDamage(caster, target, amount)
        if not validUnit(caster) or not validUnit(target) then return end
        if _G.DamageEngine and DamageEngine.applySpellDamage then
            DamageEngine.applySpellDamage(caster, target, amount)
        else
            UnitDamageTarget(
                caster, target, amount,
                false, false,
                ATTACK_TYPE_MAGIC,
                DAMAGE_TYPE_MAGIC,
                WEAPON_TYPE_NONE
            )
        end
    end

    local function playHitFx(target)
        if not validUnit(target) then return end
        local fx = AddSpecialEffectTarget(HIT_FX_PATH, target, "origin")
        BlzSetSpecialEffectScale(fx, HIT_FX_SCALE)
        DestroyEffect(fx)
    end

    local function ensureState(pid, caster)
        local st = S[pid]
        if not st then
            st = { caster = caster, orbs = {}, baseAngle = 0.0, cooldownUntil = 0.0, lastFireAt = 0.0 }
            S[pid] = st
        else
            st.caster = caster
            if st.lastFireAt == nil then
                st.lastFireAt = 0.0
            end
        end
        return st
    end

    local function clearOrbs(pid)
        local st = S[pid]
        if not st then return end
        for i = 1, #st.orbs do
            local data = st.orbs[i]
            if data and validUnit(data.unit) then
                RemoveUnit(data.unit)
            end
        end
        st.orbs = {}
    end

    local function spawnOrbs(pid, caster)
        local st = ensureState(pid, caster)
        clearOrbs(pid)
        st.baseAngle = 0.0

        local cx = GetUnitX(caster)
        local cy = GetUnitY(caster)
        local owner = GetOwningPlayer(caster)

        for i = 1, ORB_COUNT do
            local a   = (i - 1) * (360.0 / ORB_COUNT)
            local rad = a * 3.1415926 / 180.0
            local x   = cx + ORB_RADIUS * math.cos(rad)
            local y   = cy + ORB_RADIUS * math.sin(rad)

            local orb = CreateUnit(owner, ORB_UNIT, x, y, a)
            SetUnitPathing(orb, false)
            SetUnitInvulnerable(orb, true)

            st.orbs[#st.orbs + 1] = {
                unit  = orb,
                angle = a
            }
        end

        st.cooldownUntil = now() + COOLDOWN_SEC
        DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex spawned " .. tostring(ORB_COUNT) .. " orbs.")
    end

    local function nearestEnemyOf(caster, range)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local best = nil
        local bestD2 = range * range
        local g = CreateGroup()
        GroupEnumUnitsInRange(g, x, y, range, nil)
        while true do
            local u = FirstOfGroup(g)
            if not u then break end
            GroupRemoveUnit(g, u)
            if validUnit(u) and IsUnitAliveBJ(u) and IsPlayerEnemy(GetOwningPlayer(u), GetOwningPlayer(caster)) then
                local dx = GetUnitX(u) - x
                local dy = GetUnitY(u) - y
                local d2 = dx*dx + dy*dy
                if d2 < bestD2 then
                    bestD2 = d2
                    best = u
                end
            end
        end
        DestroyGroup(g)
        return best
    end

    local function fireOne(pid)
        local st = S[pid]
        if not st or #st.orbs == 0 then
            return false
        end
        local caster = st.caster
        if not validUnit(caster) then
            return false
        end

        -- fire gap check
        local tnow = now()
        if tnow - st.lastFireAt < FIRE_GAP_SEC then
            return false
        end

        local target = nearestEnemyOf(caster, SEEK_RANGE)
        if not target then
            DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex: no target.")
            return false
        end

        st.lastFireAt = tnow

        local data = st.orbs[#st.orbs]
        st.orbs[#st.orbs] = nil

        local orb = data.unit
        if not validUnit(orb) then
            return false
        end

        local px = GetUnitX(orb)
        local py = GetUnitY(orb)
        local life = 0.0
        local dmg = calcDamage(pid)

        local tim = CreateTimer()
        TimerStart(tim, TICK, true, function()
            life = life + TICK
            if not validUnit(target) or life > FIRE_MAX_TIME then
                if validUnit(orb) then
                    RemoveUnit(orb)
                end
                PauseTimer(tim)
                DestroyTimer(tim)
                return
            end

            local tx = GetUnitX(target)
            local ty = GetUnitY(target)
            local dx = tx - px
            local dy = ty - py
            local dist = SquareRoot(dx*dx + dy*dy)
            local step = FIRE_SPEED * TICK

            if dist <= step then
                dealSpellDamage(caster, target, dmg)
                playHitFx(target)
                if validUnit(orb) then
                    RemoveUnit(orb)
                end
                PauseTimer(tim)
                DestroyTimer(tim)
                return
            end

            local nx = px + dx / dist * step
            local ny = py + dy / dist * step
            px = nx
            py = ny
            SetUnitX(orb, nx)
            SetUnitY(orb, ny)
        end)

        return true
    end

    local driverStarted = false
    local function startDriver()
        if driverStarted then return end
        driverStarted = true

        local tim = CreateTimer()
        TimerStart(tim, TICK, true, function()
            for pid, st in pairs(S) do
                local caster = st.caster
                if validUnit(caster) and #st.orbs > 0 then
                    local cx = GetUnitX(caster)
                    local cy = GetUnitY(caster)

                    st.baseAngle = st.baseAngle + (ROTATE_DEG_S * TICK)
                    if st.baseAngle >= 360.0 then
                        st.baseAngle = st.baseAngle - 360.0
                    end

                    for i = 1, #st.orbs do
                        local data = st.orbs[i]
                        local a    = data.angle + st.baseAngle
                        local rad  = a * 3.1415926 / 180.0
                        local x    = cx + ORB_RADIUS * math.cos(rad)
                        local y    = cy + ORB_RADIUS * math.sin(rad)

                        if validUnit(data.unit) then
                            SetUnitX(data.unit, x)
                            SetUnitY(data.unit, y)
                        end
                    end
                end
            end
        end)
    end
    startDriver()

    function Spell_SpiritVortex.Cast(caster)
        if not validUnit(caster) then
            return false
        end
        local pid = GetPlayerId(GetOwningPlayer(caster))
        local st  = ensureState(pid, caster)
        local tnow = now()

        -- if we still have orbs, native cast should fire
        if #st.orbs > 0 then
            fireOne(pid)
            return true
        end

        -- no orbs -> check cd
        if tnow < (st.cooldownUntil or 0) then
            local remain = math.floor((st.cooldownUntil - tnow) + 0.5)
            DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex on cooldown " .. tostring(remain) .. "s")
            return false
        end

        spawnOrbs(pid, caster)
        return true
    end

    function Spell_SpiritVortex.Use(pid)
        local st   = S[pid]
        local tnow = now()

        if not st or not st.caster or not validUnit(st.caster) then
            local hero = getHero(pid)
            if hero then
                spawnOrbs(pid, hero)
            else
                DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex needs a hero.")
            end
            return
        end

        -- orbs available -> try to fire (will respect FIRE_GAP_SEC)
        if #st.orbs > 0 then
            local fired = fireOne(pid)
            if not fired then
                -- optional small message here, but can be silent
            end
            return
        end

        -- no orbs -> now cooldown matters
        if tnow >= (st.cooldownUntil or 0) then
            spawnOrbs(pid, st.caster)
        else
            local remain = math.floor((st.cooldownUntil - tnow) + 0.5)
            DisplayTextToPlayer(Player(pid), 0, 0, "Spirit Vortex on cooldown " .. tostring(remain) .. "s")
        end
    end

    OnInit.final(function()
        local trg = CreateTrigger()
        for i = 0, bj_MAX_PLAYERS - 1 do
            TriggerRegisterPlayerUnitEvent(trg, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        end
        TriggerAddAction(trg, function()
            local abil = GetSpellAbilityId()
            if abil == ABIL_ID then
                Spell_SpiritVortex.Cast(GetTriggerUnit())
            end
        end)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
