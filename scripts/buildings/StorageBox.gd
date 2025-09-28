extends Area2D
class_name StorageBox

# Storage properties
var storage_inventory: Dictionary = {}
var max_slots: int = 6
var player_in_range: bool = false
var player_ref: Node2D = null
var interaction_prompt: Label = null

signal storage_opened(storage_box: StorageBox)
signal storage_closed()

func _ready():
	print("StorageBox _ready() called")
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("Connected area signals")
	
	# Initialize storage slots
	initialize_storage()
	
	# Check for pending storage data from moves
	restore_pending_storage_data()
	
	# Create interaction prompt
	create_interaction_prompt()
	
	# Add to buildings group
	add_to_group("buildings")
	add_to_group("storage")
	
	print("Storage box created with %d slots at position %s" % [max_slots, global_position])
	
	# Debug: Check collision setup
	print("StorageBox collision_layer: %d, collision_mask: %d" % [collision_layer, collision_mask])
	
	# Test area detection in a few seconds
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(_debug_check_area)
	add_child(timer)
	timer.start()

func _debug_check_area():
	print("StorageBox debug: Checking nearby bodies...")
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = RectangleShape2D.new()
	query.shape.size = Vector2(60, 60)  # Slightly larger than interaction area
	query.transform.origin = global_position
	query.collision_mask = 1  # Player layer
	
	var results = space_state.intersect_shape(query)
	print("Found %d bodies in area" % results.size())
	for result in results:
		var body = result.collider
		print("  - Body: %s, groups: %s" % [body.name, body.get_groups()])

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

func create_interaction_prompt():
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press E to open storage"
	interaction_prompt.position = Vector2(-50, -60)
	interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 1)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 1)
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func _input(event: InputEvent):
	if player_in_range and event.is_action_pressed("interact"):
		print("StorageBox: Interact key pressed, opening storage...")
		open_storage()

func _on_body_entered(body: Node2D):
	print("StorageBox: Body entered - %s" % body.name)
	if body.is_in_group("player"):
		print("StorageBox: Player entered range")
		player_in_range = true
		player_ref = body
		show_interaction_prompt()

func _on_body_exited(body: Node2D):
	print("StorageBox: Body exited - %s" % body.name)  
	if body.is_in_group("player"):
		print("StorageBox: Player left range")
		player_in_range = false
		player_ref = null
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

func open_storage():
	print("Opening storage box...")
	
	# Use the static instance like other UIs
	if StorageUI.instance:
		print("Opening storage interface...")
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
	
	# First try to stack with existing items
	for slot_key in storage_inventory.keys():
		var slot = storage_inventory[slot_key]
		if slot["item_id"] == item_id and slot["quantity"] > 0:
			var item_data = InventorySystem.get_item_data(item_id) if InventorySystem else {}
			var max_stack = item_data.get("stack_size", 50)
			var can_add = min(remaining, max_stack - slot["quantity"])
			if can_add > 0:
				slot["quantity"] += can_add
				remaining -= can_add
				if remaining <= 0:
					return 0
	
	# Then try to find empty slots
	for slot_key in storage_inventory.keys():
		var slot = storage_inventory[slot_key]
		if slot["item_id"] == "" or slot["quantity"] == 0:
			var item_data = InventorySystem.get_item_data(item_id) if InventorySystem else {}
			var max_stack = item_data.get("stack_size", 50)
			var can_add = min(remaining, max_stack)
			slot["item_id"] = item_id
			slot["quantity"] = can_add
			remaining -= can_add
			if remaining <= 0:
				return 0
	
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
		# Remove current storage box
		queue_free()
		# Start building mode for replacement
		BuildingSystem.start_building_mode("storage_box")

func destroy_building():
	print("Destroying storage box...")
	
	# Drop all stored items on the ground
	for slot_key in storage_inventory.keys():
		var slot = storage_inventory[slot_key]
		if slot["item_id"] != "" and slot["quantity"] > 0:
			# TODO: Create item drops at this location
			print("Would drop %d %s" % [slot["quantity"], slot["item_id"]])
	
	# Return some materials to inventory
	if InventorySystem:
		InventorySystem.add_item("SCRAP_METAL", 1)
		InventorySystem.add_item("WOOD_SCRAPS", 2)
	
	# Remove the storage box
	queue_free()
