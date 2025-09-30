extends CanvasLayer

## Manages drag-and-drop preview for inventory items
## Autoload singleton that handles visual feedback and item transfer between UI slots

signal drag_started(source_type: String, source_index: int, item_id: String)
signal drag_ended(success: bool)
signal item_dropped(target_type: String, target_index: int)

enum SourceType {
	INVENTORY,
	HOTBAR,
	EQUIPMENT
}

# Drag state
var is_dragging: bool = false
var drag_source_type: String = ""
var drag_source_index: int = -1
var drag_source_slot_type: String = ""  # For equipment slots
var drag_item_id: String = ""
var drag_quantity: int = 0

# Preview visual
var preview_panel: PanelContainer
var preview_icon: TextureRect
var preview_quantity: Label

func _ready():
	# Make sure this layer is on top
	layer = 100

	setup_preview()
	print("DragPreviewManager autoload initialized")

func setup_preview():
	# Create preview panel (initially hidden)
	preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(64, 64)
	preview_panel.size = Vector2(64, 64)
	preview_panel.modulate = Color(1, 1, 1, 0.8)  # Semi-transparent
	preview_panel.visible = false
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.z_index = 100  # Make sure it's on top

	# Add a visible background color to the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)  # Dark gray background
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(1, 1, 1, 0.5)  # White border
	preview_panel.add_theme_stylebox_override("panel", style_box)

	add_child(preview_panel)

	# Create icon
	preview_icon = TextureRect.new()
	preview_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.custom_minimum_size = Vector2(64, 64)
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_icon)

	# Create quantity label
	preview_quantity = Label.new()
	preview_quantity.anchor_left = 1.0
	preview_quantity.anchor_top = 1.0
	preview_quantity.anchor_right = 1.0
	preview_quantity.anchor_bottom = 1.0
	preview_quantity.offset_left = -25
	preview_quantity.offset_top = -20
	preview_quantity.add_theme_color_override("font_color", Color.WHITE)
	preview_quantity.add_theme_color_override("font_shadow_color", Color.BLACK)
	preview_quantity.add_theme_constant_override("shadow_offset_x", 2)
	preview_quantity.add_theme_constant_override("shadow_offset_y", 2)
	preview_quantity.add_theme_font_size_override("font_size", 16)
	preview_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_quantity)

func _process(_delta):
	if is_dragging:
		# Update preview position to follow mouse
		var mouse_pos = get_viewport().get_mouse_position()
		preview_panel.global_position = mouse_pos - Vector2(32, 32)

func _input(event: InputEvent):
	if not is_dragging:
		return

	# Cancel drag on right-click
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_drag()
			get_viewport().set_input_as_handled()

func start_drag(source_type: String, source_index: int, item_id: String, quantity: int, icon_texture: Texture2D, slot_type: String = ""):
	if is_dragging:
		cancel_drag()

	is_dragging = true
	drag_source_type = source_type
	drag_source_index = source_index
	drag_source_slot_type = slot_type  # Store equipment slot type if applicable
	drag_item_id = item_id
	drag_quantity = quantity

	# Setup preview visuals
	preview_icon.texture = icon_texture
	if quantity > 1:
		preview_quantity.text = str(quantity)
		preview_quantity.visible = true
	else:
		preview_quantity.visible = false

	preview_panel.visible = true
	drag_started.emit(source_type, source_index, item_id)

func try_drop_on_inventory(slot_index: int) -> bool:
	if not is_dragging:
		return false

	# Can't drop on same source slot
	if drag_source_type == "INVENTORY" and drag_source_index == slot_index:
		cancel_drag()
		return false

	var success = false

	match drag_source_type:
		"INVENTORY":
			# Swap or stack items
			success = swap_inventory_slots(drag_source_index, slot_index)
		"HOTBAR":
			# Move from hotbar to inventory (always allowed)
			success = move_from_hotbar_to_inventory(drag_source_index, slot_index)
		"EQUIPMENT":
			# Move from equipment to inventory (always allowed)
			success = move_from_equipment_to_inventory(drag_source_type, slot_index)

	if success:
		item_dropped.emit("INVENTORY", slot_index)

	end_drag(success)
	return success

func try_drop_on_hotbar(slot_index: int) -> bool:
	if not is_dragging:
		return false

	# Can't drop on same source slot
	if drag_source_type == "HOTBAR" and drag_source_index == slot_index:
		cancel_drag()
		return false

	var success = false

	match drag_source_type:
		"INVENTORY":
			# Link inventory item to hotbar
			success = link_inventory_to_hotbar(drag_source_index, slot_index)
		"HOTBAR":
			# Swap hotbar slots
			success = swap_hotbar_slots(drag_source_index, slot_index)
		"EQUIPMENT":
			# Can't directly move equipment to hotbar
			success = false

	if success:
		item_dropped.emit("HOTBAR", slot_index)

	end_drag(success)
	return success

func try_drop_on_equipment(slot_type: String) -> bool:
	if not is_dragging:
		return false

	# Can't drop on same source slot
	if drag_source_type == "EQUIPMENT" and drag_source_index == get_equipment_slot_index(slot_type):
		cancel_drag()
		return false

	var success = false

	match drag_source_type:
		"INVENTORY":
			# Equip item from inventory with validation
			success = equip_from_inventory(drag_source_index, slot_type)
		"EQUIPMENT":
			# Swap equipment slots (if compatible)
			success = swap_equipment_slots(drag_source_type, slot_type)
		"HOTBAR":
			# Can't directly move from hotbar to equipment
			success = false

	if success:
		item_dropped.emit("EQUIPMENT", get_equipment_slot_index(slot_type))

	end_drag(success)
	return success

func cancel_drag():
	is_dragging = false
	preview_panel.visible = false
	drag_source_type = ""
	drag_source_index = -1
	drag_source_slot_type = ""
	drag_item_id = ""
	drag_quantity = 0

	drag_ended.emit(false)
	print("Drag cancelled")

func end_drag(success: bool):
	is_dragging = false
	preview_panel.visible = false

	if success:
		print("Drag completed successfully")

	drag_ended.emit(success)

	# Clear drag data
	drag_source_type = ""
	drag_source_index = -1
	drag_source_slot_type = ""
	drag_item_id = ""
	drag_quantity = 0

# Helper functions for item transfers

func swap_inventory_slots(from_index: int, to_index: int) -> bool:
	if not InventorySystem:
		return false

	var from_slot = InventorySystem.inventory_slots[from_index]
	var to_slot = InventorySystem.inventory_slots[to_index]

	# Try to stack if same item
	if not to_slot.is_empty() and from_slot.item_id == to_slot.item_id:
		var space = to_slot.get_remaining_space()
		if space > 0:
			var amount = min(from_slot.quantity, space)
			to_slot.add_items(amount)
			from_slot.remove_items(amount)
			InventorySystem.inventory_changed.emit()
			return true

	# Otherwise swap slots
	var temp_id = from_slot.item_id
	var temp_qty = from_slot.quantity
	var temp_max = from_slot.max_stack

	from_slot.item_id = to_slot.item_id
	from_slot.quantity = to_slot.quantity
	from_slot.max_stack = to_slot.max_stack

	to_slot.item_id = temp_id
	to_slot.quantity = temp_qty
	to_slot.max_stack = temp_max

	InventorySystem.inventory_changed.emit()
	return true

func move_from_hotbar_to_inventory(hotbar_index: int, inventory_index: int) -> bool:
	# Hotbar doesn't physically contain items, just links
	# This would just unlink the hotbar slot
	var hud = get_tree().get_nodes_in_group("hud")
	if not hud.is_empty():
		var hotbar = hud[0].hotbar
		if hotbar:
			hotbar.clear_slot(hotbar_index)
			return true
	return false

func move_from_equipment_to_inventory(equipment_slot: String, inventory_index: int) -> bool:
	# Use stored slot type from drag state
	var slot_to_unequip = drag_source_slot_type if not drag_source_slot_type.is_empty() else equipment_slot

	# Unequip handles adding back to inventory automatically
	var equipped_item = EquipmentManager.get_equipped_item(slot_to_unequip)
	if equipped_item:
		var unequipped = EquipmentManager.unequip_item(slot_to_unequip)
		return unequipped != null

	# Check if weapon
	var equipped_weapon = WeaponManager.get_equipped_weapon(slot_to_unequip)
	if equipped_weapon:
		return WeaponManager.unequip_weapon(slot_to_unequip) != null

	return false

func link_inventory_to_hotbar(inventory_index: int, hotbar_index: int) -> bool:
	if not InventorySystem:
		return false

	var slot = InventorySystem.inventory_slots[inventory_index]
	if slot.is_empty():
		return false

	# Find hotbar through HUD
	var hud = get_tree().get_nodes_in_group("hud")

	if hud.is_empty():
		# Try alternative: find hotbar directly in scene tree
		var hotbar_layer = get_tree().get_root().get_node_or_null("DemoScene/HotbarLayer")
		if hotbar_layer:
			var hotbar = hotbar_layer.get_node_or_null("Hotbar")
			if hotbar:
				hotbar.set_slot(hotbar_index, slot.item_id, slot.quantity)
				return true
		return false

	var hotbar = hud[0].hotbar
	if not hotbar:
		return false

	# Set the hotbar slot to link to this item
	hotbar.set_slot(hotbar_index, slot.item_id, slot.quantity)
	return true

func swap_hotbar_slots(from_index: int, to_index: int) -> bool:
	var hud = get_tree().get_nodes_in_group("hud")
	if hud.is_empty():
		return false

	var hotbar = hud[0].hotbar
	if not hotbar:
		return false

	# Swap hotbar data
	var temp_data = hotbar.hotbar_data[from_index].duplicate()
	hotbar.hotbar_data[from_index] = hotbar.hotbar_data[to_index].duplicate()
	hotbar.hotbar_data[to_index] = temp_data

	hotbar.update_slot_display(from_index)
	hotbar.update_slot_display(to_index)

	return true

func equip_from_inventory(inventory_index: int, equipment_slot: String) -> bool:
	if not InventorySystem:
		return false

	var slot = InventorySystem.inventory_slots[inventory_index]
	if slot.is_empty():
		return false

	var item_id = slot.item_id

	# Check if equipment
	if EquipmentManager.equipment_data.has(item_id):
		var equipment = EquipmentManager.create_equipment(item_id)
		if not equipment:
			return false

		# Validate slot type matches
		if equipment.slot != equipment_slot:
			print("Cannot equip %s to %s slot" % [equipment.name, equipment_slot])
			return false

		# Try to equip
		if EquipmentManager.equip_item(equipment):
			InventorySystem.remove_item(item_id, 1)
			return true

	# Check if weapon
	elif WeaponManager.weapon_data.has(item_id):
		# Only allow weapon drops on weapon slots
		if equipment_slot != "PRIMARY_WEAPON" and equipment_slot != "SECONDARY_WEAPON":
			print("Cannot equip weapon to %s slot" % equipment_slot)
			return false

		var weapon = WeaponManager.create_weapon(item_id)
		if not weapon:
			return false

		if WeaponManager.equip_weapon(weapon, equipment_slot):
			InventorySystem.remove_item(item_id, 1)
			return true

	return false

func swap_equipment_slots(from_slot: String, to_slot: String) -> bool:
	# Equipment swapping not implemented yet
	# Would need to check slot compatibility
	return false

func get_equipment_slot_index(slot_type: String) -> int:
	# Convert slot type to index for tracking
	var slots = ["HEAD", "CHEST", "PANTS", "FEET", "TRINKET_1", "TRINKET_2", "TRINKET_3",
				 "BACKPACK", "PRIMARY_WEAPON", "SECONDARY_WEAPON", "TOOL"]
	return slots.find(slot_type)

func get_hotbar_reference() -> Control:
	# Find the hotbar in the scene tree
	var hud_nodes = get_tree().get_nodes_in_group("hud")
	if not hud_nodes.is_empty():
		var hotbar = hud_nodes[0].get_node_or_null("hotbar")
		if hotbar:
			return hotbar

	# Alternative: search by node name in UI layer
	var ui_layer = get_tree().get_root().get_node_or_null("DemoScene/UI")
	if ui_layer:
		var hotbar = ui_layer.get_node_or_null("Hotbar")
		if hotbar:
			return hotbar

	return null

func get_hotbar_slot_at_position(hotbar: Control, mouse_pos: Vector2) -> int:
	# Check each hotbar slot to see if mouse is over it
	if not hotbar.slot_buttons or hotbar.slot_buttons.is_empty():
		return -1

	for i in range(hotbar.slot_buttons.size()):
		var slot_button = hotbar.slot_buttons[i]
		if slot_button and slot_button is Control:
			var rect = slot_button.get_global_rect()
			if rect.has_point(mouse_pos):
				return i

	return -1
