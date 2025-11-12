if Debug then Debug.beginFile("Spell_EnergyBounce.lua") end

do
    -- Configurations
    local ABIL_ID_STR = "A0CE"  -- Ability ID for Energy Bounce
    local EFFECT_MODEL = "az_dd021.mdx"  -- Model for the Energy Bounce visual effect
    local MAX_SPEED = 1000  -- Speed of the Energy Bounce
    local DAMAGE = 50       -- Damage dealt by the Energy Bounce
    local MAX_RANGE = 1200  -- Max range for the Energy Bounce

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
    
    -- Check if the unit is an enemy of the caster
    if IsUnitEnemy(unit, casterPlayer) then
        print("Enemy Found: " .. GetUnitName(unit))  -- Display enemy name
        return true
    end
    return false
    end

    -- Ki Bounce hit detection and damage application
    function EnergyBounceHit(energyball, unit)
        local dist = ALICE_PairGetDistance3D()  -- Use 3D distance to properly handle vertical movement

        -- Debugging: Print the distance and check if the target is an enemy or not
        if Debug then
            local isEnemy = ALICE_PairIsEnemy()  -- ALICE's function to check if they are enemies
            -- print("Energy Bounce Distance: " .. dist .. ", Is Enemy: " .. tostring(isEnemy))
        end

        -- If the distance is less than 150, check for interactions
        if dist < 150 then
            -- Get the player that owns the EnergyBounce (caster)
            local energyballOwnerPlayer = ALICE_GetOwner(energyball)  -- This gets the player who owns the EnergyBounce actor
            
            -- Get the player ID from the owner of the EnergyBounce actor
            local pid = GetPlayerId(energyballOwnerPlayer)

            -- Get the hero unit associated with the player (this is the unit to apply damage to)
            local energyballOwnerUnit = PlayerData.GetHero(pid)

            -- Check if both energyball and unit are valid actors before proceeding
            if energyball and unit then
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

                    -- Kill the Energy Bounce after hitting an enemy
                    ALICE_Kill(energyball)
                end
            else
                print("Invalid actor detected, skipping interaction.")  -- Debugging: Log if an actor is destroyed or invalid
            end
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
        visual = nil,
        --ALICE
        identifier = "energyball",
        interactions = {
            unit = EnergyBounceHit  -- Set the EnergyBounceHit function to handle unit interactions
        },
        selfInteractions = {
            CAT_Move3D,  -- 3D movement (not flat on the ground)
            CAT_OutOfBoundsCheck,  -- Check if the Energy Bounce is out of bounds
        },
        maxSpeed = MAX_SPEED,
        collisionRadius = 100,  -- Collision radius for the Energy Bounce
        actorClass = "energyball",
        owner = nil,  -- Add owner field to the gizmo
        visualZ = 150  -- Set this for height above the ground (adjust based on visual needs)
    }

    local energyballMt = { __index = EnergyBall }

    function EnergyBall.create(caster, target)
        local new = {}
        setmetatable(new, energyballMt)

        -- Start position of the Energy Bounce (caster's position)
        new.x = GetUnitX(caster)
        new.y = GetUnitY(caster)
        
        -- Get the caster's current Z position (height) from the terrain
        new.z = GetTerrainZ(new.x, new.y)  -- Set to the caster's terrain height
        new.vz = 0  -- No vertical movement (flat 3D)

        -- Get the target's coordinates
        local tx = GetUnitX(target)
        local ty = GetUnitY(target)
        local tz = GetUnitZ(target)

        -- Calculate the direction vector from caster to target
        local dx = tx - new.x
        local dy = ty - new.y
        local dz = tz - new.z

        -- Normalize the direction vector
        local length = math.sqrt(dx*dx + dy*dy + dz*dz)
        local normX = dx / length
        local normY = dy / length
        local normZ = dz / length

        -- Set the velocity to move towards the enemy
        new.vx = normX * MAX_SPEED
        new.vy = normY * MAX_SPEED
        new.vz = normZ * MAX_SPEED

        -- Create the visual effect for the Energy Bounce
        new.visual = AddSpecialEffect(EFFECT_MODEL, new.x, new.y)  -- Visual effect for the Energy Bounce
        
        -- Set the Z position of the visual effect to match the caster's height + an offset (visualZ)
        BlzSetSpecialEffectPosition(new.visual, new.x, new.y, new.z + new.visualZ)  -- Set the visual effect height with visualZ
        
        -- Scale the visual effect (optional, adjust based on your preference)
        BlzSetSpecialEffectScale(new.visual, 0.75)
        
        -- Set the yaw of the visual effect to match the unit's facing direction
        local angle = GetUnitFacing(caster)
        BlzSetSpecialEffectYaw(new.visual, angle * bj_DEGTORAD)

        -- Assign the owner field to the caster's owner
        new.owner = GetOwningPlayer(caster)

        -- Add the gizmo to ALICE
        ALICE_Create(new)

        -- Update the special effect position in 3D each frame (update position as the Energy Bounce moves)
        local function updateEffectPosition()
            -- Continuously update the visual effect's position in 3D space (X, Y, Z)
            BlzSetSpecialEffectPosition(new.visual, new.x, new.y, new.z + new.visualZ)
        end

        -- Call this every frame to update the special effect's position
        new.updateEffectPosition = updateEffectPosition

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

        -- Use ALICE_EnumObjectsInRange to get all units in range and check for enemies
        ALICE_EnumObjectsInRange(x, y, 600, "unit", function(unit)
            if enemycheck(caster, unit) then
                target = unit  -- Store the enemy unit
                enemyFound = true  -- Mark that we found an enemy
            end
        end)

        -- If no enemies were found, do not create the Energy Bounce
        if not enemyFound then
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
