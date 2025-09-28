extends Node
## QuickSpawner - One-line spawner setup for any scene

## Usage: Add `QuickSpawner.setup_basic_spawners(self)` to any scene's _ready() function

static func setup_basic_spawners(scene: Node):
	"""Add basic enemy spawners to any scene automatically"""
	var spawner_positions = [
		Vector2(200, 100),   # Right side
		Vector2(-200, -100), # Left side
		Vector2(0, 200)      # Bottom
	]

	for pos in spawner_positions:
		create_light_spawner(scene, pos)

static func setup_dangerous_spawners(scene: Node):
	"""Add dangerous enemy spawners for late-game areas"""
	var spawner_positions = [
		Vector2(300, 0),
		Vector2(-300, 0),
		Vector2(0, 300),
		Vector2(0, -300)
	]

	for pos in spawner_positions:
		create_heavy_spawner(scene, pos)

static func create_light_spawner(scene: Node, position: Vector2):
	"""Create a lightweight patrol spawner"""
	var spawner = preload("res://scenes/systems/EnemySpawner.tscn").instantiate()
	spawner.name = "QuickSpawner_Light"
	spawner.global_position = position

	# Light enemies only
	spawner.enemy_scenes.clear()
	spawner.enemy_scenes.append(preload("res://scenes/enemies/BasicEnemy.tscn"))
	spawner.enemy_scenes.append(preload("res://scenes/enemies/EnemyAI.tscn"))
	spawner.spawn_weights = [2, 1]

	# Conservative settings
	spawner.spawn_frequency = 5.0
	spawner.max_concurrent_enemies = 2
	spawner.activation_range = 250.0
	spawner.spawn_radius = 80.0

	scene.add_child(spawner)

	# Register with SpawnerManager
	var spawner_manager = scene.get_node_or_null("/root/SpawnerManager")
	if spawner_manager:
		spawner_manager.register_spawner(spawner)

static func create_heavy_spawner(scene: Node, position: Vector2):
	"""Create a dangerous area spawner"""
	var spawner = preload("res://scenes/systems/EnemySpawner.tscn").instantiate()
	spawner.name = "QuickSpawner_Heavy"
	spawner.global_position = position

	# Heavy enemies only
	spawner.enemy_scenes.clear()
	spawner.enemy_scenes.append(preload("res://scenes/enemies/HeavyMeleeEnemy.tscn"))
	spawner.enemy_scenes.append(preload("res://scenes/enemies/EngineerEnemy.tscn"))
	spawner.spawn_weights = [1, 1]

	# Aggressive settings
	spawner.spawn_frequency = 8.0
	spawner.max_concurrent_enemies = 3
	spawner.activation_range = 400.0
	spawner.spawn_radius = 120.0
	spawner.always_active = true

	scene.add_child(spawner)

	# Register with SpawnerManager
	var spawner_manager = scene.get_node_or_null("/root/SpawnerManager")
	if spawner_manager:
		spawner_manager.register_spawner(spawner)

static func create_custom_spawner(scene: Node, position: Vector2, config: Dictionary):
	"""Create a custom spawner with specified configuration

	Example config:
	{
		"enemies": ["BasicEnemy", "RangedEnemy"],
		"weights": [2, 1],
		"spawn_frequency": 4.0,
		"max_concurrent": 3,
		"activation_range": 300.0,
		"spawn_radius": 100.0
	}
	"""
	var spawner = preload("res://scenes/systems/EnemySpawner.tscn").instantiate()
	spawner.name = "QuickSpawner_Custom"
	spawner.global_position = position

	var enemy_scene_map = {
		"BasicEnemy": "res://scenes/enemies/BasicEnemy.tscn",
		"EnemyAI": "res://scenes/enemies/EnemyAI.tscn",
		"RangedEnemy": "res://scenes/enemies/RangedEnemy.tscn",
		"HeavyMeleeEnemy": "res://scenes/enemies/HeavyMeleeEnemy.tscn",
		"ScoutEnemy": "res://scenes/enemies/ScoutEnemy.tscn",
		"EngineerEnemy": "res://scenes/enemies/EngineerEnemy.tscn"
	}

	# Configure enemy types
	spawner.enemy_scenes.clear()
	for enemy_name in config.get("enemies", ["BasicEnemy"]):
		if enemy_scene_map.has(enemy_name):
			spawner.enemy_scenes.append(load(enemy_scene_map[enemy_name]))

	# Set configuration
	spawner.spawn_weights = config.get("weights", [1])
	spawner.spawn_frequency = config.get("spawn_frequency", 3.0)
	spawner.max_concurrent_enemies = config.get("max_concurrent", 3)
	spawner.activation_range = config.get("activation_range", 300.0)
	spawner.spawn_radius = config.get("spawn_radius", 100.0)
	spawner.always_active = config.get("always_active", false)

	scene.add_child(spawner)

	# Register with SpawnerManager
	var spawner_manager = scene.get_node_or_null("/root/SpawnerManager")
	if spawner_manager:
		spawner_manager.register_spawner(spawner)