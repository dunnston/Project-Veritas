extends Node3D

# Spawns desert props randomly across the map
# Attach this to the EnvironmentProps node

@export var spawn_count: int = 100
@export var map_size: float = 900.0  # Leave 100m buffer from edges
@export var min_distance_between_props: float = 10.0

# Prop paths
var cactus_props = [
	"res://3d Assets/FBX/Environment/SM_Env_Cactus_01.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Cactus_02.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Cactus_03.fbx"
]

var rock_props = [
	"res://3d Assets/FBX/Environment/SM_Env_Rock_01.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Rock_02.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Rock_03.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Rock_04.fbx"
]

var bush_props = [
	"res://3d Assets/FBX/Environment/SM_Env_Bush_Bramble_01.fbx",
	"res://3d Assets/FBX/Environment/SM_Env_Bush_Bramble_02.fbx"
]

var spawned_positions: Array[Vector3] = []

func _ready():
	spawn_desert_props()

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

			# Set position and rotation
			prop_instance.global_position = pos
			prop_instance.rotation_degrees.y = randf_range(0, 360)
			prop_instance.scale = Vector3.ONE * scale_factor

			add_child(prop_instance)
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
