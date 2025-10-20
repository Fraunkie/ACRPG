if Debug and Debug.beginFile then Debug.beginFile("PlayerData.lua") end
--==================================================
-- PlayerData.lua
-- Single source of truth for per-player runtime state.
--  - Long-lived, cross-system data lives here
--  - System-specific logic stays in its own module
--  - Mirrors read-only combat stats from HeroStatSystem
--==================================================

if not PlayerData then PlayerData = {} end
_G.PlayerData = PlayerData
PLAYER_DATA = PLAYER_DATA or {}
PlayerHero  = PlayerHero or {}

do
    --------------------------------------------------
    -- Defaults
    --------------------------------------------------
    local function defaultTable()
        return {
            -- identity / session
            hero = nil,
            zone = "YEMMA",
            role = "NONE",
            hasStarted = false,

            -- power/progression mirrors
            powerLevel = 0,
            soulEnergy = 0,
            soulLevel  = 1,
            soulXP     = 0,
            soulNextXP = 200,
            spiritDrive= 0,

            -- read-only combat stats mirror (kept in sync by events)
            stats = { power = 0, defense = 0, speed = 0, crit = 0 },

            -- loot / shards
            fragments   = 0,
            ownedShards = {},

            -- UX flags
            lootChatEnabled = true,
            yemmaPromptShown = false,
            yemmaPromptMinimized = false,

            -- intro/meta
            introChoice = nil,
            introCompleted = false,
            introStyle = nil,

            -- tasks / teleports
            hfilTask = { active=false, id=nil, name="", desc="", goalType="", need=0, have=0, rarity="Common" },
            activeTask = nil,
            teleports = {},

            -- optional misc bonuses
            xpBonusPercent = 0,
            statChanceBonusPermil = 0,
            dropLuckBonusPermil = 0,
        }
    end

    --------------------------------------------------
    -- Accessors
    --------------------------------------------------
    function PlayerData.Get(pid)
        local t = PLAYER_DATA[pid]
        if t == nil then
            t = defaultTable()
            PLAYER_DATA[pid] = t
        end
        return t
    end

    function PlayerData.GetField(pid, key, defaultValue)
        local t = PlayerData.Get(pid)
        local v = t[key]
        if v == nil then return defaultValue end
        return v
    end

    --------------------------------------------------
    -- Hero binding
    --------------------------------------------------
    function PlayerData.SetHero(pid, unit)
        local pd = PlayerData.Get(pid)
        pd.hero = unit
        PlayerHero[pid] = unit
        return unit
    end

    function PlayerData.GetHero(pid)
        local pd = PlayerData.Get(pid)
        return pd.hero
    end

    --------------------------------------------------
    -- Power mirror refresh (example based on external stat arrays)
    --------------------------------------------------
    function PlayerData.RefreshPower(pid)
        local pd = PlayerData.Get(pid)
        local str = (rawget(_G, "PlayerMStr") and PlayerMStr[pid]) or 0
        local agi = (rawget(_G, "PlayerMAgi") and PlayerMAgi[pid]) or 0
        local int = (rawget(_G, "PlayerMInt") and PlayerMInt[pid]) or 0
        pd.powerLevel = math.max(0, math.floor((str + agi + int) / 3))
        return pd.powerLevel
    end

    --------------------------------------------------
    -- Souls / shards small helpers
    --------------------------------------------------
    function PlayerData.AddSoul(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.soulEnergy = math.max(0, (pd.soulEnergy or 0) + (amount or 0))
        return pd.soulEnergy
    end

    function PlayerData.AddFragments(pid, amount)
        local pd = PlayerData.Get(pid)
        pd.fragments = math.max(0, (pd.fragments or 0) + (amount or 0))
        return pd.fragments
    end

    --------------------------------------------------
    -- Zone helpers
    --------------------------------------------------
    function PlayerData.SetZone(pid, zone)
        local pd = PlayerData.Get(pid)
        pd.zone = zone or pd.zone
        return pd.zone
    end

    function PlayerData.GetZone(pid)
        local pd = PlayerData.Get(pid)
        return pd.zone
    end

    --------------------------------------------------
    -- Read-only stats mirror (from HeroStatSystem)
    --------------------------------------------------
    function PlayerData.SetStats(pid, tbl)
        local pd = PlayerData.Get(pid)
        local s = pd.stats or {}
        s.power   = (tbl and tbl.power)   or s.power   or 0
        s.defense = (tbl and tbl.defense) or s.defense or 0
        s.speed   = (tbl and tbl.speed)   or s.speed   or 0
        s.crit    = (tbl and tbl.crit)    or s.crit    or 0
        pd.stats = s
        return s
    end

    function PlayerData.GetStats(pid)
        local pd = PlayerData.Get(pid)
        local s = pd.stats
        if not s then
            s = { power = 0, defense = 0, speed = 0, crit = 0 }
            pd.stats = s
        end
        return s
    end

    --------------------------------------------------
    -- Init and event wiring
    --------------------------------------------------
    OnInit.final(function()
        -- ensure slots exist for human players
        for pid = 0, bj_MAX_PLAYERS - 1 do
            if GetPlayerController(Player(pid)) == MAP_CONTROL_USER then
                PLAYER_DATA[pid] = PLAYER_DATA[pid] or defaultTable()
            end
        end

        -- Mirror HeroStatSystem updates into PlayerData.stats
        local function _PD_OnHeroStatsChanged(e)
            if not e or not e.unit then return end
            local p = GetPlayerId(GetOwningPlayer(e.unit))
            if p == nil then return end
            if _G.HeroStatSystem and HeroStatSystem.GetAll then
                local all = HeroStatSystem.GetAll(e.unit)
                PlayerData.SetStats(p, {
                    power   = (all and all.power)   or 0,
                    defense = (all and all.defense) or 0,
                    speed   = (all and all.speed)   or 0,
                    crit    = (all and all.crit)    or 0,
                })
            end
        end

        local PB = rawget(_G, "ProcBus")
        if PB and PB.On then
            PB.On("HeroStatsChanged", _PD_OnHeroStatsChanged)
        end

        if rawget(_G, "InitBroker") and InitBroker.SystemReady then
            InitBroker.SystemReady("PlayerData")
        end
    end)
end

if Debug and Debug.endFile then Debug.endFile() end
