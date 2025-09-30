extends Node

class_name SaveManagerModule

signal save_completed()
signal load_completed()
signal save_failed(error_message: String)
signal load_failed(error_message: String)

@export var config: SaveManagerConfig

const DEFAULT_SAVE_PATH = "user://savegame.save"
const DEFAULT_SETTINGS_PATH = "user://settings.cfg"
const BACKUP_SAVE_PATH = "user://savegame.backup"

var current_save_data: Dictionary = {}
var save_version: int = 2  # Incremented for modular system
var auto_save_enabled: bool = true
var auto_save_interval: float = 300.0  # 5 minutes
var auto_save_timer: Timer

func _ready() -> void:
	if not config:
		config = SaveManagerConfig.new()

	setup_auto_save()
	load_settings()
	print("SaveManager (Modular) initialized")

func setup_auto_save() -> void:
	auto_save_timer = Timer.new()
	auto_save_timer.wait_time = auto_save_interval
	auto_save_timer.timeout.connect(_auto_save)
	auto_save_timer.autostart = auto_save_enabled
	add_child(auto_save_timer)

func _auto_save() -> void:
	if auto_save_enabled:
		save_game(true)  # Silent auto-save

func save_game(silent: bool = false) -> bool:
	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH

	# Create backup before saving
	if FileAccess.file_exists(save_path):
		var dir = DirAccess.open("user://")
		dir.copy(save_path, BACKUP_SAVE_PATH)

	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	if not save_file:
		var error_msg = "Failed to open save file for writing: " + save_path
		if not silent:
			push_error(error_msg)
			save_failed.emit(error_msg)
		return false

	var save_data = collect_save_data()

	save_file.store_var(save_data)
	save_file.close()

	current_save_data = save_data
	save_completed.emit()
	if not silent:
		print("Game saved successfully")
	return true

func collect_save_data() -> Dictionary:
	var save_data = {
		"version": save_version,
		"timestamp": Time.get_unix_time_from_system(),
		"game_time": 0.0,
		"modules": {}
	}

	# Get game time from GameManager if available
	if GameManager:
		save_data["game_time"] = GameManager.game_time

	# Collect data from all registered systems
	collect_modular_inventory_data(save_data)
	collect_skill_system_data(save_data)
	collect_attribute_manager_data(save_data)
	collect_equipment_manager_data(save_data)
	collect_weapon_manager_data(save_data)
	collect_ammo_manager_data(save_data)
	collect_crafting_manager_data(save_data)
	collect_building_manager_data(save_data)
	collect_time_manager_data(save_data)
	collect_player_data(save_data)
	collect_world_data(save_data)

	return save_data

func collect_modular_inventory_data(save_data: Dictionary) -> void:
	if InventorySystem and InventorySystem.has_method("get_save_data"):
		save_data.modules["inventory"] = InventorySystem.get_save_data()

func collect_skill_system_data(save_data: Dictionary) -> void:
	if SkillSystem and SkillSystem.has_method("get_save_data"):
		save_data.modules["skills"] = SkillSystem.get_save_data()

func collect_attribute_manager_data(save_data: Dictionary) -> void:
	if AttributeManager and AttributeManager.has_method("get_save_data"):
		save_data.modules["attributes"] = AttributeManager.get_save_data()

func collect_equipment_manager_data(save_data: Dictionary) -> void:
	if EquipmentManager and EquipmentManager.has_method("get_save_data"):
		save_data.modules["equipment"] = EquipmentManager.get_save_data()

func collect_weapon_manager_data(save_data: Dictionary) -> void:
	if WeaponManager and WeaponManager.has_method("get_save_data"):
		save_data.modules["weapons"] = WeaponManager.get_save_data()

func collect_ammo_manager_data(save_data: Dictionary) -> void:
	if AmmoManager and AmmoManager.has_method("get_save_data"):
		save_data.modules["ammo"] = AmmoManager.get_save_data()

func collect_crafting_manager_data(save_data: Dictionary) -> void:
	if CraftingManager and CraftingManager.has_method("get_save_data"):
		save_data.modules["crafting"] = CraftingManager.get_save_data()

func collect_building_manager_data(save_data: Dictionary) -> void:
	if BuildingManager and BuildingManager.has_method("get_save_data"):
		save_data.modules["buildings"] = BuildingManager.get_save_data()

func collect_time_manager_data(save_data: Dictionary) -> void:
	if TimeManager and TimeManager.has_method("get_save_data"):
		save_data.modules["time"] = TimeManager.get_save_data()

func collect_player_data(save_data: Dictionary) -> void:
	if GameManager and GameManager.player_node:
		var player_data = {}
		var player = GameManager.player_node

		# Handle both 2D and 3D positions
		if player.has_method("get_position_3d"):
			player_data["position"] = player.get_position_3d()  # Vector3
		elif "global_position" in player:
			var pos2d = player.global_position  # Vector2
			player_data["position"] = Vector3(pos2d.x, pos2d.y, 0)  # Convert to Vector3

		# Collect player stats
		if player.has_method("get_health"):
			player_data["health"] = player.get_health()
		if player.has_method("get_energy"):
			player_data["energy"] = player.get_energy()
		if player.has_method("get_hunger"):
			player_data["hunger"] = player.get_hunger()

		save_data.modules["player"] = player_data

func collect_world_data(save_data: Dictionary) -> void:
	var world_data = {}

	if TimeManager:
		world_data["day_cycle_time"] = TimeManager.current_time if "current_time" in TimeManager else 0.0
		world_data["current_day"] = TimeManager.current_day if "current_day" in TimeManager else 1

	save_data.modules["world"] = world_data

func load_game() -> bool:
	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH

	if not FileAccess.file_exists(save_path):
		var error_msg = "Save file does not exist: " + save_path
		push_warning(error_msg)
		load_failed.emit(error_msg)
		return false

	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if not save_file:
		var error_msg = "Failed to open save file for reading: " + save_path
		push_error(error_msg)
		load_failed.emit(error_msg)
		return false

	var save_data = save_file.get_var()
	save_file.close()

	if not validate_save_data(save_data):
		var error_msg = "Invalid save data format"
		push_error(error_msg)
		load_failed.emit(error_msg)
		return false

	apply_save_data(save_data)
	current_save_data = save_data
	load_completed.emit()
	print("Game loaded successfully")
	return true

func validate_save_data(data: Dictionary) -> bool:
	var required_keys = ["version", "timestamp", "modules"]
	for key in required_keys:
		if key not in data:
			return false

	# Check version compatibility
	if data.get("version", 1) > save_version:
		push_warning("Save file is from newer version, may have compatibility issues")

	return true

func apply_save_data(data: Dictionary) -> void:
	# Apply game time
	if GameManager and "game_time" in data:
		GameManager.game_time = data["game_time"]

	var modules = data.get("modules", {})

	# Apply data to all registered systems
	apply_modular_inventory_data(modules)
	apply_skill_system_data(modules)
	apply_attribute_manager_data(modules)
	apply_equipment_manager_data(modules)
	apply_weapon_manager_data(modules)
	apply_ammo_manager_data(modules)
	apply_crafting_manager_data(modules)
	apply_building_manager_data(modules)
	apply_time_manager_data(modules)
	apply_player_data(modules)
	apply_world_data(modules)

func apply_modular_inventory_data(modules: Dictionary) -> void:
	if InventorySystem and InventorySystem.has_method("load_save_data") and "inventory" in modules:
		InventorySystem.load_save_data(modules["inventory"])

func apply_skill_system_data(modules: Dictionary) -> void:
	if SkillSystem and SkillSystem.has_method("load_save_data") and "skills" in modules:
		SkillSystem.load_save_data(modules["skills"])

func apply_attribute_manager_data(modules: Dictionary) -> void:
	if AttributeManager and AttributeManager.has_method("load_save_data") and "attributes" in modules:
		AttributeManager.load_save_data(modules["attributes"])

func apply_equipment_manager_data(modules: Dictionary) -> void:
	if EquipmentManager and EquipmentManager.has_method("load_save_data") and "equipment" in modules:
		EquipmentManager.load_save_data(modules["equipment"])

func apply_weapon_manager_data(modules: Dictionary) -> void:
	if WeaponManager and WeaponManager.has_method("load_save_data") and "weapons" in modules:
		WeaponManager.load_save_data(modules["weapons"])

func apply_ammo_manager_data(modules: Dictionary) -> void:
	if AmmoManager and AmmoManager.has_method("load_save_data") and "ammo" in modules:
		AmmoManager.load_save_data(modules["ammo"])

func apply_crafting_manager_data(modules: Dictionary) -> void:
	if CraftingManager and CraftingManager.has_method("load_save_data") and "crafting" in modules:
		CraftingManager.load_save_data(modules["crafting"])

func apply_building_manager_data(modules: Dictionary) -> void:
	if BuildingManager and BuildingManager.has_method("load_save_data") and "buildings" in modules:
		BuildingManager.load_save_data(modules["buildings"])

func apply_time_manager_data(modules: Dictionary) -> void:
	if TimeManager and TimeManager.has_method("load_save_data") and "time" in modules:
		TimeManager.load_save_data(modules["time"])

func apply_player_data(modules: Dictionary) -> void:
	if GameManager and GameManager.player_node and "player" in modules:
		var player_data = modules["player"]
		var player = GameManager.player_node

		# Handle position (supports both 2D and 3D)
		if "position" in player_data:
			var pos = player_data["position"]
			if pos is Vector3:
				if player.has_method("set_position_3d"):
					player.set_position_3d(pos)
				elif "global_position" in player:
					player.global_position = Vector2(pos.x, pos.y)  # Convert Vector3 to Vector2 for 2D
			elif pos is Vector2:
				if "global_position" in player:
					player.global_position = pos

		# Apply player stats
		if "health" in player_data and player.has_method("set_health"):
			player.set_health(player_data["health"])
		if "energy" in player_data and player.has_method("set_energy"):
			player.set_energy(player_data["energy"])
		if "hunger" in player_data and player.has_method("set_hunger"):
			player.set_hunger(player_data["hunger"])

func apply_world_data(modules: Dictionary) -> void:
	if "world" in modules and TimeManager:
		var world_data = modules["world"]
		if "day_cycle_time" in world_data:
			TimeManager.current_time = world_data["day_cycle_time"]
		if "current_day" in world_data:
			TimeManager.current_day = world_data["current_day"]

func save_settings() -> void:
	var settings_path = config.settings_file_path if config.settings_file_path else DEFAULT_SETTINGS_PATH
	var config_file = ConfigFile.new()

	# Default settings
	config_file.set_value("audio", "master_volume", config.default_master_volume)
	config_file.set_value("audio", "sfx_volume", config.default_sfx_volume)
	config_file.set_value("audio", "music_volume", config.default_music_volume)

	config_file.set_value("graphics", "fullscreen", config.default_fullscreen)
	config_file.set_value("graphics", "vsync", config.default_vsync)

	config_file.set_value("gameplay", "auto_save_enabled", auto_save_enabled)
	config_file.set_value("gameplay", "auto_save_interval", auto_save_interval)

	config_file.save(settings_path)

func load_settings() -> void:
	var settings_path = config.settings_file_path if config.settings_file_path else DEFAULT_SETTINGS_PATH
	var config_file = ConfigFile.new()
	var err = config_file.load(settings_path)

	if err != OK:
		save_settings()
		return

	# Load gameplay settings
	auto_save_enabled = config_file.get_value("gameplay", "auto_save_enabled", true)
	auto_save_interval = config_file.get_value("gameplay", "auto_save_interval", 300.0)

	if auto_save_timer:
		auto_save_timer.wait_time = auto_save_interval
		auto_save_timer.autostart = auto_save_enabled

func has_save_file() -> bool:
	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH
	return FileAccess.file_exists(save_path)

func has_backup_file() -> bool:
	return FileAccess.file_exists(BACKUP_SAVE_PATH)

func restore_backup() -> bool:
	if not has_backup_file():
		return false

	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH
	var dir = DirAccess.open("user://")
	dir.copy(BACKUP_SAVE_PATH, save_path)
	return true

func delete_save() -> void:
	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH
	if has_save_file():
		DirAccess.remove_absolute(save_path)
		current_save_data.clear()
		print("Save file deleted")

func get_save_info() -> Dictionary:
	if not has_save_file():
		return {}

	var save_path = config.save_file_path if config.save_file_path else DEFAULT_SAVE_PATH
	var save_file = FileAccess.open(save_path, FileAccess.READ)
	if not save_file:
		return {}

	var save_data = save_file.get_var()
	save_file.close()

	return {
		"version": save_data.get("version", 1),
		"timestamp": save_data.get("timestamp", 0),
		"game_time": save_data.get("game_time", 0.0),
		"file_size": FileAccess.get_file_as_bytes(save_path).size()
	}
