extends Node

# Centralized Attribute Management System for Neon Wasteland
# Handles all player attributes including survival, combat, environmental, and utility stats

signal attribute_changed(attribute_name: String, new_value: float, old_value: float)
# Emitted when attribute categories are recalculated (used by UI systems)
signal attribute_category_updated(category: String, attributes: Dictionary)

# Attribute categories for organization
enum AttributeCategory {
	CORE_SURVIVAL,
	ENVIRONMENTAL_PROTECTION,
	COMBAT_OFFENSIVE,
	COMBAT_SPECIAL_DAMAGE,
	UTILITY,
	SURVIVAL_ENHANCEMENTS,
	SOCIAL
}

# All game attributes centralized here
var attributes: Dictionary = {}

# Base values (without equipment/temporary modifiers)
var base_attributes: Dictionary = {}

# Equipment modifiers (from EquipmentManager)
var equipment_modifiers: Dictionary = {}

# Temporary modifiers (from consumables, effects, etc.)
var temporary_modifiers: Dictionary = {}

func _ready():
	initialize_attributes()
	connect_to_managers()

func initialize_attributes():
	# Core Survival Attributes (Primary Resources)
	base_attributes["health"] = 100.0
	base_attributes["max_health"] = 100.0
	base_attributes["energy"] = 100.0
	base_attributes["max_energy"] = 100.0
	base_attributes["hunger"] = 100.0
	base_attributes["max_hunger"] = 100.0
	base_attributes["thirst"] = 100.0
	base_attributes["max_thirst"] = 100.0
	base_attributes["radiation_level"] = 0.0
	base_attributes["max_radiation"] = 100.0
	base_attributes["oxygen"] = 100.0
	base_attributes["max_oxygen"] = 100.0
	
	# Environmental Protection
	base_attributes["armor"] = 0.0
	base_attributes["fire_resistance"] = 0.0
	base_attributes["cold_resistance"] = 0.0
	base_attributes["shock_resistance"] = 0.0
	
	# Combat Attributes - Offensive
	base_attributes["damage"] = 10.0
	base_attributes["critical_hit_chance"] = 0.05  # 5%
	base_attributes["critical_hit_damage"] = 1.5   # 150% damage
	base_attributes["armor_penetration"] = 0.0
	
	# Special Damage Types
	base_attributes["fire_damage"] = 0.0
	base_attributes["cold_damage"] = 0.0
	base_attributes["shock_damage"] = 0.0
	
	# Utility Attributes
	base_attributes["speed"] = 1.0  # Movement speed multiplier
	
	# Crafting & Automation
	base_attributes["crafting_speed"] = 1.0  # Crafting speed multiplier
	base_attributes["automation_efficiency"] = 1.0  # Automation efficiency multiplier
	base_attributes["resource_detection_range"] = 64.0  # Base detection range in pixels
	
	# Survival Enhancements
	base_attributes["health_regeneration_rate"] = 0.5  # HP per second
	base_attributes["energy_regeneration_rate"] = 2.0  # Energy per second
	base_attributes["radiation_decay_rate"] = 1.0     # Radiation reduced per second
	base_attributes["storm_resistance"] = 0.0         # Storm damage reduction %
	
	# Social Attributes
	base_attributes["stealth"] = 0.0              # Detection avoidance
	base_attributes["information_gathering"] = 0.0  # Intel bonus
	
	# Copy base values to current attributes
	for attribute in base_attributes:
		attributes[attribute] = base_attributes[attribute]

func connect_to_managers():
	# Connect to equipment manager for stat updates
	if EquipmentManager:
		EquipmentManager.stats_updated.connect(_on_equipment_stats_updated)
	
	# Connect to weapon manager for combat stat updates
	if WeaponManager:
		WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)

func _on_equipment_stats_updated(equipment_stats: Dictionary):
	# Update equipment modifiers
	equipment_modifiers.clear()
	for stat_name in equipment_stats:
		equipment_modifiers[stat_name] = equipment_stats[stat_name]
	
	# Recalculate all attributes
	recalculate_attributes()

func _on_weapon_equipped(_weapon: Weapon, _slot: String):
	# Add weapon stats to equipment modifiers
	update_weapon_modifiers()

func _on_weapon_unequipped(_slot: String):
	# Remove weapon stats from equipment modifiers
	update_weapon_modifiers()

func update_weapon_modifiers():
	# Clear existing weapon modifiers
	var keys_to_remove = []
	for key in equipment_modifiers:
		if key.begins_with("weapon_"):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		equipment_modifiers.erase(key)
	
	# Add current weapon stats
	var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
	var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
	
	if primary_weapon:
		add_weapon_stats(primary_weapon, "weapon_primary_")
	
	if secondary_weapon:
		add_weapon_stats(secondary_weapon, "weapon_secondary_")
	
	# Recalculate attributes
	recalculate_attributes()

func add_weapon_stats(weapon: Weapon, prefix: String):
	# Map weapon properties to attributes
	equipment_modifiers[prefix + "damage"] = weapon.damage
	equipment_modifiers[prefix + "attack_speed"] = weapon.attack_speed - 1.0  # Convert to modifier
	equipment_modifiers[prefix + "range"] = weapon.attack_range - 1.0  # Convert to modifier
	
	# Add weapon-specific stats
	var weapon_stats = weapon.get_combined_stats()
	for stat_name in weapon_stats:
		equipment_modifiers[prefix + stat_name] = weapon_stats[stat_name]

func recalculate_attributes():
	var old_attributes = attributes.duplicate()
	
	# Reset to base values
	for attribute in base_attributes:
		attributes[attribute] = base_attributes[attribute]
	
	# Apply equipment modifiers
	for modifier_name in equipment_modifiers:
		var clean_name = modifier_name.replace("weapon_primary_", "").replace("weapon_secondary_", "")
		
		if attributes.has(clean_name):
			# Different combination rules for different attributes
			match clean_name:
				"speed", "crafting_speed", "automation_efficiency":
					# Multipliers - multiply by (1 + modifier)
					attributes[clean_name] *= (1.0 + equipment_modifiers[modifier_name])
				"critical_hit_chance":
					# Percentages - add directly but cap at reasonable values
					attributes[clean_name] = min(attributes[clean_name] + equipment_modifiers[modifier_name], 0.95)
				"critical_hit_damage":
					# Damage multipliers - add to base
					attributes[clean_name] += equipment_modifiers[modifier_name]
				_:
					# Default - additive
					attributes[clean_name] += equipment_modifiers[modifier_name]
	
	# Apply temporary modifiers
	for modifier_name in temporary_modifiers:
		if attributes.has(modifier_name):
			attributes[modifier_name] += temporary_modifiers[modifier_name]
	
	# Ensure values stay within reasonable bounds
	clamp_attributes()
	
	# Emit signals for changed attributes
	for attribute in attributes:
		if old_attributes.has(attribute) and old_attributes[attribute] != attributes[attribute]:
			attribute_changed.emit(attribute, attributes[attribute], old_attributes[attribute])
	
	# Update player stats
	apply_attributes_to_player()

func clamp_attributes():
	# Clamp attributes to reasonable ranges
	attributes["health"] = clamp(attributes["health"], 0, attributes["max_health"])
	attributes["energy"] = clamp(attributes["energy"], 0, attributes["max_energy"])
	attributes["hunger"] = clamp(attributes["hunger"], 0, attributes["max_hunger"])
	attributes["thirst"] = clamp(attributes["thirst"], 0, attributes["max_thirst"])
	attributes["radiation_level"] = clamp(attributes["radiation_level"], 0, attributes["max_radiation"])
	attributes["oxygen"] = clamp(attributes["oxygen"], 0, attributes["max_oxygen"])
	
	# Clamp resistances to 0-100%
	attributes["fire_resistance"] = clamp(attributes["fire_resistance"], 0.0, 1.0)
	attributes["cold_resistance"] = clamp(attributes["cold_resistance"], 0.0, 1.0)
	attributes["shock_resistance"] = clamp(attributes["shock_resistance"], 0.0, 1.0)
	attributes["storm_resistance"] = clamp(attributes["storm_resistance"], 0.0, 1.0)
	
	# Ensure positive values for certain attributes
	attributes["speed"] = max(attributes["speed"], 0.1)
	attributes["crafting_speed"] = max(attributes["crafting_speed"], 0.1)
	attributes["automation_efficiency"] = max(attributes["automation_efficiency"], 0.1)

func apply_attributes_to_player():
	var player = GameManager.player_node
	if not player:
		return
	
	# Update player properties from attributes
	player.max_health = int(attributes["max_health"])
	player.max_energy = int(attributes["max_energy"])
	player.max_hunger = int(attributes["max_hunger"])
	player.max_thirst = int(attributes["max_thirst"])
	
	# Ensure current values don't exceed new maximums
	player.health = min(player.health, player.max_health)
	player.energy = min(player.energy, player.max_energy)
	player.hunger = min(player.hunger, player.max_hunger)
	player.thirst = min(player.thirst, player.max_thirst)
	
	# Apply other modifiers
	player.speed_modifier = attributes["speed"]
	player.defense = attributes["armor"]

# Public interface methods
func get_attribute(attribute_name: String) -> float:
	return attributes.get(attribute_name, 0.0)

func set_base_attribute(attribute_name: String, value: float):
	if base_attributes.has(attribute_name):
		base_attributes[attribute_name] = value
		recalculate_attributes()

func add_temporary_modifier(attribute_name: String, value: float, duration: float = 0.0):
	if not temporary_modifiers.has(attribute_name):
		temporary_modifiers[attribute_name] = 0.0
	
	temporary_modifiers[attribute_name] += value
	recalculate_attributes()
	
	# If duration is specified, remove the modifier after time
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
		remove_temporary_modifier(attribute_name, value)

func remove_temporary_modifier(attribute_name: String, value: float):
	if temporary_modifiers.has(attribute_name):
		temporary_modifiers[attribute_name] -= value
		if abs(temporary_modifiers[attribute_name]) < 0.001:  # Close to zero
			temporary_modifiers.erase(attribute_name)
		recalculate_attributes()

func clear_temporary_modifiers():
	temporary_modifiers.clear()
	recalculate_attributes()

# Combat calculation helpers
func calculate_damage_reduction(incoming_damage: float, damage_type: String = "physical") -> float:
	var base_reduction = 0.0
	
	match damage_type.to_lower():
		"physical":
			base_reduction = attributes["armor"] * 0.5  # Each point of armor = 0.5 damage reduction
		"fire":
			base_reduction = incoming_damage * attributes["fire_resistance"]
		"cold":
			base_reduction = incoming_damage * attributes["cold_resistance"]
		"shock":
			base_reduction = incoming_damage * attributes["shock_resistance"]
	
	return max(incoming_damage - base_reduction, 1.0)  # Minimum 1 damage

func calculate_outgoing_damage() -> Dictionary:
	var damage_info = {
		"physical": attributes["damage"],
		"fire": attributes["fire_damage"],
		"cold": attributes["cold_damage"],
		"shock": attributes["shock_damage"],
		"critical_chance": attributes["critical_hit_chance"],
		"critical_multiplier": attributes["critical_hit_damage"],
		"armor_penetration": attributes["armor_penetration"]
	}
	
	return damage_info

func get_regeneration_rates() -> Dictionary:
	return {
		"health": attributes["health_regeneration_rate"],
		"energy": attributes["energy_regeneration_rate"],
		"radiation_decay": attributes["radiation_decay_rate"]
	}

func get_attributes_by_category(category: AttributeCategory) -> Dictionary:
	var category_attributes = {}
	
	match category:
		AttributeCategory.CORE_SURVIVAL:
			var survival_attrs = ["health", "max_health", "energy", "max_energy", 
								"hunger", "max_hunger", "thirst", "max_thirst", 
								"radiation_level", "max_radiation", "oxygen", "max_oxygen"]
			for attr in survival_attrs:
				category_attributes[attr] = attributes.get(attr, 0.0)
		
		AttributeCategory.ENVIRONMENTAL_PROTECTION:
			var env_attrs = ["armor", "fire_resistance", "cold_resistance", "shock_resistance"]
			for attr in env_attrs:
				category_attributes[attr] = attributes.get(attr, 0.0)
		
		AttributeCategory.COMBAT_OFFENSIVE:
			var combat_attrs = ["damage", "critical_hit_chance", "critical_hit_damage", "armor_penetration"]
			for attr in combat_attrs:
				category_attributes[attr] = attributes.get(attr, 0.0)
		
		# Add other categories as needed...
	
	return category_attributes

# Debug and utility methods
func print_all_attributes():
	print("=== Current Attributes ===")
	for attribute in attributes:
		print("%s: %.2f" % [attribute, attributes[attribute]])

func get_attribute_summary() -> String:
	var summary = "Attribute Summary:\n"
	summary += "Health: %.0f/%.0f\n" % [attributes["health"], attributes["max_health"]]
	summary += "Energy: %.0f/%.0f\n" % [attributes["energy"], attributes["max_energy"]]
	summary += "Damage: %.0f\n" % attributes["damage"]
	summary += "Speed: %.1fx\n" % attributes["speed"]
	summary += "Armor: %.0f\n" % attributes["armor"]
	return summary

# Helper function to emit attribute category updates (suppresses unused signal warning)
func emit_attribute_category_update(category: String, category_attributes: Dictionary) -> void:
	attribute_category_updated.emit(category, category_attributes)
