if Debug and Debug.beginFile then Debug.beginFile("CreepRespawnSystem.lua") end

--==================================================
-- CREEP RESPAWN SYSTEM
--==================================================
-- Multiplayer-safe, integrates with ThreatSystem and StatSystem.
-- Automatically registers creeps, respawns them, and applies Elite upgrades.
--==================================================

if not CreateUnit then
    print("|cFFFF0000[CreepRespawnSystem]|r Warcraft III natives not yet available.")
    if Debug and Debug.endFile then Debug.endFile() end
    return
end

if not CreepRespawnSystem then CreepRespawnSystem = {} end
_G.CreepRespawnSystem = CreepRespawnSystem

-- local logger (safe)
local function LOG(msg) if Log then Log("CreepRespawnSystem", Color.CYAN, msg) else print("[CreepRespawnSystem] "..msg) end end
local function LOG_OK(msg) if Log then Log("CreepRespawnSystem", Color.GREEN, msg) else print("[CreepRespawnSystem] "..msg) end end
local function LOG_GOLD(msg) if Log then Log("CreepRespawnSystem", Color.GOLD, msg) else print("[CreepRespawnSystem] "..msg) end end

--==================================================
-- CONFIGURATION
--==================================================
local DEFAULT_RESPAWN_TIME = 8.0
local ELITE_CHANCE = 10
local ELITE_HEALTH_BONUS = 100
local ELITE_DAMAGE_BONUS = 25 -- flat add
local ELITE_NAME_PREFIX = "Elite "
local DEBUG_ENABLED = false

--==================================================
-- INTERNAL DATA
--==================================================
local CREEP_SPAWNS = {}
local UnitSpawnPoints = {}
local ELITE_CONFIG = {}

--==================================================
-- DEBUG UTIL
--==================================================
local function DebugPrint(msg)
    if DEBUG_ENABLED then
        if Log then Log("CreepRespawnSystem", Color.GRAY, msg) else print("[CreepRespawnSystem] "..msg) end
    end
end

--==================================================
-- ELITE CONFIGURATION
--==================================================
local function InitEliteConfig()
    ELITE_CONFIG[FourCC('n001')] = { canBeElite = true,  chance = 1  }
    ELITE_CONFIG[FourCC('n002')] = { canBeElite = true,  chance = 15 }
    ELITE_CONFIG[FourCC('nban')] = { canBeElite = true,  chance = 5  }
    ELITE_CONFIG[FourCC('n003')] = { canBeElite = false, chance = 0  }
end

local function GetEliteConfig(unitType)
    local config = ELITE_CONFIG[unitType]
    if config then
        return config.canBeElite, config.chance
    end
    return true, ELITE_CHANCE
end

--==================================================
-- SAFE THREAT REGISTER
--==================================================
local function SafeRegisterEnemy(u)
    if not u or GetUnitTypeId(u) == 0 then return end
    local function doReg()
        if ThreatSystem and ThreatSystem.RegisterEnemy then
            ThreatSystem.RegisterEnemy(u)
            local td = ThreatSystem.GetUnitData and ThreatSystem.GetUnitData(u)
            if td then
                td.campX, td.campY = GetUnitX(u), GetUnitY(u)
                td.campPos = { td.campX, td.campY }
            end
        end
    end
    if ThreatSystem and ThreatSystem.RegisterEnemy then
        doReg()
    elseif InitBroker and InitBroker.OnReady then
        InitBroker.OnReady("ThreatSystem", doReg)
    end
end

--==================================================
-- CREEP CREATION
--==================================================
local function CreateCreep(spawnConfig, forceElite)
    local canBeElite, chance = GetEliteConfig(spawnConfig.unitType)
    local isElite = forceElite or (canBeElite and GetRandomInt(1, 100) <= chance)
    local creep = CreateUnit(Player(PLAYER_NEUTRAL_AGGRESSIVE), spawnConfig.unitType, spawnConfig.spawnX, spawnConfig.spawnY, spawnConfig.facing)

    if not creep then
        print("|cFFFF0000[CreepRespawnSystem]|r Failed to create creep: " .. (spawnConfig.name or "Unknown"))
        return nil
    end

    SafeRegisterEnemy(creep)

    -- Elite Upgrades
    if isElite then
        local baseName = spawnConfig.name or "Creep"
        local baseHealth = GetUnitState(creep, UNIT_STATE_MAX_LIFE)
        local healthBonus = math.floor(baseHealth * ELITE_HEALTH_BONUS / 100)
        local damageBonus = ELITE_DAMAGE_BONUS

        if StatSystem and StatSystem.AddUnitStat and StatSystem.STAT_DAMAGE then
            StatSystem.AddUnitStat(creep, StatSystem.STAT_DAMAGE, damageBonus)
        end

        BlzSetUnitMaxHP(creep, baseHealth + healthBonus)
        SetUnitState(creep, UNIT_STATE_LIFE, baseHealth + healthBonus)
        SetUnitScale(creep, 1.2, 1.2, 1.2)

        if BlzSetUnitName then
            BlzSetUnitName(creep, ELITE_NAME_PREFIX .. baseName)
        end

        AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", creep, "overhead")
        AddSpecialEffectTarget("Abilities\\Spells\\Other\\HealingSpray\\HealingSprayTarget.mdl", creep, "origin")

        local tag = CreateTextTag()
        SetTextTagText(tag, "|cFFFFD700ELITE|r", 0.024)
        SetTextTagPos(tag, spawnConfig.spawnX, spawnConfig.spawnY, 40)
        SetTextTagLifespan(tag, 3.0)

        LOG_GOLD("Elite spawned: " .. baseName)
    end

    UnitSpawnPoints[creep] = spawnConfig
    return creep
end

--==================================================
-- RESPAWN HANDLER
--==================================================
local function OnCreepDeath()
    local dying = GetTriggerUnit()
    if not dying or not UnitSpawnPoints[dying] then return end
    local spawn = UnitSpawnPoints[dying]
    UnitSpawnPoints[dying] = nil

    TimerStart(CreateTimer(), spawn.respawnTime or DEFAULT_RESPAWN_TIME, false, function()
        local new = CreateCreep(spawn)
        if new then
            DebugPrint(spawn.name .. " respawned.")
        end
        DestroyTimer(GetExpiredTimer())
    end)
end

--==================================================
-- INITIALIZATION
--==================================================
local function InitializeCreeps()
    LOG("Scanning preplaced creeps...")

    -- Scan existing neutral aggressive units
    local group = CreateGroup()
    GroupEnumUnitsOfPlayer(group, Player(PLAYER_NEUTRAL_AGGRESSIVE), nil)
    ForGroup(group, function()
        local u = GetEnumUnit()
        if not IsUnitType(u, UNIT_TYPE_STRUCTURE) and GetUnitAbilityLevel(u, FourCC('Aloc')) == 0 then
            local spawn = {
                unitType = GetUnitTypeId(u),
                spawnX = GetUnitX(u),
                spawnY = GetUnitY(u),
                respawnTime = DEFAULT_RESPAWN_TIME,
                facing = GetUnitFacing(u),
                name = GetUnitName(u)
            }
            UnitSpawnPoints[u] = spawn
            SafeRegisterEnemy(u)
            DebugPrint("Registered spawn: " .. spawn.name)
        end
    end)
    DestroyGroup(group)

    -- Trigger for deaths
    local trg = CreateTrigger()
    TriggerRegisterPlayerUnitEvent(trg, Player(PLAYER_NEUTRAL_AGGRESSIVE), EVENT_PLAYER_UNIT_DEATH, nil)
    TriggerAddAction(trg, OnCreepDeath)
end

--==================================================
-- PUBLIC API
--==================================================
function CreepRespawnSystem.AddCreepSpawn(unitType, x, y, respawnTime, facing, name)
    local spawn = {
        unitType = unitType,
        spawnX = x,
        spawnY = y,
        respawnTime = respawnTime or DEFAULT_RESPAWN_TIME,
        facing = facing or 270,
        name = name or "Creep"
    }
    table.insert(CREEP_SPAWNS, spawn)
    return spawn
end

function CreepRespawnSystem.ToggleDebug()
    DEBUG_ENABLED = not DEBUG_ENABLED
    LOG("Debug: " .. (DEBUG_ENABLED and "ON" or "OFF"))
end

--==================================================
-- TOTAL INITIALIZATION HOOK
--==================================================
OnInit.map(function()
    InitEliteConfig()
    InitializeCreeps()
    LOG_OK("Initialized.")
    if InitBroker and InitBroker.SystemReady then
        InitBroker.SystemReady("CreepRespawnSystem")
    end
end)

if Debug and Debug.endFile then Debug.endFile() end
