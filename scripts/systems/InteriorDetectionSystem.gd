extends Node

signal player_entered_interior(building_id: String)
signal player_exited_interior(building_id: String)

var player_inside_building: String = ""  # Empty string means outside
var building_structures: Dictionary = {}  # building_id -> structure_data
var roof_visibility_manager: Node = null

func _ready():
	# Connect to building placement signals
	call_deferred("setup_building_connection")

func setup_building_connection():
	var building_system = get_node_or_null("/root/BuildingSystem")
	if building_system:
		building_system.building_placed.connect(_on_building_placed)
		print("INTERIOR: Connected to BuildingSystem")
	else:
		print("INTERIOR: BuildingSystem not found - retrying in 1 second")
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.timeout.connect(setup_building_connection)
		add_child(timer)
		timer.start()

func _on_building_placed(building_id: String, position: Vector2):
	# When any building is placed, refresh building detection
	call_deferred("refresh_building_structures")

func refresh_building_structures():
	"""Scan all placed buildings and identify complete structures"""
	print("INTERIOR DEBUG: refresh_building_structures called")
	building_structures.clear()
	
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_container:
		print("INTERIOR DEBUG: No Buildings container found")
		return
		
	print("INTERIOR DEBUG: Found Buildings container with %d children" % buildings_container.get_child_count())
	
	# Collect all building positions by type
	var floors: Array[Vector2] = []
	var walls: Array[Vector2] = []
	var doors: Array[Vector2] = []
	var roofs: Array[Vector2] = []
	
	for building in buildings_container.get_children():
		var building_system = get_node_or_null("/root/BuildingSystem")
		var pos
		if building_system:
			pos = building_system.snap_to_grid(building.global_position)
		else:
			pos = snap_to_grid(building.global_position)
		var building_name = building.name.to_lower()
		
		if building_name.contains("floor"):
			floors.append(pos)
		elif building_name.contains("wall"):
			walls.append(pos)
		elif building_name.contains("door"):
			doors.append(pos)
		elif building_name.contains("roof"):
			roofs.append(pos)
	
	print("INTERIOR DEBUG: Found %d floors, %d walls, %d doors, %d roofs" % [floors.size(), walls.size(), doors.size(), roofs.size()])
	
	# Identify complete structures
	identify_complete_buildings(floors, walls, doors, roofs)

func identify_complete_buildings(floors: Array[Vector2], walls: Array[Vector2], doors: Array[Vector2], roofs: Array[Vector2]):
	"""Find complete rectangular structures with floors, walls, doors, and roofs"""
	
	# Group floors into potential rectangles
	var floor_groups = find_rectangular_areas(floors)
	
	for i in range(floor_groups.size()):
		var floor_group = floor_groups[i]
		var building_id = "building_" + str(i)
		
		# Check if this floor group has complete walls, doors, and roofs
		var structure_data = analyze_structure(floor_group, walls, doors, roofs)
		
		if structure_data.is_complete:
			building_structures[building_id] = structure_data
			print("INTERIOR: Found complete building %s with %d floors" % [building_id, floor_group.size()])

func find_rectangular_areas(positions: Array[Vector2]) -> Array[Array]:
	"""Group connected floor tiles into rectangular areas"""
	var groups: Array[Array] = []
	var processed: Array[Vector2] = []
	
	for pos in positions:
		if pos in processed:
			continue
			
		# Find all connected floors from this position
		var group = flood_fill_floors(pos, positions, processed)
		if group.size() >= 4:  # Minimum 2x2 interior
			groups.append(group)
	
	return groups

func flood_fill_floors(start: Vector2, all_floors: Array[Vector2], processed: Array[Vector2]) -> Array[Vector2]:
	"""Flood fill to find connected floor tiles"""
	var group: Array[Vector2] = []
	var queue: Array[Vector2] = [start]
	
	while queue.size() > 0:
		var pos = queue.pop_front()
		if pos in processed or pos not in all_floors:
			continue
			
		processed.append(pos)
		group.append(pos)
		
		# Check 4 adjacent positions
		var adjacents = [
			pos + Vector2(32, 0),   # Right
			pos + Vector2(-32, 0),  # Left  
			pos + Vector2(0, 32),   # Down
			pos + Vector2(0, -32)   # Up
		]
		
		for adj in adjacents:
			if adj in all_floors and adj not in processed:
				queue.append(adj)
	
	return group

func analyze_structure(floor_group: Array[Vector2], walls: Array[Vector2], doors: Array[Vector2], roofs: Array[Vector2]) -> Dictionary:
	"""Check if a floor group has complete walls, doors, and roofs around it"""
	
	# Find bounding box of floor group
	var min_x = floor_group[0].x
	var max_x = floor_group[0].x  
	var min_y = floor_group[0].y
	var max_y = floor_group[0].y
	
	for pos in floor_group:
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)
	
	# Calculate required perimeter positions
	var required_walls: Array[Vector2] = []
	var required_roofs: Array[Vector2] = []
	
	# Generate perimeter positions (walls should be on edges of floor tiles)
	for x in range(min_x, max_x + 32, 32):
		for y in range(min_y, max_y + 32, 32):
			var floor_pos = Vector2(x, y)
			if floor_pos in floor_group:
				# This is a floor tile, check if it needs walls around it
				required_roofs.append(floor_pos)  # Roof goes on top of floor
				
				# Check each adjacent position for walls needed (32-pixel grid)
				var adjacent_positions = [
					Vector2(x, y - 32),     # Top adjacent
					Vector2(x, y + 32),     # Bottom adjacent  
					Vector2(x - 32, y),     # Left adjacent
					Vector2(x + 32, y)      # Right adjacent
				]
				
				for adj_pos in adjacent_positions:
					# If there's no floor at this adjacent position, we need a wall there
					if not floor_at_position(adj_pos, floor_group):
						# Wall should be at the adjacent grid position
						if adj_pos not in required_walls:
							required_walls.append(adj_pos)
	
	# Count how many required elements we have
	var wall_coverage = count_coverage(required_walls, walls)
	var door_count = count_coverage(required_walls, doors)  # Doors can substitute walls
	var roof_coverage = count_coverage(required_roofs, roofs)
	
	var total_perimeter = required_walls.size()
	var covered_perimeter = wall_coverage + door_count
	
	var is_complete = (covered_perimeter >= total_perimeter * 0.8 and 
					   door_count >= 1 and 
					   roof_coverage >= required_roofs.size() * 0.8)
	
	# Debug output for structure analysis
	print("INTERIOR DEBUG STRUCTURE:")
	print("  Floor positions: %s" % floor_group)
	print("  Required wall positions: %s" % required_walls)
	print("  Available wall positions: %s" % walls)
	print("  Available door positions: %s" % doors)
	print("  Required walls: %d, Found: %d, Coverage: %.1f%%" % [required_walls.size(), wall_coverage, (float(wall_coverage)/max(1, required_walls.size()))*100])
	print("  Required roofs: %d, Found: %d, Coverage: %.1f%%" % [required_roofs.size(), roof_coverage, (float(roof_coverage)/max(1, required_roofs.size()))*100])
	print("  Doors: %d" % door_count)
	print("  Is complete: %s" % is_complete)
	
	return {
		"floor_positions": floor_group,
		"required_walls": required_walls,
		"required_roofs": required_roofs,
		"wall_coverage": wall_coverage,
		"door_count": door_count, 
		"roof_coverage": roof_coverage,
		"is_complete": is_complete,
		"bounds": {
			"min_x": min_x,
			"max_x": max_x,
			"min_y": min_y, 
			"max_y": max_y
		}
	}

func floor_at_position(pos: Vector2, floor_group: Array[Vector2]) -> bool:
	"""Check if there's a floor tile at the given position"""
	return pos in floor_group

func count_coverage(required: Array[Vector2], available: Array[Vector2]) -> int:
	"""Count how many required positions are covered by available positions"""
	var count = 0
	for req_pos in required:
		# Check if this required position has a building at it
		if req_pos in available:
			count += 1
	return count

func _process(_delta):
	"""Check if player has entered or exited any building"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
		
	var building_system = get_node_or_null("/root/BuildingSystem")
	var player_pos
	if building_system:
		player_pos = building_system.snap_to_grid(player.global_position)
	else:
		player_pos = snap_to_grid(player.global_position)
	var current_building = find_building_at_position(player_pos)
	
	if current_building != player_inside_building:
		# Player changed building status
		print("INTERIOR DEBUG: Player building status changed from '%s' to '%s'" % [player_inside_building, current_building])
		
		if player_inside_building != "":
			# Exiting previous building
			player_exited_interior.emit(player_inside_building)
			print("INTERIOR DEBUG: Player exited %s" % player_inside_building)
		
		if current_building != "":
			# Entering new building
			player_entered_interior.emit(current_building)
			print("INTERIOR DEBUG: Player entered %s" % current_building)
		
		player_inside_building = current_building

func find_building_at_position(pos: Vector2) -> String:
	"""Check if position is inside any complete building"""
	for building_id in building_structures.keys():
		var structure = building_structures[building_id]
		if pos in structure.floor_positions:
			return building_id
	return ""

func snap_to_grid(pos: Vector2, grid_size: int = 32) -> Vector2:
	"""Snap position to grid - same as BuildingSystem"""
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

func is_player_inside() -> bool:
	"""Check if player is currently inside any building"""
	return player_inside_building != ""

func get_current_building_id() -> String:
	"""Get the ID of the building player is currently inside"""
	return player_inside_building

func get_building_data(building_id: String) -> Dictionary:
	"""Get structure data for a specific building"""
	return building_structures.get(building_id, {})
