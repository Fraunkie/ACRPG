if Debug and Debug.beginFile then Debug.beginFile("PhantomEchoDamageResolver.lua") end

do
    -- CONFIG
    local PHANTOM_ECHO_COOLDOWN = 30  -- Cooldown in seconds
    local BUFF_NAME = "Phantom Echo"
    local BUFF_ICON = "ReplaceableTextures\\CommandButtons\\BTNReincarnation.blp" -- Custom icon (can be replaced)

    -- Table to track cooldowns for each player
    local phantomEchoCooldown = {}

    -- Buff Data Structure
    local function applyPhantomEchoBuff(caster)
        local pid = GetPlayerId(GetOwningPlayer(caster))

        -- Check if the cooldown is active
        if phantomEchoCooldown[pid] and phantomEchoCooldown[pid] > 0 then
            DisplayTextToPlayer(GetOwningPlayer(caster), 0, 0, "Phantom Echo is on cooldown.")
            return false  -- Don't apply the buff if cooldown is active
        end

        -- Buff Data
        local buffData = {
            unit = caster, -- The caster is the unit we apply the buff to
            source = caster, -- The source of the buff (same as unit)
            name = BUFF_NAME, -- Buff name
            type = "passive", -- Passive effect
            duration = 10, -- Lasts for 10 seconds
            icon = BUFF_ICON, -- Buff icon
            values = { bonusDamage = 0 }, -- Stores the bonus damage value
            onApply = function(unit, source, values, level)
                -- Logic for applying bonus damage when the buff is applied
                local lostHealthPercent = (GetUnitState(unit, UNIT_STATE_LIFE) / GetUnitState(unit, UNIT_STATE_MAX_LIFE)) * 100
                values.bonusDamage = math.floor(lostHealthPercent / 10) -- 1% bonus for every 10% health lost
                -- Apply the bonus damage as a stat modifier (you could hook into StatSystem or PlayerData)
                -- Example: PlayerData.AddAbilityDamage(unit, values.bonusDamage)
                DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "Phantom Echo: " .. values.bonusDamage .. "% bonus damage.")
            end,
            onExpire = function(unit, source, values)
                -- Reset bonus damage when the buff expires
                -- You can reset any stat modifications here
                DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "Phantom Echo expired!")
            end
        }

        -- Apply the buff using BuffBot (or your preferred buff system)
        BuffBot.Apply(caster, buffData, caster)

        -- Start the cooldown timer for Phantom Echo
        phantomEchoCooldown[pid] = PHANTOM_ECHO_COOLDOWN

        -- Create a cooldown timer for the player
        local cooldownTimer = CreateTimer()
        TimerStart(cooldownTimer, 1.0, true, function()
            if phantomEchoCooldown[pid] > 0 then
                phantomEchoCooldown[pid] = phantomEchoCooldown[pid] - 1
            else
                DestroyTimer(cooldownTimer)  -- Stop the timer once the cooldown ends
            end
        end)

        return true  -- Successfully applied the buff
    end

    -- Hook into the CombatEventsBridge for Dealt Damage event
    local function onDamageDealt(caster, target, damage)
        -- Only apply Phantom Echo if the caster is the one taking damage
        if not caster or GetUnitTypeId(caster) == 0 then return end

        -- Apply or refresh Phantom Echo buff when damage is taken
        if not BuffBot.HasBuff(caster, BUFF_NAME) then
            applyPhantomEchoBuff(caster) -- Apply the buff when damage is taken
        end
    end

    -- Register the damage event for **all players** in multiplayer
    local damageResolveTrigger = CreateTrigger()
    for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
        TriggerRegisterPlayerUnitEvent(damageResolveTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED)
    end
    TriggerAddAction(damageResolveTrigger, function()
        local caster = GetTriggerUnit()  -- Get the unit that took the damage
        local target = GetEventTargetUnit()  -- Get the target of the damage
        local damage = GetEventDamage()  -- Get the damage amount
        
        -- Call the damage function
        onDamageDealt(caster, target, damage)
    end)

    -- Function to manually apply the Phantom Echo buff (this is the one you can call)
    function PhantomEcho.AddToUnit(unit)
        if not unit or GetUnitTypeId(unit) == 0 then
            return false
        end
        return applyPhantomEchoBuff(unit)
    end

    -- Initialize and debug setup
    OnInit.final(function()
        if Debug then Debug.log("Phantom Echo system initialized.") end
    end)

end

if Debug and Debug.endFile then Debug.endFile() end
