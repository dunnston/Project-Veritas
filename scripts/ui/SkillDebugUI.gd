extends Control

class_name SkillDebugUI

@onready var skills_container: VBoxContainer = $MainPanel/VBoxContainer/HBoxContainer/LeftPanel/SkillsList/SkillsContainer
@onready var history_container: VBoxContainer = $MainPanel/VBoxContainer/HBoxContainer/MiddlePanel/HistoryList/HistoryContainer
@onready var test_buttons_container: VBoxContainer = $MainPanel/VBoxContainer/HBoxContainer/RightPanel/TestButtons/TestButtonsContainer

var skill_labels: Dictionary = {}
var is_visible_debug: bool = false

func _ready() -> void:
	# SkillDebugUI initializing
	visible = false

	# Add to groups so PlayerCombat can detect this UI
	add_to_group("skill_debug_ui")
	add_to_group("debug_ui")

	setup_skill_display()
	setup_test_buttons()
	_init_storm_testing()
	_init_stealth_testing()
	setup_rapid_controls()

	# Connect to skill system signals
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.skill_xp_gained.connect(_on_xp_gained)
		skill_system.skill_level_up.connect(_on_level_up)

	refresh_display()
	# SkillDebugUI initialization complete

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Z:
			toggle_debug_panel()

func toggle_debug_panel() -> void:
	print("[DEBUG] toggle_debug_panel() called")
	print("[DEBUG] Current is_visible_debug: ", is_visible_debug)
	print("[DEBUG] Current visible: ", visible)
	
	is_visible_debug = !is_visible_debug
	visible = is_visible_debug
	
	print("[DEBUG] New is_visible_debug: ", is_visible_debug)
	print("[DEBUG] New visible: ", visible)
	print("[DEBUG] Node name: ", name)
	print("[DEBUG] Node position: ", position)
	print("[DEBUG] Node size: ", size)
	var parent_name = "NO PARENT" if not get_parent() else str(get_parent().name)
	print("[DEBUG] Parent: ", parent_name)
	print("[DEBUG] Skill Debug Panel toggled: ", "VISIBLE" if is_visible_debug else "HIDDEN")
	
	if is_visible_debug:
		refresh_display()

func setup_skill_display() -> void:
	if not has_node("/root/SkillSystem"):
		return
	
	var skill_system = get_node("/root/SkillSystem")
	if not skill_system:
		return
	
	# Group skills by category
	var categories = {
		skill_system.SkillCategory.SURVIVAL: [],
		skill_system.SkillCategory.TECHNOLOGY: [],
		skill_system.SkillCategory.COMBAT: [],
		skill_system.SkillCategory.SOCIAL: []
	}
	
	# Sort skills into categories
	for skill_id in skill_system.SKILLS:
		var skill_info = skill_system.SKILLS[skill_id]
		categories[skill_info.category].append(skill_id)
	
	# Create UI for each category
	for category in categories:
		var category_name = skill_system.get_category_name(category)
		
		# Category header
		var header = Label.new()
		header.text = "=== " + category_name.to_upper() + " ==="
		header.add_theme_color_override("font_color", Color.YELLOW)
		skills_container.add_child(header)
		
		# Skills in this category
		for skill_id in categories[category]:
			var skill_container = create_skill_display(skill_id, skill_system)
			skills_container.add_child(skill_container)
		
		# Spacer
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		skills_container.add_child(spacer)

func create_skill_display(skill_id: String, skill_system: Node) -> Control:
	var container = HBoxContainer.new()
	
	# Skill name and level
	var name_label = Label.new()
	name_label.text = skill_system.SKILLS[skill_id].display_name + ":"
	name_label.custom_minimum_size = Vector2(150, 0)
	container.add_child(name_label)
	
	# Level display
	var level_label = Label.new()
	level_label.custom_minimum_size = Vector2(50, 0)
	container.add_child(level_label)
	
	# XP display
	var xp_label = Label.new()
	xp_label.custom_minimum_size = Vector2(150, 0)
	container.add_child(xp_label)
	
	# Progress bar
	var progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(100, 20)
	progress.max_value = 100
	container.add_child(progress)
	
	# Store references
	skill_labels[skill_id] = {
		"level": level_label,
		"xp": xp_label,
		"progress": progress
	}
	
	return container

func setup_test_buttons() -> void:
	var test_scenarios = [
		# Environmental Adaptation
		{"label": "Take Environmental Damage", "method": "_test_environmental_damage"},
		
		# Life Support
		{"label": "Heal Player", "method": "_test_healing"},
		{"label": "Consume Food", "method": "_test_food_consumption"},
		{"label": "Consume Water", "method": "_test_water_consumption"},
		{"label": "Change Oxygen", "method": "_test_oxygen_change"},
		
		# Scavenging
		{"label": "Gather Basic Resource", "method": "_test_basic_resource"},
		{"label": "Find Rare Resource", "method": "_test_rare_resource"},
		{"label": "Discover New Node", "method": "_test_node_discovery"},
		
		# Technology
		{"label": "Place Automation Building", "method": "_test_automation_building"},
		{"label": "Craft Electronics", "method": "_test_craft_electronics"},
		{"label": "Unlock Recipe", "method": "_test_unlock_recipe"},
		
		# === DAMAGE & HEALING SYSTEM TESTS ===
		{"label": "--- DAMAGE TYPES ---", "method": "_test_separator"},
		{"label": "Physical Damage", "method": "_test_physical_damage"},
		{"label": "Fire Damage", "method": "_test_fire_damage"},
		{"label": "Cold Damage", "method": "_test_cold_damage"},
		{"label": "Shock Damage", "method": "_test_shock_damage"},
		{"label": "Radiation Damage", "method": "_test_radiation_damage"},
		{"label": "Environmental Damage", "method": "_test_environmental_damage_new"},
		{"label": "Storm Damage", "method": "_test_storm_damage"},
		
		{"label": "--- HEALING ITEMS ---", "method": "_test_separator"},
		{"label": "Use Medkit", "method": "_test_medkit"},
		{"label": "Use Bandage", "method": "_test_bandage"},
		{"label": "Use Stimpack", "method": "_test_stimpack"},
		{"label": "Use Rad-Away", "method": "_test_rad_away"},
		{"label": "Use Energy Drink", "method": "_test_energy_drink"},
		
		{"label": "--- STATUS EFFECTS ---", "method": "_test_separator"},
		{"label": "Apply Fire Burn", "method": "_test_fire_burn"},
		{"label": "Apply Cold Slow", "method": "_test_cold_slow"},
		{"label": "Apply Shock Stun", "method": "_test_shock_stun"},
		{"label": "Apply Healing Regen", "method": "_test_healing_regen"},
		{"label": "Clear All Effects", "method": "_test_clear_effects"},
		
		# === DURABILITY SYSTEM TESTS ===
		{"label": "--- DURABILITY SYSTEM ---", "method": "_test_separator"},
		{"label": "Damage Equipment", "method": "_test_damage_equipment"},
		{"label": "Damage Primary Weapon", "method": "_test_damage_primary_weapon"},
		{"label": "Break Random Equipment", "method": "_test_break_equipment"},
		{"label": "Repair All Items", "method": "_test_repair_all_items"},
		{"label": "Show Durability Status", "method": "_test_show_durability_status"},
		{"label": "Test Repair Costs", "method": "_test_repair_costs"},
		
		# === RADIATION SYSTEM TESTS ===
		{"label": "--- RADIATION SYSTEM ---", "method": "_test_separator"},
		{"label": "Enter Low Rad Zone", "method": "_test_low_radiation_zone"},
		{"label": "Enter Medium Rad Zone", "method": "_test_medium_radiation_zone"},
		{"label": "Enter High Rad Zone", "method": "_test_high_radiation_zone"},
		{"label": "Enter Extreme Rad Zone", "method": "_test_extreme_radiation_zone"},
		{"label": "Leave Radiation Zone", "method": "_test_leave_radiation_zone"},
		{"label": "Add 10 Radiation", "method": "_test_add_radiation"},
		{"label": "Use Rad-Away", "method": "_test_use_rad_away"},
		{"label": "Use Rad-X", "method": "_test_use_rad_x"},
		{"label": "Use Iodine Tablets", "method": "_test_use_iodine"},
		{"label": "Show Radiation Status", "method": "_test_radiation_status"},
	]
	
	for scenario in test_scenarios:
		var button = Button.new()
		button.text = scenario.label
		button.pressed.connect(Callable(self, scenario.method))
		test_buttons_container.add_child(button)

func setup_rapid_controls() -> void:
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	test_buttons_container.add_child(spacer)
	
	# Rapid Controls Header
	var header = Label.new()
	header.text = "=== RAPID CONTROLS ==="
	header.add_theme_color_override("font_color", Color.CYAN)
	test_buttons_container.add_child(header)
	
	# Custom XP Addition
	var xp_container = VBoxContainer.new()
	test_buttons_container.add_child(xp_container)
	
	var xp_label = Label.new()
	xp_label.text = "Add Custom XP:"
	xp_container.add_child(xp_label)
	
	var xp_amount_container = HBoxContainer.new()
	xp_container.add_child(xp_amount_container)
	
	var xp_slider = HSlider.new()
	xp_slider.min_value = 10
	xp_slider.max_value = 500
	xp_slider.step = 10
	xp_slider.value = 50
	xp_slider.custom_minimum_size = Vector2(150, 20)
	xp_amount_container.add_child(xp_slider)
	
	var xp_value_label = Label.new()
	xp_value_label.text = "50"
	xp_amount_container.add_child(xp_value_label)
	xp_slider.value_changed.connect(func(value): xp_value_label.text = str(int(value)))
	
	# Skill selection for custom XP
	var skill_option = OptionButton.new()
	var skill_system = get_node("/root/SkillSystem")
	if skill_system:
		for skill_id in skill_system.SKILLS:
			skill_option.add_item(skill_system.SKILLS[skill_id].display_name)
			skill_option.set_item_metadata(skill_option.get_item_count() - 1, skill_id)
	xp_container.add_child(skill_option)
	
	var add_xp_button = Button.new()
	add_xp_button.text = "Add XP to Selected Skill"
	add_xp_button.pressed.connect(func(): 
		var selected_index = skill_option.selected
		if selected_index >= 0 and skill_system:
			var skill_id = skill_option.get_item_metadata(selected_index)
			skill_system.add_xp(skill_id, int(xp_slider.value), "debug_manual")
			refresh_display()
	)
	xp_container.add_child(add_xp_button)
	
	# Level-up test
	var levelup_button = Button.new()
	levelup_button.text = "Add XP for Level-Up Test"
	levelup_button.pressed.connect(func():
		var selected_index = skill_option.selected
		if selected_index >= 0 and skill_system:
			var skill_id = skill_option.get_item_metadata(selected_index)
			var current_level = skill_system.get_skill_level(skill_id)
			if current_level < skill_system.MAX_LEVEL:
				var xp_needed = skill_system.get_xp_for_next_level(skill_id)
				skill_system.add_xp(skill_id, xp_needed, "debug_levelup")
				refresh_display()
	)
	xp_container.add_child(levelup_button)
	
	# Reset buttons
	var reset_all_button = Button.new()
	reset_all_button.text = "Reset All Skills"
	reset_all_button.pressed.connect(func(): 
		if skill_system:
			skill_system.debug_reset_all_skills()
			refresh_display()
	)
	test_buttons_container.add_child(reset_all_button)
	
	var max_all_button = Button.new()
	max_all_button.text = "Max All Skills"
	max_all_button.pressed.connect(func(): 
		if skill_system:
			skill_system.debug_max_all_skills()
			refresh_display()
	)
	test_buttons_container.add_child(max_all_button)
	
	# Comprehensive test button
	var test_all_button = Button.new()
	test_all_button.text = "RUN COMPREHENSIVE TESTS"
	test_all_button.add_theme_color_override("font_color", Color.ORANGE)
	test_all_button.pressed.connect(func(): 
		if skill_system:
			skill_system.run_comprehensive_tests()
			refresh_display()
	)
	test_buttons_container.add_child(test_all_button)
	
	# Save/Load test buttons
	var save_test_button = Button.new()
	save_test_button.text = "Test Save Skills"
	save_test_button.pressed.connect(func(): 
		if skill_system:
			skill_system.test_save_skills()
	)
	test_buttons_container.add_child(save_test_button)
	
	var load_test_button = Button.new()
	load_test_button.text = "Test Load Skills"
	load_test_button.pressed.connect(func(): 
		if skill_system:
			skill_system.test_load_skills()
			refresh_display()
	)
	test_buttons_container.add_child(load_test_button)

func refresh_display() -> void:
	if not has_node("/root/SkillSystem"):
		return
	
	# Update skill displays
	var skill_system = get_node("/root/SkillSystem")
	for skill_id in skill_labels:
		var skill_info = skill_system.get_skill_info(skill_id)
		var labels = skill_labels[skill_id]
		
		labels.level.text = "Lv.%d" % skill_info.current_level
		labels.xp.text = "%d XP (Next: %d)" % [skill_info.current_xp, skill_info.xp_for_next_level]
		labels.progress.value = skill_info.progress_percent
		
		# Color coding based on level
		var color = Color.WHITE
		if skill_info.current_level >= 15:
			color = Color.GOLD
		elif skill_info.current_level >= 10:
			color = Color.ORANGE
		elif skill_info.current_level >= 5:
			color = Color.LIGHT_BLUE
		
		labels.level.add_theme_color_override("font_color", color)
	
	# Update XP history
	update_history_display()

func update_history_display() -> void:
	if not has_node("/root/SkillSystem"):
		return
	
	# Clear existing history
	for child in history_container.get_children():
		child.queue_free()
	
	var skill_system = get_node("/root/SkillSystem")
	var history = skill_system.get_xp_history()
	for entry in history.slice(0, 10):  # Show last 10 entries
		var history_label = Label.new()
		var time_ago = (Time.get_ticks_msec() - entry.timestamp) / 1000.0
		var source_text = " (%s)" % entry.source if entry.source != "" else ""
		history_label.text = "%.1fs ago: +%d XP to %s%s" % [time_ago, entry.amount, entry.skill_name, source_text]
		history_label.add_theme_font_size_override("font_size", 12)
		
		# Color recent entries differently
		if time_ago < 5:
			history_label.add_theme_color_override("font_color", Color.LIGHT_GREEN)
		elif time_ago < 30:
			history_label.add_theme_color_override("font_color", Color.YELLOW)
		
		history_container.add_child(history_label)

# Test method implementations
func _test_environmental_damage() -> void:
	if GameManager.player_node:
		GameManager.player_node.modify_health(-15)
		print("[TEST] Triggered environmental damage")

func _test_healing() -> void:
	if GameManager.player_node:
		GameManager.player_node.modify_health(20)
		print("[TEST] Triggered healing")

func _test_food_consumption() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("LIFE_SUPPORT", skill_system.XP_VALUES.FOOD_CONSUMED, "test_food")
		print("[TEST] Simulated food consumption")

func _test_water_consumption() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("LIFE_SUPPORT", skill_system.XP_VALUES.WATER_CONSUMED, "test_water")
		print("[TEST] Simulated water consumption")

func _test_oxygen_change() -> void:
	if GameManager.player_node:
		GameManager.player_node.modify_oxygen(5.0)
		print("[TEST] Triggered oxygen change")

func _test_basic_resource() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RESOURCE_GATHERED, "test_resource")
		print("[TEST] Simulated basic resource gathering")

func _test_rare_resource() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RARE_RESOURCE_FOUND, "test_rare")
		print("[TEST] Simulated rare resource discovery")

func _test_node_discovery() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RESOURCE_NODE_DISCOVERED, "test_node")
		print("[TEST] Simulated node discovery")

func _test_automation_building() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("AUTOMATION_ENGINEERING", skill_system.XP_VALUES.CONVEYOR_BUILT, "test_automation")
		print("[TEST] Simulated automation building")

func _test_craft_electronics() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("ELECTRONICS", skill_system.XP_VALUES.ELECTRONIC_CRAFTED, "test_electronics")
		print("[TEST] Simulated electronics crafting")

func _test_unlock_recipe() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("RESEARCH", skill_system.XP_VALUES.RECIPE_UNLOCKED, "test_recipe")
		print("[TEST] Simulated recipe unlock")

# Signal handlers
func _on_xp_gained(_skill: String, _amount: int) -> void:
	refresh_display()

func _on_level_up(skill: String, new_level: int) -> void:
	refresh_display()
	# Show level up notification
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var skill_name = skill_system.SKILLS[skill].display_name
		print("🎉 LEVEL UP! %s reached level %d!" % [skill_name, new_level])

# Button handlers
func _on_close_button_pressed() -> void:
	toggle_debug_panel()

func _on_refresh_button_pressed() -> void:
	refresh_display()

func _on_clear_history_button_pressed() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.clear_xp_history()
		update_history_display()

func _on_toggle_xp_messages_pressed() -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var current_state = skill_system.debug_xp_messages
		skill_system.set_debug_xp_messages(!current_state)

# === DAMAGE & HEALING SYSTEM TEST METHODS ===
func _test_separator():
	# This is just for visual separation in buttons, no functionality
	pass

# Damage type tests
func _test_physical_damage():
	if GameManager.player_node:
		GameManager.player_node.take_damage(15.0, "physical", "debug_test")
		print("[TEST] Applied 15 physical damage")

func _test_fire_damage():
	if GameManager.player_node:
		GameManager.player_node.take_damage(12.0, "fire", "debug_test")
		print("[TEST] Applied 12 fire damage (may cause burning)")

func _test_cold_damage():
	if GameManager.player_node:
		GameManager.player_node.take_damage(10.0, "cold", "debug_test")
		print("[TEST] Applied 10 cold damage (may cause slow)")

func _test_shock_damage():
	if GameManager.player_node:
		GameManager.player_node.take_damage(8.0, "shock", "debug_test")
		print("[TEST] Applied 8 shock damage (may cause stun)")

func _test_radiation_damage():
	if GameManager.player_node:
		GameManager.player_node.take_damage(20.0, "radiation", "debug_test")
		print("[TEST] Applied 20 radiation damage (increases radiation level)")

func _test_environmental_damage_new():
	if GameManager.player_node:
		GameManager.player_node.apply_environmental_damage(18.0, "toxic_area")
		print("[TEST] Applied environmental damage from toxic area")

func _test_storm_damage():
	if GameManager.player_node:
		GameManager.player_node.apply_storm_damage(2.0)  # Intensity 2.0
		print("[TEST] Applied storm damage (intensity 2.0)")

# Healing item tests
func _test_medkit():
	if GameManager.player_node:
		# Add medkit to inventory if not present
		if not GameManager.player_node.inventory.has_item("MEDKIT", 1):
			GameManager.player_node.inventory.add_item("MEDKIT")
		GameManager.player_node.consume_healing_item("MEDKIT")
		print("[TEST] Used medkit (50 HP healing)")

func _test_bandage():
	if GameManager.player_node:
		if not GameManager.player_node.inventory.has_item("BANDAGE", 1):
			GameManager.player_node.inventory.add_item("BANDAGE")
		GameManager.player_node.consume_healing_item("BANDAGE")
		print("[TEST] Used bandage (20 HP healing)")

func _test_stimpack():
	if GameManager.player_node:
		if not GameManager.player_node.inventory.has_item("STIMPACK", 1):
			GameManager.player_node.inventory.add_item("STIMPACK")
		GameManager.player_node.consume_healing_item("STIMPACK")
		print("[TEST] Used stimpack (30 HP + regen over time)")

func _test_rad_away():
	if GameManager.player_node:
		if not GameManager.player_node.inventory.has_item("RAD_AWAY", 1):
			GameManager.player_node.inventory.add_item("RAD_AWAY")
		GameManager.player_node.consume_healing_item("RAD_AWAY")
		print("[TEST] Used Rad-Away (reduces radiation)")

func _test_energy_drink():
	if GameManager.player_node:
		if not GameManager.player_node.inventory.has_item("ENERGY_DRINK", 1):
			GameManager.player_node.inventory.add_item("ENERGY_DRINK")
		GameManager.player_node.consume_healing_item("ENERGY_DRINK")
		print("[TEST] Used energy drink (energy + speed boost)")

# Status effect tests
func _test_fire_burn():
	if StatusEffectSystem:
		StatusEffectSystem.apply_fire_burn(8.0, 4.0)
		print("[TEST] Applied fire burn (8s duration, 4 damage/sec)")

func _test_cold_slow():
	if StatusEffectSystem:
		StatusEffectSystem.apply_cold_slow(5.0, 0.5)
		print("[TEST] Applied cold slow (5s duration, 50% speed)")

func _test_shock_stun():
	if StatusEffectSystem:
		StatusEffectSystem.apply_shock_stun(2.0)
		print("[TEST] Applied shock stun (2s duration)")

func _test_healing_regen():
	if StatusEffectSystem:
		StatusEffectSystem.apply_healing_over_time(12.0, 3.0, "debug_test")
		print("[TEST] Applied healing regen (12s duration, 3 HP/sec)")

func _test_clear_effects():
	if StatusEffectSystem:
		StatusEffectSystem.clear_all_effects()
		print("[TEST] Cleared all status effects")

# === DURABILITY SYSTEM TEST METHODS ===
func _test_damage_equipment():
	if not EquipmentManager:
		print("[TEST] EquipmentManager not found")
		return
	
	var damaged_any = false
	for slot in EquipmentManager.EQUIPMENT_SLOTS:
		var equipment = EquipmentManager.get_equipped_item(slot)
		if equipment and equipment.has_method("reduce_durability"):
			equipment.reduce_durability(15)  # Damage by 15 points
			damaged_any = true
			var durability_pct = int(equipment.get_durability_percentage() * 100)
			print("[TEST] Damaged %s - now at %d%% durability" % [equipment.name, durability_pct])
	
	if damaged_any:
		EquipmentManager.update_total_stats()
	else:
		print("[TEST] No equipment found to damage")

func _test_damage_primary_weapon():
	if not WeaponManager:
		print("[TEST] WeaponManager not found")
		return
	
	var weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
	if weapon:
		weapon.current_durability = max(0, weapon.current_durability - 20)
		var durability_pct = int(weapon.get_durability_percentage() * 100)
		print("[TEST] Damaged %s - now at %d%% durability" % [weapon.name, durability_pct])
		
		if weapon.is_broken():
			print("[TEST] WARNING: %s is now broken!" % weapon.name)
	else:
		print("[TEST] No primary weapon equipped")

func _test_break_equipment():
	if not EquipmentManager:
		print("[TEST] EquipmentManager not found")
		return
	
	# Find a random equipped item to break
	var equipped_items = []
	for slot in EquipmentManager.EQUIPMENT_SLOTS:
		var equipment = EquipmentManager.get_equipped_item(slot)
		if equipment and equipment.has_method("reduce_durability"):
			equipped_items.append(equipment)
	
	if equipped_items.is_empty():
		print("[TEST] No equipment found to break")
		return
	
	var random_item = equipped_items[randi() % equipped_items.size()]
	random_item.current_durability = 0  # Break it completely
	print("[TEST] Broke %s completely!" % random_item.name)
	
	EquipmentManager.update_total_stats()

func _test_repair_all_items():
	print("[TEST] Repairing all items...")
	var repaired_count = 0
	
	# Repair all equipped items
	if EquipmentManager:
		for slot in EquipmentManager.EQUIPMENT_SLOTS:
			var equipment = EquipmentManager.get_equipped_item(slot)
			if equipment and equipment.has_method("repair_equipment"):
				var missing_durability = equipment.durability - equipment.current_durability
				if missing_durability > 0:
					equipment.repair_equipment(missing_durability)
					repaired_count += 1
					print("[TEST] Repaired %s to full durability" % equipment.name)
		
		if repaired_count > 0:
			EquipmentManager.update_total_stats()
	
	# Repair all equipped weapons
	if WeaponManager:
		var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
		if primary_weapon:
			var missing_durability = primary_weapon.durability - primary_weapon.current_durability
			if missing_durability > 0:
				primary_weapon.repair_weapon(missing_durability)
				repaired_count += 1
				print("[TEST] Repaired %s to full durability" % primary_weapon.name)
		
		var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
		if secondary_weapon:
			var missing_durability = secondary_weapon.durability - secondary_weapon.current_durability
			if missing_durability > 0:
				secondary_weapon.repair_weapon(missing_durability)
				repaired_count += 1
				print("[TEST] Repaired %s to full durability" % secondary_weapon.name)
	
	print("[TEST] Repaired %d items total" % repaired_count)

func _test_show_durability_status():
	print("[TEST] === DURABILITY STATUS ===")
	
	# Show equipped items
	if EquipmentManager:
		print("EQUIPPED ITEMS:")
		for slot in EquipmentManager.EQUIPMENT_SLOTS:
			var equipment = EquipmentManager.get_equipped_item(slot)
			if equipment:
				if equipment.has_method("get_durability_percentage"):
					var durability_pct = int(equipment.get_durability_percentage() * 100)
					var condition = equipment.get_equipment_condition_text()
					print("  %s: %s (%d%% durability)" % [equipment.name, condition, durability_pct])
				else:
					print("  %s: No durability system" % equipment.name)
			else:
				print("  %s: Empty" % slot)
	
	# Show equipped weapons
	if WeaponManager:
		print("EQUIPPED WEAPONS:")
		var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
		if primary_weapon:
			var durability_pct = int(primary_weapon.get_durability_percentage() * 100)
			var condition = primary_weapon.get_weapon_condition_text()
			print("  PRIMARY: %s (%s - %d%% durability)" % [primary_weapon.name, condition, durability_pct])
		else:
			print("  PRIMARY: Empty")
		
		var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
		if secondary_weapon:
			var durability_pct = int(secondary_weapon.get_durability_percentage() * 100)
			var condition = secondary_weapon.get_weapon_condition_text()
			print("  SECONDARY: %s (%s - %d%% durability)" % [secondary_weapon.name, condition, durability_pct])
		else:
			print("  SECONDARY: Empty")

func _test_repair_costs():
	print("[TEST] === REPAIR COST ANALYSIS ===")
	
	# Create a mock repair bench to test cost calculations
	var repair_bench = preload("res://scripts/buildings/RepairBench.gd").new()
	
	# Check equipped items
	if EquipmentManager:
		for slot in EquipmentManager.EQUIPMENT_SLOTS:
			var equipment = EquipmentManager.get_equipped_item(slot)
			if equipment and equipment.has_method("get_durability_percentage"):
				if equipment.get_durability_percentage() < 1.0:
					var cost = repair_bench.calculate_repair_cost(equipment)
					var cost_str = repair_bench.format_repair_cost(cost)
					var can_afford = repair_bench.can_afford_repair(equipment, GameManager.player_node)
					print("  %s: %s %s" % [equipment.name, cost_str, "(AFFORDABLE)" if can_afford else "(TOO EXPENSIVE)"])
	
	# Check equipped weapons
	if WeaponManager:
		var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
		if primary_weapon and primary_weapon.get_durability_percentage() < 1.0:
			var cost = repair_bench.calculate_repair_cost(primary_weapon)
			var cost_str = repair_bench.format_repair_cost(cost)
			var can_afford = repair_bench.can_afford_repair(primary_weapon, GameManager.player_node)
			print("  %s: %s %s" % [primary_weapon.name, cost_str, "(AFFORDABLE)" if can_afford else "(TOO EXPENSIVE)"])
	
	repair_bench.queue_free()  # Clean up the mock object

# === RADIATION SYSTEM TESTS ===

func _test_low_radiation_zone() -> void:
	var player = GameManager.player_node
	if player and player.has_method("set_radiation_zone"):
		player.set_radiation_zone(0.2)  # 20% intensity - Low radiation
		print("TEST: Entered low radiation zone (20%) - 1 damage per 5 minutes")

func _test_medium_radiation_zone() -> void:
	var player = GameManager.player_node
	if player and player.has_method("set_radiation_zone"):
		player.set_radiation_zone(0.5)  # 50% intensity - Medium radiation
		print("TEST: Entered medium radiation zone (50%) - 1 damage per 2 minutes")

func _test_high_radiation_zone() -> void:
	var player = GameManager.player_node
	if player and player.has_method("set_radiation_zone"):
		player.set_radiation_zone(0.8)  # 80% intensity - High radiation
		print("TEST: Entered high radiation zone (80%) - 1 damage per 30 seconds")

func _test_extreme_radiation_zone() -> void:
	var player = GameManager.player_node
	if player and player.has_method("set_radiation_zone"):
		player.set_radiation_zone(0.95)  # 95% intensity - Extreme radiation
		print("TEST: Entered extreme radiation zone (95%) - 1 damage per 10 seconds")

func _test_leave_radiation_zone() -> void:
	var player = GameManager.player_node
	if player and player.has_method("set_radiation_zone"):
		player.set_radiation_zone(0.0)  # No radiation
		print("TEST: Left radiation zone")

func _test_add_radiation() -> void:
	var player = GameManager.player_node
	if player and player.has_method("add_radiation_damage"):
		player.add_radiation_damage(10.0)
		print("TEST: Added 10 radiation damage directly")

func _test_use_rad_away() -> void:
	var player = GameManager.player_node
	if player and player.has_method("consume_radiation_treatment"):
		# First add some radiation treatment items to inventory
		if InventorySystem:
			InventorySystem.add_item("RAD_AWAY", 1)
		if player.consume_radiation_treatment("RAD_AWAY"):
			print("TEST: Used Rad-Away successfully (-25 radiation)")
		else:
			print("TEST: Failed to use Rad-Away")

func _test_use_rad_x() -> void:
	var player = GameManager.player_node
	if player and player.has_method("consume_radiation_treatment"):
		# First add some radiation treatment items to inventory
		if InventorySystem:
			InventorySystem.add_item("RAD_X", 1)
		if player.consume_radiation_treatment("RAD_X"):
			print("TEST: Used Rad-X successfully (-15 radiation)")
		else:
			print("TEST: Failed to use Rad-X")

func _test_use_iodine() -> void:
	var player = GameManager.player_node
	if player and player.has_method("consume_radiation_treatment"):
		# First add some radiation treatment items to inventory
		if InventorySystem:
			InventorySystem.add_item("IODINE_TABLETS", 1)
		if player.consume_radiation_treatment("IODINE_TABLETS"):
			print("TEST: Used Iodine Tablets successfully (-10 radiation)")
		else:
			print("TEST: Failed to use Iodine Tablets")

func _test_radiation_status() -> void:
	var player = GameManager.player_node
	if player and player.has_method("get_radiation_percentage"):
		var rad_pct = player.get_radiation_percentage()
		var rad_level = player.get_radiation_level_text() if player.has_method("get_radiation_level_text") else "Unknown"
		var current_rad = player.current_radiation_damage if "current_radiation_damage" in player else 0
		var max_rad = player.max_radiation_damage if "max_radiation_damage" in player else 100
		var in_zone = player.in_radiation_zone if "in_radiation_zone" in player else false
		var zone_intensity = player.current_radiation_intensity if "current_radiation_intensity" in player else 0
		
		print("=== RADIATION STATUS ===")
		print("Current Radiation: %.1f/%.1f (%.1f%%)" % [current_rad, max_rad, rad_pct * 100])
		print("Radiation Level: %s" % rad_level)
		print("In Radiation Zone: %s" % ("Yes" if in_zone else "No"))
		if in_zone:
			print("Zone Intensity: %.1f%%" % (zone_intensity * 100))
		
		# Show stamina effects
		var original_energy = 100  # Assume base energy
		var current_max_energy = player.max_energy if "max_energy" in player else 100
		var stamina_reduction = ((original_energy - current_max_energy) / float(original_energy)) * 100
		print("Stamina Reduction: %.1f%% (Max Energy: %d)" % [stamina_reduction, current_max_energy])

# Storm System Testing Functions
func add_storm_test_buttons() -> void:
	# Storm system header
	var storm_header = Label.new()
	storm_header.text = "=== STORM SYSTEM TESTING ==="
	storm_header.add_theme_font_size_override("font_size", 14)
	storm_header.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	test_buttons_container.add_child(storm_header)
	
	# Test storm buttons
	var test_buttons = [
		["Force Dust Storm", "_test_dust_storm"],
		["Force Radiation Storm", "_test_radiation_storm"],
		["Force Electrical Storm", "_test_electrical_storm"],
		["Force Toxic Storm", "_test_toxic_storm"],
		["Trigger Early Warning", "_test_early_warning"],
		["Trigger Immediate Warning", "_test_immediate_warning"],
		["End Current Storm", "_test_end_storm"],
		["Check Storm Status", "_test_storm_status"]
	]
	
	for button_data in test_buttons:
		var button = Button.new()
		button.text = button_data[0]
		button.custom_minimum_size = Vector2(180, 25)
		button.pressed.connect(Callable(self, button_data[1]))
		test_buttons_container.add_child(button)

func _test_dust_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.force_storm(storm_system.StormType.DUST_STORM)
		print("TEST: Forced Dust Storm (visibility/movement penalty)")
	else:
		print("TEST: StormSystem not available")

func _test_radiation_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.force_storm(storm_system.StormType.RADIATION_STORM)
		print("TEST: Forced Radiation Storm (3x radiation accumulation)")
	else:
		print("TEST: StormSystem not available")

func _test_electrical_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.force_storm(storm_system.StormType.ELECTRICAL_STORM)
		print("TEST: Forced Electrical Storm (equipment damage risk)")
	else:
		print("TEST: StormSystem not available")

func _test_toxic_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.force_storm(storm_system.StormType.TOXIC_STORM)
		print("TEST: Forced Toxic Storm (breathing damage)")
	else:
		print("TEST: StormSystem not available")

func _test_early_warning() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.skip_to_warning(storm_system.WarningType.EARLY_WARNING)
		print("TEST: Skipped to Early Warning phase")
	else:
		print("TEST: StormSystem not available")

func _test_immediate_warning() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.skip_to_warning(storm_system.WarningType.IMMEDIATE_WARNING)
		print("TEST: Skipped to Immediate Warning phase")
	else:
		print("TEST: StormSystem not available")

func _test_end_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		storm_system.end_storm()
		print("TEST: Manually ended current storm")
	else:
		print("TEST: StormSystem not available")

func _test_storm_status() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if not storm_system:
		print("TEST: StormSystem not available")
		return
		
	print("=== STORM STATUS ===")
	print("Storm Active: %s" % ("Yes" if storm_system.is_storm_active() else "No"))
	print("Current Phase: %s" % storm_system.get_current_storm_phase())
	
	if storm_system.is_storm_active():
		print("Storm Type: %s" % storm_system.get_storm_name(storm_system.get_current_storm_type()))
		print("Duration Remaining: %.1f minutes" % (storm_system.get_storm_duration_remaining() / 60.0))
		print("Movement Modifier: %.1fx" % storm_system.get_movement_modifier())
		print("Visibility Modifier: %.1fx" % storm_system.get_visibility_modifier())
		print("Radiation Multiplier: %.1fx" % storm_system.get_radiation_multiplier())
		print("Player Sheltered: %s" % ("Yes" if storm_system.is_player_sheltered() else "No"))
	else:
		var time_until = storm_system.get_time_until_next_storm()
		if time_until > 0:
			print("Next Storm In: %.1f minutes" % (time_until / 60.0))
		else:
			print("Next Storm: Not scheduled")

func _init_storm_testing() -> void:
	# Add storm testing buttons after the regular ones
	add_storm_test_buttons()

func _init_stealth_testing() -> void:
	# Add stealth testing buttons after storm buttons
	add_stealth_test_buttons()

# Stealth System Testing Functions
func add_stealth_test_buttons() -> void:
	# Stealth system header
	var stealth_header = Label.new()
	stealth_header.text = "=== STEALTH SYSTEM TESTING ==="
	stealth_header.add_theme_font_size_override("font_size", 14)
	stealth_header.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	test_buttons_container.add_child(stealth_header)
	
	# Test stealth buttons
	var test_buttons = [
		["Toggle Crouch", "_test_toggle_crouch"],
		["Force Stand Up", "_test_force_stand"],
		["Force Crouch", "_test_force_crouch"],
		["Modify Stealth (+25)", "_test_increase_stealth"],
		["Modify Stealth (-25)", "_test_decrease_stealth"],
		["Reset Stealth", "_test_reset_stealth"],
		["Test Equipment Bonus", "_test_equipment_stealth"],
		["Check Stealth Status", "_test_stealth_status"]
	]
	
	for button_data in test_buttons:
		var button = Button.new()
		button.text = button_data[0]
		button.custom_minimum_size = Vector2(180, 25)
		button.pressed.connect(Callable(self, button_data[1]))
		test_buttons_container.add_child(button)

func _test_toggle_crouch() -> void:
	var player = GameManager.player_node
	if player and player.has_method("toggle_crouch"):
		player.toggle_crouch()
		print("TEST: Toggled player crouch state")
	else:
		print("TEST: Player or toggle_crouch method not available")

func _test_force_stand() -> void:
	var player = GameManager.player_node
	if player and "is_crouching" in player:
		if player.is_crouching:
			player.toggle_crouch()
		print("TEST: Forced player to stand up")
	else:
		print("TEST: Player not available")

func _test_force_crouch() -> void:
	var player = GameManager.player_node
	if player and "is_crouching" in player:
		if not player.is_crouching:
			player.toggle_crouch()
		print("TEST: Forced player to crouch")
	else:
		print("TEST: Player not available")

func _test_increase_stealth() -> void:
	var player = GameManager.player_node
	if player and player.has_method("add_stealth_bonus"):
		player.add_stealth_bonus(25.0)
		print("TEST: Added +25 stealth bonus")
	else:
		print("TEST: Player or add_stealth_bonus method not available")

func _test_decrease_stealth() -> void:
	var player = GameManager.player_node
	if player and player.has_method("add_stealth_bonus"):
		player.add_stealth_bonus(-25.0)
		print("TEST: Added -25 stealth penalty")
	else:
		print("TEST: Player or add_stealth_bonus method not available")

func _test_reset_stealth() -> void:
	var player = GameManager.player_node
	if player and "base_stealth" in player:
		player.base_stealth = 50.0
		player.stealth_modifier = 1.0
		print("TEST: Reset stealth to defaults (base: 50, modifier: 1.0x)")
	else:
		print("TEST: Player not available")

func _test_equipment_stealth() -> void:
	var player = GameManager.player_node
	if player and player.has_method("modify_stealth"):
		player.modify_stealth(1.5)  # 50% stealth bonus from equipment
		print("TEST: Applied equipment stealth bonus (1.5x multiplier)")
	else:
		print("TEST: Player or modify_stealth method not available")

func _test_stealth_status() -> void:
	var player = GameManager.player_node
	if not player:
		print("TEST: Player not available")
		return
		
	print("=== STEALTH STATUS ===")
	
	if player.has_method("get_stealth_info"):
		var stealth_info = player.get_stealth_info()
		print("Crouching: %s" % ("Yes" if stealth_info.is_crouching else "No"))
		print("Stealth State: %s" % stealth_info.stealth_state)
		print("Base Stealth: %.1f" % stealth_info.base_stealth)
		print("Stealth Modifier: %.1fx" % stealth_info.stealth_modifier)
		print("Crouch Bonus: +%.1f" % stealth_info.crouch_bonus)
		print("Effective Stealth: %.1f" % stealth_info.effective_stealth)
		print("Detection Difficulty: %.2fx" % stealth_info.detection_difficulty)
	else:
		# Fallback manual checks
		var is_crouching = player.is_crouching if "is_crouching" in player else false
		var base_stealth = player.base_stealth if "base_stealth" in player else 0
		var stealth_modifier = player.stealth_modifier if "stealth_modifier" in player else 1.0
		
		print("Crouching: %s" % ("Yes" if is_crouching else "No"))
		print("Base Stealth: %.1f" % base_stealth)
		print("Stealth Modifier: %.1fx" % stealth_modifier)
		
		if player.has_method("get_current_stealth_value"):
			print("Effective Stealth: %.1f" % player.get_current_stealth_value())
		if player.has_method("get_detection_difficulty"):
			print("Detection Difficulty: %.2fx" % player.get_detection_difficulty())
