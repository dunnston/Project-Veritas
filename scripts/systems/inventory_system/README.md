# Modular Inventory System

A flexible, 2D/3D agnostic inventory management system with item stacking, equipment integration, and configurable JSON data loading.

## Features

- ✅ **2D/3D Agnostic**: Uses Vector3 for drop positions, works in both 2D and 3D
- ✅ **Self-Contained**: No external dependencies except optional EventBus integration
- ✅ **Configurable**: JSON data file paths, icon paths, stack sizes
- ✅ **Item Stacking**: Automatic stack management with configurable limits
- ✅ **Save/Load**: Built-in serialization system
- ✅ **Dynamic Sizing**: Support for bonus inventory slots
- ✅ **Signal-Based**: Clean event system for UI integration
- ✅ **Debug Tools**: Comprehensive logging and statistics

## Quick Setup

### 1. Copy Module
Copy the entire `modules/inventory_system/` folder to your project.

### 2. Add to Autoloads
In your `project.godot`, add to `[autoload]`:
```ini
InventorySystem="*res://modules/inventory_system/InventorySystem.gd"
```

### 3. Configure Data File
Create a JSON file with your item definitions:

```json
{
  "SCRAP_METAL": {
    "name": "Scrap Metal",
    "description": "Rusty metal pieces",
    "icon": "scrap_metal.png",
    "stack_size": 50,
    "category": "Materials",
    "value": 5,
    "weight": 0.5
  },
  "HEALTH_POTION": {
    "name": "Health Potion",
    "description": "Restores health",
    "icon": "health_potion.png",
    "stack_size": 10,
    "category": "Consumables",
    "value": 25,
    "weight": 0.2
  }
}
```

### 4. Create Configuration Resource
In your scene, create an `InventoryConfig` resource:

```gdscript
# In your game initialization
var config = InventoryConfig.new()
config.data_file_path = "res://data/items.json"
config.icon_base_path = "res://assets/sprites/items/"
config.base_slots = 30
config.debug_logging = true
InventorySystem.config = config
```

Or use a preset:
```gdscript
InventorySystem.config = InventoryConfig.create_survival_config()
```

## Usage Examples

### Basic Item Operations
```gdscript
# Add items
InventorySystem.add_item("SCRAP_METAL", 25)
InventorySystem.add_item("HEALTH_POTION", 3)

# Check items
if InventorySystem.has_item("SCRAP_METAL", 10):
    print("Have enough scrap metal!")

# Remove items
InventorySystem.remove_item("HEALTH_POTION", 1)

# Drop items (2D example - convert to Vector2 in your drop handler)
InventorySystem.drop_item("SCRAP_METAL", 5, Vector3(100, 0, 200))
```

### Connect to UI
```gdscript
# In your inventory UI script
func _ready():
    InventorySystem.inventory_changed.connect(_on_inventory_changed)
    InventorySystem.item_added.connect(_on_item_added)
    InventorySystem.item_dropped.connect(_on_item_dropped)

func _on_inventory_changed():
    update_inventory_display()

func _on_item_added(item_id: String, quantity: int):
    show_notification("Added %d %s" % [quantity, InventorySystem.get_item_data(item_id).name])

func _on_item_dropped(item_id: String, quantity: int, position: Vector3):
    # Convert Vector3 to Vector2 for 2D games
    var drop_pos_2d = Vector2(position.x, position.z)
    spawn_dropped_item(item_id, quantity, drop_pos_2d)
```

### Save/Load Integration
```gdscript
# Save inventory data
func save_game():
    var save_data = {
        "inventory": InventorySystem.get_save_data(),
        # ... other save data
    }
    # Save to file...

# Load inventory data
func load_game(save_data: Dictionary):
    if "inventory" in save_data:
        InventorySystem.load_save_data(save_data["inventory"])
```

### Dynamic Inventory Sizing
```gdscript
# Create a bonus slots provider
extends Node

func get_bonus_inventory_slots() -> int:
    # Example: backpack equipment gives bonus slots
    var bonus = 0
    if has_backpack_equipped():
        bonus += 10
    if has_utility_belt():
        bonus += 5
    return bonus

# Configure it
InventorySystem.config.bonus_slots_provider = self

# Update when equipment changes
func _on_equipment_changed():
    InventorySystem.update_inventory_size()
```

## Configuration Options

### InventoryConfig Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `base_slots` | int | 20 | Base number of inventory slots |
| `debug_logging` | bool | false | Enable debug print statements |
| `data_file_path` | String | "" | Path to JSON item data file |
| `icon_base_path` | String | "res://assets/sprites/items/" | Base path for item icons |
| `bonus_slots_provider` | Node | null | Node with `get_bonus_inventory_slots()` method |
| `auto_save_enabled` | bool | true | Enable automatic saving (not implemented yet) |
| `item_categories` | Array[String] | [] | Available item categories |
| `stack_size_overrides` | Dictionary | {} | Override stack sizes for specific items |

### Preset Configurations

```gdscript
# For survival games
InventorySystem.config = InventoryConfig.create_survival_config()

# For RPG games
InventorySystem.config = InventoryConfig.create_rpg_config()

# For automation games
InventorySystem.config = InventoryConfig.create_automation_config()
```

## Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `inventory_changed` | - | Emitted when inventory contents change |
| `item_added` | `item_id: String, quantity: int` | Emitted when items are added |
| `item_removed` | `item_id: String, quantity: int` | Emitted when items are removed |
| `item_dropped` | `item_id: String, quantity: int, drop_position: Vector3` | Emitted when items are dropped |

## API Reference

### Core Methods

#### `add_item(item_id: String, quantity: int) -> bool`
Add items to inventory. Returns true if all items were added.

#### `remove_item(item_id: String, quantity: int) -> bool`
Remove items from inventory. Returns true if all items were removed.

#### `get_item_count(item_id: String) -> int`
Get total quantity of an item in inventory.

#### `has_item(item_id: String, quantity: int = 1) -> bool`
Check if inventory contains enough of an item.

#### `drop_item(item_id: String, quantity: int = 1, drop_position: Vector3 = Vector3.ZERO) -> bool`
Drop items from inventory at specified position.

### Utility Methods

#### `get_empty_slot_count() -> int`
Get number of empty inventory slots.

#### `is_full() -> bool`
Check if inventory is completely full.

#### `clear_inventory()`
Remove all items from inventory.

#### `update_inventory_size()`
Refresh inventory size (call after equipment changes).

#### `get_inventory_stats() -> Dictionary`
Get comprehensive inventory statistics.

### Data Methods

#### `get_item_data(item_id: String) -> Dictionary`
Get item data including name, description, icon, etc.

#### `get_save_data() -> Dictionary`
Get serializable inventory data for saving.

#### `load_save_data(data: Dictionary)`
Load inventory from save data.

## JSON Data Format

Items are defined in JSON with the following structure:

```json
{
  "ITEM_ID": {
    "name": "Display Name",
    "description": "Item description",
    "icon": "filename.png",
    "stack_size": 50,
    "category": "Materials",
    "value": 10,
    "weight": 1.0
  }
}
```

### Required Fields
- `name`: Display name for the item
- `stack_size`: Maximum items per stack

### Optional Fields
- `description`: Item description text
- `icon`: Icon filename (combined with `icon_base_path`)
- `category`: Item category for organization
- `value`: Item monetary value
- `weight`: Item weight for encumbrance systems

## Migration from Original System

If migrating from the original Neon Wasteland InventorySystem:

1. **Copy your existing JSON data** - it should work as-is
2. **Update drop position handling** - convert Vector3 to Vector2 in your drop handlers
3. **Replace direct dependencies** - use signals instead of direct method calls
4. **Configure data paths** - set up InventoryConfig with your file paths

### Breaking Changes
- Drop positions now use Vector3 instead of Vector2
- Configuration is now required (use default config if needed)
- Some internal methods are now private (prefixed with `_`)

## Extending the System

### Custom Item Validation
```gdscript
# Extend InventorySystem to add custom validation
extends "res://modules/inventory_system/InventorySystem.gd"

func add_item(item_id: String, quantity: int) -> bool:
    # Add custom validation
    if not is_item_allowed(item_id):
        return false

    return super.add_item(item_id, quantity)

func is_item_allowed(item_id: String) -> bool:
    # Your custom logic here
    return true
```

### Custom Slot Types
Create specialized inventory types by extending InventorySlot:

```gdscript
class_name EquipmentSlot extends InventorySlot

var slot_type: String = ""
var restrictions: Array[String] = []

func can_add_item(id: String, qty: int) -> bool:
    if not super.can_add_item(id, qty):
        return false

    # Add equipment restrictions
    var item_data = InventorySystem.get_item_data(id)
    return item_data.get("category") in restrictions
```

## Troubleshooting

### Common Issues

**"Data file not found"**
- Check that `config.data_file_path` points to a valid JSON file
- Ensure the file is included in your project export settings

**"Items not stacking properly"**
- Verify JSON `stack_size` values are greater than 1
- Check for stack size overrides in config

**"Signals not firing"**
- Ensure you connect to signals after InventorySystem is ready
- Check that your signal handlers are correctly defined

**"Icons not loading"**
- Verify `config.icon_base_path` is correct
- Check that icon filenames in JSON match actual files
- Ensure icon files are included in export

### Debug Tools

Enable debug logging:
```gdscript
InventorySystem.config.debug_logging = true
```

Print current inventory:
```gdscript
InventorySystem.print_inventory()
```

Get inventory statistics:
```gdscript
var stats = InventorySystem.get_inventory_stats()
print("Total items: ", stats.total_items)
print("Total value: ", stats.total_value)
print("Slot usage: ", stats.slot_usage)
```

## License

This module was extracted from the Neon Wasteland project and is provided as-is for reuse in other projects.