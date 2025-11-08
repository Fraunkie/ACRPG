# ALICE 2.11.2 Noob's Guide for Warcraft III Integration

## Introduction

ALICE 2.11.2 (A Limitless Interaction Caller Engine) is a powerful Lua framework designed to manage actors and interactions in Warcraft III custom maps.
It allows you to easily create and control projectiles, interactions, physics-based objects, and much more, all while optimizing for performance.
This guide is designed for beginners and explains how to set up and use ALICE in your map.

**Table of Contents:**
1. Setting Up ALICE
2. Creating and Managing Actors
3. Actor Interactions
4. Handling Missiles and Projectiles
5. Debugging and Troubleshooting
6. Integrating ALICE with Existing Systems (e.g., Combat, Spells)
7. Performance Optimization and Best Practices

## 1. Setting Up ALICE

To get started with ALICE, you need to import the ALICE library files into your Warcraft III map. Here's the process:

1. **Download ALICE** from the HiveWorkshop page.
2. **Import the ALICE files** into your Warcraft III map:
   - ALICE2.11.lua
   - ALICE_API.lua
   - Any dependencies (HandleType, Hook, PrecomputedHeightMap)
3. **Initialize ALICE** in your map's main initialization file (e.g., TotalInitialization.lua):
   - Add the line: `require "ALICE2.11"` or `dofile("ALICE2.11.lua")`.
4. **Test the Setup** by creating a simple actor or projectile and verify if the system is working as expected.

## 2. Creating and Managing Actors

Actors are the core objects in ALICE. They can represent anything in the game: units, items, destructibles, or custom projectiles (gizmos).

Here's how to create an actor:

```lua
local actor = ALICE_Create(host, identifier, interactions, flags)
host: The object to which the actor is attached (unit, item, etc.).

identifier: A unique string or list of strings that identify the actor.

interactions: A table defining how the actor interacts with other actors (e.g., collision checks, damage functions).

flags: A table defining additional properties such as isStationary, zOffset, and radius.

Example actor creation for a projectile:

lua
Copy code
local missile = {
  identifier = "missile",
  interactions = {
    unit = OnMissileHitUnit,
    terrain = OnMissileHitTerrain
  },
  radius = 50,
  speed = 600
}
ALICE_Create(missile, caster.x, caster.y, caster.z)
Once an actor is created, it automatically begins interacting based on the specified interactions table.

3. Actor Interactions
ALICE allows you to define interactions between actors using a simple interaction system.
Each actor can have interactions with other actors (e.g., collision, triggering events).

Interactions are defined in the interactions table of an actor and can be functions that handle these events.

Example interaction when a missile hits a unit:

lua
Copy code
function OnMissileHitUnit(missile, unitActor, x, y, z, speed)
  -- Apply damage to the unit
  DamageEngine:Apply(missile, unitActor.unit, {damage = 50})
  -- Destroy the missile
  ALICE_Destroy(missile)
end
In this example, when the missile collides with a unit, the OnMissileHitUnit function is called to apply damage using the DamageEngine, and then the missile is destroyed.

4. Handling Missiles and Projectiles
Missiles and projectiles are treated as actors in ALICE. You can define their behavior by setting up properties such as speed, trajectory, and interactions.

Here is how to create and launch a missile:

lua
Copy code
function LaunchMissile(caster, targetX, targetY, params)
  local missileActor = {
    identifier = params.id or "missile",
    interactions = {
      unit = OnMissileHitUnit,
      terrain = OnMissileHitTerrain
    },
    radius = params.radius or 50,
    speed = params.speed or 600,
  }
  ALICE_Create(missileActor, caster.x, caster.y, caster.z)
  -- set velocity vector and movement direction
end
When the missile hits a target, the defined interaction will be triggered, such as dealing damage or applying an effect.

You can also simulate projectile trajectories with simple math:

lua
Copy code
function OnMissileHitTerrain(missile, x, y, z, speed)
  -- Do something when the missile hits terrain
  print("Missile hit terrain at coordinates (" .. x .. ", " .. y .. ")")
end
With this setup, you can create a variety of projectile-based spells or effects in your map.

5. Debugging and Troubleshooting
ALICE includes a powerful debugging system that allows you to visualize actors, their interactions, and their states.

To enable debug mode, use:

lua
Copy code
ALICE_Debug()
In debug mode, you can visualize interactions between objects, such as missile paths or actor collisions.

You can also use the following functions to get actor details:

lua
Copy code
ALICE_Select(actor)
ALICE_GetDescription(actor)
ALICE_ListGlobals()
Use these functions to monitor your actors and interactions during development.

ALICE provides tools for performance analysis, and you can check the evaluation time of various functions using:

lua
Copy code
ALICE_Statistics()
ALICE_Benchmark()
These debugging tools will help you identify any issues with actor behavior or performance, making it easier to fine-tune your game systems.

6. Integrating ALICE with Existing Systems (e.g., Combat, Spells)
ALICE can be easily integrated into your existing Warcraft III systems such as combat, spells, and abilities.

For example, if you want to integrate ALICE's missile system with your DamageEngine system, you can trigger damage events when a missile hits a target.

Here is an example of integration with the SpellSystem:

lua
Copy code
function LaunchMissile(caster, targetX, targetY, params)
  local missileActor = {
    identifier = params.id or "missile",
    interactions = {
      unit = function(missile, unitActor, x, y, z, speed)
        -- Apply damage using the DamageEngine
        DamageEngine:Apply(caster, unitActor.unit, {damage = params.damage})
        ALICE_Destroy(missile)  -- Destroy the missile after impact
      end
    },
    radius = params.radius or 50,
    speed = params.speed or 600,
  }
  ALICE_Create(missileActor, caster.x, caster.y, caster.z)
end
With this setup, you can create complex spell effects that involve missiles, projectiles, and interactions with the combat system.

Similarly, SoulEnergy or StatSystem can also interact with ALICE actors. You could, for example, increase projectile damage based on the player's current soul energy level or stats.

7. Performance Optimization and Best Practices
To ensure smooth performance in your game, follow these best practices:

Use Cells Efficiently: ALICE divides the map into cells to optimize interactions. Keep your actors within cells to minimize unnecessary calculations.

Limit Actor Interactions: Only interact with objects that are within the same cell or close by. This is managed automatically by ALICE, but you can fine-tune your interaction ranges.

Optimize Collision Checks: Avoid frequent and unnecessary collision checks, especially for high‑speed objects like missiles.

Leverage Debugging Tools: Use ALICE's debugging and performance monitoring tools (ALICE_Statistics, ALICE_Benchmark) to identify bottlenecks and improve game flow.

Keep Actors Simple: Don't overload actors with unnecessary properties. Focus on what matters to performance (e.g., movement speed, collision radius, etc.).

By following these guidelines, you'll ensure that your ALICE-powered systems run smoothly and efficiently even in complex RPG maps.

vbnet
Copy code

This is a fully formatted **markdown guide** with everything included in a code block. You can copy and paste this directly into your project documentation.

Let me know if you need anything else!