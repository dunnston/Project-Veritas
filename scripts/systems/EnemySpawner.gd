@tool
extends Node2D
class_name EnemySpawnerSystem

## Enemy Spawner System
## Dynamically spawns enemies in designated areas with configurable parameters

signal enemy_spawned(enemy: Node2D, spawner: EnemySpawner)
signal spawner_activated()
signal spawner_deactivated()
signal spawn_limit_reached()

## Spawner Configuration
@export_group("Enemy Types")
@export var enemy_scenes: Array[PackedScene] = []  ## List of enemy scenes that can spawn
@export var spawn_weights: Array[int] = []  ## Weight for each enemy type (higher = more likely)

@export_group("Spawn Settings")
@export var spawn_frequency: float = 3.0  ## Time between spawn attempts (seconds)
@export var max_concurrent_enemies: int = 5  ## Maximum enemies from this spawner at once
@export var initial_spawn_delay: float = 0.0  ## Delay before first spawn
@export var respawn_delay: float = 2.0  ## Extra delay after enemy death before respawning
@export var spawn_on_start: bool = false  ## Start spawning immediately when scene loads

@export_group("Spawn Area")
@export var spawn_radius: float = 100.0:  ## Radius around spawner for random spawn points
	set(value):
		spawn_radius = value
		queue_redraw()  # Redraw the spawn area in editor
@export var min_spawn_distance: float = 50.0  ## Minimum distance from spawner center
@export var spawn_height_variation: float = 0.0  ## Y-axis variation for spawn points

@export_group("Activation")
@export var activation_range: float = 500.0:  ## Distance from player to activate spawner
	set(value):
		activation_range = value
		queue_redraw()  # Redraw the activation range
@export var always_active: bool = false  ## Ignore activation range, always spawn
@export var deactivate_on_player_exit: bool = true  ## Stop spawning when player leaves
@export var require_line_of_sight: bool = false  ## Only spawn if player can see spawner

@export_group("Visual Settings")
@export var show_spawn_area: bool = true  ## Show spawn area in editor
@export var show_activation_range: bool = true  ## Show activation range in editor
@export var spawn_area_color: Color = Color(0.0, 1.0, 0.0, 0.3)
@export var activation_range_color: Color = Color(1.0, 1.0, 0.0, 0.2)

@export_group("Performance")
@export var use_object_pooling: bool = true  ## Reuse enemy instances for better performance
@export var max_spawn_attempts: int = 10  ## Max attempts to find valid spawn point
@export var spawn_check_radius: float = 30.0  ## Check for obstacles at spawn point

## Internal State
var spawned_enemies: Array[Node2D] = []
var enemy_pool: Dictionary = {}  # enemy_type -> Array[Node2D]
var spawn_timer: Timer
var is_active: bool = false
var player_in_range: bool = false
var spawn_cooldown_active: bool = false
var total_spawned: int = 0
var current_spawn_index: int = 0

@onready var detection_area: Area2D = $DetectionArea
@onready var spawn_area_collision: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var spawn_point_marker: Node2D = $SpawnPointMarker

func _ready():
	if Engine.is_editor_hint():
		return

	setup_spawner()

	if spawn_on_start and not always_active:
		check_activation()
	elif always_active:
		activate_spawner()

func setup_spawner():
	"""Initialize the spawner components"""
	# Validate enemy scenes
	if enemy_scenes.is_empty():
		push_warning("EnemySpawner at %s has no enemy scenes configured!" % global_position)
		return

	# Setup spawn weights if not configured
	if spawn_weights.is_empty():
		spawn_weights.resize(enemy_scenes.size())
		for i in range(spawn_weights.size()):
			spawn_weights[i] = 1  # Equal weight for all

	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_frequency
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)

	# Setup detection area for player activation
	if not always_active:
		setup_detection_area()

	# Initialize object pools if enabled
	if use_object_pooling:
		initialize_enemy_pools()

	print("Spawner initialized at %s with %d enemy types" % [global_position, enemy_scenes.size()])

func setup_detection_area():
	"""Configure the player detection area"""
	if not detection_area:
		detection_area = Area2D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)

	detection_area.monitoring = true
	detection_area.monitorable = false
	detection_area.collision_layer = 0
	detection_area.collision_mask = 2  # Player layer

	# Create or update collision shape
	if not spawn_area_collision:
		spawn_area_collision = CollisionShape2D.new()
		detection_area.add_child(spawn_area_collision)

	var shape = CircleShape2D.new()
	shape.radius = activation_range
	spawn_area_collision.shape = shape

	# Connect signals
	if not detection_area.body_entered.is_connected(_on_detection_area_entered):
		detection_area.body_entered.connect(_on_detection_area_entered)
	if not detection_area.body_exited.is_connected(_on_detection_area_exited):
		detection_area.body_exited.connect(_on_detection_area_exited)

func initialize_enemy_pools():
	"""Pre-create enemy instances for pooling"""
	for scene in enemy_scenes:
		if scene:
			var scene_path = scene.resource_path
			enemy_pool[scene_path] = []

func activate_spawner():
	"""Activate the spawner and start spawning enemies"""
	if is_active:
		return

	is_active = true
	spawner_activated.emit()

	# Start spawn timer with initial delay
	if initial_spawn_delay > 0:
		await get_tree().create_timer(initial_spawn_delay).timeout

	if spawned_enemies.size() < max_concurrent_enemies:
		spawn_enemy()

	spawn_timer.start()
	print("Spawner activated at %s" % global_position)

func deactivate_spawner():
	"""Deactivate the spawner and stop spawning"""
	if not is_active:
		return

	is_active = false
	spawn_timer.stop()
	spawner_deactivated.emit()
	print("Spawner deactivated at %s" % global_position)

func spawn_enemy():
	"""Spawn a new enemy at a random position within spawn area"""
	if not is_active or spawned_enemies.size() >= max_concurrent_enemies:
		return

	# Choose enemy type based on weights
	var enemy_scene = choose_weighted_enemy()
	if not enemy_scene:
		return

	# Find valid spawn position
	var spawn_pos = find_valid_spawn_position()
	if spawn_pos == Vector2.ZERO:
		print("Failed to find valid spawn position")
		return
# Get or create enemy instance
	var enemy: Node2D
	if use_object_pooling:
		enemy = get_pooled_enemy(enemy_scene)
	else:
		enemy = enemy_scene.instantiate()

	# Setup enemy - use call_deferred to avoid physics query conflicts
	call_deferred("_setup_enemy_deferred", enemy, spawn_pos)

func _setup_enemy_deferred(enemy: Node2D, spawn_pos: Vector2):
	"""Setup enemy properties after physics frame to avoid query conflicts"""
	# Add to scene if new instance
	if not enemy.is_inside_tree():
		get_tree().current_scene.add_child(enemy)

	# Setup enemy
	enemy.global_position = spawn_pos
	enemy.set_physics_process(true)
	enemy.set_process(true)
	enemy.visible = true
	
	# Configure collision layers
	enemy.collision_layer = 16
	enemy.collision_mask = 3

	# Reset enemy state
	if enemy.has_method("reset_enemy"):
		enemy.call("reset_enemy")
	else:
		# Reset health if possible using property checking
		if "current_health" in enemy and "max_health" in enemy:
			enemy.current_health = enemy.max_health
		# Reset position and visibility
		enemy.visible = true
		enemy.modulate = Color.WHITE

	# Connect to enemy death signal
	connect_enemy_signals(enemy)
	# Track spawned enemy
	spawned_enemies.append(enemy)
	total_spawned += 1

	# Create spawn effect
	create_spawn_effect(spawn_pos)

	enemy_spawned.emit(enemy, self)
	print("Spawned %s (%s) at %s (Total: %d/%d)" % [enemy.name, enemy.get_script().resource_path if enemy.get_script() else "No Script", spawn_pos, spawned_enemies.size(), max_concurrent_enemies])

func choose_weighted_enemy() -> PackedScene:
	"""Choose an enemy type based on spawn weights"""
	if enemy_scenes.is_empty():
		return null

	# If only one enemy type, return it
	if enemy_scenes.size() == 1:
		return enemy_scenes[0]

	# Calculate total weight
	var total_weight = 0
	for weight in spawn_weights:
		total_weight += weight

	# Choose random value
	var random_value = randi() % total_weight
	var accumulated_weight = 0

	# Find which enemy type to spawn
	for i in range(enemy_scenes.size()):
		accumulated_weight += spawn_weights[i]
		if random_value < accumulated_weight:
			return enemy_scenes[i]

	# Fallback to first enemy type
	return enemy_scenes[0]

func find_valid_spawn_position() -> Vector2:
	"""Find a valid position within spawn area"""
	for attempt in range(max_spawn_attempts):
		# Generate random position within spawn radius
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		var offset = Vector2(cos(angle), sin(angle)) * distance

		# Add height variation if configured
		if spawn_height_variation > 0:
			offset.y += randf_range(-spawn_height_variation, spawn_height_variation)

		var test_position = global_position + offset

		# Check if position is valid (not blocked)
		if is_position_valid(test_position):
			return test_position

	# Fallback to spawner position if no valid position found
	return global_position

func is_position_valid(pos: Vector2) -> bool:
	"""Check if a position is valid for spawning"""
	# Use physics query to check for obstacles
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 1 | 4 | 8  # World, Buildings, Interactables
	query.collide_with_areas = false

	var results = space_state.intersect_point(query, 1)
	return results.is_empty()

func get_pooled_enemy(scene: PackedScene) -> Node2D:
	"""Get an enemy from the pool or create a new one"""
	var scene_path = scene.resource_path

	if not enemy_pool.has(scene_path):
		enemy_pool[scene_path] = []

	# Check for available pooled enemy
	for enemy in enemy_pool[scene_path]:
		if enemy and not enemy.visible and not enemy in spawned_enemies:
			return enemy

	# Create new enemy for pool
	var new_enemy = scene.instantiate()
	enemy_pool[scene_path].append(new_enemy)
	return new_enemy

func connect_enemy_signals(enemy: Node2D):
	"""Connect to enemy signals for tracking"""
	# Try different death signal names
	var death_signals = ["enemy_died", "died", "death", "defeated"]
	var connected = false

	for signal_name in death_signals:
		if enemy.has_signal(signal_name):
			# Connect without binding - let signal send its parameters normally
			enemy.connect(signal_name, _on_enemy_died_signal.bind(enemy), CONNECT_ONE_SHOT)
			connected = true
			print("Connected to enemy death signal: %s" % signal_name)
			break

	if not connected:
		print("Warning: Enemy %s has no recognizable death signal" % enemy.name)

func _on_enemy_died_signal(enemy_type: String, position: Vector2, enemy: Node2D = null):
	"""Handle enemy death signal from enemies"""
	# If enemy wasn't passed as third parameter, find it by position
	if not enemy:
		for e in spawned_enemies:
			if e.global_position.distance_to(position) < 10:
				enemy = e
				break

	if enemy:
		_on_enemy_died(enemy)

func _on_enemy_died(enemy: Node2D):
	"""Handle enemy death"""
	# Find the enemy in our spawned list
	var dead_enemy = null
	for e in spawned_enemies:
		if e == enemy:
			dead_enemy = e
			break

	if dead_enemy:
		spawned_enemies.erase(dead_enemy)

		# Return to pool if using pooling
		if use_object_pooling and dead_enemy:
			dead_enemy.visible = false
			dead_enemy.set_physics_process(false)
			dead_enemy.set_process(false)
			dead_enemy.global_position = Vector2(-10000, -10000)  # Move off-screen

		print("Enemy died. Remaining: %d/%d" % [spawned_enemies.size(), max_concurrent_enemies])

		# Apply respawn delay
		if respawn_delay > 0 and is_active:
			spawn_cooldown_active = true
			await get_tree().create_timer(respawn_delay).timeout
			spawn_cooldown_active = false

func create_spawn_effect(pos: Vector2):
	"""Create visual effect when enemy spawns"""
	var effect = Node2D.new()
	var particles = CPUParticles2D.new()

	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.speed_scale = 2.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.spread = 45.0
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color(1.0, 0.5, 0.0)

	effect.add_child(particles)
	effect.global_position = pos
	get_tree().current_scene.add_child(effect)

	# Clean up effect after particles finish
	await get_tree().create_timer(1.0).timeout
	effect.queue_free()

func _on_spawn_timer_timeout():
	"""Handle spawn timer timeout"""
	if not is_active or spawn_cooldown_active:
		return

	if spawned_enemies.size() < max_concurrent_enemies:
		spawn_enemy()
	elif spawned_enemies.size() == max_concurrent_enemies:
		spawn_limit_reached.emit()

func _on_detection_area_entered(body: Node2D):
	"""Handle player entering activation range"""
	if body.is_in_group("player"):
		player_in_range = true
		if not is_active and not always_active:
			activate_spawner()

func _on_detection_area_exited(body: Node2D):
	"""Handle player leaving activation range"""
	if body.is_in_group("player"):
		player_in_range = false
		if is_active and deactivate_on_player_exit and not always_active:
			deactivate_spawner()

func check_activation():
	"""Check if spawner should be activated based on player distance"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= activation_range:
		if not is_active:
			activate_spawner()
	elif is_active and deactivate_on_player_exit:
		deactivate_spawner()

func clear_all_enemies():
	"""Remove all spawned enemies"""
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	print("Cleared all enemies from spawner at %s" % global_position)

func reset_spawner():
	"""Reset spawner to initial state"""
	clear_all_enemies()
	is_active = false
	spawn_timer.stop()
	total_spawned = 0
	spawn_cooldown_active = false

func _draw():
	"""Draw spawn area and activation range in editor"""
	if not Engine.is_editor_hint():
		return

	# Draw spawn area
	if show_spawn_area:
		draw_circle(Vector2.ZERO, spawn_radius, spawn_area_color)
		if min_spawn_distance > 0:
			draw_circle(Vector2.ZERO, min_spawn_distance, Color(spawn_area_color.r, spawn_area_color.g, spawn_area_color.b, spawn_area_color.a * 0.5))

	# Draw activation range
	if show_activation_range and not always_active:
		draw_arc(Vector2.ZERO, activation_range, 0, TAU, 32, activation_range_color, 2.0)

func get_spawner_stats() -> Dictionary:
	"""Get current spawner statistics"""
	return {
		"active": is_active,
		"spawned_enemies": spawned_enemies.size(),
		"max_enemies": max_concurrent_enemies,
		"total_spawned": total_spawned,
		"player_in_range": player_in_range,
		"position": global_position
	}
