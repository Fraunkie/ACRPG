if Debug and Debug.beginFile then Debug.beginFile("Spell_PassivePhantomEcho.lua") end

do
    Spell_PassivePhantomEcho = Spell_PassivePhantomEcho or {}
    _G.Spell_PassivePhantomEcho = Spell_PassivePhantomEcho

    -- CONFIG
    local PHANTOM_ECHO_COOLDOWN = 30  -- Cooldown in seconds
    local BUFF_NAME = "Phantom Echo"
    local BUFF_ICON = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp" -- Custom icon (can be replaced)

    -- Table to track cooldowns for each player
    local phantomEchoCooldown = {}

    -- Helper function to get known spells for the player (do not modify)
    local function getKnownTables(pid)
        if not _G.PlayerData or not PlayerData.Get then
            return nil
        end
        local pd = PlayerData.Get(pid)
        pd.knownspells = pd.knownspells or { passives = {}, actives = {} }
        pd.knownspells.passives = pd.knownspells.passives or {}
        pd.knownspells.actives  = pd.knownspells.actives or {}
        return pd.knownspells
    end

    -- Helper function to check if the player knows the Phantom Echo passive spell (do not modify)
    local function isPhantomEchoKnown(pid)
        local knownSpells = getKnownTables(pid)
        if knownSpells and knownSpells.passives then
            return knownSpells.passives["phantomEcho"] == true
        end
        return false
    end

    -- Buff Data Structure
    local function applyPhantomEchoBuff(caster)
        local pid = GetPlayerId(GetOwningPlayer(caster))

        -- Initialize the cooldown for this player if it hasn't been initialized yet
        if phantomEchoCooldown[pid] == nil then
            phantomEchoCooldown[pid] = 0  -- Initialize to 0 if it's not set
        end

        -- Check if the cooldown is active
        if phantomEchoCooldown[pid] > 0 then
            DisplayTextToPlayer(GetOwningPlayer(caster), 0, 0, "Phantom Echo is on cooldown.")
            return false  -- Don't apply the buff if cooldown is active
        end

        -- Buff Data
    local buffData = {
        name = BUFF_NAME,
        type = "Passive", -- Passive effect
        tooltip = "Increased Energy Damage by 1".."%%".." for every 10".."%%".." missing health.",
        duration = 10, -- Lasts for 10 seconds
        icon = BUFF_ICON,
        values = { bonusDamage = 0.00 }, -- Stores the bonus damage value
        onApply = function(unit, source, values, level)
            -- Logic for applying bonus damage when the buff is applied
            local lostHealthPercent = (GetUnitState(unit, UNIT_STATE_LIFE) / GetUnitState(unit, UNIT_STATE_MAX_LIFE)) * 100
            values.bonusDamage = math.floor(lostHealthPercent / 10) -- 1% bonus for every 10% health lost
            local pid = GetPlayerId(GetOwningPlayer(unit))
            local combat = PlayerData.GetCombat(pid)  -- Get the combat data for the player
            combat.energyDamage = combat.energyDamage + values.bonusDamage  -- Add bonus damage to current energyDamage

            DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "Phantom Echo: " .. values.bonusDamage .. "% bonus damage.")
            print("[DEBUG] Phantom Echo applied: " .. values.bonusDamage .. "% bonus damage")
        end,
        onExpire = function(unit, source, values)
            local pid = GetPlayerId(GetOwningPlayer(unit))
            local combat = PlayerData.GetCombat(pid)  -- Get the combat data for the player
            combat.energyDamage = combat.energyDamage - values.bonusDamage  -- Add bonus damage to current energyDamage
            -- Reset bonus damage when the buff expires
            DisplayTextToPlayer(GetOwningPlayer(unit), 0, 0, "Phantom Echo expired!")
            print("[DEBUG] Phantom Echo expired for unit: " .. GetUnitName(unit))
        end
    }
        BuffBot.Apply(caster, buffData)

        -- Start the cooldown timer for Phantom Echo
        phantomEchoCooldown[pid] = PHANTOM_ECHO_COOLDOWN

        -- Create a cooldown timer for the player
        local cooldownTimer = CreateTimer()
        TimerStart(cooldownTimer, 1.0, true, function()
            if phantomEchoCooldown[pid] > 0 then
                phantomEchoCooldown[pid] = phantomEchoCooldown[pid] - 1  -- Decrement the cooldown
            else
                DestroyTimer(cooldownTimer)  -- Stop the timer once the cooldown ends
            end
        end)

        return true  -- Successfully applied the buff
    end
	-- Hook into the CombatEventsBridge for Dealt Damage event
local function onDamageDealt(caster, target, damage)
    -- Only apply Phantom Echo if the unit taking damage has the spell unlocked
    if not caster or GetUnitTypeId(caster) == 0 then return end

    -- Get player ID for caster
    local pid = GetPlayerId(GetOwningPlayer(caster))

    -- Ensure the cooldown is initialized for the player (pid) before using it
    if phantomEchoCooldown[pid] == nil then
        phantomEchoCooldown[pid] = 0  -- Initialize cooldown to 0 if it's not set
    end

    -- Apply or refresh Phantom Echo buff when damage is taken
    if isPhantomEchoKnown(pid) then
        -- Check cooldown
        if phantomEchoCooldown[pid] <= 0 then
            -- Apply the buff when damage is taken
            if not BuffBot.HasBuff(caster, BUFF_NAME) then
                applyPhantomEchoBuff(caster)  -- Apply the buff when damage is taken
            end
        else
            -- Debug log for cooldown
            print("Phantom Echo on cooldown for unit " .. tostring(GetUnitName(caster)))
        end
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
    function Spell_PassivePhantomEcho.AddToUnit(unit)
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
