extends Node

signal ammo_created(ammo: Ammo)
signal ammo_equipped(weapon: Weapon, ammo: Ammo)
signal ammo_unequipped(weapon: Weapon, ammo: Ammo)

var ammo_data: Dictionary = {}
var ammo_type_data: Dictionary = {}

func _ready():
	load_ammo_data()

func load_ammo_data():
	var file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("ammo_items"):
				ammo_data = data.ammo_items
				print("Loaded ", ammo_data.size(), " ammo types")
			if data.has("ammo_types"):
				ammo_type_data = data.ammo_types
				print("Loaded ", ammo_type_data.size(), " ammo type categories")
		else:
			push_error("Failed to parse weapons.json for ammo data: " + json.error_string)
	else:
		push_error("Failed to open weapons.json for ammo data")

func create_ammo(ammo_id: String) -> Ammo:
	if ammo_data.has(ammo_id):
		var ammo = Ammo.new(ammo_id, ammo_data[ammo_id])
		ammo_created.emit(ammo)
		return ammo
	push_error("Ammo ID not found: " + ammo_id)
	return null

func get_ammo_by_type(ammo_type: String) -> Array[String]:
	var matching_ammo = []
	for ammo_id in ammo_data:
		var ammo_item = ammo_data[ammo_id]
		if ammo_item.get("type", "") == ammo_type:
			matching_ammo.append(ammo_id)
	return matching_ammo

func get_compatible_ammo_for_weapon(weapon: Weapon) -> Array[String]:
	var compatible_ammo = []
	if not weapon or not weapon.is_ranged():
		return compatible_ammo
	
	for ammo_type in weapon.get_compatible_ammo_types():
		var matching_ammo = get_ammo_by_type(ammo_type)
		compatible_ammo.append_array(matching_ammo)
	
	return compatible_ammo

func equip_ammo_to_weapon(weapon: Weapon, ammo: Ammo) -> bool:
	if not weapon or not ammo:
		return false
	
	if not weapon.can_equip_ammo(ammo):
		print("Cannot equip " + ammo.name + " to " + weapon.name + ": incompatible ammo type")
		return false
	
	# Unequip current ammo if any
	var old_ammo = weapon.unequip_ammo()
	if old_ammo:
		ammo_unequipped.emit(weapon, old_ammo)
	
	# Equip new ammo
	if weapon.equip_ammo(ammo):
		ammo_equipped.emit(weapon, ammo)
		return true
	
	return false

func unequip_ammo_from_weapon(weapon: Weapon) -> Ammo:
	if not weapon:
		return null
	
	var ammo = weapon.unequip_ammo()
	if ammo:
		ammo_unequipped.emit(weapon, ammo)
	
	return ammo

func is_ammo_compatible_with_weapon(ammo_id: String, weapon: Weapon) -> bool:
	var ammo = create_ammo(ammo_id)
	if not ammo or not weapon:
		return false
	
	return weapon.can_equip_ammo(ammo)

func get_ammo_type_info(ammo_type: String) -> Dictionary:
	if ammo_type_data.has(ammo_type):
		return ammo_type_data[ammo_type]
	return {}

func get_all_ammo_types() -> Array[String]:
	return ammo_type_data.keys()

func get_all_ammo_items() -> Array[String]:
	return ammo_data.keys()

func get_ammo_info(ammo_id: String) -> Dictionary:
	if ammo_data.has(ammo_id):
		return ammo_data[ammo_id]
	return {}

func save_ammo_state(weapon: Weapon) -> Dictionary:
	var save_data = {}
	
	if weapon and weapon.equipped_ammo:
		save_data["equipped_ammo_id"] = weapon.equipped_ammo.id
	
	return save_data

func load_ammo_state(weapon: Weapon, save_data: Dictionary):
	if not weapon or not save_data.has("equipped_ammo_id"):
		return
	
	var ammo_id = save_data["equipped_ammo_id"]
	var ammo = create_ammo(ammo_id)
	if ammo:
		equip_ammo_to_weapon(weapon, ammo)
