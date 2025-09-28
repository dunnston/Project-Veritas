extends Control

class_name AttributesUI

@onready var attributes_panel: Panel = $AttributesPanel
@onready var close_button: Button = $AttributesPanel/CloseButton
@onready var title_label: Label = $AttributesPanel/TitleLabel

# Static instance reference
static var instance: AttributesUI

var is_visible_to_user: bool = false

# Node references for updating values
var value_nodes: Dictionary = {}

func _ready():
	instance = self
	visible = false
	
	# Ensure we can process input even when invisible
	set_process_unhandled_key_input(true)
	
	# Cache references to all value labels for faster updates
	cache_value_nodes()
	
	# Connect to AttributeManager
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		if attr_mgr:
			attr_mgr.attribute_changed.connect(_on_attribute_changed)

func cache_value_nodes():
	# Cache all the value label references for quick updates
	value_nodes["health"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/HealthContainer/HealthValue
	value_nodes["max_health"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/MaxHealthContainer/MaxHealthValue
	value_nodes["energy"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/EnergyContainer/EnergyValue
	value_nodes["max_energy"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/MaxEnergyContainer/MaxEnergyValue
	value_nodes["hunger"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/HungerContainer/HungerValue
	value_nodes["max_hunger"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/MaxHungerContainer/MaxHungerValue
	value_nodes["thirst"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/ThirstContainer/ThirstValue
	value_nodes["max_thirst"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/MaxThirstContainer/MaxThirstValue
	value_nodes["radiation_level"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/RadiationContainer/RadiationValue
	value_nodes["oxygen"] = $AttributesPanel/ScrollContainer/AttributesContainer/SurvivalSection/OxygenContainer/OxygenValue
	
	# Combat attributes
	value_nodes["damage"] = $AttributesPanel/ScrollContainer/AttributesContainer/CombatSection/DamageContainer/DamageValue
	value_nodes["critical_hit_chance"] = $AttributesPanel/ScrollContainer/AttributesContainer/CombatSection/CritChanceContainer/CritChanceValue
	value_nodes["critical_hit_damage"] = $AttributesPanel/ScrollContainer/AttributesContainer/CombatSection/CritDamageContainer/CritDamageValue
	value_nodes["armor_penetration"] = $AttributesPanel/ScrollContainer/AttributesContainer/CombatSection/ArmorPenContainer/ArmorPenValue
	
	# Utility attributes
	value_nodes["speed"] = $AttributesPanel/ScrollContainer/AttributesContainer/UtilitySection/SpeedContainer/SpeedValue
	value_nodes["crafting_speed"] = $AttributesPanel/ScrollContainer/AttributesContainer/UtilitySection/CraftingSpeedContainer/CraftingSpeedValue
	
	# Environmental attributes
	value_nodes["armor"] = $AttributesPanel/ScrollContainer/AttributesContainer/EnvironmentalSection/ArmorContainer/ArmorValue
	value_nodes["fire_resistance"] = $AttributesPanel/ScrollContainer/AttributesContainer/EnvironmentalSection/FireResistanceContainer/FireResistanceValue
	value_nodes["cold_resistance"] = $AttributesPanel/ScrollContainer/AttributesContainer/EnvironmentalSection/ColdResistanceContainer/ColdResistanceValue
	
	# Cached value node references

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_V:
			# Toggle attributes display with V key
			toggle_attributes()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			# Close with Escape key when visible
			toggle_attributes()
			get_viewport().set_input_as_handled()

func toggle_attributes():
	is_visible_to_user = not is_visible_to_user
	visible = is_visible_to_user
	
	print("AttributesUI toggled: ", "visible" if visible else "hidden")
	
	if visible:
		update_all_attributes()

func update_all_attributes():
	print("AttributesUI: update_all_attributes called")
	if not has_node("/root/AttributeManager"):
		print("AttributesUI: No AttributeManager found for update")
		return
	
	var attr_mgr = get_node("/root/AttributeManager")
	if not attr_mgr:
		print("AttributesUI: AttributeManager node is null for update")
		return
	
	# Update all attribute displays
	var all_attributes = attr_mgr.attributes
	print("AttributesUI: Found ", all_attributes.size(), " attributes to display")
	for attr_name in all_attributes:
		update_attribute_display(attr_name, all_attributes[attr_name])

func update_attribute_display(attr_name: String, value: float):
	if value_nodes.has(attr_name):
		var value_label = value_nodes[attr_name]
		if value_label and value_label is Label:
			value_label.text = format_attribute_value(attr_name, value)
			
			# Color coding for certain attributes
			match attr_name:
				"health":
					var max_health = 100.0
					if has_node("/root/AttributeManager"):
						var attr_mgr = get_node("/root/AttributeManager")
						if attr_mgr:
							max_health = attr_mgr.get_attribute("max_health")
					var percentage = value / max_health if max_health > 0 else 0
					if percentage > 0.6:
						value_label.add_theme_color_override("font_color", Color.GREEN)
					elif percentage > 0.3:
						value_label.add_theme_color_override("font_color", Color.YELLOW)
					else:
						value_label.add_theme_color_override("font_color", Color.RED)
				"radiation_level":
					if value > 50:
						value_label.add_theme_color_override("font_color", Color.RED)
					elif value > 20:
						value_label.add_theme_color_override("font_color", Color.YELLOW)
					else:
						value_label.add_theme_color_override("font_color", Color.GREEN)
				_:
					value_label.add_theme_color_override("font_color", Color.WHITE)

func format_attribute_value(attr_name: String, value: float) -> String:
	# Format values based on attribute type
	match attr_name:
		"critical_hit_chance", "fire_resistance", "cold_resistance", "shock_resistance", "storm_resistance":
			return "%.1f%%" % (value * 100)
		"critical_hit_damage":
			return "%.1fx" % value
		"speed", "crafting_speed", "automation_efficiency":
			return "%.1fx" % value
		"health_regeneration_rate", "energy_regeneration_rate", "radiation_decay_rate":
			return "%.1f/sec" % value
		"resource_detection_range":
			return "%.0f px" % value
		_:
			# Default formatting
			if value == int(value):
				return str(int(value))
			else:
				return "%.1f" % value

func _on_attribute_changed(attribute_name: String, new_value: float, _old_value: float):
	update_attribute_display(attribute_name, new_value)

func _on_close_pressed():
	toggle_attributes()

# Debug method to show attribute summary
func show_attribute_summary():
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		if attr_mgr:
			print(attr_mgr.get_attribute_summary())

# Static access method
static func toggle() -> void:
	if instance:
		instance.toggle_attributes()
