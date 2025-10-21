File: /design/heroes/dragonball/hero_piccolo.md
# 💚🛡 **PICCOLO — Namekian Sage** 🛡💚
💚💚💚──────────────────────────────────────────────────💚💚💚

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Regeneration, tactics, and protective power.  
Piccolo splits into **Kami Fusion** (Healer / Support) and **Warring Piccolo** (Tank / Controller). He is the principal healer-style Dragon Ball hero and a natural fit for squad sustain and barrier tech.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Namek Initiate | Ranged toolkit with regen basics. |
| Tier 2 | Divergence | Choose Kami Fusion or Warring Piccolo. |
| Tier 3 | Mastery | Summon synergy and enhanced regen. |
| Tier 4 | Transcendence | Grand Shield or Overgrowth regenerative ultimate. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Kami Fusion** | Support / Healer | INT, VIT | Party healing and shielding. |
| **Warring Piccolo** | Tank / Control | VIT, STR | High threat and crowd control. |

---

### 🔹 Shared Abilities
- **🌀 Stretch Limb** — *SP 100* — extended reach strike.  
  `src/Spells/Piccolo/StretchLimb.lua` — FX: `Abilities/Stretch.mdl`

- **🌱 Regeneration** — *SP 250* — passive HP regeneration scaling with SP.  
  `src/Spells/Piccolo/Regeneration.lua` — FX: `Abilities/RegenFX.mdl`

- **💥 Light Pulse** — *SP 500* — healing pulse that damages enemies.  
  `src/Spells/Piccolo/LightPulse.lua` — FX: `Abilities/Pulse.mdl`

---

### 💥 Path Abilities & Flavor

#### Kami Fusion
- **Grand Shield** — large party barrier that absorbs damage. (Tier 4)  
- **Sanctuary Bloom** — periodic heal and cleanse over area. (Tier 3)

#### Warring Piccolo
- **Earthbind** — AoE slow and root. (Tier 3)  
- **Namekian Rampart** — taunt and damage soak. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Stretch Limb | 100 | Tier 1 | Active Melee | Range 350 | 6s | STR times 0.9 | Reach strike with knockback. | `Abilities/Stretch.mdl` | `src/Spells/Piccolo/StretchLimb.lua` |
| Regeneration | 250 | Tier 2 | Passive | Self | — | Heal per second = INT times 0.2 | Base passive heal scaling with SP. | `Abilities/RegenFX.mdl` | `src/Spells/Piccolo/Regeneration.lua` |
| Light Pulse | 500 | Tier 3 | AoE | 300 radius | 12s | Damage = INT times 0.7; Heal = INT times 0.4 | Pulsing energy that heals allies and damages enemies. | `Abilities/Pulse.mdl` | `src/Spells/Piccolo/LightPulse.lua` |
| Grand Shield | 1000 | Tier 4 (Kami) | Shield | Ally group 600 | 30s | Shield = INT times 3.0 | Massive barrier for party. | `Abilities/Shield.mdl` | `src/Spells/Piccolo/GrandShield.lua` |
| Namekian Burst | 1200 | Tier 4 Ultimate | Active AoE | 800 range | 60s | Damage = STR times 2.0 plus INT times 1.0 | Massive area rupture with after-heal. | `Abilities/NamekBurst.mdl` | `src/Spells/Piccolo/NamekBurst.lua` |

---

### 🔗 Integration Notes
- **StatSystem:** Regeneration must route through StatSystem heal APIs to prevent save desync.  
- **ThreatSystem:** Warring Piccolo increases aggro appropriately using `ThreatSystem.AddThreat`.  
- **Cinematic Hook:** Grand Shield triggers protective dome cinematic.

---

### 🔁 Cross-Links & Fusion
- Contributes to `Sage Beast` fusion with Digimon lineages and offers robust support to hybrid builds.

💚💚💚──────────────────────────────────────────────────💚💚💚
