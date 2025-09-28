extends Node

class_name BuildingManagerSingleton

signal building_mode_changed(enabled: bool)
signal building_selected(building_id: String)
signal building_rotation_changed(rotation: int)

const GRID_SIZE = 32

var is_building_mode: bool = false
var selected_building: String = ""
var current_rotation: int = 0
var placed_buildings: Dictionary = {}
var building_data: Dictionary = {}
var ghost_building: Node2D = null

func _ready() -> void:
	load_building_data()
	print("BuildingManager initialized")

func load_building_data() -> void:
	var file_path = "res://data/buildings.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				building_data = json.data
				print("Loaded building data successfully")
			else:
				push_error("Failed to parse buildings.json")
				create_fallback_building_data()
		else:
			print("Could not open buildings.json file")
			create_fallback_building_data()
	else:
		print("buildings.json not found, creating fallback data")
		create_fallback_building_data()

func create_fallback_building_data() -> void:
	building_data = {
		"basic_wall": {
			"name": "Basic Wall",
			"cost": {"SCRAP_METAL": 5},
			"max_health": 100,
			"size": {"x": 1, "y": 1}
		}
	}
	print("Created fallback building data")

func toggle_building_mode() -> void:
	if building_data.is_empty():
		print("No building data available - cannot enter build mode")
		return
	
	is_building_mode = !is_building_mode
	building_mode_changed.emit(is_building_mode)
	
	if is_building_mode:
		print("Entering build mode")
		if not selected_building or selected_building not in building_data:
			selected_building = "basic_wall"  # Default building
		print("Selected building: " + selected_building)
		GameManager.change_state(GameManager.GameState.BUILD_MODE)
	else:
		print("Exiting build mode")
		GameManager.change_state(GameManager.GameState.IN_GAME)
		if ghost_building:
			ghost_building.queue_free()
			ghost_building = null

func select_building(building_id: String) -> void:
	if building_id in building_data:
		selected_building = building_id
		building_selected.emit(building_id)
		if not is_building_mode:
			toggle_building_mode()

func rotate_building() -> void:
	current_rotation = (current_rotation + 90) % 360
	building_rotation_changed.emit(current_rotation)
	if ghost_building:
		ghost_building.rotation_degrees = current_rotation

# 3D compatible grid snapping
func snap_to_grid(pos) -> Vector3:
	if pos is Vector2:
		# Convert 2D to 3D: X stays X, Y becomes Z, Y=0 for ground level
		return Vector3(
			round(pos.x / GRID_SIZE) * GRID_SIZE,
			0.0,
			round(pos.y / GRID_SIZE) * GRID_SIZE
		)
	elif pos is Vector3:
		return Vector3(
			round(pos.x / GRID_SIZE) * GRID_SIZE,
			pos.y,  # Keep Y height
			round(pos.z / GRID_SIZE) * GRID_SIZE
		)
	else:
		print("ERROR: snap_to_grid received invalid position type")
		return Vector3.ZERO

# Legacy 2D function for compatibility
func snap_to_grid_2d(pos: Vector2) -> Vector2:
	return Vector2(
		round(pos.x / GRID_SIZE) * GRID_SIZE,
		round(pos.y / GRID_SIZE) * GRID_SIZE
	)

# 3D compatible building placement check
func can_place_building(building_id: String, grid_pos) -> bool:
	if building_id not in building_data:
		return false
	
	# Data could be used for additional validation in the future
	var _data = building_data[building_id]
	var cost = get_building_cost(building_id)
	
	if not can_afford_building_cost(cost):
		return false
	
	var pos_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	if pos_key in placed_buildings:
		return false
	
	return true

func can_afford_building_cost(cost: Dictionary) -> bool:
	for resource_id in cost:
		var required_amount = cost[resource_id]
		if not InventorySystem.has_item(resource_id, required_amount):
			return false
	return true

func pay_building_cost(cost: Dictionary) -> bool:
	# First check if we can afford all materials
	if not can_afford_building_cost(cost):
		return false
	
	# Then remove all materials from inventory
	for resource_id in cost:
		var required_amount = cost[resource_id]
		if not InventorySystem.remove_item(resource_id, required_amount):
			# If removal fails, this shouldn't happen since we checked can_afford first
			push_error("Failed to remove building material %s x%d from inventory" % [resource_id, required_amount])
			return false
	
	return true

func place_building(building_id: String, world_pos) -> bool:
	var grid_pos = snap_to_grid(world_pos)
	
	if not can_place_building(building_id, grid_pos):
		return false
	
	# Data could be used for building instantiation in the future
	var _data = building_data[building_id]
	var cost = get_building_cost(building_id)
	
	if not pay_building_cost(cost):
		return false

	# Generate position key for both 2D and 3D
	var pos_key: String
	if grid_pos is Vector2:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	elif grid_pos is Vector3:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.z]  # Use X,Z for 3D grid
	else:
		print("ERROR: place_building generated invalid grid position")
		return false
	placed_buildings[pos_key] = {
		"id": building_id,
		"position": grid_pos,
		"rotation": current_rotation,
		"health": _data.get("max_health", 100)
	}
	
	EventBus.emit_building_placed(building_id, grid_pos)
	print("Building placed: %s at %s" % [building_id, grid_pos])
	
	# Grant Automation Engineering XP for building automation structures
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var automation_buildings = ["conveyor_belt", "inserter", "assembler", "robot_frame", "logistics_chest"]
		if building_id in automation_buildings:
			skill_system.add_xp("AUTOMATION_ENGINEERING", skill_system.XP_VALUES.CONVEYOR_BUILT, "automation_building")
	
	return true

func remove_building(grid_pos) -> bool:
	var pos_key: String
	if grid_pos is Vector2:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	elif grid_pos is Vector3:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.z]  # Use X,Z for 3D grid
	else:
		print("ERROR: remove_building received invalid position type")
		return false
	
	if pos_key not in placed_buildings:
		return false
	
	var building = placed_buildings[pos_key]
	var data = building_data[building["id"]]
	
	var refund = data.get("refund", {})
	for resource in refund:
		InventorySystem.add_item(resource, refund[resource])
	
	placed_buildings.erase(pos_key)
	EventBus.emit_building_removed(building["id"], grid_pos)
	return true

func get_building_at(grid_pos) -> Dictionary:
	var pos_key: String
	if grid_pos is Vector2:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.y]
	elif grid_pos is Vector3:
		pos_key = "%d,%d" % [grid_pos.x, grid_pos.z]  # Use X,Z for 3D grid
	else:
		print("ERROR: get_building_at received invalid position type")
		return {}
	if pos_key in placed_buildings:
		return placed_buildings[pos_key]
	return {}

func get_building_cost(building_id: String) -> Dictionary:
	# First check if building has recipe_id reference
	if building_id in building_data:
		var building_data_entry = building_data[building_id]
		var recipe_id = building_data_entry.get("recipe_id", building_id)
		
		# Try to get cost from recipe
		if CraftingManager.recipes.has(recipe_id):
			var recipe = CraftingManager.recipes[recipe_id]
			return recipe.get("ingredients", {})
		
		# Fallback to building's own cost (for backward compatibility)
		return building_data_entry.get("cost", {})
	
	return {}

func get_all_buildings() -> Dictionary:
	return placed_buildings.duplicate()

func update_ghost_building(world_pos) -> void:
	if not ghost_building or selected_building == "":
		return
	
	var grid_pos = snap_to_grid(world_pos)
	ghost_building.position = grid_pos
	
	if can_place_building(selected_building, grid_pos):
		ghost_building.modulate = Color(0, 1, 0, 0.5)
	else:
		ghost_building.modulate = Color(1, 0, 0, 0.5)
