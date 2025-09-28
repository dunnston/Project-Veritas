extends Node3D

@onready var inventory_ui = $UI/InventoryUI

func _ready():
	print("=== INVENTORY SYSTEM INTEGRATION TEST ===")
	print("ModularInventory available:", ModularInventory != null)
	print("InventoryUI found:", inventory_ui != null)

	# Connect to inventory signals
	if ModularInventory:
		ModularInventory.inventory_changed.connect(_on_inventory_changed)
		ModularInventory.item_added.connect(_on_item_added)
		ModularInventory.item_dropped.connect(_on_item_dropped)

		# Test basic functionality
		print("Testing basic inventory operations...")
		test_basic_operations()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			# Toggle inventory
			if inventory_ui:
				inventory_ui.toggle_inventory()
		elif event.keycode == KEY_T:
			# Test: Add a random item
			test_add_random_item()
		elif event.keycode == KEY_R:
			# Test: Remove all items
			test_clear_inventory()

func test_basic_operations():
	print("\n--- Testing Basic Operations ---")

	# Test adding items
	var test_items = ["SCRAP_METAL", "WATER", "FOOD", "ENERGY_CELLS"]

	for item_id in test_items:
		var added = ModularInventory.add_item(item_id, 5)
		if added:
			print("✓ Added 5x %s" % item_id)
		else:
			print("✗ Failed to add %s" % item_id)

	# Test item counts
	print("\n--- Current Inventory Counts ---")
	for item_id in test_items:
		var count = ModularInventory.get_item_count(item_id)
		print("%s: %d" % [item_id, count])

	print("\n--- Inventory Stats ---")
	var stats = ModularInventory.get_inventory_stats()
	print("Total items: %d" % stats.total_items)
	print("Slot usage: %s" % stats.slot_usage)
	print("Empty slots: %d" % ModularInventory.get_empty_slot_count())

func test_add_random_item():
	var random_items = ["BIO_MATTER", "ELECTRONICS", "GEARS", "BANDAGE", "STIMPACK"]
	var item_id = random_items[randi() % random_items.size()]
	var quantity = randi_range(1, 10)

	if ModularInventory.add_item(item_id, quantity):
		print("Added %dx %s to inventory" % [quantity, item_id])
	else:
		print("Failed to add %s - inventory might be full" % item_id)

func test_clear_inventory():
	print("Clearing inventory...")
	ModularInventory.clear_inventory()

func test_vector3_drop():
	# Test dropping with Vector3 position
	var drop_pos = Vector3(0, 1, 0)
	if ModularInventory.drop_item("SCRAP_METAL", 1, drop_pos):
		print("Successfully dropped item at Vector3 position: %v" % drop_pos)
	else:
		print("Failed to drop item")

func _on_inventory_changed():
	print("Inventory changed signal received")

func _on_item_added(item_id: String, quantity: int):
	print("Item added signal: %dx %s" % [quantity, item_id])

func _on_item_dropped(item_id: String, quantity: int, drop_position: Vector3):
	print("Item dropped signal: %dx %s at position %v" % [quantity, item_id, drop_position])

	# In a real game, you'd spawn a 3D pickup item here
	print("  -> Would spawn pickup item in 3D world at this position")