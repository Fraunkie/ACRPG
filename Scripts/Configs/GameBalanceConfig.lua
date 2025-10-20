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
    GameBalance.SPAWN      = GameBalance.START_NODES.SPAWN
    GameBalance.HUB_COORDS = { SPAWN = GameBalance.START_NODES.SPAWN }

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
    -- Economy (Fragments)
    --------------------------------------------------
    GameBalance.FRAGMENT_PER_DUPLICATE = 5
    GameBalance.FRAGMENT_MAX           = 9999

    --------------------------------------------------
    -- Dev / Testing helpers
    --------------------------------------------------
    GameBalance.DEV_SPAWN_RADIUS = 200.0
    GameBalance.DEV_SOUL_TEST_ID = FourCC("n001")
end

if Debug and Debug.endFile then Debug.endFile() end
