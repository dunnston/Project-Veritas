extends Node3D

# Spawns desert props randomly across the map
# Attach this to the EnvironmentProps node

@export var spawn_count: int = 0  # Disabled for now - set to 100 to enable random spawning
@export var map_size: float = 900.0  # Leave 100m buffer from edges
@export var min_distance_between_props: float = 10.0

# Prop paths
var cactus_props = [
	"res://assets/models/environment/desert/SM_Env_Cactus_01.fbx",
	"res://assets/models/environment/desert/SM_Env_Cactus_02.fbx",
	"res://assets/models/environment/desert/SM_Env_Cactus_03.fbx"
]

var rock_props = [
	"res://assets/models/environment/desert/SM_Env_Rock_01.fbx",
	"res://assets/models/environment/desert/SM_Env_Rock_02.fbx",
	"res://assets/models/environment/desert/SM_Env_Rock_03.fbx",
	"res://assets/models/environment/desert/SM_Env_Rock_04.fbx"
]

var bush_props = [
	"res://assets/models/environment/desert/SM_Env_Bush_Bramble_01.fbx",
	"res://assets/models/environment/desert/SM_Env_Bush_Bramble_02.fbx"
]

var spawned_positions: Array[Vector3] = []

func _ready():
	# Add collision to manually placed props first
	add_collision_to_existing_props()
	# Then spawn additional random props
	spawn_desert_props()

func add_collision_to_existing_props():
	# Add collision to all manually placed child nodes
	print("Adding collision to manually placed props...")
	var children = get_children()
	var processed = 0

	for child in children:
		if child is Node3D:
			# Find all mesh instances in this prop
			var mesh_instances = find_mesh_instances(child)

			if mesh_instances.size() > 0:
				# Create a StaticBody3D parent
				var static_body = StaticBody3D.new()
				static_body.name = child.name + "_WithCollision"
				static_body.transform = child.transform

				# Add collision shapes for each mesh
				for mesh_inst in mesh_instances:
					if mesh_inst.mesh:
						var collision_shape = CollisionShape3D.new()
						var shape = mesh_inst.mesh.create_convex_shape()

						if shape:
							collision_shape.shape = shape
							collision_shape.transform = mesh_inst.global_transform.affine_inverse() * static_body.global_transform
							static_body.add_child(collision_shape)

				# Replace child with collision-enabled version
				if static_body.get_child_count() > 0:
					remove_child(child)
					add_child(static_body)
					static_body.add_child(child)
					child.transform = Transform3D.IDENTITY
					processed += 1

	print("Added collision to %d props" % processed)

func spawn_desert_props():
	print("Spawning %d desert props across %fm map..." % [spawn_count, map_size])

	var half_size = map_size / 2.0
	var spawn_attempts = 0
	var max_attempts = spawn_count * 10

	while spawned_positions.size() < spawn_count and spawn_attempts < max_attempts:
		spawn_attempts += 1

		# Random position
		var x = randf_range(-half_size, half_size)
		var z = randf_range(-half_size, half_size)
		var pos = Vector3(x, 0, z)

		# Check minimum distance
		if not is_position_valid(pos):
			continue

		# Choose random prop type (weighted)
		var rand_val = randf()
		var prop_path = ""
		var scale_factor = 1.0

		if rand_val < 0.4:  # 40% rocks
			prop_path = rock_props[randi() % rock_props.size()]
			scale_factor = randf_range(0.8, 1.5)
		elif rand_val < 0.7:  # 30% cacti
			prop_path = cactus_props[randi() % cactus_props.size()]
			scale_factor = randf_range(0.9, 1.3)
		else:  # 30% bushes
			prop_path = bush_props[randi() % bush_props.size()]
			scale_factor = randf_range(0.7, 1.2)

		# Load and instance prop
		if ResourceLoader.exists(prop_path):
			var prop_scene = load(prop_path)
			var prop_instance = prop_scene.instantiate()

			# Wrap in collision body BEFORE adding to scene
			var collision_wrapper = create_collision_wrapper(prop_instance)

			# Set position and rotation on the wrapper
			collision_wrapper.global_position = pos
			collision_wrapper.rotation_degrees.y = randf_range(0, 360)
			collision_wrapper.scale = Vector3.ONE * scale_factor

			add_child(collision_wrapper)
			spawned_positions.append(pos)
		else:
			push_warning("Prop not found: " + prop_path)

	print("Spawned %d props in %d attempts" % [spawned_positions.size(), spawn_attempts])

func is_position_valid(pos: Vector3) -> bool:
	# Check minimum distance from other props
	for existing_pos in spawned_positions:
		if pos.distance_to(existing_pos) < min_distance_between_props:
			return false

	# Check not too close to player spawn (0,0,0)
	if pos.distance_to(Vector3.ZERO) < 20.0:
		return false

	return true

func create_collision_wrapper(prop: Node3D) -> Node3D:
	# Create a StaticBody3D to wrap the prop with collision
	var static_body = StaticBody3D.new()
	static_body.name = "PropWithCollision"

	# Add the prop as a child first
	static_body.add_child(prop)

	# Find all MeshInstance3D nodes and add collision shapes
	var mesh_instances = find_mesh_instances(prop)

	for mesh_inst in mesh_instances:
		if mesh_inst.mesh:
			var collision_shape = CollisionShape3D.new()

			# Create a convex collision shape from the mesh
			var shape = mesh_inst.mesh.create_convex_shape()
			if shape:
				collision_shape.shape = shape

				# Match the mesh instance's transform
				collision_shape.transform = mesh_inst.transform
				static_body.add_child(collision_shape)

	# Return the wrapper (or just the prop if no collision was created)
	if static_body.get_child_count() > 1:  # Has prop + collision shapes
		return static_body
	else:
		# No collision shapes created, just return the prop
		static_body.remove_child(prop)
		return prop

func find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(find_mesh_instances(child))

	return meshes
