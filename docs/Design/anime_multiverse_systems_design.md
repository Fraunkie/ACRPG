## ⚙️ Anime Multiverse RPG Systems Overview

This document tracks all gameplay systems and design logic discussed so far for the **Anime Multiverse RPG (Warcraft III)** project. Each section describes purpose, integration, and how it fits into the world design.

---

### 🌌 1. Spirit Realm (HFIL) — Starting Zone
**Theme:** Dragon Ball-inspired afterlife zone, acts as the tutorial and reset world.

**Core Functions:**
- Introduces all primary systems: **Soul Energy**, **Stat System**, **Respawn**, **Drops**, and **Dynamic Events**.
- Players begin as **Lost Souls (Wisp)**.
- Teaches resource collection, stat gain, and basic combat.

**Key NPCs / Elements:**
- **Goz & Mez:** Tutorial duel and guide characters.
- **Spirit Guardian:** Gatekeeper boss for first-tier evolution.
- **The Gate:** Arena portal used for Soul Resonance (tier-up challenge).

---

### 🔮 2. Tier-Up System (Permanent Evolution)
**Purpose:** Acts as the game’s class system — permanent evolution into hero forms.

**Concept Flow:**
1. Player gains enough **Soul Power (Energy)** through combat and growth.
2. Receives message: *“You have reached enough power to challenge your inner self.”*
3. Must bring a **Spirit Shard** (e.g., Shard of Goku, Charmander, Agumon, etc.) to **The Gate**.
4. After the **Spirit Guardian** is defeated, teleport into a private 1v1 arena.
5. Player fights their “inner form.” Upon victory, they permanently evolve into that hero.

**Notes:**
- Each Tier-Up grants new abilities and stat scaling.
- Heroes are saved permanently through Save/Load system.
- Once evolved, players respawn as their hero form instead of the wisp.

---

### 🌀 3. Death and Respawn Flow
**Flow Summary:**
- Upon death, players are sent to **King Yemma’s Check-In Station**.
- King Yemma acts as the **Death Manager** — can teleport to **Kami’s Lookout** (main hub).
- Once leaving HFIL, players **cannot return** (at least for early versions).

**Hubs:**
- **Kami’s Lookout:** Central teleport hub connecting all anime zones.
- **Popo’s Teleports:** Raid-only access points.
- **Kami’s Teleports:** Zone access based on power level.

---

### 💎 4. Shard System
**Purpose:** Acts as collectible items representing potential hero paths.

**Examples:**
- *Digi Shard*, *Poke Shard*, *Saiyan Shard*, etc.

**Usage:**
- Used at The Gate for Tier-Up challenges.
- Later: can unlock special forms, hidden zones, or upgrades.

---

### 🏠 5. Capsule Corporation Hub (Bulma’s Lab)
**Purpose:** Expansion hub for tech, crafting, and customization systems.

**Functions (Future):**
- Hero-specific upgrades or augmentations.
- Equipment crafting and storage.
- Future link to Save/Load and item fusion.

---

### ⚔️ 6. Combat and Stat Systems
**Base Stats:** Strength, Agility, Intelligence.

**Implemented Systems:**
- **HeroStatSystem.lua**: Core framework for calculating, updating, and synchronizing hero stats.
  - Auto-updates via timers.
  - Supports base + multiplier logic.
  - Chat commands for testing and debugging.

**Next Integration:**
- Add Bag System support (tracks and repositions PlayerBag).
- Replace global stat tables with unified `PLAYER_DATA` references.
- Merge item-based stat modifiers (from upcoming ItemStatSystem).

---

### 📦 7. Bag System (Planned)
**Purpose:**
- Each player spawns with an invisible “bag” unit.
- Follows the hero automatically; teleports back if it drifts too far.

**Technical Behavior:**
- Checks position every 0.5s.
- Max distance: 400.
- Teleport effect: *MassTeleportTarget.mdl*.

**Future Uses:**
- Custom inventory system.
- Loot pickup and quest item storage.

---

### ⚡ 8. Progression and Power Levels
**Mechanic:**
- Power Level = STR + AGI + INT combined.
- Used for unlocking new teleports (Kami/Popo) and zones.

**Future:**
- Power scaling affects Soul Resonance and Gate challenge eligibility.

---

### 🌍 9. Zone Structure Plan
| Zone | Theme | Description |
|------|--------|-------------|
| **1. Spirit Realm (HFIL)** | Dragon Ball Z | Tutorial + power awakening zone. |
| **2. Viridian Forest** | Pokémon | Early adventure zone with wild encounters. |
| **3. Digital Plains** | Digimon | Focused on evolution and spirit training. |
| **4. Hidden Leaf Borderlands** | Naruto | Ninja-themed zone with stealth mechanics. |

Then loops with new versions (e.g., new Dragon Ball world, new Digimon tier zones).

---

### 🧙 Future Ideas
- **Dynamic Events:** Timed world events that spawn raid bosses or reward Soul Energy bursts.
- **Raid System:** Iconic anime boss fights (e.g., Raditz Landing, Mewtwo Awakens).
- **Save/Load Integration:** Permanent progress, tier, stats, and items.
- **Soul Resonance Visuals:** FX and camera transitions during Tier-Up fights.

---

### 🧩 Integration Order (Development Notes)
1. **Fix core stat globals** and convert to `PLAYER_DATA` storage.
2. **Finalize CreateNewSoul logic** (spawns hero + bag).
3. **Implement BagSystem.lua.**
4. **Integrate item stat system** for future equipment.
5. **Add Soul Resonance / Gate logic.**
6. **Build teleport hubs and zone requirement checks.**

---

### 🧠 Key Technical Notes
- All code must follow **Total Initialization** pattern.
- Never create Warcraft natives (CreateUnit, CreateTrigger, etc.) in Lua root.
- Use `Debug.beginFile()` and `Debug.endFile()` wrappers for every system.
- Always ensure multiplayer safety by isolating frame visibility and player-local actions.

---

*This document updates as the project evolves and systems are implemented.*

