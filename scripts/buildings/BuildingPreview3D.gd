extends Node3D
class_name BuildingPreview3D

@onready var mesh_instance: MeshInstance3D = null
@onready var collision_area: Area3D = null

var building_id: String = ""
var can_place: bool = false
var material_valid: StandardMaterial3D
var material_invalid: StandardMaterial3D
var overlapping_bodies: Array = []
var ground_raycast_length: float = 100.0  # How far down to check for ground
var ground_clearance: float = 0.05  # Small offset above ground to prevent z-fighting

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

	# Create mesh instance if not exists
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)

	# Use provided mesh or create default
	var box_size = Vector3(2, 1, 1)  # Default size
	if mesh:
		mesh_instance.mesh = mesh
		if mesh is BoxMesh:
			box_size = (mesh as BoxMesh).size
	else:
		# Create default box mesh for workbench
		var box_mesh = BoxMesh.new()
		box_mesh.size = box_size
		mesh_instance.mesh = box_mesh

	# Create collision detection area
	setup_collision_area(box_size)

	# Set initial material
	set_validity(false)

func set_validity(is_valid: bool):
	can_place = is_valid

	if mesh_instance:
		if is_valid:
			mesh_instance.material_override = material_valid
		else:
			mesh_instance.material_override = material_invalid

	placement_validity_changed.emit(is_valid)

func update_position(world_pos: Vector3):
	# Snap to grid on X and Z axes
	var grid_pos = Vector3(
		round(world_pos.x / 1.0) * 1.0,
		world_pos.y,  # Temporary Y, will be adjusted by ground raycast
		round(world_pos.z / 1.0) * 1.0
	)

	# Get mesh size for calculations
	var mesh_height = 1.0
	if mesh_instance and mesh_instance.mesh and mesh_instance.mesh is BoxMesh:
		var box_mesh = mesh_instance.mesh as BoxMesh
		mesh_height = box_mesh.size.y

	# Perform downward raycast to find the actual ground below this position
	var ground_y = find_ground_below(grid_pos)

	# If we found ground, snap to it
	if ground_y != null:
		# Place the bottom of the mesh exactly on the ground surface
		# Since the mesh is centered at its origin, we need to offset by half height
		grid_pos.y = ground_y + (mesh_height * 0.5) + ground_clearance
	else:
		# No ground found - use the original Y position from mouse raycast
		grid_pos.y = world_pos.y + (mesh_height * 0.5) + ground_clearance

	global_position = grid_pos

	# Force immediate validity check after moving
	# Wait one physics frame for collision updates
	await get_tree().physics_frame
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
		return result.position.y

	# No ground found
	return null

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

	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	# Use FULL size for accurate collision detection - no reductions
	# We filter out ground using name/group checks instead
	box_shape.size = size
	collision_shape.shape = box_shape
	# No offset - collision box matches mesh exactly
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
	# Can't place if overlapping with any bodies
	var is_valid = overlapping_bodies.is_empty()
	set_validity(is_valid)

func can_place_here() -> bool:
	var result = can_place and overlapping_bodies.is_empty()
	if not result:
		print("Cannot place: can_place=%s, overlapping_bodies.size=%d" % [can_place, overlapping_bodies.size()])
		if not overlapping_bodies.is_empty():
			print("Overlapping with:")
			for body in overlapping_bodies:
				print("  - %s (type: %s)" % [body.name, body.get_class()])
	return result