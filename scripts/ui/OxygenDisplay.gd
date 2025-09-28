extends Control
class_name OxygenDisplay

var oxygen_bar: ProgressBar
var oxygen_label: Label
var warning_label: Label
var warning_timer: Timer
var flash_timer: Timer
var is_flashing: bool = false

func _ready():
	print("OxygenDisplay: Initializing...")
	
	# If bars aren't set externally, create our own UI
	if not oxygen_bar:
		create_oxygen_ui()
	
	setup_connections()

func setup_connections():
	# Connect to OxygenSystem signals
	if OxygenSystem:
		if not OxygenSystem.oxygen_level_changed.is_connected(_on_oxygen_level_changed):
			OxygenSystem.oxygen_level_changed.connect(_on_oxygen_level_changed)
		if not OxygenSystem.oxygen_state_changed.is_connected(_on_oxygen_state_changed):
			OxygenSystem.oxygen_state_changed.connect(_on_oxygen_state_changed)
		if not OxygenSystem.suffocation_started.is_connected(_on_suffocation_started):
			OxygenSystem.suffocation_started.connect(_on_suffocation_started)
		if not OxygenSystem.suffocation_ended.is_connected(_on_suffocation_ended):
			OxygenSystem.suffocation_ended.connect(_on_suffocation_ended)
	
	# Connect to player for warnings
	if GameManager.player_node:
		if GameManager.player_node.has_signal("warning_message"):
			if not GameManager.player_node.warning_message.is_connected(_on_warning_message):
				GameManager.player_node.warning_message.connect(_on_warning_message)

func create_oxygen_ui():
	# Main container
	var container = VBoxContainer.new()
	container.name = "OxygenContainer"
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.position = Vector2(10, 180)
	container.add_theme_constant_override("separation", 5)
	add_child(container)
	
	# Oxygen label
	oxygen_label = Label.new()
	oxygen_label.text = "Oxygen: 100%"
	oxygen_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	oxygen_label.add_theme_font_size_override("font_size", 14)
	container.add_child(oxygen_label)
	
	# Oxygen bar background
	var bar_bg = Panel.new()
	bar_bg.custom_minimum_size = Vector2(200, 20)
	bar_bg.modulate = Color(0.2, 0.2, 0.2)
	container.add_child(bar_bg)
	
	# Oxygen progress bar
	oxygen_bar = ProgressBar.new()
	oxygen_bar.custom_minimum_size = Vector2(200, 20)
	oxygen_bar.value = 100.0
	oxygen_bar.show_percentage = false
	
	# Style the oxygen bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.3, 0.8, 1.0)
	bar_style.corner_radius_top_left = 2
	bar_style.corner_radius_top_right = 2
	bar_style.corner_radius_bottom_left = 2
	bar_style.corner_radius_bottom_right = 2
	oxygen_bar.add_theme_stylebox_override("fill", bar_style)
	
	bar_bg.add_child(oxygen_bar)
	
	# Warning label (hidden by default)
	warning_label = Label.new()
	warning_label.text = ""
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	warning_label.add_theme_font_size_override("font_size", 16)
	warning_label.visible = false
	container.add_child(warning_label)
	
	# Warning timer for auto-hide
	warning_timer = Timer.new()
	warning_timer.wait_time = 5.0
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_hide_warning)
	add_child(warning_timer)
	
	# Flash timer for critical oxygen
	flash_timer = Timer.new()
	flash_timer.wait_time = 0.5
	flash_timer.timeout.connect(_flash_oxygen_bar)
	add_child(flash_timer)

func _on_oxygen_level_changed(level: float, max_level: float):
	if not oxygen_bar or not oxygen_label:
		return
	
	var percentage = (level / max_level) * 100.0
	oxygen_bar.value = percentage
	
	# Show backup status if active
	var backup_text = ""
	if OxygenSystem and OxygenSystem.is_backup_active():
		backup_text = " (BACKUP)"
	elif OxygenSystem and OxygenSystem.is_emergency_active():
		backup_text = " (EMERGENCY MODE)"
	
	oxygen_label.text = "Oxygen: %.0f%%%s" % [percentage, backup_text]
	
	# Update bar color based on oxygen level
	var bar_style = oxygen_bar.get_theme_stylebox("fill")
	if bar_style and bar_style is StyleBoxFlat:
		if percentage > 50:
			bar_style.bg_color = Color(0.3, 0.8, 1.0)  # Light blue
			stop_flashing()
		elif percentage > 25:
			bar_style.bg_color = Color(1.0, 0.8, 0.3)  # Yellow
			stop_flashing()
		else:
			bar_style.bg_color = Color(1.0, 0.3, 0.3)  # Red
			start_flashing()

func _on_oxygen_state_changed(has_oxygen: bool):
	if has_oxygen:
		show_warning("Oxygen supply restored", Color(0.3, 1.0, 0.3))
	else:
		show_warning("WARNING: No oxygen supply!", Color(1.0, 0.3, 0.3))

func _on_suffocation_started():
	show_warning("CRITICAL: SUFFOCATING!", Color(1.0, 0.2, 0.2))
	start_flashing()

func _on_suffocation_ended():
	show_warning("Breathing normally", Color(0.3, 1.0, 0.3))
	stop_flashing()

func _on_warning_message(message: String):
	if "oxygen" in message.to_lower() or "suffocating" in message.to_lower():
		show_warning(message, Color(1.0, 0.3, 0.3))

func show_warning(text: String, color: Color = Color(1.0, 0.3, 0.3)):
	if not warning_label:
		return
	
	warning_label.text = text
	warning_label.add_theme_color_override("font_color", color)
	warning_label.visible = true
	
	# Auto-hide after 5 seconds
	warning_timer.stop()
	warning_timer.start()

func _hide_warning():
	if warning_label:
		warning_label.visible = false

func start_flashing():
	if is_flashing:
		return
	
	is_flashing = true
	flash_timer.start()

func stop_flashing():
	if not is_flashing:
		return
	
	is_flashing = false
	flash_timer.stop()
	
	# Reset bar visibility
	if oxygen_bar:
		oxygen_bar.modulate.a = 1.0

func _flash_oxygen_bar():
	if not oxygen_bar:
		return
	
	# Toggle visibility for flashing effect
	oxygen_bar.modulate.a = 1.0 if oxygen_bar.modulate.a < 1.0 else 0.5
