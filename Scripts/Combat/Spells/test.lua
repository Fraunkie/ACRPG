if Debug then Debug.beginFile("Spell_EnergyBounce.lua") end
--@@debug
do
    -- Configurations
    local ABIL_ID_STR = "A0CE"  -- Ability ID for Energy Bounce
    local EFFECT_MODEL = "az_dd021.mdx"  -- Model for the Energy Bounce visual effect
    local MAX_SPEED = 1000  -- Speed of the Energy Bounce
    local DAMAGE = 50       -- Damage dealt by the Energy Bounce
    local MAX_RANGE = 700  -- Max range for the Energy Bounce 
    local SEARCH_RANGE = 400  -- Range to search for next target (bounce)
    local MAX_BOUNCES = 3  -- Max number of bounces

    -- The state for active Energy Bounces
    Spell_EnergyBounce = Spell_EnergyBounce or {}
    _G.Spell_EnergyBounce = Spell_EnergyBounce
    local S = {}

    -- Helper function to convert strings to FourCC
    local function four(v)
        if type(v) == "string" then
            return FourCC(v)
        end
        return v
    end

    -- Function to validate if the unit is alive and valid
    local function validUnit(u)
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end

    -- Function to check if the unit is an enemy
    function enemycheck(caster, unit)
        local casterPlayer = GetOwningPlayer(caster)
        if IsUnitEnemy(unit, casterPlayer) then
            return true
        end
        return false
    end

    -- Ki Bounce hit detection and damage application
    function EnergyBounceHit(energyball, unit)
        local dist = ALICE_PairGetDistance3D()  -- Use 3D distance to properly handle vertical movement
        local data = ALICE_PairLoadData()
        
        -- Debugging: Print the distance and check if the target is an enemy or not
        if Debug then
            local isEnemy = ALICE_PairIsEnemy()  -- ALICE's function to check if they are enemies
            -- print("Energy Bounce Distance: " .. dist .. ", Is Enemy: " .. tostring(isEnemy))
        end

        -- If the distance is less than 150, check for interactions
        if dist < 150 then
            -- Get the player that owns the Energy Bounce (caster)
            local energyballOwnerPlayer = ALICE_GetOwner(energyball)  -- This gets the player who owns the EnergyBounce actor
            
            -- Get the player ID from the owner of the EnergyBounce actor
            local pid = GetPlayerId(energyballOwnerPlayer)

            -- Get the hero unit associated with the player (this is the unit to apply damage to)
            local energyballOwnerUnit = PlayerData.GetHero(pid)

            -- Get the owner of the unit (target)
            local unitOwner = ALICE_GetOwner(unit)

            -- Check if both energyball and unit are valid actors before proceeding
            if energyball and unit then  -- ALICE_PairIsDestroyed() check removed for simplicity
                -- Use ALICE_PairIsEnemy to determine if the unit is an enemy
                if not ALICE_PairIsEnemy() then
                    -- If it's not an enemy (friendly unit), disable the interaction to prevent friendly fire
                    print("Friendly fire, disabling interaction.")  -- Debugging: Log if friendly fire
                    ALICE_PairDisable()
                else
                    -- Apply damage if the target is an enemy
                    print("Hitting enemy: " .. GetUnitName(unit))  -- Debugging: Log if an enemy is hit

                    -- Ensure the unit is valid and alive before applying damage
                    if validUnit(unit) then
                        -- Apply damage to the unit using DamageEngine's applySpellDamage function
                        DamageEngine.applySpellDamage(energyballOwnerUnit, unit, DAMAGE, DAMAGE_TYPE_MAGIC)
                    else
                        -- Log if the unit is invalid or destroyed
                        print("Unit is invalid or destroyed, skipping damage.")
                    end

                    -- ------------ Start Bounce Logic (after damage and killing the ball)
                    -- Update bounce count and target
                    if not data.bounceCount then
                        data.bounceCount = 0
                    end
                    data.bounceCount = data.bounceCount + 1

                    -- Save position of the EnergyBall for the next bounce
                    local x, y, z = ALICE_GetCoordinates3D(energyball)
                    data.cords = {x = x, y = y, z = z}
                    ALICE_Kill(energyball)

                    -- Now call the function to handle the next bounce if needed
                    handleNextBounce(energyballOwnerUnit, data, x, y, z)
                end
            else
                print("Invalid actor detected, skipping interaction.")  -- Debugging: Log if an actor is destroyed or invalid
            end
        end
    end

    -- Function to handle the next bounce, creating new Energy Balls and finding the next valid target
    function handleNextBounce(energyballOwnerUnit, data, x, y, z)
        -- If bounce count is less than max, search for the next target
        if data.bounceCount < MAX_BOUNCES then
            local nextTarget = nil
            -- Find the closest enemy within range
            nextTarget = ALICE_GetClosestObject(x, y, "unit", SEARCH_RANGE, function(nextUnit)
                return enemycheck(energyballOwnerUnit, nextUnit)  -- Ensure it's an enemy
            end)

            -- If a valid target is found, create the next Energy Ball
            if nextTarget then
                print("Next target found: " .. GetUnitName(nextTarget))
                data.target = nextTarget  -- Update target for next bounce

                -- Create a new Energy Ball to the next target
                local nextEnergyball = EnergyBall.create(energyballOwnerUnit, nextTarget)
            end
        end

        -- After max bounces, destroy the EnergyBall
        if data.bounceCount >= MAX_BOUNCES then
            if Debug then print("Energy ball destroyed after max bounces.") end
        end
    end

    -- Energy Bounce Gizmo Class (Updated for 3D Movement)
    EnergyBall = {
        x = nil,
        y = nil,
        z = 0,   -- Set to 0 for base height (ground level)
        vx = nil,
        vy = nil,
        vz = 0,  -- No vertical movement (initially no vertical motion)
        speed = 1200,
        visual = nil,
        identifier = "energyball",
        interactions = {
            unit = EnergyBounceHit  -- Set the EnergyBounceHit function to handle unit interactions
        },
        selfInteractions = {
            CAT_MoveHoming3D,  -- 3D movement (not flat on the ground)
            CAT_OutOfBoundsCheck,  -- Check if the Energy Bounce is out of bounds
        },
        maxSpeed = MAX_SPEED,
        collisionRadius = 25,  -- Collision radius for the Energy Bounce
        actorClass = "energyball",
        owner = nil,  -- Add owner field to the gizmo
        visualZ = 150,  -- Set this for height above the ground (adjust based on visual needs)
        target = nil,  -- The target of the homing projectile
        bounce = 0,
    }

    local energyballMt = { __index = EnergyBall }

    -- Function to create the Energy Bounce
    function EnergyBall.create(caster, target)
        local new = {}
        setmetatable(new, energyballMt)

        -- Start position of the Energy Bounce (caster's position for the first ball)
        new.x = GetUnitX(caster)
        new.y = GetUnitY(caster)

        -- Get the caster's current Z position (height) from the terrain
        new.z = GetTerrainZ(new.x, new.y)  -- Set to the caster's terrain height
        new.vz = 0  -- No vertical movement (flat 3D)

        -- Get the target's coordinates
        new.target = target
        new.speed = 1200

        -- Create the visual effect for the Energy Bounce
        new.visual = AddSpecialEffect(EFFECT_MODEL, new.x, new.y)  -- Visual effect for the Energy Bounce

        -- Set the Z position of the visual effect to match the ball's height + an offset (visualZ)
        BlzSetSpecialEffectPosition(new.visual, new.x, new.y, new.z + new.visualZ)  -- Set the visual effect height with visualZ

        -- Adjust the scale of the visual effect to avoid overlap or large size
        BlzSetSpecialEffectScale(new.visual, 0.25)  -- Reduce the size by 75%

        -- Set the yaw of the visual effect to match the unit's facing direction
        local angle = GetUnitFacing(caster)
        BlzSetSpecialEffectYaw(new.visual, angle * bj_DEGTORAD)

        -- Assign the owner field to the caster's owner
        new.owner = GetOwningPlayer(caster)

        -- Add the gizmo to ALICE
        ALICE_Create(new)

        -- Return the newly created Energy Bounce gizmo
        return new
    end

    -- Handle casting the Energy Bounce
    function Spell_EnergyBounce.Cast(caster)
        -- Ensure the caster is valid
        if not validUnit(caster) then
            return false
        end

        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local enemyFound = false  -- Flag to check if an enemy is found in range
        local target = nil

        -- Use ALICE_GetClosestObject to find the closest enemy in range
        target = ALICE_GetClosestObject(x, y, "unit", MAX_RANGE, function(unit)
            return enemycheck(caster, unit)  -- Ensure it's an enemy
        end)

        -- If no enemies were found, do not create the Energy Bounce
        if not target then
            print("No enemies found in range. Energy Bounce will not be created.")
            return false
        end

        -- Create the Energy Bounce and fire it towards the target
        local energyball = EnergyBall.create(caster, target)

        -- Store the Energy Bounce in the active state
        local pid = GetPlayerId(GetOwningPlayer(caster))
        S[pid] = S[pid] or {}
        table.insert(S[pid], energyball)

        return true
    end

    -- Function to trigger the spell from CustomSpellBar
    function Spell_EnergyBounce.Use(pid)
        local hero = PlayerData.GetHero(pid)
        if hero then
            -- Call the cast function when the player activates the spell
            return Spell_EnergyBounce.Cast(hero)
        end
        return false
    end

    -- Initialize the runner for CustomSpellBar (this should already be defined)
    OnInit.final(function()        
    end)

end

if Debug then Debug.endFile() end
