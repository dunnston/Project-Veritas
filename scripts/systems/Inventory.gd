extends Node

class_name Inventory

signal item_added(item_id: String, amount: int)
signal item_removed(item_id: String, amount: int)
signal inventory_full()

const MAX_SLOTS = 30
const MAX_STACK_SIZE = 99

var items: Dictionary = {}
var equipment_items: Array[Equipment] = []
var equipment: Dictionary = {
	"tool": null,
	"armor": null,
	"backpack": null
}

func _ready() -> void:
	print("Inventory initialized")

func add_item(item, amount: int = 1) -> int:
	if item is Equipment:
		return add_equipment(item)
	elif item is String:
		return add_item_by_id(item, amount)
	return 0

func add_item_by_id(item_id: String, amount: int) -> int:
	if not can_add_item(item_id, amount):
		inventory_full.emit()
		return 0
	
	if item_id in items:
		var current_amount = items[item_id]
		var new_amount = min(current_amount + amount, MAX_STACK_SIZE)
		var added = new_amount - current_amount
		items[item_id] = new_amount
		item_added.emit(item_id, added)
		return added
	else:
		if get_used_slots() >= MAX_SLOTS:
			inventory_full.emit()
			return 0
		
		var added = min(amount, MAX_STACK_SIZE)
		items[item_id] = added
		item_added.emit(item_id, added)
		return added

func remove_item(item_id: String, amount: int) -> bool:
	if not has_item(item_id, amount):
		return false
	
	items[item_id] -= amount
	if items[item_id] <= 0:
		items.erase(item_id)
	
	item_removed.emit(item_id, amount)
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	if item_id not in items:
		return false
	return items[item_id] >= amount

func get_item_count(item_id: String) -> int:
	if item_id in items:
		return items[item_id]
	return 0

func can_add_item(item_id: String, amount: int) -> bool:
	if item_id in items:
		return items[item_id] + amount <= MAX_STACK_SIZE
	else:
		return get_used_slots() < MAX_SLOTS

func get_used_slots() -> int:
	return items.size()

func get_free_slots() -> int:
	return MAX_SLOTS - get_used_slots()

func equip_item(item_id: String, slot: String) -> bool:
	if slot not in equipment:
		return false
	
	if not has_item(item_id):
		return false
	
	if equipment[slot] != null:
		unequip_item(slot)
	
	equipment[slot] = item_id
	remove_item(item_id, 1)
	return true

func unequip_item(slot: String) -> bool:
	if slot not in equipment or equipment[slot] == null:
		return false
	
	var item_id = equipment[slot]
	if add_item(item_id, 1) > 0:
		equipment[slot] = null
		return true
	return false

func get_equipped_item(slot: String) -> String:
	if slot in equipment:
		return equipment[slot] if equipment[slot] else ""
	return ""

func clear_inventory() -> void:
	items.clear()
	for slot in equipment:
		equipment[slot] = null

func get_all_items() -> Dictionary:
	return items.duplicate()

func add_equipment(equipment_item: Equipment) -> int:
	var bonus_slots = 0
	if GameManager.player_node and "bonus_inventory_slots" in GameManager.player_node:
		bonus_slots = GameManager.player_node.bonus_inventory_slots
	if get_used_slots() >= MAX_SLOTS + bonus_slots:
		inventory_full.emit()
		return 0
	
	equipment_items.append(equipment_item)
	item_added.emit(equipment_item.id, 1)
	return 1

func remove_equipment(equipment_item: Equipment) -> bool:
	var index = equipment_items.find(equipment_item)
	if index >= 0:
		equipment_items.remove_at(index)
		item_removed.emit(equipment_item.id, 1)
		return true
	return false

func get_all_equipment() -> Array[Equipment]:
	return equipment_items.duplicate()

func has_equipment(equipment_id: String) -> bool:
	for eq in equipment_items:
		if eq.id == equipment_id and not eq.is_equipped:
			return true
	return false

func get_equipment_by_id(equipment_id: String) -> Equipment:
	for eq in equipment_items:
		if eq.id == equipment_id and not eq.is_equipped:
			return eq
	return null

func get_equipment_for_slot(slot: String) -> Array[Equipment]:
	var suitable_equipment: Array[Equipment] = []
	for eq in equipment_items:
		if not eq.is_equipped and eq.can_equip_to_slot(slot):
			suitable_equipment.append(eq)
	return suitable_equipment

func get_save_data() -> Dictionary:
	var equipment_save_data = []
	for eq in equipment_items:
		equipment_save_data.append({
			"id": eq.id,
			"is_equipped": eq.is_equipped
		})
	
	return {
		"items": items.duplicate(),
		"equipment": equipment.duplicate(),
		"equipment_items": equipment_save_data
	}

func load_save_data(data: Dictionary) -> void:
	if "items" in data:
		items = data["items"].duplicate()
	if "equipment" in data:
		equipment = data["equipment"].duplicate()
	if "equipment_items" in data:
		equipment_items.clear()
		for eq_data in data["equipment_items"]:
			var eq = EquipmentManager.create_equipment(eq_data.id)
			if eq:
				eq.is_equipped = eq_data.get("is_equipped", false)
				equipment_items.append(eq)
