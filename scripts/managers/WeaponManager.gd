extends Node

signal weapon_equipped(weapon: Weapon, slot: String)
signal weapon_unequipped(slot: String)
signal weapon_fired(weapon: Weapon, target: Vector3)
signal weapon_reloaded(weapon: Weapon)
signal weapon_switched(active_weapon: Weapon)
signal ammo_consumed(ammo_type: String, amount: int)

var weapon_data: Dictionary = {}
var primary_weapon: Weapon = null
var secondary_weapon: Weapon = null
var active_weapon_slot: String = "PRIMARY_WEAPON"

func _ready():
	load_weapon_data()

func load_weapon_data():
	var file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("weapons"):
				weapon_data = data.weapons
				print("Loaded ", weapon_data.size(), " weapons")
		else:
			push_error("Failed to parse weapons.json: " + json.error_string)
	else:
		push_error("Failed to open weapons.json")

func create_weapon(weapon_id: String) -> Weapon:
	if weapon_data.has(weapon_id):
		return Weapon.new(weapon_id, weapon_data[weapon_id])
	push_error("Weapon ID not found: " + weapon_id)
	return null

func equip_weapon(weapon: Weapon, slot: String = "") -> bool:
	if weapon == null:
		return false
	
	var target_slot = slot if slot != "" else active_weapon_slot
	
	if target_slot != "PRIMARY_WEAPON" and target_slot != "SECONDARY_WEAPON":
		push_error("Invalid weapon slot: " + target_slot)
		return false
	
	# Unequip current weapon in that slot if any
	if target_slot == "PRIMARY_WEAPON" and primary_weapon:
		unequip_weapon("PRIMARY_WEAPON")
	elif target_slot == "SECONDARY_WEAPON" and secondary_weapon:
		unequip_weapon("SECONDARY_WEAPON")
	
	# Equip new weapon
	if target_slot == "PRIMARY_WEAPON":
		primary_weapon = weapon
	else:
		secondary_weapon = weapon
	
	weapon.is_equipped = true

	# Auto-equip compatible ammo if it's a ranged weapon without ammo
	if weapon.is_ranged() and weapon.equipped_ammo == null:
		auto_equip_ammo_to_weapon(weapon)

	weapon_equipped.emit(weapon, target_slot)
	print("Equipped weapon: ", weapon.name, " to ", target_slot)

	return true

func unequip_weapon(slot: String) -> Weapon:
	var weapon: Weapon = null
	
	if slot == "PRIMARY_WEAPON" and primary_weapon:
		weapon = primary_weapon
		primary_weapon = null
	elif slot == "SECONDARY_WEAPON" and secondary_weapon:
		weapon = secondary_weapon
		secondary_weapon = null
	
	if weapon:
		weapon.is_equipped = false
		weapon_unequipped.emit(slot)
		print("Unequipped weapon: ", weapon.name, " from ", slot)
		
		# Add back to inventory system
		if InventorySystem:
			InventorySystem.add_item(weapon.id, 1)
			print("Returned weapon %s to inventory" % weapon.name)
		
		return weapon
	
	return null

func get_equipped_weapon(slot: String = "") -> Weapon:
	var target_slot = slot if slot != "" else active_weapon_slot
	
	if target_slot == "PRIMARY_WEAPON":
		return primary_weapon
	elif target_slot == "SECONDARY_WEAPON":
		return secondary_weapon
	
	return null

func get_primary_weapon() -> Weapon:
	return primary_weapon

func get_secondary_weapon() -> Weapon:
	return secondary_weapon

func get_active_weapon() -> Weapon:
	return get_equipped_weapon(active_weapon_slot)

func switch_weapon() -> bool:
	var new_slot = "SECONDARY_WEAPON" if active_weapon_slot == "PRIMARY_WEAPON" else "PRIMARY_WEAPON"
	var new_weapon = get_equipped_weapon(new_slot)
	
	if new_weapon:
		active_weapon_slot = new_slot
		weapon_switched.emit(new_weapon)
		print("Switched to ", new_slot, ": ", new_weapon.name)
		return true
	
	print("No weapon equipped in ", new_slot, " slot")
	return false

func switch_to_slot(slot: String) -> bool:
	if slot != "PRIMARY_WEAPON" and slot != "SECONDARY_WEAPON":
		return false
	
	var weapon = get_equipped_weapon(slot)
	if weapon:
		active_weapon_slot = slot
		weapon_switched.emit(weapon)
		print("Switched to ", slot, ": ", weapon.name)
		return true
	
	return false

func can_attack() -> bool:
	var active_weapon = get_active_weapon()
	if not active_weapon:
		return false
	
	return active_weapon.can_attack()

func attack(target_position: Vector3 = Vector3.ZERO) -> bool:
	if not can_attack():
		return false
	
	var weapon = get_active_weapon()
	var success = weapon.use_weapon()
	
	if success:
		weapon_fired.emit(weapon, target_position)
		
		# Calculate damage and effects
		var damage = weapon.get_effective_damage()
		var is_critical = randf() < weapon.get_stat_value("critical_chance")
		
		if is_critical:
			damage = int(damage * 1.5)  # 50% more damage for crits
		
		print("Attack with ", weapon.name, " dealt ", damage, " damage", " (critical)" if is_critical else "")
		
		# Emit ammo consumption for ranged weapons
		if weapon.is_ranged() and weapon.equipped_ammo:
			ammo_consumed.emit(weapon.equipped_ammo.id, 1)
		
		return true
	
	return false

func reload_weapon() -> bool:
	var weapon = get_active_weapon()
	if not weapon or not weapon.is_ranged():
		return false
	
	if not weapon.needs_reload():
		print("Weapon doesn't need reloading")
		return false
	if not weapon.equipped_ammo:
		print("No ammo equipped to weapon for reload")
		return false
	
	var ammo_id = weapon.equipped_ammo.id
	
	# Check if player has ammo
	var available_ammo = get_available_ammo(ammo_id)
	if available_ammo <= 0:
		print("No ", weapon.equipped_ammo.name, " available for reload")
		return false
	
	# Perform reload
	var ammo_used = weapon.reload_weapon(available_ammo)
	
	if ammo_used > 0:
		# Consume ammo from inventory
		consume_ammo(ammo_id, ammo_used)
		weapon_reloaded.emit(weapon)
		print("Reloaded ", weapon.name, " with ", ammo_used, " ", weapon.equipped_ammo.name)
		return true
	
	return false

func get_available_ammo(ammo_id: String) -> int:
	# Check player inventory for ammo
	if GameManager.player_node and GameManager.player_node.inventory:
		return GameManager.player_node.inventory.get_item_count(ammo_id)
	return 0

func consume_ammo(ammo_id: String, amount: int) -> bool:
	# Remove ammo from player inventory
	if GameManager.player_node and GameManager.player_node.inventory:
		return GameManager.player_node.inventory.remove_item(ammo_id, amount)
	return false

func repair_weapon(repair_amount: int, slot: String = "") -> bool:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		return false
	
	weapon.repair_weapon(repair_amount)
	print("Repaired ", weapon.name, " for ", repair_amount, " points")
	return true

func get_weapon_stats(slot: String = "") -> Dictionary:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		return {}
	return {
		"name": weapon.name,
		"type": weapon.type,
		"damage": weapon.get_effective_damage(),
		"attack_speed": weapon.attack_speed,
		"range": weapon.range,
		"durability": weapon.current_durability,
		"max_durability": weapon.durability,
		"durability_percentage": weapon.get_durability_percentage(),
		"current_ammo": weapon.current_ammo,
		"max_ammo": weapon.magazine_size,
		"ammo_percentage": weapon.get_ammo_percentage(),
		"equipped_ammo": weapon.equipped_ammo.name if weapon.equipped_ammo else "None",
		"equipped_ammo_id": weapon.equipped_ammo.id if weapon.equipped_ammo else "",
		"can_attack": weapon.can_attack(),
		"needs_reload": weapon.needs_reload(),
		"is_broken": weapon.is_broken(),
		"condition": weapon.get_weapon_condition_text()
	}

func auto_equip_ammo_to_weapon(weapon: Weapon):
	if not weapon or not weapon.is_ranged():
		return

	# Find compatible ammo in inventory
	var compatible_types = weapon.get_compatible_ammo_types()
	for ammo_type in compatible_types:
		var matching_ammo_id = find_ammo_of_type_in_inventory(ammo_type)
		if matching_ammo_id != "":
			# Create and equip the ammo
			if AmmoManager:
				var ammo = AmmoManager.create_ammo(matching_ammo_id)
				if ammo:
					weapon.equip_ammo(ammo)
					print("Auto-equipped %s to %s" % [ammo.name, weapon.name])
					return

func find_ammo_of_type_in_inventory(ammo_type: String) -> String:
	# Check which ammo items we have that match the type
	var ammo_mapping = {
		"BULLET": ["SCRAP_BULLETS", "FIRE_BULLETS"],
		"ARROW": ["WOOD_ARROWS", "STEEL_ARROWS"],
		"ENERGY": ["ENERGY_CELLS"],
		"PLASMA": ["PLASMA_CHARGES"]
	}

	if ammo_mapping.has(ammo_type):
		for ammo_id in ammo_mapping[ammo_type]:
			if has_ammo_in_inventory(ammo_id):
				return ammo_id

	return ""

func has_ammo_in_inventory(ammo_id: String) -> bool:
	# Check if player has this ammo in inventory
	if InventorySystem:
		return InventorySystem.has_item(ammo_id)
	return false

func get_damage_multiplier() -> float:
	var weapon = get_active_weapon()
	if not weapon:
		return 1.0

	var multiplier = 1.0
	
	# Apply weapon damage
	var base_damage = weapon.get_effective_damage()
	multiplier += base_damage * 0.1  # Each point of weapon damage adds 10% to base damage
	
	return multiplier

func get_attack_speed_multiplier() -> float:
	var weapon = get_active_weapon()
	if not weapon:
		return 1.0
	
	return weapon.attack_speed

func get_attack_range() -> float:
	var weapon = get_active_weapon()
	if not weapon:
		return 1.0
	
	return weapon.range

func has_stat(stat_name: String) -> bool:
	var weapon = get_active_weapon()
	if not weapon:
		return false
	
	return weapon.has_stat(stat_name)

func get_stat_value(stat_name: String) -> float:
	var weapon = get_active_weapon()
	if not weapon:
		return 0.0
	
	return weapon.get_stat_value(stat_name)

func save_weapon_state() -> Dictionary:
	var save_data = {}
	save_data["active_weapon_slot"] = active_weapon_slot
	
	if primary_weapon:
		save_data["primary_weapon"] = {
			"id": primary_weapon.id,
			"current_durability": primary_weapon.current_durability,
			"current_ammo": primary_weapon.current_ammo,
			"is_equipped": true,
			"equipped_ammo_id": primary_weapon.equipped_ammo.id if primary_weapon.equipped_ammo else ""
		}
	
	if secondary_weapon:
		save_data["secondary_weapon"] = {
			"id": secondary_weapon.id,
			"current_durability": secondary_weapon.current_durability,
			"current_ammo": secondary_weapon.current_ammo,
			"is_equipped": true,
			"equipped_ammo_id": secondary_weapon.equipped_ammo.id if secondary_weapon.equipped_ammo else ""
		}
	
	return save_data

func load_weapon_state(save_data: Dictionary):
	active_weapon_slot = save_data.get("active_weapon_slot", "PRIMARY_WEAPON")
	
	if save_data.has("primary_weapon"):
		var primary_data = save_data["primary_weapon"]
		var weapon = create_weapon(primary_data.id)
		
		if weapon:
			weapon.current_durability = primary_data.get("current_durability", weapon.durability)
			weapon.current_ammo = primary_data.get("current_ammo", weapon.magazine_size)
			equip_weapon(weapon, "PRIMARY_WEAPON")
			
			# Load equipped ammo
			var ammo_id = primary_data.get("equipped_ammo_id", "")
			if ammo_id != "" and AmmoManager:
				var ammo = AmmoManager.create_ammo(ammo_id)
				if ammo:
					AmmoManager.equip_ammo_to_weapon(weapon, ammo)
	
	if save_data.has("secondary_weapon"):
		var secondary_data = save_data["secondary_weapon"]
		var weapon = create_weapon(secondary_data.id)
		
		if weapon:
			weapon.current_durability = secondary_data.get("current_durability", weapon.durability)
			weapon.current_ammo = secondary_data.get("current_ammo", weapon.magazine_size)
			equip_weapon(weapon, "SECONDARY_WEAPON")
			
			# Load equipped ammo
			var ammo_id = secondary_data.get("equipped_ammo_id", "")
			if ammo_id != "" and AmmoManager:
				var ammo = AmmoManager.create_ammo(ammo_id)
				if ammo:
					AmmoManager.equip_ammo_to_weapon(weapon, ammo)

func equip_ammo_to_weapon(ammo_id: String, slot: String = "") -> bool:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		print("No weapon equipped in slot: ", slot)
		return false
	
	if not weapon.is_ranged():
		print("Cannot equip ammo to melee weapon")
		return false
	
	var ammo = AmmoManager.create_ammo(ammo_id)
	if not ammo:
		print("Failed to create ammo: ", ammo_id)
		return false
	
	return AmmoManager.equip_ammo_to_weapon(weapon, ammo)

func unequip_ammo_from_weapon(slot: String = "") -> bool:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		return false
	
	var ammo = AmmoManager.unequip_ammo_from_weapon(weapon)
	return ammo != null

func get_compatible_ammo_for_weapon(slot: String = "") -> Array[String]:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		return []
	
	return AmmoManager.get_compatible_ammo_for_weapon(weapon)

func can_weapon_use_ammo(ammo_id: String, slot: String = "") -> bool:
	var weapon = get_equipped_weapon(slot)
	if not weapon:
		return false
	
	return AmmoManager.is_ammo_compatible_with_weapon(ammo_id, weapon)
