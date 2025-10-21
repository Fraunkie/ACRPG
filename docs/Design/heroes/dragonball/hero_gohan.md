File: /design/heroes/dragonball/hero_gohan.md
# 🌀🌟 **GOHAN — Potential Unleashed** 🌟🌀
🌟🌟🌟──────────────────────────────────────────────────🌟🌟🌟

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Untapped potential and academic calm harnessed into power.  
Gohan branches into **Teen Gohan** (Cell Saga burst hybrid) and **Ultimate Gohan** (Buu Saga calm support hybrid). Tier 2 triggers divergence into these paths; both maintain his hybrid INT-STR identity.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Half-Blood Saiyan | Balanced melee and ki. |
| Tier 2 | Divergence | Choose Teen or Ultimate path. |
| Tier 3 | Mastery | Path-specific passives. |
| Tier 4 | Transcendence | Signature father-son cinematic ultimate. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Teen** | Burst DPS | STR, AGI | Rage spikes and high single-target burst. |
| **Ultimate** | Support / Sustain | INT, AGI | Group buffs, controlled AoE heals and support. |

---

### 🔹 Shared Abilities
- **Ki Slash** — *SP 100* — Hybrid melee strike.  
  `src/Spells/Gohan/KiSlash.lua` — FX: `Abilities/KiSlash.mdl`

- **Masenko** — *SP 250* — Directional energy projectile.  
  `src/Spells/Gohan/Masenko.lua` — FX: `Abilities/Masenko.mdl`

- **Inner Resolve** — *SP 500* — small passive buff to skill efficiency.  
  `src/Spells/Gohan/InnerResolve.lua` — FX: `Abilities/Resolve.mdl`

---

### 💥 Path Abilities & Flavor

#### Teen
- **Rising Rage** — passive: damage increases as HP declines. (Tier 3)  
- **Rage Burst** — short window of heavy damage and attack speed. (Tier 3)  
- **Father-Son Kamehameha** — Tier 4 cooperative ultimate with Goku. (Tier 4)

#### Ultimate
- **Mystic Pulse** — AoE heal and soft damage zone. (Tier 3)  
- **Scholar's Ward** — ally cooldown reduction and minor buff aura. (Tier 3)  
- **Ultimate Focus** — long duration party buff and defensive aura. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Ki Slash | 100 | Tier 1 | Active Melee | Frontal 250 | 5s | STR times 0.8 plus INT times 0.4 | Hybrid strike. | `Abilities/KiSlash.mdl` | `src/Spells/Gohan/KiSlash.lua` |
| Masenko | 250 | Tier 2 | Projectile | Direction 900 | 12s | INT times 1.0 | Signature beam. | `Abilities/Masenko.mdl` | `src/Spells/Gohan/Masenko.lua` |
| Rising Rage | 500 | Tier 3 (Teen) | Passive | Self | — | Damage scales with missing HP | Increases damage the lower the HP. | `Abilities/RageFX.mdl` | `src/Spells/Gohan/RisingRage.lua` |
| Mystic Pulse | 500 | Tier 3 (Ultimate) | AoE | 300 radius | 12s | Heal = INT times 0.5; Damage = INT times 0.8 | Heals allies and damages enemies. | `Abilities/MysticPulse.mdl` | `src/Spells/Gohan/MysticPulse.lua` |
| Father-Son Kamehameha | 1000 | Tier 4 | Ultimate Channel | Directional 1200 | 40s | INT times 1.2 per tick | Massive channel beam; cooperative cinematic if Goku present. | `Abilities/Kamehameha.mdl` | `src/Spells/Gohan/FatherSonKamehameha.lua` |

---

### 🔗 Integration Notes
- **ThreatSystem:** Teen path increases personal threat; Ultimate path can apply threat dampeners to allies.  
- **Cinematic Hook:** Father-Son Kamehameha uses `CinematicSystem.Play("Gohan_FatherSon")` and checks for Goku nearby to trigger cooperative version.  
- **Shard IDs:** `Shard_Gohan_Teen`, `Shard_Gohan_Ultimate` to be registered.

🌟🌟🌟──────────────────────────────────────────────────🌟🌟🌟
