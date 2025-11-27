# Neo Capsule City – Power Grid Overload (World Event)

## ID
`NEO_POWER_GRID_OVERLOAD`

## Zone
- Zone key: `"NEO_CAPSULE"`
  - Represents Neo Capsule City / tech metropolis area.

## High-Level Fantasy
The multiverse strain on Neo Capsule’s infrastructure has pushed the city’s power grid into critical overload. Stabilization nodes across the city begin to fail, and players must sprint from node to node, stabilizing circuits before the grid collapses or causes widespread anomalies.

This is a **movement & objective-based zone event** with a technological flavor.

## Core Behavior (Current Implementation)

### Trigger Logic
Registered as:

```lua
registerEvent({
    id        = "NEO_POWER_GRID_OVERLOAD",
    name      = "Power Grid Overload",
    zone      = "NEO_CAPSULE",
    duration  = 420.0,
    cooldown  = 1500.0,
    weight    = 3.0,
    rollChance = 0.35,
    ...
})
```

Conditions:

- At least one player must be in `"NEO_CAPSULE"`.
- Event may start if:
  - `WorldEventSystem.MarkEventReady("NEO_POWER_GRID_OVERLOAD")` has been called **OR**
  - It passes its `rollChance` of `0.35` (35%) during a global event roll.

### Duration and Cooldown
- Duration: **420 seconds** (7 minutes).
- Cooldown: **1500 seconds** (25 minutes).

### Start Flow
`onStart(ctx, t)`:

1. Emits:
   - `emit("NEO_EVENT", { id = "POWER_GRID_OVERLOAD", phase = "START" })`
2. Debug log:
   - `"Power Grid Overload started"`.
3. Initializes:
   - `ctx.data.nodesTotal = 0` (for future total counts).
   - `ctx.data.nodesFixed = 0` (tracks progress during the event).

### Action Tracking

This event is driven by **stabilization actions** rather than kills.

`onAction` handler:

```lua
onAction = function(ctx, pid, kind, amount)
    if kind == "stabilize_node" then
        WorldEventSystem.AddActionContribution(pid, kind, amount)
        ctx.data.nodesFixed = (ctx.data.nodesFixed or 0) + amount
    end
end
```

Integration pattern:

- Each time a player completes a “fix” on a power node:
  - Use `WorldEventSystem.ReportAction(pid, "stabilize_node", 1)`.
- Effects:
  - `ctx.data.nodesFixed` stores global count of fixed nodes.
  - Per-player contributions recorded in:
    - `ctx.actionsByPlayer[pid]["stabilize_node"]`.

### End Flow
`onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("NEO_EVENT", { id = "POWER_GRID_OVERLOAD", phase = "END", reason = reason })`
2. Debug log:
   - `"Power Grid Overload ended (<reason>)"`.

Rewards are not yet coded in this block – left open so you can design tech-city progression and currencies properly first.

## Intended Gameplay Design

### Node System
You’ll likely implement a separate **node system**, including:

- Stabilization nodes as units/doodads:
  - Highlighted only during this event.
  - Have states: offline, unstable, stabilized.
- Interaction:
  - Player interacts with a node (e.g. channeling, quick-time event, or simple click).
  - When completed:
    - Node flips from unstable → stabilized.
    - Event system notified:
      - `WorldEventSystem.ReportAction(pid, "stabilize_node", 1)`.

### Failure vs Success
You can implement event end states based on:

- `ctx.data.nodesFixed` compared to required node count:
  - Determine whether the grid was "barely saved", "stabilized", or "perfectly optimized".
- Optional hidden `ctx.data.nodesTotal` to track how many nodes spawned during the event.

Use `reason` or additional flags in context if you want to distinguish fail/pass types.

### Reward Ideas
Based on nodes fixed:

- SoulEnergy + fragments as baseline.
- Tech-flavored rewards:
  - Temporary buffs to movement speed in city zones.
  - Access to special shops or tech upgrades.
  - “Grid-Linked Modules” that give future bonuses when events repeat.
- Multi-stage meta-progress:
  - Each successful Overload event slowly hardens the grid (or unlocks harder events).

### Integration Points

#### ProcBus
- `NEO_EVENT` channel with payloads:
  - `{ id = "POWER_GRID_OVERLOAD", phase = "START" | "END", reason? }`.
- Generic world signals:
  - `"WorldEventStarted"` / `"WorldEventEnded"` from `WorldEventSystem`.

Use them to:
- Pulse neon lights or flicker city skybox lighting.
- Display environmental FX like arcs of electricity at nodes.
- Pulse UI elements around minimap spots where nodes are located.

### Tuning Knobs
- `duration = 420.0` → job window length.
- `cooldown = 1500.0` → long enough to avoid spam but short enough for repeated play.
- `rollChance = 0.35` → how often it tries to start when players are in the city.
- Node spawn rate and density (defined in separate node system).

## Implementation Status
- Event is **fully wired** to accept `"stabilize_node"` actions and track totals.
- Does not yet spawn nodes, create visual markers, or distribute rewards – those are deliberately kept modular so they can be implemented in separate city/tech systems and hooked into this event via `WorldEventSystem.ReportAction`.
