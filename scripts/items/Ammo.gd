class_name Ammo
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var type: String = ""  # BULLET, ARROW, ENERGY, PLASMA
@export var icon: Texture2D
@export var damage_modifier: float = 1.0
@export var accuracy_modifier: float = 1.0
@export var stack_size: int = 1
@export var stats: Dictionary = {}

func _init(p_id: String = "", data: Dictionary = {}):
	if p_id != "":
		id = p_id
		if data.has("name"):
			name = data.name
		if data.has("description"):
			description = data.description
		if data.has("type"):
			type = data.type
		if data.has("damage_modifier"):
			damage_modifier = data.damage_modifier
		if data.has("accuracy_modifier"):
			accuracy_modifier = data.accuracy_modifier
		if data.has("stack_size"):
			stack_size = data.stack_size
		if data.has("stats"):
			stats = data.stats.duplicate()
		
		if data.has("icon"):
			var icon_path = "res://assets/sprites/items/ammo/" + data.icon + ".png"
			if ResourceLoader.exists(icon_path):
				icon = load(icon_path)

func get_stat_value(stat_name: String) -> float:
	if stats.has(stat_name):
		var value = stats[stat_name]
		if value is bool:
			return 1.0 if value else 0.0
		return float(value)
	return 0.0

func has_stat(stat_name: String) -> bool:
	return stats.has(stat_name)

func is_compatible_with_weapon(weapon) -> bool:
	if not weapon or not weapon.is_ranged():
		return false
	
	if not weapon.has_method("get_compatible_ammo_types"):
		return false
	
	return type in weapon.get_compatible_ammo_types()

func get_effective_damage_modifier() -> float:
	return damage_modifier

func get_effective_accuracy_modifier() -> float:
	return accuracy_modifier

func can_stack_with(other_ammo) -> bool:
	return other_ammo != null and other_ammo.id == id

func get_formatted_stats() -> String:
	var formatted = ""
	formatted += "Type: " + type + "\n"
	formatted += "Damage Modifier: " + str(damage_modifier * 100) + "%\n"
	formatted += "Accuracy Modifier: " + str(accuracy_modifier * 100) + "%\n"
	formatted += "Stack Size: " + str(stack_size) + "\n"
	
	# Additional stats
	for stat_name in stats:
		var value = stats[stat_name]
		var display_name = stat_name.replace("_", " ").capitalize()
		
		if value is bool:
			if value:
				formatted += display_name + "\n"
		elif value is float or value is int:
			if stat_name.ends_with("_chance") or stat_name.ends_with("_penetration"):
				formatted += display_name + ": " + str(value * 100) + "%\n"
			else:
				formatted += display_name + ": " + str(value) + "\n"
	
	return formatted.strip_edges()

func duplicate_ammo():
	var new_ammo = Ammo.new(id, {
		"name": name,
		"description": description,
		"type": type,
		"damage_modifier": damage_modifier,
		"accuracy_modifier": accuracy_modifier,
		"stack_size": stack_size,
		"stats": stats
	})
	new_ammo.icon = icon
	return new_ammo