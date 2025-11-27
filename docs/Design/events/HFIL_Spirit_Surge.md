# HFIL Spirit Surge (World Event)

## ID
`HFIL_SPIRIT_SURGE`

## Zone
- Primary zone key: `"HFIL"`
- Uses `PlayerData.GetZone(pid)` → `"HFIL"` to detect eligible players.

## High-Level Fantasy
HFIL erupts in unstable spirit energy. Standard HFIL creeps become more numerous and aggressive, and players are rewarded for culling them during the surge. This is a **combat-focused, repeatable world event** that turns HFIL into a temporary farm zone with boosted rewards.

## Core Behavior

### Trigger Logic
- Registered in `WorldEventSystem.lua` as a world event.
- Event is **eligible** when:
  - At least one active player has `zone == "HFIL"`.
- Event **tries to start** based on:
  - A global roll every `ROLL_INTERVAL` (15 seconds).
  - Local `rollChance` for this event: `0.4` (40% when conditions are met).
  - Or if explicitly forced ready via:
    - `WorldEventSystem.MarkEventReady("HFIL_SPIRIT_SURGE")`.

### Duration and Cooldown
- Duration: **360 seconds** (6 minutes).
- Cooldown: **1200 seconds** (20 minutes) from when it ends (regardless of reason).

### Start Flow
When the event starts, `onStart` runs with a fresh event context:

1. Emit ProcBus event:
   - Channel: `HFIL_EVENT`
   - Payload: `{ kind = "SPIRIT_SURGE", phase = "START" }`
   - This allows HFIL-specific systems to react (visuals, music, UI).

2. Internal state:
   - `ctx.data.surgeActive = true`
   - `ctx.data.surgeFactor = 0.5` (reserved for potential future damage/XP multipliers).

3. Spawn pool calculation:
   - Calls `buildHFILSurgeSpawnPool()`:
     - Collects all players currently in HFIL.
     - Computes **average powerLevel** across those players.
     - Chooses tier set based on average power:
       - `< 5` → `tier1`
       - `< 12` → `tier1 + tier2`
       - `< 20` → `tier2 + tier3`
       - `>= 20` → `tier2 + tier3 + miniboss`
     - Checks `HFILUnitConfig.IsEligible(pid, raw)` when available to filter rawcodes per player eligibility.
     - Produces a combined list of rawcodes used for wave spawning (e.g. `n001`, `n00G`, `n00U`, etc.).
   - Stores:
     - `ctx.data.mobPool` (list of rawcodes).
     - `ctx.data.avgPower` (numeric average).

4. HFIL sub-zone selection:
   - Chooses exactly **one sub-zone** for the entire event:
     - `ctx.data.surgeSubZoneKey = pickRandomHFILSubZoneKey()`
   - `HFIL_SPAWN_POINTS` is a table of named sub-zones and their spawn anchors:
     ```lua
     local HFIL_SPAWN_POINTS = {
         graveyard = {
             { x = -3500.0, y = 4200.0 },
             { x = -3100.0, y = 3900.0 },
             { x = -2800.0, y = 3600.0 },
         },
         needle_spires = {
             { x = -4500.0, y = 2000.0 },
             { x = -4700.0, y = 1800.0 },
         },
         hell_pits = {
             { x = -5200.0, y =  800.0 },
             { x = -5400.0, y =  600.0 },
         },
     }
     ```
   - Design intent: one sub-zone per event → all waves happen **within** that region, but on varying points.

5. Wave timer:
   - `SPIRIT_SURGE_WAVE_INTERVAL = 15.0` seconds.
   - First wave scheduled after a short delay:
     - `ctx.data.nextWaveAt = t + 5.0` (start time + 5s).

### Tick Flow
`onTick(ctx, t, dt)` is called every world-event tick (`TICK_SECONDS` from the driver, currently 1.0s).

The logic:
1. If no chosen sub-zone key, do nothing (cannot spawn waves).
2. Check if current time `t` has reached `ctx.data.nextWaveAt`.
3. If yes:
   - Rebuild spawn pool and average power via `buildHFILSurgeSpawnPool()`:
     - This allows the mob pool to adapt if different players enter or leave HFIL mid-event.
   - Call `spawnSpiritSurgeWave(ctx)` if pool is non-empty.
   - Reschedule next wave:
     - `ctx.data.nextWaveAt = t + waveInterval`.

### Wave Spawning
`spawnSpiritSurgeWave(ctx)` handles an individual wave:

1. Uses `ctx.data.mobPool` as the current spawnable rawcode set.
2. If no players are currently in HFIL, the wave is skipped.
3. Resolves sub-zone:
   - `subKey = ctx.data.surgeSubZoneKey` (fixed per event).
   - Randomly picks a spawn anchor from `HFIL_SPAWN_POINTS[subKey]`.
4. Visual Telegraph:
   - Spawns a temporary WC3 effect at the spawn center:
     - Model: `"Abilities\Spells\Undead\DeathPact\DeathPactTarget.mdl"`
   - Immediately destroyed after being created, using:
     - `DestroyEffect(AddSpecialEffect(SPIRIT_SURGE_TELEGRAPH_FX, pt.x, pt.y))`
   - Visual usage: brief flash/marker so players see where a wave is about to appear.

5. Spawn count (difficulty scaling):
   - Base minimum: `SPIRIT_SURGE_MIN_SPAWN = 3`.
   - Modifiers based on `ctx.data.avgPower`:
     - `>= 5`   → +1 mob
     - `>= 12`  → +2 more
     - `>= 20`  → +2 more
   - Total is clamped by `SPIRIT_SURGE_MAX_SPAWN = 8`.

6. Spawning details:
   - Units are owned by `Player(PLAYER_NEUTRAL_AGGRESSIVE)`.
   - For each unit spawned:
     - Pick random rawcode from `mobPool`.
     - Convert to FourCC: `FourCC(raw)`.
     - Spawn near the telegraph point:
       - `sx = pt.x + random(-300, 300)`
       - `sy = pt.y + random(-300, 300)`
     - Create unit facing 270° (west by default):
       - `CreateUnit(owner, ut, sx, sy, 270.0)`
   - All spawned units are tracked in `ctx.data.spawnedUnits` for cleanup.

### Kill Tracking
- The event listens to global `"OnKill"` via `ProcBus`:
  - `WorldEventSystem.ReportKill(killed, killer)`.
- Inside the HFIL Spirit Surge `onKill` handler:
  1. Validate `killed` and `killer` are units.
  2. Check if `killed` is an HFIL creep:
     - Uses `HFIL_UNIT_TYPES` lookup.
  3. Determine `pid` from `GetOwningPlayer(killer)`.
  4. Increment contribution via:
     - `WorldEventSystem.AddKillContribution(pid, 1)`.

- Result:
  - `ctx.killsByPlayer[pid]` accumulates kill counts per player during the event.

### End Flow
When the event ends (timeout or forced):

1. ProcBus emit:
   - Channel: `HFIL_EVENT`
   - Payload: `{ kind = "SPIRIT_SURGE", phase = "END", reason = reason }`.

2. Cleanup spawned units:
   - Iterates `ctx.data.spawnedUnits` and `RemoveUnit(u)` for each valid unit.

3. Reward distribution via `grantSpiritSurgeRewards(ctx)`.

## Rewards

### Per-Kill Currency
Config constants:
- `SPIRIT_SURGE_SOUL_PER_KILL = 5`
- `SPIRIT_SURGE_FRAG_PER_KILL = 1`

For each player with recorded kills:

```lua
local soul  = count * SPIRIT_SURGE_SOUL_PER_KILL
local frags = count * SPIRIT_SURGE_FRAG_PER_KILL
```

Soul Energy handling:
- If `SoulEnergy.AddXp` exists:
  - `SoulEnergy.AddXp(pid, soul, "WorldEvent", { eventId = "HFIL_SPIRIT_SURGE" })`
- Else (fallback):
  - Increments `pd.soulEnergy` directly.

Fragment handling:
- Numeric mirror:
  - `pd.fragments = (pd.fragments or 0) + frags`
- Physical fragment items:
  - Randomly selects from:
    - `I00U` (Dragon Ball Fragment)
    - `I012` (Digi Fragment)
    - `I00Z` (Poké Fragment)
    - `I00Y` (Chakra Fragment)
  - Spawns items at hero position and immediately gives them to the hero using `UnitAddItem`.

### Bonus Item Rewards
After currency rewards, each contributing player may receive **one bonus item**:

- The item is selected via `pickSurgeRewardItemId()` from `SPIRIT_SURGE_ITEM_POOL`:

Default example:
```lua
local SPIRIT_SURGE_ITEM_POOL = {
    {
        id     = FourCC("I00W"),   -- Goku Shard (placeholder)
        rarity = "legendary",
        weight = 1,
    },
    -- future entries:
    -- { id = FourCC("I00G"), rarity = "rare",    weight = 3 },
    -- { id = FourCC("I004"), rarity = "uncommon", weight = 5 },
}
```

- Each entry has:
  - `id`     → rawcode (FourCC).
  - `rarity` → flavor/label only (no logic yet).
  - `weight` → used for weighted random selection.

### Player Feedback
- Each participating player receives local text feedback:

```lua
"[Spirit Surge] You gained <soul> Soul Energy and <frags> fragments during the surge."
```

## Integration Points

### ProcBus Channels
- Emitted:
  - `"HFIL_EVENT"` with `{ kind = "SPIRIT_SURGE", phase = "START" | "END", reason? }`.
  - `"WorldEventStarted"` / `"WorldEventEnded"` with generic `{ id, zone, reason }` from `WorldEventSystem`.

Use these to:
- Trigger zone-wide VFX, music changes, skybox changes.
- Pop UI banners (e.g., “HFIL Spirit Surge has begun!”).
- Hook additional systems (e.g., bonus SpiritDrive gain during the event).

### API Helpers
From `WorldEventSystem`:
- `WorldEventSystem.MarkEventReady("HFIL_SPIRIT_SURGE")`
  - Flags the event as immediately eligible on next roll (ignoring `rollChance`).
- `WorldEventSystem.IsActive("HFIL_SPIRIT_SURGE")`
  - Returns `true` if Spirit Surge is currently active.
- `WorldEventSystem.GetActiveContext()`
  - Can return context if you need advanced custom logic from another system.

## Tuning Knobs

### Spawn & Difficulty
- `SPIRIT_SURGE_WAVE_INTERVAL` → how often waves spawn.
- `SPIRIT_SURGE_MIN_SPAWN` / `SPIRIT_SURGE_MAX_SPAWN` → how many mobs per wave.
- Thresholds for average power scaling:
  - Currently at `5`, `12`, `20`.

### Rewards
- `SPIRIT_SURGE_SOUL_PER_KILL` → Soul XP per HFIL kill.
- `SPIRIT_SURGE_FRAG_PER_KILL` → fragment currency per HFIL kill.
- `SPIRIT_SURGE_ITEM_POOL` → composition and rarity of bonus items.

### Spatial Layout
- `HFIL_SPAWN_POINTS`:
  - Adjust sub-zone names and coordinates to match your actual HFIL layout.
  - You can add more sub-zones (keys) and points per sub-zone.

## Future Ideas / Extensions

- Add miniboss logic tied to `HFIL_MOB_POOLS.miniboss` when average power is high.
- Add per-sub-zone variations:
  - Graveyard → more ghost-type spawns, special shrines.
  - Needle Spires → spike-based hazards during waves.
- Add UI tracker:
  - Show kills contributed during the current surge per player.
- Add dynamic scaling by number of HFIL players as well as powerLevel.
