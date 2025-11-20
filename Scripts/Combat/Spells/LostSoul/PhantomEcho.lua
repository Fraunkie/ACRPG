if Debug and Debug.beginFile then Debug.beginFile("Spell_PassivePhantomEcho.lua") end

-- Make the script globally accessible
Spell_PassivePhantomEcho = Spell_PassivePhantomEcho or {}
_G.Spell_PassivePhantomEcho = Spell_PassivePhantomEcho

do
    -- CONFIG
    local PHANTOM_ECHO_COOLDOWN = 30  -- Cooldown in seconds
    local BUFF_NAME = "Phantom Echo"
    local BUFF_ICON = "ReplaceableTextures\\CommandButtons\\BTNReincarnation.blp" -- Custom icon (can be replaced)

    -- Table to track cooldowns for each player
    local phantomEchoCooldown = {}

    -- Buff Data Structure (Correct setup like Healing Herb)
    local function applyPhantomEchoBuff(caster)
        local pid = GetPlayerId(GetOwningPlayer(caster))

        -- Check if the cooldown is active
        if phantomEchoCooldown[pid] and phantomEchoCooldown[pid] > 0 then
            DisplayTextToPlayer(GetOwningPlayer(caster), 0, 0, "Phantom Echo is on cooldown.")
            return false  -- Don't apply the buff if cooldown is active
        end

        -- Buff Data (same structure as Healing Herb)
        local buffData = {
            name = BUFF_NAME,  -- Buff name
            tooltip = "Increases damage based on lost health",  -- Buff description
            icon = BUFF_ICON,  -- Buff icon
            type = "Magic",    -- Buff type
            duration = 10,     -- Lasts for 10 seconds
            color = "|cff00ff00",  -- Optional color for display (green in this case)
            effect = "Abilities\\Spells\\NightElf\\Rejuvenation\\RejuvenationTarget.mdl",  -- Optional effect for visual feedback
            attachPoint = "chest",  -- Optional attachment point (for the effect)
            values = {
                bonusDamage = function(target, source, level, stacks)
                    -- Calculate bonus damage based on lost health
                    local lostHealthPercent = (GetUnitState(target, UNIT_STATE_LIFE) / GetUnitState(target, UNIT_STATE_MAX_LIFE)) * 100
                    return math.floor(lostHealthPercent / 10)  -- 1% bonus damage for every 10% health lost
                end,
            },
            onApply = function(target, source, values, level, stacks)
                -- Apply the bonus damage when the buff is applied
                local bonusDamage = values.bonusDamage  -- Bonus damage calculated earlier
                -- Apply the bonus damage as magic damage (you can hook this into your damage system)
                

                -- Display message to the player who owns the target unit
                DisplayTextToPlayer(GetOwningPlayer(target), 0, 0, "Phantom Echo: " .. tostring(bonusDamage) .. "% bonus damage.")
            end,
            onExpire = function(target, source, values)
                -- Reset any bonus damage or other effects when the buff expires
                DisplayTextToPlayer(GetOwningPlayer(target), 0, 0, "Phantom Echo expired!")
            end
        }

        -- Apply the buff using BuffBot (no need for third 'caster' argument)
        BuffBot.Apply(caster, buffData)

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

    -- Function to manually apply the Phantom Echo buff (this is the one you can call)
    function Spell_PassivePhantomEcho.AddToUnit(unit)
        if not unit or GetUnitTypeId(unit) == 0 then
            return false
        end
        return applyPhantomEchoBuff(unit)  -- Apply the Phantom Echo buff if valid
    end

    -- Initialize and debug setup
    OnInit.final(function()
        if Debug then Debug.log("Phantom Echo system initialized.") end
    end)

end

if Debug and Debug.endFile then Debug.endFile() end
