extends Node3D

# Spawns desert props randomly across the map
# Attach this to the EnvironmentProps node

@export var spawn_count: int = 50
@export var map_size: float = 450.0  # 500m map with 50m buffer from edges
@export var min_distance_between_props: float = 10.0

# Prop paths - using new GLB assets
var cactus_props = [
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Cactus_01.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Cactus_02.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Cactus_03.glb"
]

var rock_props = [
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rock_01.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rock_02.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rock_03.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rock_04.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rocks_Spikey_01.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rocks_Spikey_02.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Rocks_Spikey_03.glb"
]

var bush_props = [
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Bush_Bramble_01.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_Bush_Bramble_02.glb"
]

var ground_cover_props = [
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_GroundCover_01.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_GroundCover_02.glb",
	"res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/Environment/SM_Env_GroundCover_03.glb"
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
	var children = get_children().duplicate()  # Duplicate to avoid modification during iteration
	var processed = 0

	for child in children:
		if child is Node3D and not child is StaticBody3D:
			# Save original transform
			var original_transform = child.transform

			# Remove from parent temporarily
			remove_child(child)

			# Wrap in collision
			var collision_wrapper = create_collision_wrapper(child)

			# Add back with correct transform
			add_child(collision_wrapper)
			collision_wrapper.transform = original_transform

			processed += 1

	print("Added collision to %d manually placed props" % processed)

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

		if rand_val < 0.35:  # 35% rocks
			prop_path = rock_props[randi() % rock_props.size()]
			scale_factor = randf_range(0.8, 1.5)
		elif rand_val < 0.6:  # 25% cacti
			prop_path = cactus_props[randi() % cactus_props.size()]
			scale_factor = randf_range(0.9, 1.3)
		elif rand_val < 0.8:  # 20% bushes
			prop_path = bush_props[randi() % bush_props.size()]
			scale_factor = randf_range(0.7, 1.2)
		else:  # 20% ground cover
			prop_path = ground_cover_props[randi() % ground_cover_props.size()]
			scale_factor = randf_range(1.5, 2.5)

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
