# 📘 **Global Soul Power Reference**

Central configuration for your **Anime Multiverse RPG**.  
All heroes, zones, and systems reference these values to ensure unified balance.

---

## ⚙️ **Soul Power System Overview**

Soul Power is the universal metric of strength, growth, and evolution.  
It determines stat scaling, ability unlocks, and access to Prestige and Fusion tiers.

---

## 💾 **GameConfig.lua Snippet**

```lua
--=====================================================
-- Global Soul Power Configuration
--=====================================================

SOUL_POWER_TIER_REQUIREMENTS = {100, 250, 500, 1000, 1200}
SOUL_POWER_HFIL_EXIT_REQUIREMENT = 500
SOUL_POWER_PRESTIGE_START = 1000000
SOUL_POWER_MAX = 1000000

SOUL_POWER_STAGE_MULTIPLIERS = {
  {threshold = 10000, multiplier = 2},
  {threshold = 100000, multiplier = 5},
  {threshold = 1000000, multiplier = 10},
}

-- Stat gain ratios per Soul Power unit
SOUL_POWER_STAT_RATIO = 0.1
STAT_MULTIPLIERS = {
  STR = 1.0,
  AGI = 1.0,
  INT = 1.0,
  VIT = 1.0
}

-- Flat Soul Energy gain values
SOUL_ENERGY_GAIN = {
  NORMAL_KILL = 25,
  ELITE_KILL = 100,
  BOSS_KILL = 250,
  QUEST_COMPLETE = 150,
  EVENT_COMPLETE = 300,
  -- PVP_KILL = 75  -- reserved for future PvP system
}

-- Abbreviation threshold for UI display
SOUL_POWER_UI_ABBREVIATION_THRESHOLD = 10000

-- Example stat gain calculation
function GetEffectiveStatGain(soulPower, baseStat)
    local multiplier = 1
    for _, stage in ipairs(SOUL_POWER_STAGE_MULTIPLIERS) do
        if soulPower >= stage.threshold then
            multiplier = stage.multiplier
        end
    end
    return baseStat + (soulPower * SOUL_POWER_STAT_RATIO * multiplier)
end
