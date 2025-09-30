extends Control

class_name HUD

var health_bar: ProgressBar
var energy_bar: ProgressBar
var hunger_bar: ProgressBar
var thirst_bar: ProgressBar
var radiation_bar: ProgressBar
var health_label: Label
var energy_label: Label
var hunger_label: Label
var thirst_label: Label
var radiation_label: Label
var radiation_status_label: Label


var time_label: Label
var day_label: Label
var weather_label: Label

var notification_container: VBoxContainer
var oxygen_display: OxygenDisplay
var storm_warning_ui: StormWarningUI
var hotbar: Hotbar
var message_label: Label
var message_timer: Timer


func _ready() -> void:
	# Add to HUD group for easy finding
	add_to_group("hud")
	
	# Safely get node references
	health_bar = get_node_or_null("StatsPanel/HealthBar")
	energy_bar = get_node_or_null("StatsPanel/EnergyBar")
	hunger_bar = get_node_or_null("StatsPanel/HungerBar")
	thirst_bar = get_node_or_null("StatsPanel/ThirstBar")
	radiation_bar = get_node_or_null("StatsPanel/RadiationBar")
	health_label = get_node_or_null("StatsPanel/HealthLabel")
	energy_label = get_node_or_null("StatsPanel/EnergyLabel")
	hunger_label = get_node_or_null("StatsPanel/HungerLabel")
	thirst_label = get_node_or_null("StatsPanel/ThirstLabel")
	radiation_label = get_node_or_null("StatsPanel/RadiationLabel")
	radiation_status_label = get_node_or_null("StatsPanel/RadiationStatusLabel")
	
	# Environmental stats are now in the scene file, no need to create programmatically
	# create_environmental_stats_display()

	# Create storm warning UI
	create_storm_warning_ui()

	# Hotbar is now in the scene hierarchy (HotbarLayer), no need to create programmatically
	# create_hotbar()

	# Create message system
	create_message_system()

	# Debug: Check what UI elements were found
	if not thirst_bar:
		print("WARNING: ThirstBar not found in HUD scene")
	if not thirst_label:
		print("WARNING: ThirstLabel not found in HUD scene")
	
	
	time_label = get_node_or_null("TimePanel/TimeLabel")
	day_label = get_node_or_null("TimePanel/DayLabel")
	weather_label = get_node_or_null("TimePanel/WeatherLabel")
	
	notification_container = get_node_or_null("NotificationContainer")
	
	# VBoxContainer handles layout automatically now
	# fix_stats_layout()
	# fix_time_layout()
	
	connect_signals()
	update_all_displays()

func connect_signals() -> void:
	if GameManager.player_node:
		print("DEBUG: HUD connecting to player signals...")
		GameManager.player_node.health_changed.connect(_on_health_changed)
		GameManager.player_node.energy_changed.connect(_on_energy_changed)
		GameManager.player_node.hunger_changed.connect(_on_hunger_changed)
		GameManager.player_node.thirst_changed.connect(_on_thirst_changed)
		if GameManager.player_node.has_signal("radiation_changed"):
			GameManager.player_node.radiation_changed.connect(_on_radiation_changed)
		print("DEBUG: HUD signals connected successfully")
	else:
		print("DEBUG: HUD cannot connect - GameManager.player_node is null, will retry...")
		# Try again after a delay
		await get_tree().create_timer(0.1).timeout
		connect_signals()
	
	# Connect manager signals with duplicate check
	if not TimeManager.hour_passed.is_connected(_on_hour_passed):
		TimeManager.hour_passed.connect(_on_hour_passed)
	if not TimeManager.day_passed.is_connected(_on_day_passed):
		TimeManager.day_passed.connect(_on_day_passed)
	if not EventBus.storm_started.is_connected(_on_storm_started):
		EventBus.storm_started.connect(_on_storm_started)
	if not EventBus.storm_ended.is_connected(_on_storm_ended):
		EventBus.storm_ended.connect(_on_storm_ended)
	
	

func update_all_displays() -> void:
	update_stats_display()
	update_time_display()

func update_stats_display() -> void:
	if not GameManager.player_node:
		return
	
	var player = GameManager.player_node
	
	if health_bar:
		health_bar.max_value = player.max_health
		health_bar.value = player.health
	if health_label:
		health_label.text = "Health: %d/%d" % [player.health, player.max_health]
	
	if energy_bar:
		energy_bar.max_value = player.max_energy
		energy_bar.value = player.energy
	if energy_label:
		energy_label.text = "Energy: %d/%d" % [player.energy, player.max_energy]
	
	if hunger_bar:
		hunger_bar.max_value = player.max_hunger
		hunger_bar.value = player.hunger
	if hunger_label:
		hunger_label.text = "Hunger: %d/%d" % [player.hunger, player.max_hunger]
	
	if thirst_bar:
		thirst_bar.max_value = player.max_thirst
		thirst_bar.value = player.thirst
	if thirst_label:
		thirst_label.text = "Thirst: %d/%d" % [player.thirst, player.max_thirst]
	
	# Update radiation display
	if radiation_bar and "current_radiation_damage" in player:
		radiation_bar.max_value = player.max_radiation_damage
		radiation_bar.value = player.current_radiation_damage
		# Set bar color based on radiation level
		var rad_pct = player.current_radiation_damage / player.max_radiation_damage
		if rad_pct <= 0.25:
			radiation_bar.modulate = Color(0.3, 1.0, 0.3)  # Green - Safe
		elif rad_pct <= 0.5:
			radiation_bar.modulate = Color(1.0, 1.0, 0.3)  # Yellow - Mild
		elif rad_pct <= 0.75:
			radiation_bar.modulate = Color(1.0, 0.6, 0.3)  # Orange - Moderate
		else:
			radiation_bar.modulate = Color(1.0, 0.3, 0.3)  # Red - Severe
	
	if radiation_label and "current_radiation_damage" in player:
		radiation_label.text = "☢ Radiation: %d/%d" % [player.current_radiation_damage, player.max_radiation_damage]
		
	if radiation_status_label and player.has_method("get_radiation_level_text"):
		var rad_level = player.get_radiation_level_text()
		var stamina_effect = ""
		var rad_pct = player.current_radiation_damage / player.max_radiation_damage
		if rad_pct > 0.75:
			stamina_effect = " (-50% Stamina)"
		elif rad_pct > 0.5:
			stamina_effect = " (-25% Stamina)"
		elif rad_pct > 0.25:
			stamina_effect = " (-10% Stamina)"
		radiation_status_label.text = "%s%s" % [rad_level, stamina_effect]


func update_time_display() -> void:
	if time_label:
		time_label.text = TimeManager.get_time_string()
	if day_label:
		day_label.text = TimeManager.get_day_string()

func _on_health_changed(new_health: int) -> void:
	if health_bar:
		health_bar.value = new_health
	if health_label and GameManager.player_node:
		health_label.text = "Health: %d/%d" % [new_health, GameManager.player_node.max_health]

func _on_energy_changed(new_energy: int) -> void:
	if energy_bar:
		energy_bar.value = new_energy
	if energy_label and GameManager.player_node:
		energy_label.text = "Energy: %d/%d" % [new_energy, GameManager.player_node.max_energy]

func _on_hunger_changed(new_hunger: int) -> void:
	if hunger_bar:
		hunger_bar.value = new_hunger
	if hunger_label and GameManager.player_node:
		hunger_label.text = "Hunger: %d/%d" % [new_hunger, GameManager.player_node.max_hunger]

func _on_thirst_changed(new_thirst: int) -> void:
	if thirst_bar:
		thirst_bar.value = new_thirst
	if thirst_label and GameManager.player_node:
		thirst_label.text = "Thirst: %d/%d" % [new_thirst, GameManager.player_node.max_thirst]

func _on_radiation_changed(current_radiation: float, max_radiation: float) -> void:
	if radiation_bar:
		radiation_bar.max_value = max_radiation
		radiation_bar.value = current_radiation
		# Set bar color based on radiation level
		var rad_pct = current_radiation / max_radiation
		if rad_pct <= 0.25:
			radiation_bar.modulate = Color(0.3, 1.0, 0.3)  # Green - Safe
		elif rad_pct <= 0.5:
			radiation_bar.modulate = Color(1.0, 1.0, 0.3)  # Yellow - Mild
		elif rad_pct <= 0.75:
			radiation_bar.modulate = Color(1.0, 0.6, 0.3)  # Orange - Moderate
		else:
			radiation_bar.modulate = Color(1.0, 0.3, 0.3)  # Red - Severe
	
	if radiation_label:
		radiation_label.text = "☢ Radiation: %d/%d" % [int(current_radiation), int(max_radiation)]
	
	if radiation_status_label and GameManager.player_node:
		var player = GameManager.player_node
		if player.has_method("get_radiation_level_text"):
			var rad_level = player.get_radiation_level_text()
			var stamina_effect = ""
			var rad_pct = current_radiation / max_radiation
			if rad_pct > 0.75:
				stamina_effect = " (-50% Stamina)"
			elif rad_pct > 0.5:
				stamina_effect = " (-25% Stamina)"
			elif rad_pct > 0.25:
				stamina_effect = " (-10% Stamina)"
			radiation_status_label.text = "%s%s" % [rad_level, stamina_effect]
			
			# Show warning for high radiation
			if rad_pct > 0.75:
				show_notification("⚠ SEVERE RADIATION - Stamina greatly reduced!", Color(1.0, 0.3, 0.3))
			elif rad_pct > 0.5 and int(current_radiation) % 10 == 0:  # Show occasionally
				show_notification("Radiation affecting stamina", Color(1.0, 0.6, 0.3))

func _on_hour_passed(_hour: int) -> void:
	update_time_display()

func _on_day_passed(day: int) -> void:
	update_time_display()
	show_notification("Day %d has begun" % day)

func _on_storm_started(_intensity: float) -> void:
	if weather_label:
		weather_label.text = "STORM ACTIVE!"
		weather_label.modulate = Color(1, 0.3, 0.3)
	show_notification("Toxic storm approaching! Seek shelter!", Color(1, 0.3, 0.3))

func _on_storm_ended() -> void:
	if weather_label:
		weather_label.text = "Clear"
		weather_label.modulate = Color.WHITE
	show_notification("Storm has passed", Color(0.3, 1, 0.3))

func fix_stats_layout() -> void:
	if health_bar and energy_bar and hunger_bar and thirst_bar:
		# Stack bars vertically with proper spacing
		health_bar.position = Vector2(10, 10)
		health_bar.size = Vector2(260, 20)
		
		energy_bar.position = Vector2(10, 35)
		energy_bar.size = Vector2(260, 20)
		
		hunger_bar.position = Vector2(10, 60)
		hunger_bar.size = Vector2(260, 20)
		
		thirst_bar.position = Vector2(10, 85)
		thirst_bar.size = Vector2(260, 20)
	
	if health_label and energy_label and hunger_label and thirst_label:
		# Position labels next to bars
		health_label.position = Vector2(10, 110)
		health_label.size = Vector2(260, 20)
		
		energy_label.position = Vector2(10, 125)
		energy_label.size = Vector2(260, 20)
		
		hunger_label.position = Vector2(10, 140)
		hunger_label.size = Vector2(260, 20)
		
		thirst_label.position = Vector2(10, 155)
		thirst_label.size = Vector2(260, 20)

func fix_time_layout() -> void:
	if time_label and day_label and weather_label:
		# Stack time info vertically
		time_label.position = Vector2(10, 5)
		time_label.size = Vector2(180, 20)
		
		day_label.position = Vector2(10, 25)
		day_label.size = Vector2(180, 20)
		
		weather_label.position = Vector2(10, 45)
		weather_label.size = Vector2(180, 20)

func create_thirst_ui_elements() -> void:
	var stats_panel = get_node_or_null("StatsPanel")
	if not stats_panel:
		print("ERROR: Cannot create thirst UI - StatsPanel not found")
		return
	
	# Create ThirstBar by duplicating HungerBar if it exists
	if hunger_bar:
		thirst_bar = hunger_bar.duplicate()
		thirst_bar.name = "ThirstBar"
		thirst_bar.modulate = Color(0.2, 0.8, 1.0)  # Blue/cyan color
		stats_panel.add_child(thirst_bar)
		
		# Position it below the hunger bar
		if hunger_bar.position:
			thirst_bar.position = hunger_bar.position + Vector2(0, 30)
		
		print("Created ThirstBar programmatically")
	
	# Create ThirstLabel by duplicating HungerLabel if it exists
	if hunger_label:
		thirst_label = hunger_label.duplicate()
		thirst_label.name = "ThirstLabel"
		thirst_label.text = "Thirst: 100/100"
		stats_panel.add_child(thirst_label)
		
		# Position it below the hunger label
		if hunger_label.position:
			thirst_label.position = hunger_label.position + Vector2(0, 30)
		
		print("Created ThirstLabel programmatically")

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notification_container:
		return
	
	var notification_label = Label.new()
	notification_label.text = text
	notification_label.modulate = color
	notification_container.add_child(notification_label)
	
	var tween = create_tween()
	tween.tween_property(notification_label, "modulate:a", 0.0, 3.0)
	tween.tween_callback(notification_label.queue_free)

func create_message_system():
	"""Create the temporary message display system"""
	message_label = Label.new()
	message_label.name = "MessageLabel"
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.modulate = Color(1, 1, 1, 0)  # Start invisible
	
	# Style the message label
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_font_size_override("font_size", 20)
	
	# Position it in the center-top area
	message_label.anchor_left = 0.3
	message_label.anchor_right = 0.7
	message_label.anchor_top = 0.15
	message_label.anchor_bottom = 0.25
	
	add_child(message_label)
	
	# Create timer for message fade
	message_timer = Timer.new()
	message_timer.wait_time = 1.0
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timer_timeout)
	add_child(message_timer)

func show_message(text: String, duration: float = 3.0):
	"""Show a temporary message to the player"""
	if not message_label:
		return
		
	message_label.text = text
	message_label.modulate = Color(1, 1, 1, 1)  # Make visible
	
	# Set timer for fade out
	message_timer.wait_time = duration
	message_timer.start()

func _on_message_timer_timeout():
	"""Fade out the message"""
	if message_label:
		var tween = create_tween()
		tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): message_label.text = "")

func create_hotbar() -> void:
	var hotbar_scene = load("res://scenes/ui/Hotbar.tscn")
	if hotbar_scene:
		hotbar = hotbar_scene.instantiate()
		add_child(hotbar)
		
		# Connect hotbar signals
		if hotbar.has_signal("item_used"):
			hotbar.item_used.connect(_on_hotbar_item_used)
		
		print("Hotbar created and added to HUD")
	else:
		print("ERROR: Could not load Hotbar scene")

func _on_hotbar_item_used(_slot_index: int, item_id: String) -> void:
	var item_data = InventorySystem.get_item_data(item_id)
	var item_name = item_data.get("name", item_id)
	show_notification("Used: %s" % item_name, Color(0.8, 0.8, 1.0))

func create_storm_warning_ui() -> void:
	storm_warning_ui = StormWarningUI.new()
	storm_warning_ui.name = "StormWarningUI"
	add_child(storm_warning_ui)
	print("StormWarningUI created and added to HUD")

func create_environmental_stats_display() -> void:
	# Create a single container for both oxygen and radiation
	var env_container = VBoxContainer.new()
	env_container.name = "EnvironmentalStatsContainer"
	env_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	env_container.position = Vector2(10, 180)
	env_container.add_theme_constant_override("separation", 10)
	add_child(env_container)
	
	# === OXYGEN SECTION ===
	var oxygen_section = VBoxContainer.new()
	oxygen_section.name = "OxygenSection"
	oxygen_section.add_theme_constant_override("separation", 2)
	env_container.add_child(oxygen_section)
	
	# Oxygen label
	var oxygen_label = Label.new()
	oxygen_label.name = "OxygenLabel"
	oxygen_label.text = "Oxygen: 100%"
	oxygen_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	oxygen_label.add_theme_font_size_override("font_size", 14)
	oxygen_section.add_child(oxygen_label)
	
	# Oxygen bar
	var oxygen_bar_bg = Panel.new()
	oxygen_bar_bg.custom_minimum_size = Vector2(200, 20)
	oxygen_bar_bg.modulate = Color(0.2, 0.2, 0.2)
	oxygen_section.add_child(oxygen_bar_bg)
	
	var oxygen_bar = ProgressBar.new()
	oxygen_bar.name = "OxygenBar"
	oxygen_bar.custom_minimum_size = Vector2(200, 20)
	oxygen_bar.max_value = 100
	oxygen_bar.value = 100
	oxygen_bar.modulate = Color(0.6, 0.9, 1.0)
	oxygen_bar.show_percentage = false
	oxygen_bar_bg.add_child(oxygen_bar)
	
	# Store oxygen references for OxygenDisplay to use
	if not oxygen_display:
		oxygen_display = OxygenDisplay.new()
	oxygen_display.oxygen_bar = oxygen_bar
	oxygen_display.oxygen_label = oxygen_label
	oxygen_display.setup_connections()
	
	# === RADIATION SECTION ===
	var radiation_section = VBoxContainer.new()
	radiation_section.name = "RadiationSection"
	radiation_section.add_theme_constant_override("separation", 2)
	env_container.add_child(radiation_section)
	
	# Radiation label
	radiation_label = Label.new()
	radiation_label.name = "RadiationLabel"
	radiation_label.text = "☢ Radiation: 0/100"
	radiation_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	radiation_label.add_theme_font_size_override("font_size", 14)
	radiation_section.add_child(radiation_label)
	
	# Radiation bar
	var rad_bar_bg = Panel.new()
	rad_bar_bg.custom_minimum_size = Vector2(200, 20)
	rad_bar_bg.modulate = Color(0.2, 0.2, 0.1)
	radiation_section.add_child(rad_bar_bg)
	
	radiation_bar = ProgressBar.new()
	radiation_bar.name = "RadiationBar"
	radiation_bar.custom_minimum_size = Vector2(200, 20)
	radiation_bar.max_value = 100
	radiation_bar.value = 0
	radiation_bar.modulate = Color(0.3, 1.0, 0.3)
	radiation_bar.show_percentage = false
	rad_bar_bg.add_child(radiation_bar)
	
	# Radiation status
	radiation_status_label = Label.new()
	radiation_status_label.name = "RadiationStatusLabel"
	radiation_status_label.text = "Safe"
	radiation_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	radiation_status_label.add_theme_font_size_override("font_size", 12)
	radiation_section.add_child(radiation_status_label)
	
	print("Environmental stats display created (Oxygen + Radiation)")

func create_radiation_display() -> void:
	var stats_panel = get_node_or_null("StatsPanel")
	if not stats_panel:
		print("Creating radiation display programmatically without StatsPanel")
		# Create a container for radiation display
		var rad_container = VBoxContainer.new()
		rad_container.name = "RadiationContainer"
		rad_container.position = Vector2(10, 280)  # Position below oxygen display (which is at 180)
		add_child(rad_container)
		
		# Create combined radiation label with icon
		radiation_label = Label.new()
		radiation_label.name = "RadiationLabel"
		radiation_label.text = "☢ Radiation: 0/100"
		radiation_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
		radiation_label.add_theme_font_size_override("font_size", 14)
		rad_container.add_child(radiation_label)
		
		# Create radiation bar with background
		var bar_bg = Panel.new()
		bar_bg.custom_minimum_size = Vector2(180, 16)  # Slightly smaller than oxygen
		bar_bg.modulate = Color(0.2, 0.2, 0.1)
		rad_container.add_child(bar_bg)
		
		radiation_bar = ProgressBar.new()
		radiation_bar.name = "RadiationBar"
		radiation_bar.custom_minimum_size = Vector2(180, 16)
		radiation_bar.max_value = 100
		radiation_bar.value = 0
		radiation_bar.modulate = Color(0.3, 1.0, 0.3)  # Start green
		radiation_bar.show_percentage = false
		bar_bg.add_child(radiation_bar)
		
		# Create compact status label
		radiation_status_label = Label.new()
		radiation_status_label.name = "RadiationStatusLabel"
		radiation_status_label.text = "Safe"
		radiation_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		radiation_status_label.add_theme_font_size_override("font_size", 12)
		rad_container.add_child(radiation_status_label)
		
		print("Radiation display created programmatically")
	else:
		# Try to create radiation display in StatsPanel
		if thirst_bar:
			# Create radiation bar by duplicating thirst bar
			radiation_bar = thirst_bar.duplicate()
			radiation_bar.name = "RadiationBar"
			radiation_bar.modulate = Color(0.8, 0.8, 0.2)  # Yellow-green color
			stats_panel.add_child(radiation_bar)
			
			# Position it below the thirst bar
			radiation_bar.position = thirst_bar.position + Vector2(0, 30)
			
			# Create radiation label
			radiation_label = Label.new()
			radiation_label.name = "RadiationLabel"
			radiation_label.text = "Radiation: 0/100"
			radiation_label.position = radiation_bar.position + Vector2(0, -20)
			stats_panel.add_child(radiation_label)
			
			# Create radiation status label
			radiation_status_label = Label.new()
			radiation_status_label.name = "RadiationStatusLabel"
			radiation_status_label.text = "Status: Safe"
			radiation_status_label.position = radiation_bar.position + Vector2(210, 0)
			radiation_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			stats_panel.add_child(radiation_status_label)
			
			print("Radiation display created in StatsPanel")
