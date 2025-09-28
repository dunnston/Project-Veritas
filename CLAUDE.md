# Neon Wasteland 3D: Development Guide

## Project Overview
This is a 3D conversion of the 2D Neon Wasteland survival-automation game. The project is designed to receive modular systems from the 2D version one at a time while maintaining compatibility.

## Important Development Notes
- Don't try to start the server with npm start - it's usually running in another terminal
- Jest is available for testing - use it for writing proper unit tests
- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files to creating new ones
- NEVER proactively create documentation files unless explicitly requested

## Migration Status Tracker
### ✅ Completed Modules
- [List will be updated as modules are migrated]

### 🔄 In Progress
- [Current module being migrated]

### 📋 Pending Modules
- GameManager
- CraftingManager
- BuildingManager
- SaveManager
- EventBus
- TimeManager
- InventorySystem
- BuildingSystem
- ItemDropManager
- PowerSystem
- OxygenSystem
- EquipmentManager
- WeaponManager
- AmmoManager
- AttributeManager
- SkillSystem
- StatusEffectSystem
- StormSystem
- ShelterSystem
- InteriorDetectionSystem
- RoofVisibilityManager
- CombatSystem
- ProjectileSystem
- LootSystem
- SpawnerManager

## Project Structure
```
neon-wasteland-3d/
├── project.godot
├── CLAUDE.md
├── GDD.md
├── modules/              # Migrated 2D systems
│   ├── managers/        # Singleton managers
│   └── systems/         # Game systems
├── scenes/
│   ├── player/          # 3D player controller
│   ├── world/           # 3D environments
│   ├── buildings/       # 3D building prefabs
│   ├── items/           # 3D item models
│   ├── ui/              # UI (can reuse 2D)
│   └── effects/         # 3D particles/shaders
├── scripts/
│   ├── player/          # 3D-specific player scripts
│   ├── world/           # World generation
│   ├── camera/          # Camera controllers
│   └── adapters/        # 2D-to-3D adapters
├── assets/
│   ├── models/          # 3D models (.glb)
│   ├── textures/        # PBR textures
│   ├── materials/       # Godot materials
│   └── sounds/          # Reused from 2D
├── data/                # JSON (reused from 2D)
└── resources/           # Godot resources
```

## Development Workflow

### Module Migration Process
1. **Analyze Dependencies**
   - Review the 2D module's dependencies
   - Check which other systems it requires
   - Plan the migration order

2. **Create Adapter Layer**
```gdscript
# scripts/adapters/BuildingAdapter3D.gd
extends Node

# Converts 2D grid coordinates to 3D world space
func grid_to_world_3d(grid_pos: Vector2i) -> Vector3:
    return Vector3(grid_pos.x, 0, grid_pos.y)
```

3. **Test in Isolation**
   - Create a test scene for the module
   - Verify core functionality works in 3D
   - Document any breaking changes

4. **Update Module Status**
   - Mark module as completed in CLAUDE.md
   - Update any dependent modules list
   - Commit with message: "Migrate [ModuleName] to 3D"

### Git Workflow
```bash
# Create feature branch for each module
git checkout -b migrate/module-name

# Stage and commit
git add modules/managers/ModuleName.gd
git commit -m "Migrate ModuleName to 3D with adapter layer"

# Merge to main after testing
git checkout main
git merge migrate/module-name
```

## Naming Conventions
- **3D Scripts:** Append "3D" to distinguish (Player3D.gd)
- **Adapters:** Use "Adapter3D" suffix (InventoryAdapter3D.gd)
- **Scenes:** Keep original names, organize by folders
- **Nodes:** Follow Godot 3D conventions (Node3D, RigidBody3D)

## Technical Guidelines

### Coordinate System
- **2D to 3D Mapping:**
  - X (2D) → X (3D)
  - Y (2D) → Z (3D)
  - Height → Y (3D)

### Physics Layers (3D)
1. World (terrain, walls)
2. Player
3. Buildings
4. Resources
5. Enemies
6. Projectiles
7. Items
8. Interactables
9. Triggers
10. UI Picking

### Performance Considerations
- Use LOD (Level of Detail) for distant objects
- Implement occlusion culling for underground areas
- Pool frequently spawned objects (projectiles, items)
- Limit shadow-casting lights

## Module Integration Patterns

### Singleton Access
```gdscript
# Modules can be accessed globally after autoload
var resources = GameManager.get_player_resources()
```

### Event Communication
```gdscript
# Use existing EventBus for decoupled communication
EventBus.connect("resource_collected", _on_resource_collected)
EventBus.emit_signal("building_placed", building_type, position)
```

### Data Compatibility
```gdscript
# Reuse existing JSON loaders with 3D adaptations
var recipe_data = CraftingManager.load_recipes("res://data/recipes.json")
```

## Testing Checklist
- [ ] Module loads without errors
- [ ] Core functionality works in 3D context
- [ ] Events properly connected via EventBus
- [ ] Save/load compatibility maintained
- [ ] Performance acceptable (60+ FPS)
- [ ] No memory leaks in scene transitions

## Common Migration Issues

### Issue: 2D Positions
**Solution:** Use adapter functions to convert Vector2 to Vector3

### Issue: Sprite to Model
**Solution:** Create model loader that maps sprite IDs to 3D models

### Issue: UI Scaling
**Solution:** Use viewport-based UI that works in both 2D/3D

### Issue: Collision Detection
**Solution:** Replace Area2D with Area3D, adjust collision shapes

## Development Commands

### Quick Test Scene
```gdscript
# Create a test harness for modules
extends Node3D

func _ready():
    # Initialize only required managers
    GameManager.initialize_3d_mode()
    EventBus.connect("test_signal", _on_test)
```

### Debug Helpers
- `F3`: Toggle debug overlay
- `F4`: Show collision shapes
- `F5`: Performance monitor
- `F6`: Network profiler

## Input Mapping
### Player Controls
- **W/A/S/D** - Movement
- **Mouse** - Camera rotation
- **Space** - Jump
- **Shift** - Sprint
- **Ctrl** - Crouch
- **E** - Interact
- **Tab** - Inventory
- **B** - Building mode
- **Escape** - Menu

### Building Controls
- **Q/E** - Rotate building
- **R** - Change building variant
- **Mouse Wheel** - Adjust height
- **Left Click** - Place
- **Right Click** - Cancel

## Camera System
### Third-Person Camera
```gdscript
# Basic orbital camera setup
extends Node3D

@export var follow_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var zoom_speed: float = 10.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 20.0
```

### First-Person Camera
```gdscript
# FPS camera for detailed work
extends Camera3D

@export var mouse_sensitivity: float = 0.002
@export var fov_default: float = 75.0
@export var fov_zoom: float = 50.0
```

## Resource Management
### Model Loading
```gdscript
# Centralized model loading
class_name ModelLoader
extends Resource

static func load_model(model_id: String) -> Node3D:
    var path = "res://assets/models/" + model_id + ".glb"
    return load(path).instantiate()
```

### Material System
```gdscript
# Dynamic material application
func apply_neon_material(mesh_instance: MeshInstance3D, color: Color):
    var material = preload("res://assets/materials/neon_base.tres").duplicate()
    material.emission = color
    mesh_instance.material_override = material
```

## Module-Specific Notes

### GameManager
- Needs scene management for 3D levels
- Camera state persistence
- 3D-specific settings (LOD, shadows, etc.)

### BuildingSystem
- Grid visualization in 3D space
- Multi-level support
- Preview with transparency

### CombatSystem
- Projectile physics in 3D
- Hit detection with raycasts
- Damage numbers as 3D labels

### InventorySystem
- UI remains 2D overlay
- 3D item preview in UI
- Drag-drop with raycast placement

### PowerSystem
- 3D cable rendering between nodes
- Visual electricity effects
- Range visualization spheres

### OxygenSystem
- Volumetric fog for low oxygen
- 3D particle effects for leaks
- Bubble visualization for safe zones

### StormSystem
- 3D weather particles
- Wind force on physics objects
- Lightning with 3D light flashes

### SaveManager
- Additional 3D position data
- Camera state serialization
- LOD settings persistence

## Performance Profiling
### Key Metrics
- Draw calls: < 2000
- Vertices: < 1M
- Physics bodies: < 500
- Lights: < 8 shadow-casting

### Optimization Strategies
1. **Batching:** Combine static meshes
2. **Culling:** Frustum and occlusion
3. **LOD:** 3 levels per model
4. **Pooling:** Reuse frequent objects

## Debug Console Commands
```gdscript
# Add to GameManager for testing
func _on_console_command(cmd: String, args: Array):
    match cmd:
        "teleport":
            player.position = Vector3(args[0], args[1], args[2])
        "spawn":
            spawn_entity(args[0], player.position + Vector3.FORWARD * 2)
        "give":
            inventory.add_item(args[0], int(args[1]))
        "time":
            TimeManager.set_time_of_day(float(args[0]))
        "weather":
            StormSystem.trigger_storm(args[0])
```

## Known Issues & Workarounds
### Issue: Shadow Acne
**Fix:** Adjust shadow bias in project settings

### Issue: Z-Fighting
**Fix:** Use depth offset for overlapping surfaces

### Issue: Physics Jitter
**Fix:** Increase physics tick rate, use interpolation

## Version History
- **v0.1.0** - Initial 3D project setup
- **v0.0.1** - Project structure created

---

**Last Updated:** 2025-09-27
**3D Project Version:** 0.1.0
**Based on 2D Version:** 0.1.0 (MVP Foundation)