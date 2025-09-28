extends Control
class_name EquipedWeaponUI

@onready var weapon_icon: TextureRect = $PanelContainer/HBoxContainer/WeaponIcon
@onready var ammo_slot: TextureRect = $PanelContainer/HBoxContainer/AmmoSlot
@onready var ammo_button: Button = $PanelContainer/HBoxContainer/AmmoButton

var current_weapon: Weapon = null
var button_click_cooldown: float = 0.0
var is_ammo_menu_open: bool = false

func _ready():
	# Add to group
	add_to_group("weapon_ui")

	# Fix panel positioning and size
	setup_panel_layout()

	# Set proper mouse filtering to not block other UI interactions
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Hide initially
	visible = false

	# Connect to weapon manager signals
	if WeaponManager:
		WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)
		WeaponManager.weapon_switched.connect(_on_weapon_switched)

	# Set up ammo button
	if ammo_button:
		# DON'T connect to pressed signal - we'll handle clicks manually
		# ammo_button.pressed.connect(_on_ammo_button_pressed)
		# Prevent button clicks from propagating to other input handlers
		ammo_button.mouse_filter = Control.MOUSE_FILTER_STOP
		# Also handle the button's input directly to consume mouse events
		ammo_button.gui_input.connect(_on_ammo_button_input)
		# Set higher process priority to handle input before other systems
		ammo_button.process_priority = 100

	# Initial update
	update_display()

func setup_panel_layout():
	# Get the panel container
	var panel = $PanelContainer
	if panel:
		# Reset any weird scaling
		panel.scale = Vector2.ONE

		# Position in top-right corner with proper sizing
		panel.anchors_preset = Control.PRESET_TOP_RIGHT
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.anchor_top = 0.0
		panel.anchor_bottom = 0.0

		# Set reasonable size and position
		panel.offset_left = -180  # 180 pixels from right edge
		panel.offset_top = 20     # 20 pixels from top
		panel.offset_right = -20  # 20 pixels margin from right
		panel.offset_bottom = 70  # 50 pixels tall

		# Set proper mouse filtering for panel and children
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Also set the HBoxContainer to ignore
		var hbox = panel.get_node("HBoxContainer")
		if hbox:
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Make sure only the button can be clicked
		if weapon_icon:
			weapon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ammo_slot:
			ammo_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# ammo_button should remain MOUSE_FILTER_STOP so it can be clicked

func _on_weapon_equipped(weapon: Weapon, slot: String):
	update_display()

func _on_weapon_unequipped(_weapon: Weapon, _slot: String):
	update_display()

func _on_weapon_switched(_weapon: Weapon):
	update_display()

func update_display():
	if not WeaponManager:
		visible = false
		return

	current_weapon = WeaponManager.get_active_weapon()

	if not current_weapon:
		# No weapon equipped
		visible = false
		return

	# Show the UI
	visible = true

	# Update weapon icon
	if weapon_icon and current_weapon.icon:
		weapon_icon.texture = current_weapon.icon

	# Show/hide ammo slot based on weapon type
	print("Weapon type check - is_ranged(): ", current_weapon.is_ranged())
	if current_weapon.is_ranged():
		show_ammo_slot()
	else:
		hide_ammo_slot()

func show_ammo_slot():
	print("show_ammo_slot() called")
	if not ammo_slot or not ammo_button:
		print("Missing ammo_slot or ammo_button")
		return

	print("Setting ammo slot and button visible")
	ammo_slot.visible = true
	ammo_button.visible = true

	# Update ammo slot display
	update_ammo_slot()

func hide_ammo_slot():
	if ammo_slot:
		ammo_slot.visible = false
	if ammo_button:
		ammo_button.visible = false

func update_ammo_slot():
	if not current_weapon or not current_weapon.is_ranged():
		return

	# Always show current magazine ammo count
	var magazine_text = "%d/%d" % [current_weapon.current_ammo, current_weapon.magazine_size]

	if current_weapon.selected_ammo_id.is_empty():
		# No ammo selected - show empty slot
		if ammo_slot:
			ammo_slot.texture = null
		if ammo_button:
			ammo_button.text = "Select Ammo\n" + magazine_text
	else:
		# Show selected ammo icon
		var ammo_data = InventorySystem.get_item_data(current_weapon.selected_ammo_id)
		var icon_path = ammo_data.get("icon_path", "")

		if icon_path != "" and ResourceLoader.exists(icon_path):
			if ammo_slot:
				ammo_slot.texture = load(icon_path)

		# Show ammo count in button
		if ammo_button and InventorySystem:
			var ammo_count = InventorySystem.get_item_count(current_weapon.selected_ammo_id)
			var ammo_name = ammo_data.get("name", current_weapon.selected_ammo_id)
			ammo_button.text = "%s (%d)\n%s" % [ammo_name, ammo_count, magazine_text]

			# Check if we're out of this ammo type
			if ammo_count <= 0:
				# Clear selection when ammo runs out
				current_weapon.selected_ammo_id = ""
				update_ammo_slot()  # Refresh display

func _on_ammo_button_input(event: InputEvent):
	# Consume all mouse button events on the ammo button to prevent weapon firing
	if event is InputEventMouseButton:
		print("Ammo button input detected: ", event.button_index, " pressed: ", event.pressed)

		# Check if this is a left click press
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if the click is actually on the button
			var local_pos = ammo_button.to_local(event.global_position)
			var button_rect = Rect2(Vector2.ZERO, ammo_button.size)

			if button_rect.has_point(local_pos):
				print("Valid ammo button click detected - opening menu")
				# Immediately consume the event before it can reach other systems
				get_viewport().set_input_as_handled()
				event.handled = true

				# Manually trigger the ammo button functionality
				_on_ammo_button_pressed()
				return

		# Always consume mouse events on the button area
		get_viewport().set_input_as_handled()
		event.handled = true

func _on_ammo_button_pressed():
	if not current_weapon or not current_weapon.is_ranged():
		return

	print("Ammo button pressed - opening menu")
	# Set flag to block combat input
	is_ammo_menu_open = true

	# Consume any pending input events to prevent conflicts
	get_viewport().set_input_as_handled()
	show_ammo_selection_menu()

func show_ammo_selection_menu():
	print("show_ammo_selection_menu() called")
	# Get compatible ammo types for current weapon
	var compatible_types = current_weapon.get_compatible_ammo_types()
	print("Compatible ammo types: ", compatible_types)
	var available_ammo = []

	# Find all compatible ammo in inventory
	for ammo_type in compatible_types:
		var ammo_ids = get_ammo_ids_for_type(ammo_type)
		for ammo_id in ammo_ids:
			if InventorySystem and InventorySystem.has_item(ammo_id):
				available_ammo.append(ammo_id)

	print("Available ammo found: ", available_ammo)

	if available_ammo.is_empty():
		print("No compatible ammo found in inventory")
		return

	# Create popup menu
	var popup = PopupMenu.new()
	# Add to the main scene or a higher-level UI container for proper display
	get_tree().current_scene.add_child(popup)


	# Add ammo options to menu
	for i in range(available_ammo.size()):
		var ammo_id = available_ammo[i]
		var ammo_data = InventorySystem.get_item_data(ammo_id)
		var ammo_count = InventorySystem.get_item_count(ammo_id)
		var menu_text = "%s (%d)" % [ammo_data.get("name", ammo_id), ammo_count]

		popup.add_item(menu_text, i)

	# Connect selection signal
	print("Connecting popup signals...")
	popup.id_pressed.connect(func(index):
		print("Popup item clicked! Index: ", index)
		_on_ammo_selected(available_ammo, popup, index)
	)
	print("Connected id_pressed signal with lambda")

	# Connect popup closed signal to clear the blocking flag
	popup.popup_hide.connect(_on_ammo_popup_closed)
	print("Connected popup_hide signal")

	# Show popup at button position
	var button_pos = ammo_button.global_position
	popup.position = Vector2i(button_pos.x, button_pos.y + ammo_button.size.y)
	print("Showing popup at position: ", popup.position)
	popup.popup()
	print("Popup shown with ", popup.get_item_count(), " items")

func _on_ammo_popup_closed():
	# Clear the blocking flag when popup is closed
	is_ammo_menu_open = false
	print("Ammo popup closed")

func _on_ammo_selected(available_ammo: Array, popup: PopupMenu, index: int):
	print("_on_ammo_selected called with index: ", index, " available_ammo: ", available_ammo)

	# Clear the blocking flag first
	is_ammo_menu_open = false

	if index >= 0 and index < available_ammo.size():
		var selected_ammo_id = available_ammo[index]
		print("Setting weapon ammo to: ", selected_ammo_id)
		current_weapon.selected_ammo_id = selected_ammo_id

		var ammo_data = InventorySystem.get_item_data(selected_ammo_id)
		print("Selected %s for %s" % [ammo_data.get("name", selected_ammo_id), current_weapon.name])
		print("Weapon selected_ammo_id is now: ", current_weapon.selected_ammo_id)

		update_ammo_slot()
	else:
		print("Invalid selection index: ", index, " for array size: ", available_ammo.size())

	# Clean up popup
	popup.queue_free()

func is_blocking_input() -> bool:
	return is_ammo_menu_open

func get_ammo_ids_for_type(ammo_type: String) -> Array[String]:
	# Map ammo types to specific ammo IDs
	var ammo_mapping = {
		"BULLET": ["SCRAP_BULLETS", "FIRE_BULLETS"],
		"ARROW": ["WOOD_ARROWS", "STEEL_ARROWS"],
		"ENERGY": ["ENERGY_CELLS"],
		"PLASMA": ["PLASMA_CHARGES"]
	}

	var result: Array[String] = []
	if ammo_mapping.has(ammo_type):
		for ammo_id in ammo_mapping[ammo_type]:
			result.append(ammo_id)

	return result

# Update display periodically to show ammo count changes
func _input(event: InputEvent):
	# If ammo menu is open, consume all input events to prevent conflicts
	if is_ammo_menu_open and event is InputEventMouseButton:
		print("EquipedWeaponUI: Consuming input event while ammo menu open")
		get_viewport().set_input_as_handled()
		return

	# Check if click is on ammo button area
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and ammo_button and ammo_button.visible:
		var global_button_rect = Rect2(ammo_button.global_position, ammo_button.size)
		if global_button_rect.has_point(event.global_position):
			print("EquipedWeaponUI: Click on ammo button detected - opening menu")
			get_viewport().set_input_as_handled()

			# Trigger the ammo button functionality
			_on_ammo_button_pressed()
			return

func _process(_delta: float):
	if visible and current_weapon and current_weapon.is_ranged():
		update_ammo_slot()
