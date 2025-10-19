
🌌 Animecraft RPG

A Multiverse Warcraft III RPG Experience
Created and directed by Gizmo
Powered by ChatGPT (GPT-5) collaboration

🧠 Overview

Animecraft RPG is a fully custom Warcraft III Reforged map blending multiple anime universes into one connected world.
You awaken as a lost spirit in HFIL — the “Home for Infinite Losers” — after the catastrophic Great Convergence ripped holes between worlds.
From there, you’ll climb through zones, ascend at gates, and become iconic heroes drawn from across the multiverse.

⚔️ Gameplay Highlights
🕊️ The Soul & Spirit Systems

Soul Energy – functions like XP in RuneScape; earned by killing enemies, not by damage.

Spirit Drive – a rage-style meter that fills when fighting and drains out of combat.
Full Drive enables powerful Ascension abilities.

💀 HFIL – Starting Zone

Task hub led by King Yemma.

Teaches Souls, Fragments, and combat basics.

Souls earn XP → raise Power Level → unlock new zones.

💎 Fragments & Shards

Duplicate shard pickups become Fragments (main spendable currency).

Each family (Saiyan, Namekian, Pokémon, etc.) has unique shard lines.

Charged shards are consumed at Ascension Gates for hero upgrades.

🔮 Ascension Gates

Located at key map points.

Require: Charged Shard + Tier + Power Level + Full Spirit Drive.

Successful ascension unlocks new hero forms and ability trees.

⚔️ Combat & Threat

True per-unit Threat System with decay, healing threat, and AI targeting.

Aggro Manager groups nearby enemies to coordinate attacks.

Combat HUD tracks your DPS and group averages in real time.

💰 Loot & Economy

Shared Loot: all players in the threat group get personal drops.

Roll Chest: rare items spawn shared rollable chests.

Fragments = main economy; Soul Energy = progression XP.

🏰 Core Systems
Category	File	Description
Config	GameBalanceConfig.lua	Master tuning knobs and IDs
Player	PlayerData.lua	Per-player runtime storage
Progression	SoulEnergy.lua, SpiritDrive.lua	XP & rage systems
Combat	CombatEventsBridge.lua, ThreatSystem.lua, AggroManager.lua, ThreatBridge.lua	Damage, threat & AI
UI	CombatThreatHUD.lua, PlayerMenu.lua, SpiritPowerLabelBridge.lua	HUDs & menus
Utility	InitBroker.lua, ChatTriggerRegistry.lua, DevMode.lua, Dev_commands.lua	Initialization, dev & chat
🧩 Development Workflow
Total Initialization

Every system runs through OnInit.final() — load order no longer matters.
This ensures consistent behavior and safe cross-system hooks.

Centralized Chat Commands

All developer/test commands live in ChatTriggerRegistry.lua for easier maintenance.

Threat & AI Integration

ThreatSystem and AggroManager cooperate to decide:

Which target mobs attack

When packs assist

When to switch focus (like WoW-style threat tables)

Loot System Bridge

Connected through CombatEventsBridge → triggers personal & roll-based loot.
Hero inventory overflow automatically redirects to the Bag Follower Unit.

🧠 Technical Summary

Written entirely in Lua (Warcraft III Total Initialization)

Zero percent (%) formatting for Reforged safety

No top-level natives (FourCC only runs inside OnInit.final)

Editor-safe; passes WE syntax & save validation

All systems modular and memory-tracked

🛠️ Sync & Snapshot

Animecraft RPG uses a local → ChatGPT snapshot system for version control.

Snapshot Builder
python tools/make_snapshot.py


Outputs a single file:

snapshot/Main_All.lua

Syncing with ChatGPT

Build the snapshot

Drag it into chat

ChatGPT merges it into the main protected memory baseline

(Details in tools/README_SYNC.md.)

❤️ Credits

Project Lead / Map Design: Gizmo
AI Development Partner: ChatGPT (GPT-5)
Art & UI Concepts: Animecraft Team
Testing: HFIL Alpha Crew

Would you like me to add a short “Next Major Milestone” section at the bottom (for example: HFIL Elite Tasks + Yemma AI Update – November 2025) before you post this live?
