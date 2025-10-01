# Animal Spawning System Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Setup Instructions](#setup-instructions)
4. [API Reference](#api-reference)
5. [Template System](#template-system)
6. [AI Behavior System](#ai-behavior-system)
7. [Examples and Use Cases](#examples-and-use-cases)
8. [Troubleshooting](#troubleshooting)
9. [Future Improvements](#future-improvements)

---

## System Overview

The Animal Spawning System provides a flexible, template-based framework for spawning and managing wildlife and enemies in Neon Wasteland 3D. It features configurable AI behaviors, dynamic spawning, loot drops, and visual debugging tools.

### Key Features

- **Template-Based Configuration**: Reusable templates for animal types
- **AI Behavior Types**: Passive (flee), Neutral (defensive), Aggressive (attack on sight)
- **Dynamic Spawning**: Area-based spawners with frequency and population control
- **Loot System**: Configurable drop tables with probabilities
- **AI State Machine**: Idle, Wander, Flee, Chase, Attack states
- **Visual Debug Tools**: In-editor spawn area visualization
- **Flexible Integration**: Works with combat and inventory systems

### Core Components

- **Animal.gd** - Base animal script with AI and health
- **AnimalTemplate.gd** - Resource defining animal configuration
- **AnimalDrop.gd** - Resource defining loot drops
- **EntitySpawner.gd** - Spawner node for scene placement
- **SpawnerManager.gd** (optional) - Global spawner coordination

---

## Architecture

### Component Hierarchy

```
EntitySpawner (Node3D in scene)
├── Tracks active_entities: Array[Node3D]
├── Manages spawn timing and limits
└── Spawns from spawn_templates: Array[AnimalTemplate]
    │
    ├── AnimalTemplate (Resource)
    │   ├── scene: PackedScene → Animal instance
    │   ├── Behavior stats (health, speed, ranges)
    │   ├── Combat stats (damage, cooldown)
    │   └── loot_drops: Array[AnimalDrop]
    │       │
    │       └── AnimalDrop (Resource)
    │           ├── item_id: String
    │           ├── min/max_amount: int
    │           └── drop_chance: float
    │
    └── Instantiates → Animal (CharacterBody3D)
        ├── AI state machine
        ├── Health and combat
        └── Loot drop on death
```

### Data Flow

**Spawn Process:**
```
1. EntitySpawner timer triggers
2. Check if active_entities < max_entities
3. Select random template from spawn_templates
4. Calculate random spawn position within radius
5. Instantiate template.scene
6. Call animal.configure_from_template(template)
7. Add to scene and track in active_entities
8. Connect to died signal for cleanup
```

**AI Update Loop:**
```
1. Find player node (cache reference)
2. Calculate distance to player
3. State machine processes current state:
   - IDLE → Stand still, occasionally switch to wander
   - WANDER → Move randomly, check player proximity
   - FLEE → Run away from player
   - CHASE → Pursue player
   - ATTACK → Deal damage when in range
4. Transition to new state based on:
   - Player distance
   - Behavior type (passive/neutral/aggressive)
   - Current health
5. Update velocity and move_and_slide()
```

**Death and Loot:**
```
1. Animal health reaches 0
2. Animal.die() called
3. For each AnimalDrop in loot_drops:
   - Roll random 0.0-1.0
   - If roll <= drop_chance: drop item
   - Random quantity between min_amount and max_amount
4. Spawn item_pickup_3d at animal position
5. Emit died signal
6. Queue animal for removal
```

---

## Setup Instructions

### Method 1: Quick Setup with Existing Templates

#### Step 1: Add Spawner to Scene

1. Open your scene (e.g., `scenes/world/demo_scene.tscn`)
2. Add a Node3D as child of root
3. Rename to describe spawner (e.g., "WolfSpawner", "PassiveAnimals")
4. Attach script: `res://scripts/world/EntitySpawner.gd`

#### Step 2: Configure Spawner Properties

In the Inspector:

**Templates:**
- Drag existing templates from `resources/animals/` into `spawn_templates` array
- Example: rabbit_template.tres, deer_template.tres

**Population:**
- `max_entities`: 8 (how many animals max from this spawner)

**Timing:**
- `spawn_frequency_min`: 10.0 (seconds)
- `spawn_frequency_max`: 20.0 (seconds)

**Area:**
- `spawn_radius`: 25.0 (meters from spawner center)
- `min_spawn_distance`: 8.0 (minimum distance from center)

**Debug:**
- `debug_draw`: true (show spawn area in editor)
- `debug_color`: Color(0, 1, 0, 0.3) (green for passive)

#### Step 3: Position and Test

1. Move the spawner Node3D to desired location (Y = 0 for ground level)
2. Run scene and watch console for spawn messages
3. Adjust properties based on spawn rate and density

### Method 2: Creating Custom Animal from Scratch

#### Step 1: Create Animal Scene

1. **Scene → New Scene**
2. **Add Root Node:** CharacterBody3D
3. **Rename:** Your animal name (e.g., "Fox")
4. **Add Children:**
   - CollisionShape3D (set shape to CapsuleShape3D)
   - MeshInstance3D (assign mesh, e.g., CapsuleMesh or import model)
   - Area3D named "AttackArea" (optional, for melee attacks)
     - Add CollisionShape3D child matching body shape

#### Step 2: Configure Animal Node

**Root (CharacterBody3D):**
- **Script:** Attach `res://scripts/entities/Animal.gd`
- **Groups:** Add to "animals" group
- **Collision Layer:** 16 (Animals)
- **Collision Mask:** 1 (World)

**CollisionShape3D:**
- **Shape:** CapsuleShape3D
- **Radius:** 0.3-0.5 (depends on animal size)
- **Height:** 1.0-2.0
- **Position:** Y = half of height

**MeshInstance3D:**
- **Mesh:** CapsuleMesh (or custom .glb model)
- **Material:** Create StandardMaterial3D with custom color

**Save scene** as `scenes/entities/Fox.tscn`

#### Step 3: Create Loot Drops

1. **FileSystem → resources/animals/**
2. **Right-click → New Resource**
3. **Select:** AnimalDrop
4. **Configure:**
   - `item_id`: "RAW_MEAT"
   - `min_amount`: 1
   - `max_amount`: 2
   - `drop_chance`: 0.8 (80%)
5. **Save as:** `resources/animals/fox_meat_drop.tres`

Repeat for other drops (e.g., leather, bones).

#### Step 4: Create Animal Template

1. **FileSystem → resources/animals/**
2. **Right-click → New Resource**
3. **Select:** AnimalTemplate
4. **Configure Basic:**
   - `animal_name`: "Fox"
   - `scene`: Drag Fox.tscn from scenes/entities/

5. **Configure Behavior:**
   - `behavior_type`: 0 (Passive), 1 (Neutral), or 2 (Aggressive)

6. **Configure Stats:**
   - `max_health`: 40.0
   - `move_speed`: 6.0 (normal movement)
   - `run_speed`: 10.0 (when fleeing/chasing)

7. **Configure AI Ranges:**
   - `aggro_range`: 12.0 (for aggressive/neutral)
   - `flee_range`: 15.0 (for passive/neutral)
   - `attack_range`: 2.0 (melee distance)

8. **Configure Combat:**
   - `attack_damage`: 8.0
   - `attack_cooldown`: 1.2 (seconds between attacks)

9. **Add Loot:**
   - Expand `loot_drops` array
   - Drag fox_meat_drop.tres and other drops

10. **Save as:** `resources/animals/fox_template.tres`

#### Step 5: Add to Spawner

1. Select your EntitySpawner node
2. In `spawn_templates`, add element
3. Drag fox_template.tres into new slot
4. Adjust spawn frequency if needed

### Method 3: Programmatic Spawning

For dynamic/scripted spawning without spawner nodes:

```gdscript
# In your game script
func spawn_animal_at_position(template: AnimalTemplate, position: Vector3):
    if not template or not template.scene:
        return null

    var animal = template.scene.instantiate()
    get_tree().current_scene.add_child(animal)
    animal.global_position = position

    if animal.has_method("configure_from_template"):
        animal.configure_from_template(template)

    return animal

# Usage
func _ready():
    var wolf_template = load("res://resources/animals/wolf_template.tres")
    spawn_animal_at_position(wolf_template, Vector3(10, 0, 10))
```

---

## API Reference

### Animal Class

#### Properties

##### Configuration (set via template)
- `animal_name: String` - Display name
- `behavior_type: BehaviorType` - PASSIVE, NEUTRAL, or AGGRESSIVE
- `max_health: float` - Maximum health points
- `current_health: float` - Current health points
- `move_speed: float` - Normal movement speed (m/s)
- `run_speed: float` - Speed when fleeing or chasing (m/s)
- `aggro_range: float` - Detection range for aggressive/neutral behaviors
- `flee_range: float` - Distance to start fleeing for passive/neutral
- `attack_range: float` - Melee attack distance
- `attack_damage: float` - Damage per attack
- `attack_cooldown: float` - Seconds between attacks
- `loot_drops: Array[AnimalDrop]` - Items dropped on death

##### Internal State
- `current_state: AIState` - Current AI state (IDLE, WANDER, FLEE, CHASE, ATTACK)
- `target_player: Node3D` - Cached player reference
- `attack_timer: float` - Cooldown timer for attacks

#### Methods

##### `configure_from_template(template: AnimalTemplate) -> void`
Configures animal from a template resource.
- **Parameters**: `template` - AnimalTemplate resource
- Sets all stats and behavior from template
- Applies custom mesh if provided

##### `take_damage(amount: float, attacker: Node = null) -> void`
Applies damage to animal.
- **Parameters**:
  - `amount` - Damage to apply
  - `attacker` - Source of damage (optional)
- Reduces current_health
- Triggers flee/aggro behavior
- Calls die() if health reaches 0

##### `die() -> void`
Handles animal death.
- Spawns loot based on loot_drops
- Emits died signal
- Queues animal for removal

##### `is_dead() -> bool`
Returns true if current_health <= 0.

##### `apply_knockback(knockback_force: Vector3) -> void`
Applies knockback force to animal.
- **Parameters**: `knockback_force` - Vector3 force to apply

#### Signals

- `died()` - Emitted when animal dies (health reaches 0)

#### AI States (enum AIState)

- `IDLE` (0) - Standing still
- `WANDER` (1) - Moving randomly
- `FLEE` (2) - Running away from player
- `CHASE` (3) - Pursuing player
- `ATTACK` (4) - Attacking player

#### Behavior Types (enum BehaviorType)

- `PASSIVE` (0) - Flees when player approaches
- `NEUTRAL` (1) - Defends when attacked
- `AGGRESSIVE` (2) - Attacks player on sight

### AnimalTemplate Class

Resource class defining animal configuration.

#### Properties

- `animal_name: String` - Display name
- `scene: PackedScene` - Animal scene to instantiate
- `mesh: Mesh` - Optional mesh override
- `behavior_type: Animal.BehaviorType` - AI behavior
- `max_health: float` - Health points
- `move_speed: float` - Movement speed
- `run_speed: float` - Run speed
- `aggro_range: float` - Aggro detection range
- `flee_range: float` - Flee trigger range
- `attack_range: float` - Attack range
- `attack_damage: float` - Attack damage
- `attack_cooldown: float` - Attack cooldown
- `loot_drops: Array[AnimalDrop]` - Loot table

### AnimalDrop Class

Resource class defining a loot drop.

#### Properties

- `item_id: String` - Item identifier (must match InventorySystem items)
- `min_amount: int` - Minimum drop quantity
- `max_amount: int` - Maximum drop quantity
- `drop_chance: float` - Probability 0.0-1.0 (0.8 = 80% chance)

### EntitySpawner Class

Node that spawns entities in an area.

#### Properties

##### Spawn Configuration
- `spawn_templates: Array[Resource]` - Templates to spawn (AnimalTemplate, etc.)
- `max_entities: int` - Maximum active entities from this spawner

##### Timing
- `spawn_frequency_min: float` - Minimum seconds between spawns
- `spawn_frequency_max: float` - Maximum seconds between spawns

##### Area
- `spawn_radius: float` - Radius of spawn area
- `min_spawn_distance: float` - Minimum distance from center

##### Debug
- `debug_draw: bool` - Show spawn area visualization
- `debug_color: Color` - Color for debug circles

#### Methods

##### `_attempt_spawn() -> void`
Attempts to spawn an entity if under max limit.
- Picks random template
- Finds valid spawn position
- Instantiates and configures entity

##### `_get_random_spawn_position() -> Vector3`
Calculates random position within spawn area.
- **Returns**: Vector3 world position or Vector3.ZERO if invalid

##### `_cleanup_entities() -> void`
Removes invalid/freed entity references from tracking.

---

## Template System

### Template Inheritance

Templates are reusable configurations. You can create base templates and variations:

**Example: Wolf Variations**

**Base Template (wolf_template.tres):**
```
animal_name: "Wolf"
max_health: 80.0
move_speed: 7.0
run_speed: 11.0
attack_damage: 20.0
behavior_type: AGGRESSIVE
```

**Alpha Wolf Variation (alpha_wolf_template.tres):**
```
animal_name: "Alpha Wolf"
max_health: 120.0    # More health
move_speed: 7.0
run_speed: 12.0      # Faster
attack_damage: 30.0  # More damage
behavior_type: AGGRESSIVE
loot_drops: [alpha_pelt, rare_meat]  # Better loot
```

### Template Categories

#### Prey Animals (Passive)
- **Behavior:** Flee when player approaches
- **Stats:** Low health, high run speed, no attack damage
- **Examples:** Rabbit, Deer, Fox (if not aggressive)
- **Loot:** Meat, hide, bones

**Recommended Stats:**
```
behavior_type: PASSIVE
max_health: 20-50
move_speed: 5-7
run_speed: 10-14 (faster than player)
flee_range: 15-20
attack_damage: 0
```

#### Defensive Animals (Neutral)
- **Behavior:** Ignore player until attacked
- **Stats:** Medium health, medium damage
- **Examples:** Boar, Elk, Large Birds
- **Loot:** Meat, hide, tusks

**Recommended Stats:**
```
behavior_type: NEUTRAL
max_health: 60-100
move_speed: 5-7
run_speed: 8-10
aggro_range: 10-12
attack_range: 2.5
attack_damage: 15-25
```

#### Predators (Aggressive)
- **Behavior:** Attack player on sight
- **Stats:** High health, high damage, fast
- **Examples:** Wolf, Bear, Tiger
- **Loot:** Meat, pelt, claws, teeth

**Recommended Stats:**
```
behavior_type: AGGRESSIVE
max_health: 100-250
move_speed: 6-8
run_speed: 10-13
aggro_range: 12-18
attack_range: 2.0-3.0
attack_damage: 25-50
attack_cooldown: 1.5-2.5
```

### Loot Table Design

#### Simple Loot (Common Animals)
```gdscript
# Rabbit
loot_drops = [
  AnimalDrop { item_id: "RAW_MEAT", min: 1, max: 2, chance: 0.95 }
  AnimalDrop { item_id: "RABBIT_PELT", min: 1, max: 1, chance: 0.7 }
]
```

#### Complex Loot (Boss/Rare Animals)
```gdscript
# Alpha Bear
loot_drops = [
  AnimalDrop { item_id: "RAW_MEAT", min: 5, max: 8, chance: 1.0 },      # Always
  AnimalDrop { item_id: "BEAR_PELT", min: 2, max: 3, chance: 0.9 },    # Usually
  AnimalDrop { item_id: "CLAWS", min: 2, max: 4, chance: 0.8 },        # Often
  AnimalDrop { item_id: "BEAR_TOOTH", min: 1, max: 2, chance: 0.5 },   # Sometimes
  AnimalDrop { item_id: "ALPHA_ESSENCE", min: 1, max: 1, chance: 0.1 } # Rare
]
```

#### Loot Probability Math
```
Expected drops per kill:
  drop_chance × average_amount

Example:
  0.8 chance × (1+3)/2 avg = 0.8 × 2 = 1.6 items per kill

For 100% guaranteed at least one item:
  Set one drop with chance: 1.0
```

---

## AI Behavior System

### State Machine Details

#### IDLE State
**Purpose:** Resting, looking around
**Duration:** 2-5 seconds (random)
**Velocity:** Zero
**Transitions:**
- → WANDER after idle_duration
- → FLEE if player within flee_range (passive/neutral)
- → CHASE if player within aggro_range (aggressive)

#### WANDER State
**Purpose:** Patrol area, search for food
**Duration:** 3-6 seconds (random)
**Velocity:** move_speed in random direction
**Transitions:**
- → IDLE after wander_duration
- → FLEE if player within flee_range (passive/neutral)
- → CHASE if player within aggro_range (aggressive)

#### FLEE State
**Purpose:** Escape from player
**Velocity:** run_speed away from player
**Transitions:**
- → IDLE when player distance > flee_range × 1.5

**Direction Calculation:**
```gdscript
var flee_direction = (animal_pos - player_pos).normalized()
velocity = flee_direction * run_speed
```

#### CHASE State
**Purpose:** Pursue player to attack
**Velocity:** run_speed toward player
**Transitions:**
- → ATTACK when player distance <= attack_range
- → IDLE when player distance > aggro_range × 1.5

**Direction Calculation:**
```gdscript
var chase_direction = (player_pos - animal_pos).normalized()
velocity = chase_direction * run_speed
```

#### ATTACK State
**Purpose:** Deal damage to player
**Velocity:** Zero (stop to attack)
**Attack Timer:** attack_cooldown seconds between hits
**Transitions:**
- → CHASE if player distance > attack_range
- → IDLE if player too far away

**Damage Application:**
```gdscript
if attack_timer <= 0:
    CombatSystem.deal_damage(self, target_player, attack_damage, "melee")
    attack_timer = attack_cooldown
```

### Behavior Type Details

#### Passive Behavior
```gdscript
# Always flee from player
if distance_to_player < flee_range:
    enter_flee_state()

# Never chase or attack
# Neutral and aggressive transitions disabled
```

**Use Cases:**
- Prey animals (rabbits, deer)
- Non-threatening wildlife
- Animals for hunting/gathering resources

#### Neutral Behavior
```gdscript
# Only flee if player very close
if distance_to_player < aggro_range * 0.5:
    enter_flee_state()

# Attack if provoked
func take_damage(amount, attacker):
    current_health -= amount
    if attacker == player:
        enter_chase_state()  # Retaliate
```

**Use Cases:**
- Territorial animals (boars, elk)
- Defensive creatures
- Animals that fight back when attacked

#### Aggressive Behavior
```gdscript
# Chase player on sight
if distance_to_player < aggro_range:
    enter_chase_state()

# Attack when in range
if distance_to_player <= attack_range:
    enter_attack_state()
```

**Use Cases:**
- Predators (wolves, bears)
- Hostile enemies
- Guard animals

### Advanced AI Patterns

#### Pack Behavior (Future)
```gdscript
# Wolves coordinate attacks
signal attacked(attacker)

func _on_pack_member_attacked(attacker):
    if behavior_type == NEUTRAL:
        target_player = attacker
        enter_chase_state()
```

#### Health-Based Behavior Change
```gdscript
func take_damage(amount, attacker):
    current_health -= amount

    # Flee when low health
    if current_health < max_health * 0.25:
        behavior_type = PASSIVE  # Temporary flee
        flee_range = aggro_range * 2.0  # Larger flee radius
```

#### Day/Night Behavior (Future)
```gdscript
func _update_ai(delta):
    # More aggressive at night
    if TimeManager.is_night():
        aggro_range = base_aggro_range * 1.5
        attack_damage = base_attack_damage * 1.25
    else:
        aggro_range = base_aggro_range
        attack_damage = base_attack_damage
```

---

## Examples and Use Cases

### Example 1: Passive Animal Zone

**Goal:** Create a safe forest area with deer and rabbits for hunting

```gdscript
# In demo_scene.tscn, add Node3D "ForestSpawner"
# Attach EntitySpawner.gd

# Inspector settings:
spawn_templates = [
    preload("res://resources/animals/rabbit_template.tres"),
    preload("res://resources/animals/deer_template.tres")
]
max_entities = 12
spawn_frequency_min = 8.0
spawn_frequency_max = 15.0
spawn_radius = 35.0
min_spawn_distance = 10.0
debug_color = Color(0.2, 0.8, 0.2, 0.3)  # Light green
```

**Result:** 12 rabbits/deer spawn over 35m area, respawn every 8-15 seconds

### Example 2: Dangerous Wolf Pack Area

**Goal:** Create threatening wolf territory

```gdscript
# Add Node3D "WolfDenSpawner"

spawn_templates = [
    preload("res://resources/animals/wolf_template.tres")
]
max_entities = 6  # Pack of 6 wolves
spawn_frequency_min = 20.0  # Less frequent
spawn_frequency_max = 40.0
spawn_radius = 25.0
min_spawn_distance = 12.0  # Spawn farther from center
debug_color = Color(1.0, 0.0, 0.0, 0.4)  # Red
```

**Result:** Up to 6 aggressive wolves in area, slow respawn for challenge

### Example 3: Mixed Biome with Multiple Behaviors

**Goal:** Realistic ecosystem with prey, neutral, and predators

```gdscript
# Add 3 spawners with overlapping areas

# PassiveSpawner (frequent, many)
spawn_templates = [rabbit, deer, fox]
max_entities = 15
spawn_frequency_min = 5.0
spawn_frequency_max = 12.0

# NeutralSpawner (medium)
spawn_templates = [boar, elk]
max_entities = 8
spawn_frequency_min = 12.0
spawn_frequency_max = 25.0

# PredatorSpawner (rare, few)
spawn_templates = [wolf, bear]
max_entities = 4
spawn_frequency_min = 30.0
spawn_frequency_max = 60.0
```

**Result:** Dynamic ecosystem with food chain simulation

### Example 4: Boss Arena Spawner

**Goal:** Spawn boss enemy when player enters area

```gdscript
# Custom script extending EntitySpawner
extends EntitySpawner

var boss_spawned: bool = false

func _on_player_entered_arena():
    if not boss_spawned:
        # Force spawn boss immediately
        var boss_template = preload("res://resources/animals/alpha_bear_template.tres")
        _spawn_animal(boss_template, global_position)
        boss_spawned = true
```

### Example 5: Dynamic Difficulty Scaling

**Goal:** Increase spawn difficulty based on player level

```gdscript
# In spawner script or game manager
func update_spawn_difficulty(player_level: int):
    for spawner in get_tree().get_nodes_in_group("spawners"):
        if player_level < 5:
            spawner.spawn_templates = [rabbit, deer]
        elif player_level < 10:
            spawner.spawn_templates = [boar, fox]
        else:
            spawner.spawn_templates = [wolf, bear, alpha_wolf]
```

### Example 6: Event-Triggered Spawning

**Goal:** Spawn animals when certain conditions are met

```gdscript
# Storm system triggers more aggressive spawns
func _on_storm_started():
    wolf_spawner.spawn_frequency_min = 5.0  # Faster spawns
    wolf_spawner.max_entities = 10  # More wolves

    # Make wolves more aggressive
    for wolf in get_tree().get_nodes_in_group("animals"):
        if wolf.animal_name == "Wolf":
            wolf.aggro_range *= 1.5
```

### Example 7: Loot Farming Optimization

**Goal:** Create efficient farming spot for specific resources

```gdscript
# Deer farm for leather and meat
spawn_templates = [deer_template]
max_entities = 20  # High population
spawn_frequency_min = 3.0  # Fast respawn
spawn_frequency_max = 6.0
spawn_radius = 40.0  # Large area

# Increase loot drops
deer_template.loot_drops = [
    AnimalDrop { item_id: "RAW_MEAT", min: 3, max: 5, chance: 1.0 },
    AnimalDrop { item_id: "LEATHER", min: 2, max: 4, chance: 0.95 }
]
```

---

## Troubleshooting

### Issue: Animals Don't Spawn

**Symptoms:**
- Spawner node in scene but no animals appear
- Console shows no spawn messages

**Solutions:**

1. **Check spawn templates are assigned:**
   ```gdscript
   # Inspector: spawn_templates array should not be empty
   # Ensure .tres files are loaded
   ```

2. **Verify template has valid scene:**
   ```gdscript
   # In AnimalTemplate resource, check:
   scene = preload("res://scenes/entities/Rabbit.tscn")  # Must not be null
   ```

3. **Check spawn timing:**
   ```gdscript
   # Spawner waits for next_spawn_time
   # Set spawn_frequency_min lower for testing (e.g., 1.0)
   ```

4. **Verify spawn position is valid:**
   ```gdscript
   # Enable debug_draw to see spawn area
   # Ensure spawner is above ground (Y position)
   # Check spawn_radius > min_spawn_distance
   ```

5. **Check console for errors:**
   ```
   Look for: "AnimalTemplate has no scene assigned"
   or: "Failed to instantiate scene"
   ```

### Issue: Animals Fall Through Ground

**Symptoms:**
- Animals spawn but immediately fall through world
- Animals disappear after spawning

**Solutions:**

1. **Check collision layers:**
   ```gdscript
   # Animal collision layer: 16
   # Ground collision layer: 1
   # Animal collision mask should include 1 (World)
   ```

2. **Verify ground has collision:**
   ```gdscript
   # Ground should be StaticBody3D or similar
   # Ground should have CollisionShape3D
   # Ground collision_layer = 1
   ```

3. **Check spawn height:**
   ```gdscript
   # Spawner Y position should be at ground level or slightly above
   # Adjust spawner global_position.y to 0 or 0.5
   ```

4. **Ensure gravity is working:**
   ```gdscript
   # In Animal.gd _physics_process:
   if not is_on_floor():
       velocity.y -= GRAVITY * delta  # Should exist
   ```

### Issue: Animals Don't Move Toward Player

**Symptoms:**
- Animals spawn but stay idle
- Aggressive animals don't chase

**Solutions:**

1. **Verify player is in "player" group:**
   ```gdscript
   # In player script _ready():
   add_to_group("player")
   ```

2. **Check aggro_range:**
   ```gdscript
   # In template, aggro_range should be > 0 for aggressive
   # For testing, set to large value like 50.0
   ```

3. **Verify behavior_type:**
   ```gdscript
   # In template:
   behavior_type = Animal.BehaviorType.AGGRESSIVE  # Or 2
   # Not PASSIVE (0) which always flees
   ```

4. **Check AI state transitions:**
   ```gdscript
   # Add debug print in Animal.gd:
   func _check_player_proximity(distance):
       print("Distance: %f, Aggro: %f, Type: %d" % [distance, aggro_range, behavior_type])
   ```

### Issue: Animals Don't Attack

**Symptoms:**
- Animals chase player but don't deal damage
- No attack animation or cooldown

**Solutions:**

1. **Verify attack_range is correct:**
   ```gdscript
   # attack_range should be >= 2.0 for melee
   # Try increasing to 3.0 for testing
   ```

2. **Check player has take_damage method:**
   ```gdscript
   # In player script:
   func take_damage(amount: int, attacker: Node = null):
       current_health -= amount
       print("Took %d damage from %s" % [amount, attacker.name if attacker else "unknown"])
   ```

3. **Verify CombatSystem exists:**
   ```gdscript
   # In Animal.gd:
   var combat_system = get_node_or_null("/root/CombatSystem")
   if not combat_system:
       push_error("CombatSystem not found!")
   ```

4. **Check attack cooldown:**
   ```gdscript
   # attack_timer must reach 0 before next attack
   # Ensure attack_cooldown is not too high (try 1.0 for testing)
   ```

### Issue: Too Many/Too Few Animals

**Symptoms:**
- Spawn area is overcrowded or empty
- Population doesn't stabilize

**Solutions:**

1. **Adjust max_entities:**
   ```gdscript
   # Reduce for fewer animals
   max_entities = 5
   # Increase for more
   max_entities = 20
   ```

2. **Modify spawn frequency:**
   ```gdscript
   # Slower spawning:
   spawn_frequency_min = 20.0
   spawn_frequency_max = 40.0

   # Faster spawning:
   spawn_frequency_min = 3.0
   spawn_frequency_max = 8.0
   ```

3. **Adjust spawn radius:**
   ```gdscript
   # Larger area = more spread out
   spawn_radius = 50.0

   # Smaller area = more concentrated
   spawn_radius = 15.0
   ```

4. **Check entity cleanup:**
   ```gdscript
   # Ensure died signal is connected
   # Animals should be removed from active_entities on death
   ```

### Issue: No Loot Drops

**Symptoms:**
- Animals die but don't drop items
- Console shows no drop messages

**Solutions:**

1. **Verify item_id matches inventory:**
   ```gdscript
   # In AnimalDrop:
   item_id = "RAW_MEAT"  # Must match item in InventorySystem data

   # Check data/items.json has this ID
   ```

2. **Check drop_chance:**
   ```gdscript
   # drop_chance must be > 0
   drop_chance = 0.8  # Not 0.0
   ```

3. **Verify item_pickup_3d scene exists:**
   ```gdscript
   # Animal.die() loads:
   var pickup_scene = load("res://scenes/items/item_pickup_3d.tscn")
   # Ensure this file exists
   ```

4. **Check loot_drops array:**
   ```gdscript
   # In template, ensure array has elements:
   loot_drops = [meat_drop, leather_drop]  # Not empty []
   ```

### Issue: Debug Visualization Not Showing

**Symptoms:**
- debug_draw = true but no circles in editor
- Can't see spawn area

**Solutions:**

1. **Ensure spawner has _draw method:**
   ```gdscript
   # EntitySpawner should have _ready_debug() called
   # Check if Godot 4 _draw works with Node3D (may need ImmediateMesh)
   ```

2. **Try manual visualization:**
   ```gdscript
   # Add MeshInstance3D child to spawner
   # Create TorusMesh with radius = spawn_radius
   # Set material with transparency
   ```

3. **Use 3D gizmo instead:**
   ```gdscript
   # In editor, select spawner and look for orange/green radius indicator
   ```

---

## Future Improvements

### Planned Features

#### 1. Group Behavior / Pack AI
**Priority:** High
**Description:** Animals coordinate as groups

**Features:**
- Pack leader with followers
- Coordinated attacks (surround player)
- Shared aggro (attacking one alerts all)
- Formation movement

**Implementation:**
```gdscript
class_name AnimalPack
extends Node

var pack_leader: Animal
var pack_members: Array[Animal] = []

func _on_member_attacked(attacker: Node):
    for member in pack_members:
        member.target_player = attacker
        member.enter_chase_state()
```

#### 2. Advanced Pathfinding
**Priority:** Medium
**Description:** Use NavigationAgent3D for smarter movement

**Features:**
- Navigate around obstacles
- Follow terrain contours
- Avoid cliffs and water
- Path to player even through complex geometry

**Migration:**
```gdscript
# Replace direct velocity setting with:
@onready var nav_agent: NavigationAgent3D

func _state_chase(delta, distance):
    nav_agent.target_position = target_player.global_position
    var next_position = nav_agent.get_next_path_position()
    velocity = (next_position - global_position).normalized() * run_speed
```

#### 3. Day/Night Behavior Changes
**Priority:** Low
**Description:** Different behavior based on time of day

**Examples:**
- Wolves more aggressive at night
- Deer only spawn during day
- Some animals sleep during specific times

**Implementation:**
```gdscript
func _update_ai(delta):
    if TimeManager.is_night():
        aggro_range = base_aggro_range * 1.5
        behavior_type = AGGRESSIVE
    else:
        aggro_range = base_aggro_range
        behavior_type = NEUTRAL
```

#### 4. Territory System
**Priority:** Medium
**Description:** Animals defend specific areas

**Features:**
- Define territory boundaries
- More aggressive within territory
- Chase player to boundary, then return
- Multiple animals share territory

**Data:**
```gdscript
@export var territory_center: Vector3
@export var territory_radius: float = 20.0

func _state_chase(delta, distance):
    var dist_from_territory = global_position.distance_to(territory_center)
    if dist_from_territory > territory_radius:
        enter_return_to_territory_state()
```

#### 5. Seasonal Spawning
**Priority:** Low
**Description:** Different animals per season

**Examples:**
- Bears hibernate in winter (don't spawn)
- Birds migrate in fall
- Rabbits more common in spring

**Implementation:**
```gdscript
# In EntitySpawner
func _attempt_spawn():
    var current_season = TimeManager.get_season()
    var valid_templates = spawn_templates.filter(
        func(t): return current_season in t.active_seasons
    )
```

#### 6. Animal Animations
**Priority:** High
**Description:** Proper 3D animations for states

**Animations Needed:**
- Idle (breathing, looking around)
- Walk cycle
- Run cycle
- Attack animation
- Death animation
- Eating/grazing

**Integration:**
```gdscript
@onready var anim_player: AnimationPlayer

func _state_idle(delta):
    anim_player.play("idle")
    velocity = Vector3.ZERO

func _state_wander(delta):
    anim_player.play("walk")
    velocity = wander_direction * move_speed
```

#### 7. Improved Loot System
**Priority:** Medium
**Description:** More complex loot mechanics

**Features:**
- Quality tiers (poor, normal, good, excellent)
- Condition-based drops (kill method affects loot)
- Rare drops with low chance
- Bonus drops based on player stats (luck)

**Example:**
```gdscript
class_name AnimalDrop
@export var quality_modifiers: Dictionary = {
    "headshot": 1.5,     # +50% quality
    "stealth_kill": 1.25 # +25% quality
}
```

#### 8. Sound Effects
**Priority:** High
**Description:** Audio for animals

**Sounds Needed:**
- Idle sounds (breathing, ambient)
- Movement sounds (footsteps)
- Aggro sounds (growl, roar)
- Attack sounds (bite, claw)
- Death sounds
- Damage taken sounds

**Setup:**
```gdscript
@onready var audio: AudioStreamPlayer3D

func take_damage(amount, attacker):
    audio.stream = damage_sound
    audio.play()
    current_health -= amount
```

#### 9. Dynamic Spawn Zones
**Priority:** Low
**Description:** Spawners that move or change

**Examples:**
- Migration paths (animals move across map)
- Seasonal movement
- Following resources (herbivores follow grass)

#### 10. Animal Interactions
**Priority:** Low
**Description:** Animals interact with each other

**Features:**
- Predators hunt prey animals
- Herbivores avoid predators
- Social animals stay together
- Territorial fights between same species

### Performance Optimizations

#### 1. Spatial Partitioning
**Current:** All animals check all players
**Improved:** Divide world into grid, only check nearby players

```gdscript
# Optimization: Only update AI if player within max range
func _physics_process(delta):
    if not target_player:
        return

    var distance = global_position.distance_to(target_player.global_position)
    if distance > max_update_range:
        return  # Skip AI update if far away
```

#### 2. LOD System
**Current:** All animals run full AI
**Improved:** Simplified AI for distant animals

```gdscript
func _physics_process(delta):
    var distance = global_position.distance_to(target_player.global_position)

    if distance > 50.0:
        # Very far: freeze
        return
    elif distance > 25.0:
        # Far: simple AI (walk randomly)
        _state_wander(delta)
    else:
        # Near: full AI
        _update_ai(delta)
```

#### 3. Entity Pooling
**Current:** Instantiate/free animals constantly
**Improved:** Reuse animal instances

```gdscript
class_name AnimalPool
var inactive_animals: Array[Animal] = []

func get_animal(template: AnimalTemplate) -> Animal:
    if inactive_animals.is_empty():
        return create_new_animal(template)
    else:
        var animal = inactive_animals.pop_back()
        animal.configure_from_template(template)
        return animal

func return_animal(animal: Animal):
    inactive_animals.append(animal)
```

### Known Limitations

1. **No Pathfinding:** Animals move in straight lines, can get stuck on obstacles
2. **Simple State Machine:** Only 5 states, no complex behavior trees
3. **No Animal-Animal Interaction:** Animals ignore each other
4. **Fixed Spawn Areas:** Spawners are static, no migration
5. **No Animation:** Uses placeholder meshes, no proper animations
6. **Instant Respawn:** No delay for ecological balance
7. **No Sound:** Silent animals
8. **Basic Loot:** Simple drop table, no quality variation

---

**Last Updated:** 2025-10-01
**System Version:** 0.1.0
**Author:** Spawning System Team
**Related Documentation:**
- See `ANIMAL_SYSTEM.md` for user-facing setup guide
- See `COMBAT_SYSTEM.md` for damage and combat integration
