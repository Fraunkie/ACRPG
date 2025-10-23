# 🔥🐉 **CHARMANDER — Flame of Courage** 🐉🔥  
🔥🔥🔥──────────────────────────────────────────────────🔥🔥🔥  

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)  

---

### 🌀 Overview  
**Theme:** Courage, growth, and determination.  
Charmander embodies fiery resolve — the spark that becomes an inferno. At Tier 2 it evolves through **Flame Burst** (aggressive offense), **Blaze Heart** (sustain & retaliation), or **Mega Ember** (ultimate hybrid evolution). Each path preserves its fiery core while focusing on power escalation and self-empowerment.  

---

### 🔺 Tier Framework  
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Ember Cub | Melee fire starter; balanced close-range fighter. |
| Tier 2 | Blaze Evolved | Branches into Flame Burst, Blaze Heart, or Mega Ember. |
| Tier 3 | Inferno Adept | Gains burn-stack and explosion passives. |
| Tier 4 | Flame Champion | Unlocks iconic finisher and transformation. |

---

### 🧭 Role Variants (Paths)  
| Path | Role | Stat Focus | Theme Summary |
|------|------|------------|---------------|
| **Flame Burst** | Burst DPS | STR, AGI | High-speed fire strikes and burning explosions. |
| **Blaze Heart** | Sustain Fighter | STR, VIT | Self-heals through burns; retaliatory flames. |
| **Mega Ember** | Hybrid / Transform | STR, INT | Channelled evolutions and AoE infernos. |

---

### 🔹 Shared Abilities  
- **🔥 Ember Slash** — *SP unlock 100* — Close-range flame slash with burn DoT.  
  `src/Spells/Charmander/EmberSlash.lua` — FX: `Abilities/EmberSlash.mdl`

- **🔥🔥 Flame Wheel** — *SP unlock 250* — Spinning dash engulfed in fire; damages and knocks back enemies.  
  `src/Spells/Charmander/FlameWheel.lua` — FX: `Abilities/FlameWheel.mdl`

- **🔥💪 Blaze Aura** — *SP unlock 500* — Self buff increasing attack speed and fire power for short duration.  
  `src/Spells/Charmander/BlazeAura.lua` — FX: `Abilities/BlazeAura.mdl`

---

### 💥 Path Abilities & Flavor  

#### Flame Burst  
- **Inferno Leap** — Leap to target area, explode on impact. (Tier 3)  
- **Burnout Blast** — Releases accumulated burn stacks for burst AoE. (Tier 4)  

#### Blaze Heart  
- **Scorch Guard** — Reflects part of damage as fire; heals for each reflection. (Tier 3)  
- **Heart of Fire** — Temporary invulnerability; massive HP regen. (Tier 4)  

#### Mega Ember  
- **Solar Blaze** — Ranged beam attack using sunlight channel. (Tier 3)  
- **Mega Evolution** — Transforms into Charizard form; grants wings & breath cone. (Tier 4)  

---

### 🛠 Core 5 Technical Spec Table  

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|----------|-----------:|------|------|-----------:|----------:|----------:|-------------|----|-------------|
| Ember Slash | 100 | Tier 1 | Melee Strike | Target 150 | 5 s | STR×1.0 + INT×0.4 | Base melee burn combo. | `Abilities/EmberSlash.mdl` | `src/Spells/Charmander/EmberSlash.lua` |
| Flame Wheel | 250 | Tier 2 | Movement / AoE | Direction 400 | 10 s | STR×0.9 per hit | Rolling dash damaging enemies. | `Abilities/FlameWheel.mdl` | `src/Spells/Charmander/FlameWheel.lua` |
| Blaze Aura | 500 | Tier 3 | Buff | Self | 18 s | +15% attack / +10% fire dmg | Short-term empowerment buff. | `Abilities/BlazeAura.mdl` | `src/Spells/Charmander/BlazeAura.lua` |
| Burnout Blast | 1000 | Tier 4 (Flame) | AoE Burst | Point 350 | 25 s | INT×1.6 | Consumes burn stacks for AoE burst. | `Abilities/BurnoutBlast.mdl` | `src/Spells/Charmander/BurnoutBlast.lua` |
| Mega Evolution | 1200 | Tier 4 Ultimate | Transform | Self | 60 s | +25% all stats | Temporarily evolves into Charizard form. | `Abilities/MegaEvolve.mdl` | `src/Spells/Charmander/MegaEvolution.lua` |

---

### 🔗 Integration Notes  
- **DamageEngine:** Burn DoT uses AFTER-hook with periodic damage.  
- **StatSystem:** Apply fire buff multipliers with `StatSystem.ApplyTemporaryMultiplier`.  
- **ThreatSystem:** Flame Wheel × 1.2 threat; Burnout Blast × 1.5.  
- **FXSystem:** Use continuous fire aura `war3mapImported\FireAura.mdl`.  
- **Shard IDs:** `Shard_Charmander`, `Shard_BlazeHeart`, `Shard_Charizard`.  

---

### 🔁 Cross-Links & Fusion  
- Fuses with **Agumon** → **Elemental Digivolution** hybrid.  
- Combines with **Squirtle** → *Twin Element Overdrive* co-op skill.  

🔥🔥🔥──────────────────────────────────────────────────🔥🔥🔥  
