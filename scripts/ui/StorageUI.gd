extends Control
class_name StorageUI

@onready var storage_panel: PanelContainer = $StoragePanel
@onready var title_label: Label = $StoragePanel/VBoxContainer/TitleBar/TitleLabel
@onready var close_button: Button = $StoragePanel/VBoxContainer/TitleBar/CloseButton
@onready var storage_grid: GridContainer = $StoragePanel/VBoxContainer/StorageGrid
@onready var move_button: Button = $StoragePanel/VBoxContainer/ButtonContainer/MoveButton
@onready var destroy_button: Button = $StoragePanel/VBoxContainer/ButtonContainer/DestroyButton

var current_storage = null  # Can be StorageBox (2D) or StorageBox3D (3D)
var storage_slots: Array[Dictionary] = []  # Array of {panel, icon, quantity_label}

static var instance: StorageUI

# Constants
const SLOT_SIZE = 48
const STORAGE_SLOTS = 6

func _ready():
	instance = self
	visible = false
	add_to_group("ui")
	
	# Connect button signals
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	if move_button:
		move_button.pressed.connect(_on_move_button_pressed)
	if destroy_button:
		destroy_button.pressed.connect(_on_destroy_button_pressed)
	
	# Setup storage grid
	setup_storage_grid()

func setup_storage_grid():
	if not storage_grid:
		return
	
	storage_grid.columns = 3  # 3x2 grid for 6 slots
	
	# Create 6 storage slot buttons
	for i in range(STORAGE_SLOTS):
		var slot_ui = create_slot_button(i)
		storage_grid.add_child(slot_ui["panel"])
		storage_slots.append(slot_ui)

func create_slot_button(slot_index: int) -> Dictionary:
	# Create panel container for the slot
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# Create icon display
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(icon)

	# Create quantity label
	var quantity_label = Label.new()
	quantity_label.anchor_left = 1.0
	quantity_label.anchor_top = 1.0
	quantity_label.anchor_right = 1.0
	quantity_label.anchor_bottom = 1.0
	quantity_label.offset_left = -20
	quantity_label.offset_top = -15
	quantity_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	quantity_label.size_flags_vertical = Control.SIZE_SHRINK_END
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	quantity_label.add_theme_constant_override("shadow_offset_x", 1)
	quantity_label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(quantity_label)

	# Connect signals for click and drag
	panel.gui_input.connect(_on_slot_gui_input.bind(slot_index))

	return {
		"panel": panel,
		"icon": icon,
		"quantity_label": quantity_label
	}

func _on_storage_slot_clicked(_slot_index: int):
	# This is now handled in _on_slot_gui_input to manage single vs double clicks
	pass

func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if we're currently dragging - if so, try to drop here
			if DragPreviewManager and DragPreviewManager.is_dragging:
				DragPreviewManager.try_drop_on_storage(slot_index)
			else:
				# Not dragging - start drag from storage slot
				start_drag_from_storage(slot_index)


func start_drag_from_storage(slot_index: int):
	if not current_storage:
		return

	var slot_contents = current_storage.get_slot_contents(slot_index)
	if slot_contents["item_id"] == "" or slot_contents["quantity"] <= 0:
		return

	# Get icon texture for the preview
	var item_data = InventorySystem.get_item_data(slot_contents["item_id"])
	var icon_path = item_data.get("icon_path", "")

	var icon_texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)

	# Use DragPreviewManager to start the drag
	if DragPreviewManager:
		DragPreviewManager.start_drag("STORAGE", slot_index, slot_contents["item_id"], slot_contents["quantity"], icon_texture)

func get_inventory_ui() -> Control:
	# Find the InventoryUI in the scene
	var ui_nodes = get_tree().get_nodes_in_group("ui")
	for node in ui_nodes:
		if node.has_method("toggle_inventory"):
			return node
	
	# Also try to find it by name
	var scene_root = get_tree().current_scene
	var inventory = scene_root.find_child("InventoryUI", true, false)
	if inventory and inventory.has_method("toggle_inventory"):
		return inventory
	
	return null

func transfer_from_storage_to_inventory(slot_index: int, amount: int):
	print("Attempting transfer from storage slot %d, amount: %d" % [slot_index, amount])
	
	if not current_storage or not InventorySystem:
		print("ERROR: Missing current_storage or InventorySystem")
		return
	
	var slot_contents = current_storage.get_slot_contents(slot_index)
	print("Storage slot %d contents: %s" % [slot_index, slot_contents])
	
	if slot_contents["item_id"] == "" or slot_contents["quantity"] <= 0:
		print("Storage slot is empty, nothing to transfer")
		return
	
	var item_id = slot_contents["item_id"]
	var transfer_amount = amount
	if amount == -1 or amount > slot_contents["quantity"]:
		transfer_amount = slot_contents["quantity"]  # Transfer entire stack
	
	print("Trying to transfer %d %s from storage to inventory" % [transfer_amount, item_id])
	
	# Try to add to inventory
	if InventorySystem.add_item(item_id, transfer_amount):
		# Remove from storage
		current_storage.remove_item_from_storage(slot_index, transfer_amount)
		refresh_display()
		print("Successfully transferred %d %s to inventory" % [transfer_amount, item_id])
	else:
		print("Inventory full, cannot transfer item")

func open_storage_interface(storage):
	current_storage = storage
	
	# First, open the player's inventory if not already open
	var inventory_ui = get_inventory_ui()
	if inventory_ui:
		if not inventory_ui.visible:
			if inventory_ui.has_method("toggle_inventory"):
				inventory_ui.toggle_inventory()
			else:
				inventory_ui.visible = true
		print("Inventory UI opened: %s" % inventory_ui.visible)
	else:
		print("ERROR: Could not find InventoryUI")
	
	# Small delay to ensure inventory is positioned first
	await get_tree().process_frame
	
	# Now show storage and position it
	visible = true
	position_next_to_inventory()
	
	refresh_display()

func position_next_to_inventory():
	var inventory_ui = get_inventory_ui()
	print("Positioning storage. Inventory UI found: %s" % (inventory_ui != null))
	
	if inventory_ui and inventory_ui.visible:
		# Get inventory panel position and size
		var inventory_panel = inventory_ui.get_node("InventoryPanel")
		print("Inventory panel found: %s" % (inventory_panel != null))
		
		if inventory_panel:
			var inventory_rect = inventory_panel.get_global_rect()
			print("Inventory rect: %s" % inventory_rect)
			
			# Position storage panel to the right with some spacing
			var new_x = inventory_rect.position.x + inventory_rect.size.x + 20
			var new_y = inventory_rect.position.y
			
			storage_panel.position = Vector2(new_x, new_y)
			print("Storage panel positioned at: %s" % storage_panel.position)
		else:
			# Fallback positioning
			storage_panel.position = Vector2(600, 200)
			print("Using fallback positioning")
	else:
		# Fallback positioning if inventory not found
		storage_panel.position = Vector2(400, 200)
		print("Using fallback positioning - no inventory")

func close_storage_interface():
	visible = false
	current_storage = null

func refresh_display():
	if not current_storage:
		return
	
	print("Refreshing storage display...")
	
	# Update storage slots
	var storage_contents = current_storage.get_storage_contents()
	print("Storage contents: %s" % storage_contents)
	
	for i in range(storage_slots.size()):
		var slot_ui = storage_slots[i]
		var slot_data = storage_contents.get(str(i), {"item_id": "", "quantity": 0})
		update_slot_display(slot_ui, slot_data["item_id"], slot_data["quantity"])
		
	# Also try to refresh the inventory UI
	var inventory_ui = get_inventory_ui()
	if inventory_ui and inventory_ui.has_method("_on_inventory_changed"):
		inventory_ui._on_inventory_changed()
		print("Refreshed inventory UI as well")

func update_slot_display(slot_ui: Dictionary, item_id: String, quantity: int):
	print("Updating slot display - item_id: '%s', quantity: %d" % [item_id, quantity])

	var icon = slot_ui["icon"]
	var quantity_label = slot_ui["quantity_label"]
	var panel = slot_ui["panel"]

	if item_id == "" or quantity <= 0:
		icon.texture = null
		quantity_label.text = ""
		panel.tooltip_text = "Empty slot\nDrag inventory items here to store"
		print("Slot is empty")
	else:
		# Get item data
		var item_data = InventorySystem.get_item_data(item_id) if InventorySystem else {}
		var item_name = item_data.get("name", item_id)
		print("Item data for '%s': %s" % [item_id, item_data])

		# Set quantity label
		quantity_label.text = str(quantity) if quantity > 1 else ""
		print("Quantity label set to: '%s'" % quantity_label.text)

		# Try to load and set icon using icon_path directly
		var icon_path = item_data.get("icon_path", "")
		print("Icon path from data: '%s'" % icon_path)

		if not icon_path.is_empty():
			print("Trying to load icon from: %s" % icon_path)
			if ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
				print("Icon loaded successfully from: %s" % icon_path)
			else:
				print("ERROR: Icon file not found at: %s" % icon_path)
				icon.texture = null
		else:
			print("No icon_path specified for item: %s" % item_id)
			icon.texture = null

		# Set tooltip
		panel.tooltip_text = "%s x%d\nClick to pick up, then click inventory to transfer" % [item_name, quantity]
		print("Final slot state - quantity: '%s', icon: %s, tooltip: '%s'" % [quantity_label.text, icon.texture, panel.tooltip_text])

func _on_close_button_pressed():
	close_storage_interface()

func _on_move_button_pressed():
	print("Moving storage box...")
	if current_storage:
		current_storage.move_building()
		close_storage_interface()

func _on_destroy_button_pressed():
	print("Destroying storage box...")
	if current_storage:
		current_storage.destroy_building()
		close_storage_interface()

func _input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		close_storage_interface()

func transfer_from_inventory_to_storage(item_id: String, quantity: int):
	if not current_storage or not InventorySystem:
		return false
	
	# Check if player has the item
	var player_quantity = InventorySystem.get_item_count(item_id)
	if player_quantity < quantity:
		return false
	
	# Try to add to storage
	var remaining = current_storage.add_item_to_storage(item_id, quantity)
	var transferred = quantity - remaining
	
	if transferred > 0:
		# Remove from inventory
		InventorySystem.remove_item(item_id, transferred)
		refresh_display()
		print("Transferred %d %s to storage" % [transferred, item_id])
		return true
	else:
		print("Storage full, cannot transfer item")
		return false

func transfer_from_inventory_to_storage_slot(slot_index: int):
	print("Double-clicked storage slot %d - attempting to transfer from inventory" % slot_index)
	
	if not current_storage or not InventorySystem:
		print("ERROR: Missing current_storage or InventorySystem")
		return
	
	# Find the first item in player's inventory
	var first_item_id = ""
	var first_item_quantity = 0
	
	for slot in InventorySystem.inventory_slots:
		if not slot.is_empty():
			first_item_id = slot.item_id
			first_item_quantity = slot.quantity
			break
	
	if first_item_id == "":
		print("No items in inventory to transfer")
		return
	
	print("Found item in inventory: %s (quantity: %d)" % [first_item_id, first_item_quantity])
	
	# Transfer 1 item from inventory to storage
	print("About to call transfer_from_inventory_to_storage with: %s, quantity: 1" % first_item_id)
	if transfer_from_inventory_to_storage(first_item_id, 1):
		print("Successfully transferred 1 %s from inventory to storage" % first_item_id)
	else:
		print("Failed to transfer item from inventory to storage")
	
	# Force refresh to see what happened
	print("Forcing refresh after transfer attempt")
	refresh_display()

# Handle drops from inventory onto storage panel
func _can_drop_data(pos: Vector2, _data) -> bool:
	if not current_storage:
		return false
	
	# Check if the drop is over the storage panel
	var local_pos = storage_panel.to_local(pos)
	var panel_rect = Rect2(Vector2.ZERO, storage_panel.size)
	return panel_rect.has_point(local_pos)

func _drop_data(_pos: Vector2, data):
	# Handle inventory item dropped onto storage
	if data.has("item_id") and data.has("quantity"):
		transfer_from_inventory_to_storage(data["item_id"], data["quantity"])

