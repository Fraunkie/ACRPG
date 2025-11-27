# HFIL Needle Spire Stampede (World Event)

## ID
`HFIL_NEEDLE_STAMPEDE`

## Zone
- Uses zone key `"HFIL"`; same HFIL region as Spirit Surge, but thematically focused on the Needle Spire sub-area.

## High-Level Fantasy
The Needle Spire fields experience a sudden rush of condemned beasts and spirit herds. Shards of HFIL's landscape animate and stampede between spires, forcing players to intercept and break the stampede lines before they reach key choke points.

This is a **mobility & interception** style event rather than a pure farm surge.

## Core Behavior (Current Skeleton)

### Trigger Logic
- Zone: `"HFIL"`.
- Registered with:
  ```lua
  registerEvent({
      id        = "HFIL_NEEDLE_STAMPEDE",
      name      = "Needle Spire Stampede",
      zone      = "HFIL",
      duration  = 240.0,
      cooldown  = 900.0,
      weight    = 2.0,
      checkTrigger = function(self, t, isReadyFlag)
          if not anyPlayerInZone(self.zone) then return false end
          return isReadyFlag and true or false
      end,
      ...
  })
  ```

- Event starts when:
  - At least one player is in HFIL.
  - Another system explicitly calls:
    - `WorldEventSystem.MarkEventReady("HFIL_NEEDLE_STAMPEDE")`.
  - `rollChance` is not used here; instead, `isReadyFlag` is required (scripted trigger).

### Duration and Cooldown
- Duration: **240 seconds** (4 minutes).
- Cooldown: **900 seconds** (15 minutes).

### Start Flow
On `onStart(ctx, t)`:

1. Emits:
   - `emit("HFIL_EVENT", { kind = "STAMPEDE", phase = "START" })`
2. Logs:
   - `"Needle Spire Stampede started"` to debug output.
3. Initializes:
   - `ctx.data.herdsCleared = 0` (counter for future gameplay).

### Kill & Action Logic
- Currently **not implemented** – both `onKill` and `onAction` are no-ops.
- Intent:
  - `onKill` should recognize specific "herd" units and credit players for breaking up the stampede.
  - Additional metrics could track:
    - Time to intercept a herd.
    - Number of herds that reach escape points (fail conditions).

### End Flow
On `onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("HFIL_EVENT", { kind = "STAMPEDE", phase = "END", reason = reason })`
2. Logs:
   - `"Needle Spire Stampede ended (<reason>)"`.

## Design Hooks / Expansion Plan

### Herd Spawns
You can implement herd logic similar to Spirit Surge waves, but with pathing behavior:

- Define herd templates:
  - Herd leader unit type.
  - 3–8 followers.
- Spawn them at predefined herd entry points in the Needle Spire sub-zone.
- Order them to move along spline/path points between spires.

### Player Goals
Possible objective patterns:

1. **Intercept & Break:**
   - Each herd moving from point A → B.
   - If herd is fully killed before reaching B → `herdsCleared++`.
   - If any herd reaches B → lose potential bonus or fail threshold.

2. **Protect Shrines or Rifts:**
   - Stampede units target one or more important structures.
   - Each destroyed structure reduces final rewards.

3. **Shard Charge Progress:**
   - Kills during stampede charge a special HFIL shard faster than normal.

### Reward Model
You can reuse the Spirit Surge reward model or define a different one:

- Base structure:
  - Per-herd clearance → SoulEnergy, Fragments, optional items.
- Additional reward tiers:
  - Bronze/Silver/Gold depending on `ctx.data.herdsCleared` vs. total spawned.

### Integration Points
- Event signals through:
  - `"HFIL_EVENT"` with `kind = "STAMPEDE"` and phases.
  - `"WorldEventStarted"` / `"WorldEventEnded"` from `WorldEventSystem`.

Use these to:
- Turn on red/amber lighting in Needle Spire subzone.
- Add ground crack FX and dust trails along herd paths.
- Spawn world markers showing herd lanes.

### Tuning Knobs
- Duration: `duration = 240.0`.
- Cooldown: `cooldown = 900.0`.
- Trigger method:
  - Currently manual via `MarkEventReady`; you can add `rollChance` similar to Spirit Surge.
- Difficulty can scale via:
  - Number of herds.
  - Herd movement speed.
  - Herd unit composition (tiered mobs similar to Spirit Surge).

## Implementation Notes
- Currently safe but **non-functional** from a gameplay perspective (no herd spawns yet).
- Exists as a placeholder "slot" in the event system so you can wire it later without changing the core world event framework.
