if Debug and Debug.beginFile then Debug.beginFile("GameBalanceConfig.lua") end
--==================================================
-- GameBalanceConfig.lua
-- Global knobs and canonical IDs used across systems
-- • ASCII only
--==================================================

if not GameBalance then GameBalance = {} end
_G.GameBalance = GameBalance

-- ---------- Hero type IDs ----------
GameBalance.HERO_TYPES = GameBalance.HERO_TYPES or {
    SOUL = "H001",
    GOKU = "H000",
}

-- ---------- Hub world coordinates ----------
GameBalance.HUB_COORDS = GameBalance.HUB_COORDS or {
    YEMMA        = { x = 28829.4,  y = 28428.0,  z = 597.2 },
    KAMI_LOOKOUT = { x = -18880.8, y = 26654.0,  z = 196.5 },
    SPAWN        = { x = 28797.1,  y = 27785.0,  z = 597.2 },
}

-- ---------- Zone coordinates ----------
GameBalance.ZONE_COORDS = GameBalance.ZONE_COORDS or {
    SPIRIT_REALM = { x = 26968.9, y = 26138.7, z = 247.4 },
}

-- ---------- Teleport node IDs ----------
GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {
    YEMMA        = "YEMMA",
    KAMI_LOOKOUT = "KAMI_LOOKOUT",
    SPIRIT_REALM = "SPIRIT_REALM",
    HFIL         = "HFIL",
}

GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {
    YEMMA        = "King Yemma's Desk",
    KAMI_LOOKOUT = "Kami's Lookout",
    SPIRIT_REALM = "HFIL",
    HFIL         = "HFIL",
}

-- ---------- Teleport policy ----------
GameBalance.TELEPORT_POLICY = GameBalance.TELEPORT_POLICY or {
    YEMMA_EXIT_COSTS_LIFE = true,
    INTERACT_RADIUS       = 350.0,
    PAGE_TIMEOUT_SECONDS  = 10.0,
    INSTANCE_EJECT_DELAY  = 60.0,
    YEMMA_VISIT_SOURCES   = { LOOKOUT = true, SERVICE = true },
}

-- ---------- Lives ----------
GameBalance.LIVES = GameBalance.LIVES or {
    STARTING_LIVES = 3,
    MAX_LIVES      = 5,
}

-- ---------- Power gates ----------
GameBalance.POWER_REQUIREMENTS = GameBalance.POWER_REQUIREMENTS or {
    ZONES = {
        SPIRIT_REALM  = { name = "HFIL Tutorial",   power = 0    },
        VIRIDIAN      = { name = "Viridian Forest", power = 600  },
        FILE_ISLAND   = { name = "File Island",     power = 950  },
        LAND_OF_FIRE  = { name = "Land of Fire",    power = 1300 },
    },
    RAIDS = {
        RADITZ        = { name = "Raditz Landing",     power = 500  },
        VIRIDIAN_BOSS = { name = "Viridian Guardian",  power = 900  },
        DARK_DIGI     = { name = "Dark Digivolution",  power = 1200 },
        NINE_TAILS    = { name = "Nine Tails Rampage", power = 1600 },
    },
}

-- ---------- HFIL flow ----------
GameBalance.HFIL_FLOW = GameBalance.HFIL_FLOW or {
    AUTO_START_TUTORIAL = true,
    SHOW_TASK_PAGE      = true,
}

-- ---------- Bag follow ----------
GameBalance.BAG = GameBalance.BAG or {
    CHECK_INTERVAL = 0.5,
    MAX_DISTANCE   = 400.0,
    FX_ON_SNAP     = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl",
}

-- ---------- Yemma Intro ----------
GameBalance.YEMMA_DESK_POINT        = GameBalance.YEMMA_DESK_POINT        or { x = 28853.2, y = 28777.6 }
GameBalance.YEMMA_PROMPT_RADIUS     = GameBalance.YEMMA_PROMPT_RADIUS     or 300.0
GameBalance.YEMMA_PROMPT_MIN_RADIUS = GameBalance.YEMMA_PROMPT_MIN_RADIUS or 400.0

-- ---------- Icons / tooltips / SFX ----------
GameBalance.ICON_CREATE_SOUL = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_SKIP        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_FULL        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_MINI        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"

GameBalance.TOOLTIP_SKIP_TITLE = "Skip Intro"
GameBalance.TOOLTIP_SKIP_BODY  = "Skip the cinematic and begin your journey now.|nUnlocks HFIL teleport and Yemma's quest page."
GameBalance.SFX_SKIP_CLICK     = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"
GameBalance.SFX_FULL_CLICK     = "Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl"

-- ---------- Soul / Spirit tuning ----------
GameBalance.XP_PER_KILL_BASE = 10
GameBalance.SD_ON_HIT        = 8
GameBalance.SD_ON_KILL       = 10
GameBalance.SD_MAX_DEFAULT   = 100
GameBalance.SD_OUT_OF_COMBAT_DELAY = 5.0
GameBalance.SD_DRAIN_RATE          = 4.0

-- ---------- Start UI timings ----------
GameBalance.STARTUI = GameBalance.STARTUI or {
    BUTTON_APPEAR_DELAY = 1.00,
    INPUT_DEBOUNCE      = 0.10,
}

-- ---------- Optional node coord fallback ----------
GameBalance.NODE_COORDS = GameBalance.NODE_COORDS or {
    HFIL = {
        x = GameBalance.ZONE_COORDS.SPIRIT_REALM.x,
        y = GameBalance.ZONE_COORDS.SPIRIT_REALM.y,
        z = GameBalance.ZONE_COORDS.SPIRIT_REALM.z,
    },
}

-- ---------- Respawn profiles (used by CreepRespawnSystem) ----------
GameBalance.RespawnProfiles = GameBalance.RespawnProfiles or {}
GameBalance.RespawnProfiles.Default = GameBalance.RespawnProfiles.Default or {
    delay        = 10.0,
    jitter       = 4.0,
    batch        = 2,
    throttlePerSec = 8,
    eliteChance  = 10,
    eliteHpPct   = 100,
    eliteDmgAdd  = 25,
    eliteScale   = 1.20,
    elitePrefix  = "Elite ",
}

-- ---------- Spirit Drive combat timeout ----------
GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC =
    GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC
    or GameBalance.SD_OUT_OF_COMBAT_DELAY
    or 6.0

if Debug and Debug.endFile then Debug.endFile() end
