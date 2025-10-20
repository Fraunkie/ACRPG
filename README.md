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
  ...existing code...

- **Appendix**
  - [Troubleshooting](#-troubleshooting)
  - [Glossary](#-glossary)

---

- **Top-level natives:** Avoid calling natives (like `FourCC`) at file top-level. Build those lookups in `OnInit.final` only.


**One bus to rule them all:**
  - **HUDs** & UI sync via `SpiritPowerLabelBridge` and HUD APIs.

## 🔀 Event Flow: Combat → Rewards → UI

5. **SpiritDrive** bumps on hit, drains OOC; full triggers optional events.
6. **UI Bridges** update the soul/spirit labels; **HUDs** reflect threat & DPS.
---


Common chat commands (all gated by DevMode):
- **Init:** `-initdump`
- **Watch:** `-watchdog` (10 ticks to detect freezes)


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
