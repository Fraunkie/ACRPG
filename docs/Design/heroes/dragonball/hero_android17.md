File: /design/heroes/dragonball/hero_android17.md
# 🤖🔋 **ANDROID 17 — Ranger of the Wilds** 🔋🤖
🔋🔋🔋──────────────────────────────────────────────────🔋🔋🔋

> Refer to: [global_soulpower_reference.md](../../global_soulpower_reference.md)

---

### 🌀 Overview
**Theme:** Stoic efficiency and endless reserves.  
Android 17 is a hybrid-field controller who branches into **Ranger 17** (agile ranged DPS), **Barrier Protocol 17** (defensive support), and **Evolved 17** (raid hybrid with reactor burst). He is designed to pair with Android 18 for twin synergies.

---

### 🔺 Tier Framework
| Tier | Title | Description |
|------|-------|-------------|
| Tier 1 | Synthetic Scout | Rapid projectiles and field gadgets. |
| Tier 2 | Divergence | Ranger, Barrier, or Evolved. |
| Tier 3 | Mastery | Field control and reactor management. |
| Tier 4 | Transcendence | Reactor overload ultimate. |

---

### 🧭 Role Variants (Paths)
| Path | Role | Stat Focus | Theme |
|------|------|------------|-------|
| **Ranger 17** | Burst / Ranged DPS | AGI, INT | Fast-fire precision volley. |
| **Barrier Protocol 17** | Support / Defensive | INT, VIT | Protective bubble and barrier systems. |
| **Evolved 17** | Raid / Hybrid | STR, VIT | Reactor burst and large-scale energy output. |

---

### 🔹 Shared Abilities
- **🔫 Pulse Shot** — *SP 100* — quick pulse projectiles.  
  `src/Spells/Android17/PulseShot.lua` — FX: `Abilities/PulseShot.mdl`

- **🕸 Energy Net** — *SP 250* — snare field that roots targets.  
  `src/Spells/Android17/EnergyNet.lua` — FX: `Abilities/EnergyNet.mdl`

- **🚀 Overdrive** — *SP 500* — speed and regen boost.  
  `src/Spells/Android17/Overdrive.lua` — FX: `Abilities/Overdrive.mdl`

---

### 💥 Path Abilities & Flavor

#### Ranger 17
- **Precision Barrage** — rapid accurate fire with crit scaling. (Tier 3)  
- **Hunter's Focus** — single-target suppression burst. (Tier 4)

#### Barrier Protocol 17
- **Barrier Field** — ally bubble shield that absorbs significant damage. (Tier 4)  
- **Field Stabilizer** — temporary cooldown reduction for allies inside barrier. (Tier 3)

#### Evolved 17
- **Evolved Reactor** — ultimate reactor discharge that damages area and repairs self. (Tier 4)  
- **Drone Swarm** — summon drones that assist with damage and small heals. (Tier 3)

---

### 🛠 Core 5 Technical Spec Table

| Ability | SP Unlock | Tier | Type | Targeting | Cooldown | Scaling | Description | FX | Script File |
|---------|----------:|------|------|---------:|---------:|--------:|------------|----|-------------|
| Pulse Shot | 100 | Tier 1 | Projectile | Directional 600 | 5s | Damage = AGI times 1.0 | Quick energy bolts. | `Abilities/PulseShot.mdl` | `src/Spells/Android17/PulseShot.lua` |
| Energy Net | 250 | Tier 2 | AoE Snare | 300 radius | 15s | INT times 0.9 | Roots and damages over time. | `Abilities/EnergyNet.mdl` | `src/Spells/Android17/EnergyNet.lua` |
| Overdrive | 500 | Tier 3 | Buff | Self | 20s | +AGI temporary boost and regen | Speed and regeneration. | `Abilities/Overdrive.mdl` | `src/Spells/Android17/Overdrive.lua` |
| Barrier Field | 1000 | Tier 4 (Barrier) | Support Shield | 600 radius | 40s | Shield = INT times 2.0 | Protective bubble for allies. | `Abilities/BarrierField.mdl` | `src/Spells/Android17/BarrierField.lua` |
| Evolved Reactor | 1200 | Tier 4 Ultimate | Ultimate AoE | 800 radius | 90s | Damage = STR times 2.0 plus INT times 1.5 | Massive reactor discharge and self-repair. | `Abilities/ReactorBurst.mdl` | `src/Spells/Android17/EvolvedReactor.lua` |

---

### 🔗 Integration Notes
- **ThreatSystem:** Barrier path reduces party threat by certain amounts via `ThreatSystem.ModifyThreat`.  
- **Cinematic Hook:** Evolved Reactor uses slow zoom and burst ring FX.  
- **Fusion:** Twin Android fusion recipe with Android 18 yields a `FusionCoreAndroid` hybrid form.

---

### 🔁 Cross-Links & Fusion
- Provides the other half of the `Twin Android Fusion` and a sub-component for `Divine Android` prestige recipes.

🔋🔋🔋──────────────────────────────────────────────────🔋🔋🔋
