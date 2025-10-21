File: /design/heroes/dragonball/hero_cell.md
# 🧬⚗ **CELL — Bio Synth Perfection** ⚗🧬
🧬🧬🧬──────────────────────────────────────────────────🧬🧬🧬

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Absorption, adaptation, and calculated evolution.  
Cell evolves into **Perfect** (balanced hybrid), **Super Perfect** (burst with regen), and **Cell Max** (raid-scale transformation). Absorb mechanics are core to his identity.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Imperfect Cell | Absorb strike and bio spikes. |
| Tier 2 | Divergence | Choose Perfect, Super Perfect, or Cell Max. |
| Tier 3 | Mastery | Adaptive bonuses and absorptions. |
| Tier 4 | Transcendence | Final transformative overload. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Perfect** | Hybrid DPS | STR, INT | Balanced offense and sustain. |
| **Super Perfect** | Burst / Regen | INT, VIT | Strong regen with ramping damage. |
| **Cell Max** | Raid / Transformation | STR, VIT | Transform into massive form for high AoE. |

---

### 🔹 Shared Abilities
- **🤜 Absorb Slam** — *SP 100* — slam that leeches a small amount.  
  `src/Spells/Cell/AbsorbSlam.lua` — FX: `Abilities/Absorb.mdl`

- **🦠 Bio Spike** — *SP 250* — ranged spike with DoT.  
  `src/Spells/Cell/BioSpike.lua` — FX: `Abilities/Spike.mdl`

- **🛡 Adaptive Shell** — *SP 500* — temporary resist buff.  
  `src/Spells/Cell/AdaptiveShell.lua` — FX: `Abilities/Shell.mdl`

---

### 💥 Path Abilities & Flavor

#### Perfect
- **Assimilate** — heal for portion of damage done. (Tier 3)  
- **Perfect Burst** — balanced AoE and single-target focus. (Tier 4)

#### Super Perfect
- **Overgrow** — while active, massive regen and increased damage output. (Tier 3)  
- **Release** — short ultimate that dumps accumulated energy in large AoE. (Tier 4)

#### Cell Max
- **Overload Transform** — long transformation with world-scale AoE and toughness. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Absorb Slam | 100 | Tier 1 | Active Melee | 250 range | 8s | Damage = STR times 1.0; Heal = STR times 0.2 | Slam that leeches small HP. | `Abilities/Absorb.mdl` | `src/Spells/Cell/AbsorbSlam.lua` |
| Bio Spike | 250 | Tier 2 | Projectile DoT | Directional 700 | 12s | Damage per tick = INT times 0.6 | Spikes apply damage over time. | `Abilities/Spike.mdl` | `src/Spells/Cell/BioSpike.lua` |
| Adaptive Shell | 500 | Tier 3 | Buff | Self | 20s | Reduce incoming damage by INT times 0.05 | Temporary resistances. | `Abilities/Shell.mdl` | `src/Spells/Cell/AdaptiveShell.lua` |
| Perfect Burst | 1000 | Tier 4 (Perfect) | Active AoE | Self / AoE | 30s | Burst = STR times 1.5 plus INT times 1.0 | Large burst with healing on hit. | `Abilities/Burst.mdl` | `src/Spells/Cell/PerfectBurst.lua` |
| Cell Overload | 1200 | Tier 4 Ultimate | Transformation | Self | 90s | Massive stat boost and AoE | Final transformation into ultimate Cell form. | `Abilities/Overload.mdl` | `src/Spells/Cell/CellOverload.lua` |

---

### 🔗 Integration Notes
- **DamageEngine:** Absorb must be applied via AFTER hook to ensure correct healing events.  
- **ThreatSystem:** Transformations spike threat; call `ThreatSystem.ForceAggro` on transform.  
- **Cinematic Hook:** Cell Overload uses body morph and radiation FX.

---

### 🔁 Cross-Links & Fusion
- Cell is a candidate for `PsyTech Hybrid` fusions and pairs well with Mewtwo for data-bio synergies.

🧬🧬🧬──────────────────────────────────────────────────🧬🧬🧬
