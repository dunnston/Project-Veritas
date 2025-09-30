extends Resource

class_name SaveManagerConfig

@export_group("File Paths")
@export var save_file_path: String = "user://savegame.save"
@export var settings_file_path: String = "user://settings.cfg"
@export var backup_file_path: String = "user://savegame.backup"

@export_group("Auto Save")
@export var auto_save_enabled: bool = true
@export var auto_save_interval: float = 300.0  # 5 minutes
@export var max_backup_files: int = 3

@export_group("Default Settings")
@export var default_master_volume: float = 1.0
@export var default_sfx_volume: float = 1.0
@export var default_music_volume: float = 1.0
@export var default_fullscreen: bool = false
@export var default_vsync: bool = true

@export_group("Compression")
@export var compress_saves: bool = false
@export var compression_level: int = 6  # gzip compression level

@export_group("Validation")
@export var validate_on_save: bool = true
@export var validate_on_load: bool = true
@export var strict_validation: bool = false  # If true, invalid data prevents loading

func _init():
	resource_name = "SaveManagerConfig"