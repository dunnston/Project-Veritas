extends StaticBody3D
class_name StorageBox3D

# Storage properties
var storage_inventory: Dictionary = {}
var max_slots: int = 6
var player_in_range: bool = false
var interaction_area: Area3D = null
var interaction_prompt: Label3D = null

signal storage_opened(storage_box: StorageBox3D)
signal storage_closed()

func _ready():
	print("StorageBox3D _ready() called")

	# Add to groups
	add_to_group("building")
	add_to_group("storage")
	add_to_group("interactable")

	# Initialize storage slots
	initialize_storage()

	# Check for pending storage data from moves
	restore_pending_storage_data()

	# Create interaction area
	call_deferred("setup_interaction_area")

	# Create interaction prompt
	call_deferred("create_interaction_prompt")

	print("StorageBox3D created with %d slots at position %s" % [max_slots, global_position])

func setup_interaction_area():
	# Create Area3D for detecting player
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)

	# Create collision shape for interaction range
	var interaction_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 3.0  # 3 meter interaction range
	interaction_shape.shape = sphere_shape
	interaction_area.add_child(interaction_shape)

	# Configure area to detect player
	interaction_area.collision_layer = 1 << 7  # Interactables layer (layer 8)
	interaction_area.collision_mask = 1 << 1   # Player layer (layer 2)
	interaction_area.monitoring = true
	interaction_area.monitorable = true

	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	print("StorageBox3D: Interaction area set up with 3m range")

func create_interaction_prompt():
	# Create 3D label for interaction prompt
	interaction_prompt = Label3D.new()
	interaction_prompt.text = "Press E to open storage"
	interaction_prompt.pixel_size = 0.01
	interaction_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_prompt.position = Vector3(0, 1.5, 0)  # Float above storage box
	interaction_prompt.modulate = Color.WHITE
	interaction_prompt.outline_modulate = Color.BLACK
	interaction_prompt.outline_size = 2
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func initialize_storage():
	# Initialize empty storage slots
	for i in range(max_slots):
		storage_inventory[str(i)] = {
			"item_id": "",
			"quantity": 0
		}

func restore_pending_storage_data():
	print("Checking for pending storage data...")
	if BuildingSystem and not BuildingSystem.pending_storage_data.is_empty():
		print("Found pending storage data: %s" % BuildingSystem.pending_storage_data)
		storage_inventory = BuildingSystem.pending_storage_data.duplicate(true)
		# Clear the pending data so it doesn't affect future storage boxes
		BuildingSystem.pending_storage_data = {}
		print("Restored storage inventory: %s" % storage_inventory)
	else:
		print("No pending storage data found")

func _on_body_entered(body: Node3D):
	print("StorageBox3D: Body entered - %s" % body.name)
	if body.is_in_group("player"):
		print("StorageBox3D: Player entered range")
		player_in_range = true
		show_interaction_prompt()

func _on_body_exited(body: Node3D):
	print("StorageBox3D: Body exited - %s" % body.name)
	if body.is_in_group("player"):
		print("StorageBox3D: Player left range")
		player_in_range = false
		hide_interaction_prompt()
		# Close storage UI if open
		if StorageUI.instance and StorageUI.instance.visible:
			close_storage()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

# This is called by the player when they press E near this object
func interact():
	print("StorageBox3D: interact() called")
	open_storage()

func open_storage():
	print("Opening storage box...")

	# Use the static instance like other UIs
	if StorageUI.instance:
		print("Opening storage interface...")
		# StorageUI expects a StorageBox (2D), so we need to adapt
		# For now, we'll use this 3D storage box directly
		StorageUI.instance.open_storage_interface(self)
		storage_opened.emit(self)
	else:
		print("ERROR: StorageUI.instance not found")

func close_storage():
	if StorageUI.instance:
		StorageUI.instance.close_storage_interface()
	storage_closed.emit()

func add_item_to_storage(item_id: String, quantity: int) -> int:
	# Returns the amount that couldn't be stored
	var remaining = quantity

	# First try to find an empty slot for the entire stack
	for slot_key in storage_inventory.keys():
		var slot = storage_inventory[slot_key]
		if slot["item_id"] == "" or slot["quantity"] == 0:
			# Store the entire quantity in this slot (no splitting)
			slot["item_id"] = item_id
			slot["quantity"] = remaining
			return 0  # All items stored successfully

	# If no empty slots, try to stack with existing same items
	for slot_key in storage_inventory.keys():
		var slot = storage_inventory[slot_key]
		if slot["item_id"] == item_id and slot["quantity"] > 0:
			# Add to existing stack without enforcing max_stack limit
			slot["quantity"] += remaining
			return 0  # All items stacked successfully

	# If we get here, storage is full
	return remaining

func remove_item_from_storage(slot_index: int, quantity: int) -> Dictionary:
	# Returns the item removed
	var slot_key = str(slot_index)
	if not storage_inventory.has(slot_key):
		return {"item_id": "", "quantity": 0}

	var slot = storage_inventory[slot_key]
	var removed_quantity = min(quantity, slot["quantity"])
	var result = {
		"item_id": slot["item_id"],
		"quantity": removed_quantity
	}

	slot["quantity"] -= removed_quantity
	if slot["quantity"] <= 0:
		slot["item_id"] = ""
		slot["quantity"] = 0

	return result

func get_storage_contents() -> Dictionary:
	return storage_inventory.duplicate(true)

func get_slot_contents(slot_index: int) -> Dictionary:
	var slot_key = str(slot_index)
	if storage_inventory.has(slot_key):
		return storage_inventory[slot_key].duplicate()
	return {"item_id": "", "quantity": 0}

func set_slot_contents(slot_index: int, item_id: String, quantity: int):
	var slot_key = str(slot_index)
	if storage_inventory.has(slot_key):
		storage_inventory[slot_key]["item_id"] = item_id
		storage_inventory[slot_key]["quantity"] = quantity

func move_building():
	print("Moving storage box...")
	# Store the current inventory data before destroying
	var inventory_backup = storage_inventory.duplicate(true)
	print("Backing up storage inventory: %s" % inventory_backup)

	# Store in a temporary global location that the new storage box can access
	if BuildingSystem:
		BuildingSystem.pending_storage_data = inventory_backup
		# Start building MOVE mode (no resource cost, transfers the building)
		BuildingSystem.start_building_mode_for_move("storage_box", self)
		# Note: The building will be destroyed when the new one is placed

func destroy_building():
	print("Destroying storage box...")

	# Drop all stored items on the ground
	if ItemDropManager:
		for slot_key in storage_inventory.keys():
			var slot = storage_inventory[slot_key]
			if slot["item_id"] != "" and slot["quantity"] > 0:
				print("Dropping %d %s at position %s" % [slot["quantity"], slot["item_id"], global_position])
				# Spawn item pickup at storage box position with slight upward offset
				var drop_position = global_position + Vector3(0, 1.0, 0)
				ItemDropManager.spawn_item_pickup_3d(
					ItemDropManager.GENERIC_PICKUP_3D_SCENE,
					drop_position,
					slot["item_id"],
					slot["quantity"]
				)
	else:
		print("ERROR: ItemDropManager not found!")

	# Return some materials to inventory (50% refund like other buildings)
	if InventorySystem:
		InventorySystem.add_item("SCRAP_METAL", 1)
		InventorySystem.add_item("WOOD_SCRAPS", 2)

	# Remove the storage box
	queue_free()
