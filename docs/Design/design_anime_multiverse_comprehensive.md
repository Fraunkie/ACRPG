# DESIGN: Anime Multiverse RPG — Comprehensive Reference

A single, master reference document containing every design decision, system specification, data model, implementation notes, and sample API calls we discussed. Keep this as the authoritative source while you implement and iterate.

---

# 1. Project Overview

This project is an anime-multiverse RPG built in Warcraft 3 custom maps. Players begin as lost souls in the Spirit Realm (HFIL), grow via a Soul Energy system and a stat system, then permanently tier up into iconic hero forms (Goku, Vegeta, Agumon, Charmander, Naruto, etc.). The map is designed around modular world zones that each reflect a different anime universe.

Goals

- Fast, responsive combat with persistent permament evolution.
- Soul-driven progression rather than traditional XP levels.
- Modular shard families for future expansion across multiple anime worlds.
- Multiplayer safe, save and load ready.

---

# 2. Area: Spirit Realm (HFIL)

Overview

HFIL is the tutorial and permanent starting zone. Visuals should evoke a half-purgatory, half-training ground atmosphere. The player starts as a wisp with minimal stats and no equipment. HFIL is also the testing ground for the Ascension Gate and the Soul Resonance loop.

Key world objects and actors

- Wandering Spirits: common mobs that drop Soul Fragments and small amounts of Soul Energy.
- Vengeful Wraiths: fast, evasive enemies that drop shards fragments occasionally.
- Spirit Guardian: mini-boss that seals the Ascension Gate until defeated.
- The Gate: Ascension portal that opens once world and player conditions are met.
- King Yemma Check-In Station: death check-in hub after leaving HFIL.

Encounters and pacing

- Early loops emphasize killing many weak spirits to accumulate Soul Energy and fragments.
- Elite spawns and dynamic events periodically increase challenge and shard fragment drops.

---

# 3. Core Systems (High Level)

List of systems and how they interact

- Character Creation: spawns the Lost Soul and initializes PLAYER_DATA. Calls StatSystem initialization.
- Player Data: single global table per player that holds hero, tier, role, power level, energy, inventory references, and flags.
- Hero Stat System: base stats, multiplier framework, automatically updates WC3 hero attributes, and writes a computed power level into PLAYER_DATA.
- Soul Energy System: resource that players earn by combat and events. Drives Soul Resonance and gates.
- Drop System: loot tables for mobs, elites, and bosses. Provides shards and shard fragments.
- Shard System: families of shards representing anime lineages. Used as catalysts for tier-up and fusion mechanics.
- Ascension / Tier System: permanent transformations triggered by Soul Resonance, shard catalysts, and the Ascension Gate ritual.
- Respawn & Dynamic Events: world liveliness management, elite roll spawn modifiers, event triggers.
- Bag System: player storage object that follows the hero and can hold loot and quest items.
- Hubs: Kami's Lookout, Popo, Bulma's Capsule Corp. Provide teleports, vendors, and special services.
- Save / Load: persistent storage of PLAYER_DATA and lineage data across sessions.

---

# 4. Player Data Model

Canonical single-table model for all player state. Store this globally as PLAYER_DATA.

Schema (per player index)

- hero: unit handle or nil
- tier: integer (0 equals Lost Soul)  
- role: string ("NONE", "TANK", "DPS", "HEALER")
- zone: string
- powerLevel: integer (STR + AGI + INT final values)  
- energy: integer (Soul Energy)  
- ownedShards: table of shard ids and counts  
- inventory: table of item ids or references  
- saveCode: string (for save/load)  
- isInitialized: boolean  
- lineageCount: integer (account legacy)

Implementation notes

- Initialize PLAYER_DATA entries for all players during map init.  
- Always access with safety checks: PLAYER_DATA[playerId] and PLAYER_DATA[playerId].hero.

Example initialization pseudo snippet

```
if not PLAYER_DATA then PLAYER_DATA = {} end
for i = 0, bj_MAX_PLAYERS - 1 do
  PLAYER_DATA[i] = PLAYER_DATA[i] or defaultPlayerTable()
end
```

---

# 5. Hero Stat System (Design)

Purpose

- Replace classic Warcraft 3 leveling with a stat multiplier driven system. Base stats are Strength, Agility, Intelligence. Multipliers come from shards, items, buffs, and ascension.

Formula

- finalStat = floor(baseStat * statMultiplier * globalMultiplier)
- powerLevel = finalStr + finalAgi + finalInt

Design choices

- Use a per-player multiplier table for strength, agility, intelligence and a global multiplier.  
- Update hero attributes on a fixed interval (example 0.4 seconds) to reflect changes quickly.  
- Persist base stats in arrays like PlayerBaseStr[playerId] and computed values in PlayerMStr[playerId]. These remain internal to the stat system.  

Integration with PLAYER_DATA

- StatSystem writes computed powerLevel back to PLAYER_DATA[playerId].powerLevel on each update.
- Character creation calls StatSystem.InitializeHeroStats(playerId).

Public API proposed

- HeroStatSystem.InitializeHeroStats(playerId)
- HeroStatSystem.SetPlayerBaseStat(playerId, statName, value)
- HeroStatSystem.AddPlayerBaseStat(playerId, statName, amount)
- HeroStatSystem.SetPlayerStatMultiplier(playerId, statName, multiplier)
- HeroStatSystem.GetPowerLevel(playerId)

Implementation notes

- Ensure PlayerBaseStr, PlayerBaseAgi, PlayerBaseInt exist before use by initializing them early.  
- Example defaults: base Str 2, Agi 2, Int 2 for Lost Soul.  

---

# 6. Soul Energy System

Purpose

- Tracks a resource called Soul Energy that players gain from combat, events, and quests. It powers both permanent stat increases and eligibility to challenge the Ascension Gate.

Mechanics

- Each mob grants a Soul Energy amount on death. Bosses and events grant larger chunks.  
- Soul Resonance threshold: once a player reaches a configured energy threshold, the player receives a UI message "You have enough power to challenge your inner self" and a player flag is set CanChallengeAscension = true.
- Soul Energy can be spent for small stat purchases or saved for ascension catalysts.  
- On death in HFIL a portion of Soul Energy may be lost to encourage caution.

UI

- Show a Soul Energy bar or floating text. Use a hybrid system where an XP bar is repurposed as a soul energy visual meter if you want the instant feedback of a bar.  

---

# 7. Ascension and Tier-Up System

Design overview

- Players must meet three conditions to attempt Ascension:  
  1. Soul Energy threshold reached.  
  2. Spirit Guardian for the zone defeated (world flag).  
  3. Player holds a relevant Spirit Shard in inventory for the form they want to awaken.

Flow

1. Player receives Soul Resonance alert.  
2. Player travels to the Gate and interacts.  
3. The system teleports them to a private Ascension arena containing an inner trial or 1v1 guardian.  
4. On win the shard dissolves, the player's unit model and stats update permanently to the new hero form, and the player is teleported to King Yemma.  
5. On fail the player returns with a small penalty or cooldown.

Tier and Sub-Tier rules

- Four main tiers: Tier 1 Awakened, Tier 2 Ascended, Tier 3 Legendary, Tier 4 Transcendent.  
- Each main tier provides large stat increases and at least one new ability slot.  
- Sub-Tiers A, B, C provide minor stat bumps and variation. Use sub-tiers to express canonical intermediate transformations (for example Super Saiyan 1.5) without giving massive spikes.

Balancing rules

- Make total final power at Tier 4 broadly equivalent across different heroes by scaling base stats and ability strengths.  
- Favorite approach: main tier increases scale as multiplicative factors on base stats, while sub-tiers are additive small gains.  

---

# 8. Spirit Shards and Families

Overview

- Shards are the collectible currency that define hero lineages. Each zone contributes one or more shard families: Saiyan Shards, Digi Shards, Poke Shards, Chakra Shards, Divine Shards, Spirit Cores.

Shard mechanics

- Shard acquisition: boss drops, raid rewards, shard fragments from elites or events, Popo or Bulma synthesis.  
- Shard fragments can be combined into full shards at hubs.  
- Shard families have base attributes and fusion compatibilities.  

Fusion rules and examples

- Not all families fuse. Define compatibility graph.  
- Example fusions: Saiyan plus Chakra -> God Ki Hybrid. Digi plus Poke -> Elemental Digivolution.
- Fusions are expensive and performed at Bulma's lab or Popo's shrine. They grant hybrid tiers or special passives.

---

# 9. Combat Roles and Ascension Bonuses

Roles

- Tanks: primary stats Strength and Vitality. Function focus: damage soak, taunt, crowd control.  
- DPS: primary stats Strength plus Agility or Intelligence, depending on hero archetype. Focus on burst and sustained damage.  
- Healers and Support: primary stat Intelligence, focus on heals, shields, and party buffs.

Role-based tier bonuses (example table)

Tanks

- Tier 1 to Tier 2: plus 25 percent max HP and plus 10 armor, unlock Defender's Resolve passive (small damage reduction aura).  
- Tier 2 to Tier 3: plus 20 percent threat generation, unlock Guardian Pulse AoE taunt.  
- Tier 3 to Tier 4: plus 30 percent HP regen and unlock Unbreakable (knockback immunity after ultimate).  
- Sub-tiers: small per-sub-tier armor or block gains.

DPS

- Tier 1 to Tier 2: plus 20 percent attack and plus 10 percent move speed, unlock Momentum stacking buff.  
- Tier 2 to Tier 3: plus 15 percent critical damage and restore small Soul Energy on crit.  
- Tier 3 to Tier 4: plus 20 percent skill power and Final Burst mechanic.  
- Sub-tiers: alternate finishers and combo variations.

Healers

- Tier 1 to Tier 2: plus 15 percent healing output, unlock Renewal HoT.  
- Tier 2 to Tier 3: plus 10 percent resource regen and Harmony buff.  
- Tier 3 to Tier 4: plus 20 percent healing range plus 15 percent barrier strength and Resonate Light on-death AoE heal.  
- Sub-tiers: small heal efficiency increments.

Notes on fairness

- If canonical heroes have massively different numbers of forms, use sub-tiers and alternate cosmetic-only transformations to keep core power equivalent.
- Hybrid heroes can borrow percentages from a secondary role while their main role defines most bonuses.

---

# 10. Hub Network and Teleports

Philosophy

- Teleports have no currency cost. Access is gated by a Power Level requirement. Only Popo offers raid teleports. Kami's Lookout offers zone teleports. Capsule Corp is a hub for tech and crafting.

Example thresholds

- Raditz Landing raid: Power Level 500  
- Viridian Forest: Power Level 600  
- Digi File Island: Power Level 950  
- Naruto Land of Fire: Power Level 1300

Popo and Bulma

- Popo: handles raid teleports and shard refinement services (Essence infusion, Chakra Gates).  
- Bulma: Capsule Corp provides analysis, crafting capsules, simulation chamber, scouters, and inventory upgrades.

---

# 11. Bag System

Purpose

- Provide players an invisible unit to hold inventory and follow hero. The bag repositions if it drifts outside a maximum distance.

Behavior

- Create bag on character spawn, mandatory.  
- Hide bag visually for players but keep unit handle for script usage.  
- Check bag to hero distance every half second. If distance greater than max threshold, teleport bag back to hero location and show a reposition effect.

Sample API

- BagSystem.CreateBagForPlayer(player)  
- BagSystem.RemoveBagForPlayer(player)  

---

# 12. Save / Load and Soul Lineage

Soul Lineage concept

- Each permanent awakening increases an account-level lineage counter and unlocks persistent bonuses for future characters. Hybrid fused shards count double.

Save data

For each saved character, serialize minimal fields for quick load:  
- heroId  
- tier  
- role  
- shardList  
- baseStats  
- powerLevel  
- inventory ids  

Implementation notes

- Save on major events: ascension, death, zone transfer.  
- Keep serialization compact and deterministic to avoid corruption.

---

# 13. Raid System and Replayability

Design

- Raids are special instances triggered by Popo or world events. They replicate iconic anime boss fights.  
- Allow replays in simulation chambers at Capsule Corp for training.

Balancing

- Raids should require party composition and role synergy. Use Power Level thresholds and raid modifiers to scale difficulty.

---

# 14. UX and UI Guidelines

Important UI elements

- Soul Energy Bar: show current progress toward next ascension threshold.  
- Power Level indicator: small HUD widget showing combined stat total.  
- Ascension notification: clear text and sound when threshold met.  
- Shard inventory: show shards and fragment counts in a hub UI.  
- Dev debug commands: keep chat commands for quick testing.

Performance notes

- Use player-local frames for per-player UI.  
- Avoid expensive frequent global loops; use timers with reasonable intervals.

---

# 15. Developer API and File Layout

Suggested files and responsibilities

- src/Systems/PlayerData.lua  
- src/Systems/CharacterCreation.lua  
- src/Systems/HeroStatSystem.lua  
- src/Systems/SoulEnergy.lua  
- src/Systems/DropSystem.lua  
- src/Systems/AscensionGate.lua  
- src/Systems/BagSystem.lua  
- src/Systems/PopoServices.lua  
- src/Systems/CapsuleCorp.lua  
- src/UI/UISystem.lua

Recommended saving functions and fields

- PLAYER_DATA table as canonical source of player state  
- Provide helper wrappers: PlayerData.GetHero, PlayerData.AddEnergy, PlayerData.SetTier, PlayerData.GetPowerLevel

Example helper function signatures

```
PlayerData.GetHero(playerId) -> unit or nil
PlayerData.AddEnergy(playerId, amount)
HeroStatSystem.InitializeHeroStats(playerId)
BagSystem.CreateBagForPlayer(player)
AscensionGate.TryStartAscension(playerId)
```

---

# 16. Implementation To Do List

Priority

1. Fix stat system globals and fully integrate with PLAYER_DATA.  
2. Finalize CharacterCreation and ensure the Lost Soul unit ID is H001.  
3. Implement BagSystem and hook to creation.  
4. Implement SoulEnergy with visual meter and thresholds.  
5. Add Ascension Gate flow and private arena instance creation.  
6. Add Popo and Bulma services.  
7. Implement Save / Load serialization and Soul Lineage.  

Medium

- Add raids and simulation replay.  
- Shard fusion UI and rules.  
- Capsule crafting and item fusion.

Low

- Cosmetic and audio polish.  
- Extra special transformations and eventual new anime zones.

---

# 17. Notes on Balance and Playtesting

- Balance by role and by aggregated power at Tier 4.  
- Track player feedback on grind rhythm for Soul Energy acquisition.  
- Provide catch-up mechanics for players who die or fail ascension to reduce frustration.

---

# 18. Contact and Next Steps

If you want I can split this single comprehensive design into smaller, per-system markdown files for a sprint board. Tell me which systems you want first and I will split them into separate docs.

---

End of comprehensive design reference.

