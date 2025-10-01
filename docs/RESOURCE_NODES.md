# Resource Node System Documentation

## Table of Contents
1. [Player Guide](#player-guide) - **Start here for gameplay mechanics**
2. [Quick Setup Guide](#quick-setup-guide) - **Adding nodes to your scene**
3. [Creating New Resource Types](#creating-new-resource-types)
4. [System Overview](#system-overview)
5. [API Reference](#api-reference)
6. [Advanced Configuration](#advanced-configuration)
7. [Troubleshooting](#troubleshooting)

---

## Player Guide

### What Are Resource Nodes?

Resource nodes are minable objects in the world like rocks, trees, ore deposits, and cacti that give you materials when you mine them. These materials are used for crafting, building, and survival.

### How to Mine Resources

#### Requirements
- **Tool**: Most nodes require a specific tool (pickaxe for rocks, axe for trees)
- **Tool Level**: Higher tier nodes need better tools (e.g., iron ore needs level 2+ pickaxe)
- **Health/Stamina**: Mining takes time and effort

#### Mining Process
1. **Equip the Right Tool**: Press **Tab** → Equip pickaxe or axe to your tool slot
2. **Approach the Node**: Get close to the resource (within interaction range)
3. **Hold Left Click**: Hold down the attack button while looking at the node
4. **Watch Progress**: The node will show mining particles and damage
5. **Collect Drops**: When destroyed, items drop on the ground - walk over them to collect

#### Mining Controls
| Action | Control | Description |
|--------|---------|-------------|
| **Mine** | **Hold Left Mouse** | Continuously hit the resource node |
| **Stop Mining** | **Release Mouse** | Stop mining, progress is saved |
| **Switch Tool** | **Tab → Click Tool** | Change between pickaxe, axe, etc. |
| **Pick Up Items** | **Walk Over Them** | Auto-collect dropped resources |

### Resource Types

#### Stone Resources (Require Pickaxe)
- **Sandstone** - Common desert rock, gives stone and sand
  - Tool: Pickaxe Level 1
  - Health: 80 HP
  - Respawn: 3 minutes

- **Granite** - Hard stone, gives granite chunks
  - Tool: Pickaxe Level 2
  - Health: 120 HP
  - Respawn: 5 minutes

- **Iron Ore** - Metal deposit, gives iron ore
  - Tool: Pickaxe Level 2
  - Health: 150 HP
  - Respawn: 8 minutes

- **Copper Ore** - Metal deposit, gives copper ore
  - Tool: Pickaxe Level 1
  - Health: 100 HP
  - Respawn: 6 minutes

#### Organic Resources (Require Axe)
- **Cactus** - Desert plant, gives cactus flesh and needles
  - Tool: None (can use fists)
  - Health: 30 HP
  - Respawn: 5 minutes

- **Trees** - Wood source, gives wood logs
  - Tool: Axe Level 1
  - Health: 200 HP
  - Respawn: 10 minutes

#### Special Resources
- **Bone Piles** - Animal remains, gives bones
  - Tool: None
  - Health: 20 HP
  - Respawn: Never (one-time pickup)

- **Salt Deposits** - Mineral, gives salt
  - Tool: Pickaxe Level 1
  - Health: 50 HP
  - Respawn: 4 minutes

### Resource Drops

Each node has a **drop table** that determines what items you get:
- **Item ID**: What resource drops (e.g., "STONE", "IRON_ORE")
- **Amount**: How many you get (random between min/max)
- **Drop Chance**: Probability of getting this item (e.g., 80% = usually drops)

**Example**: Iron Ore Node might drop:
- 2-4 Iron Ore (100% chance)
- 0-1 Stone (30% chance)
- 0-1 Rare Crystal (5% chance)

### Mining Tips

**Efficiency:**
- Use the correct tool - wrong tools don't work or deal less damage
- Higher level tools mine faster
- Some nodes require no tool (cactus, bones)

**Resource Management:**
- Nodes respawn after a timer - remember good spots!
- Some nodes never respawn (bone piles) - one-time loot
- Drop rates are random - you might get lucky or unlucky

**Strategy:**
- Mark resource-rich areas on your map (future feature)
- Build near resource clusters for easy farming
- Stockpile rare resources when you find them

---

## Quick Setup Guide

### Adding a Resource Node to Your Scene

This is the fastest way to add an existing resource node (like sandstone) to your game world.

#### Step 1: Open Your Scene
1. Open the scene where you want resources (e.g., `demo_scene.tscn`)
2. Make sure you can see the Scene panel and FileSystem panel

#### Step 2: Drag and Drop the Node
1. In FileSystem, navigate to `res://scenes/world/nodes/`
2. Find the resource you want (e.g., `SandstoneNode.tscn`)
3. **Drag it into your scene hierarchy** or into the 3D viewport
4. The node appears at position (0, 0, 0)

#### Step 3: Position the Node
1. Select the node in the scene tree
2. In the Inspector, set **Transform → Position** to where you want it
   - Example: `(10, 0, 5)` = 10 units East, ground level, 5 units North
3. Or use the 3D gizmo to drag it into place

#### Step 4: Configure Properties (Optional)
In the Inspector under the ResourceNode script, you can adjust:
- **Max Health**: How long it takes to mine (default: 80)
- **Required Tool**: What tool is needed (Pickaxe, Axe, None)
- **Required Tool Level**: Minimum tool tier (1-10)
- **Can Respawn**: Does it come back? (true/false)
- **Respawn Time**: Seconds until it respawns (default: 180 = 3 min)

#### Step 5: Set Up Drops
1. Scroll down to **Resource Drops** in the Inspector
2. Click the **Array size** and increase it (e.g., size = 2 for two drop types)
3. Click each array element to configure:
   - **Item ID**: Type the item ID (e.g., "STONE", "SAND")
   - **Min Amount**: Minimum items dropped (e.g., 1)
   - **Max Amount**: Maximum items dropped (e.g., 3)
   - **Drop Chance**: Probability 0.0-1.0 (e.g., 0.8 = 80% chance)

**Example Drop Table for Sandstone:**
```
Drop Table [2]
├─ [0]
│  ├─ item_id: "STONE"
│  ├─ min_amount: 2
│  ├─ max_amount: 4
│  └─ drop_chance: 1.0 (100%)
└─ [1]
   ├─ item_id: "SAND"
   ├─ min_amount: 1
   ├─ max_amount: 2
   └─ drop_chance: 0.5 (50%)
```

#### Step 6: Test It
1. Press **F5** to run the game
2. Find your resource node
3. Equip a pickaxe (Tab → Ctrl+Click pickaxe from inventory)
4. Hold left-click on the node to mine it
5. Items should drop when it's destroyed

---

## Creating New Resource Types

### Method 1: Duplicate an Existing Node (Easiest)

This is the recommended method for creating variations of existing resources.

#### Step 1: Duplicate the Scene
1. In FileSystem, go to `res://scenes/world/nodes/`
2. Right-click an existing node (e.g., `SandstoneNode.tscn`)
3. Select **Duplicate**
4. Rename it (e.g., `LimestoneNode.tscn`)

#### Step 2: Edit the Visual
1. Double-click your new scene to open it
2. Select **MeshInstance3D** in the scene tree
3. In Inspector → **Mesh → Material**:
   - Change **Albedo Color** to match your resource (e.g., white for limestone)
   - Adjust **Roughness** for appearance
4. Optional: Import a 3D model and replace the mesh

#### Step 3: Configure Properties
Select the root node and adjust in Inspector:
- **Max Health**: How tough it is (e.g., 100)
- **Required Tool**: Pickaxe, Axe, or None
- **Required Tool Level**: 1-10 (higher = rarer resource)
- **Respawn Time**: How fast it comes back (in seconds)

#### Step 4: Set Up Drops
1. Under **Resource Drops**, set **Array Size** to how many drop types
2. For each drop:
   - **Item ID**: The item's code name (must exist in `data/resources.json`)
   - **Min/Max Amount**: Range of items dropped
   - **Drop Chance**: 0.0-1.0 probability

**Example: Limestone Node Drops**
```
Drop Table [3]
├─ Limestone Chunks (guaranteed)
│  ├─ item_id: "LIMESTONE"
│  ├─ min_amount: 2
│  ├─ max_amount: 5
│  └─ drop_chance: 1.0
├─ Stone (common)
│  ├─ item_id: "STONE"
│  ├─ min_amount: 1
│  ├─ max_amount: 2
│  └─ drop_chance: 0.6
└─ Fossil (rare)
   ├─ item_id: "FOSSIL"
   ├─ min_amount: 1
   ├─ max_amount: 1
   └─ drop_chance: 0.05
```

#### Step 5: Save and Test
1. **Ctrl+S** to save the scene
2. Add it to a level scene
3. Test mining it in-game

### Method 2: Create From Scratch (Advanced)

For completely custom resources with unique models.

#### Step 1: Create New Scene
1. **Scene → New Scene**
2. Select **3D Scene** as root type
3. Change root type to **StaticBody3D**
4. Rename root to your resource name (e.g., `CrystalNode`)

#### Step 2: Add Required Components
Add these as children of the root:

**CollisionShape3D:**
1. Add Node → **CollisionShape3D**
2. In Inspector → **Shape** → **New BoxShape3D** (or SphereShape3D, CapsuleShape3D)
3. Adjust **Size** to match your visual mesh
4. Move it up slightly so it sits on the ground (Transform → Position Y = 0.5)

**MeshInstance3D:**
1. Add Node → **MeshInstance3D**
2. In Inspector → **Mesh** → **New BoxMesh** (or import a model)
3. Create a new **Material** and customize colors
4. Position it to match the collision shape

#### Step 3: Attach ResourceNode Script
1. Select the root node
2. In Inspector → **Script** → click the script icon
3. Select **Load** → Navigate to `res://scripts/world/ResourceNode.gd`
4. Click **Open**

#### Step 4: Configure All Properties
Now fill out all the export properties:

**Resource Drops:**
- Add drop table entries as described above

**Mining Requirements:**
- **Required Tool**: "Pickaxe", "Axe", or "None"
- **Required Tool Level**: 1-10

**Health:**
- **Max Health**: 50-200 (how many hits to destroy)
- **Current Health**: Same as max health

**Respawn:**
- **Can Respawn**: true/false
- **Respawn Time**: Seconds (180 = 3 minutes, 0 = never)

**Visuals** (Optional):
- **Mining Particles**: Drag `res://scenes/effects/MiningParticles.tscn`
- **Destruction Particles**: Drag `res://scenes/effects/DestructionParticles.tscn`

#### Step 5: Create Item Data
Your drops must exist in the game's item database:

1. Open `data/resources.json`
2. Add your new resource:

```json
{
  "LIMESTONE": {
    "name": "Limestone",
    "description": "Sedimentary rock used in construction",
    "category": "Resource",
    "stack_size": 50,
    "icon_path": "res://assets/sprites/items/resources/limestone.png"
  }
}
```

#### Step 6: Save and Test
1. **Save the scene** (Ctrl+S) to `res://scenes/world/nodes/YourNode.tscn`
2. Add it to a level
3. Run and test mining

---

## Using Resource Node Spawners

For dynamic world generation, use **ResourceNodeSpawner** to automatically spawn nodes in an area.

### Adding a Spawner to Your Scene

#### Step 1: Add Spawner Node
1. In your scene, add a new node: **Node3D**
2. Rename it to something descriptive (e.g., "SandstoneSpawner")
3. Attach script: `res://scripts/world/ResourceNodeSpawner.gd`

#### Step 2: Position the Spawner
1. Select the spawner in the scene tree
2. Set its **Transform → Position** to the center of your spawn area
   - Example: `(50, 0, 30)` = center of a desert region

#### Step 3: Configure Spawn Area
In Inspector under **Spawn Area**:
- **Spawn Radius**: How far from center nodes can spawn (e.g., 20 meters)
- **Max Nodes**: Maximum number of nodes in this area (e.g., 10)

#### Step 4: Configure Spawn Settings
Under **Spawn Configuration**:
- **Spawn On Ready**: true (spawns when scene loads)
- **Check Ground Collision**: true (raycasts to place on terrain)
- **Ground Check Height**: 100 (how high to raycast from)

#### Step 5: Set Up Spawn Table
This determines which nodes spawn and how common they are:

1. **Spawn Table** → increase **Array Size** (e.g., 3 for three node types)
2. For each entry, click to create a **New NodeSpawnConfig**
3. Configure each NodeSpawnConfig:

**NodeSpawnConfig Properties:**
- **Node Scene**: Drag your resource node scene (e.g., `SandstoneNode.tscn`)
- **Spawn Weight**: Relative probability (1.0 = common, 0.1 = rare)
- **Can Respawn**: true/false (override node's setting)
- **Respawn Time**: Seconds (0 = use node's default)
- **Random Rotation**: true (randomize Y rotation)
- **Scale Variation**: 0.0-0.5 (size randomization, 0.1 = ±10%)

**Example Spawn Table:**
```
Spawn Table [3]
├─ [0] Sandstone (Very Common)
│  ├─ node_scene: SandstoneNode.tscn
│  ├─ spawn_weight: 10.0
│  ├─ random_rotation: true
│  └─ scale_variation: 0.15
├─ [1] Iron Ore (Uncommon)
│  ├─ node_scene: IronNode.tscn
│  ├─ spawn_weight: 2.0
│  ├─ random_rotation: true
│  └─ scale_variation: 0.1
└─ [2] Copper Ore (Rare)
   ├─ node_scene: CopperNode.tscn
   ├─ spawn_weight: 0.5
   ├─ random_rotation: true
   └─ scale_variation: 0.1
```

This creates a spawn area where:
- Sandstone is most common (weight 10)
- Iron ore is less common (weight 2)
- Copper is rare (weight 0.5)
- Total weight = 12.5, sandstone has 10/12.5 = 80% chance per spawn

#### Step 6: Debug Visualization (Optional)
Under **Debug**:
- **Show Spawn Area**: true (shows green circle in editor)
- **Debug Color**: Color(0, 1, 0, 0.3) - green transparent

#### Step 7: Test Spawning
1. Save your scene
2. Run the game (F5)
3. Go to the spawner location
4. You should see nodes randomly distributed in the radius
5. Mine them - they'll respawn based on configuration

---

## System Overview

### Architecture

```
ResourceNode (StaticBody3D)
├── Handles mining damage
├── Manages health and durability
├── Drops resources when destroyed
├── Respawns after timer
└── Signals: node_mined, node_destroyed, health_changed

ResourceNodeSpawner (Node3D)
├── Spawns nodes in radius
├── Manages population
├── Handles respawning
└── Uses weighted spawn table

ResourceDrop (Resource)
└── Configures item drops (ID, amount, chance)

NodeSpawnConfig (Resource)
└── Configures spawning (scene, weight, settings)
```

### Key Features

- **Tool Requirements**: Nodes can require specific tools and levels
- **Health System**: Nodes have HP that depletes when mined
- **Drop Tables**: Random loot with configurable chances and amounts
- **Respawning**: Nodes can respawn after a timer
- **Visual Feedback**: Mining and destruction particle effects
- **Spawner System**: Dynamic node placement in defined areas
- **Weight-based Spawning**: Common/rare resource distribution

---

## API Reference

### ResourceNode Class

```gdscript
extends StaticBody3D
class_name ResourceNode
```

#### Signals

```gdscript
signal node_mined(node: ResourceNode)      # Emitted when fully mined
signal node_destroyed(node: ResourceNode)  # Emitted when destroyed
signal health_changed(current: float, maximum: float)  # HP changes
```

#### Export Properties

**Resource Drops:**
```gdscript
@export var drop_table: Array[ResourceDrop] = []
```

**Mining Requirements:**
```gdscript
@export_enum("None", "Pickaxe", "Axe") var required_tool: String = "Pickaxe"
@export_range(1, 10) var required_tool_level: int = 1
```

**Health:**
```gdscript
@export var max_health: float = 100.0
@export var current_health: float = 100.0
```

**Respawn:**
```gdscript
@export var can_respawn: bool = true
@export var respawn_time: float = 300.0  # 5 minutes
```

**Visuals:**
```gdscript
@export var mining_particles: PackedScene
@export var destruction_particles: PackedScene
```

#### Key Functions

**can_mine(player_tool: String, player_tool_level: int) -> bool**
- Checks if player has correct tool and level
- Returns: true if can mine, false otherwise

**mine(damage: float, player_tool: String, player_tool_level: int) -> bool**
- Apply damage to the node
- Parameters:
  - `damage`: Amount of HP to remove
  - `player_tool`: Tool being used ("Pickaxe", "Axe", "None")
  - `player_tool_level`: Tool's level (1-10)
- Returns: true if mining succeeded, false if wrong tool

**get_mining_progress() -> float**
- Returns: 0.0 (full health) to 1.0 (destroyed)

---

### ResourceDrop Class

```gdscript
extends Resource
class_name ResourceDrop
```

Configuration for items dropped from nodes.

**Properties:**
```gdscript
@export var item_id: String = ""              # Item ID from resources.json
@export var min_amount: int = 1               # Minimum dropped
@export var max_amount: int = 3               # Maximum dropped
@export_range(0.0, 1.0) var drop_chance: float = 1.0  # Probability
```

---

### ResourceNodeSpawner Class

```gdscript
extends Node3D
class_name ResourceNodeSpawner
```

#### Export Properties

**Spawn Area:**
```gdscript
@export var spawn_radius: float = 10.0  # Meters from center
@export var max_nodes: int = 5          # Max simultaneous nodes
```

**Configuration:**
```gdscript
@export var spawn_table: Array[NodeSpawnConfig] = []
@export var spawn_on_ready: bool = true
@export var check_ground_collision: bool = true
@export var ground_check_height: float = 100.0
```

**Debug:**
```gdscript
@export var show_spawn_area: bool = true
@export var debug_color: Color = Color(0, 1, 0, 0.3)
```

#### Functions

**spawn_random_node() -> ResourceNode**
- Spawns a random node based on spawn table weights
- Returns: The spawned node instance

**spawn_node(config: NodeSpawnConfig) -> ResourceNode**
- Spawns a specific configuration
- Returns: The spawned node instance

**clear_all_nodes() -> void**
- Removes all spawned nodes

**respawn_all_nodes() -> void**
- Clears and respawns all nodes

---

### NodeSpawnConfig Class

```gdscript
extends Resource
class_name NodeSpawnConfig
```

Configuration for what and how nodes spawn.

**Properties:**
```gdscript
@export var node_scene: PackedScene      # Scene to spawn
@export var spawn_weight: float = 1.0   # Relative probability
@export var can_respawn: bool = true    # Override node setting
@export var respawn_time: float = 0.0   # 0 = use node default
@export var random_rotation: bool = true
@export_range(0.0, 0.5) var scale_variation: float = 0.1
```

---

## Advanced Configuration

### Creating Resource Drop Tables

Drop tables use probability and random ranges for varied loot:

```gdscript
# Example: Rich ore deposit
Drop Table [4]
├─ Ore (guaranteed) - 100% chance
│  ├─ item_id: "IRON_ORE"
│  ├─ min_amount: 3
│  ├─ max_amount: 6
│  └─ drop_chance: 1.0
├─ Stone (common) - 70% chance
│  ├─ item_id: "STONE"
│  ├─ min_amount: 1
│  ├─ max_amount: 3
│  └─ drop_chance: 0.7
├─ Gems (uncommon) - 15% chance
│  ├─ item_id: "GEMSTONE"
│  ├─ min_amount: 1
│  ├─ max_amount: 1
│  └─ drop_chance: 0.15
└─ Rare Mineral (rare) - 2% chance
   ├─ item_id: "MITHRIL"
   ├─ min_amount: 1
   ├─ max_amount: 1
   └─ drop_chance: 0.02
```

### Balancing Spawn Weights

Spawn weights are relative to each other:

```gdscript
# Desert biome example
Sandstone: 20.0  (60% of spawns)
Copper:     8.0  (24% of spawns)
Iron:       4.0  (12% of spawns)
Rare Gem:   1.0  ( 3% of spawns)
Total:     33.0

Sandstone probability = 20.0 / 33.0 = 60.6%
```

**Guidelines:**
- Common resources: 5.0 - 20.0
- Uncommon resources: 1.0 - 5.0
- Rare resources: 0.1 - 1.0
- Ultra-rare: < 0.1

### Respawn Timing Strategy

**Fast Respawn (30-180 seconds):**
- Common early-game resources (wood, stone)
- High-traffic areas
- Tutorial zones

**Medium Respawn (3-10 minutes):**
- Standard resources (ores, plants)
- Balanced between availability and scarcity
- Most late-game resources

**Slow Respawn (10+ minutes):**
- Rare resources
- Boss/special areas
- Encourages exploration

**No Respawn:**
- One-time pickups (treasure chests, quest items)
- Boss loot
- Story items

---

## Troubleshooting

### Node Doesn't Take Damage When Mined

**Possible Causes:**
1. **Wrong Tool Equipped**
   - Solution: Check node's `required_tool` matches equipped tool
   - Debug: Print player's current tool when mining

2. **Tool Level Too Low**
   - Solution: Upgrade your tool or find easier nodes
   - Check: `required_tool_level` vs your tool's level

3. **Not Interacting Correctly**
   - Solution: Make sure player's mining system calls `node.mine(damage, tool, level)`
   - Check: Player script's mining logic

### No Items Drop When Node is Destroyed

**Possible Causes:**
1. **Drop Table Empty**
   - Solution: Add at least one ResourceDrop to `drop_table` array
   - In Inspector: Resource Drops → Array Size > 0

2. **Invalid Item IDs**
   - Solution: Check item IDs exist in `data/resources.json`
   - Must match exactly (case-sensitive)

3. **Drop Chance Too Low**
   - Solution: Temporarily set `drop_chance = 1.0` to test
   - Check: Are you just unlucky? (50% = half the time nothing drops)

4. **ItemDropManager Missing**
   - Solution: Make sure ItemDropManager is in autoloads
   - Check Project → Project Settings → Autoload

### Node Never Respawns

**Possible Causes:**
1. **Respawn Disabled**
   - Solution: Set `can_respawn = true` in Inspector
   - Check: Node properties

2. **Respawn Time Too Long**
   - Solution: Reduce `respawn_time` for testing (e.g., 10 seconds)
   - Default 300 = 5 minutes

3. **Node Removed Instead of Hidden**
   - Solution: Check ResourceNode script hasn't been modified
   - Should call `hide()` not `queue_free()` when `can_respawn = true`

### Spawner Doesn't Spawn Nodes

**Possible Causes:**
1. **Empty Spawn Table**
   - Solution: Add NodeSpawnConfig entries to `spawn_table`
   - Must have at least one valid config

2. **Invalid Node Scenes**
   - Solution: Make sure `node_scene` paths are correct
   - Drag and drop scenes, don't type paths

3. **Ground Check Failing**
   - Solution: Set `check_ground_collision = false` for testing
   - Or ensure there's terrain/ground below spawn area

4. **Spawn Radius Too Small**
   - Solution: Increase `spawn_radius` (try 20+ meters)
   - Tiny radius might fail to find valid positions

### Spawned Nodes Float or Sink Into Ground

**Possible Causes:**
1. **Ground Check Disabled**
   - Solution: Set `check_ground_collision = true`
   - This raycasts to find proper height

2. **Wrong Collision Layer**
   - Solution: Ensure ground/terrain is on collision layer 1
   - Spawner raycasts layer 1 for ground

3. **CollisionShape Too Low/High**
   - Solution: Adjust CollisionShape3D position in node scene
   - Should be centered vertically on mesh

---

## Integration with Player Mining

Your player needs to send mining commands to nodes. Here's how to connect them:

### Player Mining Script Example

```gdscript
# In player script (e.g., PlayerController.gd)

var mining_target: ResourceNode = null
var current_tool: String = "Pickaxe"
var current_tool_level: int = 1
var mining_damage: float = 10.0

func _physics_process(delta: float):
	# Check for mining input
	if Input.is_action_pressed("mine"):  # Holding left-click
		try_mine_resource(delta)

func try_mine_resource(delta: float):
	# Raycast to find resource node
	var camera = get_viewport().get_camera_3d()
	var from = camera.project_ray_origin(get_viewport().get_mouse_position())
	var to = from + camera.project_ray_normal(get_viewport().get_mouse_position()) * 5.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Resource nodes layer

	var result = space_state.intersect_ray(query)

	if result and result.collider is ResourceNode:
		var node = result.collider as ResourceNode

		# Apply damage over time (10 damage per second)
		var damage_this_frame = mining_damage * delta
		node.mine(damage_this_frame, current_tool, current_tool_level)

func equip_tool(tool_name: String, level: int):
	current_tool = tool_name
	current_tool_level = level
```

---

## Best Practices

### Scene Organization

```
scenes/
└── world/
    └── nodes/              # All resource node scenes
        ├── SandstoneNode.tscn
        ├── IronNode.tscn
        ├── TreeNode.tscn
        └── etc...
```

### Naming Conventions

- **Scenes**: `[Resource]Node.tscn` (e.g., `SandstoneNode.tscn`)
- **Item IDs**: ALL_CAPS_SNAKE_CASE (e.g., `IRON_ORE`)
- **Spawner Nodes**: `[Resource]Spawner` (e.g., `IronOreSpawner`)

### Performance Considerations

**For Large Worlds:**
1. **Use Spawners** instead of placing hundreds of individual nodes
2. **Limit max_nodes** in spawners (5-10 per area)
3. **Use longer respawn times** for distant areas (saves processing)
4. **Disable spawners** in unloaded areas (future feature)

**Particle Effects:**
1. **Keep particles simple** (low particle count)
2. **Use one-shot particles** for destruction (auto-cleanup)
3. **Don't stack effects** (disable mining particles when not mining)

---

## Version Information

- **Last Updated**: 2025-01-20
- **Godot Version**: 4.x
- **System Version**: 1.0

---

## Related Documentation

- [Combat System](COMBAT_SYSTEM.md) - How tools and weapons work
- [Spawning System](SPAWNING_SYSTEM.md) - Animal spawning (similar to resource spawning)
- [Inventory System](INVENTORY_SYSTEM.md) - How dropped items are collected
