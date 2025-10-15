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
var is_building_from_template: bool = false  # Skip re-snapping when building from template

# Building data loaded from JSON (single source of truth)
var building_data: Dictionary = {}

# Cache for GLB geometry data (lazy-loaded on first use)
var glb_geometry_cache: Dictionary = {}

var camera: Camera3D = null
var raycast_layer_mask: int = 0x1  # Layer 1 - Ground/World collision layer
var placed_buildings: Dictionary = {}

# Storage box data persistence for moving
var pending_storage_data: Dictionary = {}

# Door functionality for 3D doors
var door_states: Dictionary = {}
var player_nearby_door: Area3D = null

# ============================================================================
# GRID COORDINATE SYSTEM (Phase 1)
# ============================================================================

# Direction enum for rotation handling (Unity pattern)
enum Direction {
	DOWN = 0,   # 0° rotation (facing -Z in Godot, South)
	LEFT = 1,   # 90° rotation (facing -X in Godot, West)
	UP = 2,     # 180° rotation (facing +Z in Godot, North)
	RIGHT = 3   # 270° rotation (facing +X in Godot, East)
}

# Grid size constants (world units per grid cell)
const GRID_CELL_SIZE: float = 5.0  # SimpleSpace prefabs use 5m grid
const LEGACY_GRID_SIZE: float = 4.0  # Fallback for generic buildings

# Building type classification for grid behavior
enum BuildingType {
	GRID_OBJECT,   # Snaps to grid cell centers (floors, roofs, furniture)
	EDGE_OBJECT,   # Snaps to grid cell edges (walls, doors, windows)
	LOOSE_OBJECT   # Free placement (decorations, props)
}

# Tile edge enum for edge-based placement (Phase 3)
enum TileEdge {
	NORTH = 0,  # +Z edge
	EAST = 1,   # +X edge
	SOUTH = 2,  # -Z edge
	WEST = 3    # -X edge
}

# Grid tracking dictionary: Vector2i grid coords -> building info
var grid_objects: Dictionary = {}  # Replaces placed_buildings with grid-based keys

func _ready():
	# Load building data from JSON
	load_building_data()

	# Add to group so preview can find us
	add_to_group("building_system")

	# Connect to build menu
	call_deferred("_connect_to_build_menu")

	# Find camera
	call_deferred("_find_camera")

	print("3D BuildingSystem initialized")

func load_building_data():
	"""Load building data from buildings.json - single source of truth

	GLB geometry is lazy-loaded on first use via get_building_geometry()
	"""
	var file_path = "res://data/buildings.json"
	if not FileAccess.file_exists(file_path):
		push_error("BuildingSystem: buildings.json not found at %s" % file_path)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("BuildingSystem: Failed to open buildings.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("BuildingSystem: Failed to parse buildings.json: %s" % json.get_error_message())
		return

	var json_data = json.data
	if typeof(json_data) != TYPE_DICTIONARY:
		push_error("BuildingSystem: buildings.json root is not a dictionary")
		return

	# Convert JSON data to 3D building format
	for building_id in json_data:
		var building = json_data[building_id]

		# Convert 2D size to 3D size (x, y from JSON becomes x, z in 3D; add default height)
		var size_2d = building.get("size", {"x": 1, "y": 1})
		var size_x = size_2d.get("x", 1)
		var size_y = size_2d.get("y", 1)

		# Determine 3D size based on building type
		var size_3d: Vector3
		var height_offset: float = 0.0

		# Special handling for SimpleSpace/SciFiSpace prefabs (5x5 grid)
		if building_id == "basic_wall":
			size_3d = Vector3(5, 5, 0.1)
		elif building_id == "basic_floor":
			size_3d = Vector3(5, 0.1, 5)
			height_offset = 0.02
		elif building_id == "basic_roof":
			size_3d = Vector3(5, 0.1, 5)
		elif building_id == "door_frame":
			size_3d = Vector3(5, 5, 0.1)
		elif building_id == "door_frame_with_door" or building_id == "door":
			size_3d = Vector3(5, 5, 0.1)
		elif building_id == "reinforced_wall":
			size_3d = Vector3(1, 3, 0.3)
		elif building_id == "reinforced_roof":
			size_3d = Vector3(1, 0.2, 1)
		elif building_id.contains("wall"):
			# Generic walls are vertical
			size_3d = Vector3(size_x * 4.0, 3.0, 0.2)
		elif building_id.contains("floor") or building_id.contains("roof"):
			# Generic floors/roofs are horizontal
			size_3d = Vector3(size_x * 4.0, 0.1, size_y * 4.0)
		else:
			# Other buildings use simple cube sizing
			size_3d = Vector3(size_x, size_x, size_y)

		# Get scene path - prioritize scene_path, fall back to empty string
		var scene_path = building.get("scene_path", "")

		# Get icon path - try to resolve from JSON icon field
		var icon_path = ""
		if building.has("icon") and not building.icon.is_empty():
			icon_path = "res://assets/sprites/buildings/" + building.icon

		building_data[building_id] = {
			"name": building.get("name", building_id),
			"scene_path": scene_path,
			"size": size_3d,
			"collision_shape": size_3d,  # Use same as size by default
			"height_offset": height_offset,
			"geometry_offset": Vector3.ZERO,  # Will be populated by get_building_geometry() if GLB exists
			"icon_path": icon_path
		}

	print("BuildingSystem: Loaded %d buildings from JSON" % building_data.size())

## Get building geometry data, extracting from GLB on first access (lazy-load)
## @param building_id: The building ID to get geometry for
## @returns: Dictionary with size, geometry_offset, and other AABB data
func get_building_geometry(building_id: String) -> Dictionary:
	# Return cached data if available
	if glb_geometry_cache.has(building_id):
		return glb_geometry_cache[building_id]

	# Get building data
	if not building_data.has(building_id):
		push_warning("BuildingSystem: Unknown building_id '%s'" % building_id)
		return {}

	var building_info = building_data[building_id]
	var scene_path = building_info.get("scene_path", "")

	# Try to extract from GLB if path exists
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		var mesh_info = MeshInspector.inspect_mesh(scene_path)
		if mesh_info.has("has_mesh") and mesh_info.has_mesh:
			# Cache the geometry data
			glb_geometry_cache[building_id] = mesh_info

			# Update building_data with extracted values
			building_data[building_id].size = mesh_info.aabb_size
			building_data[building_id].geometry_offset = mesh_info.geometry_offset

			print("BuildingSystem: Lazy-loaded GLB geometry for '%s'" % building_id)
			return mesh_info

	# Return existing building_data as fallback
	return {
		"size": building_info.get("size", Vector3.ONE),
		"geometry_offset": building_info.get("geometry_offset", Vector3.ZERO),
		"has_mesh": false
	}

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

	# Lazy-load GLB geometry if not already cached
	get_building_geometry(building_id)

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
		# CSG is centered like BoxMesh, no offset needed
		csg_wall.name = "CSGBox3D"  # Named so preview can find it

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
		building_preview.setup_preview(current_building_id, null, Vector3.ZERO)
	else:
		# Standard box mesh preview - BoxMesh is already centered, no offset needed
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		building_preview.setup_preview(current_building_id, box_mesh, Vector3.ZERO)

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

func is_valid_building_position(pos: Vector3, building_id: String = "", rotation: int = -1) -> bool:
	# Allow external callers (like preview) to specify building_id and rotation
	var check_building_id = building_id if building_id != "" else current_building_id
	var check_rotation = rotation if rotation != -1 else building_rotation

	# NEW WORKFLOW: Don't check affordability since we're placing templates
	# Templates can be placed even if player can't afford them yet
	# Player will find out if they can't afford it when trying to build the template

	# Check for collisions with other buildings
	if not building_data.has(check_building_id):
		print("is_valid_building_position: Unknown building_id '%s'" % check_building_id)
		return false

	var building_info = building_data[check_building_id]
	var size = building_info.get("size", Vector3(1, 1, 1))

	# Simple grid position check using building-specific snapping
	var grid_pos = get_grid_snapped_position(pos, check_building_id, check_rotation)
	var pos_key = grid_pos_to_key(grid_pos, check_building_id, check_rotation)

	# Check if spot is occupied by a completed building
	if pos_key in placed_buildings:
		return false

	# Check if spot is occupied by an existing template
	var templates = get_tree().get_nodes_in_group("building_template")
	for template in templates:
		if template is Node3D and "building_id" in template:
			# Use the template's own building_id and rotation to snap with correct grid size
			var template_rotation = int(template.building_rotation_degrees) if "building_rotation_degrees" in template else 0
			var template_grid_pos = get_grid_snapped_position(template.global_position, template.building_id, template_rotation)
			var template_pos_key = grid_pos_to_key(template_grid_pos, template.building_id, template_rotation)
			if template_pos_key == pos_key:
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

	# NEW WORKFLOW: Place template instead of real building
	# No resource consumption yet - that happens when player builds the template
	place_building_template(building_preview.global_position)

	# Keep building mode active so player can place more templates
	# Don't call finish_building_mode() here

func place_building_template(pos: Vector3):
	"""Place a building template that can be built later"""
	var building_info = building_data[current_building_id]

	# Create template instance
	var template_script = load("res://scripts/buildings/BuildingTemplate.gd")
	var template = template_script.new()

	# Initialize template with building data
	template.initialize_template(
		current_building_id,
		pos,
		building_rotation,
		current_building_cost,
		building_info
	)

	# Add to scene
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings3D")
	if not buildings_container:
		buildings_container = Node3D.new()
		buildings_container.name = "Buildings3D"
		get_tree().current_scene.add_child(buildings_container)

	buildings_container.add_child(template)

	# Connect template signals
	template.construction_completed.connect(_on_template_construction_completed)
	template.construction_cancelled.connect(_on_template_construction_cancelled)

	print("Placed building template: %s at %s" % [current_building_id, pos])

	# Play a placement sound/feedback if desired
	# building_placed.emit(current_building_id, pos)  # Don't emit yet - only when actually built

func place_building(pos: Vector3):
	var building_info = building_data[current_building_id]
	var scene_path = building_info.get("scene_path", "")

	var placed_building: Node3D = null
	var is_glb_building = false  # Track if building was loaded from GLB prefab

	# Try to load building scene
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		print("Loading building scene: ", scene_path)
		var building_scene = load(scene_path)
		if building_scene:
			placed_building = building_scene.instantiate()
			is_glb_building = true  # GLB buildings already have collision built-in
		else:
			print("Failed to load building scene: ", scene_path)
	else:
		print("Scene path empty or doesn't exist: ", scene_path)

	if not placed_building:
		# Special case: Storage box needs special script
		if current_building_id == "storage_box":
			# Load the StorageBox3D script
			var storage_script = load("res://scripts/buildings/StorageBox3D.gd")
			placed_building = storage_script.new()
			print("Created StorageBox3D instance")
		else:
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
			elif current_building_id.contains("storage"):
				material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown for storage
			else:
				material.albedo_color = Color(0.5, 0.5, 0.5)

			mesh_instance.material_override = material
			placed_building.add_child(mesh_instance)

		# Only add collision shape for procedurally generated buildings
		# GLB buildings already have collision built into their prefab
		# CSG buildings handle their own collision via use_collision = true
		if not is_glb_building and current_building_id != "door_frame":
			var collision_shape = CollisionShape3D.new()
			var box_shape = BoxShape3D.new()
			box_shape.size = building_info.get("collision_shape", Vector3(1, 1, 1))
			collision_shape.shape = box_shape
			placed_building.add_child(collision_shape)
			print("Added procedural collision for non-GLB building: %s" % current_building_id)
		elif is_glb_building:
			print("Skipping duplicate collision - GLB already has built-in collision: %s" % current_building_id)

	# Ensure building is in the building group
	if not placed_building.is_in_group("building"):
		placed_building.add_to_group("building")

	# Calculate grid-snapped position (edge-based for walls/doors, center for floors)
	var grid_snapped_pos: Vector3
	if is_building_from_template:
		# GLB mesh geometry offsets vary by asset pack
		# These represent where the VISUAL center is in LOCAL space relative to the root
		var local_visual_center = Vector3.ZERO

		# SimpleSpace prefabs: Visual centers based on actual AABB measurements
		# Floor/Wall: Mesh(-2.5,0,-2.5) + AABB_center(-2.5,0,2.5) = Visual(-5,0,0)
		# Roof: Mesh(-2.5,0,-2.5) + AABB_center(-2.5,0,-2.5) = Visual(-5,0,-5)
		if current_building_id in ["basic_floor", "basic_wall"]:
			local_visual_center = Vector3(-5, 0, 0)
		elif current_building_id == "basic_roof":
			local_visual_center = Vector3(-5, 0, -5)  # Roof has different Z offset!

		# SciFiSpace doorframe: Visual center at local (2.5, 1.5, 0.25)
		# Z offset of 0.25 moves the building forward by -0.25 to align with SimpleSpace walls
		elif current_building_id == "door_frame":
			local_visual_center = Vector3(2.5, 1.5, 0.25)

		# Other door-related buildings (if using SimpleSpace)
		elif current_building_id in ["door_frame_with_door", "door"]:
			local_visual_center = Vector3(-5, 0, 0)

		# Rotate the local visual center to world space
		var rotation_transform = Transform3D()
		rotation_transform = rotation_transform.rotated(Vector3.UP, deg_to_rad(building_rotation))
		var world_visual_center = rotation_transform.basis * local_visual_center

		# To make visual appear at template position, offset root by negative of world visual center
		var geometry_offset = -world_visual_center

		grid_snapped_pos = pos + geometry_offset
	else:
		grid_snapped_pos = get_grid_snapped_position(pos, current_building_id, building_rotation)

	# Position and add to scene
	# Apply height offset if the building has one (e.g., to raise floors above ground)
	var height_offset = building_info.get("height_offset", 0.0)

	placed_building.global_position = grid_snapped_pos + Vector3(0, height_offset, 0)

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

	print("Placed building at position: ", placed_building.global_position)
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
	# Use grid-snapped position for the tracking key (already calculated above)
	var pos_key = grid_pos_to_key(grid_snapped_pos, current_building_id, building_rotation)
	placed_buildings[pos_key] = {
		"id": current_building_id,
		"position": grid_snapped_pos,
		"rotation": building_rotation,
		"node": placed_building
	}
	print("Tracking building with key: %s at grid position: %s" % [pos_key, grid_snapped_pos])

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

# ============================================================================
# GRID COORDINATE CONVERSION FUNCTIONS (Phase 1)
# ============================================================================

## Convert grid coordinates to world position (Unity pattern)
## @param grid_x: Grid X coordinate (integer)
## @param grid_z: Grid Z coordinate (integer - Godot Z, not Y!)
## @param grid_size: Size of grid cell in world units
## @returns: World position (Vector3) at the CENTER of the grid cell
func grid_to_world(grid_x: int, grid_z: int, grid_size: float = GRID_CELL_SIZE) -> Vector3:
	return Vector3(
		grid_x * grid_size + grid_size * 0.5,  # Center of cell
		0,  # Ground level (Y = 0)
		grid_z * grid_size + grid_size * 0.5   # Center of cell
	)

## Convert world position to grid coordinates
## @param world_pos: World position (Vector3)
## @param grid_size: Size of grid cell in world units
## @returns: Grid coordinates as Vector2i (x, z)
func world_to_grid(world_pos: Vector3, grid_size: float = GRID_CELL_SIZE) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / grid_size)),
		int(floor(world_pos.z / grid_size))
	)

## Get rotation offset for building placement (Unity pattern)
## Different rotations need different offsets to keep buildings grid-aligned
## @param dir: Direction enum value
## @param width: Building width in grid cells
## @param height: Building height in grid cells (depth in 3D)
## @returns: Offset as Vector2i (x, z)
func get_rotation_offset(dir: Direction, width: int, height: int) -> Vector2i:
	match dir:
		Direction.DOWN:   # 0° - no offset
			return Vector2i(0, 0)
		Direction.LEFT:   # 90° - offset by width
			return Vector2i(0, width)
		Direction.UP:     # 180° - offset by width and height
			return Vector2i(width, height)
		Direction.RIGHT:  # 270° - offset by height
			return Vector2i(height, 0)
		_:
			return Vector2i.ZERO

## Convert rotation degrees to Direction enum
## @param rotation_deg: Rotation in degrees (0, 90, 180, 270)
## @returns: Direction enum value
func degrees_to_direction(rotation_deg: int) -> Direction:
	var normalized = int(rotation_deg) % 360
	if normalized < 0:
		normalized += 360

	if normalized >= 315 or normalized < 45:
		return Direction.DOWN   # 0°
	elif normalized >= 45 and normalized < 135:
		return Direction.RIGHT  # 90°
	elif normalized >= 135 and normalized < 225:
		return Direction.UP     # 180°
	else:
		return Direction.LEFT   # 270°

## Convert Direction enum to rotation degrees
## @param dir: Direction enum value
## @returns: Rotation in degrees
func direction_to_degrees(dir: Direction) -> int:
	match dir:
		Direction.DOWN:
			return 0
		Direction.RIGHT:
			return 90
		Direction.UP:
			return 180
		Direction.LEFT:
			return 270
		_:
			return 0

## Get grid coordinates for a building at a world position with rotation
## Handles rotation offset automatically
## @param world_pos: World position where building is being placed
## @param width: Building width in grid cells
## @param height: Building height in grid cells (depth)
## @param dir: Direction/rotation
## @param grid_size: Size of grid cell
## @returns: Grid coordinates (bottom-left corner) as Vector2i
func get_grid_position_with_rotation(world_pos: Vector3, width: int, height: int, dir: Direction, grid_size: float = GRID_CELL_SIZE) -> Vector2i:
	var grid_pos = world_to_grid(world_pos, grid_size)
	var offset = get_rotation_offset(dir, width, height)
	return grid_pos - offset

# ============================================================================
# ROTATION OFFSET SYSTEM (Phase 5)
# ============================================================================

## Calculate world position for a building with rotation offset (Unity pattern)
## Used for multi-tile buildings (2x1, 3x2, etc.) to ensure proper grid alignment
## @param grid_origin: Grid coordinates (bottom-left corner) as Vector2i
## @param building_id: Building ID to look up dimensions
## @param rotation: Rotation in degrees (0, 90, 180, 270)
## @param grid_size: Size of grid cell in world units
## @returns: World position (Vector3) with rotation offset applied
func calculate_building_world_position(grid_origin: Vector2i, building_id: String, rotation: int, grid_size: float = GRID_CELL_SIZE) -> Vector3:
	# Get base world position at grid cell center
	var base_world = grid_to_world(grid_origin.x, grid_origin.y, grid_size)

	# Get building dimensions from building_data
	if not building_data.has(building_id):
		push_warning("BuildingSystem: Unknown building_id '%s' for rotation offset" % building_id)
		return base_world

	var data = building_data[building_id]
	var size_3d = data.get("size", Vector3.ONE)

	# Convert 3D size to grid dimensions (x = width, z = height/depth)
	# Grid size is in cells, so divide world size by cell size
	var width = max(1, int(round(size_3d.x / grid_size)))
	var height = max(1, int(round(size_3d.z / grid_size)))

	# Convert rotation to Direction enum
	var dir = degrees_to_direction(rotation)

	# Get rotation offset for this direction
	var rotation_offset = get_rotation_offset(dir, width, height)

	# Apply rotation offset (Unity pattern: grid_world_pos + rotation_offset * cell_size)
	base_world.x += rotation_offset.x * grid_size
	base_world.z += rotation_offset.y * grid_size

	return base_world

# ============================================================================
# EDGE-BASED PLACEMENT SYSTEM (Phase 3)
# ============================================================================

## Convert rotation degrees to TileEdge enum
## @param rotation_deg: Rotation in degrees (0, 90, 180, 270)
## @returns: TileEdge enum value
func get_edge_from_rotation(rotation_deg: int) -> TileEdge:
	var normalized = int(rotation_deg) % 360
	if normalized < 0:
		normalized += 360

	if normalized >= 315 or normalized < 45:
		return TileEdge.NORTH  # 0° - facing +Z
	elif normalized >= 45 and normalized < 135:
		return TileEdge.EAST   # 90° - facing +X
	elif normalized >= 135 and normalized < 225:
		return TileEdge.SOUTH  # 180° - facing -Z
	else:
		return TileEdge.WEST   # 270° - facing -X

## Get world position for a wall center on specified edge of a tile
## Positions wall so INNER face sits flush with tile edge
## @param tile_grid_pos: Grid coordinates of the tile (Vector2i for x,z)
## @param edge: Which edge of the tile (NORTH/SOUTH/EAST/WEST)
## @param thickness: Wall thickness in world units
## @param grid_size: Size of grid cell in world units
## @returns: World position (Vector3) for wall center
func get_edge_world_position(tile_grid_pos: Vector2i, edge: TileEdge, thickness: float, grid_size: float = GRID_CELL_SIZE) -> Vector3:
	# Get tile center position
	var tile_center = grid_to_world(tile_grid_pos.x, tile_grid_pos.y, grid_size)
	var half_tile = grid_size / 2.0

	# Position wall so inner face is flush with tile edge
	# Wall center = tile_edge_position + (thickness/2) outward
	var offset = half_tile + (thickness / 2.0)

	match edge:
		TileEdge.NORTH:  # +Z edge
			return tile_center + Vector3(0, 0, offset)
		TileEdge.SOUTH:  # -Z edge
			return tile_center + Vector3(0, 0, -offset)
		TileEdge.EAST:   # +X edge
			return tile_center + Vector3(offset, 0, 0)
		TileEdge.WEST:   # -X edge
			return tile_center + Vector3(-offset, 0, 0)
		_:
			return tile_center

## Snap floor/roof to grid center
## @param world_pos: World position to snap
## @param grid_size: Size of grid cell
## @returns: World position at grid cell center
func snap_floor_to_grid(world_pos: Vector3, grid_size: float = GRID_CELL_SIZE) -> Vector3:
	var grid_pos = world_to_grid(world_pos, grid_size)
	return grid_to_world(grid_pos.x, grid_pos.y, grid_size)

## Snap wall/door frame to nearest tile edge
## @param world_pos: World position to snap
## @param rotation: Building rotation in degrees
## @param building_id: Building ID to get thickness
## @param grid_size: Size of grid cell
## @returns: World position at edge
func snap_wall_to_edge(world_pos: Vector3, rotation: int, building_id: String = "", grid_size: float = GRID_CELL_SIZE) -> Vector3:
	var nearest_tile = world_to_grid(world_pos, grid_size)
	var edge = get_edge_from_rotation(rotation)

	# Get wall thickness from building data
	var thickness = 0.1  # Default SimpleSpace wall thickness
	if not building_id.is_empty() and building_data.has(building_id):
		var data = building_data[building_id]
		# Thickness is the Z component of the size for walls
		thickness = data.get("size", Vector3(5, 5, 0.1)).z

	return get_edge_world_position(Vector2i(nearest_tile.x, nearest_tile.y), edge, thickness, grid_size)

## Snap door to nearest door frame, or fall back to edge snapping
## @param world_pos: World position to snap
## @param search_radius: How far to search for door frames
## @returns: Dictionary with position and rotation
func snap_door_to_frame(world_pos: Vector3, search_radius: float = 3.0) -> Dictionary:
	var nearest_frame = find_nearest_door_frame(world_pos, search_radius)
	if nearest_frame:
		return {
			"position": nearest_frame.global_position,
			"rotation": nearest_frame.rotation_degrees.y
		}
	else:
		# Fallback to wall-like edge snapping
		return {
			"position": snap_wall_to_edge(world_pos, building_rotation, current_building_id),
			"rotation": building_rotation
		}

## Find nearest door frame to a position
## @param world_pos: Position to search from
## @param max_distance: Maximum search radius
## @returns: Node3D of nearest frame, or null
func find_nearest_door_frame(world_pos: Vector3, max_distance: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist = max_distance

	# Search placed buildings
	for key in placed_buildings:
		var building_entry = placed_buildings[key]
		if building_entry.id == "door_frame" or building_entry.id == "door_frame_with_door":
			var dist = building_entry.node.global_position.distance_to(world_pos)
			if dist < nearest_dist:
				nearest = building_entry.node
				nearest_dist = dist

	# Also search templates
	var templates = get_tree().get_nodes_in_group("building_template")
	for template in templates:
		if template is Node3D and "building_id" in template:
			if template.building_id == "door_frame" or template.building_id == "door_frame_with_door":
				var dist = template.global_position.distance_to(world_pos)
				if dist < nearest_dist:
					nearest = template
					nearest_dist = dist

	return nearest

## Rotate a Vector3 offset around the Y axis (Phase 4)
## Used to rotate geometry offsets to match building rotation
## @param offset: The offset vector to rotate
## @param rotation_deg: Rotation in degrees
## @returns: Rotated offset vector
func rotate_offset(offset: Vector3, rotation_deg: int) -> Vector3:
	var rotation_rad = deg_to_rad(rotation_deg)
	var transform = Transform3D()
	transform = transform.rotated(Vector3.UP, rotation_rad)
	return transform.basis * offset

# 3D Grid functions (LEGACY - will be replaced by grid coordinate system)
func snap_to_grid_3d(pos: Vector3, grid_size: float = 4.0) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		pos.y,  # Keep original Y position from raycast
		round(pos.z / grid_size) * grid_size
	)

func get_grid_snapped_position(pos: Vector3, building_id: String, rotation_deg: int = 0) -> Vector3:
	# Determine grid size for this building type
	var grid_size = 4.0
	if building_id in ["basic_wall", "basic_floor", "basic_roof", "door_frame", "door_frame_with_door", "door"]:
		grid_size = 5.0
	elif building_id.contains("wall") or building_id.contains("door_frame"):
		grid_size = 2.0

	# Walls and door frames snap to tile EDGES, not centers
	if building_id.contains("wall") or building_id.contains("door"):
		return snap_to_tile_edge(pos, grid_size, rotation_deg)
	else:
		# Floors, roofs, etc. snap to tile centers
		return snap_to_grid_3d(pos, grid_size)

func snap_to_tile_edge(pos: Vector3, grid_size: float, rotation_deg: int) -> Vector3:
	# First, find the nearest tile center
	var tile_center = Vector3(
		round(pos.x / grid_size) * grid_size,
		pos.y,
		round(pos.z / grid_size) * grid_size
	)

	# Then offset to the appropriate edge based on rotation
	var half_grid = grid_size / 2.0
	var edge_dir = get_edge_direction_from_rotation(rotation_deg)

	match edge_dir:
		"N":  # North edge (+Z)
			return Vector3(tile_center.x, tile_center.y, tile_center.z + half_grid)
		"E":  # East edge (+X)
			return Vector3(tile_center.x + half_grid, tile_center.y, tile_center.z)
		"S":  # South edge (-Z)
			return Vector3(tile_center.x, tile_center.y, tile_center.z - half_grid)
		"W":  # West edge (-X)
			return Vector3(tile_center.x - half_grid, tile_center.y, tile_center.z)
		_:
			return tile_center

func grid_pos_to_key(grid_pos: Vector3, building_id: String = "", rotation: int = 0) -> String:
	# Edge-based buildings (walls, door frames) get edge-specific keys
	# This prevents walls from blocking each other on different edges of the same tile
	if building_id.contains("wall") or building_id.contains("door"):
		var edge = get_edge_from_rotation(rotation)
		var edge_name = TileEdge.keys()[edge]
		return "%d,%d,%d-%s" % [grid_pos.x, grid_pos.y, grid_pos.z, edge_name]
	# Floors, roofs, and other buildings use tile-center keys
	return "%d,%d,%d" % [grid_pos.x, grid_pos.y, grid_pos.z]

func get_building_data(id: String) -> Dictionary:
	"""Get building data for a specific building ID"""
	if building_data.has(id):
		return building_data[id]
	return {}

func get_edge_direction_from_rotation(rotation: int) -> String:
	# Convert rotation to cardinal direction
	var normalized = int(rotation) % 360
	if normalized < 0:
		normalized += 360

	if normalized >= 315 or normalized < 45:
		return "N"  # North (0°)
	elif normalized >= 45 and normalized < 135:
		return "E"  # East (90°)
	elif normalized >= 135 and normalized < 225:
		return "S"  # South (180°)
	else:
		return "W"  # West (270°)

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

# ============================================================================
# TEMPLATE BUILDING SYSTEM
# ============================================================================

func _on_template_construction_completed(template: BuildingTemplate):
	"""Called when a template finishes construction"""
	print("Template construction completed: %s" % template.building_id)

	# Check if player can still afford it (in case resources were spent elsewhere)
	if not template.can_afford():
		print("ERROR: Cannot afford to complete this building anymore!")
		return

	# Consume resources
	for resource_id in template.building_cost.keys():
		var required_amount = template.building_cost[resource_id]
		var success = InventorySystem.remove_item(resource_id, required_amount)
		if not success:
			print("ERROR: Failed to consume resource %s" % resource_id)
			return

	# Place the real building at the template's position
	var template_pos = template.global_position
	var template_rotation = template.building_rotation_degrees

	# Store the template's building_id before removing it
	var building_id = template.building_id

	# Remove the template
	template.queue_free()

	# Place the real building using existing logic
	# Temporarily set current_building_id and building_rotation for place_building()
	var old_building_id = current_building_id
	var old_rotation = building_rotation

	current_building_id = building_id
	building_rotation = int(template_rotation)
	is_building_from_template = true  # Skip re-snapping - template position is already correct

	place_building(template_pos)

	# Restore old values
	current_building_id = old_building_id
	building_rotation = old_rotation
	is_building_from_template = false

	print("Real building placed from template at %s" % template_pos)

func _on_template_construction_cancelled(template: BuildingTemplate):
	"""Called when a template is cancelled/removed"""
	print("Template construction cancelled: %s" % template.building_id)
