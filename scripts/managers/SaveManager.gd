extends Node

class_name SaveManagerLegacy

signal save_completed()
signal load_completed()

const SAVE_PATH = "user://savegame.save"
const SETTINGS_PATH = "user://settings.cfg"

var current_save_data: Dictionary = {}

func _ready() -> void:
	load_settings()
	print("SaveManager initialized")

func save_game() -> bool:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not save_file:
		push_error("Failed to open save file for writing")
		return false
	
	var save_data = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"game_time": GameManager.game_time,
		"inventory": InventorySystem.get_save_data(),
		"buildings": BuildingManager.get_all_buildings(),
		"unlocked_recipes": CraftingManager.unlocked_recipes,
		"player_data": get_player_save_data(),
		"world_data": get_world_save_data(),
		"skill_data": get_node("/root/SkillSystem").get_save_data() if has_node("/root/SkillSystem") else {}
	}
	
	save_file.store_var(save_data)
	save_file.close()
	
	current_save_data = save_data
	save_completed.emit()
	print("Game saved successfully")
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("Save file does not exist")
		return false
	
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not save_file:
		push_error("Failed to open save file for reading")
		return false
	
	var save_data = save_file.get_var()
	save_file.close()
	
	if not validate_save_data(save_data):
		push_error("Invalid save data")
		return false
	
	apply_save_data(save_data)
	current_save_data = save_data
	load_completed.emit()
	print("Game loaded successfully")
	return true

func validate_save_data(data: Dictionary) -> bool:
	var required_keys = ["version", "timestamp", "game_time", "resources", "buildings"]
	for key in required_keys:
		if key not in data:
			return false
	return true

func apply_save_data(data: Dictionary) -> void:
	GameManager.game_time = data.get("game_time", 0.0)
	
	if "inventory" in data:
		InventorySystem.load_save_data(data["inventory"])
	
	if "buildings" in data:
		BuildingManager.placed_buildings = data["buildings"]
	
	if "unlocked_recipes" in data:
		CraftingManager.unlocked_recipes = data["unlocked_recipes"]
	
	if "player_data" in data:
		apply_player_save_data(data["player_data"])
	
	if "world_data" in data:
		apply_world_save_data(data["world_data"])
	
	if "skill_data" in data and has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.load_save_data(data["skill_data"])

func get_player_save_data() -> Dictionary:
	if GameManager.player_node:
		return {
			"position": GameManager.player_node.position,
			"health": GameManager.player_node.get("health"),
			"energy": GameManager.player_node.get("energy"),
			"hunger": GameManager.player_node.get("hunger")
		}
	return {}

func apply_player_save_data(data: Dictionary) -> void:
	if GameManager.player_node:
		if "position" in data:
			GameManager.player_node.position = data["position"]
		if "health" in data:
			GameManager.player_node.set("health", data["health"])
		if "energy" in data:
			GameManager.player_node.set("energy", data["energy"])
		if "hunger" in data:
			GameManager.player_node.set("hunger", data["hunger"])

func get_world_save_data() -> Dictionary:
	if GameManager.world_node:
		return {
			"day_cycle_time": TimeManager.current_time,
			"current_day": TimeManager.current_day
		}
	return {}

func apply_world_save_data(data: Dictionary) -> void:
	if "day_cycle_time" in data:
		TimeManager.current_time = data["day_cycle_time"]
	if "current_day" in data:
		TimeManager.current_day = data["current_day"]

func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("audio", "master_volume", 1.0)
	config.set_value("audio", "sfx_volume", 1.0)
	config.set_value("audio", "music_volume", 1.0)
	
	config.set_value("graphics", "fullscreen", false)
	config.set_value("graphics", "vsync", true)
	
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err != OK:
		save_settings()
		return

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		current_save_data.clear()
		print("Save file deleted")