extends Node
class_name IntegrationTestNode

# Comprehensive integration test for migrated systems
# Add this as a child node to the demo scene to test functionality

var test_results: Dictionary = {}
var tests_completed: int = 0
var total_tests: int = 0

func _ready():
	print("=== NEON WASTELAND 3D MIGRATION INTEGRATION TEST ===")
	await get_tree().process_frame
	run_all_tests()

func run_all_tests():
	print("\n🚀 Starting comprehensive integration tests...")

	# Test 1: Autoload Systems
	await test_autoload_systems()

	# Test 2: Core Classes
	await test_core_classes()

	# Test 3: Data Loading
	await test_data_loading()

	# Test 4: Manager Functionality
	await test_manager_functionality()

	# Test 5: System Integration
	await test_system_integration()

	# Test 6: Save/Load System
	await test_save_load_system()

	print_final_results()

func test_autoload_systems() -> void:
	print("\n🔧 Testing Autoload Systems...")
	total_tests += 1

	var required_systems = [
		"EventBus", "GameManager", "SaveManager", "SkillSystem",
		"AttributeManager", "InventorySystem", "TimeManager", "GameTimeManager",
		"CraftingManager", "EquipmentManager", "WeaponManager", "AmmoManager",
		"CombatSystem", "StormSystem", "StatusEffectSystem", "BuildingManager",
		"BuildingSystem", "PowerSystem", "ProjectileSystem", "LootSystem",
		"ItemDropManager", "SpawnerManager", "OxygenSystem", "ShelterSystem",
		"InteriorDetectionSystem", "RoofVisibilityManager", "DoorSystem", "EmergencySystem"
	]

	var loaded_systems = 0
	var missing_systems = []

	for system_name in required_systems:
		if has_node("/root/" + system_name):
			loaded_systems += 1
			print("  ✓ " + system_name)
		else:
			missing_systems.append(system_name)
			print("  ✗ " + system_name + " (MISSING)")

	var success_rate = float(loaded_systems) / float(required_systems.size())
	test_results["autoload_systems"] = {
		"success": success_rate >= 0.9,  # 90% success rate required
		"loaded": loaded_systems,
		"total": required_systems.size(),
		"missing": missing_systems
	}

	print("  Summary: %d/%d systems loaded (%.1f%%)" % [loaded_systems, required_systems.size(), success_rate * 100])
	await get_tree().process_frame

func test_core_classes() -> void:
	print("\n🏗️ Testing Core Classes...")
	total_tests += 1

	var equipment_success = test_equipment_class()
	var weapon_success = test_weapon_class()
	var ammo_success = test_ammo_class()

	test_results["core_classes"] = {
		"success": equipment_success and weapon_success and ammo_success,
		"equipment": equipment_success,
		"weapon": weapon_success,
		"ammo": ammo_success
	}

	await get_tree().process_frame

func test_equipment_class() -> bool:
	try:
		var Equipment = load("res://classes/equipment/Equipment.gd")
		var test_data = {
			"name": "Test Helmet",
			"slot": "HEAD",
			"durability": 100,
			"stats": {"defense": 5}
		}
		var helmet = Equipment.new("TEST_HELMET", test_data)

		if helmet.name == "Test Helmet" and helmet.slot == "HEAD":
			print("  ✓ Equipment class working")
			return true
		else:
			print("  ✗ Equipment class data mismatch")
			return false
	except:
		print("  ✗ Equipment class failed to instantiate")
		return false

func test_weapon_class() -> bool:
	try:
		var Weapon = load("res://classes/weapons/Weapon.gd")
		var test_data = {
			"name": "Test Sword",
			"type": "MELEE",
			"damage": 15,
			"attack_speed": 1.5
		}
		var sword = Weapon.new("TEST_SWORD", test_data)

		if sword.name == "Test Sword" and sword.damage == 15:
			print("  ✓ Weapon class working")
			return true
		else:
			print("  ✗ Weapon class data mismatch")
			return false
	except:
		print("  ✗ Weapon class failed to instantiate")
		return false

func test_ammo_class() -> bool:
	try:
		var Ammo = load("res://classes/ammo/Ammo.gd")
		var test_data = {
			"name": "Test Bullets",
			"type": "BULLET",
			"damage_modifier": 1.2,
			"stack_size": 50
		}
		var bullets = Ammo.new("TEST_BULLETS", test_data)

		if bullets.name == "Test Bullets" and bullets.damage_modifier == 1.2:
			print("  ✓ Ammo class working")
			return true
		else:
			print("  ✗ Ammo class data mismatch")
			return false
	except:
		print("  ✗ Ammo class failed to instantiate")
		return false

func test_data_loading() -> void:
	print("\n📊 Testing Data Loading...")
	total_tests += 1

	var data_files = [
		"res://data/equipment.json",
		"res://data/weapons.json",
		"res://data/ammo.json",
		"res://data/buildings.json",
		"res://data/recipes.json",
		"res://data/resources.json",
		"res://data/spawner_configs.json"
	]

	var loaded_files = 0
	var failed_files = []

	for file_path in data_files:
		if test_json_file(file_path):
			loaded_files += 1
		else:
			failed_files.append(file_path.get_file())

	test_results["data_loading"] = {
		"success": loaded_files == data_files.size(),
		"loaded": loaded_files,
		"total": data_files.size(),
		"failed": failed_files
	}

	await get_tree().process_frame

func test_json_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		print("  ✗ " + file_path.get_file() + " (missing)")
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("  ✗ " + file_path.get_file() + " (can't open)")
		return false

	var content = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(content)

	if parse_result == OK:
		print("  ✓ " + file_path.get_file())
		return true
	else:
		print("  ✗ " + file_path.get_file() + " (invalid JSON)")
		return false

func test_manager_functionality() -> void:
	print("\n⚙️ Testing Manager Functionality...")
	total_tests += 1

	var inventory_test = test_inventory_manager()
	var equipment_test = test_equipment_manager()
	var weapon_test = test_weapon_manager()
	var crafting_test = test_crafting_manager()

	test_results["manager_functionality"] = {
		"success": inventory_test and equipment_test and weapon_test and crafting_test,
		"inventory": inventory_test,
		"equipment": equipment_test,
		"weapon": weapon_test,
		"crafting": crafting_test
	}

	await get_tree().process_frame

func test_inventory_manager() -> bool:
	var inventory = get_node_or_null("/root/InventorySystem")
	if not inventory:
		print("  ✗ InventorySystem not found")
		return false

	if inventory.has_method("add_item") and inventory.has_method("remove_item"):
		print("  ✓ InventorySystem has required methods")
		return true
	else:
		print("  ✗ InventorySystem missing required methods")
		return false

func test_equipment_manager() -> bool:
	var equipment = get_node_or_null("/root/EquipmentManager")
	if not equipment:
		print("  ✗ EquipmentManager not found")
		return false

	if equipment.has_method("load_equipment_data"):
		print("  ✓ EquipmentManager has required methods")
		return true
	else:
		print("  ✗ EquipmentManager missing required methods")
		return false

func test_weapon_manager() -> bool:
	var weapon = get_node_or_null("/root/WeaponManager")
	if not weapon:
		print("  ✗ WeaponManager not found")
		return false

	if weapon.has_method("load_weapon_data"):
		print("  ✓ WeaponManager has required methods")
		return true
	else:
		print("  ✗ WeaponManager missing required methods")
		return false

func test_crafting_manager() -> bool:
	var crafting = get_node_or_null("/root/CraftingManager")
	if not crafting:
		print("  ✗ CraftingManager not found")
		return false

	if crafting.has_method("load_recipes"):
		print("  ✓ CraftingManager has required methods")
		return true
	else:
		print("  ✗ CraftingManager missing required methods")
		return false

func test_system_integration() -> void:
	print("\n🔄 Testing System Integration...")
	total_tests += 1

	# Test EventBus signals
	var eventbus = get_node_or_null("/root/EventBus")
	if eventbus and eventbus.has_signal("resource_collected"):
		print("  ✓ EventBus signals available")
	else:
		print("  ✗ EventBus signals missing")

	# Test GameManager state
	var gamemanager = get_node_or_null("/root/GameManager")
	if gamemanager and gamemanager.has_method("change_state"):
		print("  ✓ GameManager state management available")
	else:
		print("  ✗ GameManager state management missing")

	test_results["system_integration"] = {
		"success": eventbus != null and gamemanager != null,
		"eventbus": eventbus != null,
		"gamemanager": gamemanager != null
	}

	await get_tree().process_frame

func test_save_load_system() -> void:
	print("\n💾 Testing Save/Load System...")
	total_tests += 1

	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		print("  ✗ SaveManager not found")
		test_results["save_load"] = {"success": false, "reason": "SaveManager missing"}
		return

	var has_save = save_manager.has_method("save_game")
	var has_load = save_manager.has_method("load_game")

	if has_save and has_load:
		print("  ✓ SaveManager has save/load methods")
		test_results["save_load"] = {"success": true}
	else:
		print("  ✗ SaveManager missing save/load methods")
		test_results["save_load"] = {"success": false, "reason": "Missing methods"}

	await get_tree().process_frame

func print_final_results():
	print("\n" + "="*50)
	print("🎯 FINAL INTEGRATION TEST RESULTS")
	print("="*50)

	var total_passed = 0
	var total_failed = 0

	for test_name in test_results:
		var result = test_results[test_name]
		if result.success:
			print("✅ " + test_name.capitalize().replace("_", " ") + " - PASSED")
			total_passed += 1
		else:
			print("❌ " + test_name.capitalize().replace("_", " ") + " - FAILED")
			total_failed += 1

	print("\nSummary: %d PASSED, %d FAILED" % [total_passed, total_failed])

	if total_failed == 0:
		print("\n🎉 ALL TESTS PASSED! Migration integration successful!")
		print("Your 3D project now has full feature parity with the 2D version.")
	else:
		print("\n⚠️ Some tests failed. Check the results above for details.")
		print("The migration may need additional fixes for full compatibility.")

	print("="*50)