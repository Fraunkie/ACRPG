if Debug and Debug.beginFile then Debug.beginFile('HeroStatSystem') end

--==================================================
-- HERO STAT SYSTEM (v2 - Integrated with PLAYER_DATA)
--==================================================
-- Handles base stats, multipliers, automatic updates,
-- and synchronizes with PLAYER_DATA.powerLevel.
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

    local function isHumanPid(pid)
        if pid == nil or pid < 0 or pid >= bj_MAX_PLAYERS then return false end
        return GetPlayerController(Player(pid)) == MAP_CONTROL_USER
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

    local function RefreshPlayerPower(pid)
        if not isHumanPid(pid) then return end
        local pd = PLAYER_DATA and PLAYER_DATA[pid]
        if not pd then return end
        pd.powerLevel = (PlayerMStr[pid] or 0) + (PlayerMAgi[pid] or 0) + (PlayerMInt[pid] or 0)
    end

    local function UpdateHeroAttributes(playerId)
        local heroTbl = rawget(_G, "PlayerHero")
        local hero = heroTbl and heroTbl[playerId] or nil
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

        RefreshPlayerPower(playerId)

        -- Passive: Soul Haste (A000) +120% attack speed via StatSystem
        local S = rawget(_G, "StatSystem")
        if S and S.SetUnitStat and S.STAT_ATTACK_SPEED then
            if GetUnitAbilityLevel(hero, AURA_PASSIVE_ID) > 0 then
                pcall(S.SetUnitStat, hero, S.STAT_ATTACK_SPEED, 120)
                if not SoulHasteAura[hero] then
                    local FX = rawget(_G, "FX")
                    if FX and FX.play then
                        pcall(FX.play, AURA_FX_ID, { unit = hero, localTo = GetOwningPlayer(hero) })
                    end
                    SoulHasteAura[hero] = true
                end
            else
                pcall(S.SetUnitStat, hero, S.STAT_ATTACK_SPEED, 0)
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

        local heroTbl = rawget(_G, "PlayerHero")
        local hero = heroTbl and heroTbl[playerId] or nil
        if hero then
            UpdateHeroAttributes(playerId)
        end
        RefreshPlayerPower(playerId)
    end

    function HeroStatSystem.UpdateHeroAttributes(playerId)
        UpdateHeroAttributes(playerId)
    end

    function HeroStatSystem.GetPowerLevel(playerId)
        local pdata = PLAYER_DATA and PLAYER_DATA[playerId]
        return (pdata and pdata.powerLevel) or 0
    end

    function HeroStatSystem.RefreshPowerLevel(playerId)
        RefreshPlayerPower(playerId)
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
    -- BUS & STAT EVENTS SYNC
    --------------------------------------------------
    local function wireEvents()
        -- Whenever a stat is applied via StatSystem, re-sync powerLevel if it's a hero.
        local S = rawget(_G, "StatSystem")
        if S and S.RegisterStatEvent and not HeroStatSystem._statHooked then
            S.RegisterStatEvent(function()
                local u = S.GetStatEventUnit and S.GetStatEventUnit() or nil
                if not u then return end
                local owner = GetOwningPlayer(u)
                if not owner then return end
                local pid = GetPlayerId(owner)
                -- Only adjust if this unit is the tracked hero for that player
                local heroTbl = rawget(_G, "PlayerHero")
                if heroTbl and heroTbl[pid] == u then
                    RefreshPlayerPower(pid)
                end
            end)
            HeroStatSystem._statHooked = true
        end

        -- Optional ProcBus hero-binding events (safe if not present)
        local PB = rawget(_G, "ProcBus")
        local function tryInit(e)
            if not e then return end
            local pid = e.pid or (e.playerId) or nil
            if pid ~= nil then HeroStatSystem.InitializeHeroStats(pid) end
        end
        if PB then
            if PB.Subscribe then
                PB.Subscribe("HERO_CREATED", tryInit)
                PB.Subscribe("HERO_BOUND", tryInit)
            elseif PB.On then
                PB.On("HERO_CREATED", tryInit)
                PB.On("HERO_BOUND", tryInit)
            end
        end
    end

    --------------------------------------------------
    -- CHAT COMMANDS
    --------------------------------------------------
    local function SetupStatCommands()
        local trig = CreateTrigger()
        for i = 0, bj_MAX_PLAYER_SLOTS - 1 do
            TriggerRegisterPlayerChatEvent(trig, Player(i), "-statsdebug", true)
        end
        TriggerAddAction(trig, function() ToggleDebug() end)
    end

    --------------------------------------------------
    -- AUTO-INIT
    --------------------------------------------------
    local initTimer = CreateTimer()
    TimerStart(initTimer, 1.0, false, function()
        SetupStatCommands()
        wireEvents()
        -- Boot-time ensure for all human slots (no-op if hero not spawned yet)
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if isHumanPid(pid) then
                if not HeroStatMultipliers[pid] then InitializePlayerStats(pid) end
                StartStatUpdates(pid)
            end
        end
        print("HeroStatSystem Initialized.")
        DestroyTimer(initTimer)
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
