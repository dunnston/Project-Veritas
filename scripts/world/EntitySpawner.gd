## EntitySpawner.gd
## Spawns entities (animals, enemies) within a defined radius
## Handles spawn timing, limits, and area visualization
class_name EntitySpawner
extends Node3D

## Entity templates that can be spawned
@export var spawn_templates: Array[Resource] = []

## Maximum number of entities that can exist at once from this spawner
@export var max_entities: int = 10

## Minimum time between spawn attempts (seconds)
@export var spawn_frequency_min: float = 5.0

## Maximum time between spawn attempts (seconds)
@export var spawn_frequency_max: float = 15.0

## Radius within which entities can spawn
@export var spawn_radius: float = 20.0

## Minimum distance from spawner center
@export var min_spawn_distance: float = 5.0

## Enable debug visualization
@export var debug_draw: bool = true

## Color for debug visualization
@export var debug_color: Color = Color(0.0, 1.0, 0.0, 0.3)

## Spawned entity tracking
var active_entities: Array[Node3D] = []
var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0

func _ready() -> void:
	_set_next_spawn_time()
	_ready_debug()

func _process(delta: float) -> void:
	# Clean up dead/freed entities
	_cleanup_entities()

	# Handle spawning
	spawn_timer += delta
	if spawn_timer >= next_spawn_time and active_entities.size() < max_entities:
		_attempt_spawn()
		spawn_timer = 0.0
		_set_next_spawn_time()

func _cleanup_entities() -> void:
	# Remove null/freed references
	active_entities = active_entities.filter(func(entity): return is_instance_valid(entity))

func _attempt_spawn() -> void:
	if spawn_templates.is_empty():
		return

	# Pick random template
	var template = spawn_templates[randi() % spawn_templates.size()]

	# Get spawn position
	var spawn_pos = _get_random_spawn_position()
	if spawn_pos == Vector3.ZERO:
		return # Failed to find valid position

	# Spawn entity based on template type
	if template is AnimalTemplate:
		_spawn_animal(template, spawn_pos)

func _spawn_animal(template: AnimalTemplate, spawn_pos: Vector3) -> void:
	if not template.scene:
		push_error("AnimalTemplate '%s' has no scene assigned" % template.animal_name)
		return

	var animal_instance = template.scene.instantiate()
	get_tree().current_scene.add_child(animal_instance)
	animal_instance.global_position = spawn_pos

	# Configure animal with template data
	if animal_instance.has_method("configure_from_template"):
		animal_instance.configure_from_template(template)

	active_entities.append(animal_instance)

	# Connect to death signal if available
	if animal_instance.has_signal("died"):
		animal_instance.died.connect(_on_entity_died.bind(animal_instance))

func _on_entity_died(entity: Node3D) -> void:
	active_entities.erase(entity)

func _get_random_spawn_position() -> Vector3:
	# Try multiple times to find valid position
	for i in range(10):
		# Random angle and distance
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)

		var offset = Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)

		var spawn_pos = global_position + offset

		# Raycast down to find ground
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			spawn_pos + Vector3.UP * 10,
			spawn_pos + Vector3.DOWN * 20
		)
		query.collision_mask = 1 # World layer

		var result = space_state.intersect_ray(query)
		if result:
			return result.position + Vector3.UP * 0.5 # Slightly above ground

	return Vector3.ZERO # Failed to find position

func _set_next_spawn_time() -> void:
	next_spawn_time = randf_range(spawn_frequency_min, spawn_frequency_max)

## Debug visualization using ImmediateMesh
var debug_mesh: ImmediateMesh
var debug_mesh_instance: MeshInstance3D

func _ready_debug() -> void:
	if not debug_draw:
		return

	# Create debug mesh for visualization
	debug_mesh = ImmediateMesh.new()
	debug_mesh_instance = MeshInstance3D.new()
	debug_mesh_instance.mesh = debug_mesh
	debug_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(debug_mesh_instance)

	_update_debug_mesh()

func _update_debug_mesh() -> void:
	if not debug_draw or not debug_mesh:
		return

	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Draw spawn radius circle
	var steps = 32
	for i in range(steps):
		var angle1 = (float(i) / steps) * TAU
		var angle2 = (float(i + 1) / steps) * TAU

		var p1 = Vector3(cos(angle1) * spawn_radius, 0.1, sin(angle1) * spawn_radius)
		var p2 = Vector3(cos(angle2) * spawn_radius, 0.1, sin(angle2) * spawn_radius)

		debug_mesh.surface_set_color(debug_color)
		debug_mesh.surface_add_vertex(p1)
		debug_mesh.surface_add_vertex(p2)

	# Draw min radius
	for i in range(steps):
		var angle1 = (float(i) / steps) * TAU
		var angle2 = (float(i + 1) / steps) * TAU

		var p1 = Vector3(cos(angle1) * min_spawn_distance, 0.1, sin(angle1) * min_spawn_distance)
		var p2 = Vector3(cos(angle2) * min_spawn_distance, 0.1, sin(angle2) * min_spawn_distance)

		debug_mesh.surface_set_color(Color(1, 0, 0, 0.3))
		debug_mesh.surface_add_vertex(p1)
		debug_mesh.surface_add_vertex(p2)

	debug_mesh.surface_end()
