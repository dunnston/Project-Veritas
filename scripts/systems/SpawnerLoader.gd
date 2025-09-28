extends Node
## SpawnerLoader - Helper to load spawners from JSON configuration

const SPAWNER_CONFIG_PATH = "res://data/spawner_configs.json"

var enemy_scene_map = {
	"BasicEnemy": "res://scenes/enemies/BasicEnemy.tscn",
	"EnemyAI": "res://scenes/enemies/EnemyAI.tscn",
	"RangedEnemy": "res://scenes/enemies/RangedEnemy.tscn",
	"HeavyMeleeEnemy": "res://scenes/enemies/HeavyMeleeEnemy.tscn",
	"ScoutEnemy": "res://scenes/enemies/ScoutEnemy.tscn",
	"EngineerEnemy": "res://scenes/enemies/EngineerEnemy.tscn"
}

var spawner_configs = {}

func _ready():
	load_spawner_configs()

func load_spawner_configs():
	"""Load spawner configurations from JSON"""
	if not FileAccess.file_exists(SPAWNER_CONFIG_PATH):
		print("Warning: Spawner config file not found: %s" % SPAWNER_CONFIG_PATH)
		return

	var file = FileAccess.open(SPAWNER_CONFIG_PATH, FileAccess.READ)
	if not file:
		print("Error: Could not open spawner config file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		print("Error parsing spawner config JSON: %s" % json.get_error_message())
		return

	spawner_configs = json.data
	print("Loaded spawner configurations")

func create_spawner_from_preset(preset_name: String, position: Vector2, spawner_name: String = "") -> EnemySpawner:
	"""Create a spawner using a preset configuration"""
	if not spawner_configs.has("spawner_presets") or not spawner_configs.spawner_presets.has(preset_name):
		print("Error: Spawner preset '%s' not found" % preset_name)
		return null

	var preset = spawner_configs.spawner_presets[preset_name]
	var spawner = preload("res://scenes/systems/EnemySpawner.tscn").instantiate()

	# Set basic properties
	spawner.name = spawner_name if spawner_name != "" else preset_name
	spawner.global_position = position

	# Configure enemy types
	for enemy_type in preset.enemies:
		if enemy_scene_map.has(enemy_type):
			var enemy_scene = load(enemy_scene_map[enemy_type])
			spawner.enemy_scenes.append(enemy_scene)
		else:
			print("Warning: Unknown enemy type '%s'" % enemy_type)

	# Set spawn weights
	if preset.has("weights") and preset.weights.size() == preset.enemies.size():
		for weight in preset.weights:
			spawner.spawn_weights.append(weight)

	# Configure spawn settings
	spawner.spawn_frequency = preset.get("spawn_frequency", 3.0)
	spawner.max_concurrent_enemies = preset.get("max_concurrent", 3)
	spawner.activation_range = preset.get("activation_range", 300.0)
	spawner.spawn_radius = preset.get("spawn_radius", 100.0)
	spawner.always_active = preset.get("always_active", false)
	spawner.initial_spawn_delay = preset.get("initial_delay", 0.0)
	spawner.respawn_delay = preset.get("respawn_delay", 2.0)

	return spawner

func load_spawners_for_level(level_name: String, parent_node: Node):
	"""Load all spawners for a specific level"""
	if not spawner_configs.has("level_spawner_layouts") or not spawner_configs.level_spawner_layouts.has(level_name):
		print("No spawner layout found for level: %s" % level_name)
		return

	var level_layout = spawner_configs.level_spawner_layouts[level_name]
	var spawners_created = 0

	for spawner_data in level_layout:
		var preset_name = spawner_data.preset
		var pos = Vector2(spawner_data.position[0], spawner_data.position[1])
		var name = spawner_data.get("name", preset_name)

		var spawner = create_spawner_from_preset(preset_name, pos, name)
		if spawner:
			parent_node.add_child(spawner)

			# Register with SpawnerManager
			var spawner_manager = get_node_or_null("/root/SpawnerManager")
			if spawner_manager:
				spawner_manager.register_spawner(spawner)

			spawners_created += 1

	print("Created %d spawners for level '%s'" % [spawners_created, level_name])

func get_available_presets() -> Array[String]:
	"""Get list of available spawner presets"""
	if spawner_configs.has("spawner_presets"):
		return spawner_configs.spawner_presets.keys()
	return []

func get_preset_info(preset_name: String) -> Dictionary:
	"""Get information about a specific preset"""
	if spawner_configs.has("spawner_presets") and spawner_configs.spawner_presets.has(preset_name):
		return spawner_configs.spawner_presets[preset_name]
	return {}