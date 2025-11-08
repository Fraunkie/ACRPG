if Debug then Debug.beginFile("Spell_KiBlast.lua") end

do
    -- Configurations
    local ABIL_ID_STR = "A0CE"  -- Ability ID for Ki Blast (change this to your spell's ID)
    local EFFECT_MODEL = "Effect\\KiMissile.mdl"
    local MAX_SPEED = 1000  -- Speed of the Ki Blast
    local DAMAGE = 50       -- Damage dealt by the Ki Blast
    local MAX_RANGE = 1200  -- Max range for the Ki Blast

    Spell_KiBlast = Spell_KiBlast or {}
    _G.Spell_KiBlast = Spell_KiBlast
    -- State for active Ki Blasts
    local S = {}

    -- Helper function to convert strings to FourCC
    local function four(v)
        if type(v) == "string" then
            return FourCC(v)
        end
        return v
    end

    local function validUnit(u) 
        return u and GetUnitTypeId(u) ~= 0 and GetWidgetLife(u) > 0.405
    end

    -- Ki Blast hit detection and damage (using DamageEngine for proper spell damage application)
    function KiBlastHit(kiblast, unit)
        local dist = ALICE_PairGetDistance2D()

        -- Debugging: Print the distance and check if the target is an enemy or not
        if Debug then
            local isEnemy = ALICE_PairIsEnemy()  -- ALICE's function to check if they are enemies
            print("Ki Blast Distance: " .. dist .. ", Is Enemy: " .. tostring(isEnemy))
        end

        -- If the distance is less than 150, check for interactions
        if dist < 150 then
            -- Get the player that owns the KiBlast (caster)
            local kiblastOwnerPlayer = ALICE_GetOwner(kiblast)  -- This gets the player who owns the KiBlast actor
            
            -- Get the player ID from the owner of the KiBlast actor
            local pid = GetPlayerId(kiblastOwnerPlayer)

            -- Get the hero unit associated with the player (this is the unit to apply damage to)
            local kiblastOwnerUnit = PlayerData.GetHero(pid)

            -- Get the owner of the unit (target)
            local unitOwner = ALICE_GetOwner(unit)

            -- Check if both kiblast and unit are valid actors before proceeding
            if kiblast and unit then  -- ALICE_PairIsDestroyed() check removed for simplicity
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
                        DamageEngine.applySpellDamage(kiblastOwnerUnit, unit, DAMAGE, DAMAGE_TYPE_MAGIC)
                    else
                        -- Log if the unit is invalid or destroyed
                        print("Unit is invalid or destroyed, skipping damage.")
                    end

                    -- Kill the Ki Blast after hitting an enemy
                    ALICE_Kill(kiblast)
                end
            else
                print("Invalid actor detected, skipping interaction.")  -- Debugging: Log if an actor is destroyed or invalid
            end
        end
    end

    -- Ki Blast Gizmo Class
    KiBlast = {
        x = nil,
        y = nil,
        z = 0,   -- Set to 0 for base height (ground level)
        vx = nil,
        vy = nil,
        vz = 0,  -- No vertical movement
        visual = nil,
        --ALICE
        identifier = "kiblast",
        interactions = {
            unit = KiBlastHit  -- Set the KiBlastHit function to handle unit interactions
        },
        selfInteractions = {
            CAT_Move2D,  -- Use 2D movement (flat, on ground)
            CAT_OutOfBoundsCheck,  -- Check if the Ki Blast is out of bounds
        },
        maxSpeed = MAX_SPEED,
        collisionRadius = 100,  -- Collision radius for the Ki Blast
        actorClass = "kiblast",
        owner = nil,  -- Add owner field to the gizmo
        visualZ = 150  -- Set this for height above the ground (adjust based on visual needs)
    }

    local kiblastMt = { __index = KiBlast }

    function KiBlast.create(caster)
        local new = {}
        setmetatable(new, kiblastMt)
        new.x = GetUnitX(caster)  -- Start position of the Ki Blast (caster's position)
        new.y = GetUnitY(caster)
        new.z = 0  -- Set to 0 for base height (ground level)
        new.vz = 0  -- No vertical movement (flat 3D)

        local angle = GetUnitFacing(caster)  -- Direction the hero is facing
        new.vx = MAX_SPEED * math.cos(angle * bj_DEGTORAD)  -- Velocity in the X direction
        new.vy = MAX_SPEED * math.sin(angle * bj_DEGTORAD)  -- Velocity in the Y direction

        -- Create the visual effect for the Ki Blast
        new.visual = AddSpecialEffect(EFFECT_MODEL, new.x, new.y)  -- Visual effect for the Ki Blast
        BlzSetSpecialEffectPosition(new.visual, new.x, new.y, new.z + new.visualZ)  -- Set the visual effect height with visualZ
        BlzSetSpecialEffectScale(new.visual, 0.75)  -- Scale the visual effect

        -- Debugging: Log the Z position of the visual effect
        if Debug then
            print("KiBlast Visual Effect Z: " .. new.z + new.visualZ)
        end

        -- Set the yaw of the visual effect to match the unit's facing direction
        BlzSetSpecialEffectYaw(new.visual, angle * bj_DEGTORAD)

        -- Assign the owner field to the caster's owner
        new.owner = GetOwningPlayer(caster)

        -- Add the gizmo to ALICE
        ALICE_Create(new)

        -- Update the special effect position in 2D each frame (update position as the KiBlast moves)
        local function updateEffectPosition()
            -- Continuously update the visual effect's position with the gizmo's position
            BlzSetSpecialEffectPosition(new.visual, new.x, new.y, new.z + new.visualZ)
        end

        -- Call this every frame to update the special effect's position
        new.updateEffectPosition = updateEffectPosition

        -- Return the newly created KiBlast gizmo
        return new
    end

    -- Handle casting the Ki Blast
    function Spell_KiBlast.Cast(caster)
        -- Ensure the caster is valid
        if not validUnit(caster) then
            return false
        end

        -- Create the Ki Blast
        local kiblast = KiBlast.create(caster)

        -- Store the Ki Blast in the active state
        local pid = GetPlayerId(GetOwningPlayer(caster))
        S[pid] = S[pid] or {}
        table.insert(S[pid], kiblast)

        return true
    end

    -- Function to trigger the spell from CustomSpellBar
    function Spell_KiBlast.Use(pid)
        local hero = PlayerData.GetHero(pid)
        if hero then
            -- Call the cast function when the player activates the spell
            return Spell_KiBlast.Cast(hero)
        end
        return false
    end

    -- Initialize the runner for CustomSpellBar (this should already be defined)
    OnInit.final(function()        
    end)

end

if Debug then Debug.endFile() end
