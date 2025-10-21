File: /design/heroes/dragonball/hero_buu.md
# 🍬✨ **MAJIN BUU — Sweet Devastation** ✨🍬
🍬🍬🍬──────────────────────────────────────────────────🍬🍬🍬

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Regenerative chaos and strange magic.  
Majin Buu offers varied playstyles across three paths: **Fat Buu** (healer / sustain), **Kid Buu** (pure chaos DPS), and **Super Buu** (hybrid with absorb/transform features).

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Wandering Majin | Candy beam and regen basics. |
| Tier 2 | Divergence | Choose Fat, Kid, or Super Buu. |
| Tier 3 | Mastery | Split forms and advanced mechanics. |
| Tier 4 | Transcendence | Unique metamorphosis ultimates. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Fat Buu** | Healer / Support | INT, VIT | Party heals and regeneration auras. |
| **Kid Buu** | Burst DPS | AGI, STR | Chaotic high burst AoE. |
| **Super Buu** | Hybrid | INT, STR | Spell damage plus absorb mechanics. |

---

### 🔹 Shared Abilities
- **🍭 Candy Beam** — *SP 100* — converts or stuns enemies.  
  `src/Spells/Buu/CandyBeam.lua` — FX: `Abilities/Candy.mdl`

- **❤️ Majin Regain** — *SP 250* — heal on hit passive.  
  `src/Spells/Buu/MajinRegain.lua` — FX: `Abilities/Regain.mdl`

- **🔀 Stretch Body** — *SP 500* — reposition and reach utility.  
  `src/Spells/Buu/StretchBody.lua` — FX: `Abilities/Stretch2.mdl`

---

### 💥 Path Abilities & Flavor

#### Fat Buu
- **Fat Embrace** — large party heal and long regen aura. (Tier 4)  
- **Candy Shelter** — temporary damage absorption for party. (Tier 3)

#### Kid Buu
- **Pure Chaos** — chaotic map-scale blast pattern dealing heavy damage. (Tier 4)  
- **Explosive Burst** — high mobility small bursts. (Tier 3)

#### Super Buu
- **Absorb Form** — eat and gain form-based bonuses. (Tier 3)  
- **Massive Reconfiguration** — mixed spells and rework for hybrid power. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Candy Beam | 100 | Tier 1 | Projectile | Direction 700 | 12s | Damage = INT times 0.6; plus convert duration | Converts or stuns targets. | `Abilities/Candy.mdl` | `src/Spells/Buu/CandyBeam.lua` |
| Majin Regain | 250 | Tier 2 | Passive | Self | — | Heal on hit = STR times 0.2 | Heals when dealing damage. | `Abilities/Regain.mdl` | `src/Spells/Buu/MajinRegain.lua` |
| Stretch Body | 500 | Tier 3 | Utility | Self | 10s | — | Repositioning reach. | `Abilities/Stretch2.mdl` | `src/Spells/Buu/StretchBody.lua` |
| Fat Embrace | 1000 | Tier 4 (Fat) | AoE Heal | 600 radius | 30s | Heal = INT times 2.0 | Massive party heal and regen aura. | `Abilities/FatHeal.mdl` | `src/Spells/Buu/FatEmbrace.lua` |
| Pure Chaos | 1200 | Tier 4 (Kid) | Ultimate AoE | 1000 radius | 90s | Massive burst | Random chaotic blasts across the field. | `Abilities/Chaos.mdl` | `src/Spells/Buu/PureChaos.lua` |

---

### 🔗 Integration Notes
- **StatSystem:** Majin heals and transformations must interface with SaveSystem through StatSystem for persistent HP changes.  
- **ThreatSystem:** Fat Buu healer reduces ally threat via threat dampener application.  
- **Cinematic Hook:** Fat Embrace uses soft zoom and pink aura bloom.

---

### 🔁 Cross-Links & Fusion
- Majin Buu fits Spirit Bio Core fusions and offers excellent sustain as fusion support.

🍬🍬🍬──────────────────────────────────────────────────🍬🍬🍬
