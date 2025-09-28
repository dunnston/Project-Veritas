extends Node

signal inventory_changed
signal item_added(item_id: String, quantity: int)
signal item_removed(item_id: String, quantity: int)
signal item_dropped(item_id: String, quantity: int, drop_position: Vector2)

const BASE_SLOTS: int = 20
const WOOD_SCRAP_STACK_SIZE: int = 10

# Inventory data structure
var inventory_slots: Array[InventorySlot] = []

class InventorySlot:
	var item_id: String = ""
	var quantity: int = 0
	var max_stack: int = 1
	
	func _init(id: String = "", qty: int = 0, stack_size: int = 1):
		item_id = id
		quantity = qty
		max_stack = stack_size
	
	func is_empty() -> bool:
		return item_id.is_empty() or quantity <= 0
	
	func can_add_item(id: String, qty: int) -> bool:
		if is_empty():
			return true
		return item_id == id and (quantity + qty) <= max_stack
	
	func add_items(qty: int) -> int:
		var added = min(qty, max_stack - quantity)
		quantity += added
		return added
	
	func remove_items(qty: int) -> int:
		var removed = min(qty, quantity)
		quantity -= removed
		if quantity <= 0:
			clear()
		return removed
	
	func clear():
		item_id = ""
		quantity = 0
		max_stack = 1

func _ready():
	# Initialize empty inventory slots
	for i in BASE_SLOTS:
		inventory_slots.append(InventorySlot.new())
	
	# Load unified resource data
	load_unified_resource_data()

# UNIFIED SYSTEM: Load item data from resources.json (same source as ResourceManager)
var unified_resource_data: Dictionary = {}

func load_unified_resource_data() -> void:
	var file_path = "res://data/resources.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			unified_resource_data = json.data
			print("InventorySystem: Loaded unified resource data from JSON")
		else:
			push_error("InventorySystem: Failed to parse resources.json")

func get_item_data(item_id: String) -> Dictionary:
	# SAFEGUARD: Load data if not already loaded
	if unified_resource_data.is_empty():
		load_unified_resource_data()
	
	# Use unified JSON data
	if item_id in unified_resource_data:
		var json_data = unified_resource_data[item_id]
		return {
			"name": json_data.get("name", "Unknown Item"),
			"description": json_data.get("description", "An unknown item."),
			"icon_path": "res://assets/sprites/items/" + json_data.get("icon", ""),
			"max_stack": int(json_data.get("stack_size", 1)),
			"category": json_data.get("category", "Misc").capitalize()
		}
	
	# Fallback for unknown items
	return {
		"name": "Unknown Item",
		"description": "An unknown item.",
		"icon_path": "",
		"max_stack": 1,
		"category": "Misc"
	}

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
	
	# Check if we successfully added all items
	var actually_added = quantity - remaining
	if actually_added > 0:
		item_added.emit(item_id, actually_added)
		inventory_changed.emit()
		print("Added %d %s to inventory" % [actually_added, item_data.get("name", item_id)])
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

func drop_item(item_id: String, quantity: int = 1, drop_position: Vector2 = Vector2.ZERO) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	
	# Check if we have enough of the item
	if not has_item(item_id, quantity):
		return false
	
	# Remove the item from inventory
	if remove_item(item_id, quantity):
		print("Dropped %d %s" % [quantity, get_item_data(item_id).get("name", item_id)])
		item_dropped.emit(item_id, quantity, drop_position)
		return true
	
	return false

func drop_item_from_slot(slot_index: int, quantity: int = 1, drop_position: Vector2 = Vector2.ZERO) -> bool:
	if slot_index < 0 or slot_index >= inventory_slots.size():
		return false
	
	var slot = inventory_slots[slot_index]
	if slot.is_empty():
		return false
	
	# If quantity not specified or exceeds available, drop all
	var drop_quantity = min(quantity, slot.quantity)
	
	return drop_item(slot.item_id, drop_quantity, drop_position)

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

func get_max_slots() -> int:
	# Get bonus slots from player if available
	var bonus_slots = 0
	if GameManager and GameManager.player_node:
		# Try to access bonus_inventory_slots directly
		if "bonus_inventory_slots" in GameManager.player_node:
			bonus_slots = GameManager.player_node.bonus_inventory_slots
		elif GameManager.player_node.has_method("get"):
			# Try using get() method as fallback
			var result = GameManager.player_node.get("bonus_inventory_slots")
			if result != null:
				bonus_slots = result
	
	return BASE_SLOTS + bonus_slots

func update_inventory_size():
	var target_size = get_max_slots()
	var current_size = inventory_slots.size()
	
	if target_size > current_size:
		# Add more slots
		for i in range(current_size, target_size):
			inventory_slots.append(InventorySlot.new())
		print("InventorySystem: Expanded inventory to %d slots (+%d bonus)" % [target_size, target_size - BASE_SLOTS])
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
			print("InventorySystem: Shrunk inventory to %d slots" % target_size)
			inventory_changed.emit()
		else:
			print("InventorySystem: Cannot shrink inventory - slots contain items")

# Save/Load functionality
func get_save_data() -> Dictionary:
	var save_data = {
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
	if "slots" in data:
		var slots_data = data["slots"]
		for i in range(min(slots_data.size(), inventory_slots.size())):
			var slot_data = slots_data[i]
			if slot_data.is_empty():
				inventory_slots[i].clear()
			else:
				inventory_slots[i].item_id = slot_data.get("item_id", "")
				inventory_slots[i].quantity = slot_data.get("quantity", 0)
				inventory_slots[i].max_stack = slot_data.get("max_stack", 1)
	
	inventory_changed.emit()
	print("InventorySystem: Loaded inventory from save data")

# Debug function
func print_inventory():
	print("=== INVENTORY ===")
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		if not slot.is_empty():
			var item_data = get_item_data(slot.item_id)
			print("Slot %d: %s x%d" % [i, item_data.get("name", slot.item_id), slot.quantity])
