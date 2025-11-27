# Yemma’s Bureau – Ledger Overflow (World Event)

## ID
`YEMMA_LEDGER_OVERFLOW`

## Zone
- Uses custom zone key: `"BUREAU"`
  - Represents King Yemma’s Bureau / main administrative area.

## High-Level Fantasy
The Great Convergence has jammed HFIL’s paperwork systems. Soul intake forms, reassignment slips, and cross-universe paperwork have piled up. King Yemma declares a temporary emergency: anyone who helps process the backlog will earn his favor (and rewards).

This is a **non-combat, interaction-focused administrative event** set in the Bureau.

## Core Behavior (Current Implementation)

### Trigger Logic
Registered event:

```lua
registerEvent({
    id        = "YEMMA_LEDGER_OVERFLOW",
    name      = "Ledger Overflow",
    zone      = "BUREAU",
    duration  = 240.0,
    cooldown  = 2400.0,
    weight    = 1.0,
    checkTrigger = function(self, t, isReadyFlag)
        return isReadyFlag and anyPlayerInZone(self.zone)
    end,
    ...
})
```

Conditions:
- At least one player must be in the `"BUREAU"` zone.
- Event **only triggers** when explicitly flagged:
  - `WorldEventSystem.MarkEventReady("YEMMA_LEDGER_OVERFLOW")`.

No random `rollChance` – this is a **scripted/scheduled** event by design (e.g. triggered after certain storyline milestones).

### Duration and Cooldown
- Duration: **240 seconds** (4 minutes).
- Cooldown: **2400 seconds** (40 minutes).

### Start Flow
On `onStart(ctx, t)`:

1. Emits:
   - `emit("YEMMA_EVENT", { id = "LEDGER_OVERFLOW", phase = "START" })`
2. Debug log:
   - `"Ledger Overflow started"`.
3. Initializes:
   - `ctx.data.formsTotal = 0`.

This counter is meant to track all forms filed during the event.

### Action Tracking
The event is driven by **actions**, not kills.

`onAction`:

```lua
onAction = function(ctx, pid, kind, amount)
    if kind == "file_form" then
        WorldEventSystem.AddActionContribution(pid, kind, amount)
        ctx.data.formsTotal = (ctx.data.formsTotal or 0) + amount
    end
end
```

Expected integration:

- Some UI or interaction system in the Bureau detects when a player:
  - Files a soul form.
  - Validates a document.
  - Stamps a reassignment sheet.
- That system calls:
  - `WorldEventSystem.ReportAction(pid, "file_form", 1)`.

Effects:
- `ctx.data.formsTotal` tracks total filing work done across all players.
- Per-player contributions are tracked by:
  - `ctx.actionsByPlayer[pid]["file_form"]`.

### End Flow
On `onEnd(ctx, t, reason)`:

1. Emits:
   - `emit("YEMMA_EVENT", { id = "LEDGER_OVERFLOW", phase = "END", reason = reason })`
2. Debug log:
   - `"Ledger Overflow ended (<reason>)"`.

Currently this event does **not** auto-grant rewards inside its definition block, leaving them to be implemented later once your Bureau systems and currencies are settled.

## Intended Gameplay Loops

### Filing Mini-Game
You can easily attach this event to a mini-game in the Bureau:

- Examples:
  - Sort souls into correct queues (DBZ, Pokémon, Digi, Naruto sectors).
  - Stamp incoming forms for special souls (e.g. Garlic Jr.’s followers, rogue shinobi).
  - Cancel or correct misfiled HFIL entries.

Each success calls:

```lua
WorldEventSystem.ReportAction(pid, "file_form", 1)
```

### Reward Ideas
Based on:

- `ctx.data.formsTotal` → global efficiency of players.
- `ctx.actionsByPlayer[pid]["file_form"]` → individual contribution.

You could grant:

- Yemma favor points (a meta-currency).
- Extra fragments or soul energy.
- Special Bureau-only cosmetics or flavor items:
  - “Signed Soul Ledger Page”.
  - “Enchanted Stamp of Approval”.
  - Temporary buff scrolls for HFIL zone.

### Integration Points

#### Events Emitted
- `"YEMMA_EVENT"` with `{ id = "LEDGER_OVERFLOW", phase = "START" | "END", reason? }`.
- `"WorldEventStarted"` / `"WorldEventEnded"` generic signals from `WorldEventSystem`.

Use them to:
- Animate stacks of papers and books in Yemma’s office.
- Spawn glowing “urgent” queues or flashing lamps.
- Highlight interactive desks and counters during the event.

### Tuning Knobs
- `duration = 240.0` → length of mini-game window.
- `cooldown = 2400.0` → long downtime, preserving special feeling.
- `weight = 1.0` → relative priority if you later allow random triggering.
- `checkTrigger`:
  - Currently event is **fully controlled** by `MarkEventReady`.
  - You can add `rollChance` if you want it to trigger occasionally while players idle in the Bureau.

## Implementation Status
- Fully integrated with world event driver.
- Tracks `"file_form"` actions and global total forms.
- Has no built-in rewards **on purpose** so you can design Bureau economy & favor systems separately while still relying on this event’s hooks to drive them.
