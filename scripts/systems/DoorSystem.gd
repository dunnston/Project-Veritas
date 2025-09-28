extends Node

signal door_opened(position: Vector2)
signal door_closed(position: Vector2)

var door_states: Dictionary = {}  # Track door states by position
var door_tilemap: TileMapLayer = null
var interaction_areas: Array[Area2D] = []

# Door tile configuration - you may need to adjust these based on your tileset
# For now, we'll use a simple approach with source_id and atlas_coords
var door_tile_config = {
	"closed": {"source_id": 0, "atlas_coords": Vector2i(17, 1)},  # Adjust based on your tileset
	"open": {"source_id": 0, "atlas_coords": Vector2i(18, 1)}     # Adjust based on your tileset
}

const ANIMATION_SPEED = 0.15  # Time for door animation

func _ready():
	# Find the door tilemap layer
	call_deferred("setup_door_system")

func setup_door_system():
	var scene = get_tree().current_scene
	if not scene:
		print("DoorSystem: No current scene found")
		return
		
	# Find TileMap and Door layer
	var tilemap = scene.find_children("*", "TileMap", true, false)
	if tilemap.size() > 0:
		var door_layer = tilemap[0].find_children("Door", "TileMapLayer", false, false)
		if door_layer.size() > 0:
			door_tilemap = door_layer[0]
			print("DoorSystem: Found door tilemap layer")
			scan_for_doors()
		else:
			print("DoorSystem: No Door layer found")
	else:
		print("DoorSystem: No TileMap found")

func scan_for_doors():
	if not door_tilemap:
		return
		
	# Get all door positions from the tilemap
	var used_cells = door_tilemap.get_used_cells()
	print("DoorSystem: Found %d door cells" % used_cells.size())
	
	for cell_pos in used_cells:
		# Initialize door as closed
		door_states[cell_pos] = {
			"is_open": false,
			"is_animating": false,
			"collision_body": null
		}
		
		# Create collision body for this specific door
		create_door_collision(cell_pos)
		
		# Create interaction area for this door
		create_door_interaction_area(cell_pos)

func create_door_collision(cell_pos: Vector2i):
	# Create individual collision body for this door
	var collision_body = StaticBody2D.new()
	collision_body.name = "DoorCollision_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	
	# Position at the door's world position
	var world_pos = door_tilemap.to_global(door_tilemap.map_to_local(cell_pos))
	collision_body.global_position = world_pos
	
	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(32, 32)  # Standard tile size
	collision_shape.shape = shape
	collision_body.add_child(collision_shape)
	
	# Add to scene
	get_tree().current_scene.add_child(collision_body)
	
	# Store reference in door state
	door_states[cell_pos]["collision_body"] = collision_body

func create_door_interaction_area(cell_pos: Vector2i):
	var area = Area2D.new()
	area.name = "DoorInteraction_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	
	# Position the area at the door's world position
	var world_pos = door_tilemap.to_global(door_tilemap.map_to_local(cell_pos))
	area.global_position = world_pos
	
	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(48, 48)  # Slightly larger than tile for easier interaction
	collision.shape = shape
	area.add_child(collision)
	
	# Set up area properties
	area.collision_layer = 16  # Door interaction layer
	area.collision_mask = 2    # Player layer
	
	# Store reference to cell position
	area.set_meta("door_cell", cell_pos)
	
	# Connect signals
	area.body_entered.connect(_on_player_entered_door_area.bind(area))
	area.body_exited.connect(_on_player_exited_door_area.bind(area))
	
	# Add to scene
	get_tree().current_scene.add_child(area)
	interaction_areas.append(area)
	
	print("DoorSystem: Created interaction area for door at ", cell_pos)

func _on_player_entered_door_area(area: Area2D):
	var player = get_player_in_area(area)
	if player:
		# Show interaction prompt
		show_door_interaction_prompt(area, true)

func _on_player_exited_door_area(area: Area2D):
	# Hide interaction prompt
	show_door_interaction_prompt(area, false)

func get_player_in_area(area: Area2D) -> Node:
	var bodies = area.get_overlapping_bodies()
	for body in bodies:
		if body.name == "Player":
			return body
	return null

func show_door_interaction_prompt(area: Area2D, show: bool):
	# Find or create interaction prompt
	var prompt_name = "DoorPrompt_" + area.name
	var existing_prompt = get_tree().current_scene.find_children(prompt_name, "Label", true, false)
	
	if show and existing_prompt.size() == 0:
		# Create new prompt
		var prompt = Label.new()
		prompt.name = prompt_name
		prompt.text = "[E] Open/Close Door"
		prompt.add_theme_color_override("font_color", Color.WHITE)
		prompt.z_index = 100
		
		# Position above the door
		var world_pos = area.global_position
		prompt.global_position = world_pos + Vector2(-50, -40)
		
		get_tree().current_scene.add_child(prompt)
		
		# Store reference for cleanup
		area.set_meta("interaction_prompt", prompt)
		
	elif not show and existing_prompt.size() > 0:
		# Remove existing prompt
		for prompt in existing_prompt:
			prompt.queue_free()

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		check_door_interaction()

func check_door_interaction():
	# Find which door the player is near
	var player = get_tree().current_scene.find_children("Player", "", true, false)
	if player.size() == 0:
		return
		
	var player_node = player[0]
	
	# Check all door interaction areas
	for area in interaction_areas:
		if area.get_overlapping_bodies().has(player_node):
			var door_cell = area.get_meta("door_cell")
			toggle_door(door_cell)
			break

func toggle_door(cell_pos: Vector2i):
	if not door_states.has(cell_pos):
		print("DoorSystem: Door not found at position ", cell_pos)
		return
		
	var door_data = door_states[cell_pos]
	
	# Don't toggle if already animating
	if door_data.is_animating:
		return
		
	if door_data.is_open:
		close_door(cell_pos)
	else:
		open_door(cell_pos)

func open_door(cell_pos: Vector2i):
	var door_data = door_states[cell_pos]
	door_data.is_animating = true
	
	print("DoorSystem: Opening door at ", cell_pos)
	
	# Wait for animation time (you could add visual effects here)
	await get_tree().create_timer(ANIMATION_SPEED).timeout
	
	# Remove collision for this specific door
	var collision_body = door_data.collision_body
	if collision_body:
		collision_body.queue_free()
		door_data.collision_body = null
	
	door_data.is_animating = false
	door_data.is_open = true
	door_opened.emit(Vector2(cell_pos))

func close_door(cell_pos: Vector2i):
	var door_data = door_states[cell_pos]
	door_data.is_animating = true
	
	print("DoorSystem: Closing door at ", cell_pos)
	
	# Wait for animation time
	await get_tree().create_timer(ANIMATION_SPEED).timeout
	
	# Recreate collision for this specific door
	if not door_data.collision_body:
		create_door_collision(cell_pos)
	
	door_data.is_animating = false
	door_data.is_open = false
	door_closed.emit(Vector2(cell_pos))

func is_door_open(cell_pos: Vector2i) -> bool:
	if door_states.has(cell_pos):
		return door_states[cell_pos].is_open
	return false

func cleanup():
	# Clean up interaction areas
	for area in interaction_areas:
		if is_instance_valid(area):
			area.queue_free()
	interaction_areas.clear()
	door_states.clear()