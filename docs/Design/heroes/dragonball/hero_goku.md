# ⚡🔥 **GOKU — Saiyan Lineage of Power** 🔥⚡
⚡⚡⚡──────────────────────────────────────────────────⚡⚡⚡

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Growth through combat, pure ki mastery, and transcendence.  
Goku is the archetypal Saiyan: he scales with fighting experience, unlocks signature ki arts, and branches into three distinct paths at Tier 2: **Super Saiyan** (Burst DPS), **Super Saiyan God** (Divine Support / Hybrid), and **Ultra Instinct** (Evasion / Reactive Utility). Each path retains Goku's core combat identity while offering unique team play or solo power.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Awakened Saiyan | Base kit: melee ki and basic projectile. |
| Tier 2 | Divergence | Choose one of three path transformations. |
| Tier 3 | Mastery | Path exclusive upgrades and passives. |
| Tier 4 | Transcendence | Ultimate transformation and signature ultimate. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme Summary |
|------|------|------------|---------------|
| **Super Saiyan** | Burst DPS | STR, AGI | Raw melee power, attack speed, and single target burst. |
| **Super Saiyan God** | Support / Hybrid | INT, STR | Calm divine ki that grants ally ki regeneration and controlled beams. |
| **Ultra Instinct** | Utility / Evasion | AGI, INT | Reactive dodge mechanics, counterattacks, and team evade aura. |

---

### 🔹 Shared Abilities (available before divergence)
- **💥 Ki Slash** — *Soul Power unlock: 100*  
  Short range frontal ki-infused strike that deals hybrid damage. Scales with STR and INT.  
  Script: `src/Spells/Goku/KiSlash.lua`  
  FX: `Abilities/KiSlash.mdl`

- **🔁 Energy Bounce** — *Soul Power unlock: 250*  
  Directional projectile that splits and bounces to nearby targets. Good for wave clear.  
  Script: `src/Spells/Goku/EnergyBounce.lua`  
  FX: `Abilities/EnergyBounce.mdl`

- **⚡ Surge Movement** — *Soul Power unlock: 500*  
  Blink dash that briefly grants invulnerability frames for repositioning. Works for gap closing and escape.  
  Script: `src/Spells/Goku/SurgeMovement.lua`  
  FX: `Abilities/Blink.mdl`

---

## 💥 Path Abilities & Flavor

### Super Saiyan (Burst DPS)
- **Rising Fury** — passive stacking attack rate when striking enemies. (Tier 3)
- **Golden Flare** — targeted burst AoE on activation that amplifies strike damage for a short time. (Tier 3)
- **Final Impact** — long channel finishing strike; enormous single target damage. (Tier 4)

### Super Saiyan God (Divine Support / Hybrid)
- **Ki Blessing** — aura that slowly regenerates Soul Power for allies within range. (Tier 3)
- **Divine Beam** — piercing beam that ignores a portion of enemy resistances, scales with INT. (Tier 3)
- **Sacred Surge** — team buff that increases ally skill effectiveness for a short period. (Tier 4)

### Ultra Instinct (Evasion / Utility)
- **Reflex Echo** — chance to auto-evade small attacks and create a short-lived counter window. (Tier 3)
- **Calm Counter** — reactive strike that triggers after a successful evade, dealing scaled damage and small knockback. (Tier 3-4)
- **Instinct Veil** — team-wide brief evasion aura with a visual slow-motion effect for cinematic clarity. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table (Soul Power unlocks follow global config)

| Ability | Soul Power Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|--------:|-------------------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| **Ki Slash** | 100 | Tier 1 | Active Melee | Frontal cone 300 | 5s | Damage = STR * 1.2 + INT * 0.4 | Short ki-infused slash that staggers. | `Abilities/KiSlash.mdl` | `src/Spells/Goku/KiSlash.lua` |
| **Energy Bounce** | 250 | Tier 2 | Projectile Chain | Directional 900 | 10s | Damage per hit = INT * 0.9 | Energy bolt that bounces up to 3 targets. | `Abilities/EnergyBounce.mdl` | `src/Spells/Goku/EnergyBounce.lua` |
| **Surge Movement** | 500 | Tier 3 | Utility (Blink) | Self 600 | 12s | — | Dash with brief invulnerability frames. | `Abilities/Blink.mdl` | `src/Spells/Goku/SurgeMovement.lua` |
| **Calm Counter** | 1000 | Tier 4 (Ultra Instinct path) | Passive Reactive | Self | — | Proc damage = AGI * 0.6 + INT * 0.8 | Auto-evade small attacks and counter with ki strike. | `Abilities/DodgeFX.mdl` | `src/Spells/Goku/CalmCounter.lua` |
| **Spirit Surge** | 1200 | Tier 4 Ultimate | Active Buff | Self | 60s | Duration 10s; Stats +25 listed as "plus 25 percent" | Overcharges ki: increases all stats and prevents knockback for a short time. | `Abilities/SurgeAura.mdl` | `src/Spells/Goku/SpiritSurge.lua` |

> Implementation note: describe "plus 25 percent" in code as `multiplier = 1.25` in `StatSystem.ApplyTemporaryMultiplier`.

---

### ✨ Additional Abilities (Optional / Cosmetic)
- **Father's Echo** — cooperative cinematic skill that triggers upgraded Father-Son Kamehameha if Goku and Gohan are nearby.  
- **Training Echo** — small passive that grants minor XP or Soul Power when engaging stronger enemies for the first time.

---

### 🔗 Integration Notes
- **SoulSystem:** abilities respect the global Soul Power thresholds defined in `global_soulpower_reference.md`. Abilities only register as unlocked if player Soul Power is greater or equal to the threshold.  
- **StatSystem:** primary scaling: STR primary for physical ki strikes, INT secondary for beam scaling, AGI influences hit chance and proc frequency. Use `CalculateStatBonus` from global config to recalc PowerLevel.  
- **DamageEngine:** route all ability damage through `DamageEngine.lua` hooks. Use `DamageEngine.AFTER` for post-damage effects like Soul Power awards and threat updates.  
- **ThreatSystem:** Super Saiyan Burst increases threat multipliers during Spirit Surge. God Ki path lowers ally threat when Ki Blessing is active. Use `ThreatSystem.ModifyThreat(playerId, amount)` calls.  
- **UISystem:** show ability icons and Soul Power lock markers; present unlock hint text when player crosses thresholds. Create local player frames only inside `OnInit.final()` and anchor to `ORIGIN_FRAME_GAME_UI`.  
- **CinematicSystem:** call `CinematicSystem.Play("Goku_Tier4_SpiritSurge")` on Tier 4 ascension. Add camera slow motion of 1.2 seconds and a white-silver aura pulse. Cinematics should be visual-only and not change unit control state in multiplayer.  
- **SaveSystem:** mark unlocked abilities and current path in `PLAYER_DATA[playerId].heroPath` and `PLAYER_DATA[playerId].unlockedAbilities` on ascension and logout.

---

### 🎬 Cinematic & FX Hooks
- **Tier 2 Divergence:** play a short camera zoom and golden aura bloom when the player selects a path. `CinematicSystem.Play("Goku_Divergence")`  
- **Tier 3 Mastery:** small aura flare and sound cue `audio/goku_mastery.ogg`.  
- **Tier 4 Transformation:** full-screen gold flash, 1.2 second slow motion, and a long tone; use `CinematicSystem.Play("Goku_SpiritSurge_Transform")`.  
- **Ability FX:** use the listed `Abilities/*.mdl` assets as placeholders. Replace with custom models as they are created.

---

### 🔁 Cross-Links & Fusion Synergies
- **Synergies:** Goku pairs with Gohan for cooperative cinematics. He contributes to **God Ki Hybrid** fusion recipes (e.g., Goku + Naruto).  
- **Shard IDs:** `Shard_Goku`, `Shard_Saiyan`, `Shard_Divine` should be registered in `ShardSystem.lua`.  
- **Fusion role:** God Ki Hybrid uses Goku's God Ki path as the primary Ki source.

---

### 🛠 Developer To Do (copy into your sprint)
- Add hero table `HERO_PATH_GOKU` into `src/Design/HeroPaths.lua` with path data and ability ids.  
- Create ability script stubs at the listed `src/Spells/Goku/*.lua` locations and register them with `SpellSystem.RegisterSpell`.  
- Register cinematic assets and hook names in `CinematicSystem.lua`.  
- Update `ShardSystem.lua` with `Shard_Goku` entries and drop tables for HFIL elites and boss shards.

---

⚡⚡⚡──────────────────────────────────────────────────⚡⚡⚡


