extends Node3D
class_name BuildingPreview3D

@onready var mesh_instance: MeshInstance3D = null
@onready var collision_area: Area3D = null

var building_id: String = ""
var can_place: bool = false
var material_valid: StandardMaterial3D
var material_invalid: StandardMaterial3D
var overlapping_bodies: Array = []

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
	# Snap to grid (but keep Y from raycast)
	var grid_pos = Vector3(
		round(world_pos.x / 1.0) * 1.0,
		world_pos.y,  # Keep the exact Y from raycast
		round(world_pos.z / 1.0) * 1.0
	)

	# Adjust Y position to sit properly on ground
	if mesh_instance and mesh_instance.mesh and mesh_instance.mesh is BoxMesh:
		var box_mesh = mesh_instance.mesh as BoxMesh
		# The raycast hits the surface. For a box mesh centered at origin,
		# we need to offset by half its height to place bottom at surface
		grid_pos.y = world_pos.y + (box_mesh.size.y * 0.5) + 0.01  # Small offset to prevent z-fighting

	global_position = grid_pos

	# TEMPORARY: Always set as valid to test if placement works
	set_validity(true)

	# Comment out collision checking for now
	# call_deferred("recheck_validity")

func recheck_validity():
	# Let the physics engine update and re-detect overlaps
	if collision_area:
		# Force area to re-check overlaps at new position
		overlapping_bodies.clear()
		for body in collision_area.get_overlapping_bodies():
			# Skip player and pickups
			if body.is_in_group("player") or body.is_in_group("item_pickup"):
				continue
			# Skip ground
			if body.name == "Ground" or body.is_in_group("terrain"):
				continue
			# Skip large flat surfaces (likely ground)
			if _is_ground_like(body):
				continue

			overlapping_bodies.append(body)
		check_placement_validity()

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
	# Make collision slightly smaller to avoid false positives with ground
	box_shape.size = Vector3(size.x * 0.9, size.y * 0.9, size.z * 0.9)
	collision_shape.shape = box_shape
	# Position collision shape to match mesh center
	collision_shape.position = Vector3(0, 0, 0)
	collision_area.add_child(collision_shape)

	# Set collision layers
	collision_area.collision_layer = 0  # Preview doesn't collide
	# Detect everything except ground (layer 1)
	# Layer 1 = ground/terrain, so exclude it from mask
	collision_area.collision_mask = 0xFFFFFFFE  # All layers except layer 1
	collision_area.monitoring = true
	collision_area.monitorable = false

	# Connect signals
	collision_area.body_entered.connect(_on_body_entered)
	collision_area.body_exited.connect(_on_body_exited)
	collision_area.area_entered.connect(_on_area_entered)
	collision_area.area_exited.connect(_on_area_exited)

func _on_body_entered(body: Node3D):
	# Ignore certain bodies
	if body.is_in_group("player") or body.is_in_group("item_pickup"):
		return

	# Ignore ground/terrain
	if body.name == "Ground" or body.is_in_group("terrain"):
		return

	# Check if it's ground-like geometry
	if _is_ground_like(body):
		return

	# Check if it's an actual obstacle
	if body is StaticBody3D or body is RigidBody3D or body is CharacterBody3D:
		print("Preview overlapping with: ", body.name)
		overlapping_bodies.append(body)
		check_placement_validity()

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
	if not is_valid:
		print("Cannot place - overlapping with %d objects:" % overlapping_bodies.size())
		for body in overlapping_bodies:
			print("  - ", body.name)
	set_validity(is_valid)

func can_place_here() -> bool:
	# TEMPORARY: Always allow placement to test
	return true
	# return can_place and overlapping_bodies.is_empty()