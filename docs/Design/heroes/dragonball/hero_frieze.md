File: /design/heroes/dragonball/hero_frieza.md
# 🌌❄️ **FRIEZA — Galactic Tyrant** ❄️🌌
❄️❄️❄️──────────────────────────────────────────────────❄️❄️❄️

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Calculated cruelty and energy precision.  
Frieza branches into **Final Form** (precision assassin), **Golden Form** (overcharged burst), and **Corrupt** (debuff control). Each path explores different cruelty facets while keeping Frieza’s ranged, precise identity.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Scouter Cadet | Ranged beam toolkit. |
| Tier 2 | Divergence | Choose Final, Golden, or Corrupt. |
| Tier 3 | Mastery | Path passives. |
| Tier 4 | Transcendence | Massive beam or domain ultimate. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Final Form** | Precision DPS | AGI, INT | High accuracy, quick bursts. |
| **Golden** | Burst DPS | INT, STR | Massive overcharge and high AoE. |
| **Corrupt** | Control / Debuffer | INT, AGI | Drain and debilitate enemies. |

---

### 🔹 Shared Abilities
- **🔫 Death Beam** — *SP 100* — precision single bolt.  
  `src/Spells/Frieza/DeathBeam.lua` — FX: `Abilities/DeathBeam.mdl`

- **🌀 Tail Whip** — *SP 250* — knockback and minor slow.  
  `src/Spells/Frieza/TailWhip.lua` — FX: `Abilities/Tail.mdl`

- **🟣 Orb of Ruin** — *SP 500* — lingering damaging orb.  
  `src/Spells/Frieza/OrbOfRuin.lua` — FX: `Abilities/Orb.mdl`

---

### 💥 Path Abilities & Flavor

#### Final Form
- **Precision Strike** — crit-focused single-target spikes. (Tier 3)  
- **Micro Nova** — compact burst for quick finishers. (Tier 4)

#### Golden
- **Golden Nova** — massive area explosion. (Tier 4)  
- **Overcharge** — temporary huge damage amplifier. (Tier 3)

#### Corrupt
- **Drain Pulse** — life drain that transfers to self. (Tier 3)  
- **Corrupt Domain** — slows and weakens enemies in area. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Death Beam | 100 | Tier 1 | Projectile | Single target 1000 | 8s | INT times 1.4 | Piercing precision bolt. | `Abilities/DeathBeam.mdl` | `src/Spells/Frieza/DeathBeam.lua` |
| Tail Whip | 250 | Tier 2 | Melee Control | Melee 200 | 7s | STR times 0.8 | Knockback and slow. | `Abilities/Tail.mdl` | `src/Spells/Frieza/TailWhip.lua` |
| Orb of Ruin | 500 | Tier 3 | Area Persistent | 300 radius | 15s | INT times 0.9 per tick | Persistent damaging orb. | `Abilities/Orb.mdl` | `src/Spells/Frieza/OrbOfRuin.lua` |
| Golden Nova | 1000 | Tier 4 (Golden) | Ultimate AoE | 800 radius | 60s | INT times 2.0 | Massive golden explosion. | `Abilities/GoldenNova.mdl` | `src/Spells/Frieza/GoldenNova.lua` |
| Corrupt Drain | 1200 | Tier 4 (Corrupt) | Channel Drain | Directional 900 | 40s | Damage plus absorb = INT times 1.0 | Life drain that transfers HP to user. | `Abilities/CorruptDrain.mdl` | `src/Spells/Frieza/CorruptDrain.lua` |

---

### 🔗 Integration Notes
- **StatSystem:** Corrupt Drain must be carefully applied via DamageEngine.AFTER to credit correct healing.  
- **Cinematic Hook:** Golden Nova saturates screen color to golden hue and uses audio spike.  
- **Shard IDs:** `Shard_Frieza`, `Shard_Frieza_Golden`, etc.

---

### 🔁 Cross-Links & Fusion
- Frieza is a candidate core for `PsyTech Hybrid` fusions and provides strong control for hybrid raid builds.

❄️❄️❄️──────────────────────────────────────────────────❄️❄️❄️
