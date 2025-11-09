if Debug then Debug.beginFile("Spell_EnergyBall.lua") end

do
    ----------------------------------------------------------------
    -- Global export (match exactly; same style as KiBlast)
    ----------------------------------------------------------------
    Spell_EnergyBall = Spell_EnergyBall or {}
    _G.Spell_EnergyBall = Spell_EnergyBall

    ----------------------------------------------------------------
    -- Config
    ----------------------------------------------------------------
    local ABIL_ID_STR   = "A0EB"
    local EFFECT_MODEL  = "az_dd021.mdx"
    local MAX_SPEED     = 1000
    local BASE_DAMAGE   = 50
    local MAX_RANGE     = 1200
    local BOUNCE_RANGE  = 600   -- search radius for next target
    local BOUNCES_MAX   = 2     -- # of extra hops after first hit
    local DAMAGE_FALLOFF= 0.85  -- -15% each hop

    -- state bucket (mirrors KiBlast)
    local S = {}

    ----------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and not IsUnitType(u, UNIT_TYPE_DEAD)
    end

    -- Find closest “unit” object around (x,y). Condition kept nil so we don’t
    -- accidentally call pair-only helpers during enumeration. Enemy filtering
    -- is enforced in the collision callback via ALICE_PairIsEnemy().
    local function getClosestUnit(x, y, cutoff)
        return ALICE_GetClosestObject(x, y, "unit", cutoff or BOUNCE_RANGE, nil)
    end

    ----------------------------------------------------------------
    -- Collision callback
    ----------------------------------------------------------------
    local function EnergyBallHit(self, hitUnit)
        local dist = ALICE_PairGetDistance3D()
        if Debug then
            print(("EnergyBall Distance: %.3f, Is Enemy: %s"):format(dist, tostring(ALICE_PairIsEnemy())))
        end
        if dist >= 150 then return end

        -- owner / caster unit
        local ownerPlayer = ALICE_GetOwner(self)               -- player
        local pid         = GetPlayerId(ownerPlayer)
        local casterUnit  = PlayerData.GetHero(pid)

        if not self or not hitUnit then return end

        if not ALICE_PairIsEnemy() then
            -- friendly -> ignore
            ALICE_PairDisable()
            return
        end

        if validUnit(hitUnit) and validUnit(casterUnit) then
            DamageEngine.applySpellDamage(casterUnit, hitUnit, self.damage or BASE_DAMAGE, DAMAGE_TYPE_MAGIC)
        end

        -- bounce logic
        if (self.bouncesRemaining or 0) > 0 then
            local nx = GetUnitX(hitUnit)
            local ny = GetUnitY(hitUnit)
            local nextTarget = getClosestUnit(nx, ny, BOUNCE_RANGE)

            if nextTarget and nextTarget ~= hitUnit then
                -- spawn a new ball from the current hit target toward the next one
                local nextDmg   = (self.damage or BASE_DAMAGE) * DAMAGE_FALLOFF
                local nextHops  = (self.bouncesRemaining or 0) - 1
                local nextBall  = EnergyBall.create(hitUnit, nextDmg, nextHops, nextTarget)
                -- done with this instance
                ALICE_Kill(self)
                return
            end
        end

        -- no more bounces
        ALICE_Kill(self)
    end

    ----------------------------------------------------------------
    -- Gizmo (actor) definition
    ----------------------------------------------------------------
    EnergyBall = {
        -- position/velocity
        x = nil, y = nil, z = 0,
        vx = nil, vy = nil, vz = 0,

        -- visuals
        visual = nil,
        visualZ = 150,

        -- ALICE identity & behavior
        identifier = "energyball",
        interactions = { unit = EnergyBallHit },
        selfInteractions = {
            CAT_Move3D,
            CAT_OutOfBoundsCheck },

        -- dynamics
        maxSpeed = MAX_SPEED,
        collisionRadius = 100,

        -- bookkeeping
        actorClass = "energyball",
        owner = nil,

        -- gameplay
        damage = BASE_DAMAGE,
        bouncesRemaining = 0,
    }

    local mt = { __index = EnergyBall }

    ----------------------------------------------------------------
    -- Create a ball.
    --   sourceUnit       : unit that spawns the ball
    --   damage           : number (optional)
    --   bouncesRemaining : integer (optional)
    --   forceTarget      : unit (optional) — aim toward this
    ----------------------------------------------------------------
    function EnergyBall.create(sourceUnit, damage, bouncesRemaining, forceTarget)
        if not validUnit(sourceUnit) then return nil end

        local self = setmetatable({}, mt)

        -- start at source
        self.x = GetUnitX(sourceUnit)
        self.y = GetUnitY(sourceUnit)
        self.z = GetTerrainZ(self.x, self.y)
        self.vz = 0

        -- aim
        local angleRad
        if forceTarget and validUnit(forceTarget) then
            local tx, ty = GetUnitX(forceTarget), GetUnitY(forceTarget)
            angleRad = math.atan2(ty - self.y, tx - self.x)
        else
            angleRad = GetUnitFacing(sourceUnit) * bj_DEGTORAD
        end

        self.vx = MAX_SPEED * math.cos(angleRad)
        self.vy = MAX_SPEED * math.sin(angleRad)

        -- visual effect
        self.visual = AddSpecialEffect(EFFECT_MODEL, self.x, self.y)
        BlzSetSpecialEffectPosition(self.visual, self.x, self.y, self.z + self.visualZ)
        BlzSetSpecialEffectScale(self.visual, 0.75)
        BlzSetSpecialEffectYaw(self.visual, angleRad)

        -- ownership
        self.owner = GetOwningPlayer(sourceUnit)

        -- gameplay payload
        self.damage           = damage or BASE_DAMAGE
        self.bouncesRemaining = math.max(0, bouncesRemaining or BOUNCES_MAX)

        -- register with ALICE
        ALICE_Create(self)

        -- (optional) keep the visual riding the actor’s z
        local function updateFx()
            BlzSetSpecialEffectPosition(self.visual, self.x, self.y, self.z + self.visualZ)
        end
        self.updateEffectPosition = updateFx

        return self
    end

    ----------------------------------------------------------------
    -- Cast API (same shape as KiBlast)
    ----------------------------------------------------------------
    function Spell_EnergyBall.Cast(caster)
        if not validUnit(caster) then return false end

        -- choose first target (closest enemy-ish unit near the caster’s spot).
        -- We let the collision callback enforce enemy strictly.
        local target = getClosestUnit(GetUnitX(caster), GetUnitY(caster), BOUNCE_RANGE)

        local ball = EnergyBall.create(caster, BASE_DAMAGE, BOUNCES_MAX, target)
        if not ball then return false end

        local pid = GetPlayerId(GetOwningPlayer(caster))
        S[pid] = S[pid] or {}
        table.insert(S[pid], ball)

        return true
    end

    function Spell_EnergyBall.Use(pid)
        local hero = PlayerData.GetHero(pid)
        if hero then
            return Spell_EnergyBall.Cast(hero)
        end
        return false
    end

    OnInit.final(function() end)
end

if Debug then Debug.endFile() end
