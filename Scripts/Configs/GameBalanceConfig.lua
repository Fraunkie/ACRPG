if Debug and Debug.beginFile then Debug.beginFile("GameBalanceConfig.lua") end
--==================================================
-- GameBalanceConfig.lua
-- Global knobs and canonical IDs used across systems
--==================================================

if not GameBalance then GameBalance = {} end
_G.GameBalance = GameBalance

--Hero Type IDs
GameBalance.HERO_TYPES = GameBalance.HERO_TYPES or {
    SOUL  = "H001",
    GOKU  = "H000",
}

-- Hub world coordinates
GameBalance.HUB_COORDS = GameBalance.HUB_COORDS or {
    YEMMA        = { x = 28829.4,  y = 28428.0,  z = 597.2 },
    KAMI_LOOKOUT = { x = -18880.8, y = 26654.0,  z = 196.5 },
    SPAWN        = { x = 28797.1,  y = 27785.0,  z = 597.2 },
}

-- Zone coordinates
GameBalance.ZONE_COORDS = GameBalance.ZONE_COORDS or {
    SPIRIT_REALM = { x = 26968.9, y = 26138.7, z = 247.4 },
}

-- Teleport node IDs
GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {
    YEMMA        = "YEMMA",
    KAMI_LOOKOUT = "KAMI_LOOKOUT",
    SPIRIT_REALM = "SPIRIT_REALM",
}
-- Alias
if GameBalance.TELEPORT_NODE_IDS then
    GameBalance.TELEPORT_NODE_IDS.HFIL = GameBalance.TELEPORT_NODE_IDS.HFIL or "HFIL"
end

-- Pretty names for nodes
GameBalance.NODE_PRETTY = GameBalance.NODE_PRETTY or {
    YEMMA        = "King Yemma's Desk",
    KAMI_LOOKOUT = "Kami's Lookout",
    SPIRIT_REALM = "HFIL",
    HFIL         = "HFIL",
}

-- Teleport and lives
GameBalance.TELEPORT_POLICY = GameBalance.TELEPORT_POLICY or {
    YEMMA_EXIT_COSTS_LIFE = true,
    INTERACT_RADIUS       = 350.0,
    PAGE_TIMEOUT_SECONDS  = 10.0,
    INSTANCE_EJECT_DELAY  = 60.0,
    YEMMA_VISIT_SOURCES   = { LOOKOUT = true, SERVICE = true },
}

-- Lives
GameBalance.LIVES = GameBalance.LIVES or {
    STARTING_LIVES = 3,
    MAX_LIVES      = 5,
}

-- Power gates
GameBalance.POWER_REQUIREMENTS = GameBalance.POWER_REQUIREMENTS or {
    ZONES = {
        SPIRIT_REALM   = { name = "HFIL Tutorial",   power = 0    },
        VIRIDIAN       = { name = "Viridian Forest", power = 600  },
        FILE_ISLAND    = { name = "File Island",     power = 950  },
        LAND_OF_FIRE   = { name = "Land of Fire",    power = 1300 },
    },
    RAIDS = {
        RADITZ         = { name = "Raditz Landing",     power = 500  },
        VIRIDIAN_BOSS  = { name = "Viridian Guardian",  power = 900  },
        DARK_DIGI      = { name = "Dark Digivolution",  power = 1200 },
        NINE_TAILS     = { name = "Nine Tails Rampage", power = 1600 },
    },
}

-- HFIL flow
GameBalance.HFIL_FLOW = GameBalance.HFIL_FLOW or {
    AUTO_START_TUTORIAL = true,
    SHOW_TASK_PAGE      = true,
}

-- Bag follow
GameBalance.BAG = GameBalance.BAG or {
    CHECK_INTERVAL = 0.5,
    MAX_DISTANCE   = 400.0,
    FX_ON_SNAP     = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl",
}

-- Yemma Intro / desk proximity
GameBalance.YEMMA_DESK_POINT        = GameBalance.YEMMA_DESK_POINT        or { x = 28853.2, y = 28777.6 }
GameBalance.YEMMA_PROMPT_RADIUS     = GameBalance.YEMMA_PROMPT_RADIUS     or 300.0
GameBalance.YEMMA_PROMPT_MIN_RADIUS = GameBalance.YEMMA_PROMPT_MIN_RADIUS or 400.0

-- Temp icons
GameBalance.ICON_CREATE_SOUL = GameBalance.ICON_CREATE_SOUL or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_SKIP        = GameBalance.ICON_SKIP        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_FULL        = GameBalance.ICON_FULL        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_MINI        = GameBalance.ICON_MINI        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"

-- Tooltips and SFX
GameBalance.TOOLTIP_SKIP_TITLE = GameBalance.TOOLTIP_SKIP_TITLE or "Skip Intro"
GameBalance.TOOLTIP_SKIP_BODY  = GameBalance.TOOLTIP_SKIP_BODY  or "Skip the cinematic and begin your journey now.|nUnlocks HFIL teleport and Yemma's quest page."
GameBalance.SFX_SKIP_CLICK     = GameBalance.SFX_SKIP_CLICK     or "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"
GameBalance.SFX_FULL_CLICK     = GameBalance.SFX_FULL_CLICK     or "Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl"

-- ===== Simple gain knobs =====
GameBalance.XP_PER_KILL_BASE = 20     -- used only if a unit has no HFIL_UnitConfig row
GameBalance.SD_ON_HIT        = 8      -- << Spirit +8 per hit (throttled in CombatEventsBridge)
GameBalance.SD_ON_KILL       = 0      -- << no extra Spirit on kill (tune later)
GameBalance.SD_MAX_DEFAULT   = 100

-- Spirit Drive drain tuning
GameBalance.SD_OUT_OF_COMBAT_DELAY = GameBalance.SD_OUT_OF_COMBAT_DELAY or 5.0
GameBalance.SD_DRAIN_RATE          = GameBalance.SD_DRAIN_RATE          or 4.0

-- StartUI timings
GameBalance.STARTUI = GameBalance.STARTUI or {
    BUTTON_APPEAR_DELAY = 1.00,
    INPUT_DEBOUNCE      = 0.10,
}

-- Optional: coordinate fallback
GameBalance.NODE_COORDS = GameBalance.NODE_COORDS or {
    HFIL = {
        x = GameBalance.ZONE_COORDS.SPIRIT_REALM.x,
        y = GameBalance.ZONE_COORDS.SPIRIT_REALM.y,
        z = GameBalance.ZONE_COORDS.SPIRIT_REALM.z,
    },
}

if Debug and Debug.endFile then Debug.endFile() end
