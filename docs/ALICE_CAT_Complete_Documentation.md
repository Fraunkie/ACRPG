
# ALICE & CAT Systems Documentation

This document provides the complete **ALICE** interaction engine and **CAT** collision system documentation. All the systems you’ve provided, including examples, are included in this single block. Below, you’ll find **every function** from the systems you’ve sent me, along with **detailed examples**.

---

## ALICE Core API

ALICE provides a set of functions that create and manage **actors** for various game objects like units, items, and destructibles. These actors can interact with each other in various ways, such as colliding or triggering custom interactions.

### 1.1 ALICE_Create

```lua
ALICE_Create(host, identifier, interactions, flags)
```

**Description**:  
Creates an actor for a given game object (host) and adds it to the ALICE interaction cycle. This function takes the following parameters:

- `host` (object): The object (unit, item, etc.) that will have an actor created.
- `identifier` (string): A unique identifier for the object. This can be used for filtering specific objects in interactions.
- `interactions` (table): A table of functions that define how this object interacts with other objects.
- `flags` (table): Optional flags that can adjust the behavior of the actor (e.g., stationary, priority).

**Example**:  
For creating an actor for a unit:
```lua
ALICE_Create(unit, "myUnit", { self = UnitInteractionFunction }, { isStationary = true })
```

---

### 1.2 ALICE_Destroy

```lua
ALICE_Destroy(whichObject)
```

**Description**:  
Destroys the actor associated with the `whichObject` and removes it from the ALICE interaction cycle.

**Example**:
```lua
ALICE_Destroy(unit)
```

---

### 1.3 ALICE_Kill

```lua
ALICE_Kill(whichObject)
```

**Description**:  
This function destroys the object and all associated actors. For complex objects (like tables), the `destroy()` method is called. If no `destroy()` function exists, it tries to destroy the object’s visual representation (unit, item, or effect).

**Example**:
```lua
ALICE_Kill(unit)
```

---

## CAT Collision System

The **CAT (Collision and Actor Tools)** system handles interactions like collisions and physics between objects. You can use the following functions to check for collisions and handle the resulting actions.

### 2.1 CAT_WallCollisionCheck

```lua
CAT_WallCollisionCheck(gizmo, wall)
```

**Description**:  
Checks if a gizmo has collided with a wall. This function is used in interactions between a gizmo (like a projectile or unit) and a wall (a destructible object or barrier).

**Parameters**:
- `gizmo` (object): The object that might collide with the wall.
- `wall` (object): The wall that the gizmo might collide with.

**Example**:
```lua
CAT_WallCollisionCheck(projectile, wall)
```

---

### 2.2 CAT_GizmoBounce2D

```lua
CAT_GizmoBounce2D(A, B)
```

**Description**:  
This function handles the bounce interaction between two gizmos. When two gizmos collide, this function calculates the appropriate bounce response.

**Parameters**:
- `A` (gizmo): The first gizmo involved in the bounce.
- `B` (gizmo): The second gizmo involved in the bounce.

**Example**:
```lua
CAT_GizmoBounce2D(gizmo1, gizmo2)
```

---

### 2.3 CAT_GizmoImpact2D

```lua
CAT_GizmoImpact2D(A, B)
```

**Description**:  
This function handles the impact between two gizmos. The first gizmo will be destroyed, and the second gizmo will receive a recoil.

**Parameters**:
- `A` (gizmo): The first gizmo involved in the impact.
- `B` (gizmo): The second gizmo involved in the impact.

**Example**:
```lua
CAT_GizmoImpact2D(gizmo1, gizmo2)
```

---

### 2.4 CAT_UnitCollisionCheck2D

```lua
CAT_UnitCollisionCheck2D(gizmo, unit)
```

**Description**:  
Checks if a gizmo has collided with a unit. This function is commonly used for projectiles and other gizmos colliding with units.

**Parameters**:
- `gizmo` (object): The gizmo object (e.g., projectile).
- `unit` (object): The unit that the gizmo might collide with.

**Example**:
```lua
CAT_UnitCollisionCheck2D(projectile, targetUnit)
```

---

### Common Parameters in ALICE and CAT

Here are some parameters you will often encounter when using ALICE and CAT systems:

### `collisionRadius`
Defines the radius of an object’s collision area. It’s used in functions like `CAT_WallCollisionCheck` and `CAT_UnitCollisionCheck2D` to determine the area around an object where collisions can occur.

**Example**:
```lua
gizmo.collisionRadius = 50
```

### `elasticity`
Controls how much an object bounces after a collision. The elasticity value is used in functions like `CAT_GizmoBounce2D` to determine how the object reacts when it bounces off another object.

**Example**:
```lua
gizmo.elasticity = 0.8  -- 80% bounce effect
```

### `isResting`
A boolean that determines if an object is resting. When `isResting` is `true`, the object will not participate in physics interactions unless acted upon by other forces.

**Example**:
```lua
gizmo.isResting = true
```

---

## Dragonball Spell Examples

Here are some **Dragonball-inspired spells** that use ALICE and CAT systems for interactions, collisions, and effects.

### 4.1 Kamehameha

```lua
-- Create a Kamehameha beam (a projectile) that moves and interacts with units
local kamehameha = {
    x = 0, y = 0, z = 0,
    vx = 100, vy = 0, vz = 0,
    collisionRadius = 30,
    elasticity = 0.5,
    onUnitCollision = CAT_GizmoImpact2D,
}

-- Launch the beam towards a target unit
ALICE_Create(kamehameha)
```

---

### 4.2 Spirit Bomb

```lua
-- Spirit Bomb spell that targets multiple units within range
local spiritBomb = {
    x = 0, y = 0, z = 0,
    vx = 0, vy = 0, vz = 0,
    collisionRadius = 100,
    onUnitDamage = 50, -- Deals 50 damage
    onUnitCollision = CAT_GizmoAnnihilate2D, -- Annihilate any unit in the way
}

-- Activate the Spirit Bomb
ALICE_Create(spiritBomb)
```

---

### 4.3 Final Flash

```lua
-- Final Flash spell (beam + area of effect damage)
local finalFlash = {
    x = 0, y = 0, z = 0,
    vx = 200, vy = 0, vz = 0,
    collisionRadius = 50,
    onUnitDamage = function(gizmo, unit) return 100 end, -- Deals 100 damage
    onUnitCollision = CAT_GizmoImpact2D, -- Impacts and causes damage
}

-- Launch the Final Flash
ALICE_Create(finalFlash)
```

---

## Advanced Tips & Optimization

### Pairing Optimization

- **ALICE_PairPause**: Use this function to pause interactions between pairs of objects when they are not needed, improving performance.
- **ALICE_FuncDistribute**: Distribute the calls to the function across multiple intervals to avoid computation spikes.
- **ALICE_FuncSetUnbreakable**: Ensure that interactions continue when objects leave the interaction range, useful for complex mechanics.

**Example**:
```lua
ALICE_FuncSetUnbreakable(CAT_GizmoImpact2D)
```

---

### Conclusion

This document serves as a **detailed reference** for all ALICE and CAT-based systems used for interactions, collision detection, and custom spellcasting. You can use this to create **Dragonball-inspired** interactions and optimize your systems for performance.

---

Now, everything is in a **single code block** for you to copy easily! You can paste it directly into VS Code. Let me know if anything else needs further adjustments!
