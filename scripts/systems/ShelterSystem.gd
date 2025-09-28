extends Node

class_name ShelterSystemSingleton

signal shelter_integrity_changed(integrity_percent: float)
signal shelter_status_changed(is_fully_sheltered: bool, missing_components: Array)

enum ShelterComponent {
	WALL,
	ROOF,
	DOOR,
	FLOOR
}

enum ShelterQuality {
	NO_SHELTER,     # 0% - No protection
	BASIC_SHELTER,  # 25% - Partial walls only
	PARTIAL_SHELTER,# 50% - Walls + some roof/floor
	GOOD_SHELTER,   # 75% - Walls + roof, maybe missing floor
	COMPLETE_SHELTER# 100% - Walls + roof + floor + door
}

# Shelter detection constants
const SHELTER_CHECK_RADIUS: int = 2  # Check 5x5 area around player
const MIN_SHELTER_SIZE: int = 3      # Minimum 3x3 enclosed area
const INTEGRITY_UPDATE_INTERVAL: float = 1.0  # Check integrity every second

# Current shelter state
var current_shelter_quality: ShelterQuality = ShelterQuality.NO_SHELTER
var current_integrity_percent: float = 0.0
var is_fully_enclosed: bool = false
var missing_components: Array[ShelterComponent] = []

# Timing
var integrity_timer: float = 0.0

func _ready() -> void:
	print("ShelterSystem: Initializing shelter integrity system...")

func _process(delta: float) -> void:
	integrity_timer += delta
	if integrity_timer >= INTEGRITY_UPDATE_INTERVAL:
		integrity_timer = 0.0
		update_shelter_status()

func update_shelter_status() -> void:
	if not GameManager.player_node:
		return
	
	var player_pos = GameManager.player_node.global_position
	var shelter_data = analyze_shelter_at_position(player_pos)
	
	var new_quality = calculate_shelter_quality(shelter_data)
	var new_integrity = calculate_integrity_percent(shelter_data)
	var new_missing = find_missing_components(shelter_data)
	var is_enclosed = shelter_data.get("fully_enclosed", false)
	
	# Check if status changed
	if new_quality != current_shelter_quality or new_integrity != current_integrity_percent:
		current_shelter_quality = new_quality
		current_integrity_percent = new_integrity
		missing_components = new_missing
		is_fully_enclosed = is_enclosed
		
		shelter_integrity_changed.emit(current_integrity_percent)
		shelter_status_changed.emit(is_fully_enclosed, missing_components)
		
		print("ShelterSystem: Shelter quality: %s (%.1f%% integrity)" % [get_quality_name(new_quality), new_integrity])
		if missing_components.size() > 0:
			print("ShelterSystem: Missing: %s" % get_missing_components_text(missing_components))

func analyze_shelter_at_position(world_pos: Vector2) -> Dictionary:
	# First check if player is in a complete building structure
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system and interior_system.is_player_inside():
		var building_id = interior_system.get_current_building_id()
		var building_data = interior_system.get_building_data(building_id)
		
		if not building_data.is_empty() and building_data.is_complete:
			print("SHELTER: Player in complete building %s" % building_id)
			# Return complete shelter data
			return {
				"walls": building_data.required_walls,
				"roofs": building_data.required_roofs,
				"floors": building_data.floor_positions,
				"doors": [], # doors counted as walls in coverage
				"fully_enclosed": true,
				"total_positions": building_data.floor_positions.size(),
				"covered_positions": building_data.floor_positions.size()
			}
	
	var building_manager = get_node_or_null("/root/BuildingManager")
	var grid_pos
	if building_manager:
		grid_pos = building_manager.snap_to_grid(world_pos)
	else:
		# Fallback grid snapping
		grid_pos = Vector2(round(world_pos.x / 32) * 32, round(world_pos.y / 32) * 32)
	
	var shelter_data = {
		"walls": [],
		"roofs": [],
		"floors": [],
		"doors": [],
		"fully_enclosed": false,
		"total_positions": 0,
		"covered_positions": 0
	}
	
	# Check area around player
	var positions_to_check = []
	for x in range(-SHELTER_CHECK_RADIUS, SHELTER_CHECK_RADIUS + 1):
		for y in range(-SHELTER_CHECK_RADIUS, SHELTER_CHECK_RADIUS + 1):
			var check_pos = grid_pos + Vector2(x * 32, y * 32)  # GRID_SIZE = 32
			positions_to_check.append(check_pos)
	
	shelter_data.total_positions = positions_to_check.size()
	
	# Analyze buildings at each position
	for pos in positions_to_check:
		var building = null
		if building_manager and building_manager.has_method("get_building_at"):
			building = building_manager.get_building_at(pos)
		if building:
			var building_id = building.get("id", "")
			var building_type = get_building_shelter_type(building_id)
			
			match building_type:
				ShelterComponent.WALL:
					shelter_data.walls.append(pos)
					shelter_data.covered_positions += 1
				ShelterComponent.ROOF:
					shelter_data.roofs.append(pos)
					shelter_data.covered_positions += 1
				ShelterComponent.FLOOR:
					shelter_data.floors.append(pos)
					shelter_data.covered_positions += 1
				ShelterComponent.DOOR:
					shelter_data.doors.append(pos)
					shelter_data.covered_positions += 1
	
	# Check if area is fully enclosed (simplified)
	shelter_data.fully_enclosed = check_enclosure(grid_pos, shelter_data)
	
	return shelter_data

func get_building_shelter_type(building_id: String) -> ShelterComponent:
	# Get building data to determine shelter component type
	var building_manager = get_node_or_null("/root/BuildingManager")
	if not building_manager or not building_manager.building_data.has(building_id):
		return ShelterComponent.WALL  # Default fallback
		
	var building_data = building_manager.building_data[building_id]
	var category = building_data.get("category", "")
	
	# Map building types to shelter components
	if building_id.contains("wall"):
		return ShelterComponent.WALL
	elif building_id.contains("roof"):
		return ShelterComponent.ROOF
	elif building_id.contains("floor"):
		return ShelterComponent.FLOOR
	elif building_id.contains("door") or building_data.get("can_open", false):
		return ShelterComponent.DOOR
	elif building_data.get("provides_shelter", false):
		return ShelterComponent.WALL  # Treat shelter-providing buildings as walls
	
	# Default based on category
	match category:
		"structure":
			if building_id == "basic_wall":
				return ShelterComponent.WALL
			else:
				return ShelterComponent.FLOOR
		_:
			return ShelterComponent.WALL

func check_enclosure(center_pos: Vector2, shelter_data: Dictionary) -> bool:
	# Simplified enclosure check - requires walls/doors on perimeter
	var required_perimeter_positions = []
	
	# Get perimeter positions for a 3x3 minimum shelter
	for x in [-1, 0, 1]:
		for y in [-1, 0, 1]:
			# Only perimeter positions (not center)
			if x == -1 or x == 1 or y == -1 or y == 1:
				var pos = center_pos + Vector2(x * 32, y * 32)  # GRID_SIZE = 32
				required_perimeter_positions.append(pos)
	
	# Check if all perimeter positions have walls or doors
	var covered_perimeter = 0
	for pos in required_perimeter_positions:
		if pos in shelter_data.walls or pos in shelter_data.doors:
			covered_perimeter += 1
	
	# Consider enclosed if at least 75% of perimeter is covered
	return float(covered_perimeter) / float(required_perimeter_positions.size()) >= 0.75

func calculate_shelter_quality(shelter_data: Dictionary) -> ShelterQuality:
	var wall_count = shelter_data.walls.size()
	var roof_count = shelter_data.roofs.size()
	var floor_count = shelter_data.floors.size()
	var door_count = shelter_data.doors.size()
	var is_enclosed = shelter_data.fully_enclosed
	
	# No protection
	if wall_count == 0 and roof_count == 0:
		return ShelterQuality.NO_SHELTER
	
	# Basic shelter - some walls
	if wall_count > 0 and not is_enclosed:
		return ShelterQuality.BASIC_SHELTER
	
	# Partial shelter - enclosed but missing roof/floor
	if is_enclosed and roof_count < 3:
		return ShelterQuality.PARTIAL_SHELTER
	
	# Good shelter - walls + roof, maybe missing floor
	if is_enclosed and roof_count >= 3 and floor_count < 3:
		return ShelterQuality.GOOD_SHELTER
	
	# Complete shelter - all components
	if is_enclosed and roof_count >= 3 and floor_count >= 3:
		return ShelterQuality.COMPLETE_SHELTER
	
	return ShelterQuality.BASIC_SHELTER

func calculate_integrity_percent(shelter_data: Dictionary) -> float:
	var base_percent = 0.0
	
	# Wall contribution (40% max)
	var wall_coverage = min(float(shelter_data.walls.size()) / 8.0, 1.0)  # 8 perimeter positions
	base_percent += wall_coverage * 40.0
	
	# Roof contribution (30% max)
	var roof_coverage = min(float(shelter_data.roofs.size()) / 9.0, 1.0)  # 3x3 area
	base_percent += roof_coverage * 30.0
	
	# Floor contribution (20% max)
	var floor_coverage = min(float(shelter_data.floors.size()) / 9.0, 1.0)
	base_percent += floor_coverage * 20.0
	
	# Enclosure bonus (10% max)
	if shelter_data.fully_enclosed:
		base_percent += 10.0
	
	return min(base_percent, 100.0)

func find_missing_components(shelter_data: Dictionary) -> Array[ShelterComponent]:
	var missing: Array[ShelterComponent] = []
	
	if shelter_data.walls.size() < 6:  # Need most perimeter covered
		missing.append(ShelterComponent.WALL)
	
	if shelter_data.roofs.size() < 3:  # Need basic roof coverage
		missing.append(ShelterComponent.ROOF)
	
	if shelter_data.floors.size() < 1:  # Need some flooring
		missing.append(ShelterComponent.FLOOR)
	
	if shelter_data.doors.size() < 1 and shelter_data.fully_enclosed:  # Need access
		missing.append(ShelterComponent.DOOR)
	
	return missing

# Public getters for other systems
func get_shelter_protection_multiplier() -> float:
	# Returns storm protection based on shelter quality
	match current_shelter_quality:
		ShelterQuality.NO_SHELTER:
			return 0.0      # No protection
		ShelterQuality.BASIC_SHELTER:
			return 0.25     # 25% protection
		ShelterQuality.PARTIAL_SHELTER:
			return 0.5      # 50% protection
		ShelterQuality.GOOD_SHELTER:
			return 0.75     # 75% protection
		ShelterQuality.COMPLETE_SHELTER:
			return 1.0      # Full protection
		_:
			return 0.0

func is_player_fully_sheltered() -> bool:
	return current_shelter_quality == ShelterQuality.COMPLETE_SHELTER

func get_current_shelter_quality() -> ShelterQuality:
	return current_shelter_quality

func get_current_integrity_percent() -> float:
	return current_integrity_percent

func get_missing_components() -> Array[ShelterComponent]:
	return missing_components

# Utility functions
func get_quality_name(quality: ShelterQuality) -> String:
	match quality:
		ShelterQuality.NO_SHELTER:
			return "No Shelter"
		ShelterQuality.BASIC_SHELTER:
			return "Basic Shelter"
		ShelterQuality.PARTIAL_SHELTER:
			return "Partial Shelter"
		ShelterQuality.GOOD_SHELTER:
			return "Good Shelter"
		ShelterQuality.COMPLETE_SHELTER:
			return "Complete Shelter"
		_:
			return "Unknown"

func get_component_name(component: ShelterComponent) -> String:
	match component:
		ShelterComponent.WALL:
			return "Walls"
		ShelterComponent.ROOF:
			return "Roof"
		ShelterComponent.FLOOR:
			return "Floor"
		ShelterComponent.DOOR:
			return "Door"
		_:
			return "Unknown"

func get_missing_components_text(missing: Array) -> String:
	var names = []
	for component in missing:
		names.append(get_component_name(component))
	return ", ".join(names)

# Debug functions
func force_update_shelter() -> void:
	update_shelter_status()

func debug_print_shelter_status() -> void:
	print("=== SHELTER DEBUG ===")
	print("Quality: %s" % get_quality_name(current_shelter_quality))
	print("Integrity: %.1f%%" % current_integrity_percent)
	print("Fully Enclosed: %s" % is_fully_enclosed)
	print("Protection Multiplier: %.1f%%" % (get_shelter_protection_multiplier() * 100))
	if missing_components.size() > 0:
		print("Missing: %s" % get_missing_components_text(missing_components))
	print("====================")
