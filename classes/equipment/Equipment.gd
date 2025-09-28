class_name Equipment
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var slot: String = ""
@export var icon: Texture2D
@export var tier: int = 1
@export var durability: int = 100
@export var current_durability: int = 100
@export var stats: Dictionary = {}
@export var is_equipped: bool = false

func _init(p_id: String = "", data: Dictionary = {}):
	if p_id != "":
		id = p_id
		if data.has("name"):
			name = data.name
		if data.has("description"):
			description = data.description
		if data.has("slot"):
			slot = data.slot
		if data.has("tier"):
			tier = data.tier
		if data.has("durability"):
			durability = data.durability
			current_durability = durability
		if data.has("stats"):
			stats = data.stats.duplicate()
		if data.has("icon"):
			var icon_path = "res://assets/sprites/items/equipment/" + data.icon + ".png"
			if ResourceLoader.exists(icon_path):
				icon = load(icon_path)

func get_stat_value(stat_name: String) -> float:
	if stats.has(stat_name):
		var value = stats[stat_name]
		if value is bool:
			return 1.0 if value else 0.0
		return float(value)
	return 0.0

func get_formatted_stats() -> String:
	var formatted = ""
	for stat_name in stats:
		var value = stats[stat_name]
		var display_name = stat_name.replace("_", " ").capitalize()

		if value is bool:
			if value:
				formatted += display_name + "\n"
		elif value is float or value is int:
			var prefix = "+" if value > 0 else ""
			if stat_name.ends_with("_resist") or stat_name.ends_with("_reduction") or stat_name.ends_with("_bonus") or stat_name.ends_with("_efficiency"):
				formatted += display_name + ": " + prefix + str(value) + "%\n"
			elif stat_name == "movement_speed" or stat_name == "stamina_regen" or stat_name == "luck" or stat_name == "organization_bonus":
				formatted += display_name + ": " + prefix + str(value * 100) + "%\n"
			else:
				formatted += display_name + ": " + prefix + str(value) + "\n"

	return formatted.strip_edges()

func can_equip_to_slot(target_slot: String) -> bool:
	if target_slot.begins_with("TRINKET"):
		return slot.begins_with("TRINKET")
	return slot == target_slot

# Durability system methods
func get_durability_percentage() -> float:
	if durability <= 0:
		return 0.0
	return float(current_durability) / float(durability)

func is_broken() -> bool:
	return current_durability <= 0

func can_provide_stats() -> bool:
	return current_durability > 0

func get_effective_stats() -> Dictionary:
	if is_broken():
		return {}  # No stat bonuses when broken

	# Apply durability modifier to stats (optional - equipment could work at reduced efficiency)
	var effective_stats = stats.duplicate()
	var durability_ratio = get_durability_percentage()

	# Only reduce positive stats, keep negative ones (penalties) unchanged
	for stat_name in effective_stats:
		var value = effective_stats[stat_name]
		if value is float or value is int:
			if value > 0:
				effective_stats[stat_name] = value * durability_ratio

	return effective_stats

func reduce_durability(amount: int = 1):
	current_durability = max(0, current_durability - amount)

func repair_equipment(repair_amount: int):
	current_durability = min(durability, current_durability + repair_amount)

func get_equipment_condition_text() -> String:
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

func duplicate_equipment() -> Equipment:
	var new_equipment = Equipment.new(id, {
		"name": name,
		"description": description,
		"slot": slot,
		"tier": tier,
		"durability": durability,
		"stats": stats,
		"icon": icon.resource_path if icon else ""
	})
	new_equipment.icon = icon
	new_equipment.current_durability = current_durability
	new_equipment.is_equipped = is_equipped
	return new_equipment