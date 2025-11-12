# 🕯️ AREA: The Spirit Realm (HFIL)

**“Home For Infinite Losers”** — the first zone in your Dragon Ball–inspired RPG.

---

## 🌫️ Theme / Atmosphere

A desolate realm where souls of the defeated wander endlessly — half-purgatory, half-battlefield.  
Ghostly fog drifts over floating rocks illuminated by violet torches.  
The air echoes with faint screams and the pull of unfinished lives.  

The player awakens here after death — stripped of power — and must rebuild strength by battling the lost souls trapped within.

---

## 👹 Units / Enemies

All enemies are **preplaced in the map**, but fully controlled and respawned dynamically via Lua.

| Type | Name | Behavior | Notes |
|------|------|-----------|-------|
| 🧟 Common | **Wandering Spirit** | Slow melee unit, drifts toward player, groups up in packs | Basic soul fragment drops |
| 👻 Common | **Vengeful Wraith** | Fast, phasing through obstacles, fragile | Drops rare *Cursed Essence* |
| 🔱 Elite | **Spirit Guardian** | Stationary gatekeeper, AOE stun, slow respawn | Defeating it unlocks next zone |
| 💪 Mini-Boss | **Goz** | Grappler, stuns and throws the player | Drops **Ogre’s Belt** |
| ⚡ Mini-Boss | **Mez** | Fast/agile ranged spirit, uses ki blasts | Drops **Ogre’s Gloves** |

---

## ⚙️ Core Gameplay Loop

1. Player spawns in **Spirit Realm Gate** with base stats.  
2. Defeat wandering spirits to gather **Soul Fragments** (used as both currency and stat XP).  
3. Spend fragments via the **Soul Energy System** to grow stats or unlock permanent buffs.  
4. Defeat both **Goz** and **Mez** → triggers the **Gate of Judgment** event.  
5. **Spirit Guardian** spawns — defeat it to open the exit portal to the next realm.

---

## 💀 Systems Overview

### 🧩 1. Respawn System
Handles all enemy respawns and elite generation.

**Controls:**
- Respawn delay per creep type  
- Elite spawn chance modifier  
- Radius of respawn from original placement  

### 💎 2. Drop System

Manages all item drop tables and rarity weighting.

Works with preplaced and dynamic units

Elites and bosses drop special gear (e.g., Ogre’s Belt, Ogre’s Gloves)

Can later include “Cursed Items” that apply stat modifiers through the Stat System

###🌀 3. Soul Energy System (Custom Stat Growth)

Replaces the XP/level system with pure soul-based stat evolution.

Core mechanics:

Kills grant soul energy instead of experience.

When energy reaches threshold → random stat increases (+STR, +AGI, +INT).

On death, player loses a portion of current soul energy.

Visual feedback via floating text or XP bar animation.

Example:

SOUL_ENERGY.AddEnergy(playerId, soulValue)

### 🧠 4. Custom Stat System

Handles both permanent and temporary stat growth.

Functions:

Calculates HP, damage, regen, and scaling formulas.

Tracks bonus stats from gear, buffs, or soul upgrades.

Integrates directly with Soul Energy for permanent stat leveling.

Example:

STATS.Add(player, "str", 1)

### 🔮 5. Progression / Gate Triggers

Controls the flow and unlocking of the next area.

When both Goz and Mez are defeated:

Trigger Gate of Judgment Opens event.

Spawn Spirit Guardian.

Optionally play screen effect or camera shake.

Pseudocode:

if IsDead("Goz") and IsDead("Mez") then
    Spawn("SpiritGuardian")
    DisplayMessageAll("|cff80ff80Gate of Judgment Opens...|r")
end

### 🌪️ 6. Dynamic Events (Replayability)

Adds world activity and time-based challenges.

Spirit Storms: Temporarily doubles elite spawn rates and darkens the sky.

Cursed Rift: Random mini-arena event that spawns enemy waves for bonus soul fragments.

Soul Merchant (Enma Jr.): Wandering vendor trading fragments for buffs or curses.

### 📊 Progression Flow Summary

Spawn in HFIL (tutorial phase, basic stats).

Grind spirits to gather fragments → permanent stat gains via Soul Energy.

Defeat Goz + Mez → triggers Gate of Judgment.

Confront Spirit Guardian to unlock the next realm.

Portal opens → transition to Reincarnation Fields (Act II).

### 🗝️ Developer Notes

HFIL serves as both tutorial and power-reset zone.

Ideal for testing all core systems (Respawn, Soul Energy, Stat Scaling, Drops).

Systems here form the backbone of your entire RPG loop.

Once complete, new realms can reuse this framework with minimal rework.

### **Integration Example:**
```lua
SOUL_ENERGY.AddEnergy(killerId, soulValue)
DROPS.Generate(killedUnit)
