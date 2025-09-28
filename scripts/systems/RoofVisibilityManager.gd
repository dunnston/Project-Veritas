extends Node

var roof_tiles: Dictionary = {}  # position -> roof_node
var interior_detection: Node = null
var tween: Tween

# Visibility states
enum VisibilityState {
	VISIBLE,      # Fully visible (player outside)
	TRANSPARENT,  # Semi-transparent (transitioning)
	HIDDEN        # Fully hidden (player inside)
}

var current_state: VisibilityState = VisibilityState.VISIBLE
var target_opacity: float = 1.0
var transition_speed: float = 0.3  # Seconds for transition

func _ready():
	# Get reference to interior detection system - delay to ensure it's loaded
	call_deferred("setup_interior_connection")
	
	# Create tween for smooth transitions (Godot 4 style)
	tween = create_tween()
	
	# Scan for existing roofs
	call_deferred("scan_existing_roofs")

func setup_interior_connection():
	"""Set up connection to interior detection system"""
	interior_detection = get_node_or_null("/root/InteriorDetectionSystem")
	
	if interior_detection:
		print("ROOF DEBUG: Found InteriorDetectionSystem, connecting signals...")
		interior_detection.player_entered_interior.connect(_on_player_entered_interior)
		interior_detection.player_exited_interior.connect(_on_player_exited_interior)
		print("ROOF DEBUG: Connected to InteriorDetectionSystem signals")
	else:
		print("ROOF DEBUG: InteriorDetectionSystem not found - retrying in 1 second")
		# Retry connection after 1 second
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.timeout.connect(setup_interior_connection)
		add_child(timer)
		timer.start()

func scan_existing_roofs():
	"""Find all existing roof tiles in the scene"""
	roof_tiles.clear()
	
	var buildings_container = get_tree().current_scene.get_node_or_null("Buildings")
	if not buildings_container:
		return
	
	for building in buildings_container.get_children():
		if building.name.to_lower().contains("roof"):
			var pos = snap_to_grid(building.global_position)
			roof_tiles[pos] = building
			print("ROOF: Registered roof tile at %s" % pos)

func register_roof_tile(position: Vector2, roof_node: Node2D):
	"""Register a new roof tile for visibility management"""
	var grid_pos = snap_to_grid(position)
	roof_tiles[grid_pos] = roof_node
	print("ROOF: Registered new roof tile at %s" % grid_pos)
	
	# Apply current visibility state to new roof
	apply_visibility_to_roof(roof_node, get_current_opacity())

func unregister_roof_tile(position: Vector2):
	"""Remove a roof tile from visibility management"""
	var grid_pos = snap_to_grid(position)
	if grid_pos in roof_tiles:
		roof_tiles.erase(grid_pos)
		print("ROOF: Unregistered roof tile at %s" % grid_pos)

func _on_player_entered_interior(building_id: String):
	"""Player entered a building - hide roofs for that building"""
	print("ROOF DEBUG: Player entered building %s, hiding roofs (current state: %s)" % [building_id, current_state])
	print("ROOF DEBUG: Managed roof tiles: %d" % roof_tiles.size())
	set_roof_visibility_state(VisibilityState.HIDDEN)

func _on_player_exited_interior(building_id: String):
	"""Player exited building - show all roofs"""
	print("ROOF DEBUG: Player exited building %s, showing roofs (current state: %s)" % [building_id, current_state])
	print("ROOF DEBUG: Managed roof tiles: %d" % roof_tiles.size()) 
	set_roof_visibility_state(VisibilityState.VISIBLE)

func set_roof_visibility_state(new_state: VisibilityState):
	"""Change roof visibility state with smooth transition"""
	if current_state == new_state:
		print("ROOF DEBUG: Already in state %s, skipping" % new_state)
		return
		
	print("ROOF DEBUG: Changing state from %s to %s" % [current_state, new_state])
	current_state = new_state
	
	match new_state:
		VisibilityState.VISIBLE:
			target_opacity = 1.0
		VisibilityState.TRANSPARENT:
			target_opacity = 0.5
		VisibilityState.HIDDEN:
			target_opacity = 0.0
	
	print("ROOF DEBUG: Target opacity set to %.2f for %d roof tiles" % [target_opacity, roof_tiles.size()])
	
	# If no roofs registered, try to scan again
	if roof_tiles.is_empty():
		print("ROOF DEBUG: No roofs registered, scanning again...")
		scan_existing_roofs()
	
	# Start smooth transition
	transition_roof_visibility(target_opacity)

func transition_roof_visibility(target_alpha: float):
	"""Smoothly transition roof visibility"""
	var current_opacity = get_current_opacity()
	print("ROOF DEBUG: Transitioning from %.2f to %.2f opacity for %d roof tiles" % [current_opacity, target_alpha, roof_tiles.size()])

	# Skip transition if already at target
	if abs(current_opacity - target_alpha) < 0.01:
		print("ROOF DEBUG: Already at target opacity, skipping transition")
		return

	# Skip if no roof tiles to transition
	if roof_tiles.is_empty():
		print("ROOF DEBUG: No roof tiles to transition")
		return

	# Stop any existing tween
	if tween and tween.is_valid():
		tween.kill()

	# Create new tween
	tween = create_tween()
	tween.set_parallel(true)
	
	# If no transition needed (instant), apply directly
	if transition_speed <= 0.0:
		print("ROOF DEBUG: Instant transition (speed %.2f)" % transition_speed)
		for roof_node in roof_tiles.values():
			if is_instance_valid(roof_node):
				apply_visibility_to_roof(roof_node, target_alpha)
		return
	
	# Tween each roof tile individually
	var tweened_count = 0
	for roof_node in roof_tiles.values():
		if is_instance_valid(roof_node):
			print("ROOF DEBUG: Setting up tween for roof at %s (from %.2f to %.2f)" % [roof_node.global_position, current_opacity, target_alpha])
			
			# Create individual tween for this roof
			tween.tween_method(
				func(alpha: float): apply_visibility_to_roof(roof_node, alpha),
				current_opacity,
				target_alpha,
				transition_speed
			)
			
			tweened_count += 1
	
	print("ROOF DEBUG: Started transition on %d roof tiles" % tweened_count)

func apply_visibility_to_roof(roof_node: Node2D, alpha: float):
	"""Apply visibility (alpha) to a specific roof node"""
	if not is_instance_valid(roof_node):
		print("ROOF DEBUG: Invalid roof node, skipping")
		return
	
	print("ROOF DEBUG: Applying alpha %.2f to roof at %s" % [alpha, roof_node.global_position])
	
	# Find the sprite (first Sprite2D child)
	var sprite: Sprite2D = null
	for child in roof_node.get_children():
		if child is Sprite2D:
			sprite = child
			break
	
	if sprite:
		sprite.modulate.a = alpha
		print("ROOF DEBUG: Applied alpha %.2f to sprite, result: %.2f" % [alpha, sprite.modulate.a])
	else:
		# If no sprite found, apply to the node itself if it has modulate
		if roof_node.has_method("set_modulate"):
			var current_color = roof_node.modulate
			roof_node.modulate = Color(current_color.r, current_color.g, current_color.b, alpha)
			print("ROOF DEBUG: Applied alpha %.2f to roof node, result: %.2f" % [alpha, roof_node.modulate.a])
		else:
			print("ROOF DEBUG: Roof node has no sprite or modulate method!")

func get_current_opacity() -> float:
	"""Get the current opacity of roof tiles"""
	if roof_tiles.is_empty():
		print("ROOF DEBUG: No roof tiles, returning target_opacity: %.2f" % target_opacity)
		return target_opacity
		
	# Get opacity from first available roof - check both sprite and node
	for roof_node in roof_tiles.values():
		if is_instance_valid(roof_node):
			# First try to find a Sprite2D child
			var sprite: Sprite2D = null
			for child in roof_node.get_children():
				if child is Sprite2D:
					sprite = child
					break
			
			if sprite:
				var current_alpha = sprite.modulate.a
				print("ROOF DEBUG: Found sprite with opacity: %.2f" % current_alpha)
				return current_alpha
			
			# If no sprite, try the roof node itself
			var current_alpha = roof_node.modulate.a
			print("ROOF DEBUG: Using roof node opacity: %.2f" % current_alpha)
			return current_alpha
	
	print("ROOF DEBUG: No valid roof found, returning target_opacity: %.2f" % target_opacity)
	return target_opacity

func get_roofs_in_building(building_id: String) -> Array[Node2D]:
	"""Get all roof tiles that belong to a specific building"""
	var building_roofs: Array[Node2D] = []
	
	if not interior_detection:
		return building_roofs
		
	var building_data = interior_detection.get_building_data(building_id)
	if building_data.is_empty():
		return building_roofs
		
	# Check which roof tiles are within this building's bounds
	var bounds = building_data.bounds
	
	for pos in roof_tiles.keys():
		if (pos.x >= bounds.min_x and pos.x <= bounds.max_x and
			pos.y >= bounds.min_y and pos.y <= bounds.max_y):
			building_roofs.append(roof_tiles[pos])
	
	return building_roofs

func snap_to_grid(pos: Vector2, grid_size: int = 32) -> Vector2:
	"""Snap position to grid - same as BuildingSystem"""
	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

# Debug functions
func get_roof_count() -> int:
	"""Get total number of registered roof tiles"""
	return roof_tiles.size()

func get_roof_positions() -> Array[Vector2]:
	"""Get all roof tile positions"""
	var positions: Array[Vector2] = []
	for pos in roof_tiles.keys():
		positions.append(pos)
	return positions

func force_refresh_roofs():
	"""Force refresh all roof tiles (useful for debugging)"""
	scan_existing_roofs()
	apply_current_visibility()

func apply_current_visibility():
	"""Apply current visibility state to all roofs"""
	print("ROOF DEBUG: Applying current visibility (%.2f) to %d roof tiles" % [target_opacity, roof_tiles.size()])
	for roof_node in roof_tiles.values():
		if is_instance_valid(roof_node):
			apply_visibility_to_roof(roof_node, target_opacity)

func force_immediate_visibility(alpha: float):
	"""Force immediate visibility change without tween"""
	print("ROOF DEBUG: Force setting all roofs to alpha %.2f" % alpha)
	target_opacity = alpha
	apply_current_visibility()
