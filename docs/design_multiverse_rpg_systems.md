# DESIGN: Multiverse RPG — Systems, Zones, and Progression

A single reference document collecting all the systems, design ideas, and implementation notes we discussed. Use this as the canonical design doc for the Spirit Realm (HFIL) and the multiverse systems that expand from it.

---

# 🕯️ AREA: The Spirit Realm (HFIL)

**Home For Infinite Losers** — the first zone and tutorial for your multiverse RPG.

## Theme and Atmosphere
- Half-purgatory, half-battlefield. Floating rocks, violet torches, drifting fog and distant whispers.
- The player starts as a weak lost soul (a wisp) with minimal stats and no equipment.
- HFIL is both the tutorial and the core testbed for your major systems.

## Key Units and Encounters
All enemies are preplaced but dynamically controlled by Lua.

| Type | Name | Behavior | Notes |
|------|------|----------|-------|
| Common | Wandering Spirit | Slow melee, groups up on players | Drops Soul Fragments (currency and stat XP) |
| Common | Vengeful Wraith | Fast, phases through obstacles | Rare drops: Cursed Essence |
| Elite | Spirit Guardian | Stationary gatekeeper, AOE stun | World progression gate — must be defeated to activate Gate of Judgment |
| Mini-Boss | Goz | Grappler, stuns and throws players | Drop: Ogre's Belt |
| Mini-Boss | Mez | Agile ranged, ki blasts | Drop: Ogre's Gloves |

---

# ⚙️ Core Gameplay Loop (HFIL)
1. Player spawns at Spirit Realm Gate as a wisp with base stats.
2. Kill spirits and enemies to collect Soul Fragments and Soul Energy.
3. Use Soul Energy to unlock permanent stat increases via the Soul Energy System.
4. When progression conditions are met (see Tier-Up below), the Gate of Judgment or Ascension Gate becomes active.
5. Player performs Tier-Up ritual and is permanently transformed. Afterward, they teleport to King Yemma’s Check-In Station, and from there to Kami’s Lookout hub.

---

# 💀 System Catalog — What Every System Does
Below are the major systems, with explanations and developer notes on purpose and interactions.

## 1. Respawn System
**Purpose:** Manage enemy respawns, elite spawn rates, and preplaced versus dynamic units.

**What it does:**
- Controls per-unit respawn timers and radii from preplaced locations.
- Handles elite generation by chance modifiers and event multipliers (Spirit Storms, Cursed Rift events).
- Ensures HFIL remains lively and provides consistent Soul Fragment income.

**Developer notes:**
- Configurable table per unit type: spawn delay, elite chance, max population.
- Should expose hooks for dynamic events to temporarily modify spawn behavior.

## 2. Drop System
**Purpose:** Manage loot tables, rarity weighting, and item fusion paths.

**What it does:**
- Assigns drops to every enemy type and boss event.
- Provides rare drop pools for shards, shard fragments, and rarer catalysts.
- Supports item fusion (example: Ogre's Belt plus Ogre's Gloves -> Relic of Reincarnation).

**Developer notes:**
- Make drop tables easy to tune (weight-based lists). Avoid absolute RNG extremes.
- Add guaranteed progression drops for players that fail the Tier ritual multiple times (catch-up mechanics).

## 3. Soul Energy System
**Purpose:** Replace vanilla XP with a soul-based progression that drives tiering and stat growth.

**What it does:**
- Grants Soul Energy on kills and events. Soul Energy acts both as currency for permanent stat upgrades and as evolution fuel.
- Tracks and exposes functions like GetEnergy(playerId), AddEnergy(playerId, amount), and SpendEnergy(playerId, cost).
- Triggers Soul Resonance messages when thresholds are met.

**Developer notes:**
- Visual feedback is critical: floating text, bar UI, and aura changes.
- Players lose a portion of Soul Energy on death, reinforcing the risk element.

## 4. Custom Stat System
**Purpose:** Centralized management of STR, AGI, INT, derived stats (HP, mana, damage), and gear modifiers.

**What it does:**
- Provides stat accessors and mutators (AddStat, GetStat, ApplyModifier, RemoveModifier).
- Calculates derived stats from base stats and gear.
- Supplies Power Level calculation: Power Level = STR plus AGI plus INT.

**Developer notes:**
- Save the base stats and applied buffs separately so Power Level recalc is deterministic.
- Integrates with Soul Lineage bonuses and tier multipliers.

## 5. Progression and Gate Triggers
**Purpose:** Manage when the Gate of Judgment and other progression gates become active.

**What it does:**
- Observes world flags (e.g., Spirit Guardian defeated), player flags (Soul Resonance unlocked), and inventory (Spirit Shards).
- Activates physical world states (Gate torches, portal visuals) and player prompts to begin Tier-Up.

**Developer notes:**
- Keep world flags global but track player-specific flags for per-player eligibility in co-op.

## 6. Dynamic Events
**Purpose:** Add replayability and world variation.

**What it does:**
- Examples include Spirit Storms (increased elites), Cursed Rift (mini arena events), Soul Merchant spawns, and random elite patrols.
- Event system not only adds loot but also changes the filmic tone of the map.

**Developer notes:**
- Events should scale with average Power Level of players in the zone.
- Provide visual telegraphs to avoid surprising players unfairly.

---

# 🔥 Tier-Up System: Soul Resonance + Ascension Gate
**Core idea:** players earn permanent evolutions by combining Soul Energy thresholds, shard catalysts, and the Ascension ritual.

## Overview
- Players gain a Soul Resonance notification when they reach a Soul Energy threshold.
- Gate activation requires: Soul Resonance unlocked, the Spirit Guardian must be defeated, and the player must hold a Spirit Shard (a shard that binds the hero destiny).
- The player goes to the Ascension Gate where they perform a short ritual and face a themed challenge or an inner trial. On success they awaken into a new permanent hero form.

## Detailed Flow
1. Soul Resonance Trigger
   - When Soul Energy reaches a threshold, the player receives a UI and audio cue. A player flag CanChallengeAscension becomes true.
2. Gate Activation
   - The Gate of Judgment shows visual changes once the world flag Spirit Guardian Defeated is true.
3. Item Requirement
   - Player must have a Spirit Shard corresponding to their desired hero in inventory (Shard of Goku, Shard of Agumon, etc.).
4. Ascension Ritual
   - Player interacts with the gate and is teleported to the Ascension arena (the Gate arena or a thematic mini area).
   - Depending on the design, the challenge is either an event-based trial or a short one-on-one inner duel that represents the hero lesson.
   - Failure results in the ritual being cancelled and a minor penalty (small Soul Energy loss or timeout) but progress is not destroyed.
5. Transformation
   - On success, a cinematic plays, the shard dissolves into the player, and the player is permanently transformed to the new hero form. The player is then teleported to King Yemma’s Check-In Station.

## Design notes
- Shards act as destiny selectors. Offer both rarer direct shard drops and shard fragment systems so players can craft shards later.
- The Ascension arena should be isolated and safe to prevent external interference in co-op.

---

# 💎 Spirit Shards and Shard Families
**Summary:** Each anime world offers shard families. A shard determines hero destiny, the nature of the ascension trial, and what forms the player can reach later.

## Shard Families
| Family | Origin World | Core Energy | Function |
|--------|---------------|-------------|---------|
| Saiyan Shards | Dragon Ball | Ki energy | Drives Saiyan transformations and ascensions.
| Digi Shards | Digimon | Data energy | Enables Digivolutions and data fusion mechanics.
| Poke Shards | Pokemon | Elemental essence | Elemental evolutions and type synergy.
| Chakra Shards | Naruto | Chakra flow | Jutsu unlocks and chakra modes.
| Spirit Cores | Spirit Realm (HFIL) | Pure soul energy | Foundation shard family for first awakenings.
| Divine Shards | Kami’s Lookout | Rebirth light | Grants passive divine effects and fusion seeds.

## Example Shards (short descriptions)
- Spirit Shard of Goku: strong melee and ki focus; rare HFIL drop or event reward.
- Spirit Shard of Vegeta: precision burst archetype; hidden or event chest.
- Spirit Shard of Agumon: digital primal fighter; Digi event reward.
- Spirit Shard of Charmander: elemental fire trajectory; rare wandering elite drop.
- Spirit Shard of Naruto: chakra flow and clone mechanics; late event or quest chain.

**Shard acquisition:** mix of boss drops, event rewards, shard fragments, and Popo or Bulma synthesis recipes.

**Shard fragments:** gather fragments from mobs and raids, then use item fusion to craft a full shard.

---

# 🌍 Multiverse Shard Framework and Fusions
**Purpose:** Make shards modular and infinitely extensible across worlds.

## Core rules
- Each world introduces one shard family.
- Shards can be fused if families are compatible. Fusions create hybrid shards with combined traits.
- Fusion rules are explicit: not every family fuses with every family.

## Example fusions and results
- Saiyan plus Chakra -> God Ki Hybrid (improved scaling and Ki control).
- Digi plus Poke -> Elemental Digivolution (temporary element buffs and hybrid moves).
- Spirit plus Digi -> Spirit Bio Core (permanent HP regen and data resist).

**Developer notes:**
- Fusion costs should be high and require players to visit hubs like Popo and Bulma for specialized services.
- Fusions unlock special hybrid tier paths and count double in Soul Lineage total when created.

---

# 🌌 Hub Network: Kami’s Lookout, Mr. Popo, Capsule Corporation
A concise reference for hub responsibilities and teleportation rules.

## Teleportation Philosophy
- No currency cost. Teleports gated only by Power Level.
- Power Level equals STR plus AGI plus INT.
- Once Power Level meets or exceeds a zone or raid threshold the teleport is freely usable.

## Kami’s Lookout
**Role:** Zone teleports, narrative hub, and place to advance story-related missions.
**Function:** Teleports to major zones. Displays unlocked portals when Power Level is sufficient.

### Example zone thresholds
| Zone | Universe | Power Level Requirement |
|------|----------|-------------------------|
| Spirit Realm (HFIL) | Dragon Ball | 0 |
| Earth - Raditz Landing | Dragon Ball | 250 |
| Viridian Forest | Pokemon | 600 |
| File Island | Digimon | 950 |
| Land of Fire | Naruto | 1300 |

## Mr. Popo
**Role:** Raid teleporter, shard handler, and mystical services vendor.
**Function:** Teleports players into raid arenas if Power Level threshold is met. Offers shard services such as Essence Infusion and Chakra Gate activation.

### Example raid thresholds
| Raid | Universe | Power Level Requirement |
|------|----------|-------------------------|
| Raditz Landing | Dragon Ball | 500 |
| Viridian Guardian | Pokemon | 900 |
| Dark Digivolution | Digimon | 1200 |
| Nine-Tails Rampage | Naruto | 1600 |

## Capsule Corporation (Bulma’s Lab)
**Role:** Scientific and technological hub for crafting, analysis, and capsule items.
**Function:** Provides tech crafting, scouters, capsule inventory upgrades, simulation chamber and cross-anime research later.

**Access:** unlocked by Power Level threshold (example: 700) and available via Kami teleport.

**Planned features:**
- Crafting capsules that hold consumables, deployables, or temporary buffs.
- Stat analyzer that shows DPS and detailed power breakdowns.
- Simulation chamber for replaying raid encounters offline.

---

# 🪔 Mr. Popo — Essence Infusion and Chakra Gates
**Purpose:** Turn redundant shards into value and provide long term meta progression through gate mechanics.

## Essence Infusion
**Concept:** Popo refines duplicate shards into Essence Cores that provide permanent micro-stat upgrades or temporary burst transformations.

**Flow:**
1. Player trades duplicates or fragments to Popo.
2. Popo refines them into a consumable Essence or a reusable Essence Core.
3. Essences grant small permanent stat bonuses or one use buff-transformations.

**Example results:**
- Trade three Poke Shards -> Fire Essence (plus 2 STR and plus 1 INT permanently).
- Trade two Digi Shards -> Data Overdrive (temporary digital buff for 30 seconds).

## Chakra Gate Training
**Concept:** Popo can open spiritual gate states for a player, each gate granting a passive but risky bonus.

**Flow:**
1. Player spends shards or catalysts to unlock a Gate.
2. The Gate grants a permanent buff while active but may add a drawback (balance trade off).

**Example gates:**
- Gate of Life: increased HP regen.
- Gate of Pain: increased damage but reduced defense.
- Gate of Limit: burst movement and damage for short durations at cost of recovery time.

**Developer notes:**
- Gates should be carefully balanced and only one gate may be active at a time to avoid stacking abuse.

---

# 🧪 Capsule Corporation — Bulma’s Lab Features
**Purpose:** Provide a scientific playground for crafting, research, and useful utilities.

## Key systems
- Tech Crafting: combine shards and raid materials into capsules and devices.
- Stat Analyzer: shows exact stat break downs, energy efficiency, and power readouts.
- Portable Capsules: inventory expansion, deployable turrets or vehicles.
- Simulation Battles: optional replay and training system for raids and boss encounters.

**Example capsule items:**
- Scouter Capsule: reveals nearby hidden units and their Power Level.
- Energy Drink Capsule: temporary regen buff.
- Hover Pod Capsule: deploys a short-lived movement mount.

---

# 🔮 Soul Lineage System
**Purpose:** Provide account-level legacy progression. Each awakened soul leaves a Soul Memory that benefits future characters.

## Core mechanics
- Every permanent awakening adds to the Lineage Count.
- Lineage bonuses automatically apply when creating new characters.
- Hybrid souls (fused shards) count double toward lineage.

## Example lineage milestones and bonuses
| Lineage Count | Bonus |
|---------------|-------|
| 2 souls awakened | plus 2 base stats to all new characters |
| 4 souls awakened | Start new characters with plus 50 Soul Energy |
| 6 souls awakened | Unlock aura color customization |
| 8 souls awakened | Unlock shard fusion capability for new characters |
| 10 souls awakened | Grant special title and cosmetic options |

**Developer notes:**
- Store lineage data globally and apply it at character creation time.
- Lineage progression should feel meaningful but not mandatory for first runs.

---

# 🌟 Tier and Ascension Framework
**Purpose:** Provide a consistent evolution skeleton across all heroes while allowing deep lore forms to exist fairly.

## Main rules
- Every hero has four main Tiers: Tier 1 Awakened, Tier 2 Ascended, Tier 3 Legendary, Tier 4 Transcendent.
- Heroes with many canonical forms get Sub-Tiers inside the main Tier structure. Sub-Tiers provide smaller stat bumps and stylistic changes.
- Main Tiers deliver the big stat jumps and unlock new spells or ability slots.

## Example tiering model
- Tier 1 to Tier 2: plus 30 percent total base stats and unlock of new skill types.
- Tier 2 to Tier 3: plus 40 percent total base stats and new ultimate ability.
- Tier 3 to Tier 4: plus 60 percent total base stats and final transcendent mechanic.
- Sub-Tiers: incremental plus 5 percent stat increases and cosmetic or small passive changes.

**Developer notes:**
- Use Soul Energy thresholds and shard catalysts to gate Tiers and Sub-Tiers.
- Ensure the final Tier 4 power ends up similar across different heroes so balance is preserved.

---

# ⚡ Ascension System — The Ritual of Evolution
**Purpose:** Govern how Sub-Tier ascensions and main Tier ascensions visually and mechanically happen.

## Unlock conditions
- Soul Energy thresholds plus specific shard catalysts and a Soul Resonance level.
- Example catalysts: Saiyan Shard for Saiyan forms, Mega Stone Capsule for Pokemon mega forms, Digi Core for Digimon evolutions.

## Ascension ritual flow
1. Resonance alert: player is notified when ready.
2. Meditation at the Ascension Gate: player interacts to begin the ritual.
3. Ascension challenge: a short thematic challenge or inner trial (one-on-one inner duel or event-based test). Failure requires retry and applies a small penalty.
4. Transformation sequence: cinematic flash, model swap, aura, and new abilities activated.
5. Return: player is teleported to King Yemma for post-ascension narrative and hub access.

**Visual and audio cues:** color auras, short voice cues, camera flare, and a floating text announcing the new form.

---

# ⚔️ Combat Roles: Tank, DPS, Healer
**Purpose:** Define role identity per hero and ensure team composition matters.

## Role definitions
- Tanks: Primary stats are STR and VIT. Roles focus on survivability, threat control, and crowd control.
- DPS: Primary stats are STR and AGI or INT depending on hero. Focus on burst and sustained damage.
- Healer: Primary stat is INT with VIT secondary. Focus on heals, shields, and buffs.

## Role Ascension Bonuses (per Tier and Sub-Tier)
### Tank path sample bonuses
- Tier 1 to Tier 2: plus 25 percent max HP and plus 10 armor, unlock Defender's Resolve passive (small damage reduction aura).
- Tier 2 to Tier 3: plus 20 percent threat generation, unlock Guardian Pulse (AoE taunt on low HP trigger).
- Tier 3 to Tier 4: plus 30 percent HP regen rate and unlock Unbreakable (knockback immunity after ultimate).
- Sub-Tiers: plus 3 percent armor each and rotate defensive passive styles.

### DPS path sample bonuses
- Tier 1 to Tier 2: plus 20 percent attack and plus 10 percent move speed, unlock Momentum (stacking damage buff).
- Tier 2 to Tier 3: plus 15 percent critical damage, unlock Overflow (crit restores Soul Energy).
- Tier 3 to Tier 4: plus 20 percent skill power, unlock Final Burst (temporary massive damage when below threshold).
- Sub-Tiers: plus 3 percent attack each and unlock alternate finishers.

### Healer path sample bonuses
- Tier 1 to Tier 2: plus 15 percent healing output, unlock Renewal (heals apply small heal over time effect).
- Tier 2 to Tier 3: plus 10 percent mana regen, unlock Harmony (healing gives small ally damage buff).
- Tier 3 to Tier 4: plus 20 percent healing range and plus 15 percent barrier strength, unlock Resonate Light (on death AoE heal once per fight).
- Sub-Tiers: plus 2 percent healing each and alternate buff modes.

**Developer notes:**
- Keep totals balanced so Tier 4 heroes of any role are equally effective in their niche.
- Role based aura and fx are recommended to visually communicate role on the field.

---

# 🧭 Save / Load and Data Model
**Purpose:** Provide a minimal but robust data structure to persist player progression.

## Core fields to save
- PlayerCharacter.Table containing: HeroType, CurrentTier, SubTierLevel, RoleType, StatsBase, SoulEnergy, OwnedShards.
- GlobalLineage object containing: LineageCount, HybridUnlocks, CosmeticUnlocks.
- WorldFlags object containing major beat flags (SpiritGuardianDefeated, GateActive, etc.).

**Developer notes:**
- Keep saving atomic and infrequent to avoid IO stalls. Save on major events: ascension, death, zone change.
- Use compact serialization: integers and short strings. Avoid large verbose dumps.

---

# 🗝️ Developer To Do List (Suggested Implementation Modules)
- Core modules:
  - SoulEnergy.lua
  - StatsSystem.lua
  - RespawnManager.lua
  - DropManager.lua
  - TierUpSystem.lua
  - AscensionGate.lua
  - PopoServices.lua
  - CapsuleCorp.lua
  - LineageManager.lua
- UX and tools:
  - Ascension UI widget
  - Power Level indicator and aura preview
  - Save/Load handler

**Integration notes:**
- Follow Total Initialization patterns: delay native calls to proper OnInit phases.
- Include Debug.beginFile and Debug.endFile in each file for your debug utils.
- Do not use the percent sign character in any code or comments in project files to adhere to project constraints.

---

# Next Steps and Priorities
1. Implement SoulEnergy and StatsSystem first so other systems can query Power Level reliably.
2. Implement TierUpSystem and AscensionGate in parallel — they are tightly coupled conceptually.
3. Implement Popo services and Capsule Corp features after shards and drop systems are stable.
4. Design at least three raid templates and a replayable raid format for consistency.

---

# Endnotes
This document captures our full design conversation so far: HFIL systems, the tier and ascension framework, shard families and fusions, hub network and teleport rules, Popo and Bulma features, Soul Lineage meta progression, role integration, and developer implementation notes.

If you want this turned into separate per-system markdown files (for example a single file per feature for a code sprint), tell me which ones and I will break this into smaller docs next.

