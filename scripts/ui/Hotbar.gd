extends Control
class_name Hotbar

signal item_used(slot_index: int, item_id: String)
signal slot_updated(slot_index: int)

const HOTBAR_SLOTS = 9

var hotbar_data: Array = []
var slot_buttons: Array = []

@onready var slot_container = $GridContainer

func _ready():
	initialize_hotbar_data()
	setup_slot_references()
	connect_signals()
	update_all_slots()
	
	print("Hotbar initialized with %d slots" % HOTBAR_SLOTS)

func initialize_hotbar_data():
	hotbar_data.clear()
	for i in HOTBAR_SLOTS:
		hotbar_data.append({
			"item_id": "",
			"quantity": 0
		})

func setup_slot_references():
	slot_buttons.clear()

	var slot_names = ["Slot", "Slot2", "Slot3", "Slot4", "Slot5", "Slot6", "Slot7", "Slot8", "Slot9"]

	for i in range(HOTBAR_SLOTS):
		var slot_node = slot_container.get_node_or_null(slot_names[i])
		if slot_node:
			slot_buttons.append(slot_node)
			# Connect gui_input only (PanelContainer doesn't have pressed signal)
			slot_node.gui_input.connect(_on_slot_gui_input.bind(i))
		else:
			print("Warning: Could not find slot node: %s" % slot_names[i])

func connect_signals():
	if InventorySystem:
		InventorySystem.inventory_changed.connect(_on_inventory_changed)

func _input(event: InputEvent):
	for i in range(min(9, HOTBAR_SLOTS)):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			use_hotbar_slot(i)
			get_viewport().set_input_as_handled()

func set_slot(slot_index: int, item_id: String, quantity: int = 1):
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return
	
	hotbar_data[slot_index]["item_id"] = item_id
	hotbar_data[slot_index]["quantity"] = quantity
	update_slot_display(slot_index)
	slot_updated.emit(slot_index)

func clear_slot(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return
	
	hotbar_data[slot_index]["item_id"] = ""
	hotbar_data[slot_index]["quantity"] = 0
	update_slot_display(slot_index)
	slot_updated.emit(slot_index)

func update_slot_display(slot_index: int):
	if slot_index >= slot_buttons.size():
		return
	
	var slot_button = slot_buttons[slot_index]
	var slot_data = hotbar_data[slot_index]
	var item_icon = slot_button.get_node_or_null("ItemIcon")
	var stack_label = slot_button.get_node("Stack Number")
	
	if not item_icon:
		print("Warning: ItemIcon not found for slot %d" % slot_index)
		return
	
	if slot_data["item_id"].is_empty():
		item_icon.texture = null
		stack_label.visible = false
	else:
		var item_data = InventorySystem.get_item_data(slot_data["item_id"])
		var icon_path = item_data.get("icon_path", "")
		
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			item_icon.texture = load(icon_path)
		else:
			item_icon.texture = null
		
		if slot_data["quantity"] > 1:
			stack_label.text = str(slot_data["quantity"])
			stack_label.visible = true
		else:
			stack_label.visible = false

func update_all_slots():
	for i in range(HOTBAR_SLOTS):
		update_slot_display(i)

func add_item_to_hotbar(item_id: String, quantity: int = 1, preferred_slot: int = -1):
	if preferred_slot >= 0 and preferred_slot < HOTBAR_SLOTS:
		if hotbar_data[preferred_slot]["item_id"].is_empty():
			set_slot(preferred_slot, item_id, quantity)
			return preferred_slot
		elif hotbar_data[preferred_slot]["item_id"] == item_id:
			hotbar_data[preferred_slot]["quantity"] += quantity
			update_slot_display(preferred_slot)
			return preferred_slot
	
	for i in range(HOTBAR_SLOTS):
		if hotbar_data[i]["item_id"] == item_id:
			hotbar_data[i]["quantity"] += quantity
			update_slot_display(i)
			return i
	
	for i in range(HOTBAR_SLOTS):
		if hotbar_data[i]["item_id"].is_empty():
			set_slot(i, item_id, quantity)
			return i
	
	return -1

func remove_item_from_hotbar(slot_index: int, quantity: int = 1):
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return false
	
	var slot_data = hotbar_data[slot_index]
	if slot_data["item_id"].is_empty():
		return false
	
	slot_data["quantity"] -= quantity
	if slot_data["quantity"] <= 0:
		clear_slot(slot_index)
	else:
		update_slot_display(slot_index)
	
	return true

func use_hotbar_slot(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return
	
	var slot_data = hotbar_data[slot_index]
	if slot_data["item_id"].is_empty():
		return
	
	var item_data = InventorySystem.get_item_data(slot_data["item_id"])
	var category = item_data.get("category", "").to_lower()
	
	if category == "consumable":
		if try_consume_item(slot_index):
			print("Consumed %s from hotbar slot %d" % [item_data.get("name", slot_data["item_id"]), slot_index + 1])
	elif category == "tool" or category == "equipment":
		print("Equipped %s from hotbar slot %d" % [item_data.get("name", slot_data["item_id"]), slot_index + 1])
	else:
		print("Used %s from hotbar slot %d" % [item_data.get("name", slot_data["item_id"]), slot_index + 1])
	
	item_used.emit(slot_index, slot_data["item_id"])

func try_consume_item(slot_index: int) -> bool:
	var slot_data = hotbar_data[slot_index]
	var item_id = slot_data["item_id"]
	
	if not InventorySystem.has_item(item_id, 1):
		clear_slot(slot_index)
		return false
	
	var player = GameManager.player_node
	if player and player.has_method("consume_item"):
		if InventorySystem.remove_item(item_id, 1):
			if player.inventory.add_item(item_id, 1) > 0:
				if player.consume_item(item_id):
					remove_item_from_hotbar(slot_index, 1)
					return true
				else:
					player.inventory.remove_item(item_id, 1)
					InventorySystem.add_item(item_id, 1)
			else:
				InventorySystem.add_item(item_id, 1)
	
	return false

func _on_slot_pressed(slot_index: int):
	use_hotbar_slot(slot_index)

func _on_slot_gui_input(event: InputEvent, slot_index: int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if we're currently dragging
		if DragPreviewManager and DragPreviewManager.is_dragging:
			# Drop on this hotbar slot
			DragPreviewManager.try_drop_on_hotbar(slot_index)
		else:
			# Not dragging - start drag if slot has item
			var slot_data = hotbar_data[slot_index]
			if not slot_data["item_id"].is_empty():
				start_drag_from_hotbar(slot_index)

func start_drag_from_hotbar(slot_index: int):
	if slot_index < 0 or slot_index >= HOTBAR_SLOTS:
		return

	var slot_data = hotbar_data[slot_index]
	if slot_data["item_id"].is_empty():
		return

	# Get icon texture
	var item_data = InventorySystem.get_item_data(slot_data["item_id"])
	var icon_path = item_data.get("icon_path", "")

	var icon_texture: Texture2D = null
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		icon_texture = load(icon_path)

	if DragPreviewManager:
		DragPreviewManager.start_drag("HOTBAR", slot_index, slot_data["item_id"], slot_data["quantity"], icon_texture)

func _on_inventory_changed():
	for i in range(HOTBAR_SLOTS):
		var slot_data = hotbar_data[i]
		if not slot_data["item_id"].is_empty():
			var actual_count = InventorySystem.get_item_count(slot_data["item_id"])
			if actual_count == 0:
				clear_slot(i)
			elif actual_count < slot_data["quantity"]:
				slot_data["quantity"] = actual_count
				update_slot_display(i)

func sync_with_inventory():
	for i in range(HOTBAR_SLOTS):
		var slot_data = hotbar_data[i]
		if not slot_data["item_id"].is_empty():
			var actual_count = InventorySystem.get_item_count(slot_data["item_id"])
			if actual_count != slot_data["quantity"]:
				slot_data["quantity"] = actual_count
				if actual_count == 0:
					clear_slot(i)
				else:
					update_slot_display(i)

func get_hotbar_save_data() -> Array:
	return hotbar_data.duplicate(true)

func load_hotbar_data(data: Array):
	if data.size() != HOTBAR_SLOTS:
		print("Warning: Hotbar save data size mismatch")
		return
	
	hotbar_data = data.duplicate(true)
	update_all_slots()
