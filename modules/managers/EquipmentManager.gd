extends Node

signal equipment_changed(slot: String, equipment: Equipment)
signal stats_updated(total_stats: Dictionary)

var equipment_data: Dictionary = {}
var equipped_items: Dictionary = {}
var total_stats: Dictionary = {}

const EQUIPMENT_SLOTS = [
	"HEAD",
	"CHEST", 
	"PANTS",
	"FEET",
	"TRINKET_1",
	"TRINKET_2",
	"BACKPACK",
	"PRIMARY_WEAPON",
	"SECONDARY_WEAPON",
	"TOOL"
]

func _ready():
	load_equipment_data()
	initialize_equipment_slots()

func load_equipment_data():
	var file = FileAccess.open("res://data/equipment.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("equipment_items"):
				equipment_data = data.equipment_items
				print("Loaded ", equipment_data.size(), " equipment items")
		else:
			push_error("Failed to parse equipment.json: " + json.error_string)
	else:
		push_error("Failed to open equipment.json")

func initialize_equipment_slots():
	for slot in EQUIPMENT_SLOTS:
		equipped_items[slot] = null

func create_equipment(equipment_id: String) -> Equipment:
	if equipment_data.has(equipment_id):
		return Equipment.new(equipment_id, equipment_data[equipment_id])
	push_error("Equipment ID not found: " + equipment_id)
	return null

func equip_item(equipment: Equipment, slot_override: String = "") -> bool:
	if equipment == null:
		return false
	
	var target_slot = slot_override if slot_override != "" else equipment.slot
	
	if not target_slot in EQUIPMENT_SLOTS:
		push_error("Invalid equipment slot: " + target_slot)
		return false
	
	if not equipment.can_equip_to_slot(target_slot):
		push_error("Equipment cannot be equipped to slot: " + target_slot)
		return false
	
	var previous_item = equipped_items[target_slot]
	
	if previous_item:
		unequip_item(target_slot, false)
	
	equipped_items[target_slot] = equipment
	equipment.is_equipped = true
	
	update_total_stats()
	equipment_changed.emit(target_slot, equipment)
	
	return true

func unequip_item(slot: String, update_stats: bool = true) -> Equipment:
	if not slot in EQUIPMENT_SLOTS:
		push_error("Invalid equipment slot: " + slot)
		return null
	
	var equipment = equipped_items[slot]
	if equipment:
		equipment.is_equipped = false
		equipped_items[slot] = null
		
		if update_stats:
			update_total_stats()
		
		equipment_changed.emit(slot, null)
		
		# Add back to inventory system
		if InventorySystem:
			InventorySystem.add_item(equipment.id, 1)
			print("Returned %s to inventory" % equipment.name)
	
	return equipment

func get_equipped_item(slot: String) -> Equipment:
	if equipped_items.has(slot):
		return equipped_items[slot]
	return null

func get_all_equipped_items() -> Array:
	var items = []
	for slot in EQUIPMENT_SLOTS:
		if equipped_items[slot] != null:
			items.append(equipped_items[slot])
	return items

func update_total_stats():
	total_stats.clear()
	
	for slot in equipped_items:
		var equipment = equipped_items[slot]
		if equipment and equipment.stats:
			# Use effective stats that account for durability
			var effective_stats = equipment.get_effective_stats() if equipment.has_method("get_effective_stats") else equipment.stats
			
			for stat_name in effective_stats:
				var value = equipment.get_stat_value(stat_name) if not equipment.has_method("get_effective_stats") else effective_stats[stat_name]
				if total_stats.has(stat_name):
					if stat_name == "radiation_detection":
						total_stats[stat_name] = total_stats[stat_name] or value
					else:
						total_stats[stat_name] += value
				else:
					total_stats[stat_name] = value
	
	stats_updated.emit(total_stats)
	
	if GameManager.player_node:
		apply_stats_to_player()

func apply_stats_to_player():
	var player = GameManager.player_node
	if not player:
		return
	
	if total_stats.has("max_health"):
		player.max_health = player.base_max_health + total_stats.max_health
	
	if total_stats.has("max_stamina"):
		player.max_stamina = player.base_max_stamina + total_stats.max_stamina
	
	if total_stats.has("movement_speed"):
		player.speed_modifier = 1.0 + total_stats.movement_speed
	
	if total_stats.has("defense"):
		player.defense = total_stats.defense
	
	if total_stats.has("inventory_slots"):
		player.bonus_inventory_slots = int(total_stats.inventory_slots)

func get_stat_value(stat_name: String) -> float:
	if total_stats.has(stat_name):
		return total_stats[stat_name]
	return 0.0

func has_stat(stat_name: String) -> bool:
	return total_stats.has(stat_name) and total_stats[stat_name] != 0

func calculate_damage_reduction(base_damage: float) -> float:
	var defense = get_stat_value("defense")
	var reduction = defense * 0.5
	return max(base_damage - reduction, 1.0)

func calculate_radiation_damage(base_radiation: float) -> float:
	var resist = get_stat_value("radiation_resist")
	return base_radiation * (1.0 - resist / 100.0)

func calculate_temperature_damage(base_temp_damage: float) -> float:
	var resist = get_stat_value("temperature_resist")
	return base_temp_damage * (1.0 - resist / 100.0)

func calculate_fall_damage(base_fall_damage: float) -> float:
	var reduction = get_stat_value("fall_damage_reduction")
	return base_fall_damage * (1.0 - reduction)

func get_scavenge_multiplier() -> float:
	var bonus = get_stat_value("scavenge_bonus")
	var luck = get_stat_value("luck")
	return 1.0 + bonus + (luck * 0.5)

func get_crafting_time_modifier() -> float:
	var org_bonus = get_stat_value("organization_bonus")
	return 1.0 - org_bonus

func save_equipment_state() -> Dictionary:
	var save_data = {}
	for slot in equipped_items:
		if equipped_items[slot]:
			save_data[slot] = {
				"id": equipped_items[slot].id,
				"is_equipped": true
			}
	return save_data

func load_equipment_state(save_data: Dictionary):
	initialize_equipment_slots()
	
	for slot in save_data:
		if save_data[slot] and save_data[slot].has("id"):
			var equipment = create_equipment(save_data[slot].id)
			if equipment:
				equip_item(equipment, slot)
