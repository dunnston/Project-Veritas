# Animal System Documentation

## Overview
The Animal System provides a complete template-based framework for spawning and managing wildlife with configurable AI behaviors, combat mechanics, and loot drops. Animals can be passive (flee from player), neutral (defensive), or aggressive (attack on sight).

## System Architecture

### Core Components
- **Animal.gd**: Base script with AI state machine and combat logic
- **AnimalTemplate.gd**: Resource defining animal type configuration
- **AnimalDrop.gd**: Resource defining loot drop configuration
- **EntitySpawner.gd**: Generic spawner for animals and enemies

## Creating a New Animal

### Step 1: Create the Animal Scene

1. **Open Godot** and navigate to `scenes/entities/`

2. **Create a new scene** or duplicate an existing animal scene (recommended)
   - Right-click `scenes/entities/` → New Scene
   - Or right-click an existing animal (e.g., `Rabbit.tscn`) → Duplicate

3. **Scene Structure** (if creating from scratch):
   ```
   CharacterBody3D (root)
   ├── CollisionShape3D
   ├── MeshInstance3D
   └── AttackArea (Area3D)
       └── CollisionShape3D
   ```

4. **Configure the Root Node**:
   - **Type**: `CharacterBody3D`
   - **Script**: Attach `res://scripts/entities/Animal.gd`
   - **Groups**: Add to "animals" group
   - **Collision Layer**: 16 (Animals)
   - **Collision Mask**: 1 (World)

5. **Set Up Collision**:
   - Add `CollisionShape3D` as child
   - Choose shape (CapsuleShape3D recommended)
   - Adjust size for your animal
   - Position: Y offset = half the height

6. **Add Visual Mesh**:
   - Add `MeshInstance3D` as child
   - Assign mesh (capsule, box, or custom model)
   - Match position with collision shape
   - Optional: Add `StandardMaterial3D` with custom color

7. **Configure Attack Area** (optional):
   - Add `Area3D` node named "AttackArea"
   - Collision Layer: 0
   - Collision Mask: 2 (Player)
   - Add child `CollisionShape3D` matching body shape

8. **Save the scene** as `scenes/entities/YourAnimalName.tscn`

### Step 2: Create Loot Drops

1. **In Godot**, go to FileSystem panel
2. Navigate to `resources/animals/`
3. Right-click → New Resource
4. Search for and select `AnimalDrop`
5. Configure the drop:
   - **item_id**: Item identifier (e.g., "raw_meat", "leather", "bone")
   - **min_amount**: Minimum quantity (e.g., 1)
   - **max_amount**: Maximum quantity (e.g., 3)
   - **drop_chance**: Probability 0.0-1.0 (e.g., 0.8 = 80% chance)
6. Save as `resources/animals/your_animal_drop_name.tres`
7. **Repeat** for each type of drop your animal can have

### Step 3: Create Animal Template

1. **Create new resource**:
   - Navigate to `resources/animals/`
   - Right-click → New Resource
   - Select `AnimalTemplate`

2. **Configure Basic Info**:
   - **animal_name**: Display name (e.g., "Fox")
   - **scene**: Drag your animal scene from Step 1
   - **mesh**: (Optional) Override mesh

3. **Set Behavior Type**:
   - **PASSIVE (0)**: Flees when player approaches or attacked
   - **NEUTRAL (1)**: Only attacks when provoked
   - **AGGRESSIVE (2)**: Attacks player on sight

4. **Configure Health**:
   - **max_health**: Total HP (e.g., 50.0 for medium animal)

5. **Set Movement Speeds**:
   - **move_speed**: Normal wandering speed (e.g., 5.0)
   - **run_speed**: Speed when fleeing/chasing (e.g., 8.0)

6. **Configure AI Ranges**:
   - **aggro_range**: Distance to detect and chase player (e.g., 12.0)
   - **flee_range**: Distance to start fleeing (for passive/neutral) (e.g., 15.0)
   - **attack_range**: Melee attack distance (e.g., 2.5)

7. **Set Combat Stats**:
   - **attack_damage**: Damage per hit (e.g., 15.0)
   - **attack_cooldown**: Seconds between attacks (e.g., 1.5)

8. **Add Loot Drops**:
   - Expand **loot_drops** array
   - Click "Add Element"
   - Drag your AnimalDrop resources from Step 2
   - Add multiple drops for varied loot tables

9. **Save** as `resources/animals/your_animal_template.tres`

## Adding Animals to a Scene

### Method 1: Using Spawners (Recommended)

1. **Open your scene** (e.g., `scenes/world/demo_scene.tscn`)

2. **Create Spawner Node**:
   - Right-click scene root → Add Child Node
   - Select `Node3D`
   - Rename to describe purpose (e.g., "ForestSpawner")

3. **Attach Spawner Script**:
   - Select the new Node3D
   - In Inspector, click script icon → Load
   - Select `res://scripts/world/EntitySpawner.gd`

4. **Configure Spawner**:
   - **spawn_templates**: Array of AnimalTemplate resources
     - Click "Add Element"
     - Drag animal templates from `resources/animals/`
     - Can include multiple types in one spawner

   - **max_entities**: Maximum animals spawned at once (e.g., 8)

   - **spawn_frequency_min**: Minimum seconds between spawns (e.g., 5.0)

   - **spawn_frequency_max**: Maximum seconds between spawns (e.g., 15.0)

   - **spawn_radius**: How far from spawner center (e.g., 25.0)

   - **min_spawn_distance**: Minimum distance from center (e.g., 5.0)

   - **debug_draw**: Enable to see spawn circles (true/false)

   - **debug_color**: Color for spawn visualization (e.g., green for passive)

5. **Position the Spawner**:
   - Move the Node3D to desired world location
   - Y position should be at ground level (usually 0)

6. **Save the scene**

### Method 2: Direct Placement

1. **Drag animal scene** into your level
2. Position where desired
3. Animal will use default stats from its script
4. To customize: Select instance → Make Local → Edit properties
5. Not recommended for dynamic spawning

## Spawner Configuration Examples

### Passive Animal Zone (Rabbits, Deer)
```gdscript
spawn_templates = [rabbit_template, deer_template]
max_entities = 10
spawn_frequency_min = 8.0
spawn_frequency_max = 20.0
spawn_radius = 30.0
min_spawn_distance = 10.0
debug_color = Color(0, 1, 0, 0.3)  # Green
```

### Neutral Animal Zone (Boars)
```gdscript
spawn_templates = [boar_template]
max_entities = 5
spawn_frequency_min = 10.0
spawn_frequency_max = 25.0
spawn_radius = 20.0
min_spawn_distance = 8.0
debug_color = Color(1, 1, 0, 0.3)  # Yellow
```

### Aggressive Predator Zone (Wolves, Bears)
```gdscript
spawn_templates = [wolf_template, bear_template]
max_entities = 4
spawn_frequency_min = 15.0
spawn_frequency_max = 35.0
spawn_radius = 35.0
min_spawn_distance = 15.0
debug_color = Color(1, 0, 0, 0.3)  # Red
```

## Understanding Animal Behaviors

### Passive Animals
- **Flee Range**: Starts running when player within this distance
- **Run Speed**: Should be faster than player for escape
- **Use For**: Prey animals, harmless creatures
- **Examples**: Rabbit, Deer, Small Birds

### Neutral Animals
- **Aggro Range**: Only relevant if attacked first
- **Flee Range**: May retreat if health low
- **Use For**: Defensive wildlife, territorial animals
- **Examples**: Boar, Elk, Ostrich

### Aggressive Animals
- **Aggro Range**: Attacks when player enters this distance
- **Chase**: Pursues player at run_speed
- **Attack Range**: Stops and attacks when close enough
- **Use For**: Predators, hostile creatures
- **Examples**: Wolf, Bear, Tiger

## AI State Machine

Animals cycle through states based on behavior type and player proximity:

1. **IDLE**: Standing still, occasionally switching to wander
2. **WANDER**: Moving randomly within area
3. **FLEE**: Running away from player (passive/neutral when scared)
4. **CHASE**: Pursuing player (aggressive/neutral when provoked)
5. **ATTACK**: In melee range, dealing damage

## Loot System

### Drop Chance Calculation
When an animal dies:
1. Each item in `loot_drops` rolls independently
2. Random value 0.0-1.0 compared to `drop_chance`
3. If roll ≤ drop_chance, item drops
4. Quantity is random between `min_amount` and `max_amount`

### Example Loot Table
```
Bear drops:
- raw_meat (min: 3, max: 6, chance: 0.95) → Almost always, large quantity
- leather (min: 2, max: 4, chance: 0.8) → Usually drops
- bone (min: 1, max: 3, chance: 0.5) → 50% chance
```

## Balancing Guidelines

### Health Values
- **Small/Passive**: 20-50 HP (Rabbit, Fox)
- **Medium/Neutral**: 60-100 HP (Boar, Deer)
- **Large/Aggressive**: 100-250 HP (Wolf, Bear)

### Speed Values
- **Slow**: 3-4 m/s (Bear, Heavy creatures)
- **Medium**: 5-7 m/s (Most animals)
- **Fast**: 8-12 m/s (Predators, Small prey)

### Damage Values
- **Weak**: 5-10 damage (Small animals)
- **Medium**: 15-25 damage (Medium predators)
- **Strong**: 30-50 damage (Large predators)

### Range Values
- **Aggro Range**: 8-15 units (sight distance)
- **Flee Range**: Usually 1.5x aggro range
- **Attack Range**: 1.5-3.0 units (melee reach)

## Troubleshooting

### Animals fall through ground
- Check collision layers (animal layer 16, world layer 1)
- Ensure ground has StaticBody3D with collision

### Animals don't spawn
- Check console for errors about missing scenes/resources
- Verify spawner position is above ground
- Ensure spawn_radius > min_spawn_distance

### Animals don't move toward player
- Player must be in "player" group
- Check aggro_range is appropriate for behavior type
- Verify collision masks allow detection

### Animals don't attack
- Check attack_range vs actual distance
- Ensure player has `take_damage(amount)` method
- Verify AttackArea collision mask includes player layer

### Loot doesn't drop
- Verify item_id matches items in your game data
- Check that item_pickup_3d.tscn exists
- Ensure drop_chance is > 0.0

### Too many/few animals spawning
- Adjust max_entities for population cap
- Modify spawn_frequency_min/max for rate
- Increase spawn_radius for spread

## Advanced Customization

### Custom AI Behaviors
Edit `Animal.gd` to add new states:
1. Add new state to `AIState` enum
2. Create `_state_your_state(delta)` function
3. Add transition logic in `_update_ai()`

### Custom Attack Patterns
Override `_perform_attack()` in animal scene script:
```gdscript
func _perform_attack() -> void:
    super._perform_attack()  # Call base attack
    # Add custom effects: AOE, projectiles, buffs, etc.
```

### Group Behaviors
Use signals to coordinate animals:
```gdscript
# In Animal.gd
signal attacked(attacker)

# Connect other animals to respond
animal.attacked.connect(_on_pack_member_attacked)
```

## Performance Considerations

### Spawner Limits
- Keep max_entities reasonable (5-15 per spawner)
- Use fewer spawners with larger radius vs many small ones
- Disable debug_draw in production builds

### LOD for Animals
For distant animals, consider:
- Reducing AI update frequency
- Simplifying collision shapes
- Using lower poly models

### Culling
Animals far from player could be:
- Frozen in place
- Despawned and respawned later
- Updated less frequently

## File Reference

### Required Files
- `scripts/entities/Animal.gd` - Base animal logic
- `scripts/entities/AnimalTemplate.gd` - Template resource
- `scripts/entities/AnimalDrop.gd` - Loot drop resource
- `scripts/world/EntitySpawner.gd` - Spawning system

### Example Resources
- `resources/animals/rabbit_template.tres`
- `resources/animals/deer_template.tres`
- `resources/animals/boar_template.tres`
- `resources/animals/wolf_template.tres`
- `resources/animals/bear_template.tres`

### Example Scenes
- `scenes/entities/Rabbit.tscn`
- `scenes/entities/Deer.tscn`
- `scenes/entities/Boar.tscn`
- `scenes/entities/Wolf.tscn`
- `scenes/entities/Bear.tscn`

## Quick Start Checklist

Creating a new animal:
- [ ] Create or duplicate animal scene with CharacterBody3D
- [ ] Add Animal.gd script, set collision layers
- [ ] Add CollisionShape3D with appropriate size
- [ ] Add MeshInstance3D with visual representation
- [ ] Create AnimalDrop resources for loot (1-3 types)
- [ ] Create AnimalTemplate resource with all stats
- [ ] Test animal by placing in scene directly
- [ ] Add animal template to spawner's spawn_templates array
- [ ] Configure spawner frequency and radius
- [ ] Position spawner in world
- [ ] Test spawning and behavior in game

---

**Last Updated**: 2025-10-01
**System Version**: 0.1.0
