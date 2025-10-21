File: /design/heroes/dragonball/hero_vegeta.md
# 💥🔥 **VEGETA — Prince of Pride** 🔥💥
💥💥💥──────────────────────────────────────────────────💥💥💥

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Pride, precision, and ruthless efficiency.  
Vegeta is a calculated fighter who grows through rival-driven improvement. At Tier 2 he diverges into three thematic paths: **Royal Burst** (critical single-target DPS), **Majin Temper** (unstable high-power tradeoffs), and **Super Blue** (team buffer and controlled offense). Each path preserves Vegeta's elite single-target identity while offering team-oriented utilities in certain branches.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Royal Saiyan | Precision melee and focused ki attacks. |
| Tier 2 | Divergence | Choose Royal Burst, Majin, or Super Blue. |
| Tier 3 | Mastery | Path-specific passives and combos. |
| Tier 4 | Transcendence | Signature ultimate per path. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme Summary |
|------|------|------------|---------------|
| **Royal Burst** | Burst DPS | STR, AGI | Critical strikes, focused single-target burst. |
| **Majin Temper** | Hybrid / Tank | STR, VIT | Trade defense for raw damage spikes or a controlled defensive stance. |
| **Super Blue** | Support / Buff | INT, STR | Team damage aura and disciplined beam control. |

---

### 🔹 Shared Abilities
- **⚔ Force Kick** — *SP unlock: 100* — Leap strike, follow-up combo.  
  `src/Spells/Vegeta/ForceKick.lua` — FX: `Abilities/ForceKick.mdl`

- **🔥 Galick Shot Lite** — *SP unlock: 250* — Mid-range channeled beam.  
  `src/Spells/Vegeta/GalickLite.lua` — FX: `Abilities/GalickBeam.mdl`

- **🛡 Rival Roar** — *SP unlock: 500* — Buff allies or debuff enemies based on chosen path.  
  `src/Spells/Vegeta/RivalRoar.lua` — FX: `Abilities/Roar.mdl`

---

### 💥 Path Abilities & Flavor

#### Royal Burst
- **Relentless Strike** — burst combo chains that increase crit chance for short time. (Tier 3)
- **Apex Stomp** — targeted heavy hit that deals huge single-target damage. (Tier 4)

#### Majin Temper
- **Forbidden Surge** — toggle buff that increases damage and life steal while reducing armor. (Tier 3)
- **Majin Resilience** — temporary shield produced when toggled buff ends. (Tier 4)

#### Super Blue
- **Blue Command** — team damage buff aura for a short duration. (Tier 3)
- **Divine Barrage** — disciplined multi-beam volley that pierces resistances. (Tier 4)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|-----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Force Kick | 100 | Tier 1 | Active Melee | Point 250 | 6s | STR times 1.1 | Leap strike with minor stun. | `Abilities/ForceKick.mdl` | `src/Spells/Vegeta/ForceKick.lua` |
| Galick Shot Lite | 250 | Tier 2 | Channel Beam | Direction 900 | 14s | INT times 0.95 per tick | Short channel beam. | `Abilities/GalickBeam.mdl` | `src/Spells/Vegeta/GalickLite.lua` |
| Rival Roar | 500 | Tier 3 | Buff/Debuff | AoE 400 | 20s | Buff = STR times 0.2 to allies | Path dependent buff or enemy debuff. | `Abilities/Roar.mdl` | `src/Spells/Vegeta/RivalRoar.lua` |
| Majin Surge | 1000 | Tier 4 (Majin) | Active Toggle | Self | 30s | Attack speed and life steal increases | Toggle: swaps offense for defense. | `Abilities/MajinSurge.mdl` | `src/Spells/Vegeta/MajinSurge.lua` |
| Final Flash | 1200 | Tier 4 Ultimate | Channel Beam | Direction 1100 | 60s | INT times 2.2 per tick | Massive focused beam ultimate. | `Abilities/FinalFlash.mdl` | `src/Spells/Vegeta/FinalFlash.lua` |

---

### 🔗 Integration Notes
- **StatSystem:** Vegeta’s Majin toggle modifies VIT and STR temporarily using `StatSystem.ApplyTemporaryMultiplier`. Represent "plus X percent" as multiplier like 1.15.  
- **DamageEngine:** Handle Final Flash channel ticks through DamageEngine's channel-safe pattern.  
- **Cinematic Hook:** `CinematicSystem.Play("Vegeta_FinalFlash")` with camera track and screen shake.  
- **Shard IDs:** `Shard_Vegeta`, `Shard_Saiyan_Pride`, `Shard_Majin` register in `ShardSystem.lua`.

---

### 🔁 Cross-Links & Fusion
- Vegeta contributes to `Divine Android` (with Android 18) and `Legendary Saiyan Overlord` fusions.  
- Rival synergies with Goku produce special cinematic duels when both in same party.

💥💥💥──────────────────────────────────────────────────💥💥💥
