extends Node3D
class_name ResourceNodeSpawner

## Spawns resource nodes within a defined area
## Manages respawning and spawn distribution

@export_group("Spawn Area")
@export var spawn_radius: float = 10.0
@export var max_nodes: int = 5

@export_group("Spawn Configuration")
@export var spawn_table: Array[NodeSpawnConfig] = []
@export var spawn_on_ready: bool = true
@export var check_ground_collision: bool = true
@export var ground_check_height: float = 100.0

@export_group("Debug")
@export var show_spawn_area: bool = true
@export var debug_color: Color = Color(0.0, 1.0, 0.0, 0.3)

var spawned_nodes: Array[ResourceNode] = []
var active_node_count: int = 0

func _ready() -> void:
	add_to_group("resource_spawners")

	if spawn_on_ready:
		spawn_initial_nodes()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and show_spawn_area:
		queue_redraw()

## Spawn initial set of resource nodes
func spawn_initial_nodes() -> void:
	for i in range(max_nodes):
		spawn_random_node()

## Spawn a random node based on spawn table
func spawn_random_node() -> ResourceNode:
	if spawn_table.is_empty():
		push_warning("ResourceNodeSpawner: No spawn configurations defined")
		return null

	# Calculate total weight
	var total_weight: float = 0.0
	for config in spawn_table:
		if config:
			total_weight += config.spawn_weight

	if total_weight <= 0:
		return null

	# Pick random node based on weight
	var random_value: float = randf() * total_weight
	var current_weight: float = 0.0

	for config in spawn_table:
		if not config or not config.node_scene:
			continue

		current_weight += config.spawn_weight

		if random_value <= current_weight:
			return spawn_node(config)

	return null

## Spawn a specific node configuration
func spawn_node(config: NodeSpawnConfig) -> ResourceNode:
	if not config or not config.node_scene:
		return null

	# Find valid spawn position
	var spawn_pos = find_spawn_position()
	if spawn_pos == Vector3.ZERO and check_ground_collision:
		return null

	# Instance the node
	var node_instance = config.node_scene.instantiate() as ResourceNode
	if not node_instance:
		push_warning("ResourceNodeSpawner: Failed to instantiate node scene")
		return null

	# Position the node
	add_child(node_instance)
	node_instance.global_position = spawn_pos

	# Apply random rotation
	if config.random_rotation:
		node_instance.rotation.y = randf() * TAU

	# Apply random scale variation
	if config.scale_variation > 0:
		var scale_factor = 1.0 + randf_range(-config.scale_variation, config.scale_variation)
		node_instance.scale = Vector3.ONE * scale_factor

	# Override respawn settings if configured
	if not config.can_respawn:
		node_instance.can_respawn = false
	elif config.respawn_time > 0:
		node_instance.respawn_time = config.respawn_time

	# Track the node
	spawned_nodes.append(node_instance)
	active_node_count += 1

	# Connect to destruction signal
	node_instance.node_destroyed.connect(_on_node_destroyed.bind(node_instance, config))

	return node_instance

## Find a valid spawn position within the spawn area
func find_spawn_position() -> Vector3:
	var max_attempts = 10
	var space_state = get_world_3d().direct_space_state

	for attempt in range(max_attempts):
		# Random position within radius
		var angle = randf() * TAU
		var distance = randf() * spawn_radius
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var test_pos = global_position + offset

		if check_ground_collision:
			# Raycast down to find ground
			var query = PhysicsRayQueryParameters3D.create(
				test_pos + Vector3.UP * ground_check_height,
				test_pos + Vector3.DOWN * ground_check_height
			)
			query.collision_mask = 1  # World layer

			var result = space_state.intersect_ray(query)
			if result:
				return result.position

		else:
			return test_pos

	return Vector3.ZERO

## Handle node destruction
func _on_node_destroyed(node: ResourceNode, config: NodeSpawnConfig) -> void:
	active_node_count -= 1

	# Respawn if configured and under max
	if config.can_respawn and spawned_nodes.size() < max_nodes:
		# Wait a bit before spawning replacement
		await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
		spawn_node(config)

## Clear all spawned nodes
func clear_all_nodes() -> void:
	for node in spawned_nodes:
		if is_instance_valid(node):
			node.queue_free()

	spawned_nodes.clear()
	active_node_count = 0

## Respawn all nodes
func respawn_all_nodes() -> void:
	clear_all_nodes()
	spawn_initial_nodes()

## Debug draw spawn area
func _draw() -> void:
	if not show_spawn_area or not Engine.is_editor_hint():
		return

	# This would need to be implemented with ImmediateMesh or similar
	# for proper 3D debug drawing in Godot 4
