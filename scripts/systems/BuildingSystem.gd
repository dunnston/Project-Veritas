extends Node

signal building_placed(building_id: String, position: Vector3)
signal building_cancelled()
signal building_demolished(building_id: String, position: Vector3)

var is_building_mode: bool = false
var is_demolition_mode: bool = false
var current_building_id: String = ""
var building_preview: BuildingPreview3D = null
var building_rotation: int = 0  # 0, 90, 180, 270 degrees
var current_building_cost: Dictionary = {}
var building_to_move: Node3D = null  # Reference to building being moved
var demolition_mode_label: Label = null  # UI indicator for demolition mode

# 3D Building data
var building_data: Dictionary = {
	"workbench": {
		"name": "Workbench",
		"scene_path": "res://scenes/buildings/workbench_3d.tscn",
		"size": Vector3(2, 1, 1),
		"collision_shape": Vector3(2, 1, 1),
		"icon_path": "res://assets/sprites/buildings/pixellab-A-sci-fi-workbench-with-a-meta-1756949376631.png"
	},
	"oxygen_tank": {
		"name": "Oxygen Tank",
		"size": Vector3(1, 1, 1),
		"collision_shape": Vector3(1, 1, 1),
		"icon_path": "res://assets/sprites/items/oxygentank.png"
	},
	"hand_crank_generator": {
		"name": "Hand Crank Generator",
		"size": Vector3(1.5, 1, 1),
		"collision_shape": Vector3(1.5, 1, 1),
		"icon_path": "res://assets/sprites/items/generator2.png"
	},
	"storage_box": {
		"name": "Storage Box",
		"size": Vector3(1, 1, 1),
		"collision_shape": Vector3(1, 1, 1),
		"icon_path": "res://assets/sprites/items/Chest.png"
	},
	# Shelter Building Components (3D) - 4m grid system
	"basic_wall": {
		"name": "Basic Wall",
		"size": Vector3(4, 3, 0.2),  # 4m wide, 3m tall, 20cm thick
		"collision_shape": Vector3(4, 3, 0.2),
		"icon_path": ""
	},
	"basic_floor": {
		"name": "Basic Floor",
		"size": Vector3(4, 0.1, 4),  # 4m x 4m floor tile
		"collision_shape": Vector3(4, 0.1, 4),
		"icon_path": ""
	},
	"basic_roof": {
		"name": "Basic Roof",
		"size": Vector3(4, 0.1, 4),  # 4m x 4m roof tile
		"collision_shape": Vector3(4, 0.1, 4),
		"icon_path": ""
	},
	"door_frame": {
		"name": "Door Frame",
		"size": Vector3(4, 3, 0.2),  # Same as wall - 4m wide, 3m tall, 20cm thick
		"collision_shape": Vector3(4, 3, 0.2),
		"icon_path": ""
	},
	"door_frame_with_door": {
		"name": "Door Frame with Door",
		"size": Vector3(4, 3, 0.2),  # Same as wall - 4m wide, 3m tall, 20cm thick
		"collision_shape": Vector3(4, 3, 0.2),
		"icon_path": ""
	},
	"door": {
		"name": "Door",
		"size": Vector3(1.15, 2.35, 0.1),  # Slightly smaller to fit in frame (1.15m wide x 2.35m tall x 0.1m thick)
		"collision_shape": Vector3(1.15, 2.35, 0.1),
		"icon_path": ""
	},
	"reinforced_wall": {
		"name": "Reinforced Wall",
		"size": Vector3(1, 3, 0.3),
		"collision_shape": Vector3(1, 3, 0.3),
		"icon_path": ""
	},
	"reinforced_roof": {
		"name": "Reinforced Roof",
		"size": Vector3(1, 0.2, 1),
		"collision_shape": Vector3(1, 0.2, 1),
		"icon_path": ""
	}
}

var camera: Camera3D = null
var raycast_layer_mask: int = 0x1  # Layer 1 - Ground/World collision layer
var placed_buildings: Dictionary = {}

# Door functionality for 3D doors
var door_states: Dictionary = {}
var player_nearby_door: Area3D = null

func _ready():
	# Connect to build menu
	call_deferred("_connect_to_build_menu")

	# Find camera
	call_deferred("_find_camera")

	print("3D BuildingSystem initialized")

func _find_camera():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var cameras = player.find_children("*", "Camera3D", true, false)
		if cameras.size() > 0:
			camera = cameras[0]

func _connect_to_build_menu():
	if BuildMenu.instance:
		# Connect our system
		if not BuildMenu.instance.item_to_build_selected.is_connected(_on_item_to_build_selected):
			BuildMenu.instance.item_to_build_selected.connect(_on_item_to_build_selected)
			print("3D BuildingSystem connected to BuildMenu")

func _input(event: InputEvent):
	# Debug: Add resources with L key
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		add_debug_resources()
		get_viewport().set_input_as_handled()
		return

	# Demolition mode toggle with X key
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		toggle_demolition_mode()
		get_viewport().set_input_as_handled()
		return

	# Handle demolition mode
	if is_demolition_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				demolish_building_at_mouse()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				exit_demolition_mode()
				get_viewport().set_input_as_handled()
		return

	# Handle door interactions when not in building mode
	if not is_building_mode:
		handle_door_input(event)
		return

	# Only handle building placement when in building mode
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			attempt_place_building()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rotate_building()
			get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_C:
			cancel_building()
			get_viewport().set_input_as_handled()

func _process(_delta):
	if is_building_mode and building_preview and camera:
		update_preview_position()

func _on_item_to_build_selected(item_id: String):
	print("BuildingSystem received item_to_build_selected: ", item_id)
	start_building_mode(item_id)

func start_building_mode(building_id: String):
	if not building_data.has(building_id):
		print("Unknown 3D building: %s" % building_id)
		return

	is_building_mode = true
	current_building_id = building_id
	building_rotation = 0
	current_building_cost = get_building_recipe_cost(building_id)
	building_to_move = null  # Not a move operation

	# Set mouse to visible for building placement
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	create_building_preview()
	print("Started 3D building mode for: %s" % building_id)

func start_building_mode_for_move(building_id: String, building_to_move_ref: Node3D):
	if not building_data.has(building_id):
		print("Unknown 3D building: %s" % building_id)
		return

	is_building_mode = true
	current_building_id = building_id
	building_rotation = 0
	current_building_cost = {}  # No cost for moving
	building_to_move = building_to_move_ref  # Store reference to building being moved

	# Set mouse to visible for building placement
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	create_building_preview()
	print("Started 3D building MOVE mode for: %s" % building_id)

func create_building_preview():
	if building_preview:
		building_preview.queue_free()

	# Create 3D preview using our BuildingPreview3D class
	var preview_scene = preload("res://scripts/buildings/BuildingPreview3D.gd")
	building_preview = preview_scene.new()
	building_preview.name = "BuildingPreview3D"

	# Create mesh for preview
	var building_info = building_data[current_building_id]
	var size = building_info.get("size", Vector3(1, 1, 1))

	# Special case: Door frame (with or without door) needs CSG preview
	if current_building_id == "door_frame" or current_building_id == "door_frame_with_door":
		# Create CSG-based preview with door cutout
		var csg_wall = CSGBox3D.new()
		csg_wall.size = size
		csg_wall.name = "CSGBox3D"  # Named so preview can find it
		print("DEBUG: Creating %s preview with size: %s" % [current_building_id, size])

		var csg_cutout = CSGBox3D.new()
		csg_cutout.size = Vector3(1.2, 2.4, 0.3)
		csg_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
		csg_cutout.position = Vector3(0, -0.3, 0)
		csg_wall.add_child(csg_cutout)

		# If this is door_frame_with_door, add the door to preview
		if current_building_id == "door_frame_with_door":
			var door_mesh = CSGBox3D.new()
			door_mesh.size = Vector3(1.15, 2.35, 0.05)
			door_mesh.position = Vector3(0, -0.325, 0)
			csg_wall.add_child(door_mesh)

		building_preview.add_child(csg_wall)
		building_preview.setup_preview(current_building_id, null)  # No mesh, using CSG
	else:
		# Standard box mesh preview
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		building_preview.setup_preview(current_building_id, box_mesh)

	# Add to scene
	get_tree().current_scene.add_child(building_preview)
	print("Created 3D building preview")

func update_preview_position():
	if not camera:
		_find_camera()
		if not camera:
			return

	# Raycast from camera to ground
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	# Create raycast
	var space_state = get_world_3d().direct_space_state

	# Exclude list for raycast
	var exclude_list = []
	var player = get_tree().get_first_node_in_group("player")
	if player:
		exclude_list.append(player.get_rid())

	# Exclude the preview if it has collision
	if building_preview and building_preview.has_method("get_rid"):
		exclude_list.append(building_preview.get_rid())

	# SPECIAL CASE: When placing walls or door frames, exclude roofs from raycast
	# This ensures the wall/door_frame snaps to the floor, not the roof above it
	if current_building_id.contains("wall") or current_building_id.contains("door_frame"):
		var buildings = get_tree().get_nodes_in_group("building")
		for building in buildings:
			if building.name.contains("roof"):
				exclude_list.append(building.get_rid())

	# SPECIAL CASE: When placing doors, exclude door_frames from raycast
	# This ensures the door snaps to the floor through the frame opening
	if current_building_id == "door":
		var buildings = get_tree().get_nodes_in_group("building")
		for building in buildings:
			if building.name.contains("door_frame"):
				exclude_list.append(building.get_rid())

	var query = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_origin + ray_direction * 1000
	)
	# Check all layers for any solid surface
	query.collision_mask = 0xFFFFFFFF  # All layers

	if not exclude_list.is_empty():
		query.exclude = exclude_list

	var result = space_state.intersect_ray(query)

	if result:
		var hit_position = result.position
		# Debug: uncomment to see what raycast hits
		# print("Raycast hit: ", result.collider.name, " at ", hit_position)
		building_preview.update_position(hit_position)
		# The preview will set its own validity based on collision detection
	else:
		# No hit - position preview at fixed distance in front of camera
		# print("No raycast hit - using default position")
		var forward = -camera.global_transform.basis.z
		var default_pos = camera.global_position + forward * 10.0
		default_pos.y = 0.5  # Slightly above ground level
		building_preview.update_position(default_pos)

func is_valid_building_position(pos: Vector3) -> bool:
	# Check if player has resources
	if not can_afford_building():
		return false

	# Check for collisions with other buildings
	var building_info = building_data[current_building_id]
	var size = building_info.get("size", Vector3(1, 1, 1))

	# Simple grid position check using building-specific snapping
	var grid_pos = get_grid_snapped_position(pos, current_building_id)
	var pos_key = grid_pos_to_key(grid_pos)

	if pos_key in placed_buildings:
		print("Position validation failed: spot already occupied at key %s" % pos_key)
		return false

	return true

func can_afford_building() -> bool:
	if current_building_cost.is_empty():
		return true

	if not InventorySystem:
		return false

	for resource_id in current_building_cost.keys():
		var required_amount = current_building_cost[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id)
		if current_amount < required_amount:
			return false

	return true

func rotate_building():
	building_rotation = (building_rotation + 90) % 360
	if building_preview:
		building_preview.rotate_building()
	print("Rotated building to: %d degrees" % building_rotation)

func attempt_place_building():
	if not building_preview or not building_preview.can_place_here():
		print("Cannot place building here")
		return

	if not consume_building_resources():
		print("Cannot afford building")
		return

	place_building(building_preview.global_position)

func place_building(pos: Vector3):
	var building_info = building_data[current_building_id]
	var scene_path = building_info.get("scene_path", "")

	var placed_building: Node3D = null

	# Try to load building scene
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		print("Loading building scene: ", scene_path)
		var building_scene = load(scene_path)
		if building_scene:
			placed_building = building_scene.instantiate()
			print("Successfully instantiated building: ", placed_building.name)
		else:
			print("Failed to load building scene: ", scene_path)
	else:
		print("Scene path empty or doesn't exist: ", scene_path)

	if not placed_building:
		# Fallback: create simple 3D building
		placed_building = StaticBody3D.new()
		placed_building.add_to_group("building")

		# Special case: Door frame uses CSG for cutout
		if current_building_id == "door_frame" or current_building_id == "door_frame_with_door":
			var csg_wall = CSGBox3D.new()
			csg_wall.size = building_info.get("size", Vector3(4, 3, 0.2))
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(0.6, 0.6, 0.7)
			csg_wall.material = material
			csg_wall.use_collision = true  # Enable collision on CSG
			placed_building.add_child(csg_wall)

			# Create door cutout (1.2m wide x 2.4m tall, centered at bottom)
			var csg_cutout = CSGBox3D.new()
			csg_cutout.size = Vector3(1.2, 2.4, 0.3)  # Slightly thicker to ensure clean cut
			csg_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
			# Position: centered horizontally, bottom aligned at floor level
			# Wall center is at Y=0, wall goes from -1.5 to +1.5
			# Door 2.4m tall, so bottom at -1.5, top at +0.9
			csg_cutout.position = Vector3(0, -0.3, 0)  # -1.5 + 1.2 = -0.3
			csg_wall.add_child(csg_cutout)

			# If this is door_frame_with_door, add the actual door
			if current_building_id == "door_frame_with_door":
				# Create a pivot node for the door at the left edge (hinge position)
				var door_pivot = Node3D.new()
				door_pivot.name = "DoorPivot"
				# Position pivot at left edge of door opening (x = -0.6m)
				door_pivot.position = Vector3(-0.6, -0.325, 0)
				placed_building.add_child(door_pivot)

				# Create door mesh as child of pivot, offset so it extends to the right
				var door_mesh = CSGBox3D.new()
				door_mesh.name = "DoorMesh"
				door_mesh.size = Vector3(1.15, 2.35, 0.05)
				# Position door so left edge is at pivot (hinge)
				door_mesh.position = Vector3(0.575, 0, 0)  # Half width to the right
				var door_material = StandardMaterial3D.new()
				door_material.albedo_color = Color(0.5, 0.3, 0.1)  # Brown door
				door_mesh.material = door_material
				door_pivot.add_child(door_mesh)

				# Store door state (store pivot, not mesh)
				placed_building.set_meta("has_door", true)
				placed_building.set_meta("door_open", false)
				placed_building.set_meta("door_pivot", door_pivot)
		else:
			# Standard mesh-based building
			var mesh_instance = MeshInstance3D.new()
			var box_mesh = BoxMesh.new()
			box_mesh.size = building_info.get("size", Vector3(1, 1, 1))
			mesh_instance.mesh = box_mesh

			# Create material based on building type
			var material = StandardMaterial3D.new()
			if current_building_id.contains("wall"):
				material.albedo_color = Color(0.6, 0.6, 0.7)
			elif current_building_id.contains("floor"):
				material.albedo_color = Color(0.8, 0.6, 0.4)
			elif current_building_id.contains("roof"):
				material.albedo_color = Color(0.4, 0.5, 0.8)
			elif current_building_id.contains("door"):
				material.albedo_color = Color(0.7, 0.5, 0.3)
			else:
				material.albedo_color = Color(0.5, 0.5, 0.5)

			mesh_instance.material_override = material
			placed_building.add_child(mesh_instance)

		# Only add collision shape for non-CSG buildings
		# CSG buildings handle their own collision via use_collision = true
		if current_building_id != "door_frame":
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = building_info.get("collision_shape", Vector3(1, 1, 1))
			collision_shape.shape = box_shape
			placed_building.add_child(collision_shape)

	# Ensure building is in the building group
	if not placed_building.is_in_group("building"):
		placed_building.add_to_group("building")

	# Position and add to scene
	# Use the preview's position directly - it already has correct height adjustment for floors/walls
	placed_building.global_position = pos

	# For doors, use the preview's rotation (which may have been set by snap_door_to_frame)
	# For other buildings, use building_rotation
	if current_building_id == "door" and building_preview:
		placed_building.rotation_degrees = building_preview.rotation_degrees
	else:
		placed_building.rotation_degrees = Vector3(0, building_rotation, 0)

	placed_building.name = current_building_id + "_" + str(Time.get_unix_time_from_system())

	# Add to buildings container
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings3D")
	if not buildings_container:
		buildings_container = Node3D.new()
		buildings_container.name = "Buildings3D"
		get_tree().current_scene.add_child(buildings_container)

	buildings_container.add_child(placed_building)

	# Force physics update for dynamic bodies/areas
	if placed_building.has_method("set_physics_process"):
		placed_building.set_physics_process(true)

	print("Placed building at position: ", pos)
	print("Building name: ", placed_building.name)
	print("Building type: ", placed_building.get_class())
	if placed_building.has_method("interact"):
		print("Building has interact method - interaction should work")
	else:
		print("WARNING: Building does not have interact method!")

	if placed_building.is_in_group("interactable"):
		print("Building is in interactable group")
	else:
		print("WARNING: Building is not in interactable group!")

	# Track placed building
	# Use building-specific grid snapping for the tracking key
	var grid_snapped_pos = get_grid_snapped_position(pos, current_building_id)
	var pos_key = grid_pos_to_key(grid_snapped_pos)
	placed_buildings[pos_key] = {
		"id": current_building_id,
		"position": pos,
		"rotation": building_rotation,
		"node": placed_building
	}
	print("Tracking building with key: %s (snapped from %s)" % [pos_key, pos])

	# Add door functionality if needed
	if current_building_id == "door" or current_building_id == "door_frame_with_door":
		add_door_functionality_3d(placed_building)

	# If this was a move operation, delete the old building
	if building_to_move and is_instance_valid(building_to_move):
		print("Removing old building after successful move")
		building_to_move.queue_free()
		building_to_move = null

	# Emit signal
	building_placed.emit(current_building_id, pos)
	print("Placed 3D building %s at %s" % [current_building_id, pos])

	# Exit building mode
	finish_building_mode()

func cancel_building():
	print("Cancelled 3D building mode")
	# Clear move reference without deleting the original building
	building_to_move = null
	finish_building_mode()
	building_cancelled.emit()

func finish_building_mode():
	is_building_mode = false
	current_building_id = ""
	building_rotation = 0
	current_building_cost = {}
	building_to_move = null

	if building_preview:
		building_preview.queue_free()
		building_preview = null

	# Restore mouse capture for camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Restored mouse capture for camera control")

# 3D Grid functions
func snap_to_grid_3d(pos: Vector3, grid_size: float = 4.0) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		pos.y,  # Keep original Y position from raycast
		round(pos.z / grid_size) * grid_size
	)

func get_grid_snapped_position(pos: Vector3, building_id: String) -> Vector3:
	# Snap position using the correct grid size for this building type
	# Walls and door_frames use 2m grid, everything else uses 4m grid
	if building_id.contains("wall") or building_id.contains("door_frame"):
		# Use 2m grid for walls/door_frames
		return snap_to_grid_3d(pos, 2.0)
	else:
		# Use 4m grid for floors, roofs, etc.
		return snap_to_grid_3d(pos, 4.0)

func grid_pos_to_key(grid_pos: Vector3) -> String:
	return "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]

func key_to_grid_pos(key: String) -> Vector3:
	var parts = key.split(",")
	if parts.size() == 3:
		return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO

# Resource management
func get_building_recipe_cost(building_id: String) -> Dictionary:
	var recipes_file = "res://data/recipes.json"
	if not FileAccess.file_exists(recipes_file):
		return {}

	var file = FileAccess.open(recipes_file, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		return {}

	var recipes_data = json.data
	if building_id in recipes_data:
		var recipe = recipes_data[building_id]
		return recipe.get("ingredients", {})

	return {}

func consume_building_resources() -> bool:
	if current_building_cost.is_empty():
		return true

	if not InventorySystem:
		return false

	# Check if we can afford all resources
	for resource_id in current_building_cost.keys():
		var required_amount = current_building_cost[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id)
		if current_amount < required_amount:
			return false

	# Consume the resources
	for resource_id in current_building_cost.keys():
		var required_amount = current_building_cost[resource_id]
		var success = InventorySystem.remove_item(resource_id, required_amount)
		if not success:
			return false

	return true

func add_debug_resources() -> void:
	print("DEBUG: L key pressed - attempting to add resources")

	if InventorySystem:
		var success1 = InventorySystem.add_item("SCRAP_METAL", 100)
		var success2 = InventorySystem.add_item("METAL_SHEETS", 50)
		var success3 = InventorySystem.add_item("ELECTRONICS", 50)
		var success4 = InventorySystem.add_item("WOOD_SCRAPS", 100)

		print("DEBUG: Added resources - SCRAP_METAL: %s, METAL_SHEETS: %s, ELECTRONICS: %s, WOOD_SCRAPS: %s" % [success1, success2, success3, success4])
	else:
		print("DEBUG: InventorySystem not found")

# Demolition system
func toggle_demolition_mode():
	if is_demolition_mode:
		exit_demolition_mode()
	else:
		enter_demolition_mode()

func enter_demolition_mode():
	if is_building_mode:
		cancel_building()

	is_demolition_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Create UI indicator
	create_demolition_mode_ui()

	print("DEMOLITION: Entered demolition mode (X to toggle, ESC to exit, left-click to demolish)")

func create_demolition_mode_ui():
	if demolition_mode_label:
		return  # Already exists

	# Create a label centered at top of screen
	demolition_mode_label = Label.new()
	demolition_mode_label.text = "DEMOLITION MODE - Click building to destroy (X to exit)"
	demolition_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Style it
	demolition_mode_label.add_theme_color_override("font_color", Color.RED)
	demolition_mode_label.add_theme_font_size_override("font_size", 24)

	# Position at top center
	demolition_mode_label.anchor_left = 0.5
	demolition_mode_label.anchor_right = 0.5
	demolition_mode_label.anchor_top = 0.0
	demolition_mode_label.offset_left = -300
	demolition_mode_label.offset_right = 300
	demolition_mode_label.offset_top = 50
	demolition_mode_label.offset_bottom = 100

	# Add to current scene
	get_tree().current_scene.add_child(demolition_mode_label)

func remove_demolition_mode_ui():
	if demolition_mode_label:
		demolition_mode_label.queue_free()
		demolition_mode_label = null

func exit_demolition_mode():
	is_demolition_mode = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Remove UI indicator
	remove_demolition_mode_ui()

	print("DEMOLITION: Exited demolition mode")

func demolish_building_at_mouse():
	if not camera:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000)
	var result = space_state.intersect_ray(query)

	if result:
		var hit_object = result.collider
		print("DEMOLITION: Hit object: %s (type: %s)" % [hit_object.name, hit_object.get_class()])

		# Check if the hit object is a building or has a building parent
		var building = hit_object
		if not building.is_in_group("building"):
			# Check parent (CSG nodes are children of building)
			if building.get_parent() and building.get_parent().is_in_group("building"):
				building = building.get_parent()
			else:
				print("DEMOLITION: Hit object is not a building")
				return

		# Extract building ID from the name (format: "building_id_timestamp")
		var building_name = building.name
		var building_id = extract_building_id_from_name(building_name)

		print("DEMOLITION: Attempting to demolish: %s (ID: %s)" % [building_name, building_id])
		demolish_building_direct(building, building_id)

func extract_building_id_from_name(building_name: String) -> String:
	# Building names are formatted as "building_id_timestamp"
	# Extract everything before the last underscore
	var parts = building_name.split("_")
	if parts.size() >= 2:
		# Remove the timestamp (last part)
		parts.remove_at(parts.size() - 1)
		return "_".join(parts)
	return building_name

func demolish_building_direct(building_node: Node3D, building_id: String):
	if not building_node:
		return

	# Get the recipe cost for this building to calculate refund
	var recipe_cost = get_building_recipe_cost(building_id)

	# Refund materials (50% of original cost)
	if InventorySystem and not recipe_cost.is_empty():
		print("DEMOLITION: Refunding materials for %s:" % building_id)
		for resource_id in recipe_cost.keys():
			var original_amount = recipe_cost[resource_id]
			var refund_amount = int(original_amount * 0.5)  # 50% refund
			if refund_amount > 0:
				InventorySystem.add_item(resource_id, refund_amount)
				print("  + %d %s" % [refund_amount, resource_id])

	# Remove from tracking dictionary (try to find by node reference)
	for pos_key in placed_buildings.keys():
		if placed_buildings[pos_key].node == building_node:
			placed_buildings.erase(pos_key)
			break

	# Remove from scene
	var building_pos = building_node.global_position
	building_node.queue_free()

	building_demolished.emit(building_id, building_pos)
	print("DEMOLITION: Demolished %s at %s" % [building_id, building_pos])

func demolish_building(building_data_entry: Dictionary, position: Vector3):
	# Old function - kept for compatibility
	var building_id = building_data_entry.id
	var building_node = building_data_entry.node
	demolish_building_direct(building_node, building_id)

# Door system for 3D
func add_door_functionality_3d(door_node: Node3D):
	# Add Area3D for interaction if not present
	var interaction_area = door_node.get_node_or_null("InteractionArea")
	if not interaction_area:
		interaction_area = Area3D.new()
		interaction_area.name = "InteractionArea"
		door_node.add_child(interaction_area)

		var interaction_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(2, 2, 2)  # Larger interaction area
		interaction_shape.shape = box_shape
		interaction_area.add_child(interaction_shape)

	# Connect signals
	interaction_area.body_entered.connect(_on_player_entered_door_area_3d.bind(door_node))
	interaction_area.body_exited.connect(_on_player_exited_door_area_3d.bind(door_node))

	# Initialize door state
	var door_id = door_node.get_instance_id()
	door_states[door_id] = {
		"is_open": false,
		"static_body": door_node,
		"collision_shape": door_node.get_node_or_null("CollisionShape3D")
	}

func _on_player_entered_door_area_3d(door_node: Node3D):
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_nearby_door = door_node.get_node("InteractionArea")
		print("Press E to interact with door")

func _on_player_exited_door_area_3d(door_node: Node3D):
	if player_nearby_door == door_node.get_node_or_null("InteractionArea"):
		player_nearby_door = null

func handle_door_input(event: InputEvent):
	if not player_nearby_door:
		return

	if event.is_action_pressed("interact"):
		var door_node = player_nearby_door.get_parent()
		toggle_door_3d(door_node)

func toggle_door_3d(door_node: Node3D):
	var door_id = door_node.get_instance_id()
	if not door_states.has(door_id):
		return

	var door_data = door_states[door_id]
	if door_data.is_open:
		close_door_3d(door_node)
	else:
		open_door_3d(door_node)

func open_door_3d(door_node: Node3D):
	var door_id = door_node.get_instance_id()
	var door_data = door_states[door_id]

	# Check if this is a door_frame_with_door (has door metadata)
	if door_node.has_meta("has_door"):
		var door_pivot = door_node.get_meta("door_pivot")
		if door_pivot:
			# Rotate door pivot 90 degrees to open
			door_pivot.rotation_degrees.y = 90
			door_node.set_meta("door_open", true)
			print("Door frame door opened (rotated 90°)")
	else:
		# Old standalone door behavior
		var collision_shape = door_data.collision_shape
		if collision_shape:
			collision_shape.disabled = true

		# Change color to indicate open
		var mesh_instance = door_node.get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = Color.GREEN
		print("Door opened")

	door_data.is_open = true

func close_door_3d(door_node: Node3D):
	var door_id = door_node.get_instance_id()
	var door_data = door_states[door_id]

	# Check if this is a door_frame_with_door (has door metadata)
	if door_node.has_meta("has_door"):
		var door_pivot = door_node.get_meta("door_pivot")
		if door_pivot:
			# Rotate door pivot back to closed position
			door_pivot.rotation_degrees.y = 0
			door_node.set_meta("door_open", false)
			print("Door frame door closed")
	else:
		# Old standalone door behavior
		var collision_shape = door_data.collision_shape
		if collision_shape:
			collision_shape.disabled = false

		# Restore original color
		var mesh_instance = door_node.get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = Color(0.7, 0.5, 0.3)
		print("Door closed")

	door_data.is_open = false

func get_world_3d() -> World3D:
	return get_tree().current_scene.get_world_3d()

# Compatibility functions for systems that might still expect 2D interfaces
func snap_to_grid(pos, grid_size = 1.0):
	if pos is Vector3:
		return snap_to_grid_3d(pos, grid_size)
	elif pos is Vector2:
		# Convert 2D to 3D, place on ground level
		return Vector3(pos.x, 0, pos.y)
	return Vector3.ZERO
