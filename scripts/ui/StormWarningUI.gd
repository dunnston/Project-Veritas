extends Control

class_name StormWarningUI

var warning_panel: Panel
var warning_icon: TextureRect
var warning_title: Label
var warning_message: Label
var countdown_label: Label
var shelter_status_label: Label
var storm_type_icon: TextureRect

var warning_timer: Timer
var flash_timer: Timer
var is_flashing: bool = false

func _ready() -> void:
	print("StormWarningUI: Initializing storm warning display...")
	create_warning_ui()
	setup_connections()

func setup_connections() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		if not storm_system.storm_warning_issued.is_connected(_on_storm_warning_issued):
			storm_system.storm_warning_issued.connect(_on_storm_warning_issued)
		if not storm_system.storm_phase_changed.is_connected(_on_storm_phase_changed):
			storm_system.storm_phase_changed.connect(_on_storm_phase_changed)
		if not storm_system.storm_shelter_status_changed.is_connected(_on_shelter_status_changed):
			storm_system.storm_shelter_status_changed.connect(_on_shelter_status_changed)

func create_warning_ui() -> void:
	# Main warning panel (initially hidden)
	warning_panel = Panel.new()
	warning_panel.name = "StormWarningPanel"
	warning_panel.visible = false
	warning_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	warning_panel.offset_top = 10.0
	warning_panel.offset_bottom = 120.0
	warning_panel.offset_left = 10.0
	warning_panel.offset_right = -10.0
	add_child(warning_panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.8, 0.3, 0.2, 0.9)  # Red warning background
	panel_style.border_color = Color(1.0, 0.5, 0.3, 1.0)
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	warning_panel.add_theme_stylebox_override("panel", panel_style)
	
	# Content container
	var content_container = HBoxContainer.new()
	content_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	content_container.offset_left = 15.0
	content_container.offset_right = -15.0
	content_container.offset_top = 10.0
	content_container.offset_bottom = -10.0
	content_container.add_theme_constant_override("separation", 15)
	warning_panel.add_child(content_container)
	
	# Warning icon
	warning_icon = TextureRect.new()
	warning_icon.custom_minimum_size = Vector2(64, 64)
	warning_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	warning_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content_container.add_child(warning_icon)
	
	# Text content
	var text_container = VBoxContainer.new()
	text_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_child(text_container)
	
	# Warning title
	warning_title = Label.new()
	warning_title.text = "STORM WARNING"
	warning_title.add_theme_font_size_override("font_size", 24)
	warning_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8, 1.0))
	text_container.add_child(warning_title)
	
	# Warning message
	warning_message = Label.new()
	warning_message.text = "Storm detected on horizon"
	warning_message.add_theme_font_size_override("font_size", 16)
	warning_message.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	warning_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_container.add_child(warning_message)
	
	# Right side info
	var info_container = VBoxContainer.new()
	info_container.custom_minimum_size = Vector2(200, 0)
	content_container.add_child(info_container)
	
	# Countdown
	countdown_label = Label.new()
	countdown_label.text = "Time: 5:00"
	countdown_label.add_theme_font_size_override("font_size", 20)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_container.add_child(countdown_label)
	
	# Shelter status
	shelter_status_label = Label.new()
	shelter_status_label.text = "Status: EXPOSED"
	shelter_status_label.add_theme_font_size_override("font_size", 14)
	shelter_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
	shelter_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_container.add_child(shelter_status_label)
	
	# Warning auto-hide timer
	warning_timer = Timer.new()
	warning_timer.wait_time = 10.0
	warning_timer.one_shot = true
	warning_timer.timeout.connect(_hide_warning)
	add_child(warning_timer)
	
	# Flash timer for urgent warnings
	flash_timer = Timer.new()
	flash_timer.wait_time = 0.5
	flash_timer.timeout.connect(_flash_warning)
	add_child(flash_timer)

func _process(delta: float) -> void:
	if warning_panel.visible:
		update_countdown_display()

func update_countdown_display() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if not storm_system:
		return
		
	var time_remaining: float = 0.0
	
	if storm_system.is_storm_active():
		time_remaining = storm_system.get_storm_duration_remaining()
		countdown_label.text = "Duration: %s" % format_time(time_remaining)
	else:
		time_remaining = storm_system.get_time_until_next_storm()
		if time_remaining > 0 and time_remaining <= 300.0:  # Only show if within warning period
			countdown_label.text = "Time: %s" % format_time(time_remaining)
		else:
			countdown_label.text = ""

func format_time(seconds: float) -> String:
	var minutes = int(seconds / 60)
	var remaining_seconds = int(seconds) % 60
	return "%d:%02d" % [minutes, remaining_seconds]

func _on_storm_warning_issued(warning_type: int, time_remaining: float, storm_type: int) -> void:
	show_warning(warning_type, time_remaining, storm_type)

func _on_storm_phase_changed(phase: int) -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if not storm_system:
		return
		
	# Use enum values directly from the system
	if phase == storm_system.StormPhase.CALM:
		hide_warning()
	elif phase == storm_system.StormPhase.STORM_ACTIVE:
		show_active_storm()

func _on_shelter_status_changed(is_sheltered: bool) -> void:
	update_shelter_status_display(is_sheltered)

func show_warning(warning_type: int, time_remaining: float, storm_type: int) -> void:
	warning_panel.visible = true
	stop_flashing()  # Reset any previous flashing
	
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		if warning_type == storm_system.WarningType.EARLY_WARNING:
			show_early_warning(storm_type, time_remaining)
		elif warning_type == storm_system.WarningType.INCOMING_WARNING:
			show_incoming_warning(storm_type, time_remaining)
		elif warning_type == storm_system.WarningType.IMMEDIATE_WARNING:
			show_immediate_warning(storm_type, time_remaining)
	
		# Auto-hide timer (except for immediate warnings)
		if warning_type != storm_system.WarningType.IMMEDIATE_WARNING:
			warning_timer.start()

func show_early_warning(storm_type: int, time_remaining: float) -> void:
	warning_title.text = "STORM DETECTED"
	warning_message.text = "%s approaching in %.1f minutes\n%s" % [
		get_storm_name(storm_type),
		time_remaining / 60.0,
		get_storm_description(storm_type)
	]
	
	# Mild warning colors
	var panel_style = warning_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		panel_style.bg_color = Color(0.8, 0.6, 0.2, 0.85)  # Yellow warning

func show_incoming_warning(storm_type: int, time_remaining: float) -> void:
	warning_title.text = "STORM INCOMING"
	warning_message.text = "%s approaching fast! %.1f minutes remaining\n%s\nSeek shelter immediately!" % [
		get_storm_name(storm_type),
		time_remaining / 60.0,
		get_storm_description(storm_type)
	]
	
	# Orange warning colors
	var panel_style = warning_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		panel_style.bg_color = Color(0.9, 0.4, 0.2, 0.9)  # Orange warning

func show_immediate_warning(storm_type: int, time_remaining: float) -> void:
	warning_title.text = "⚠ STORM IMMINENT ⚠"
	warning_message.text = "%s starting in %.0f seconds!\n%s\nTAKE COVER NOW!" % [
		get_storm_name(storm_type),
		time_remaining,
		get_storm_description(storm_type)
	]
	
	# Critical red warning colors
	var panel_style = warning_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		panel_style.bg_color = Color(0.9, 0.2, 0.2, 0.95)  # Red critical warning
	
	# Start flashing for urgency
	start_flashing()

func show_active_storm() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if not storm_system:
		return
		
	warning_title.text = "STORM ACTIVE"
	var storm_type = storm_system.get_current_storm_type()
	warning_message.text = "%s in progress!\n%s\nStay in shelter until storm passes." % [
		get_storm_name(storm_type),
		get_storm_description(storm_type)
	]
	
	# Dark storm colors
	var panel_style = warning_panel.get_theme_stylebox("panel")
	if panel_style is StyleBoxFlat:
		panel_style.bg_color = Color(0.3, 0.3, 0.4, 0.95)  # Dark storm background
	
	warning_panel.visible = true
	stop_flashing()

func update_shelter_status_display(is_sheltered: bool) -> void:
	if is_sheltered:
		shelter_status_label.text = "Status: SHELTERED"
		shelter_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))  # Green
	else:
		shelter_status_label.text = "Status: EXPOSED"
		shelter_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))  # Red

func hide_warning() -> void:
	warning_panel.visible = false
	stop_flashing()

func _hide_warning() -> void:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system and storm_system.get_current_storm_phase() == storm_system.StormPhase.IMMEDIATE_WARNING:
		return  # Don't auto-hide immediate warnings
	hide_warning()

func start_flashing() -> void:
	if is_flashing:
		return
	is_flashing = true
	flash_timer.start()

func stop_flashing() -> void:
	if not is_flashing:
		return
	is_flashing = false
	flash_timer.stop()
	warning_panel.modulate.a = 1.0  # Ensure panel is visible

func _flash_warning() -> void:
	if not is_flashing:
		return
	warning_panel.modulate.a = 1.0 if warning_panel.modulate.a < 1.0 else 0.7

func get_storm_name(storm_type: int) -> String:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		return storm_system.get_storm_name(storm_type)
	return "Storm"

func get_storm_description(storm_type: int) -> String:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		return storm_system.get_storm_description(storm_type)
	return "Dangerous weather conditions"
