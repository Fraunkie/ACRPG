# Digital Zone – Data Storm (World Event)

## ID
`DATA_STORM`

## Zone
- Zone key: `"DIGITAL_SEA"`
  - Represents a digital / virtual plane, likely tied to Digimon or similar cyber realms.

## High-Level Fantasy
A rogue Data Storm sweeps through the digital sea. Packets of corrupted data manifest as enemies, caches, and glitches. Players must defeat corrupted entities and secure data caches before the storm fractures the region or leaks hostile programs into neighboring zones.

This is designed as a **combat + treasure cache** style event.

## Core Behavior (Current Implementation)

### Trigger Logic
Event definition:

```lua
registerEvent({
    id        = "DATA_STORM",
    name      = "Data Storm",
    zone      = "DIGITAL_SEA",
    duration  = 360.0,
    cooldown  = 1500.0,
    weight    = 3.0,
    rollChance = 0.4,
    ...
})
```

Conditions:

- At least one player must be in `"DIGITAL_SEA"`.
- Event may start when:
  - `WorldEventSystem.MarkEventReady("DATA_STORM")` is used **OR**
  - It passes a `rollChance` of `0.4` (40%) during global rolls.

### Duration and Cooldown
- Duration: **360 seconds** (6 minutes).
- Cooldown: **1500 seconds** (25 minutes).

### Start Flow
On `onStart(ctx, t)`:

1. Emits:
   - `emit("DIGI_EVENT", { id = "DATA_STORM", phase = "START" })`
2. Debug log:
   - `"Data Storm started"`.
3. No specific data fields initialized yet, leaving room for future counters (e.g., caches opened, corrupted nodes destroyed).

### Kill & Action Handling
Current definitions:

```lua
onKill = function(ctx, killed, killer)
    -- TODO: data storm kill logic
end,

onAction = function(ctx, pid, kind, amount)
    if kind == "open_data_cache" then
        WorldEventSystem.AddActionContribution(pid, kind, amount)
    end
end,
```

Meaning:

- Kills are currently not processed – you will add custom logic here later.
- `onAction` already tracks `"open_data_cache"` actions, giving you:
  - Per-player contribution via `ctx.actionsByPlayer[pid]["open_data_cache"]`.

Expected usage:

- When a player interacts with a Data Cache object/unit:
  - Grant loot / currency.
  - Call `WorldEventSystem.ReportAction(pid, "open_data_cache", 1)`.

### End Flow
`onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("DIGI_EVENT", { id = "DATA_STORM", phase = "END", reason = reason })`
2. Debug log:
   - `"Data Storm ended (<reason>)"`.

No reward distribution happens here yet – this is left open for your final Digimon economy design.

## Intended Gameplay Design

### Storm FX and Hazards
During the event:
- The digital sea can visually destabilize:
  - Shifting tiles.
  - Glitch particles.
  - Random pseudo-lightning arcs.
- Environmental hazards:
  - Periodic shockwaves in certain regions.
  - Safe zones where players gather between surges.

### Enemy Spawns
You may design Data Storm-specific spawns:

- Corrupted Digimon or glitch monsters that:
  - Reward extra XP or fragments during the event.
  - Potentially drop data caches or keys when killed.
- Boss nodes (e.g. fragmented antivirus or rogue firewalls).

### Cache Gameplay
Data caches can serve as mini-objectives:

- Must be located and opened under time pressure.
- Some caches could be:
  - Locked behind enemy waves.
  - Tied to puzzles or sequences.
- Each opening:
  - Triggers `WorldEventSystem.ReportAction(pid, "open_data_cache", 1)`.
  - Potentially spawns additional enemies or mini-bosses.

### Reward Model
Possible directions:

- Rewards scale with:
  - Number of caches opened.
  - Number of corrupted enemies defeated.
- Reward types:
  - Digital currency or tokens redeemable in a tech/Digi shop.
  - Data chips used for upgrading companions or digital artifacts.
  - Unique cosmetics with pixel/glitch themes.

## Integration Points

### ProcBus
- `DIGI_EVENT` channel:
  - `{ id = "DATA_STORM", phase = "START" | "END", reason? }`.
- Generic `WorldEventStarted` / `WorldEventEnded` signals.

Use them to:
- Apply a screen shader or glitch overlay during the storm.
- Modify ambient sounds in the zone (e.g., static, modem screams, etc.).
- Show a dynamic banner across the UI indicating “Data Storm in Progress”.

### WorldEventSystem API
- Start the event manually:
  - `WorldEventSystem.MarkEventReady("DATA_STORM")`.
- Track contributions:
  - `WorldEventSystem.ReportAction(pid, "open_data_cache", 1)`.
  - Future kill hooks via `WorldEventSystem.ReportKill` / `onKill` logic.

### Tuning Knobs
- `duration = 360.0` → event window.
- `cooldown = 1500.0` → downtime between storms.
- `rollChance = 0.4` → spawn frequency in active digital zones.
- Density of caches and spawn rates to be controlled in dedicated Digi zone scripts.

## Implementation Status
- Fully connected to world event driver.
- Supports `"open_data_cache"` action tracking per player.
- No enemy spawn, hazard logic, or rewards yet – those are deliberately deferred to Digi-specific systems to keep the world event core clean and generic.
