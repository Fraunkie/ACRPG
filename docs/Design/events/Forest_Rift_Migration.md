# Forest Zone – Rift Migration (World Event)

## ID
`FOREST_RIFT_MIGRATION`

## Zone
- Zone key: `"FOREST"`
  - Represents a forested region where mini-rifts and cross-world anomalies migrate through the area.

## High-Level Fantasy
Temporal and spatial rifts drift slowly through the forest, dragging enemies and loot with them from other universes. Players must hunt these rifts, defeat the creatures emerging from them, and close the anomalies before they destabilize the region.

This is envisioned as a **hybrid combat + objective** event, but is currently implemented as a lightweight placeholder.

## Core Behavior (Current Implementation)

### Trigger Logic
Event definition:

```lua
registerEvent({
    id        = "FOREST_RIFT_MIGRATION",
    name      = "Rift Migration",
    zone      = "FOREST",
    duration  = 300.0,
    cooldown  = 1200.0,
    weight    = 2.0,
    checkTrigger = function(self, t, isReadyFlag)
        return isReadyFlag and anyPlayerInZone(self.zone)
    end,
    ...
})
```

Conditions:

- At least one player must be in the `"FOREST"` zone.
- Event can start only when:
  - `WorldEventSystem.MarkEventReady("FOREST_RIFT_MIGRATION")` has been used.

No random `rollChance` – this is a **scripted event** by default, potentially triggered by story beats.

### Duration and Cooldown
- Duration: **300 seconds** (5 minutes).
- Cooldown: **1200 seconds** (20 minutes).

### Start Flow
`onStart(ctx, t)`:

1. Emits:
   - `emit("FOREST_EVENT", { id = "RIFT_MIGRATION", phase = "START" })`
2. Debug log:
   - `"Rift Migration started"`.

No context values are initialized yet – it is a blank slate for you to define:

- Number of active rifts.
- Rift movement paths.
- Kill/capture counters per player.

### Kill & Action Logic
Both `onKill` and `onAction` are currently placeholders:

```lua
onKill = function(ctx, killed, killer)
    -- TODO: forest hybrid kill logic
end,

onEnd = function(ctx, t, reason)
    emit("FOREST_EVENT", { id = "RIFT_MIGRATION", phase = "END", reason = reason })
    debugPrint("Rift Migration ended (" .. tostring(reason) .. ")")
end,
```

Nothing is yet tracked or rewarded here – giving you full design freedom later while the event framework is already integrated.

### End Flow
`onEnd(ctx, t, reason)`:

- Emits:
  - `"FOREST_EVENT"` with `{ id = "RIFT_MIGRATION", phase = "END", reason = reason }`.
- Logs that the event ended.

## Intended Gameplay Direction

### Rifts as Moving Targets
You can design rifts as units or special objects that:

- Periodically move between anchor points in the forest (migration path).
- Act as spawn points for cross-world mobs:
  - Pokémon ghosts in one wave, Naruto shinobi in another, etc.
- Can be interacted with or destroyed by players:
  - Killing all mobs near a rift may weaken it.
  - Directly damaging the rift reduces its health.
  - Success could be closing or capturing rifts.

### Tracking Contributions
Possible metrics to track via `WorldEventSystem`:

- `"rift_kill"` → kills near a rift.
- `"rift_close"` → final blow on a rift object.
- `"rift_protect"` → protecting forest NPCs while rifts are active.

Each would be fed using `WorldEventSystem.ReportAction` or `ReportKill` with conditions around rift-related units.

### Rewards
Tie rewards to:

- Number of rifts closed.
- Time taken to close all rifts.
- Amount of damage prevented (e.g. forest corruption meter).

Rewards could be:
- Nature-themed gear.
- Small bonuses to movement speed or stealth in forested areas.
- Unlocking special forest events or NPCs.

### Integration Points

#### ProcBus
- `FOREST_EVENT` channel:
  - `{ id = "RIFT_MIGRATION", phase = "START" | "END", reason? }`.
- Generic world event signals:
  - `"WorldEventStarted"` / `"WorldEventEnded"`.

Use them to:
- Add fog, color shifts, or distortion FX when rifts are active.
- Show temporary minimap pings for rift locations.
- Add ambient sounds of distortion, whispers, etc.

### Tuning Knobs
- `duration = 300.0` → length of event.
- `cooldown = 1200.0` → reset period.
- `weight = 2.0` → relative importance for scheduling, if you later allow random triggers.
- Additional knobs to add later:
  - Number of rifts spawned.
  - Spawn frequency for mobs around each rift.
  - Difficulty scaling with zone player count/power.

## Implementation Status
- Event is fully registered in `WorldEventSystem` and can be started via `MarkEventReady`.
- Start and end events are emitted through ProcBus.
- Kill/action handlers are currently stubbed out, ready for you to add rift-specific logic once the forest and rift systems are designed.
