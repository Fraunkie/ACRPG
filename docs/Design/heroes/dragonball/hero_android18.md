File: /design/heroes/dragonball/hero_android18.md
# 🤖⚡ **ANDROID 18 — Synthetic Precision** ⚡🤖
⚡⚡⚡──────────────────────────────────────────────────⚡⚡⚡

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Tech-enhanced combat and energy sharing.  
Android 18 splits into **Classic** (sustain DPS), **Infinite Energy** (support/energy share), and **Bio-Android** (hybrid with self-repair). She pairs naturally with Android 17 for twin synergies and Divine Android fusions.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Synthetic Recruit | Balanced ranged and melee tech. |
| Tier 2 | Divergence | Choose Classic, Infinite, or Bio. |
| Tier 3 | Mastery | Tech synergies and shields. |
| Tier 4 | Transcendence | Ultimate mechanical heart transform. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Classic** | Sustain DPS | AGI, STR | Balanced volley and melee mix. |
| **Infinite Energy** | Support / Utility | INT, AGI | Energy sharing and cooldown reduction for allies. |
| **Bio** | Hybrid / Raid | VIT, STR | Self repair and team barrier mechanics. |

---

### 🔹 Shared Abilities
- **🔫 Rapid Volley** — *SP 100* — burst multi-shot volley.  
  `src/Spells/Android18/RapidVolley.lua` — FX: `Abilities/Volley.mdl`

- **🛡 Reactive Shield** — *SP 250* — small reliable shield on hit.  
  `src/Spells/Android18/ReactiveShield.lua` — FX: `Abilities/ShieldTech.mdl`

- **⚙ Overclock** — *SP 500* — attack speed and cooldown reduction buff.  
  `src/Spells/Android18/Overclock.lua` — FX: `Abilities/Overclock.mdl`

---

### 💥 Path Abilities & Flavor

#### Classic
- **Precision Strike** — single target high DPS follow-ups. (Tier 3)  
- **Suppressive Fire** — ranged wall of bullets. (Tier 4)

#### Infinite Energy
- **Energy Share** — transfers Soul Power or reduces cooldowns for allies. (Tier 4)  
- **Field Distributor** — aura that slowly restores small Soul Power to allies. (Tier 3)

#### Bio
- **System Reboot** — massive self repair and temporary immunity. (Tier 4)  
- **Repair Drones** — summon auto-drones to heal allies. (Tier 3)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Rapid Volley | 100 | Tier 1 | Ranged Multi | Directional 600 | 6s | Damage = AGI times 1.0 | Multi-shot volley. | `Abilities/Volley.mdl` | `src/Spells/Android18/RapidVolley.lua` |
| Reactive Shield | 250 | Tier 2 | Shield | Self | 12s | Shield = INT times 1.5 | Temp absorb shield on activation. | `Abilities/ShieldTech.mdl` | `src/Spells/Android18/ReactiveShield.lua` |
| Overclock | 500 | Tier 3 | Buff | Self | 18s | Attack speed bonus = AGI times 0.05 | Boost firing and cooldown speed. | `Abilities/Overclock.mdl` | `src/Spells/Android18/Overclock.lua` |
| Energy Share | 1000 | Tier 4 (Infinite) | Support | Ally 600 | 30s | Transfers energy = INT times 0.5 | Distributes small Soul Power and reduces cooldowns. | `Abilities/Share.mdl` | `src/Spells/Android18/EnergyShare.lua` |
| System Reboot | 1200 | Tier 4 Ultimate | Self Repair | Self | 120s | Restore HP and remove debuffs | Massive self-repair and immunity. | `Abilities/Reboot.mdl` | `src/Spells/Android18/SystemReboot.lua` |

---

### 🔗 Integration Notes
- **SoulSystem:** Energy Share should call `SoulSystem.AddSoulPowerToPlayer` when transferring values.  
- **UISystem:** show small energy transfer animations and indicators.  
- **Cinematic Hook:** System Reboot plays mechanical reassembly and white-blue flares.

---

### 🔁 Cross-Links & Fusion
- Key component for `Divine Android` fusion with Vegeta and Android 17.

⚡⚡⚡──────────────────────────────────────────────────⚡⚡⚡
