extends Node3D
class_name BuildingPreview3D

var mesh_instance: MeshInstance3D = null
var collision_area: Area3D = null

var building_id: String = ""
var can_place: bool = false
var material_valid: StandardMaterial3D
var material_invalid: StandardMaterial3D
var overlapping_bodies: Array = []
var ground_raycast_length: float = 100.0  # How far down to check for ground
var ground_clearance: float = 0.05  # Small offset above ground to prevent z-fighting
var last_roof_had_wall: bool = true  # Track roof wall state to reduce spam

signal placement_validity_changed(is_valid: bool)

func _ready():
	# Create materials for valid/invalid placement
	setup_materials()

func setup_materials():
	# Green material for valid placement
	material_valid = StandardMaterial3D.new()
	material_valid.albedo_color = Color.GREEN
	material_valid.flags_transparent = true
	material_valid.albedo_color.a = 0.7
	material_valid.emission_enabled = true
	material_valid.emission = Color.GREEN
	material_valid.emission_energy_multiplier = 0.3

	# Red material for invalid placement
	material_invalid = StandardMaterial3D.new()
	material_invalid.albedo_color = Color.RED
	material_invalid.flags_transparent = true
	material_invalid.albedo_color.a = 0.7
	material_invalid.emission_enabled = true
	material_invalid.emission = Color.RED
	material_invalid.emission_energy_multiplier = 0.3

func setup_preview(id: String, mesh: Mesh = null):
	building_id = id

	var box_size = Vector3(2, 1, 1)  # Default size

	# Only create mesh_instance if mesh is provided (not CSG-based)
	if mesh:
		if not mesh_instance:
			mesh_instance = MeshInstance3D.new()
			add_child(mesh_instance)

		mesh_instance.mesh = mesh
		if mesh is BoxMesh:
			box_size = (mesh as BoxMesh).size
	elif not has_node("CSGBox3D"):
		# No mesh and no CSG = create default mesh for workbench/etc
		if not mesh_instance:
			mesh_instance = MeshInstance3D.new()
			add_child(mesh_instance)

		var box_mesh = BoxMesh.new()
		box_mesh.size = box_size
		mesh_instance.mesh = box_mesh
	else:
		# CSG-based preview - get size from CSG node
		var csg_node = get_node("CSGBox3D")
		if csg_node and csg_node is CSGBox3D:
			box_size = csg_node.size

	# Create collision detection area
	setup_collision_area(box_size)

	# Set initial material
	set_validity(false)

func set_validity(is_valid: bool):
	can_place = is_valid

	# Apply material to mesh_instance if it exists
	if mesh_instance:
		if is_valid:
			mesh_instance.material_override = material_valid
		else:
			mesh_instance.material_override = material_invalid
	else:
		# For CSG-based previews (like door_frame), find and apply material to CSG node
		var csg_node = get_node_or_null("CSGBox3D")
		if csg_node:
			if is_valid:
				csg_node.material = material_valid
			else:
				csg_node.material = material_invalid

	placement_validity_changed.emit(is_valid)

func update_position(world_pos: Vector3):
	# Different grid snapping based on building type
	var grid_size = 4.0
	var grid_pos: Vector3

	if building_id.contains("wall") or building_id.contains("door_frame"):
		# Walls and door frames use 2m grid (half-grid) to sit on floor edges
		var half_grid = grid_size / 2.0
		grid_pos = snap_wall_to_floor_edge(world_pos, half_grid)
	elif building_id == "door":
		# Doors snap to door_frame openings
		grid_pos = snap_door_to_frame(world_pos)
	else:
		# Floors, roofs use full 4m grid
		grid_pos = Vector3(
			round(world_pos.x / grid_size) * grid_size,
			world_pos.y,
			round(world_pos.z / grid_size) * grid_size
		)

	# Get mesh size for calculations
	var mesh_height = 1.0
	print("DEBUG %s: mesh_instance exists: %s" % [building_id, mesh_instance != null])

	# Try to get height from mesh_instance first
	if mesh_instance and mesh_instance.mesh and mesh_instance.mesh is BoxMesh:
		var box_mesh = mesh_instance.mesh as BoxMesh
		mesh_height = box_mesh.size.y
		print("DEBUG %s: Detected mesh size from mesh_instance: %s (height=%.2f)" % [building_id, box_mesh.size, mesh_height])
	else:
		# Check for CSG-based preview (like door_frame)
		var csg_node = get_node_or_null("CSGBox3D")
		print("DEBUG %s: Looking for CSG node, found: %s" % [building_id, csg_node != null])
		if csg_node and csg_node is CSGBox3D:
			mesh_height = csg_node.size.y
			print("DEBUG %s: Detected mesh size from CSG: %s (height=%.2f)" % [building_id, csg_node.size, mesh_height])
		else:
			print("DEBUG %s: No mesh or CSG - using default height 1.0" % building_id)

	# Perform downward raycast to find the actual ground below this position
	var ground_y = find_ground_below(grid_pos)

	# If we found ground, snap to it
	if ground_y != null:
		# For floor pieces (thin, horizontal pieces), place directly on ground
		# For other pieces (walls, etc.), offset by half height
		if building_id.contains("floor"):
			# Floor tiles: Place center at ground level so floor sits ON the ground, not above it
			# The 0.1m thick floor will extend -0.05 to +0.05 from center
			# This means bottom will be slightly below ground_y (by 0.05m)
			# and top will be slightly above (by 0.05m) - this creates a flush floor surface
			grid_pos.y = ground_y
			print("DEBUG Floor: ground_y=%.3f, mesh_height=%.3f, final_y=%.3f (bottom at %.3f, top at %.3f)" %
				[ground_y, mesh_height, grid_pos.y, grid_pos.y - mesh_height * 0.5, grid_pos.y + mesh_height * 0.5])
		elif building_id.contains("roof"):
			# Roofs: MUST have walls below to be placeable
			var wall_height = detect_wall_height_at_position(grid_pos)
			if wall_height > 0:
				# Found wall - wall_height is already the TOP of the wall
				# Place roof with minimal overlap to prevent z-fighting
				# Overlap by 0.01m (1cm) for clean connection
				var overlap = 0.01
				grid_pos.y = wall_height + (mesh_height * 0.5) - overlap
				var roof_bottom = grid_pos.y - (mesh_height * 0.5)
				print("Roof placement: wall_top=%.3f, roof_center=%.3f, roof_bottom=%.3f (overlap=%.3fm)" %
					[wall_height, grid_pos.y, roof_bottom, wall_height - roof_bottom])
			else:
				# No wall found - show roof at ground level but mark as invalid
				# This keeps the preview visible so player can see where they're trying to place
				grid_pos.y = ground_y + 2.0  # Show at reasonable height for visibility
		else:
			# Walls, doors, etc.: Place bottom flush with ground, just like floors
			# Center = ground_y + half_height (no clearance - we want flush placement)
			grid_pos.y = ground_y + (mesh_height * 0.5)
			print("DEBUG Wall: ground_y=%.3f, mesh_height=%.3f, final_y=%.3f (bottom at %.3f, top at %.3f)" %
				[ground_y, mesh_height, grid_pos.y, grid_pos.y - mesh_height * 0.5, grid_pos.y + mesh_height * 0.5])
	else:
		# No ground found - use the original Y position from mouse raycast
		grid_pos.y = world_pos.y + (mesh_height * 0.5) + ground_clearance

	global_position = grid_pos

	# Force immediate validity check after moving
	# Wait one physics frame for collision updates
	await get_tree().physics_frame

	# Special case: Check if roof has wall support BEFORE normal validity check
	if building_id.contains("roof"):
		var wall_height = detect_wall_height_at_position(grid_pos)
		var has_wall = wall_height > 0

		# Only print debug when state changes
		if has_wall != last_roof_had_wall:
			if has_wall:
				print("Roof: Wall support detected at height %.2f" % wall_height)
			else:
				print("Roof: No wall support - cannot place here")
			last_roof_had_wall = has_wall

		if not has_wall:
			# No wall support - mark as invalid
			set_validity(false)
			return  # Skip normal recheck_validity

	recheck_validity()

func recheck_validity():
	# Let the physics engine update and re-detect overlaps
	if collision_area:
		# Force area to re-check overlaps at new position
		overlapping_bodies.clear()
		var all_body_overlaps = collision_area.get_overlapping_bodies()
		var all_area_overlaps = collision_area.get_overlapping_areas()
		print("DEBUG: Rechecking validity - found %d bodies, %d areas" % [all_body_overlaps.size(), all_area_overlaps.size()])

		# ALSO check with a physics shape query for more accuracy
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()

		# Use the collision area's shape
		if collision_area.get_child_count() > 0:
			var collision_shape_node = collision_area.get_child(0)
			if collision_shape_node is CollisionShape3D and collision_shape_node.shape:
				query.shape = collision_shape_node.shape
				# Use the collision shape's global transform to include rotation
				query.transform = collision_shape_node.global_transform
				query.collision_mask = 0xFFFFFFFF  # Check all layers

				# Exclude player
				var player = get_tree().get_first_node_in_group("player")
				if player:
					query.exclude = [player.get_rid()]

				var shape_results = space_state.intersect_shape(query)
				print("DEBUG: Shape query found %d intersections" % shape_results.size())

				for result in shape_results:
					var collider = result.collider
					print("  Shape query found: %s (type: %s)" % [collider.name, collider.get_class()])

					# Skip ground
					if collider.name == "Ground" or collider.is_in_group("terrain"):
						print("    -> Skipped: ground/terrain")
						continue
					# Skip ground-like
					if _is_ground_like(collider):
						print("    -> Skipped: ground-like")
						continue
					# SPECIAL CASE: Walls can overlap with roofs
					if building_id.contains("wall") and collider.name.contains("roof"):
						print("    -> Skipped: wall can overlap with roof")
						continue
					# SPECIAL CASE: Walls can overlap with door_frame_with_door
					if building_id.contains("wall") and collider.name.contains("door_frame_with_door"):
						print("    -> Skipped: wall can overlap with door_frame_with_door")
						continue
					# SPECIAL CASE: Doors can overlap with door_frames
					if building_id == "door" and collider.name.contains("door_frame"):
						print("    -> Skipped: door can overlap with door_frame")
						continue
					# SPECIAL CASE: Door frames can overlap with doors
					if building_id.contains("door_frame") and collider.name.contains("door"):
						print("    -> Skipped: door_frame can overlap with door")
						continue

					print("    -> ADDED from shape query")
					if not overlapping_bodies.has(collider):
						overlapping_bodies.append(collider)

		# Check body overlaps from Area3D
		for body in all_body_overlaps:
			print("  Checking body: %s (type: %s)" % [body.name, body.get_class()])
			# Skip player and pickups
			if body.is_in_group("player") or body.is_in_group("item_pickup"):
				print("    -> Skipped: player/pickup")
				continue
			# Skip ground
			if body.name == "Ground" or body.is_in_group("terrain"):
				print("    -> Skipped: ground/terrain")
				continue
			# Skip large flat surfaces (likely ground)
			if _is_ground_like(body):
				print("    -> Skipped: ground-like")
				continue
			# SPECIAL CASE: Walls can overlap with roofs
			if building_id.contains("wall") and body.name.contains("roof"):
				print("    -> Skipped: wall can overlap with roof")
				continue
			# SPECIAL CASE: Walls can overlap with door_frame_with_door
			if building_id.contains("wall") and body.name.contains("door_frame_with_door"):
				print("    -> Skipped: wall can overlap with door_frame_with_door")
				continue
			# SPECIAL CASE: Doors can overlap with door_frames
			if building_id == "door" and body.name.contains("door_frame"):
				print("    -> Skipped: door can overlap with door_frame")
				continue
			# SPECIAL CASE: Door frames can overlap with doors
			if building_id.contains("door_frame") and body.name.contains("door"):
				print("    -> Skipped: door_frame can overlap with door")
				continue

			print("    -> ADDED body to overlapping_bodies")
			if not overlapping_bodies.has(body):
				overlapping_bodies.append(body)

		# Check area overlaps (e.g., other buildings' interaction areas)
		for area in all_area_overlaps:
			var parent = area.get_parent()
			if parent and parent.is_in_group("building"):
				print("  Found building area: %s" % parent.name)
				print("    -> ADDED building from area overlap")
				if not overlapping_bodies.has(parent):
					overlapping_bodies.append(parent)

		print("DEBUG: Final overlapping_bodies count: %d" % overlapping_bodies.size())
		# Update validity based on current overlaps
		check_placement_validity()
	else:
		# No collision area yet, assume valid for now
		set_validity(true)

func find_ground_below(position: Vector3) -> Variant:
	# Cast a ray straight down from above the position to find ground
	var space_state = get_world_3d().direct_space_state

	# Start the ray from above the current position
	var ray_start = Vector3(position.x, position.y + 50.0, position.z)
	var ray_end = Vector3(position.x, position.y - ground_raycast_length, position.z)

	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	# Check all layers for ground
	query.collision_mask = 0xFFFFFFFF

	# Exclude the preview itself from the raycast
	if collision_area:
		query.exclude = [collision_area.get_rid()]

	var result = space_state.intersect_ray(query)

	if result:
		# Return the Y coordinate where we hit
		print("DEBUG find_ground_below: hit '%s' at Y=%.3f (ray from %.3f to %.3f)" %
			[result.collider.name if result.collider else "unknown", result.position.y, ray_start.y, ray_end.y])
		return result.position.y

	# No ground found
	return null

func detect_wall_height_at_position(position: Vector3) -> float:
	# Check for walls at this grid position
	# Walls are 3m tall, so check if there's a building node that's wall-like
	var buildings = get_tree().get_nodes_in_group("building")
	var highest_wall_top = 0.0

	for building in buildings:
		if not building is Node3D:
			continue

		# Check if building name contains "wall"
		if not building.name.contains("wall"):
			continue

		# Check if building is at approximately the same X,Z position
		var building_pos = building.global_position
		var distance_xz = Vector2(position.x - building_pos.x, position.z - building_pos.z).length()

		# If within 2m (half grid), consider it as "at this position"
		if distance_xz < 2.5:
			# Get the actual wall mesh size if possible
			var wall_height = 3.0  # Default wall height
			var mesh_instance = building.get_node_or_null("MeshInstance3D")
			if mesh_instance and mesh_instance.mesh and mesh_instance.mesh is BoxMesh:
				wall_height = (mesh_instance.mesh as BoxMesh).size.y

			# Wall top = wall center Y + half wall height
			var wall_top = building_pos.y + (wall_height * 0.5)
			highest_wall_top = max(highest_wall_top, wall_top)

	return highest_wall_top

func _is_ground_like(body: Node3D) -> bool:
	# Check if this body is ground-like (large, flat)
	if body.has_node("CollisionShape3D"):
		var shape_node = body.get_node("CollisionShape3D")
		if shape_node.shape is BoxShape3D:
			var box = shape_node.shape as BoxShape3D
			# If height is small compared to width/depth, likely ground
			var aspect_ratio = max(box.size.x, box.size.z) / box.size.y
			if aspect_ratio > 5.0:  # If it's at least 5x wider than tall
				return true
			# Also check absolute sizes
			if box.size.y <= 2.0 and (box.size.x > 20 or box.size.z > 20):
				return true
	return false

func snap_to_grid_3d(pos: Vector3, grid_size: float = 1.0) -> Vector3:
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		pos.y,  # Keep Y position (height)
		round(pos.z / grid_size) * grid_size
	)

func snap_wall_to_floor_edge(wall_pos: Vector3, half_grid: float) -> Vector3:
	# Wall snapping logic:
	# - Along wall length: snap to FULL 4m grid (to align corners with floors)
	# - Perpendicular to wall: position so INNER face sits flush with floor edge
	# - For a 0.2m thick wall on a 4m floor: inner face at ±2m, center at ±2.1m

	var full_grid = half_grid * 2.0  # 4m (floor tile size)
	var wall_thickness = 0.2  # Wall thickness from building_data
	var wall_offset = half_grid + (wall_thickness / 2.0)  # 2.1m from floor center

	# Determine wall orientation
	var rotation_y = rotation_degrees.y
	var normalized_rotation = fmod(rotation_y + 360.0, 360.0)
	var runs_along_x = abs(normalized_rotation) < 45.0 or abs(normalized_rotation - 180.0) < 45.0

	var x_snapped: float
	var z_snapped: float

	if runs_along_x:
		# Wall runs along X axis (4m wide wall extends in X direction)
		# X: Snap to full 4m grid for corner alignment
		x_snapped = round(wall_pos.x / full_grid) * full_grid

		# Z: Position wall so inner face is flush with floor edge
		# Find nearest floor center in Z
		var nearest_floor_z = round(wall_pos.z / full_grid) * full_grid
		# Determine which side of floor we're on
		if wall_pos.z >= nearest_floor_z:
			z_snapped = nearest_floor_z + wall_offset  # North side
		else:
			z_snapped = nearest_floor_z - wall_offset  # South side
	else:
		# Wall runs along Z axis (4m wide wall extends in Z direction)
		# Z: Snap to full 4m grid for corner alignment
		z_snapped = round(wall_pos.z / full_grid) * full_grid

		# X: Position wall so inner face is flush with floor edge
		# Find nearest floor center in X
		var nearest_floor_x = round(wall_pos.x / full_grid) * full_grid
		# Determine which side of floor we're on
		if wall_pos.x >= nearest_floor_x:
			x_snapped = nearest_floor_x + wall_offset  # East side
		else:
			x_snapped = nearest_floor_x - wall_offset  # West side

	return Vector3(x_snapped, wall_pos.y, z_snapped)

func snap_door_to_frame(door_pos: Vector3) -> Vector3:
	# Find nearby door_frame buildings
	var buildings = get_tree().get_nodes_in_group("building")
	var closest_frame = null
	var closest_distance = 999999.0

	for building in buildings:
		if not building.name.contains("door_frame"):
			continue

		var building_pos = building.global_position
		var distance = door_pos.distance_to(building_pos)

		if distance < closest_distance and distance < 3.0:  # Within 3m
			closest_distance = distance
			closest_frame = building

	if closest_frame:
		# Snap to the door frame's X/Z position, but keep the door_pos Y (from raycast to floor)
		var frame_pos = closest_frame.global_position
		var snapped_pos = Vector3(frame_pos.x, door_pos.y, frame_pos.z)

		# Match the door frame's rotation
		rotation_degrees.y = closest_frame.rotation_degrees.y

		print("Door snapping to frame at: %s with rotation: %.1f° (Y from raycast: %.2f)" % [snapped_pos, rotation_degrees.y, door_pos.y])
		return snapped_pos
	else:
		# No frame nearby, use wall-like snapping
		print("No door frame nearby, using default snapping")
		var half_grid = 2.0
		return snap_wall_to_floor_edge(door_pos, half_grid)

func rotate_building():
	rotation_degrees.y += 90
	if rotation_degrees.y >= 360:
		rotation_degrees.y = 0

func setup_collision_area(size: Vector3):
	# Remove old collision area if exists
	if collision_area:
		collision_area.queue_free()

	# Create new Area3D for overlap detection
	collision_area = Area3D.new()
	collision_area.name = "CollisionDetection"
	add_child(collision_area)

	# Special case: Door frame needs multiple collision shapes to avoid door opening
	if building_id == "door_frame":
		# Create 3 collision boxes: left wall, right wall, top section
		# Door opening is 1.2m wide, centered
		var wall_thickness = 0.2
		var door_width = 1.2
		var door_height = 2.4
		var total_width = size.x  # 4m
		var total_height = size.y  # 3m

		var side_width = (total_width - door_width) / 2.0  # 1.4m each side

		# Left wall section
		var left_shape = CollisionShape3D.new()
		var left_box = BoxShape3D.new()
		left_box.size = Vector3(side_width, total_height, wall_thickness)
		left_shape.shape = left_box
		left_shape.position = Vector3(-(door_width/2.0 + side_width/2.0), 0, 0)
		collision_area.add_child(left_shape)

		# Right wall section
		var right_shape = CollisionShape3D.new()
		var right_box = BoxShape3D.new()
		right_box.size = Vector3(side_width, total_height, wall_thickness)
		right_shape.shape = right_box
		right_shape.position = Vector3(door_width/2.0 + side_width/2.0, 0, 0)
		collision_area.add_child(right_shape)

		# Top section (above door)
		var top_height = total_height - door_height
		var top_shape = CollisionShape3D.new()
		var top_box = BoxShape3D.new()
		top_box.size = Vector3(door_width, top_height, wall_thickness)
		top_shape.shape = top_box
		top_shape.position = Vector3(0, door_height/2.0 + top_height/2.0, 0)
		collision_area.add_child(top_shape)
	else:
		# Standard single collision shape
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		collision_shape.position = Vector3.ZERO
		collision_area.add_child(collision_shape)

	# Set collision layers
	collision_area.collision_layer = 0  # Preview doesn't collide
	# Detect ALL layers - we'll filter out ground in the signal handlers
	collision_area.collision_mask = 0xFFFFFFFF  # All layers
	collision_area.monitoring = true
	collision_area.monitorable = false

	# Connect signals
	collision_area.body_entered.connect(_on_body_entered)
	collision_area.body_exited.connect(_on_body_exited)
	collision_area.area_entered.connect(_on_area_entered)
	collision_area.area_exited.connect(_on_area_exited)

func _on_body_entered(body: Node3D):
	print("DEBUG: Body entered collision area: %s (type: %s)" % [body.name, body.get_class()])

	# Ignore certain bodies
	if body.is_in_group("player") or body.is_in_group("item_pickup"):
		print("  -> Ignored: player or item_pickup")
		return

	# Ignore ground/terrain
	if body.name == "Ground" or body.is_in_group("terrain"):
		print("  -> Ignored: ground/terrain")
		return

	# Check if it's ground-like geometry
	if _is_ground_like(body):
		print("  -> Ignored: ground-like geometry")
		return

	# SPECIAL CASE: Walls can overlap with roofs
	# Allow walls to be placed even when they intersect with roofs
	if building_id.contains("wall") and body.name.contains("roof"):
		print("  -> Allowed: wall can overlap with roof")
		return

	# SPECIAL CASE: Walls can overlap with door_frame_with_door
	if building_id.contains("wall") and body.name.contains("door_frame_with_door"):
		print("  -> Allowed: wall can overlap with door_frame_with_door")
		return

	# SPECIAL CASE: Doors can overlap with door_frames
	# Allow doors to be placed in door frame openings
	if building_id == "door" and body.name.contains("door_frame"):
		print("  -> Allowed: door can overlap with door_frame")
		return

	# SPECIAL CASE: Door frames can overlap with doors
	# Allow door frames to be placed around existing doors
	if building_id.contains("door_frame") and body.name.contains("door"):
		print("  -> Allowed: door_frame can overlap with door")
		return

	# Check if it's an actual obstacle
	# Include all CSG types (CSGShape3D, CSGBox3D, CSGPolygon3D, etc.)
	var is_collidable = (
		body is StaticBody3D or
		body is RigidBody3D or
		body is CharacterBody3D or
		body.get_class().begins_with("CSG")  # Catches all CSG types
	)

	if is_collidable:
		print("  -> COLLISION DETECTED with: ", body.name)
		overlapping_bodies.append(body)
		check_placement_validity()
	else:
		print("  -> Not a collidable body type: %s" % body.get_class())

func _on_body_exited(body: Node3D):
	overlapping_bodies.erase(body)
	check_placement_validity()

func _on_area_entered(area: Area3D):
	# Check if area belongs to another building
	var parent = area.get_parent()
	if parent and parent.is_in_group("building"):
		overlapping_bodies.append(parent)
		check_placement_validity()

func _on_area_exited(area: Area3D):
	var parent = area.get_parent()
	if parent:
		overlapping_bodies.erase(parent)
		check_placement_validity()

func check_placement_validity():
	# Allow placement if only overlapping with other buildings (for connecting pieces)
	# Only block if overlapping with non-building obstacles
	var has_blocking_overlap = false
	for body in overlapping_bodies:
		# Buildings can overlap/connect with each other
		if body.is_in_group("building"):
			continue
		# Everything else blocks placement
		has_blocking_overlap = true
		break

	var is_valid = not has_blocking_overlap
	set_validity(is_valid)

func can_place_here() -> bool:
	# Check if there are any blocking overlaps (non-building obstacles)
	var has_blocking_overlap = false
	for body in overlapping_bodies:
		if not body.is_in_group("building"):
			has_blocking_overlap = true
			break

	var result = can_place and not has_blocking_overlap
	if not result:
		print("Cannot place: can_place=%s, has_blocking_overlap=%s" % [can_place, has_blocking_overlap])
		if has_blocking_overlap:
			print("Blocked by non-building obstacles:")
			for body in overlapping_bodies:
				if not body.is_in_group("building"):
					print("  - %s (type: %s)" % [body.name, body.get_class()])
	return result