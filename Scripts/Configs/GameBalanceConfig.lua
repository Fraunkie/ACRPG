if Debug and Debug.beginFile then Debug.beginFile("GameBalanceConfig.lua") end
--==================================================
-- GameBalanceConfig.lua
-- Central balance + globals used across systems
--==================================================

if not GameBalance then GameBalance = {} end
_G.GameBalance = GameBalance

do
    --------------------------------------------------
    -- Spawn / Hub coordinates
    --------------------------------------------------
    GameBalance.START_NODES = {
        SPAWN = { x = 28802.9, y = 27926.3, facing = 270.0 },
    }
    -- Back-compat aliases for older code paths
    GameBalance.SPAWN = GameBalance.START_NODES.SPAWN

    -- Hubs (add new hubs here as needed)
    GameBalance.HUB_COORDS = {
        SPAWN = GameBalance.START_NODES.SPAWN,
        -- King Yemma's Desk (hub)
        YEMMA = { x = 28853.2, y = 28777.6, facing = 180.0 },
        -- Optional placeholders; fill when ready:
        -- KAMI_LOOKOUT = { x = 0.0, y = 0.0, facing = 0.0 },
    }

    -- Legacy point used by older modules (e.g., YemmaHub)
    GameBalance.YEMMA_DESK_POINT = GameBalance.HUB_COORDS.YEMMA

    --------------------------------------------------
    -- Teleport node ids + names (lightweight seed for UIs/openers)
    --------------------------------------------------
    GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {
        YEMMA        = "YEMMA",
        KAMI_LOOKOUT = "KAMI_LOOKOUT",
        SPIRIT_REALM = "SPIRIT_REALM",
        HFIL         = "HFIL",
    }

    GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {
        YEMMA        = "King Yemma's Desk",
        KAMI_LOOKOUT = "Kami's Lookout",
        SPIRIT_REALM = "Spirit Realm",
        HFIL         = "HFIL",
    }

    -- Optional world coords for nodes (used by proximity/openers)
    GameBalance.NODE_COORDS = GameBalance.NODE_COORDS or {}
    GameBalance.NODE_COORDS.YEMMA = GameBalance.HUB_COORDS.YEMMA
    -- GameBalance.NODE_COORDS.KAMI_LOOKOUT = { x=..., y=..., z=0.0 }
    -- GameBalance.NODE_COORDS.SPIRIT_REALM = { x=..., y=..., z=0.0 }

    --------------------------------------------------
    -- Starting hero id (legacy fallback friendly)
    --------------------------------------------------
    GameBalance.START_HERO_ID = FourCC("H001")  -- replace with your real start hero if needed

    --------------------------------------------------
    -- Spirit Drive (Energy bar)
    --------------------------------------------------
    GameBalance.SPIRIT_DRIVE_MAX                = 100
    GameBalance.SPIRIT_DRIVE_ON_HIT             = 3
    GameBalance.SPIRIT_DRIVE_ON_KILL            = 10
    GameBalance.SPIRIT_DRIVE_DECAY_PER_SEC      = 2
    GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC = 6
    GameBalance.SPIRIT_DRIVE_GATE_SEC           = 0.60  -- per pid+target SD grant gate
    -- Legacy aliases for older scripts
    GameBalance.SD_ON_HIT  = GameBalance.SPIRIT_DRIVE_ON_HIT
    GameBalance.SD_ON_KILL = GameBalance.SPIRIT_DRIVE_ON_KILL

    --------------------------------------------------
    -- Souls / XP
    --------------------------------------------------
    GameBalance.XP_PER_KILL_BASE = 20
    GameBalance.SOUL_ENERGY_MULT = 1.0
    GameBalance.SOUL_SHARE_RANGE = 900.0

    --------------------------------------------------
    -- Threat / Combat scaling (stabilized)
    --------------------------------------------------
    GameBalance.THREAT_PER_DAMAGE     = 0.5   -- threat per 1 damage recorded
    GameBalance.DAMAGE_TRACK_CLAMP    = 35    -- cap any single hit fed to DPS/threat
    GameBalance.DAMAGE_RECORD_MIN_GAP = 0.20  -- ignore sub-hits inside this window per pid+target

    --------------------------------------------------
    -- Combat tunables (used by DamageResolver if present)
    --------------------------------------------------
    GameBalance.CRIT_MULT_BASE  = 1.5
    GameBalance.BLOCK_REDUCTION = 0.30

    --------------------------------------------------
    -- Ascension / Misc progression
    --------------------------------------------------
    GameBalance.ASCENSION_MIN_POWER = 25
    GameBalance.ASCENSION_MIN_TIER  = 1
    GameBalance.SPIRIT_REQ_FULL     = true

    --------------------------------------------------
    -- Power Level cap (for task scaling)
    --------------------------------------------------
    GameBalance.POWERLEVEL_CAP = GameBalance.POWERLEVEL_CAP or 20

    --------------------------------------------------
    -- Economy (Fragments)
    --------------------------------------------------
    GameBalance.FRAGMENT_PER_DUPLICATE = 5
    GameBalance.FRAGMENT_MAX           = 9999

    --------------------------------------------------
    -- Dev / Testing helpers
    --------------------------------------------------
    GameBalance.DEV_SPAWN_RADIUS = 200.0
    GameBalance.DEV_SOUL_TEST_ID = FourCC("n001")

    --------------------------------------------------
    -- HFIL Tasks Reward Config (data-driven; tweak freely)
    --------------------------------------------------
    GameBalance.HFIL_TASK_REWARDS = GameBalance.HFIL_TASK_REWARDS or {
        P_CAP = GameBalance.POWERLEVEL_CAP or 20, -- power level where scaling tops out

        KILL = {
            base = 2,            -- soul per kill at low power
            alpha = 0.8,         -- power scaling factor [0..1+]
            fragsOnComplete = 1, -- fragments granted when task completes
        },

        COLLECT = {
            base = 3,            -- soul per collected fragment at low power
            alpha = 1.0,         -- power scaling factor
            fragsOnComplete = 2, -- fragments granted when task completes
            dropChance = 0.35,   -- 35% chance n001 yields a virtual Spirit Fragment
        },

        MULTS = {
            party = 1.0,         -- optional hook for party-size multiplier
            difficulty = 1.0,    -- optional hook for difficulty profile
            trialPhase = { 1.0, 1.1, 1.2 }, -- optional extra multiplier by phase
        },
    }

    --------------------------------------------------
    -- Spell unlocks: keyed by UNIT rawcode (string)
    -- Each entry = { name, abil=ability rawcode, need={ pl_min, pl_max, sl_min, sl_max, tier_min }, role? }
    --------------------------------------------------
    GameBalance.SPELL_UNLOCKS_BY_UNIT = GameBalance.SPELL_UNLOCKS_BY_UNIT or {
        -- GOKU (H000)
        H000 = {
            { name="Kamehameha",        abil="A006", need={ pl_min=1,  sl_min=1 } },
            { name="Kaioken",           abil="A019", need={ pl_min=3,  sl_min=2 } },
            { name="Solar Flare",       abil="A02A", need={ pl_min=2,  sl_min=1 } },
            { name="Earth's Protector", abil="A018", need={ pl_min=6,  sl_min=2 } },
            { name="Spirit Bomb",       abil="A001", need={ pl_min=10, sl_min=3, tier_min=1 } },
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=4, sl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1 } },
        },

        -- VEGETA (H002)
        H002 = {
            { name="Big Bang Attack",   abil="A01X", need={ pl_min=6,  sl_min=2 } },
            { name="Final Flash",       abil="A020", need={ pl_min=8,  sl_min=2 } },
            { name="Final Explosion",   abil="A021", need={ pl_min=10, sl_min=3, tier_min=1 } },
            { name="Galaxy Breaker",    abil="A01W", need={ pl_min=7,  sl_min=2 } },
            { name="Saiyan Pride",      abil="A01Y", need={ pl_min=3,  sl_min=1 } },
            { name="Savage Strike",     abil="A015", need={ pl_min=2,  sl_min=1 } },
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=4 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1 } },
        },

        -- PICCOLO (H008)
        H008 = {
            { name="Stretch Limb",      abil="A2PS", need={ pl_min=2,  sl_min=1 } }, -- NEW
            { name="Demon Wave",        abil="A022", need={ pl_min=3,  sl_min=1 } },
            { name="Hellzone Grenade",  abil="A026", need={ pl_min=7,  sl_min=2 } },
            { name="Lightzone Grenade", abil="A024", need={ pl_min=5,  sl_min=2 } },
            { name="Multi-Form",        abil="A025", need={ pl_min=6,  sl_min=2 } },
            -- { name="Special Beam Cannon", abil="A023", need={ pl_min=4, sl_min=1 } },
            { name="Training Focus",    abil="A01J", need={ pl_min=1 } },
        },

        -- GOHAN (H00B) – placeholder
        H00B = {
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1 } },
        },

        -- MAJIN BUU (H009) – placeholder
        H009 = {
            { name="Energy Blast Volley", abil="A01Z", need={ pl_min=2 } },
            { name="Training Focus",      abil="A01J", need={ pl_min=1 } },
        },

        -- NARUTO (H00C) – placeholder
        H00C = {
            { name="Training Focus", abil="A01J", need={ pl_min=1 } },
        },

        -- SAKURA (H00D)
        H00D = {
            { name="Cherry Blossom Impact", abil="A02B", need={ pl_min=2, sl_min=1 } },
            { name="Training Focus",        abil="A01J", need={ pl_min=1 } },
        },

        -- AGUMON (H00E)
        H00E = {
            { name="Claw Attack",   abil="A02D", need={ pl_min=1 } },
            { name="Pepper Breath", abil="A02C", need={ pl_min=2, sl_min=1 } },
        },

        -- GABUMON (H00F) – placeholder
        H00F = {
            { name="Training Focus", abil="A01J", need={ pl_min=1 } },
        },

        -- CHARMANDER (H00H) – placeholder
        H00H = {
            { name="Training Focus", abil="A01J", need={ pl_min=1 } },
        },

        -- SQUIRTLE (H006) – placeholder
        H006 = {
            { name="Training Focus", abil="A01J", need={ pl_min=1 } },
        },

        -- LOST SOUL (H001)
        H001 = {
            { name="Soul Spirit", abil="A000", need={ pl_min=1 } },
            -- If A023 is actually Soul Strike for Lost Soul; otherwise move to Piccolo above:
            { name="Soul Strike", abil="A023", need={ pl_min=2 } },
        },

        -- CAPSULE BAG (H003) – utility / placeholder
        H003 = {
            { name="Training Focus", abil="A01J", need={ pl_min=1 } },
        },
    }

    -- Getter used by SpellUnlockSystem
    function GameBalance.GetSpellUnlocksByUnit()
        return GameBalance.SPELL_UNLOCKS_BY_UNIT
    end
end

if Debug and Debug.endFile then Debug.endFile() end
