# Rebirth Pools – Soul Bloom Harvest (World Event)

## ID
`REBIRTH_SOUL_BLOOM`

## Zone
- Uses custom zone key: `"REBIRTH_POOLS"`.
- Represents the Rebirth Pools sub-region impacted by the Great Convergence.

## High-Level Fantasy
The Rebirth Pools periodically overflow with crystallized Soul Blooms. During this event, spectral plants sprout around the pools. Players must **harvest** these blooms safely before HFIL currents reabsorb them.

Gameplay-wise, this is a **collection/event node interaction** style event, not focused on mass killing.

## Core Behavior (Current Implementation)

### Trigger Logic
Registered event:

```lua
registerEvent({
    id        = "REBIRTH_SOUL_BLOOM",
    name      = "Soul Bloom Harvest",
    zone      = "REBIRTH_POOLS",
    duration  = 300.0,
    cooldown  = 1200.0,
    weight    = 2.5,
    rollChance = 0.5,
    ...
})
```

Conditions:

- At least one player must be in `"REBIRTH_POOLS"` (`anyPlayerInZone(self.zone)`).
- Event starts when:
  - `WorldEventSystem.MarkEventReady("REBIRTH_SOUL_BLOOM")` is used **OR**
  - The event passes its `rollChance` of `0.5` (50%) in a global roll.

### Duration and Cooldown
- Duration: **300 seconds** (5 minutes).
- Cooldown: **1200 seconds** (20 minutes).

### Start Flow
On `onStart(ctx, t)`:

1. Emits:
   - `emit("REBIRTH_EVENT", { id = "SOUL_BLOOM_HARVEST", phase = "START" })`
2. Debug message:
   - `"Soul Bloom Harvest started"`.
3. Initializes:
   - `ctx.data.totalBlooms = 0`.

This is intended as an accumulator for **all** Soul Bloom harvests by all players during the event.

### Action Tracking

Instead of kills, this event listens for **actions**.  
`WorldEventSystem.ReportAction(pid, kind, amount)` is the pathway other scripts should use.

`onAction` handler:

```lua
onAction = function(ctx, pid, kind, amount)
    if kind == "harvest_bloom" then
        ctx.data.totalBlooms = (ctx.data.totalBlooms or 0) + amount
        WorldEventSystem.AddActionContribution(pid, kind, amount)
    end
end
```

Meaning:

- Other systems (e.g. interaction handlers in Rebirth Pools) should:
  - Call: `WorldEventSystem.ReportAction(pid, "harvest_bloom", 1)` each time a bloom is collected.
- `ctx.data.totalBlooms` tracks the **global total**.
- `WorldEventSystem.AddActionContribution` also tracks per-player contributions in:
  - `ctx.actionsByPlayer[pid]["harvest_bloom"]`.

### End Flow
On `onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("REBIRTH_EVENT", { id = "SOUL_BLOOM_HARVEST", phase = "END", reason = reason })`
2. Debug message:
   - `"Soul Bloom Harvest ended (<reason>)"`.

Currently no default rewards are implemented in this event block – those are intentionally left to be **defined later** based on how many blooms were harvested.

## Intended Gameplay Extensions

### Soul Bloom Nodes
You’ll likely want:

- Special doodads/units representing Soul Blooms that:
  - Only appear while `WorldEventSystem.IsActive("REBIRTH_SOUL_BLOOM")` is true.
  - Use a periodic spawn system to place them around the Rebirth Pools.
- Interaction script where:
  - Player interacts with a bloom:
    - Destroys bloom unit / doodad.
    - Grants immediate SoulEnergy and/or items.
    - Calls: `WorldEventSystem.ReportAction(pid, "harvest_bloom", 1)`.

### Reward Resolution
At event end, you can loop `ctx.actionsByPlayer` and `ctx.data.totalBlooms`:

- Global total determines **tier of success**:
  - `0–20` → basic rewards.
  - `21–50` → improved rewards.
  - `51+` → rare drop chance.
- Per-player contributions determine **individual rewards**.

This could mirror HFIL Spirit Surge reward logic, but tied to harvest count instead of kills.

### Integration Points

#### ProcBus
- `REBIRTH_EVENT` channel:
  - `{ id = "SOUL_BLOOM_HARVEST", phase = "START" | "END", reason? }`
- `WorldEventStarted` / `WorldEventEnded` (generic world event signals).

Use these to:
- Tint water of Rebirth Pools during the event.
- Add floating soul particles / bubble FX around nodes.
- Pop zone-wide alerts or mini-quest style hints: “Soul Blooms are blooming around the Rebirth Pools!”

### Tuning Knobs
- `duration = 300.0` → total window to harvest blooms.
- `cooldown = 1200.0` → how often Rebirth Pools can bloom again.
- `rollChance = 0.5` → how frequently the event fires when players are present.
- Internal spawn rate / number of nodes (to be defined in a dedicated Rebirth Pools spawner script).

## Implementation Status
- Event is **fully wired** into the world event system (trigger, start, end).
- Action tracking is already implemented via `"harvest_bloom"` kind.
- **Reward logic & node spawning** are intentionally left to be implemented in separate scripts, so this document is your reference for integrating those systems cleanly later.
