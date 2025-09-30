extends Node

signal building_placed(building_id: String, position: Vector2)
signal building_cancelled()
signal building_demolished(building_id: String, position: Vector2)

var is_building_mode: bool = false
var is_demolition_mode: bool = false
var current_building_id: String = ""
var building_preview: Node2D = null
var building_rotation: int = 0  # 0, 90, 180, 270 degrees
var current_building_cost: Dictionary = {}  # Store resource requirements for current building

# Temporary storage for preserving data during building moves
var pending_storage_data: Dictionary = {}

# Building data - will be expanded later
var building_data: Dictionary = {
	"workbench": {
		"name": "Workbench",
		"size": Vector2(64, 64),
		"collision_shape": Vector2(64, 64),
		"icon_path": "res://assets/sprites/buildings/pixellab-A-sci-fi-workbench-with-a-meta-1756949376631.png",
		"scene_path": "res://scenes/buildings/Workbench.tscn"
	},
	"oxygen_tank": {
		"name": "Oxygen Tank",
		"size": Vector2(48, 48),
		"collision_shape": Vector2(48, 48),
		"icon_path": "res://assets/sprites/items/oxygentank.png",
		"scene_path": "res://scenes/buildings/OxygenTank.tscn"
	},
	"hand_crank_generator": {
		"name": "Hand Crank Generator", 
		"size": Vector2(64, 48),
		"collision_shape": Vector2(64, 48),
		"icon_path": "res://assets/sprites/items/generator2.png",
		"scene_path": "res://scenes/buildings/HandCrankGenerator.tscn"
	},
	"storage_box": {
		"name": "Storage Box",
		"size": Vector2(32, 32),
		"collision_shape": Vector2(32, 32),
		"icon_path": "res://assets/sprites/items/Chest.png",
		"scene_path": "res://scenes/buildings/StorageBox.tscn"
	},
	# Shelter Building Components
	"basic_wall": {
		"name": "Basic Wall",
		"size": Vector2(32, 8),
		"collision_shape": Vector2(32, 8),
		"icon_path": ""  # Will use fallback colored rectangle
	},
	"basic_floor": {
		"name": "Basic Floor", 
		"size": Vector2(32, 32),
		"collision_shape": Vector2(32, 32),
		"icon_path": ""  # Will use fallback colored rectangle
	},
	"basic_roof": {
		"name": "Basic Roof",
		"size": Vector2(32, 32),
		"collision_shape": Vector2(32, 32),
		"icon_path": ""  # Will use fallback colored rectangle
	},
	"door": {
		"name": "Door",
		"size": Vector2(32, 8),
		"collision_shape": Vector2(32, 8),
		"icon_path": ""  # Will use fallback colored rectangle
	},
	"reinforced_wall": {
		"name": "Reinforced Wall",
		"size": Vector2(32, 8),
		"collision_shape": Vector2(32, 8),
		"icon_path": ""  # Will use fallback colored rectangle
	},
	"reinforced_roof": {
		"name": "Reinforced Roof",
		"size": Vector2(32, 32),
		"collision_shape": Vector2(32, 32),
		"icon_path": ""  # Will use fallback colored rectangle
	}
}

func _ready():
	# Connect to build menu with delay to ensure BuildMenu is ready
	call_deferred("_connect_to_build_menu")
	
	# Set up a timer to periodically check for new BuildMenu instances
	var reconnect_timer = Timer.new()
	reconnect_timer.wait_time = 1.0  # Check every second
	reconnect_timer.timeout.connect(_check_build_menu_connection)
	add_child(reconnect_timer)
	reconnect_timer.start()

func _connect_to_build_menu():
	if BuildMenu.instance:
		# Disconnect from previous instance if it exists and is still valid
		if BuildMenu.instance.item_to_build_selected.is_connected(_on_item_to_build_selected):
			print("Disconnecting from previous BuildMenu instance")
			BuildMenu.instance.item_to_build_selected.disconnect(_on_item_to_build_selected)
		
		BuildMenu.instance.item_to_build_selected.connect(_on_item_to_build_selected)
		print("BuildingSystem connected to BuildMenu instance: ", BuildMenu.instance)
	else:
		print("BuildMenu.instance not found, retrying...")
		# Use a timer instead of process_frame for a more reasonable retry interval
		var timer = Timer.new()
		timer.wait_time = 0.5
		timer.one_shot = true
		timer.timeout.connect(_connect_to_build_menu)
		add_child(timer)
		timer.start()

var last_build_menu_instance: BuildMenu = null

func _check_build_menu_connection():
	# Check if BuildMenu instance has changed (new scene loaded)
	if BuildMenu.instance != last_build_menu_instance:
		print("BuildMenu instance changed, reconnecting...")
		last_build_menu_instance = BuildMenu.instance
		call_deferred("_connect_to_build_menu")

func _input(event: InputEvent):
	# Debug: Add resources with L key
	if event is InputEventKey and event.pressed and event.keycode == KEY_L:
		print("DEBUG: L key detected in BuildingSystem!")
		add_debug_resources()
		return
	
	# Demolition mode toggle with X key
	if event is InputEventKey and event.pressed and event.keycode == KEY_X:
		toggle_demolition_mode()
		return
	
	# Handle demolition mode
	if is_demolition_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				demolish_building_at_mouse()
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				exit_demolition_mode()
		return
	
	# Handle door interactions when not in building mode
	if not is_building_mode:
		handle_door_input(event)
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			attempt_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			rotate_building()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			cancel_building()

func _process(_delta):
	if is_building_mode and building_preview:
		# Update preview position to follow mouse
		var mouse_pos = get_corrected_mouse_position()
		var grid_pos = snap_to_grid(mouse_pos)
		building_preview.global_position = grid_pos
		
		# Update preview validity (green for valid, red for invalid)
		update_preview_validity(grid_pos)
	
	elif is_demolition_mode:
		# Visual feedback for demolition mode
		update_demolition_cursor()

func _unhandled_input(event: InputEvent):
	"""Fallback input handler for demolition mode - handles cases where main _input doesn't work"""
	if is_demolition_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				demolish_building_at_mouse()
				get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				exit_demolition_mode()
				get_viewport().set_input_as_handled()

func _on_item_to_build_selected(item_id: String):
	print("BuildingSystem received item_to_build_selected: ", item_id)
	start_building_mode(item_id)

func start_building_mode(building_id: String):
	print("start_building_mode called with: ", building_id)
	
	if not building_data.has(building_id):
		print("Unknown building: %s" % building_id)
		return
	
	is_building_mode = true
	current_building_id = building_id
	building_rotation = 0
	
	# Get recipe cost data for resource consumption on placement
	current_building_cost = get_building_recipe_cost(building_id)
	
	print("Creating building preview...")
	create_building_preview()
	print("Started building mode for: %s" % building_id)
	print("is_building_mode: ", is_building_mode)
	print("building_preview: ", building_preview)

func create_building_preview():
	if building_preview:
		building_preview.queue_free()
	
	print("[DEBUG] Creating preview for building_id: ", current_building_id)
	print("[DEBUG] building_data keys: ", building_data.keys())
	
	# Create a sprite-based preview using the actual asset
	building_preview = Node2D.new()
	building_preview.name = "BuildingPreview"
	
	if not building_data.has(current_building_id):
		print("[ERROR] Building ID '%s' not found in building_data!" % current_building_id)
		return
	
	var building_info = building_data[current_building_id]
	var icon_path = building_info.get("icon_path", "")
	
	print("Creating preview with icon_path: ", icon_path)
	print("ResourceLoader.exists: ", ResourceLoader.exists(icon_path))
	
	# Create sprite component
	var sprite = Sprite2D.new()
	sprite.name = "PreviewSprite"
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
		print("Loaded texture: ", sprite.texture)
	else:
		print("Failed to load texture, creating fallback for: ", current_building_id)
		# Create a fallback colored rectangle with appropriate dimensions
		var image_width = 32
		var image_height = 32
		
		# Adjust dimensions for different building types for better alignment
		if current_building_id.contains("wall"):
			# Wall dimensions depend on orientation (will be determined during placement)
			# Default to horizontal wall
			image_width = 32
			image_height = 8  # Thin horizontal rectangle
		elif current_building_id.contains("door"):
			# Doors should be same size as walls for consistent alignment
			image_width = 32
			image_height = 8  # Same size as walls
		
		var image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
		
		# Create more sophisticated textures for better visual distinction
		if current_building_id.contains("wall"):
			# Create a wall texture with border for better alignment visibility
			var wall_color = Color(0.4, 0.4, 0.5, 1.0)  # Dark gray for wall interior
			var border_color = Color(0.2, 0.2, 0.3, 1.0)  # Darker border
			image.fill(wall_color)
			
			# Add border around the edges for clear grid alignment
			for x in range(image_width):
				for y in range(image_height):
					if x == 0 or x == image_width-1 or y == 0 or y == image_height-1:
						image.set_pixel(x, y, border_color)
		
		elif current_building_id.contains("floor"):
			# Floor gets a simple fill
			var color = Color(0.6, 0.5, 0.4, 1.0)  # Brown for floors
			image.fill(color)
		
		elif current_building_id.contains("roof"):
			# Roof gets a simple fill
			var color = Color(0.2, 0.3, 0.7, 1.0)  # Blue for roofs
			image.fill(color)
		
		elif current_building_id.contains("door"):
			# Door with same border style as walls but different color
			var door_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown for door interior
			var border_color = Color(0.4, 0.2, 0.1, 1.0)  # Darker brown border
			image.fill(door_color)
			
			# Add border around the edges (same style as walls)
			for x in range(image_width):
				for y in range(image_height):
					if x == 0 or x == image_width-1 or y == 0 or y == image_height-1:
						image.set_pixel(x, y, border_color)
		
		else:
			# Default fallback
			var color = Color.MAGENTA
			image.fill(color)
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture
	
	sprite.modulate = Color.GREEN
	sprite.modulate.a = 0.7
	
	# Set scale based on building type
	var scale_factor = 0.6  # Default for workbench
	if current_building_id == "oxygen_tank" or current_building_id == "hand_crank_generator" or current_building_id == "storage_box":
		scale_factor = 0.3  # 50% smaller (30% of original instead of 60%)
	
	sprite.scale = Vector2(scale_factor, scale_factor)
	building_preview.add_child(sprite)
	
	# Skip outline for now to simplify debugging
	# TODO: Add outline back later if needed
	
	building_preview.z_index = 100
	
	# Add to scene
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(building_preview)
		print("Added building_preview to scene: ", scene.name)
	else:
		print("ERROR: No current scene found!")

# Removed create_outline_style function for now

func snap_to_grid(pos: Vector2, grid_size: int = 32) -> Vector2:
	var base_pos = Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)
	
	# For walls and doors, adjust position to align with floor edges
	if current_building_id.contains("wall") or current_building_id.contains("door"):
		# Determine wall orientation based on mouse position relative to grid center
		var grid_center = base_pos
		var offset_x = pos.x - grid_center.x
		var offset_y = pos.y - grid_center.y
		
		# If closer to horizontal edges (top/bottom), position as horizontal wall
		if abs(offset_y) > abs(offset_x):
			if offset_y > 0:
				# Bottom edge of grid cell
				return Vector2(base_pos.x, base_pos.y + grid_size/2 - 4)  # 4 = half wall thickness
			else:
				# Top edge of grid cell  
				return Vector2(base_pos.x, base_pos.y - grid_size/2 + 4)
		else:
			# Vertical wall - left/right edges
			if offset_x > 0:
				# Right edge of grid cell
				return Vector2(base_pos.x + grid_size/2 - 4, base_pos.y)
			else:
				# Left edge of grid cell
				return Vector2(base_pos.x - grid_size/2 + 4, base_pos.y)
	
	return base_pos

func update_preview_validity(pos: Vector2):
	if not building_preview:
		return
	
	var is_valid = is_valid_building_position(pos)
	var sprite = building_preview.get_child(0) as Sprite2D
	if sprite:
		sprite.modulate = Color.GREEN if is_valid else Color.RED
		sprite.modulate.a = 0.7

func is_valid_building_position(pos: Vector2) -> bool:
	var building_info = building_data[current_building_id]
	var size = building_info.get("size", Vector2(64, 64))
	
	# Check room boundaries first
	var room_bounds = get_room_bounds()
	if room_bounds:
		if not room_bounds.is_position_valid_for_building(pos, size):
			return false
	
	# Check for collisions with other buildings
	# TODO: Add collision detection with existing buildings
	
	return true

func get_room_bounds() -> RoomBounds:
	var scene = get_tree().current_scene
	if scene:
		var room_bounds = scene.find_children("*", "RoomBounds", false, false)
		if room_bounds.size() > 0:
			return room_bounds[0] as RoomBounds
	return null

func rotate_building():
	building_rotation = (building_rotation + 90) % 360
	if building_preview:
		building_preview.rotation_degrees = building_rotation
	print("Rotated building to: %d degrees" % building_rotation)

func attempt_place_building():
	if not building_preview:
		return
	
	var position = building_preview.global_position
	
	if not is_valid_building_position(position):
		print("Invalid building position")
		return
	
	# Place the actual building
	place_building(position)

func place_building(pos: Vector2):
	print("Placing %s at position: %s" % [current_building_id, pos])
	
	# Consume resources before placing
	if not consume_building_resources():
		print("Failed to consume resources for: %s" % current_building_id)
		return
	
	# For now, create a simple building representation
	# Later this would instantiate the actual building scene
	create_placed_building(pos)
	
	# Emit signal
	building_placed.emit(current_building_id, pos)
	
	print("Successfully placed %s and consumed resources" % current_building_id)
	
	# Exit building mode
	finish_building_mode()

func create_placed_building(pos: Vector2):
	print("Creating placed building: %s" % current_building_id)
	var building_info = building_data[current_building_id]
	var scene_path = building_info.get("scene_path", "")
	
	var placed_building: Node2D
	
	# Try to load the actual building scene first
	if not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		print("Loading building scene: %s" % scene_path)
		var building_scene = load(scene_path)
		if building_scene:
			placed_building = building_scene.instantiate()
			print("Successfully instantiated building from scene")
		else:
			print("ERROR: Failed to load building scene")
	
	# Fallback to simple sprite if scene loading fails
	if not placed_building:
		print("Fallback: Creating simple building representation")
		placed_building = Area2D.new()  # Use Area2D for interaction
		var icon_path = building_info.get("icon_path", "")
		
		# Create sprite
		var sprite = Sprite2D.new()
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			sprite.texture = load(icon_path)
		else:
			# Create fallback colored texture with appropriate dimensions
			var image_width = 32
			var image_height = 32
			
			# Adjust dimensions for different building types for better alignment
			if current_building_id.contains("wall"):
				# Wall dimensions depend on orientation (will be determined during placement)
				# Default to horizontal wall
				image_width = 32
				image_height = 8  # Thin horizontal rectangle
			elif current_building_id.contains("door"):
				# Doors should be same size as walls for consistent alignment
				image_width = 32
				image_height = 8  # Same size as walls
			
			var image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
			
			# Create more sophisticated textures for better visual distinction
			if current_building_id.contains("wall"):
				# Create a wall texture with border for better alignment visibility
				var wall_color = Color(0.4, 0.4, 0.5, 1.0)  # Dark gray for wall interior
				var border_color = Color(0.2, 0.2, 0.3, 1.0)  # Darker border
				image.fill(wall_color)
				
				# Add border around the edges for clear grid alignment
				for x in range(image_width):
					for y in range(image_height):
						if x == 0 or x == image_width-1 or y == 0 or y == image_height-1:
							image.set_pixel(x, y, border_color)
			
			elif current_building_id.contains("floor"):
				# Floor gets a simple fill
				var color = Color(0.6, 0.5, 0.4, 1.0)  # Brown for floors
				image.fill(color)
			
			elif current_building_id.contains("roof"):
				# Roof gets a simple fill
				var color = Color(0.2, 0.3, 0.7, 1.0)  # Blue for roofs
				image.fill(color)
			
			elif current_building_id.contains("door"):
				# Door with same border style as walls but different color
				var door_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown for door interior
				var border_color = Color(0.4, 0.2, 0.1, 1.0)  # Darker brown border
				image.fill(door_color)
				
				# Add border around the edges (same style as walls)
				for x in range(image_width):
					for y in range(image_height):
						if x == 0 or x == image_width-1 or y == 0 or y == image_height-1:
							image.set_pixel(x, y, border_color)
			
			else:
				# Default fallback
				var color = Color.MAGENTA
				image.fill(color)
			var texture = ImageTexture.create_from_image(image)
			sprite.texture = texture
		
		sprite.modulate = Color.WHITE  # Full color for placed buildings
		
		# Set scale based on building type
		var scale_factor = 0.6  # Default for workbench
		if current_building_id == "oxygen_tank" or current_building_id == "hand_crank_generator" or current_building_id == "storage_box":
			scale_factor = 0.3  # 50% smaller (30% of original instead of 60%)
		elif current_building_id.contains("wall") or current_building_id.contains("floor") or current_building_id.contains("roof") or current_building_id.contains("door"):
			scale_factor = 1.0  # Full size for shelter buildings (32x32 pixels)
		
		sprite.scale = Vector2(scale_factor, scale_factor)
		placed_building.add_child(sprite)
		
		# Add collision for physics (so player can't walk through)
		# Only add collision for walls and doors, not floors or roofs
		if current_building_id.contains("wall") or current_building_id.contains("door"):
			var static_body = StaticBody2D.new()
			static_body.name = "Collision"
			var collision_shape = CollisionShape2D.new()
			collision_shape.name = "CollisionShape2D"  # Give it the expected name
			var shape = RectangleShape2D.new()
			var size = building_info.get("collision_shape", Vector2(32, 32))
			shape.size = size
			collision_shape.shape = shape
			static_body.add_child(collision_shape)
			placed_building.add_child(static_body)
		
		# Add interaction area (for E key interaction) - only for fallback
		var interaction_shape = CollisionShape2D.new()
		var interaction_rect = RectangleShape2D.new()
		var building_size = building_info.get("collision_shape", Vector2(32, 32))
		interaction_rect.size = building_size * 1.2  # Slightly larger than collision
		interaction_shape.shape = interaction_rect
		placed_building.add_child(interaction_shape)
		
		# Set up area properties for fallback
		placed_building.collision_layer = 8  # Building interaction layer
		placed_building.collision_mask = 2   # Player layer
		
		# Add building-specific script based on type for fallback
		if current_building_id == "workbench":
			var script = load("res://scripts/buildings/WorkbenchBuilding.gd")
			if script:
				placed_building.set_script(script)
		elif current_building_id == "hand_crank_generator":
			var script = load("res://scripts/buildings/HandCrankGenerator.gd")
			if script:
				placed_building.set_script(script)
	
	# Position and setup for all buildings (scene-loaded or fallback)
	placed_building.global_position = pos
	placed_building.name = current_building_id + "_" + str(Time.get_unix_time_from_system())
	placed_building.rotation_degrees = building_rotation  # Apply rotation from preview
	
	# Set z-index based on building type for proper layering
	if current_building_id.contains("floor"):
		placed_building.z_index = -1  # Floors render above ground, below player
	elif current_building_id.contains("roof"):
		placed_building.z_index = 3   # Roofs render above everything
	else:
		placed_building.z_index = 2   # Walls and doors above player level
	
	# Add to a buildings container
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_container:
		buildings_container = Node2D.new()
		buildings_container.name = "Buildings"
		get_tree().current_scene.add_child(buildings_container)
	
	buildings_container.add_child(placed_building)
	print("Added building %s to scene at %s" % [current_building_id, pos])
	
	# Add building-specific functionality after positioning and adding to scene
	if current_building_id == "door":
		# Add door functionality after building is properly positioned
		add_door_functionality(placed_building)
	elif current_building_id.contains("roof"):
		# Register roof with visibility manager
		var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
		if roof_manager:
			roof_manager.register_roof_tile(pos, placed_building)
	
	# Notify interior detection system of new building
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system:
		interior_system.call_deferred("refresh_building_structures")

func cancel_building():
	print("Cancelled building mode")
	finish_building_mode()
	restore_normal_cursor()  # Make sure cursor is restored
	building_cancelled.emit()

func finish_building_mode():
	is_building_mode = false
	current_building_id = ""
	building_rotation = 0
	
	if building_preview:
		building_preview.queue_free()
		building_preview = null

func get_global_mouse_position() -> Vector2:
	# Get the mouse position in the world
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	
	# Try to find the camera in the current scene
	var camera = viewport.get_camera_2d()
	if not camera:
		# Look for camera in the scene tree
		var scene = get_tree().current_scene
		if scene:
			camera = scene.find_children("*", "Camera2D", true, false)
			if camera.size() > 0:
				camera = camera[0]
			else:
				camera = null
	
	if camera:
		# Use the camera's built-in method which handles viewport scaling properly
		return camera.get_global_mouse_position()
	else:
		# Fallback for no camera
		return viewport.get_mouse_position()

# Function to update building icon when asset is ready
func update_building_icon(building_id: String, icon_path: String):
	if building_data.has(building_id):
		building_data[building_id]["icon_path"] = icon_path
		print("Updated icon for %s: %s" % [building_id, icon_path])

# Get recipe cost from recipes.json for resource consumption
func get_building_recipe_cost(building_id: String) -> Dictionary:
	var recipes_file = "res://data/recipes.json"
	if not FileAccess.file_exists(recipes_file):
		print("recipes.json not found")
		return {}
	
	var file = FileAccess.open(recipes_file, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		print("Failed to parse recipes.json")
		return {}
	
	var recipes_data = json.data
	if building_id in recipes_data:
		var recipe = recipes_data[building_id]
		var ingredients = recipe.get("ingredients", {})
		print("Found recipe cost for %s: %s" % [building_id, ingredients])
		return ingredients
	else:
		print("No recipe found for building: %s" % building_id)
		return {}

# Consume resources for the current building
func consume_building_resources() -> bool:
	if current_building_cost.is_empty():
		print("No resource cost data for %s" % current_building_id)
		return true  # Allow placement if no cost data
	
	if not InventorySystem:
		print("InventorySystem not available")
		return false
	
	# Check if we can afford all resources
	for resource_id in current_building_cost.keys():
		var required_amount = current_building_cost[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id)
		if current_amount < required_amount:
			print("Insufficient %s: have %d, need %d" % [resource_id, current_amount, required_amount])
			return false
	
	# Consume the resources
	for resource_id in current_building_cost.keys():
		var required_amount = current_building_cost[resource_id]
		var success = InventorySystem.remove_item(resource_id, required_amount)
		if not success:
			print("Failed to remove resource: %s" % resource_id)
			return false
	
	print("Successfully consumed resources: %s" % current_building_cost)
	return true

# Door functionality for placed doors
var door_states: Dictionary = {}  # Track door state by door instance ID
var player_nearby_door: Area2D = null  # Track which door player is near

func add_door_functionality(door_area: Area2D):
	"""Add interactive door functionality to a placed door"""
	# Initialize door state
	var door_id = door_area.get_instance_id()
	door_states[door_id] = {
		"is_open": false,
		"is_animating": false,
		"static_body": null,
		"sprite": null
	}
	
	# Find the static body (collision) and sprite
	var static_body = door_area.get_node_or_null("Collision")
	var sprite: Sprite2D = null
	
	# Find the sprite among the children (it might not be the first child)
	for child in door_area.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
			break
	
	door_states[door_id]["static_body"] = static_body
	door_states[door_id]["sprite"] = sprite
	
	# Make sure the door area can detect the player
	door_area.collision_layer = 8  # Building interaction layer
	door_area.collision_mask = 2   # Player layer
	door_area.monitoring = true
	door_area.monitorable = true
	
	# Connect door area signals
	door_area.body_entered.connect(_on_player_entered_door_area.bind(door_area))
	door_area.body_exited.connect(_on_player_exited_door_area.bind(door_area))
	
	print("Added door functionality to door at: ", door_area.global_position)
	print("Door area collision layer: %d, mask: %d" % [door_area.collision_layer, door_area.collision_mask])
	print("Door has static body: %s, sprite: %s" % [static_body != null, sprite != null])

func _on_player_entered_door_area(door_area: Area2D):
	"""Handle player entering door interaction area"""
	print("DOOR DEBUG: Player entered door area at %s" % door_area.global_position)
	var bodies = door_area.get_overlapping_bodies()
	print("DOOR DEBUG: Found %d overlapping bodies" % bodies.size())
	
	for body in bodies:
		print("DOOR DEBUG: Body name: %s, collision_layer: %d" % [body.name, body.collision_layer])
		if body.name == "Player":
			player_nearby_door = door_area
			var door_id = door_area.get_instance_id()
			var door_data = door_states.get(door_id, {})
			var action_text = "close" if door_data.get("is_open", false) else "open"
			print("DOOR DEBUG: Press E to %s door" % action_text)
			break

func _on_player_exited_door_area(door_area: Area2D):
	"""Handle player leaving door interaction area"""
	print("DOOR DEBUG: Player exited door area at %s" % door_area.global_position)
	if player_nearby_door == door_area:
		player_nearby_door = null
		print("DOOR DEBUG: Cleared nearby door")

func handle_door_input(event: InputEvent):
	"""Handle door interaction input"""
	# Manual door detection as backup
	if not player_nearby_door:
		check_for_nearby_doors()
	
	if not player_nearby_door:
		return
	
	if event.is_action_pressed("interact"):
		print("DOOR DEBUG: E key pressed, toggling door")
		toggle_door(player_nearby_door)
		# Consume the event to prevent other systems from processing it
		get_viewport().set_input_as_handled()

func check_for_nearby_doors():
	"""Manually check if player is near any doors"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Check all doors
	for door_id in door_states.keys():
		# Find the door by searching through all buildings
		var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
		if not buildings_container:
			continue
			
		for building in buildings_container.get_children():
			if building.get_instance_id() == door_id:
				var door_pos = building.global_position
				var distance = player_pos.distance_to(door_pos)
				
				if distance < 50:  # Within 50 pixels
					player_nearby_door = building
					var door_data = door_states.get(door_id, {})
					var action_text = "close" if door_data.get("is_open", false) else "open"
					print("DOOR DEBUG: Manual detection - Press E to %s door (distance: %.1f)" % [action_text, distance])
					return
	
	# Clear nearby door if no doors are close
	if player_nearby_door:
		player_nearby_door = null
		print("DOOR DEBUG: Manual detection - No doors nearby")

func toggle_door(door_area: Area2D):
	"""Toggle door open/closed state"""
	var door_id = door_area.get_instance_id()
	if not door_states.has(door_id):
		return
		
	var door_data = door_states[door_id]
	
	# Don't toggle if already animating
	if door_data.is_animating:
		return
		
	if door_data.is_open:
		close_door(door_area)
	else:
		open_door(door_area)

func open_door(door_area: Area2D):
	"""Open the door"""
	var door_id = door_area.get_instance_id()
	var door_data = door_states[door_id]
	door_data.is_animating = true
	
	print("Opening door...")
	
	# Change visual to indicate open state (green)
	var sprite = door_data.sprite as Sprite2D
	if sprite:
		sprite.modulate = Color.GREEN
	
	# Disable collision so player can pass through
	var static_body = door_data.static_body as StaticBody2D
	if static_body:
		var collision_shape = static_body.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = true
			print("DOOR DEBUG: Collision disabled - you should be able to walk through")
		else:
			print("DOOR DEBUG: No collision shape found!")
	else:
		print("DOOR DEBUG: No static body found!")
	
	# Animation delay
	await get_tree().create_timer(0.2).timeout
	
	door_data.is_animating = false
	door_data.is_open = true
	
	print("Door opened")

func close_door(door_area: Area2D):
	"""Close the door"""
	var door_id = door_area.get_instance_id()
	var door_data = door_states[door_id]
	door_data.is_animating = true
	
	print("Closing door...")
	
	# Change visual back to closed state (brown)
	var sprite = door_data.sprite as Sprite2D
	if sprite:
		sprite.modulate = Color.WHITE  # Reset to original door color (brown with borders)
	
	# Enable collision so player can't pass through
	var static_body = door_data.static_body as StaticBody2D
	if static_body:
		var collision_shape = static_body.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.disabled = false
			print("DOOR DEBUG: Collision enabled - door should now block player")
		else:
			print("DOOR DEBUG: No collision shape found!")
	else:
		print("DOOR DEBUG: No static body found!")
	
	# Animation delay
	await get_tree().create_timer(0.2).timeout
	
	door_data.is_animating = false
	door_data.is_open = false
	
	print("Door closed")

func add_debug_resources() -> void:
	"""Add debug resources when L key is pressed"""
	print("DEBUG: L key pressed - attempting to add resources")
	
	# Try using the direct InventorySystem reference  
	if InventorySystem:
		# Add the requested resources (using uppercase IDs)
		var success1 = InventorySystem.add_item("SCRAP_METAL", 100)
		var success2 = InventorySystem.add_item("METAL_SHEETS", 50)
		var success3 = InventorySystem.add_item("ELECTRONICS", 50)
		var success4 = InventorySystem.add_item("WOOD_SCRAPS", 100)
		
		print("DEBUG: Add results - SCRAP_METAL: %s, METAL_SHEETS: %s, ELECTRONICS: %s, WOOD_SCRAPS: %s" % [success1, success2, success3, success4])
		print("DEBUG: Added resources - 100 scrap metal, 50 metal sheets, 50 electronics, 100 wood scraps")
	else:
		print("DEBUG: InventorySystem not found")

# DEMOLITION SYSTEM FUNCTIONS

func toggle_demolition_mode():
	"""Toggle between demolition mode and normal mode"""
	if is_demolition_mode:
		exit_demolition_mode()
	else:
		enter_demolition_mode()

func enter_demolition_mode():
	"""Enter demolition mode"""
	if is_building_mode:
		cancel_building()  # Exit building mode first
	
	is_demolition_mode = true
	print("DEMOLITION: Entered demolition mode (X to toggle, ESC to exit, left-click to demolish)")
	
	# Change cursor to demolition icon
	set_demolition_cursor()
	
	# Show UI feedback
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message("Demolition Mode - Left click to demolish buildings", 3.0)

func exit_demolition_mode():
	"""Exit demolition mode"""
	is_demolition_mode = false
	print("DEMOLITION: Exited demolition mode")
	
	# Restore normal cursor
	restore_normal_cursor()
	
	# Show UI feedback
	var hud = get_tree().current_scene.get_node_or_null("UI/HUD")
	if hud and hud.has_method("show_message"):
		hud.show_message("Demolition mode disabled", 2.0)

func demolish_building_at_mouse():
	"""Demolish building at mouse position and refund materials"""
	var mouse_pos = get_corrected_mouse_position()
	var grid_pos = snap_to_grid(mouse_pos)
	
	var building = find_building_at_position(grid_pos)
	if building:
		demolish_building(building, grid_pos)
	else:
		print("DEMOLITION: No building found at position %s" % grid_pos)

func find_building_at_position(position: Vector2) -> Node2D:
	"""Find a building node at the specified grid position"""
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_container:
		return null
	
	# Check all buildings for one at this position (with larger tolerance for better click detection)
	var closest_building: Node2D = null
	var closest_distance: float = 32.0  # Maximum search distance (one grid cell)
	
	for building in buildings_container.get_children():
		var building_pos = snap_to_grid(building.global_position)
		var distance = building_pos.distance_to(position)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_building = building
	
	return closest_building

func demolish_building(building_node: Node2D, position: Vector2):
	"""Demolish a specific building and refund materials"""
	var building_id = extract_building_id_from_node(building_node)
	if building_id.is_empty():
		print("DEMOLITION: Could not determine building type for demolition")
		return
	
	# Get refund amounts from building data
	var building_system = get_node_or_null("/root/BuildingManager")  
	var building_data_dict = {}
	
	# Load building data from JSON
	if building_system and building_system.has_method("get_building_costs"):
		building_data_dict = building_system.get_building_costs(building_id)
	else:
		# Fallback: load building data directly
		var buildings_file = "res://data/buildings.json"
		if ResourceLoader.exists(buildings_file):
			var file = FileAccess.open(buildings_file, FileAccess.READ)
			if file:
				var json_text = file.get_as_text()
				file.close()
				var json = JSON.new()
				var parse_result = json.parse(json_text)
				if parse_result == OK:
					building_data_dict = json.data.get(building_id, {})
	
	var refund_amounts = building_data_dict.get("refund", {})
	
	if refund_amounts.is_empty():
		print("DEMOLITION: No refund data found for building type: %s" % building_id)
		# Still allow demolition, just no refund
	else:
		# Give refund materials to player
		refund_building_materials(refund_amounts)
		print("DEMOLITION: Refunded materials for %s: %s" % [building_id, refund_amounts])
	
	# Handle special building cleanup
	cleanup_building_systems(building_node, building_id, position)
	
	# Remove the building from scene
	building_node.queue_free()
	
	# Emit signal
	building_demolished.emit(building_id, position)
	
	print("DEMOLITION: Successfully demolished %s at %s" % [building_id, position])

func extract_building_id_from_node(building_node: Node2D) -> String:
	"""Extract building ID from building node name or properties"""
	var node_name = building_node.name
	
	# List of known building IDs in order of specificity (most specific first)
	var known_building_ids = [
		"hand_crank_generator", "reinforced_wall", "reinforced_roof", 
		"basic_wall", "basic_floor", "basic_roof", "storage_box",
		"oxygen_tank", "workbench", "door"
	]
	
	# First try direct matching with known building types
	for building_id in known_building_ids:
		if node_name.to_lower().begins_with(building_id.to_lower()):
			return building_id
	
	# Fallback: try parsing "building_id_timestamp" format
	var parts = node_name.split("_")
	if parts.size() >= 2:
		# Check if last part looks like a timestamp (all digits)
		var last_part = parts[-1]
		if last_part.is_valid_int() and last_part.length() >= 10:  # Unix timestamp
			# Remove the timestamp part and reconstruct building ID
			var building_id_parts = parts.slice(0, parts.size() - 1)
			var building_id = "_".join(building_id_parts)
			return building_id
	
	# Final fallback: contains matching
	for building_id in known_building_ids:
		if node_name.to_lower().contains(building_id.to_lower()):
			return building_id
	
	return ""

func refund_building_materials(refund_amounts: Dictionary):
	"""Add refund materials to player inventory"""
	if not InventorySystem:
		print("DEMOLITION: InventorySystem not found, cannot refund materials")
		return
	
	for resource_id in refund_amounts.keys():
		var amount = refund_amounts[resource_id]
		var success = InventorySystem.add_item(resource_id, amount)
		if success:
			print("DEMOLITION: Refunded %d %s" % [amount, resource_id])
		else:
			print("DEMOLITION: Failed to refund %d %s (inventory full?)" % [amount, resource_id])

func cleanup_building_systems(_building_node: Node2D, building_id: String, position: Vector2):
	"""Handle cleanup of building-specific systems when demolishing"""
	
	# Roof visibility cleanup
	if building_id.contains("roof"):
		var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
		if roof_manager:
			roof_manager.unregister_roof_tile(position)
			print("DEMOLITION: Unregistered roof tile from visibility manager")
	
	# Door cleanup
	elif building_id == "door":
		# Remove door from any door tracking systems
		# The door functionality should clean up automatically when node is freed
		pass
	
	# Storage cleanup - preserve items if possible
	elif building_id == "storage_box":
		# TODO: Drop stored items on ground or try to transfer to player inventory
		pass
	
	# Notify interior detection system
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system:
		interior_system.call_deferred("refresh_building_structures")
		print("DEMOLITION: Notified interior detection system of building removal")

func update_demolition_cursor():
	"""Provide visual feedback for demolition mode"""
	# Check if there's a building at cursor position for additional visual feedback
	var mouse_pos = get_corrected_mouse_position()
	var grid_pos = snap_to_grid(mouse_pos)
	var building = find_building_at_position(grid_pos)
	
	# Could add highlighting or color changes here in the future
	# For now, the custom cursor icon provides the main visual feedback

func get_corrected_mouse_position() -> Vector2:
	"""Get mouse position corrected for viewport scaling and camera transforms"""
	return get_global_mouse_position()

func set_demolition_cursor():
	"""Set cursor to demolition/destroy icon"""
	var cursor_image = create_demolition_cursor_image()
	if cursor_image:
		Input.set_custom_mouse_cursor(cursor_image, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		# Fallback: use system forbidden cursor
		Input.set_custom_mouse_cursor(null, Input.CURSOR_FORBIDDEN)

func restore_normal_cursor():
	"""Restore normal mouse cursor"""
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)

func create_demolition_cursor_image() -> ImageTexture:
	"""Create a custom demolition cursor image"""
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)

	# Fill with transparent background
	image.fill(Color(0, 0, 0, 0))

	# Draw a red X for demolition
	var red = Color.RED
	var thickness = 2

	# Draw diagonal lines for X shape
	for i in range(size):
		for t in range(thickness):
			# Top-left to bottom-right diagonal
			var x1 = i
			var y1 = i + t
			if x1 < size and y1 < size:
				image.set_pixel(x1, y1, red)

			# Top-right to bottom-left diagonal
			var x2 = size - 1 - i
			var y2 = i + t
			if x2 >= 0 and y2 < size:
				image.set_pixel(x2, y2, red)

			# Make lines thicker
			if t == 1:
				if x1 + 1 < size and y1 < size:
					image.set_pixel(x1 + 1, y1, red)
				if x2 - 1 >= 0 and y2 < size:
					image.set_pixel(x2 - 1, y2, red)

	# Add a small circle around the X for better visibility
	var center = size / 2
	var radius = 14
	for x in range(size):
		for y in range(size):
			var dx = x - center
			var dy = y - center
			var distance = sqrt(dx * dx + dy * dy)

			# Draw circle outline
			if abs(distance - radius) < 1.5:
				image.set_pixel(x, y, Color(0.8, 0.2, 0.2, 0.8))  # Semi-transparent red circle

	# Create texture from image
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

# 3D compatibility function - convert 3D position to 2D for compatibility with existing systems
func snap_to_grid_3d(pos) -> Vector2:
	"""Convert 3D position to 2D grid position for compatibility"""
	if pos is Vector3:
		# Convert 3D position to 2D: X stays X, Z becomes Y
		var pos_2d = Vector2(pos.x, pos.z)
		return snap_to_grid(pos_2d)
	elif pos is Vector2:
		return snap_to_grid(pos)
	else:
		print("ERROR: snap_to_grid_3d received invalid position type")
		return Vector2.ZERO
