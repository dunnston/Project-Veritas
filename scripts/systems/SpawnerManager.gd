extends Node
## SpawnerManager - Global control system for all enemy spawners

signal all_spawners_activated()
signal all_spawners_deactivated()
signal spawner_registered(spawner: EnemySpawner)
signal spawner_unregistered(spawner: EnemySpawner)
signal enemy_count_changed(total_enemies: int)

## Configuration
@export var global_spawn_limit: int = 50  ## Maximum enemies across all spawners
@export var enable_performance_mode: bool = true  ## Auto-disable distant spawners
@export var performance_check_interval: float = 2.0  ## How often to check spawner distances
@export var max_active_spawners: int = 10  ## Maximum spawners active at once
@export var spawner_cull_distance: float = 1000.0  ## Distance to auto-disable spawners

## Runtime State
var registered_spawners: Array[EnemySpawner] = []
var active_spawners: Array[EnemySpawner] = []
var total_enemy_count: int = 0
var performance_timer: Timer
var player_reference: Node3D

## Statistics
var stats = {
	"total_enemies_spawned": 0,
	"total_enemies_killed": 0,
	"spawners_registered": 0,
	"spawners_active": 0,
	"current_enemy_count": 0
}

func _ready():
	set_process(false)  # We'll use timer for performance checks

	# Create performance check timer
	if enable_performance_mode:
		setup_performance_timer()

	# Connect to game manager for player reference
	call_deferred("setup_player_reference")

	print("SpawnerManager initialized")

func setup_performance_timer():
	"""Setup timer for performance checks"""
	performance_timer = Timer.new()
	performance_timer.wait_time = performance_check_interval
	performance_timer.timeout.connect(_on_performance_check)
	performance_timer.autostart = true
	add_child(performance_timer)

func setup_player_reference():
	"""Get reference to player for distance checks"""
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		push_warning("SpawnerManager: No player found in scene")

func register_spawner(spawner: EnemySpawner):
	"""Register a new spawner with the manager"""
	if spawner in registered_spawners:
		return

	registered_spawners.append(spawner)
	stats.spawners_registered += 1

	# Connect to spawner signals
	if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		spawner.enemy_spawned.connect(_on_enemy_spawned)
	if not spawner.spawner_activated.is_connected(_on_spawner_activated.bind(spawner)):
		spawner.spawner_activated.connect(_on_spawner_activated.bind(spawner))
	if not spawner.spawner_deactivated.is_connected(_on_spawner_deactivated.bind(spawner)):
		spawner.spawner_deactivated.connect(_on_spawner_deactivated.bind(spawner))

	spawner_registered.emit(spawner)
	print("Registered spawner at %s (Total: %d)" % [spawner.global_position, registered_spawners.size()])

func unregister_spawner(spawner: EnemySpawner):
	"""Unregister a spawner from the manager"""
	if spawner not in registered_spawners:
		return

	registered_spawners.erase(spawner)
	active_spawners.erase(spawner)
	stats.spawners_registered -= 1

	# Disconnect signals
	if spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		spawner.enemy_spawned.disconnect(_on_enemy_spawned)
	if spawner.spawner_activated.is_connected(_on_spawner_activated):
		spawner.spawner_activated.disconnect(_on_spawner_activated)
	if spawner.spawner_deactivated.is_connected(_on_spawner_deactivated):
		spawner.spawner_deactivated.disconnect(_on_spawner_deactivated)

	spawner_unregistered.emit(spawner)
	print("Unregistered spawner at %s" % spawner.global_position)

func activate_all_spawners():
	"""Activate all registered spawners"""
	for spawner in registered_spawners:
		if spawner and not spawner.is_active:
			spawner.activate_spawner()
	all_spawners_activated.emit()

func deactivate_all_spawners():
	"""Deactivate all spawners"""
	for spawner in registered_spawners:
		if spawner and spawner.is_active:
			spawner.deactivate_spawner()
	active_spawners.clear()
	all_spawners_deactivated.emit()

func clear_all_enemies():
	"""Clear all enemies from all spawners"""
	for spawner in registered_spawners:
		if spawner:
			spawner.clear_all_enemies()
	total_enemy_count = 0
	enemy_count_changed.emit(0)

func reset_all_spawners():
	"""Reset all spawners to initial state"""
	for spawner in registered_spawners:
		if spawner:
			spawner.reset_spawner()
	active_spawners.clear()
	total_enemy_count = 0
	stats.current_enemy_count = 0

func get_nearest_spawner_to_player() -> EnemySpawner:
	"""Get the spawner nearest to the player"""
	if not player_reference or registered_spawners.is_empty():
		return null

	var nearest_spawner: EnemySpawner = null
	var nearest_distance: float = INF

	for spawner in registered_spawners:
		if spawner:
			var distance = spawner.global_position.distance_to(player_reference.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_spawner = spawner

	return nearest_spawner

func get_active_spawner_count() -> int:
	"""Get number of currently active spawners"""
	return active_spawners.size()

func get_total_enemy_count() -> int:
	"""Get total enemies across all spawners"""
	var count = 0
	for spawner in registered_spawners:
		if spawner:
			count += spawner.spawned_enemies.size()
	return count

func is_under_global_limit() -> bool:
	"""Check if we're under the global enemy limit"""
	return get_total_enemy_count() < global_spawn_limit

func _on_performance_check():
	"""Periodic check for performance optimization"""
	if not enable_performance_mode or not player_reference:
		return

	var spawners_to_check = registered_spawners.duplicate()

	# Sort spawners by distance to player
	spawners_to_check.sort_custom(func(a, b):
		var dist_a = a.global_position.distance_to(player_reference.global_position)
		var dist_b = b.global_position.distance_to(player_reference.global_position)
		return dist_a < dist_b
	)

	# Manage spawner activation based on distance and limits
	var active_count = 0
	for spawner in spawners_to_check:
		if not spawner:
			continue

		var distance = spawner.global_position.distance_to(player_reference.global_position)

		# Check if spawner should be active
		var should_be_active = (
			distance <= spawner_cull_distance and
			active_count < max_active_spawners and
			(spawner.always_active or distance <= spawner.activation_range)
		)

		# Activate or deactivate as needed
		if should_be_active and not spawner.is_active:
			spawner.activate_spawner()
			active_count += 1
		elif not should_be_active and spawner.is_active and not spawner.always_active:
			spawner.deactivate_spawner()

	update_stats()

func _on_enemy_spawned(enemy: Node3D, spawner: EnemySpawner):
	"""Handle enemy spawn from any spawner"""
	total_enemy_count += 1
	stats.total_enemies_spawned += 1
	stats.current_enemy_count = get_total_enemy_count()

	# Connect to enemy death if possible
	connect_enemy_death_signal(enemy)

	enemy_count_changed.emit(total_enemy_count)

	# Check global limit
	if total_enemy_count >= global_spawn_limit:
		print("Global spawn limit reached (%d/%d)" % [total_enemy_count, global_spawn_limit])
		# Temporarily disable spawning on all spawners
		for s in registered_spawners:
			if s and s.is_active:
				s.spawn_timer.stop()

func connect_enemy_death_signal(enemy: Node3D):
	"""Connect to enemy death signal for tracking"""
	var death_signals = ["enemy_died", "died", "death", "defeated"]
	for signal_name in death_signals:
		if enemy.has_signal(signal_name):
			if not enemy.is_connected(signal_name, _on_enemy_died):
				enemy.connect(signal_name, _on_enemy_died)
				break

func _on_enemy_died(_enemy_type, _position, _enemy = null):
	"""Handle enemy death"""
	total_enemy_count = max(0, total_enemy_count - 1)
	stats.total_enemies_killed += 1
	stats.current_enemy_count = get_total_enemy_count()

	enemy_count_changed.emit(total_enemy_count)

	# Re-enable spawning if under global limit
	if total_enemy_count < global_spawn_limit:
		for spawner in active_spawners:
			if spawner and spawner.is_active and not spawner.spawn_timer.is_stopped():
				spawner.spawn_timer.start()

func _on_spawner_activated(spawner: EnemySpawner):
	"""Handle spawner activation"""
	if spawner not in active_spawners:
		active_spawners.append(spawner)
		stats.spawners_active = active_spawners.size()

func _on_spawner_deactivated(spawner: EnemySpawner):
	"""Handle spawner deactivation"""
	active_spawners.erase(spawner)
	stats.spawners_active = active_spawners.size()

func update_stats():
	"""Update manager statistics"""
	stats.spawners_active = active_spawners.size()
	stats.current_enemy_count = get_total_enemy_count()

func get_stats() -> Dictionary:
	"""Get current manager statistics"""
	update_stats()
	return stats

func get_spawners_in_radius(position: Vector3, radius: float) -> Array[EnemySpawner]:
	"""Get all spawners within a certain radius of a position"""
	var spawners_in_range: Array[EnemySpawner] = []

	for spawner in registered_spawners:
		if spawner and spawner.global_position.distance_to(position) <= radius:
			spawners_in_range.append(spawner)

	return spawners_in_range

func set_spawn_rate_multiplier(multiplier: float):
	"""Adjust spawn rate for all spawners"""
	for spawner in registered_spawners:
		if spawner:
			spawner.spawn_timer.wait_time = spawner.spawn_frequency / multiplier

func pause_all_spawning():
	"""Pause spawning on all spawners without deactivating them"""
	for spawner in active_spawners:
		if spawner:
			spawner.spawn_timer.paused = true

func resume_all_spawning():
	"""Resume spawning on all active spawners"""
	for spawner in active_spawners:
		if spawner:
			spawner.spawn_timer.paused = false
