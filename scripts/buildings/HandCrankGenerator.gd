extends Area2D
class_name HandCrankGeneratorBuilding

var player_in_range: bool = false
var player_ref: Node2D = null
var interaction_prompt: Label = null

# Generator state
var is_running: bool = false
var remaining_game_time: float = 0.0  # in game seconds
var max_run_game_time: float = 4.0 * 3600.0  # 4 game hours in game seconds

# Visual indicators
var running_indicator: Node2D = null
var status_light: ColorRect = null

@warning_ignore("unused_signal")
signal generator_interacted(generator: HandCrankGeneratorBuilding)
signal generator_cranked()
signal generator_stopped()

func _ready():
	# Connect area signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Connected body_entered signal")
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		print("Connected body_exited signal")
	
	# Create interaction prompt
	create_interaction_prompt()
	
	# Create visual indicators
	create_visual_indicators()
	
	# Register with PowerSystem
	if PowerSystem:
		PowerSystem.register_generator(self)
	
	# Debug: Check collision settings
	print("Hand Crank Generator ready:")
	print("  Collision layer: ", collision_layer, " (binary: ", String.num(collision_layer, 2), ")")
	print("  Collision mask: ", collision_mask, " (binary: ", String.num(collision_mask, 2), ")")
	print("  Monitoring: ", monitoring)
	print("  Monitorable: ", monitorable)
	print("  Position: ", global_position)
	
	# Ensure monitoring is enabled
	monitoring = true
	monitorable = true
	
	# Test if we can find any players in the scene
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	print("Found ", players.size(), " players in scene:")
	for player in players:
		print("  Player: ", player.name, " at ", player.global_position, " layer: ", player.collision_layer)

func _process(delta: float):
	if is_running and remaining_game_time > 0:
		# Convert real delta to game time delta
		if GameTimeManager:
			remaining_game_time -= GameTimeManager.real_to_game_seconds(delta)
		else:
			remaining_game_time -= delta * 48.0  # Fallback: 1 real second = 48 game seconds
		
		if remaining_game_time <= 0:
			stop_generator()
		
		# Update visual indicator (animate running state)
		if running_indicator:
			running_indicator.rotation += delta * 2.0  # Rotate to show it's running

func create_interaction_prompt():
	# Create a simple text prompt
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press E to use generator"
	interaction_prompt.position = Vector2(-60, -80)  # Above the generator
	interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 1)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 1)
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func create_visual_indicators():
	# Create a small rotating indicator to show when running
	running_indicator = Node2D.new()
	running_indicator.name = "RunningIndicator"
	
	var indicator_sprite = ColorRect.new()
	indicator_sprite.color = Color.GREEN
	indicator_sprite.size = Vector2(4, 16)
	indicator_sprite.position = Vector2(-2, -8)
	running_indicator.add_child(indicator_sprite)
	
	running_indicator.position = Vector2(0, -30)  # Above the generator
	running_indicator.visible = false
	add_child(running_indicator)
	
	# Create status light
	status_light = ColorRect.new()
	status_light.size = Vector2(6, 6)
	status_light.position = Vector2(-3, -40)
	status_light.color = Color.RED  # Red when not running
	add_child(status_light)

func _input(event: InputEvent):
	if player_in_range and event.is_action_pressed("interact"):
		interact_with_generator()

func _on_body_entered(body: Node2D):
	print("Body entered generator area: ", body.name)
	print("Body groups: ", body.get_groups())
	if body.is_in_group("player"):
		print("Player detected in range!")
		player_in_range = true
		player_ref = body
		show_interaction_prompt()
	else:
		print("Body is not in player group")

func _on_body_exited(body: Node2D):
	print("Body exited generator area: ", body.name)
	if body.is_in_group("player"):
		print("Player left range")
		player_in_range = false
		player_ref = null
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func interact_with_generator():
	print("Player interacted with generator!")
	
	# Find the generator menu in the scene
	var generator_menu = get_tree().current_scene.get_node_or_null("UI/GeneratorMenu")
	if generator_menu:
		generator_menu.open_generator_menu(self)
		print("Generator menu opened")
	else:
		print("GeneratorMenu not found in scene!")
		# Try to find it in the UI layer
		var ui_layer = get_tree().current_scene.get_node_or_null("UI")
		if ui_layer:
			for child in ui_layer.get_children():
				if child.has_method("open_generator_menu"):
					child.open_generator_menu(self)
					print("Found and opened generator menu")
					return
		print("Could not find GeneratorMenu anywhere!")

func crank_generator():
	if is_running:
		print("Generator is already running!")
		return false
	
	is_running = true
	remaining_game_time = max_run_game_time
	
	# Update visual indicators
	if running_indicator:
		running_indicator.visible = true
	if status_light:
		status_light.color = Color.GREEN
	
	generator_cranked.emit()
	print("Generator cranked! Running for 4 game hours.")
	return true

func stop_generator():
	if not is_running:
		return
	
	is_running = false
	remaining_game_time = 0.0
	
	# Update visual indicators
	if running_indicator:
		running_indicator.visible = false
		running_indicator.rotation = 0.0
	if status_light:
		status_light.color = Color.RED
	
	generator_stopped.emit()
	print("Generator stopped.")

func get_remaining_hours() -> float:
	return remaining_game_time / 3600.0

func get_remaining_time_text() -> String:
	if not is_running:
		return "Not running"
	
	var hours = int(remaining_game_time / 3600.0)
	var minutes = int(fmod(remaining_game_time, 3600.0) / 60.0)
	return "%d game hours %d minutes" % [hours, minutes]

func move_generator():
	print("Moving generator...")
	# Return materials to inventory
	if InventorySystem:
		InventorySystem.add_item("COPPER_WIRE", 3)
		InventorySystem.add_item("MAGNETS", 2)
		InventorySystem.add_item("METAL_ROD", 2)
		InventorySystem.add_item("GEAR_ASSEMBLY", 1)
	
	# Remove current generator
	queue_free()
	# Start building mode for replacement
	if BuildingSystem:
		BuildingSystem.start_building_mode("hand_crank_generator")

func destroy_generator():
	print("Destroying generator...")
	
	# Return materials to inventory
	if InventorySystem:
		InventorySystem.add_item("COPPER_WIRE", 3)
		InventorySystem.add_item("MAGNETS", 2)
		InventorySystem.add_item("METAL_ROD", 2)
		InventorySystem.add_item("GEAR_ASSEMBLY", 1)
	
	# Remove the generator
	queue_free()

func _exit_tree():
	# Unregister from PowerSystem when destroyed
	if PowerSystem:
		PowerSystem.unregister_generator(self)

func is_generator_running() -> bool:
	return is_running
