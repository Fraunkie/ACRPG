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
    SPAWN        = { x = 28797.1,  y = 27785.0,  z = 597.2 }, -- default spawn
}

-- ---------- Zone coordinates ----------
GameBalance.ZONE_COORDS = GameBalance.ZONE_COORDS or {
    SPIRIT_REALM = { x = 26968.9, y = 26138.7, z = 247.4 },
}

-- ---------- Teleport node IDs + pretty names ----------
GameBalance.TELEPORT_NODE_IDS = GameBalance.TELEPORT_NODE_IDS or {
    YEMMA        = "YEMMA",
    KAMI_LOOKOUT = "KAMI_LOOKOUT",
    SPIRIT_REALM = "SPIRIT_REALM",
}
-- alias
GameBalance.TELEPORT_NODE_IDS.HFIL = GameBalance.TELEPORT_NODE_IDS.HFIL or "HFIL"

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

-- ---------- Power gates (examples) ----------
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

-- ---------- Bag follow (visual only; ignored by combat and loot) ----------
GameBalance.BAG = GameBalance.BAG or {
    CHECK_INTERVAL = 0.5,
    MAX_DISTANCE   = 400.0,
    FX_ON_SNAP     = "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportTarget.mdl",
}

-- ---------- Yemma Intro prompt ----------
GameBalance.YEMMA_DESK_POINT        = GameBalance.YEMMA_DESK_POINT        or { x = 28853.2, y = 28777.6 }
GameBalance.YEMMA_PROMPT_RADIUS     = GameBalance.YEMMA_PROMPT_RADIUS     or 300.0
GameBalance.YEMMA_PROMPT_MIN_RADIUS = GameBalance.YEMMA_PROMPT_MIN_RADIUS or 400.0

-- ---------- Icons / tooltips / SFX ----------
GameBalance.ICON_CREATE_SOUL = GameBalance.ICON_CREATE_SOUL or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_SKIP        = GameBalance.ICON_SKIP        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_FULL        = GameBalance.ICON_FULL        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"
GameBalance.ICON_MINI        = GameBalance.ICON_MINI        or "ReplaceableTextures\\CommandButtons\\BTNUsedSoulGem.blp"

GameBalance.TOOLTIP_SKIP_TITLE = GameBalance.TOOLTIP_SKIP_TITLE or "Skip Intro"
GameBalance.TOOLTIP_SKIP_BODY  = GameBalance.TOOLTIP_SKIP_BODY  or "Skip the cinematic and begin your journey now.|nUnlocks HFIL teleport and Yemma's quest page."
GameBalance.SFX_SKIP_CLICK     = GameBalance.SFX_SKIP_CLICK     or "Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl"
GameBalance.SFX_FULL_CLICK     = GameBalance.SFX_FULL_CLICK     or "Abilities\\Spells\\Items\\TomeOfRetraining\\TomeOfRetrainingCaster.mdl"

-- ---------- Soul / Spirit tuning ----------
-- NOTE: Soul XP per-kill is read from HFIL_UnitConfig rows (baseSoul).
--       This fallback is only used if a unit type has no config row.
GameBalance.XP_PER_KILL_BASE = 10

-- Spirit Drive (rage) – per our latest tuning:
GameBalance.SD_ON_HIT        = 8      -- +SD per landed hit
GameBalance.SD_ON_KILL       = 10     -- bonus on kill
GameBalance.SD_MAX_DEFAULT   = 100

-- OOC drain
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

--==================================================
-- Respawn / Elite / Threat knobs (added; merge-safe)
--==================================================
do
    local function ensureTable(tbl, k)
        if type(tbl[k]) ~= "table" then tbl[k] = {} end
        return tbl[k]
    end
    local function ensure(tbl, k, v)
        if tbl[k] == nil then tbl[k] = v end
        return tbl[k]
    end
    local function mergeDefaults(dst, defaults)
        for k, v in pairs(defaults) do
            if type(v) == "table" then
                ensureTable(dst, k)
                mergeDefaults(dst[k], v)
            else
                if dst[k] == nil then dst[k] = v end
            end
        end
    end

    -- Default profile set (only fills missing keys)
    local DEFAULT_RESPAWN_PROFILES = {
        Default           = { delay = 10.0, jitter = 4.0, batch = 2, throttlePerSec = 8 },
        HFIL_Starter      = { delay = 10.0, jitter = 4.0, batch = 2, throttlePerSec = 8 },
        Overworld_Default = { delay = 22.0, jitter = 6.0, batch = 3, throttlePerSec = 6 },
        Dungeon_NoTrash   = { delay = 9999.0, jitter = 0.0, batch = 0, throttlePerSec = 0 },
        Dungeon_Wipe      = { delay = 28.0,   jitter = 6.0, batch = 4, throttlePerSec = 4 },
        Trial_Phase1      = { delay = 14.0, jitter = 4.0, batch = 3, throttlePerSec = 6 },
        Trial_Phase2      = { delay = 18.0, jitter = 5.0, batch = 3, throttlePerSec = 5 },
        Trial_Phase3      = { delay = 24.0, jitter = 6.0, batch = 2, throttlePerSec = 4 },
    }

    local DEFAULT_ELITE_CONFIG = {
        defaultChance        = 2,     -- percent
        hpX                  = 3.0,   -- HP multiplier
        dmgX                 = 1.5,   -- damage multiplier
        eliteCapPerZone      = 12,
        eliteCapPerCamp      = 1,
        eliteCooldownPerCamp = 90,    -- seconds
        scale                = 1.10,
        nameTagPrefix        = "[Elite] ",
        rewardSoulMult       = 2.0,
        rewardLootTierBonus  = 1,
        rewardChestChanceBonus = 15,  -- percent
    }

    local DEFAULT_THREAT_CONFIG = {
        Elite = {
            dmgMult     = 2.0,
            abilityMult = 1.5,
            healerMult  = 1.25,
        },
        Spawn = {
            basePing      = 15,
            enablePing    = true,
            graceSuppress = true,
        },
        Pack = {
            leaderAuraThreatBonus = 0.10,
            linkFocus             = true,
        },
        Taunt = {
            eliteStickBonus = 1.5,
            eliteResistAfter= 1.0,
        },
    }

    GameBalance.RespawnProfiles = GameBalance.RespawnProfiles or {}
    GameBalance.EliteConfig     = GameBalance.EliteConfig     or {}
    GameBalance.Threat          = GameBalance.Threat          or {}

    mergeDefaults(GameBalance.RespawnProfiles, DEFAULT_RESPAWN_PROFILES)
    mergeDefaults(GameBalance.EliteConfig,     DEFAULT_ELITE_CONFIG)
    mergeDefaults(GameBalance.Threat,          DEFAULT_THREAT_CONFIG)

    -- Zone → default profile mapping (controllers can switch these at runtime)
    GameBalance.ZoneRespawnProfile = GameBalance.ZoneRespawnProfile or {}
    local Z = GameBalance.ZoneRespawnProfile
    if Z.HFIL       == nil then Z.HFIL       = "HFIL_Starter" end
    if Z.OVERWORLD  == nil then Z.OVERWORLD  = "Overworld_Default" end
    if Z.DUNGEON    == nil then Z.DUNGEON    = "Dungeon_NoTrash" end
    if Z.TRIAL      == nil then Z.TRIAL      = "Trial_Phase1" end
end

OnInit.final(function()
    if InitBroker and InitBroker.SystemReady then
        InitBroker.SystemReady("GameBalanceConfig")
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
