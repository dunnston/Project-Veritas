class_name Weapon
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var type: String = ""  # MELEE or RANGED
@export var icon: Texture2D
@export var tier: int = 1
@export var damage: int = 0
@export var attack_speed: float = 1.0
@export var attack_range: float = 1.0
@export var durability: int = 100
@export var current_durability: int = 100
@export var stats: Dictionary = {}

# Ranged weapon specific
@export var compatible_ammo_types: Array[String] = []
@export var magazine_size: int = 0
@export var current_ammo: int = 0
@export var reload_time: float = 2.0
var equipped_ammo = null  # Ammo reference
var selected_ammo_id: String = ""  # Which ammo type to use for reloading

@export var is_equipped: bool = false

func _init(p_id: String = "", data: Dictionary = {}):
	if p_id != "":
		id = p_id
		if data.has("name"):
			name = data.name
		if data.has("description"):
			description = data.description
		if data.has("type"):
			type = data.type
		if data.has("tier"):
			tier = data.tier
		if data.has("damage"):
			damage = data.damage
		if data.has("attack_speed"):
			attack_speed = data.attack_speed
		if data.has("range"):
			attack_range = data.range
		if data.has("durability"):
			durability = data.durability
			current_durability = durability
		if data.has("stats"):
			stats = data.stats.duplicate()
		
		# Ranged weapon properties
		if data.has("compatible_ammo_types"):
			# Convert regular array to typed Array[String]
			var ammo_types: Array[String] = []
			for ammo_type in data.compatible_ammo_types:
				ammo_types.append(str(ammo_type))
			compatible_ammo_types = ammo_types
		if data.has("magazine_size"):
			magazine_size = data.magazine_size
			current_ammo = magazine_size  # Start with full magazine
		if data.has("reload_time"):
			reload_time = data.reload_time
			
		if data.has("icon"):
			var icon_path = "res://assets/sprites/items/weapons/" + data.icon + ".png"
			if ResourceLoader.exists(icon_path):
				icon = load(icon_path)

func is_melee() -> bool:
	return type == "MELEE"

func is_ranged() -> bool:
	return type == "RANGED"

func can_attack() -> bool:
	if current_durability <= 0:
		return false

	if is_ranged():
		# Can only attack if we have ammo in magazine
		return current_ammo > 0

	return true

func has_compatible_ammo_in_inventory() -> bool:
	if not InventorySystem:
		return false

	# Check each compatible ammo type
	for ammo_type in compatible_ammo_types:
		var ammo_ids = get_ammo_ids_for_type(ammo_type)
		for ammo_id in ammo_ids:
			if InventorySystem.has_item(ammo_id):
				return true

	return false

func get_ammo_ids_for_type(ammo_type: String) -> Array[String]:
	# Map ammo types to specific ammo IDs
	var ammo_mapping = {
		"BULLET": ["SCRAP_BULLETS", "FIRE_BULLETS"],
		"ARROW": ["WOOD_ARROWS", "STEEL_ARROWS"],
		"ENERGY": ["ENERGY_CELLS"],
		"PLASMA": ["PLASMA_CHARGES"]
	}

	var result: Array[String] = []
	if ammo_mapping.has(ammo_type):
		for ammo_id in ammo_mapping[ammo_type]:
			result.append(ammo_id)

	return result

func get_effective_damage() -> int:
	var base_damage = damage
	
	# Apply durability modifier
	var durability_ratio = float(current_durability) / float(durability)
	base_damage = int(base_damage * durability_ratio)
	
	# Apply ammo damage modifier for ranged weapons
	if is_ranged() and equipped_ammo != null:
		base_damage = int(base_damage * equipped_ammo.get_effective_damage_modifier())
	
	return base_damage

func get_stat_value(stat_name: String) -> float:
	if stats.has(stat_name):
		var value = stats[stat_name]
		if value is bool:
			return 1.0 if value else 0.0
		return float(value)
	return 0.0

func has_stat(stat_name: String) -> bool:
	return stats.has(stat_name)

func use_weapon() -> bool:
	if not can_attack():
		return false

	# Consume ammo for ranged weapons
	if is_ranged():
		current_ammo = max(0, current_ammo - 1)

	# Reduce durability
	current_durability = max(0, current_durability - 1)

	return true

func consume_ammo_from_inventory():
	if not InventorySystem:
		return

	# Find the first available compatible ammo in inventory and consume 1
	for ammo_type in compatible_ammo_types:
		var ammo_ids = get_ammo_ids_for_type(ammo_type)
		for ammo_id in ammo_ids:
			if InventorySystem.has_item(ammo_id):
				InventorySystem.remove_item(ammo_id, 1)
				print("Consumed 1 %s from inventory" % InventorySystem.get_item_data(ammo_id).get("name", ammo_id))
				return

func reload_weapon(ammo_count: int) -> int:
	if not is_ranged():
		return 0

	var ammo_needed = magazine_size - current_ammo
	var ammo_to_load = min(ammo_needed, ammo_count)

	current_ammo += ammo_to_load
	return ammo_to_load  # Return how much ammo was actually used

func reload_from_inventory() -> bool:
	if not is_ranged() or not InventorySystem:
		return false

	if not needs_reload():
		return false

	# Check if we have selected ammo
	if selected_ammo_id.is_empty():
		print("No ammo selected for %s" % name)
		return false

	# Check if we have the selected ammo in inventory
	if not InventorySystem.has_item(selected_ammo_id):
		print("No %s available in inventory" % InventorySystem.get_item_data(selected_ammo_id).get("name", selected_ammo_id))
		return false

	var ammo_needed = magazine_size - current_ammo
	var available_ammo = InventorySystem.get_item_count(selected_ammo_id)
	var ammo_to_use = min(ammo_needed, available_ammo)

	if ammo_to_use > 0:
		# Consume ammo from inventory
		InventorySystem.remove_item(selected_ammo_id, ammo_to_use)
		current_ammo += ammo_to_use
		var ammo_name = InventorySystem.get_item_data(selected_ammo_id).get("name", selected_ammo_id)
		print("Reloaded %s with %d %s" % [name, ammo_to_use, ammo_name])
		return true

	return false

func repair_weapon(repair_amount: int):
	current_durability = min(durability, current_durability + repair_amount)

func get_durability_percentage() -> float:
	if durability <= 0:
		return 0.0
	return float(current_durability) / float(durability)

func get_ammo_percentage() -> float:
	if not is_ranged() or magazine_size <= 0:
		return 1.0
	return float(current_ammo) / float(magazine_size)

func needs_reload() -> bool:
	return is_ranged() and current_ammo < magazine_size

func is_broken() -> bool:
	return current_durability <= 0

func get_formatted_stats() -> String:
	var formatted = ""
	formatted += "Damage: " + str(get_effective_damage()) + "\n"
	formatted += "Attack Speed: " + str(attack_speed) + "/sec\n"
	formatted += "Range: " + str(attack_range) + "m\n"
	formatted += "Durability: " + str(current_durability) + "/" + str(durability) + "\n"
	
	if is_ranged():
		formatted += "Ammo: " + str(current_ammo) + "/" + str(magazine_size) + "\n"
		formatted += "Equipped Ammo: " + (equipped_ammo.name if equipped_ammo else "None") + "\n"
		formatted += "Reload Time: " + str(reload_time) + "s\n"
	
	# Additional stats
	for stat_name in stats:
		var value = stats[stat_name]
		var display_name = stat_name.replace("_", " ").capitalize()
		
		if value is bool:
			if value:
				formatted += display_name + "\n"
		elif value is float or value is int:
			if stat_name.ends_with("_chance") or stat_name.ends_with("_penetration") or stat_name == "accuracy":
				formatted += display_name + ": " + str(value * 100) + "%\n"
			else:
				formatted += display_name + ": " + str(value) + "\n"
	
	return formatted.strip_edges()

func get_weapon_condition_text() -> String:
	var durability_pct = get_durability_percentage()
	if durability_pct > 0.8:
		return "Excellent"
	elif durability_pct > 0.6:
		return "Good"
	elif durability_pct > 0.4:
		return "Fair"
	elif durability_pct > 0.2:
		return "Poor"
	else:
		return "Broken"

func can_equip_to_slot(target_slot: String) -> bool:
	return target_slot == "PRIMARY_WEAPON" or target_slot == "SECONDARY_WEAPON"

func can_equip_ammo(ammo) -> bool:
	if not is_ranged() or ammo == null:
		return false
	
	return ammo.type in compatible_ammo_types

func equip_ammo(ammo) -> bool:
	if not can_equip_ammo(ammo):
		push_error("Cannot equip " + ammo.type + " ammo to weapon that accepts: " + str(compatible_ammo_types))
		return false
	
	equipped_ammo = ammo
	print("Equipped " + ammo.name + " to " + name)
	return true

func unequip_ammo():
	var old_ammo = equipped_ammo
	equipped_ammo = null
	if old_ammo:
		print("Unequipped " + old_ammo.name + " from " + name)
	return old_ammo

func get_equipped_ammo():
	return equipped_ammo

func get_compatible_ammo_types() -> Array[String]:
	return compatible_ammo_types

func get_accuracy_modifier() -> float:
	var base_accuracy = get_stat_value("accuracy")
	
	# Apply ammo accuracy modifier for ranged weapons
	if is_ranged() and equipped_ammo != null:
		base_accuracy *= equipped_ammo.get_effective_accuracy_modifier()
	
	return base_accuracy

func get_combined_stats() -> Dictionary:
	var combined_stats = stats.duplicate()
	
	# Add ammo stats for ranged weapons
	if is_ranged() and equipped_ammo != null:
		for stat_name in equipped_ammo.stats:
			var ammo_value = equipped_ammo.get_stat_value(stat_name)
			if combined_stats.has(stat_name):
				combined_stats[stat_name] += ammo_value
			else:
				combined_stats[stat_name] = ammo_value
	
	return combined_stats

func duplicate_weapon() -> Weapon:
	var new_weapon = Weapon.new(id, {
		"name": name,
		"description": description,
		"type": type,
		"tier": tier,
		"damage": damage,
		"attack_speed": attack_speed,
		"range": attack_range,
		"durability": durability,
		"stats": stats,
		"compatible_ammo_types": compatible_ammo_types,
		"magazine_size": magazine_size,
		"reload_time": reload_time
	})
	new_weapon.icon = icon
	new_weapon.current_durability = current_durability
	new_weapon.current_ammo = current_ammo
	new_weapon.is_equipped = is_equipped
	if equipped_ammo and equipped_ammo.has_method("duplicate_ammo"):
		new_weapon.equipped_ammo = equipped_ammo.duplicate_ammo()
	return new_weapon
