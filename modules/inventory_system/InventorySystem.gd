extends Node

## Modular Inventory System
##
## A flexible, 2D/3D agnostic inventory management system with item stacking,
## equipment integration, and configurable JSON data loading.
##
## Author: Generated from Neon Wasteland project
## Version: 1.0

signal inventory_changed
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal item_dropped(item_id: String, quantity: int, drop_position: Vector3)

# Configuration
@export var config: InventoryConfig

# Core inventory settings
const DEFAULT_BASE_SLOTS: int = 20
const BASE_SLOTS: int = 20  # Alias for UI compatibility

# Inventory data structure
var inventory_slots: Array[InventorySlot] = []

# Internal data cache
var _item_data_cache: Dictionary = {}
var _config_loaded: bool = false

func _ready():
	# Load configuration
	_load_configuration()

	# Initialize empty inventory slots
	var base_slots = config.base_slots if config else DEFAULT_BASE_SLOTS
	for i in base_slots:
		inventory_slots.append(InventorySlot.new())

	# Load item data
	_load_item_data()

	print("InventorySystem: Initialized with %d base slots" % inventory_slots.size())

## Configuration Management
func _load_configuration():
	if not config:
		# Create default configuration if none provided
		config = InventoryConfig.new()
		config.setup_defaults()

	# Bonus slots provider disabled for now - using fixed slot count

	_config_loaded = true

## Data Loading
func _load_item_data():
	if not config or config.data_file_path.is_empty():
		push_warning("InventorySystem: No data file path configured")
		return

	var file_path = config.data_file_path
	if not FileAccess.file_exists(file_path):
		push_error("InventorySystem: Data file not found at: " + file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("InventorySystem: Failed to open data file: " + file_path)
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result == OK:
		_item_data_cache = json.data
		print("InventorySystem: Loaded item data from %s (%d items)" % [file_path, _item_data_cache.size()])
	else:
		push_error("InventorySystem: Failed to parse JSON data file")

func get_item_data(item_id: String) -> Dictionary:
	# Ensure data is loaded
	if _item_data_cache.is_empty() and config:
		_load_item_data()

	# Return item data from cache
	if item_id in _item_data_cache:
		var json_data = _item_data_cache[item_id]
		return {
			"name": json_data.get("name", "Unknown Item"),
			"description": json_data.get("description", "An unknown item."),
			"icon_path": _build_icon_path(json_data.get("icon", "")),
			"max_stack": int(json_data.get("stack_size", 1)),
			"category": json_data.get("category", "Misc").capitalize(),
			"value": json_data.get("value", 0),
			"weight": json_data.get("weight", 0.0)
		}

	# Fallback for unknown items
	return {
		"name": "Unknown Item",
		"description": "An unknown item.",
		"icon_path": "",
		"max_stack": 1,
		"category": "Misc",
		"value": 0,
		"weight": 0.0
	}

func _build_icon_path(icon_filename: String) -> String:
	if icon_filename.is_empty() or not config:
		return ""
	return config.icon_base_path + icon_filename

## Core Inventory Operations
func add_item(item_id: String, quantity: int) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false

	var item_data = get_item_data(item_id)
	var max_stack = item_data.get("max_stack", 1)
	var remaining = quantity

	# Try to add to existing stacks first
	for slot in inventory_slots:
		if slot.item_id == item_id and slot.quantity < slot.max_stack:
			var added = slot.add_items(remaining)
			remaining -= added
			if remaining <= 0:
				break

	# If there are still items remaining, find empty slots
	if remaining > 0:
		for slot in inventory_slots:
			if slot.is_empty():
				slot.item_id = item_id
				slot.max_stack = max_stack
				var added = slot.add_items(remaining)
				remaining -= added
				if remaining <= 0:
					break

	# Emit signals for successful additions
	var actually_added = quantity - remaining
	if actually_added > 0:
		item_added.emit(item_id, actually_added)
		inventory_changed.emit()

		if config and config.debug_logging:
			print("InventorySystem: Added %d %s" % [actually_added, item_data.get("name", item_id)])

		return remaining == 0

	return false

func remove_item(item_id: String, quantity: int) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false

	var remaining = quantity

	# Remove from slots
	for slot in inventory_slots:
		if slot.item_id == item_id and slot.quantity > 0:
			var removed = slot.remove_items(remaining)
			remaining -= removed
			if remaining <= 0:
				break

	var actually_removed = quantity - remaining
	if actually_removed > 0:
		item_removed.emit(item_id, actually_removed)
		inventory_changed.emit()

		if config and config.debug_logging:
			print("InventorySystem: Removed %d %s" % [actually_removed, get_item_data(item_id).get("name", item_id)])

		return remaining == 0

	return false

func get_item_count(item_id: String) -> int:
	var total = 0
	for slot in inventory_slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

## 2D/3D Agnostic Item Dropping
func drop_item(item_id: String, quantity: int = 1, drop_position: Vector3 = Vector3.ZERO) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false

	# Check if we have enough of the item
	if not has_item(item_id, quantity):
		return false

	# Remove the item from inventory
	if remove_item(item_id, quantity):
		item_dropped.emit(item_id, quantity, drop_position)

		if config and config.debug_logging:
			print("InventorySystem: Dropped %d %s" % [quantity, get_item_data(item_id).get("name", item_id)])

		return true

	return false

func drop_item_from_slot(slot_index: int, quantity: int = 1, drop_position: Vector3 = Vector3.ZERO) -> bool:
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return false

	var slot = inventory_slots[slot_index]
	if slot.is_empty():
		return false

	# If quantity not specified or exceeds available, drop all
	var drop_quantity = min(quantity, slot.quantity)

	return drop_item(slot.item_id, drop_quantity, drop_position)

## Utility Functions
func get_empty_slot_count() -> int:
	var count = 0
	for slot in inventory_slots:
		if slot.is_empty():
			count += 1
	return count

func is_full() -> bool:
	return get_empty_slot_count() == 0

func clear_inventory():
	for slot in inventory_slots:
		slot.clear()
	inventory_changed.emit()

## Dynamic Inventory Sizing
func get_max_slots() -> int:
	var base_slots = config.base_slots if config else DEFAULT_BASE_SLOTS
	return base_slots  # Fixed slot count for now

func update_inventory_size():
	var target_size = get_max_slots()
	var current_size = inventory_slots.size()

	if target_size > current_size:
		# Add more slots
		for i in range(current_size, target_size):
			inventory_slots.append(InventorySlot.new())

		if config and config.debug_logging:
			print("InventorySystem: Expanded inventory to %d slots" % target_size)

		inventory_changed.emit()

	elif target_size < current_size:
		# Remove slots (only if they're empty)
		var can_shrink = true
		for i in range(target_size, current_size):
			if not inventory_slots[i].is_empty():
				can_shrink = false
				break

		if can_shrink:
			inventory_slots.resize(target_size)

			if config and config.debug_logging:
				print("InventorySystem: Shrunk inventory to %d slots" % target_size)

			inventory_changed.emit()
		else:
			if config and config.debug_logging:
				print("InventorySystem: Cannot shrink inventory - slots contain items")

# Equipment Integration removed for now - using fixed inventory size

## Save/Load System
func get_save_data() -> Dictionary:
	var save_data = {
		"version": "1.0",
		"base_slots": config.base_slots if config else DEFAULT_BASE_SLOTS,
		"slots": []
	}

	for slot in inventory_slots:
		if slot.is_empty():
			save_data["slots"].append({})
		else:
			save_data["slots"].append({
				"item_id": slot.item_id,
				"quantity": slot.quantity,
				"max_stack": slot.max_stack
			})

	return save_data

func load_save_data(data: Dictionary):
	if not "slots" in data:
		push_warning("InventorySystem: Invalid save data - missing slots")
		return

	var slots_data = data["slots"]

	# Ensure we have enough slots
	while inventory_slots.size() < slots_data.size():
		inventory_slots.append(InventorySlot.new())

	# Load slot data
	for i in range(min(slots_data.size(), inventory_slots.size())):
		var slot_data = slots_data[i]
		if slot_data.is_empty():
			inventory_slots[i].clear()
		else:
			inventory_slots[i].item_id = slot_data.get("item_id", "")
			inventory_slots[i].quantity = slot_data.get("quantity", 0)
			inventory_slots[i].max_stack = slot_data.get("max_stack", 1)

	inventory_changed.emit()

	if config and config.debug_logging:
		print("InventorySystem: Loaded inventory from save data")

## Debug Functions
func print_inventory():
	if not config or not config.debug_logging:
		return

	print("=== INVENTORY SYSTEM ===")
	print("Slots: %d/%d used" % [inventory_slots.size() - get_empty_slot_count(), inventory_slots.size()])

	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		if not slot.is_empty():
			var item_data = get_item_data(slot.item_id)
			print("Slot %d: %s x%d" % [i, item_data.get("name", slot.item_id), slot.quantity])

func get_inventory_stats() -> Dictionary:
	var total_items = 0
	var total_value = 0
	var total_weight = 0.0
	var categories = {}

	for slot in inventory_slots:
		if not slot.is_empty():
			total_items += slot.quantity
			var item_data = get_item_data(slot.item_id)
			total_value += item_data.get("value", 0) * slot.quantity
			total_weight += item_data.get("weight", 0.0) * slot.quantity

			var category = item_data.get("category", "Misc")
			if category in categories:
				categories[category] += slot.quantity
			else:
				categories[category] = slot.quantity

	return {
		"total_items": total_items,
		"total_value": total_value,
		"total_weight": total_weight,
		"categories": categories,
		"slot_usage": "%d/%d" % [inventory_slots.size() - get_empty_slot_count(), inventory_slots.size()]
	}
