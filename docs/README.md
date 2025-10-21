# 🌌 Animecraft RPG — Developer Docs

Welcome to the **Animecraft RPG** developer documentation.  
This folder is your one-stop portal for the game’s systems: combat events, XP/levels, spirit/rage, threat/aggro, UI HUDs, dev tools, and shared event bus.

> 🧭 Tip: Start with **Quick Start** and **Architecture Overview**, then dive into system APIs.

---

## 📚 Table of Contents

- **Getting Started**
  - [Quick Start](#-quick-start)
  - [Local Setup](#-local-setup)
  - [Build & Import](#-build--import)
- **Architecture**
  - [High-Level Overview](#-architecture-overview)
  - [Event Flow: Combat → Rewards → UI](#-event-flow-combat--rewards--ui)
- **Core Systems (APIs)**
  - [⚡ SoulEnergy (XP System)](./SoulEnergy_API.md)
  - [🔥 SpiritDrive (Rage Meter)](./SpiritDrive_API.md)
  - [💀 ThreatSystem](./ThreatSystem_API.md)
  - [🦾 AggroManager](./AggroManager_API.md)
  - [⚔️ CombatEventsBridge](./CombatEventsBridge_API.md)
  - [🧵 ProcBus (Event Bus)](./ProcBus_Events.md)
- **Developer Utilities**
  - [🧰 DevMode & Chat Commands](./DevMode_Guide.md)
- **Contributing**
  - [Coding Conventions](#-coding-conventions)
  - [Testing & Debugging](#-testing--debugging)
  - [Checklist Before Commit](#-pre-commit-checklist)
- **Appendix**
  - [Troubleshooting](#-troubleshooting)
  - [Glossary](#-glossary)

---

## 🚀 Quick Start

1. **Clone** the repo and open the map project in your editor.
2. Ensure the following **core scripts** are present and enabled:
   - `ProcBus.lua`, `InitBroker.lua`
   - `DamageEngine.lua`, `CombatEventsBridge.lua`
   - `SoulEnergy.lua`, `SoulEnergyLogic.lua`
   - `SpiritDrive.lua`, `SpiritPowerLabelBridge.lua`, `SpiritDriveOOC.lua`
   - `ThreatSystem.lua`, `AggroManager.lua`
   - `HFIL_UnitConfig.lua`
   - `ChatTriggerRegistry.lua`, `DevMode.lua` (or `ACDebug.lua`)
3. Import (or re-import) the **BLP** UI assets if needed for HUDs.
4. Launch a local test:
   - **Dev toggles:** `-dev on`
   - **HUD:** `-thud`
   - **XP sanity:** `-soul`, kill a configured HFIL creep (`HFIL_UnitConfig.lua`)
   - **Spirit sanity:** hit a unit; watch SD fill & drain via `SpiritDriveOOC`

---

## 🏗 Local Setup

- **War3 Lua:** Ensure **Lua mode** is enabled and total initialization is used (we follow the same init style).
- **No `%` prints:** All logs avoid percent symbols for editor stability.
- **Top-level natives:** Avoid calling natives (like `FourCC`) at file top-level. Build those lookups in `OnInit.final` only.

---

## 🧩 Architecture Overview

**One bus to rule them all:**
- `DamageEngine` hooks all native damage/heal events.
- `CombatEventsBridge` normalizes & emits:
  - `OnDealtDamage`, `OnKill`, `OnHeal`, (plus pid/unit payloads)
- Systems subscribe through **`ProcBus`**:
  - **ThreatSystem** adds/decays threat.
  - **SoulEnergyLogic** awards XP on kill (per-unit config).
  - **SpiritDrive** gains on hit; drains OOC via `SpiritDriveOOC`.
  - **HUDs** & UI sync via `SpiritPowerLabelBridge` and HUD APIs.

---

## 🔀 Event Flow: Combat → Rewards → UI

1. **Hit occurs** → `DamageEngine` fires BEFORE/AFTER/LETHAL.
2. **Bridge** emits `OnDealtDamage` and (if lethal) `OnKill`.
3. **ThreatSystem** updates tables; **AggroManager** may retarget.
4. **SoulEnergyLogic** calculates XP from `HFIL_UnitConfig` and shares to allies.
5. **SpiritDrive** bumps on hit, drains OOC; full triggers optional events.
6. **UI Bridges** update the soul/spirit labels; **HUDs** reflect threat & DPS.

---

## 🧠 System APIs

- **XP:** [⚡ SoulEnergy](./SoulEnergy_API.md)
- **Rage:** [🔥 SpiritDrive](./SpiritDrive_API.md)
- **Threat:** [💀 ThreatSystem](./ThreatSystem_API.md)
- **AI Packs:** [🦾 AggroManager](./AggroManager_API.md)
- **Events:** [⚔️ CombatEventsBridge](./CombatEventsBridge_API.md)
- **Bus:** [🧵 ProcBus Events](./ProcBus_Events.md)

---

## 🧪 Testing & Debugging

Common chat commands (all gated by DevMode):

- **Dev mode:** `-dev on`, `-dev off`, `-dev toggle`
- **XP:** `-soul`, `-souladd 50`, `-soulset 100`
- **SpiritDrive:** `-sd 50`, `-sdadd 8`
- **HUDs:** `-thud` (Threat HUD toggle)
- **Init:** `-initdump`
- **Watch:** `-watchdog` (10 ticks to detect freezes)

> Add/remove commands centrally in `ChatTriggerRegistry.lua`.

---

## ✍️ Coding Conventions

- **Initialization:** Always use `OnInit.final(function() ... end)` for setup.
- **Logging:** ASCII-only; prefix with system tag, e.g. `[Threat] ...`.
- **Safety:** Wrap external callbacks with `pcall` to prevent hard crashes.
- **Globals:** Write through `_G.Name = Name` for cross-file access.

---

## ✅ Pre-Commit Checklist

- [ ] No top-level native calls (e.g., `FourCC`) outside `OnInit.final`.
- [ ] No `%` in any `print()` / debug strings.
- [ ] All new events **Emit** through `ProcBus`, not direct calls across modules.
- [ ] Chat commands registered in `ChatTriggerRegistry.lua`.
- [ ] Editor save-tested for each updated script.

---

## 🆘 Troubleshooting

- **Editor crash on save:** Check for `%` in strings; remove top-level native calls.
- **Commands stop working:** Ensure chat triggers are stored globally (`ChatTriggers[cmd] = trig`) to prevent GC; verify DevMode is enabled.
- **Spirit hits 100 instantly:** Verify `GameBalance.SD_ON_HIT`, and bridge isn’t double-adding; confirm only one bridge is active.
- **Loot FX spam:** Ensure no OOC loops re-trigger SD or FX on idle (Bag unit excluded from all combat systems).

---

## 📗 Glossary

- **SoulEnergy:** Player XP (RuneScape-style curve).
- **SpiritDrive:** Rage resource that fills on hit, drains out of combat.
- **Threat:** Per-target aggro priority value; used for AI.
- **ProcBus:** Lightweight pub/sub event dispatcher.
- **Bridge:** A unifier translating native/engine events to ProcBus events.

---

## 🤝 Contributing

- Open a PR with a **short summary** and which systems are affected.
- Keep changes **small & testable**; attach test steps (commands, units to kill).
- Update relevant docs in `/docs` when system behavior changes.

---

**Happy modding!**  
If you need a docs badge, a changelog template, or GitHub Actions to lint Lua, say the word and we’ll add them.
