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
        NEO_CAPSULE_CITY   = { x = -24130.5, y = -17751.8, z = 196.5, facing = 180.0 },
    }

    --------------------------------------------------
    -- HUBS
    --------------------------------------------------
    local HUB_RADIUS = 300.0
    GameBalance.HUBS = GameBalance.HUBS or {
        { id = "YEMMA", x = 28856.0, y = 28929.0,z = 597.2, facing = 180.0, radius = HUB_RADIUS, ui = "hub" },
        { id = "NEO",  x = -25569.3, y = -16780.6, z = 196.5, facing = 180.0 , radius = HUB_RADIUS, ui = "hub" },
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
        YEMMA                     = "YEMMA",
        NEO_CAPSULE_CITY          = "NEO_CAPSULE_CITY",
        KAMI_LOOKOUT              = "KAMI_LOOKOUT",
        HFIL                      = "HFIL",
        RADITZ                    = "RADITZ",
        VIRIDIAN                  = "VIRIDIAN",
        FILE_ISLAND               = "FILE_ISLAND",
        LAND_OF_FIRE              = "LAND_OF_FIRE",
        VIRIDIAN_BOSS             = "VIRIDIAN_BOSS",
        DARK_DIGI                 = "DARK_DIGI",
        NINE_TAILS                = "NINE_TAILS",
    }

    GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {
        YEMMA                      = "King Yemma's Desk",
        NEO_CAPSULE_CITY           = "Neo Capsule City",
        KAMI_LOOKOUT               = "Kami's Lookout",
        HFIL                       = "HFIL",
        RADITZ                     = "Raditz Landing",
        VIRIDIAN                   = "Viridian Forest",
        FILE_ISLAND                = "File Island",
        LAND_OF_FIRE               = "Land of Fire",
    }

    --------------------------------------------------
    -- Travel requirements
    --------------------------------------------------
    GameBalance.NODE_REQS = GameBalance.NODE_REQS or {
        NEO_CAPSULE_CITY ={pl_min = 0},
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
    GameBalance.DAMAGE_TRACK_CLAMP    = GameBalance.DAMAGE_TRACK_CLAMP or 100
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
    GameBalance.POWERLEVEL_CAP = GameBalance.POWERLEVEL_CAP or 120

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
    ---ItemGlobalDroptables
    --------------------------------------------------
    GameBalance.ITEMGLOBALCHANCE_COMMON             = GameBalance.ITEMGLOBALCHANCE_COMMON or 0.2 -- 20 percent chance
    GameBalance.ITEMGLOBALCHANCE_UNCOMMON           = GameBalance.ITEMGLOBALCHANCE_UNCOMMON or 0.01 -- 1 percent chance
    GameBalance.ITEMGLOBALCHANCE_RARE               = GameBalance.ITEMGLOBALCHANCE_RARE or 0.005 -- 0.01 percent chance
    GameBalance.ITEMGLOBALDROPS                     = GameBalance.ITEMGLOBALDROPS or {
        common = {[FourCC("I00F")] = {weight = 1, zone = "HFIL" }
                    
        },

        uncommon = {[FourCC("I00H")] = { weight = 1,},
                    
        },

        rare = {[FourCC("I00C")] = { weight = 1,},
                [FourCC("I00B")] = { weight = 1,},
                [FourCC("I00O")] = { weight = 1,},
                [FourCC("I00W")] = { weight = 1,},
                [FourCC("I014")] = { weight = 1,},
                [FourCC("I015")] = { weight = 1,},
                [FourCC("I006")] = { weight = 1,},
                [FourCC("I007")] = { weight = 1,},
                [FourCC("I016")] = { weight = 1,},
        },
    }


    --------------------------------------------------
    -- Spell unlocks (define with string keys, normalize to numeric)
    --------------------------------------------------
     local RAW = function(k)
        if type(k) == "number" then return k end
        if type(k) == "string" and #k == 4 then return FourCC(k) end
        return k
    end

    local SPELLS_BY_UNIT_STRKEY = {
        -- LOST SOUL (H001)
        H001 = {
            { name="Soul Spirit",   maxlevel = 1,    abil="A000", icon = "ReplaceableTextures\\CommandButtons\\BTNSoulSpirit.blp",
                 need   =   { sl_min = 1,  checkname = "soulSpirit"},       type = "passive", tooltip = {header = "Soul Spirit",
                                                                                                        title = "Passive",
                                                                                                        description = "Basic passive increases attack and movement speed.",
                                                                                                        requirements = " Requires Soul Level 1.",
                                                                                                        damage = "Increases attack speed by 25".."%%".." and movement speed by".."%%"}},

            { name="Phantom Echo", maxlevel = 1,     abil="A0PE", icon = "ReplaceableTextures\\CommandButtons\\BTNPhantomEcho.blp",
                 need   =   { sl_min = 12,  checkname = "phantomEcho"},      type = "passive", tooltip = {header = "Phantom Echo",
                                                                                                         title = "Passive",
                                                                                                         description = "Gives bonus damage depending on total heal missing.",
                                                                                                         requirements = " Requires Soul Level 12.",
                                                                                                         damage = "Increases Energy Damage by 1 ".."%%".." for every 10 ".."%%".." missing health."}},                                            
            { name="Energy Volley", maxlevel = 1,    abil="A0CE", icon = "ReplaceableTextures\\CommandButtons\\BTNVegetaEnergyVolley.blp",
                 need   =   { sl_min = 0,  checkname = "energyVolley" },    type = "active",  tooltip = {header = "Energy Volley",
                                                                                                         title = "Active",
                                                                                                         description = "Shots a single ki blast straight ahead.",
                                                                                                         requirements = " Requires Soul Level 1.",
                                                                                                         damage = "Deals damage on hit based on Energy Damage. (Energy Damage * 2)"}},  -- Active spell
            { name="Spirit Vortex", maxlevel = 1,    abil="A0SV", icon = "ReplaceableTextures\\CommandButtons\\BTNSpiritVortex.blp",
                 need   =   { sl_min = 3,  checkname = "spiritVortex" },    type = "active",  tooltip = {header = "Spirit Vortex",
                                                                                                         title = "Active",
                                                                                                         description = "Creates orbs that rotate around the user and each orb can be fired"..
                                                                                                                       "towards closest target in range.",
                                                                                                         requirements = " Requires Soul Level 3.",
                                                                                                         damage = "Deals damage on hit based on Energy Damage. Each orb = (Energy Damage * 1)"}},  -- Active spell
            { name="Spirit Burst", maxlevel = 1,     abil="A002", icon = "ReplaceableTextures\\CommandButtons\\BTNSoulBurst.blp",
                 need   =   { sl_min = 8,  checkname = "spiritBurst" },     type = "active",  tooltip = {header = "Spirit Burst",
                                                                                                         title = "Active",
                                                                                                         description = "Caster creates a aoe blast around them dealing Energy damage.",
                                                                                                         requirements = " Requires Soul Level 8.",
                                                                                                         damage = "Deals aoe damage (Energy Damage * 3)"}},  -- Active spell
            { name="Soul Strike", maxlevel = 1,      abil="A003", icon = "ReplaceableTextures\\CommandButtons\\BTNGuardianWispSpirits.blp",
                 need   =   { sl_min = 15, checkname = "soulStrike" },    type = "passive", tooltip = {header = "Soul Strike",
                                                                                                         title = "Passive",
                                                                                                         description = "Basic passive that increases soul energy gain.",
                                                                                                         requirements = " Requires Soul Level 15.",
                                                                                                         damage = "Deals damage on hit based on Energy Damage. (Energy Damage * 0.1)"}},  -- Passive spell
        }
    }
    GameBalance.TALENT_TREES = GameBalance.TALENT_TREES or {
        H001 = "LostSoul",  -- Link LostSoul hero to the LostSoul talent tree
        H000 = "Goku",      -- Link Goku hero to the Goku talent tree
        H002 = "Vegeta",    -- Link Vegeta hero to the Vegeta talent tree
        -- Add more heroes here as needed
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
