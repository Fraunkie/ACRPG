if Debug and Debug.beginFile then Debug.beginFile('HeroStatSystem') end

--==================================================
-- HERO STAT SYSTEM (v2 - Integrated with PLAYER_DATA)
--==================================================
-- Handles base stats, multipliers, automatic updates,
-- and now synchronizes with PLAYER_DATA.powerLevel.
--==================================================
if Debug and Debug.beginFile then Debug.beginFile("StatGlobals") end

--==================================================
-- GLOBAL STAT TABLES
--==================================================

if not PlayerBaseStr then PlayerBaseStr = {} end
if not PlayerBaseAgi then PlayerBaseAgi = {} end
if not PlayerBaseInt then PlayerBaseInt = {} end

if not PlayerMStr then PlayerMStr = {} end
if not PlayerMAgi then PlayerMAgi = {} end
if not PlayerMInt then PlayerMInt = {} end

if Debug and Debug.endFile then Debug.endFile() end

if not HeroStatSystem then HeroStatSystem = {} end
_G.HeroStatSystem = HeroStatSystem

do
    --------------------------------------------------
    -- CONSTANTS
    --------------------------------------------------
    local UPDATE_INTERVAL = 1.00

    local DEFAULT_BASE_STR = 2
    local DEFAULT_BASE_AGI = 2
    local DEFAULT_BASE_INT = 2
    local DEFAULT_MULTIPLIER = 1.0

    --------------------------------------------------
    -- INTERNAL TABLES
    --------------------------------------------------
    local HeroStatMultipliers = {}
    local StatUpdateTimers = {}
    local DEBUG_ENABLED = false

    -- Soul Haste passive (A000) integration
    local AURA_PASSIVE_ID = FourCC('A000')
    local AURA_FX_ID = "fx_soul_haste_aura"
    local SoulHasteAura = {}

    --------------------------------------------------
    -- UTILITIES
    --------------------------------------------------
    local function DebugPrint(msg)
        if DEBUG_ENABLED then print("STATS DEBUG: " .. msg) end
    end

    local function ToggleDebug()
        DEBUG_ENABLED = not DEBUG_ENABLED
        print("Stat debug messages: " .. (DEBUG_ENABLED and "ENABLED" or "DISABLED"))
    end

    --------------------------------------------------
    -- INITIALIZATION
    --------------------------------------------------
    local function InitializePlayerStats(playerId)
        PlayerBaseStr[playerId] = DEFAULT_BASE_STR
        PlayerBaseAgi[playerId] = DEFAULT_BASE_AGI
        PlayerBaseInt[playerId] = DEFAULT_BASE_INT

        HeroStatMultipliers[playerId] = {
            strength = DEFAULT_MULTIPLIER,
            agility = DEFAULT_MULTIPLIER,
            intelligence = DEFAULT_MULTIPLIER,
            global = DEFAULT_MULTIPLIER
        }

        PlayerMStr[playerId] = 0
        PlayerMAgi[playerId] = 0
        PlayerMInt[playerId] = 0
    end

    local function CalculateCurrentStat(playerId, base, mult, global)
        local result = math.floor((base * mult) * global + 0.5)
        if result < 1 then result = 1 end
        return result
    end

    local function UpdateHeroAttributes(playerId)
        local hero = PlayerHero[playerId]
        if not hero or GetWidgetLife(hero) <= 0 then return false end

        local mult = HeroStatMultipliers[playerId] or {}
        local global = mult.global or DEFAULT_MULTIPLIER

        local baseStr = PlayerBaseStr[playerId] or DEFAULT_BASE_STR
        local baseAgi = PlayerBaseAgi[playerId] or DEFAULT_BASE_AGI
        local baseInt = PlayerBaseInt[playerId] or DEFAULT_BASE_INT

        local newStr = CalculateCurrentStat(playerId, baseStr, mult.strength or 1, global)
        local newAgi = CalculateCurrentStat(playerId, baseAgi, mult.agility or 1, global)
        local newInt = CalculateCurrentStat(playerId, baseInt, mult.intelligence or 1, global)

        SetHeroStr(hero, newStr, true)
        SetHeroAgi(hero, newAgi, true)
        SetHeroInt(hero, newInt, true)

        PlayerMStr[playerId] = newStr
        PlayerMAgi[playerId] = newAgi
        PlayerMInt[playerId] = newInt

        -- Update power level inside PLAYER_DATA
        local pdata = PLAYER_DATA[playerId]
        if pdata then
            pdata.powerLevel = newStr + newAgi + newInt
        end

        -- Passive: Soul Haste (A000) +120% attack speed via StatSystem
        if StatSystem and StatSystem.SetUnitStat then
            if GetUnitAbilityLevel(hero, AURA_PASSIVE_ID) > 0 then
                -- Apply 120 to STAT_ATTACK_SPEED (percent bonus)
                StatSystem.SetUnitStat(hero, StatSystem.STAT_ATTACK_SPEED, 120)
                -- Play persistent aura once per hero (visual only)
                if not SoulHasteAura[hero] then
                    local FX = rawget(_G, "FX")
                    if FX and FX.play then
                        FX.play(AURA_FX_ID, { unit = hero, localTo = GetOwningPlayer(hero) })
                    end
                    SoulHasteAura[hero] = true
                end
            else
                -- If passive not present, ensure no extra attack speed from this passive
                StatSystem.SetUnitStat(hero, StatSystem.STAT_ATTACK_SPEED, 0)
            end
        end

        return true
    end

    local function StartStatUpdates(playerId)
        if StatUpdateTimers[playerId] then
            DestroyTimer(StatUpdateTimers[playerId])
        end

        StatUpdateTimers[playerId] = CreateTimer()
        TimerStart(StatUpdateTimers[playerId], UPDATE_INTERVAL, true, function()
            UpdateHeroAttributes(playerId)
        end)
    end

    --------------------------------------------------
    -- PUBLIC INTERFACE
    --------------------------------------------------
    function HeroStatSystem.InitializeHeroStats(playerId)
        InitializePlayerStats(playerId)
        StartStatUpdates(playerId)

        local hero = PlayerHero[playerId]
        if hero then
            UpdateHeroAttributes(playerId)
        end

        local pdata = PLAYER_DATA[playerId]
        if pdata then
            pdata.powerLevel =
                (PlayerMStr[playerId] or 0)
                + (PlayerMAgi[playerId] or 0)
                + (PlayerMInt[playerId] or 0)
        end
    end

    function HeroStatSystem.UpdateHeroAttributes(playerId)
        UpdateHeroAttributes(playerId)
    end

    function HeroStatSystem.GetPowerLevel(playerId)
        local pdata = PLAYER_DATA[playerId]
        if pdata then
            return pdata.powerLevel or 0
        end
        return 0
    end

    function HeroStatSystem.RefreshPowerLevel(playerId)
        local pdata = PLAYER_DATA[playerId]
        if pdata then
            pdata.powerLevel =
                (PlayerMStr[playerId] or 0)
                + (PlayerMAgi[playerId] or 0)
                + (PlayerMInt[playerId] or 0)
        end
    end

    function HeroStatSystem.SetPlayerBaseStat(playerId, stat, value)
        if not HeroStatMultipliers[playerId] then
            InitializePlayerStats(playerId)
        end

        if stat == "strength" or stat == "str" then
            PlayerBaseStr[playerId] = value
        elseif stat == "agility" or stat == "agi" then
            PlayerBaseAgi[playerId] = value
        elseif stat == "intelligence" or stat == "int" then
            PlayerBaseInt[playerId] = value
        end

        UpdateHeroAttributes(playerId)
    end

    function HeroStatSystem.SetPlayerMultiplier(playerId, stat, mult)
        if not HeroStatMultipliers[playerId] then
            InitializePlayerStats(playerId)
        end

        local m = HeroStatMultipliers[playerId]
        if stat == "strength" or stat == "str" then
            m.strength = mult
        elseif stat == "agility" or stat == "agi" then
            m.agility = mult
        elseif stat == "intelligence" or stat == "int" then
            m.intelligence = mult
        elseif stat == "global" then
            m.global = mult
        end

        UpdateHeroAttributes(playerId)
    end

    --------------------------------------------------
    -- CHAT COMMANDS
    --------------------------------------------------
    local function SetupStatCommands()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-statsdebug", true)
        end
        TriggerAddAction(trig, function()
            ToggleDebug()
        end)
    end

    --------------------------------------------------
    -- AUTO-INIT
    --------------------------------------------------
    local initTimer = CreateTimer()
    TimerStart(initTimer, 1.0, false, function()
        SetupStatCommands()
        print("HeroStatSystem Initialized.")
        DestroyTimer(initTimer)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
