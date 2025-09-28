extends Node

# Test script to verify migration integration
# This script will test all the migrated systems

func _ready():
	print("=== NEON WASTELAND MIGRATION VERIFICATION ===")
	await get_tree().process_frame
	verify_autoloads()
	verify_classes()
	verify_data_loading()
	test_basic_functionality()
	print("=== VERIFICATION COMPLETE ===")

func verify_autoloads():
	print("\n--- Testing Autoloads ---")

	var systems = [
		"EventBus", "GameManager", "SaveManager", "SkillSystem",
		"AttributeManager", "InventorySystem", "TimeManager", "GameTimeManager",
		"CraftingManager", "EquipmentManager", "WeaponManager", "AmmoManager",
		"CombatSystem", "StormSystem", "StatusEffectSystem", "BuildingManager",
		"BuildingSystem", "PowerSystem", "ProjectileSystem", "LootSystem",
		"ItemDropManager", "SpawnerManager", "OxygenSystem", "ShelterSystem",
		"InteriorDetectionSystem", "RoofVisibilityManager", "DoorSystem", "EmergencySystem"
	]

	var loaded_count = 0
	for system_name in systems:
		if has_node("/root/" + system_name):
			print("✓ " + system_name + " loaded")
			loaded_count += 1
		else:
			print("✗ " + system_name + " not found")

	print("Loaded " + str(loaded_count) + "/" + str(systems.size()) + " systems")

func verify_classes():
	print("\n--- Testing Core Classes ---")

	# Test Equipment class
	if load("res://classes/equipment/Equipment.gd"):
		print("✓ Equipment class found")
		try_test_equipment()
	else:
		print("✗ Equipment class not found")

	# Test Weapon class
	if load("res://classes/weapons/Weapon.gd"):
		print("✓ Weapon class found")
		try_test_weapon()
	else:
		print("✗ Weapon class not found")

	# Test Ammo class
	if load("res://classes/ammo/Ammo.gd"):
		print("✓ Ammo class found")
		try_test_ammo()
	else:
		print("✗ Ammo class not found")

func try_test_equipment():
	try:
		var Equipment = load("res://classes/equipment/Equipment.gd")
		var equipment_data = {
			"name": "Test Helmet",
			"slot": "HEAD",
			"durability": 100,
			"stats": {"defense": 5}
		}
		var helmet = Equipment.new("TEST_HELMET", equipment_data)
		print("✓ Equipment instantiated: " + helmet.name)
	except:
		print("✗ Equipment instantiation failed")

func try_test_weapon():
	try:
		var Weapon = load("res://classes/weapons/Weapon.gd")
		var weapon_data = {
			"name": "Test Sword",
			"type": "MELEE",
			"damage": 15,
			"attack_speed": 1.5
		}
		var sword = Weapon.new("TEST_SWORD", weapon_data)
		print("✓ Weapon instantiated: " + sword.name)
	except:
		print("✗ Weapon instantiation failed")

func try_test_ammo():
	try:
		var Ammo = load("res://classes/ammo/Ammo.gd")
		var ammo_data = {
			"name": "Test Bullets",
			"type": "BULLET",
			"damage_modifier": 1.2,
			"stack_size": 50
		}
		var bullets = Ammo.new("TEST_BULLETS", ammo_data)
		print("✓ Ammo instantiated: " + bullets.name)
	except:
		print("✗ Ammo instantiation failed")

func verify_data_loading():
	print("\n--- Testing Data Files ---")

	var data_files = [
		"res://data/equipment.json",
		"res://data/weapons.json",
		"res://data/ammo.json",
		"res://data/buildings.json",
		"res://data/recipes.json",
		"res://data/resources.json",
		"res://data/spawner_configs.json"
	]

	for file_path in data_files:
		if FileAccess.file_exists(file_path):
			print("✓ " + file_path.get_file() + " found")
			test_json_validity(file_path)
		else:
			print("✗ " + file_path.get_file() + " not found")

func test_json_validity(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(content)
		if parse_result == OK:
			print("  ✓ Valid JSON")
		else:
			print("  ✗ Invalid JSON: " + json.get_error_message())
	else:
		print("  ✗ Could not open file")

func test_basic_functionality():
	print("\n--- Testing Basic Functionality ---")

	# Test InventorySystem if available
	if has_node("/root/InventorySystem"):
		print("✓ Testing InventorySystem...")
		var inventory = get_node("/root/InventorySystem")
		if inventory.has_method("add_item"):
			print("  ✓ add_item method available")
		if inventory.has_method("remove_item"):
			print("  ✓ remove_item method available")

	# Test SaveManager if available
	if has_node("/root/SaveManager"):
		print("✓ Testing SaveManager...")
		var save_manager = get_node("/root/SaveManager")
		if save_manager.has_method("save_game"):
			print("  ✓ save_game method available")
		if save_manager.has_method("load_game"):
			print("  ✓ load_game method available")

	# Test EquipmentManager if available
	if has_node("/root/EquipmentManager"):
		print("✓ Testing EquipmentManager...")
		var equipment_manager = get_node("/root/EquipmentManager")
		if equipment_manager.has_method("load_equipment_data"):
			print("  ✓ load_equipment_data method available")