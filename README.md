🌌 Animecraft RPG — Developer Docs

Welcome to the Animecraft RPG Developer Documentation.
This folder is the central knowledge hub for all gameplay systems, UI modules, and dev tools — from combat to soul progression.

🧭 Tip: Start with Quick Start
 and Architecture Overview
, then check the system APIs or Codex for cross-module references.

📚 Table of Contents

Getting Started

Quick Start

Local Setup

Build & Import

Architecture

High-Level Overview

Event Flow: Combat → Rewards → UI

Core Systems (APIs)

⚡ SoulEnergy (XP System)

🔥 SpiritDrive (Rage Meter)

💀 ThreatSystem

🧠 AggroManager

⚔️ CombatEventsBridge

🧵 ProcBus (Event Bus)

UI Systems

📜 Player Menu & Modules

💾 Save & Load Module

📊 Stats Panel

Developer Utilities

🧰 DevMode & Chat Commands

Appendix

Troubleshooting

Glossary

🚀 Quick Start

Import all .lua files into your Warcraft III map using Trigger Editor → Custom Scripts.

Verify load order matches the InitBroker
 registration sequence.

Enable DevMode and test with:

-dev on
-create


After spawn, open the Player Menu with L and confirm UI responsiveness.

🧩 Architecture Overview

Animecraft RPG is built around modular systems linked through ProcBus, a unified event bus.
Each script focuses on one domain and emits standardized events so subsystems can react cleanly.

Core design pillars
Layer	Purpose
Gameplay Systems	Core logic: Combat, XP, Spirit, Threat, Loot
Bridges	Translate native engine events → ProcBus signals
UI & HUDs	Present game data (menus, HUDs, overlays)
Data Models	Store runtime player info (PlayerData, GameBalance)
Dev Tools	Hot reload, chat testing, debug visualizers

“One bus to rule them all.”
All cross-module communication runs through ProcBus. No direct system-to-system calls.

🔀 Event Flow: Combat → Rewards → UI

DamageEngine captures Warcraft native damage and kill events.

CombatEventsBridge emits structured ProcBus events (OnDealtDamage, OnKill).

ThreatSystem updates per-target threat and DPS tracking.

SoulEnergyLogic awards XP to killers and nearby allies.

SpiritDrive fills from outgoing damage, drains out of combat.

UI Bridges (e.g., SpiritPowerLabelBridge, ThreatHUD) reflect updates live.

🪶 Player Menu & Modules

File: PlayerMenu.lua
Light background outer frame, dark button rail (left), dark content panel (right).
Toggled via L key.

Left Rail Buttons
Button	Function
Load Save	Opens PlayerMenu_SaveModule inside content panel.
Stats	Opens PlayerMenu_StatsModule (WoW-style character sheet).
Behavior

Only one sub-panel is visible at a time (auto-closes others).

All frames are anchored to the same root for layout consistency.

Modular — future tabs like Inventory, Quests, or Codex can mount easily.

💾 Save & Load Module

File: PlayerMenu_SaveModule.lua
Nine-slot grid for character storage (currently in-memory).

Save Current:
Overwrites the first slot that matches current hero type;
if none match, uses the first empty slot.

Load Slot:
Recreates the saved hero and restores key PlayerData fields.

UI Style: Smaller icon cells, locked inside content backdrop.

Planned upgrade:

Preload-based or native file I/O (using FileIO pattern).

SAVE_VERSION and SAVE_SALT constants to invalidate old codes on version bump.

📊 Stats Panel

File: PlayerMenu_StatsModule.lua
Compact three-column layout inside the main menu content panel.

Section	Example Fields
Primary	Power, Defense, Speed, Crit
Offensive	Attack Damage, Attack Speed, Energy Bonus
Defensive	Armor, Damage Reduction, Dodge, Energy Resist
Progression	Soul Level, Soul Energy, SpiritDrive, Fragments, Shard
Debug	Threat, DPS, Last Damage, Zone
🧰 Developer Utilities

File: ChatTriggerRegistry.lua
All dev/test commands live here. Registered under -command syntax.
Gated by DevMode.

Examples

-create → spawns hero

-savesoul / -loadsoul → test save/load

-frags, -addfrags 50 → fragment currency testing

-soulinfo → view XP state

-sdinfo → view SpiritDrive values

Rule:
All new debug or dev commands must register here — never in separate files.

🧠 Coding Conventions

No % symbols in any string literals that reach Warcraft’s engine.

No top-level FourCC or Blz calls — define IDs inside OnInit.final.

Use ProcBus.Emit for all cross-system events.

Keep debug strings simple:
DisplayTextToPlayer(Player(pid), 0, 0, "Soul +20")

Always mark new systems ready with:

if InitBroker and InitBroker.SystemReady then
    InitBroker.SystemReady("SystemName")
end

🆘 Troubleshooting
Symptom	Cause / Fix
Editor crashes on save	Remove % symbols; check top-level natives.
L key not toggling menu	Ensure KeyEventHandler.lua loads after PlayerMenu.lua.
Menu stacking	Each module must hide others before showing itself.
SD jumps to 100 instantly	Verify GameBalance.SD_ON_HIT and bridge throttling.
Threat too high	Adjust GameBalance.THREAT.base_hit and per_damage.
📗 Glossary
Term	Description
SoulEnergy	XP resource (RuneScape-style curve).
SpiritDrive	Rage meter that fills from attacks, drains out of combat.
Threat	Enemy aggro metric; used by AI targeting.
ProcBus	Global event bus (pub/sub).
InitBroker	Signals system readiness and manages init order.
Bridge	Adapter translating Warcraft natives to ProcBus events.
🤝 Contributing

Create a short-named branch for your system or fix.

Keep commits atomic and descriptive.

Update /docs API pages for any behavioral changes.

Verify OnInit.final order before pushing.
