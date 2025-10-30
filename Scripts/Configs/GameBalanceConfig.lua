if Debug and Debug.beginFile then Debug.beginFile("GameBalanceConfig.lua") end
--==================================================
-- GameBalanceConfig.lua  (v3.1a — unlocks normalized)
--  • All prior data kept
--  • SPELL_UNLOCKS_BY_UNIT now normalized to numeric FourCC keys
--  • Lost Soul entries flagged as passives where intended
--==================================================

if not GameBalance then GameBalance = {} end
_G.GameBalance = GameBalance

do
    --------------------------------------------------
    -- ZONE / AREA COORDINATES
    --------------------------------------------------
    GameBalance.COORDS = GameBalance.COORDS or {
        SPAWN = { x = 28802.9, y = 27926.3, z = nil, facing = 270.0 },
        HFIL  = { x = 28546.5, y = -21148.4, z = 564.0, facing = 180.0 },
        YEMMA = { x = 28856.0, y = 28929.0, z = 597.2, facing = 180.0 },
    }

    --------------------------------------------------
    -- HUBS
    --------------------------------------------------
    local HUB_RADIUS = 300.0
    GameBalance.HUBS = GameBalance.HUBS or {
        { id = "YEMMA", x = 28856.0, y = 28929.0,z = 597.2, facing = 180.0, radius = HUB_RADIUS, ui = "hub" },
    }

    --------------------------------------------------
    -- CRYSTALS
    --------------------------------------------------
    local CRYSTAL_RADIUS = 250.0
    GameBalance.CRYSTALS = GameBalance.CRYSTALS or {
        -- empty by default
    }

    --------------------------------------------------
    -- Accessors
    --------------------------------------------------
    function GameBalance.GetCoord(key)       return GameBalance.COORDS[key] end
    function GameBalance.ListHubs()          return GameBalance.HUBS end
    function GameBalance.ListCrystals()      return GameBalance.CRYSTALS end
    function GameBalance.FindHub(id)
        for _, hub in ipairs(GameBalance.HUBS) do
            if hub.id == id then return hub end
        end
        return nil
    end
    function GameBalance.FindCrystal(id)
        for _, c in ipairs(GameBalance.CRYSTALS) do
            if c.id == id then return c end
        end
        return nil
    end

    --------------------------------------------------
    -- Teleport node ids and names
    --------------------------------------------------
    GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {
        YEMMA        = "YEMMA",
        KAMI_LOOKOUT = "KAMI_LOOKOUT",
        HFIL         = "HFIL",
        RADITZ       = "RADITZ",
        VIRIDIAN     = "VIRIDIAN",
        FILE_ISLAND  = "FILE_ISLAND",
        LAND_OF_FIRE = "LAND_OF_FIRE",
        VIRIDIAN_BOSS = "VIRIDIAN_BOSS",
        DARK_DIGI     = "DARK_DIGI",
        NINE_TAILS    = "NINE_TAILS",
    }

    GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {
        YEMMA        = "King Yemma's Desk",
        KAMI_LOOKOUT = "Kami's Lookout",
        HFIL         = "HFIL",
        RADITZ        = "Raditz Landing",
        VIRIDIAN      = "Viridian Forest",
        FILE_ISLAND   = "File Island",
        LAND_OF_FIRE  = "Land of Fire",
        VIRIDIAN_BOSS = "Viridian Guardian",
        DARK_DIGI     = "Dark Digivolution",
        NINE_TAILS    = "Nine Tails Rampage",
    }

    --------------------------------------------------
    -- Travel requirements
    --------------------------------------------------
    GameBalance.NODE_REQS = GameBalance.NODE_REQS or {
        KAMI_LOOKOUT = { pl_min = 250 },
        VIRIDIAN     = { pl_min = 600 },
        FILE_ISLAND  = { pl_min = 950 },
        LAND_OF_FIRE = { pl_min = 1300 },
        RADITZ        = { pl_min = 500 },
        VIRIDIAN_BOSS = { pl_min = 900 },
        DARK_DIGI     = { pl_min = 1200 },
        NINE_TAILS    = { pl_min = 1600 },
    }

    --------------------------------------------------
    -- Starting hero
    --------------------------------------------------
    GameBalance.START_HERO_ID = GameBalance.START_HERO_ID or FourCC("H001")

    --------------------------------------------------
    -- Spirit Drive settings
    --------------------------------------------------
    GameBalance.SPIRIT_DRIVE_MAX                = GameBalance.SPIRIT_DRIVE_MAX or 100
    GameBalance.SPIRIT_DRIVE_ON_HIT             = GameBalance.SPIRIT_DRIVE_ON_HIT or 3
    GameBalance.SPIRIT_DRIVE_ON_KILL            = GameBalance.SPIRIT_DRIVE_ON_KILL or 10
    GameBalance.SPIRIT_DRIVE_DECAY_PER_SEC      = GameBalance.SPIRIT_DRIVE_DECAY_PER_SEC or 2
    GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC = GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC or 6
    GameBalance.SPIRIT_DRIVE_GATE_SEC           = GameBalance.SPIRIT_DRIVE_GATE_SEC or 0.60

    --------------------------------------------------
    -- Souls and XP
    --------------------------------------------------
    GameBalance.XP_PER_KILL_BASE = GameBalance.XP_PER_KILL_BASE or 20
    GameBalance.SOUL_ENERGY_MULT = GameBalance.SOUL_ENERGY_MULT or 1.0
    GameBalance.SOUL_SHARE_RANGE = GameBalance.SOUL_SHARE_RANGE or 900.0

    --------------------------------------------------
    -- Threat and combat scaling
    --------------------------------------------------
    GameBalance.THREAT_PER_DAMAGE     = GameBalance.THREAT_PER_DAMAGE or 0.5
    GameBalance.DAMAGE_TRACK_CLAMP    = GameBalance.DAMAGE_TRACK_CLAMP or 35
    GameBalance.DAMAGE_RECORD_MIN_GAP = GameBalance.DAMAGE_RECORD_MIN_GAP or 0.20

    --------------------------------------------------
    -- Combat tunables
    --------------------------------------------------
    GameBalance.CRIT_MULT_BASE  = GameBalance.CRIT_MULT_BASE or 1.5
    GameBalance.BLOCK_REDUCTION = GameBalance.BLOCK_REDUCTION or 0.30

    --------------------------------------------------
    -- Ascension and misc progression
    --------------------------------------------------
    GameBalance.ASCENSION_MIN_POWER = GameBalance.ASCENSION_MIN_POWER or 25
    GameBalance.ASCENSION_MIN_TIER  = GameBalance.ASCENSION_MIN_TIER  or 1
    GameBalance.SPIRIT_REQ_FULL     = GameBalance.SPIRIT_REQ_FULL     or true

    --------------------------------------------------
    -- Power Level cap for task scaling
    --------------------------------------------------
    GameBalance.POWERLEVEL_CAP = GameBalance.POWERLEVEL_CAP or 20

    --------------------------------------------------
    -- Economy
    --------------------------------------------------
    GameBalance.FRAGMENT_PER_DUPLICATE = GameBalance.FRAGMENT_PER_DUPLICATE or 5
    GameBalance.FRAGMENT_MAX           = GameBalance.FRAGMENT_MAX or 9999

    --------------------------------------------------
    -- Dev helpers
    --------------------------------------------------
    GameBalance.DEV_SPAWN_RADIUS = GameBalance.DEV_SPAWN_RADIUS or 200.0
    GameBalance.DEV_SOUL_TEST_ID = GameBalance.DEV_SOUL_TEST_ID or FourCC("n001")

    --------------------------------------------------
    -- Spell unlocks (define with string keys, normalize to numeric)
    --------------------------------------------------
    local RAW = function(k)
        if type(k) == "number" then return k end
        if type(k) == "string" and #k == 4 then return FourCC(k) end
        return k
    end

    local SPELLS_BY_UNIT_STRKEY = {
        -- GOKU (H000)
        H000 = {
            { name="Kamehameha",          abil="A006", need={ pl_min=1,  sl_min=1 } },
            { name="Kaioken",             abil="A019", need={ pl_min=3,  sl_min=2 } },
            { name="Solar Flare",         abil="A02A", need={ pl_min=2,  sl_min=1 } },
            { name="Earth's Protector",   abil="A018", need={ pl_min=6,  sl_min=2 } },
            { name="Spirit Bomb",         abil="A001", need={ pl_min=10, sl_min=3, tier_min=1 } },
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=4,  sl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1,  sl_min=0, passive=true } },
        },

        -- VEGETA (H002)
        H002 = {
            { name="Big Bang Attack",       abil="A01X", need={ pl_min=6,  sl_min=2 } },
            { name="Final Flash",           abil="A020", need={ pl_min=8,  sl_min=2 } },
            { name="Final Explosion",       abil="A021", need={ pl_min=10, sl_min=3, tier_min=1 } },
            { name="Galaxy Breaker",        abil="A01W", need={ pl_min=7,  sl_min=2 } },
            { name="Saiyan Pride",          abil="A01Y", need={ pl_min=3,  sl_min=1, passive=true } },
            { name="Savage Strike",         abil="A015", need={ pl_min=2,  sl_min=1 } },
            { name="Energy Blast Volley",   abil="A01Z", need={ pl_min=4 } },
            { name="Training Focus",        abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- PICCOLO (H008)
        H008 = {
            { name="Stretch Limb",       abil="A2PS", need={ pl_min=2,  sl_min=1 } },
            { name="Demon Wave",         abil="A022", need={ pl_min=3,  sl_min=1 } },
            { name="Hellzone Grenade",   abil="A026", need={ pl_min=7,  sl_min=2 } },
            { name="Lightzone Grenade",  abil="A024", need={ pl_min=5,  sl_min=2 } },
            { name="Multi-Form",         abil="A025", need={ pl_min=6,  sl_min=2 } },
            { name="Training Focus",     abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- GOHAN (H00B)
        H00B = {
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- MAJIN BUU (H009)
        H009 = {
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- NARUTO (H00C)
        H00C = {
            { name="Training Focus", abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- SAKURA (H00D)
        H00D = {
            { name="Cherry Blossom Impact", abil="A02B", need={ pl_min=2, sl_min=1 } },
            { name="Training Focus",        abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- AGUMON (H00E)
        H00E = {
            { name="Claw Attack",   abil="A02D", need={ pl_min=1 } },
            { name="Pepper Breath", abil="A02C", need={ pl_min=2, sl_min=1 } },
        },

        -- GABUMON (H00F)
        H00F = {
            { name="Training Focus", abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- CHARMANDER (H00H)
        H00H = {
            { name="Training Focus", abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- SQUIRTLE (H006)
        H006 = {
            { name="Training Focus", abil="A01J", need={ pl_min=1, passive=true } },
        },

        -- LOST SOUL (H001) 
        H001 = {
            { name="Soul Spirit",  abil="A000", need={ sl_min=0, passive=true } },
            { name="Spirit Vortex", abil="A0SV", need={ sl_min=4 } },
            { name="Spirit Burst",  abil="A002", need={ sl_min=8 } },
            { name="Soul Strike", abil="A003", need={ sl_min=15, passive=true } },
        },

        -- CAPSULE BAG (H003)
        H003 = {
            { name="Training Focus", abil="A01J", need={ pl_min=1, passive=true } },
        },
    }

    -- Normalize to numeric FourCC keys
    GameBalance.SPELL_UNLOCKS_BY_UNIT = {}
    for k, v in pairs(SPELLS_BY_UNIT_STRKEY) do
        GameBalance.SPELL_UNLOCKS_BY_UNIT[RAW(k)] = v
    end

    function GameBalance.GetSpellUnlocksByUnit()
        return GameBalance.SPELL_UNLOCKS_BY_UNIT
    end
end

if Debug and Debug.endFile then Debug.endFile() end
