extends Node

## Test Script for Modular Inventory System
##
## This script demonstrates how to use the InventorySystem module.
## Attach this to a node in your scene to test the inventory functionality.

func _ready():
	print("=== INVENTORY SYSTEM TEST ===")

	# Wait for InventorySystem to be ready
	await get_tree().process_frame

	# Set up configuration
	setup_inventory_config()

	# Connect to signals
	connect_inventory_signals()

	# Run tests
	await get_tree().create_timer(0.1).timeout
	run_basic_tests()

func setup_inventory_config():
	print("Setting up inventory configuration...")

	# Create and configure the inventory system
	var config = InventoryConfig.new()
	config.base_slots = 15
	config.debug_logging = true
	config.data_file_path = "res://modules/inventory_system/example_items.json"
	config.icon_base_path = "res://assets/sprites/items/"

	InventorySystem.config = config

	print("Configuration complete!")

func connect_inventory_signals():
	print("Connecting to inventory signals...")

	InventorySystem.inventory_changed.connect(_on_inventory_changed)
	InventorySystem.item_added.connect(_on_item_added)
	InventorySystem.item_removed.connect(_on_item_removed)
	InventorySystem.item_dropped.connect(_on_item_dropped)

func run_basic_tests():
	print("\n=== RUNNING BASIC TESTS ===")

	# Test 1: Add items
	print("\n--- Test 1: Adding Items ---")
	InventorySystem.add_item("SCRAP_METAL", 25)
	InventorySystem.add_item("HEALTH_STIM", 3)
	InventorySystem.add_item("ELECTRONIC_COMPONENTS", 7)

	# Test 2: Check item counts
	print("\n--- Test 2: Checking Item Counts ---")
	print("Scrap Metal count: ", InventorySystem.get_item_count("SCRAP_METAL"))
	print("Health Stim count: ", InventorySystem.get_item_count("HEALTH_STIM"))
	print("Electronics count: ", InventorySystem.get_item_count("ELECTRONIC_COMPONENTS"))

	# Test 3: Check if has items
	print("\n--- Test 3: Has Item Checks ---")
	print("Has 10 Scrap Metal: ", InventorySystem.has_item("SCRAP_METAL", 10))
	print("Has 5 Health Stims: ", InventorySystem.has_item("HEALTH_STIM", 5))
	print("Has 1 Water Filter: ", InventorySystem.has_item("WATER_FILTER", 1))

	# Test 4: Remove items
	print("\n--- Test 4: Removing Items ---")
	var removed = InventorySystem.remove_item("SCRAP_METAL", 10)
	print("Successfully removed 10 Scrap Metal: ", removed)
	print("Remaining Scrap Metal: ", InventorySystem.get_item_count("SCRAP_METAL"))

	# Test 5: Drop items
	print("\n--- Test 5: Dropping Items ---")
	var dropped = InventorySystem.drop_item("HEALTH_STIM", 1, Vector3(100, 0, 50))
	print("Successfully dropped Health Stim: ", dropped)
	print("Remaining Health Stims: ", InventorySystem.get_item_count("HEALTH_STIM"))

	# Test 6: Fill inventory to test stacking
	print("\n--- Test 6: Testing Stack Limits ---")
	for i in range(3):
		InventorySystem.add_item("SCRAP_METAL", 50)  # Should stack up to limit

	# Test 7: Test item data retrieval
	print("\n--- Test 7: Item Data Retrieval ---")
	var scrap_data = InventorySystem.get_item_data("SCRAP_METAL")
	print("Scrap Metal data: ", scrap_data)

	# Test 8: Inventory statistics
	print("\n--- Test 8: Inventory Statistics ---")
	var stats = InventorySystem.get_inventory_stats()
	print("Inventory stats: ", stats)

	# Test 9: Save/Load test
	print("\n--- Test 9: Save/Load Test ---")
	var save_data = InventorySystem.get_save_data()
	print("Save data created, slots: ", save_data.slots.size())

	# Clear and reload
	InventorySystem.clear_inventory()
	print("Inventory cleared")

	InventorySystem.load_save_data(save_data)
	print("Inventory reloaded")
	print("Scrap Metal after reload: ", InventorySystem.get_item_count("SCRAP_METAL"))

	# Test 10: Print final inventory
	print("\n--- Test 10: Final Inventory State ---")
	InventorySystem.print_inventory()

	print("\n=== TESTS COMPLETE ===")

# Signal handlers
func _on_inventory_changed():
	print("📦 Inventory changed!")

func _on_item_added(item_id: String, quantity: int):
	var item_data = InventorySystem.get_item_data(item_id)
	print("➕ Added %d %s" % [quantity, item_data.name])

func _on_item_removed(item_id: String, quantity: int):
	var item_data = InventorySystem.get_item_data(item_id)
	print("➖ Removed %d %s" % [quantity, item_data.name])

func _on_item_dropped(item_id: String, quantity: int, drop_position: Vector3):
	var item_data = InventorySystem.get_item_data(item_id)
	print("📤 Dropped %d %s at position %s" % [quantity, item_data.name, drop_position])

# Input handling for manual testing
func _input(event):
	if event.is_action_pressed("ui_accept"):
		print("\n--- Manual Test: Adding Random Items ---")
		var items = ["SCRAP_METAL", "HEALTH_STIM", "ELECTRONIC_COMPONENTS", "ENERGY_CELL"]
		var random_item = items[randi() % items.size()]
		var random_amount = randi_range(1, 10)
		InventorySystem.add_item(random_item, random_amount)

	elif event.is_action_pressed("ui_cancel"):
		print("\n--- Manual Test: Printing Inventory ---")
		InventorySystem.print_inventory()
		var stats = InventorySystem.get_inventory_stats()
		print("Stats: ", stats)