extends Node
# Removed class_name to avoid conflict with autoload singleton

signal countdown_finished()
@warning_ignore("unused_signal")
signal oxygen_restored()

# Emergency state
var emergency_active: bool = false
var time_remaining_game_seconds: float = 259200.0  # 72 game hours in game seconds (72 * 60 * 60)
var countdown_timer: Timer
var flash_timer: Timer

# UI References
var countdown_label: Label
var emergency_overlay: ColorRect

# Emergency lighting effect
var flash_state: bool = false
const FLASH_INTERVAL: float = 0.5  # Flash every 0.5 seconds

# Requirements for restoring oxygen
var has_oxygen_tank: bool = false
var has_hand_crank_generator: bool = false

func _ready():
	print("EmergencySystem: Initializing...")
	add_to_group("emergency_system")
	setup_timers()
	create_emergency_ui()

func setup_timers():
	# Main countdown timer
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 1.0  # Update every second
	countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(countdown_timer)
	
	# Flash timer for emergency lighting
	flash_timer = Timer.new()
	flash_timer.wait_time = FLASH_INTERVAL
	flash_timer.timeout.connect(_on_flash_tick)
	add_child(flash_timer)

func create_emergency_ui():
	# Wait a frame to ensure scene is fully loaded
	await get_tree().process_frame
	
	# Find or create UI layer
	var scene = get_tree().current_scene
	var ui_layer = scene.get_node_or_null("UI")
	if not ui_layer:
		print("EmergencySystem: No UI layer found, creating one")
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UI"
		scene.add_child(ui_layer)
	
	# Create emergency overlay for red flashing
	emergency_overlay = ColorRect.new()
	emergency_overlay.name = "EmergencyOverlay"
	emergency_overlay.color = Color(1, 0, 0, 0.15)  # Semi-transparent red
	emergency_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	emergency_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emergency_overlay.visible = false
	emergency_overlay.z_index = 999  # Make sure it's on top
	ui_layer.add_child(emergency_overlay)
	
	# Create countdown display container
	var countdown_container = Control.new()
	countdown_container.name = "CountdownContainer"
	countdown_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(countdown_container)
	
	# Create countdown display
	countdown_label = Label.new()
	countdown_label.name = "EmergencyCountdown"
	countdown_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # Bright red
	countdown_label.add_theme_font_size_override("font_size", 20)  # Smaller font
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	countdown_label.position = Vector2(-300, 35)  # Center horizontally, position below day/time
	countdown_label.size = Vector2(600, 30)  # Reasonable width
	countdown_label.visible = false
	countdown_label.z_index = 1000  # Make sure it's visible
	countdown_container.add_child(countdown_label)
	
	print("EmergencySystem: UI created successfully")

func start_emergency():
	if emergency_active:
		print("EmergencySystem: Emergency already active, ignoring")
		return
		
	print("EmergencySystem: Starting emergency countdown!")
	emergency_active = true
	
	# Start timers
	countdown_timer.start()
	flash_timer.start()
	print("EmergencySystem: Timers started")
	
	# Show UI elements
	if countdown_label:
		countdown_label.visible = true
		print("EmergencySystem: Countdown label made visible")
	else:
		print("EmergencySystem: WARNING - countdown_label is null!")
		
	if emergency_overlay:
		emergency_overlay.visible = true
		print("EmergencySystem: Emergency overlay made visible")
	else:
		print("EmergencySystem: WARNING - emergency_overlay is null!")
	
	# Update initial display
	update_countdown_display()
	print("EmergencySystem: Emergency started successfully")

func _on_countdown_tick():
	if not emergency_active:
		return
		
	# Convert 1 real second to game seconds (48 game seconds per real second)
	if GameTimeManager:
		time_remaining_game_seconds -= GameTimeManager.real_to_game_seconds(1.0)
	else:
		time_remaining_game_seconds -= 48.0  # Fallback if GameTimeManager not available
	
	if time_remaining_game_seconds <= 0:
		game_over()
	else:
		update_countdown_display()

func _on_flash_tick():
	if not emergency_active:
		return
		
	flash_state = not flash_state
	
	if emergency_overlay:
		emergency_overlay.modulate.a = 0.15 if flash_state else 0.05

func update_countdown_display():
	if not countdown_label:
		return
		
	# Display game time remaining
	var game_days = int(time_remaining_game_seconds / 86400.0)
	var game_hours = int((time_remaining_game_seconds / 3600.0)) % 24
	var game_minutes = int((time_remaining_game_seconds / 60.0)) % 60
	
	if game_days > 0:
		countdown_label.text = "EMERGENCY: Oxygen systems will shut down in %d days, %d hours" % [game_days, game_hours]
	else:
		countdown_label.text = "EMERGENCY: Oxygen systems will shut down in %02d:%02d" % [game_hours, game_minutes]

func check_oxygen_restoration():
	# This function is now handled by the OxygenSystem
	# The emergency countdown continues regardless of what the player builds
	# The player must survive using their built systems after countdown ends
	pass

func set_oxygen_tank_built(built: bool):
	has_oxygen_tank = built
	print("EmergencySystem: Oxygen tank built = ", built)
	# No longer auto-restores oxygen - player must survive the countdown

func set_hand_crank_generator_built(built: bool):
	has_hand_crank_generator = built
	print("EmergencySystem: Hand crank generator built = ", built)
	# No longer auto-restores oxygen - player must survive the countdown

# Legacy function - no longer used but kept for compatibility
func restore_oxygen():
	print("EmergencySystem: restore_oxygen called but no longer auto-restores")

# Legacy function - no longer used but kept for compatibility  
func show_success_message():
	print("EmergencySystem: show_success_message called but countdown doesn't auto-end anymore")

func game_over():
	print("EmergencySystem: Countdown finished - Backup oxygen systems shutting down")
	emergency_active = false
	
	# Stop timers
	countdown_timer.stop()
	flash_timer.stop()
	
	# Turn off backup oxygen - player now relies on their own systems
	if OxygenSystem:
		OxygenSystem.end_backup_oxygen()
	
	# Show transition message instead of game over
	var dialog = AcceptDialog.new()
	dialog.title = "Backup Systems Offline"
	dialog.dialog_text = """BACKUP OXYGEN SYSTEMS SHUTTING DOWN

The 72-game-hour emergency power has been depleted.

Life support systems are now offline.

You must rely on your own oxygen generation systems to survive.

If you built and powered an oxygen tank, stay within range to survive!"""
	dialog.size = Vector2(500, 350)
	
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func(): dialog.queue_free())
	
	countdown_finished.emit()

func get_time_remaining_formatted() -> String:
	var game_days = int(time_remaining_game_seconds / 86400.0)
	var game_hours = int((time_remaining_game_seconds / 3600.0)) % 24
	var game_minutes = int((time_remaining_game_seconds / 60.0)) % 60
	
	if game_days > 0:
		return "%d days, %d hours" % [game_days, game_hours]
	else:
		return "%02d:%02d" % [game_hours, game_minutes]

func add_emergency_time(additional_game_seconds: float):
	if not emergency_active:
		return
		
	time_remaining_game_seconds += additional_game_seconds
	print("EmergencySystem: Added ", additional_game_seconds, " game seconds. New total: ", get_time_remaining_formatted())
	update_countdown_display()
	
	# Show system message
	show_time_added_message(additional_game_seconds)

func show_time_added_message(game_seconds_added: float):
	var game_hours = int(game_seconds_added / 3600.0)
	var dialog = AcceptDialog.new()
	dialog.title = "Emergency Power Extended"
	dialog.dialog_text = """HAND CRANK GENERATOR ACTIVATED

Emergency power extended by %d game hour(s).

Life support systems stabilized.

Current remaining time: %s""" % [game_hours, get_time_remaining_formatted()]
	dialog.size = Vector2(400, 300)
	
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func(): dialog.queue_free())
