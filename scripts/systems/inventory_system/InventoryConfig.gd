extends Resource

class_name InventoryConfig

## Inventory System Configuration Resource
##
## Configure the InventorySystem for different projects and use cases.
## Create this resource and assign it to your InventorySystem node.

## Core Settings
@export var base_slots: int = 20
@export var debug_logging: bool = false

## Data File Configuration
@export var data_file_path: String = ""
@export var icon_base_path: String = "res://assets/sprites/items/"

## Optional Bonus Slots Provider
## Assign a node that has a get_bonus_inventory_slots() method
##@export var bonus_slots_provider: Node

## Auto-save Configuration
@export var auto_save_enabled: bool = true
@export var auto_save_interval: float = 30.0  # seconds

## Item Categories (for filtering and organization)
@export var item_categories: Array[String] = []

## Stack Size Overrides
## Override stack sizes for specific items
@export var stack_size_overrides: Dictionary = {}

## Default setup for quick configuration
func setup_defaults():
	base_slots = 20
	debug_logging = true  # Enable for testing backpack functionality
	data_file_path = "res://data/resources.json"
	icon_base_path = "res://assets/sprites/items/"
	auto_save_enabled = true
	auto_save_interval = 30.0
	item_categories = ["Materials", "Tools", "Food", "Equipment", "Misc"]

## Get effective stack size for an item (considering overrides)
func get_stack_size(item_id: String, default_stack: int) -> int:
	if item_id in stack_size_overrides:
		return stack_size_overrides[item_id]
	return default_stack

## Add stack size override
func set_stack_override(item_id: String, stack_size: int):
	stack_size_overrides[item_id] = stack_size

## Remove stack size override
func remove_stack_override(item_id: String):
	if item_id in stack_size_overrides:
		stack_size_overrides.erase(item_id)

## Validate configuration
func is_valid() -> bool:
	if base_slots <= 0:
		push_error("InventoryConfig: base_slots must be greater than 0")
		return false

	if not data_file_path.is_empty() and not FileAccess.file_exists(data_file_path):
		push_warning("InventoryConfig: data_file_path does not exist: " + data_file_path)

	if auto_save_interval <= 0:
		push_error("InventoryConfig: auto_save_interval must be greater than 0")
		return false

	return true

## Create a configuration for common use cases
static func create_survival_config() -> InventoryConfig:
	var config = InventoryConfig.new()
	config.base_slots = 30
	config.debug_logging = false
	config.data_file_path = "res://data/items.json"
	config.icon_base_path = "res://assets/items/"
	config.item_categories = ["Tools", "Materials", "Food", "Medicine", "Equipment"]
	return config

static func create_rpg_config() -> InventoryConfig:
	var config = InventoryConfig.new()
	config.base_slots = 40
	config.debug_logging = false
	config.data_file_path = "res://data/items.json"
	config.icon_base_path = "res://assets/items/"
	config.item_categories = ["Weapons", "Armor", "Consumables", "Materials", "Quest Items", "Misc"]
	return config

static func create_automation_config() -> InventoryConfig:
	var config = InventoryConfig.new()
	config.base_slots = 50
	config.debug_logging = true  # More debugging for complex systems
	config.data_file_path = "res://data/resources.json"
	config.icon_base_path = "res://assets/sprites/items/"
	config.item_categories = ["Raw Materials", "Intermediate Products", "Finished Goods", "Tools", "Buildings"]
	return config
