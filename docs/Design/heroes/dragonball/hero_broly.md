File: /design/heroes/dragonball/hero_broly.md
# 💢🌋 **BROLY — Wrath of the Wild** 🌋💢
🌋🌋🌋──────────────────────────────────────────────────🌋🌋🌋

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Uncontrolled rage and unstoppable force.  
Broly splits into **Wrathful** (ramp rage DPS), **Legendary** (massive AoE destroyer), and **Berserker God** (prestige-level raid juggernaut).

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Unleashed | Ramp mechanics and heavy strikes. |
| Tier 2 | Divergence | Wrathful, Legendary, or Berserker God. |
| Tier 3 | Mastery | Refined rage stacking and control. |
| Tier 4 | Transcendence | Massive eruption ultimates. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Wrathful** | Rage DPS | STR, VIT | Stack-based ramping damage. |
| **Legendary** | AoE Damage | STR, INT | Area destruction and large blasts. |
| **Berserker God** | Prestige / Raid | STR, VIT | Massive boss-level form. |

---

### 🔹 Shared Abilities
- **🦶 Ground Slam** — *SP 100* — AoE stomp.  
  `src/Spells/Broly/GroundSlam.lua` — FX: `Abilities/Slam.mdl`

- **🔊 Roar of Wrath** — *SP 250* — rage stacks passive.  
  `src/Spells/Broly/RoarOfWrath.lua` — FX: `Abilities/Roar.mdl`

- **⚡ Shockwave Charge** — *SP 500* — forward charge with shockwave.  
  `src/Spells/Broly/ShockwaveCharge.lua` — FX: `Abilities/Charge.mdl`

---

### 💥 Path Abilities & Flavor

#### Wrathful
- **Rage Stacks** — build on damage taken and dealt to increase STR. (Tier 3)  
- **Savage Crush** — powerful finish that consumes stacks. (Tier 4)

#### Legendary
- **Legendary Eruption** — massive area eruption across map segment. (Tier 4)  
- **Molten Core** — leave burning area that damages over time. (Tier 3)

#### Berserker God
- **Berserker Ascend** — ultimate transform with massive stat multipliers and pushback immunity. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Ground Slam | 100 | Tier 1 | AoE | 400 radius | 10s | Damage = STR times 1.2 | Knockdown stomp. | `Abilities/Slam.mdl` | `src/Spells/Broly/GroundSlam.lua` |
| Roar of Wrath | 250 | Tier 2 | Passive | Self | — | Builds rage stacks for damage buff | Ramp mechanic on receiving or dealing damage. | `Abilities/Roar.mdl` | `src/Spells/Broly/RoarOfWrath.lua` |
| Shockwave Charge | 500 | Tier 3 | Charge AoE | Direction 600 | 18s | Damage = STR times 1.0 | Charge with shockwave. | `Abilities/Charge.mdl` | `src/Spells/Broly/ShockwaveCharge.lua` |
| Legendary Eruption | 1000 | Tier 4 (Legendary) | Massive AoE | 1000 radius | 90s | Damage = STR times 2.5 | Map-scale eruption. | `Abilities/Eruption.mdl` | `src/Spells/Broly/LegendaryEruption.lua` |
| Berserker Ascend | 1200 | Tier 4 Ultimate | Transformation | Self | 120s | Huge stat multipliers | Unstoppable rage state with massive stats. | `Abilities/Ascend.mdl` | `src/Spells/Broly/BerserkerAscend.lua` |

---

### 🔗 Integration Notes
- **StatSystem:** Rage stacks should be stored per player and applied as flat STR bonuses then recalc PowerLevel.  
- **ThreatSystem:** Berserker Ascend calls `ThreatSystem.ForceAggro` to direct enemy focus to Broly while active.  
- **Cinematic Hook:** Legendary Eruption uses high camera shake and ground cracking FX.

---

### 🔁 Cross-Links & Fusion
- Broly is a core candidate for `Legendary Saiyan Overlord` fusions and serves as raid boss template.

🌋🌋🌋──────────────────────────────────────────────────🌋🌋🌋
