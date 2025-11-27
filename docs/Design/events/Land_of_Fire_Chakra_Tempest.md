# Land of Fire – Chakra Tempest (World Event)

## ID
`CHAKRA_TEMPEST`

## Zone
- Zone key: `"LAND_OF_FIRE"`
  - Represents the Naruto-inspired zone (Hidden Leaf / Land of Fire region).

## High-Level Fantasy
A violent Chakra Tempest sweeps through the Land of Fire, destabilizing the flow of natural and spiritual energy. Monsters, shinobi, and rogue chakra constructs become empowered or unstable. Players must capitalize on the chaos, tackling empowered enemies or stabilizing key chakra points before the storm ends.

This event is designed as a **flexible combat/interaction hybrid**, but currently serves as a structural placeholder inside the world event system.

## Core Behavior (Current Implementation)

### Trigger Logic
Event definition:

```lua
registerEvent({
    id        = "CHAKRA_TEMPEST",
    name      = "Chakra Tempest",
    zone      = "LAND_OF_FIRE",
    duration  = 300.0,
    cooldown  = 2400.0,
    weight    = 1.5,
    checkTrigger = function(self, t, isReadyFlag)
        return isReadyFlag and anyPlayerInZone(self.zone)
    end,
    ...
})
```

Conditions:

- At least one player must be present in `"LAND_OF_FIRE"`.
- Event only starts when explicitly marked ready:
  - `WorldEventSystem.MarkEventReady("CHAKRA_TEMPEST")`.

Currently no random `rollChance` – intended as a **scripted or milestone-based** event.

### Duration and Cooldown
- Duration: **300 seconds** (5 minutes).
- Cooldown: **2400 seconds** (40 minutes).

### Start Flow
On `onStart(ctx, t)`:

1. Emits:
   - `emit("NARUTO_EVENT", { id = "CHAKRA_TEMPEST", phase = "START" })`
2. Logs:
   - `"Chakra Tempest started"`.

No specific `ctx.data` fields are initialized yet – you have full freedom to define counters, chakra node states, etc.

### Kill & Action Handling
Current handlers:

```lua
onKill = function(ctx, killed, killer)
    -- Optional: chakra kill logic
end,

onAction = function(ctx, pid, kind, amount)
    -- Optional: chakra action tracking
end,
```

They are intentionally empty, waiting for:
- Chakra-infused enemy kill logic.
- Interactions with chakra seals, shrines, torches, or barriers.

### End Flow
`onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("NARUTO_EVENT", { id = "CHAKRA_TEMPEST", phase = "END", reason = reason })`
2. Logs:
   - `"Chakra Tempest ended (<reason>)"`.

No reward logic is implemented yet – this will come once the Land of Fire storyline and systems are more fleshed out.

## Intended Gameplay Ideas

### Empowered Mobs
During the tempest:
- Some mobs in the Land of Fire could gain temporary buffs:
  - Increased speed.
  - Extra elemental damage.
  - Special abilities (e.g., fire trails, chakra explosions).
- Killing tempest-empowered mobs could give bonus drops or chakra essences.

### Chakra Nodes and Seals
Add objectives like:

- Chakra pillars that must be stabilized:
  - Requires channel function or item use.
  - Each stabilized pillar weakens the storm.
- Evil seals that spawn cursed shinobi until dispelled.

Each successfully stabilized/cleansed node could be reported as actions:

- `WorldEventSystem.ReportAction(pid, "stabilize_chakra_node", 1)`
- `WorldEventSystem.ReportAction(pid, "dispel_curse_seal", 1)`

You can then track and reward based on per-player action contributions.

### Reward Types
This event can award:

- Chakra-oriented currency or items.
- Ninja equipment (weapons, headbands, scrolls).
- Passive bonuses when fighting in the Land of Fire during/after tempests.

Reward distribution would typically happen inside `onEnd`, using data in:
- `ctx.actionsByPlayer`
- Possibly `ctx.killsByPlayer` if you integrate kill logic.

## Integration Points

### ProcBus
- `NARUTO_EVENT`:
  - `{ id = "CHAKRA_TEMPEST", phase = "START" | "END", reason? }`.
- Generic:
  - `"WorldEventStarted"` / `"WorldEventEnded"` for cross-system coordination.

Use these to:
- Change sky tint and ambient sounds in the Land of Fire.
- Add crackling chakra auroras or swirling leaf/energy particles.
- Show zone banners like “Chakra Tempest in the Land of Fire!”.

### WorldEventSystem API
- Start event:
  - `WorldEventSystem.MarkEventReady("CHAKRA_TEMPEST")`
- Check if it’s active:
  - `WorldEventSystem.IsActive("CHAKRA_TEMPEST")`
- Use `ReportKill` and `ReportAction` to feed contributions into this event once the logic is implemented.

### Tuning Knobs
- `duration = 300.0` → active storm period.
- `cooldown = 2400.0` → long downtime; keeps it special.
- `weight = 1.5` → ordering priority if/when automated scheduling uses weights.
- Additional knobs to define later:
  - Number of chakra nodes per zone.
  - Spawn rate & difficulty of tempest-afflicted enemies.

## Implementation Status
- Structurally integrated into the world event system (trigger, start, end, signals).
- Kill + action logic are placeholders to be filled when Land of Fire mechanics and chakra systems are defined.
