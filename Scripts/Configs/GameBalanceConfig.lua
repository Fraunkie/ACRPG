if Debug and Debug.beginFile then Debug.beginFile("GameBalanceConfig.lua") end
--==================================================
-- GameBalanceConfig.lua
-- Central config for all systems and spawn locations.
-- Safe for Warcraft III (ASCII only).
--==================================================

if not GameBalance then GameBalance = {} end
_G.GameBalance = GameBalance

----------------------------------------------------
-- GLOBAL COORDINATES / START NODES
----------------------------------------------------
-- Canonical coordinates from the map editor.
-- Everything reads from these; old names auto-map below.
GameBalance.START_NODES = GameBalance.START_NODES or {}

GameBalance.START_NODES.CREATE_BUTTON = { x = 28802.9, y = 27926.3, face = 270.0 }
GameBalance.START_NODES.HERO_SPAWN    = { x = 28802.9, y = 27926.3, face = 270.0 }
GameBalance.START_NODES.CAMERA        = { x = 28802.9, y = 27926.3, z = 597.2 }

function GameBalance.GetStartNode(name)
    if not name then return nil end
    local n = GameBalance.START_NODES and GameBalance.START_NODES[name]
    if n and type(n.x) == "number" and type(n.y) == "number" then
        return n
    end
    return nil
end

-- Legacy compat for old spawn readers
do
    local getNode = GameBalance.GetStartNode
    if getNode then
        local n = getNode("HERO_SPAWN")
        if n then
            GameBalance.SPAWN = GameBalance.SPAWN or { x = n.x, y = n.y, face = n.face or 270.0 }
            GameBalance.HUB_COORDS = GameBalance.HUB_COORDS or {}
            GameBalance.HUB_COORDS.SPAWN =
                GameBalance.HUB_COORDS.SPAWN or { x = n.x, y = n.y, face = n.face or 270.0 }
        end
    end
end

----------------------------------------------------
-- GLOBAL SETTINGS
----------------------------------------------------
-- Spirit Drive
GameBalance.SPIRIT_DRIVE_MAX                = 100
GameBalance.SPIRIT_DRIVE_DECAY_RATE         = 1                 -- used by some older scripts
GameBalance.SPIRIT_DRIVE_DECAY_PER_SEC      = GameBalance.SPIRIT_DRIVE_DECAY_RATE  -- mirror for others
GameBalance.SPIRIT_DRIVE_COMBAT_TIMEOUT_SEC = 6
GameBalance.SD_ON_HIT  = 8                                      -- gain per melee hit
GameBalance.SD_ON_KILL = 10                                     -- bonus on kill

-- Soul / XP
GameBalance.XP_PER_KILL_BASE = 10
GameBalance.SOUL_REWARD_BY_FOUR = GameBalance.SOUL_REWARD_BY_FOUR or {
    -- Example overrides:
    -- [FourCC("n001")] = 20,
    -- [FourCC("n00G")] = 20,
}

-- Respawn
GameBalance.RESPAWN = {
    baseSec     = 25.0,
    eliteBonus  = 10.0,
    maxGroups   = 3,
    eliteChance = 10,
    eliteHpPct  = 100,
    eliteDmgAdd = 25,
    eliteScale  = 1.20,
    elitePrefix = "Elite ",
}

-- Lives
GameBalance.LIVES = {
    STARTING_LIVES = 3,
    MAX_LIVES      = 5,
}

-- Loot tuning
GameBalance.LOOT = {
    goldPerSoul = 0,
    groupShare  = true,
    rarityChances = {
        Common    = 8000,
        Uncommon  = 1500,
        Rare      = 450,
        Epic      = 45,
        Legendary = 5,
    },
}

-- Shards
GameBalance.SHARDS = {
    dropBase    = 120,
    familyBonus = 25,
}

-- Yemma hub behavior
GameBalance.YEMMA = {
    SKIP_UNLOCKS_TELEPORT = true,
    SKIP_UNLOCKS_TASKS    = true,
    SHOW_TELEPORTS_FIRST  = false,
    INSTANCE_EJECT_DELAY  = 60.0,
    YEMMA_VISIT_SOURCES   = { LOOKOUT = true, SERVICE = true },
}

-- Power gates
GameBalance.POWER_REQUIREMENTS = {
    ZONES = {
        SPIRIT_REALM  = { name = "HFIL Tutorial",   power = 0 },
        VIRIDIAN      = { name = "Viridian Forest", power = 600 },
        FILE_ISLAND   = { name = "File Island",     power = 950 },
        LAND_OF_FIRE  = { name = "Land of Fire",    power = 1300 },
    },
    RAIDS = {
        RADITZ        = { name = "Raditz Landing",     power = 500 },
        VIRIDIAN_BOSS = { name = "Viridian Guardian",  power = 900 },
        DARK_DIGI     = { name = "Dark Digivolution",  power = 1200 },
        NINE_TAILS    = { name = "Nine Tails Rampage", power = 1600 },
    },
}

-- Start flow
GameBalance.START_FLOW = {
    ALLOW_SKIP      = true,
    SHOW_TITLE_PREF = true,
    SHOW_TASK_HINT  = true,
}

-- Hub travel / portals
GameBalance.TELEPORTS = {
    HUB_YEMMA      = "TP_YEMMA",
    HUB_LOOKOUT    = "TP_LOOKOUT",
    DUNGEON_RADITZ = "TP_RADITZ",
}

-- Hero types
GameBalance.HERO_TYPES = {
    SOUL = "H001",
    GOKU = "H000",
}

-- Icons and tooltips
GameBalance.ICON_CREATE_SOUL = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_SKIP        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_FULL        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_MINI        = "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"

GameBalance.TOOLTIP_SKIP_TITLE = "Skip Intro"
GameBalance.TOOLTIP_SKIP_BODY  =
    "Skip the cinematic and begin your journey now.|nUnlocks HFIL teleport and Yemma's quest page."
GameBalance.SFX_SKIP_CLICK     = "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"
GameBalance.SFX_FULL_CLICK     = "Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl"

-- Start UI timings
GameBalance.STARTUI = {
    BUTTON_APPEAR_DELAY = 1.00,
    INPUT_DEBOUNCE      = 0.10,
}

-- Zones
GameBalance.ZONES = {
    YEMMA = "YEMMA",
    HFIL  = "HFIL",
    EARTH = "EARTH",
}

----------------------------------------------------
-- COMBAT TUNING (NEW)
----------------------------------------------------
-- Scales and clamps used by CombatEventsBridge for HUD and threat.
GameBalance.THREAT_PER_DAMAGE  = GameBalance.THREAT_PER_DAMAGE or 1.0   -- threat per 1 recorded damage
GameBalance.DAMAGE_TRACK_CLAMP = GameBalance.DAMAGE_TRACK_CLAMP or 250  -- cap any single hit recorded

if Debug and Debug.endFile then Debug.endFile() end
