extends Control
class_name TurretUI

## UI for managing turret ammo inventory
## Shows a single slot for ammo and displays current ammo count

@onready var turret_panel: PanelContainer = $TurretPanel
@onready var title_label: Label = $TurretPanel/VBoxContainer/TitleBar/TitleLabel
@onready var close_button: Button = $TurretPanel/VBoxContainer/TitleBar/CloseButton
@onready var ammo_slot_button: Button = $TurretPanel/VBoxContainer/AmmoContainer/AmmoSlot
@onready var ammo_count_label: Label = $TurretPanel/VBoxContainer/AmmoContainer/AmmoCountLabel

var current_turret: Node3D = null

static var instance: TurretUI

const SLOT_SIZE = 64

func _ready():
	instance = self
	visible = false
	add_to_group("ui")
	add_to_group("turret_ui")

	# Connect button signals
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

	if ammo_slot_button:
		ammo_slot_button.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		ammo_slot_button.pressed.connect(_on_ammo_slot_pressed)
		ammo_slot_button.gui_input.connect(_on_ammo_slot_gui_input)
		print("TurretUI: Connected ammo_slot_button signals")

func _on_close_button_pressed():
	close_turret_interface()

func _on_ammo_slot_gui_input(event: InputEvent):
	# Handle drops when dragging
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if DragPreviewManager and DragPreviewManager.is_dragging:
				print("TurretUI: Trying to add ammo from drag")
				_try_add_ammo_from_drag()
				get_viewport().set_input_as_handled()

func _on_ammo_slot_pressed():
	print("TurretUI: AmmoSlot pressed, is_dragging: %s" % (DragPreviewManager.is_dragging if DragPreviewManager else "N/A"))

	# If not dragging, this is a click to remove ammo
	if not DragPreviewManager or not DragPreviewManager.is_dragging:
		print("TurretUI: Trying to remove ammo to inventory")
		_try_remove_ammo_to_inventory()

func _try_remove_ammo_to_inventory():
	if not current_turret:
		return

	var ammo_count = current_turret.get_ammo_count()
	if ammo_count <= 0:
		return  # No ammo to remove

	var ammo_type = current_turret.accepted_ammo_type

	# Get the icon for this ammo type
	var item_data = InventorySystem.get_item_data(ammo_type)
	var icon_texture: Texture2D = null
	if item_data and item_data.has("icon"):
		var icon_path = "res://assets/sprites/items/ammo/" + item_data["icon"]
		if ResourceLoader.exists(icon_path):
			icon_texture = load(icon_path)

	# Start dragging the ammo (source_type, source_index, item_id, quantity, icon_texture)
	if DragPreviewManager and icon_texture:
		DragPreviewManager.start_drag(
			"TURRET",
			0,  # slot index
			ammo_type,
			ammo_count,
			icon_texture
		)
		print("TurretUI: Started dragging %d %s from turret" % [ammo_count, ammo_type])


func _try_add_ammo_from_drag():
	if not DragPreviewManager.is_dragging:
		return

	if not current_turret:
		return

	var item_id = DragPreviewManager.drag_item_id
	var quantity = DragPreviewManager.drag_quantity

	# Try to add ammo to turret
	var remaining = current_turret.add_item_to_storage(item_id, quantity)

	if remaining < quantity:
		# Some or all ammo was added
		var added = quantity - remaining

		# Remove from source
		if DragPreviewManager.drag_source_type == "INVENTORY":
			if InventorySystem:
				InventorySystem.remove_item(item_id, added)

		# End the drag
		DragPreviewManager.end_drag(true)

		# Refresh display
		refresh_display()
	else:
		# None was added (wrong ammo type or full)
		DragPreviewManager.cancel_drag()

func open_turret_interface(turret: Node3D):
	current_turret = turret

	# Open player's inventory if not already open
	var inventory_ui = InventoryUI.instance
	if inventory_ui and not inventory_ui.visible:
		inventory_ui.toggle_inventory()

	# Wait a frame for inventory to position
	await get_tree().process_frame

	# Show turret UI
	visible = true
	position_next_to_inventory()

	# Update title
	if title_label:
		title_label.text = "Turret Ammo"

	refresh_display()

	# Release mouse for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func position_next_to_inventory():
	if not InventoryUI.instance or not InventoryUI.instance.visible:
		turret_panel.position = Vector2(300, 200)
		return

	# Get inventory main panel
	var inventory_panel = InventoryUI.instance.get_node("MainPanel")
	if inventory_panel:
		var inventory_rect = inventory_panel.get_global_rect()

		# Position to the LEFT of inventory
		var new_x = inventory_rect.position.x - turret_panel.size.x - 20
		var new_y = inventory_rect.position.y

		turret_panel.position = Vector2(new_x, new_y)
	else:
		turret_panel.position = Vector2(300, 200)

func close_turret_interface():
	visible = false
	current_turret = null

	# Close inventory too
	if InventoryUI.instance and InventoryUI.instance.visible:
		InventoryUI.instance.toggle_inventory()

	# Recapture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func refresh_display():
	if not current_turret:
		return

	var ammo_count = current_turret.get_ammo_count()
	var ammo_capacity = current_turret.get_ammo_capacity()
	var accepted_ammo = current_turret.accepted_ammo_type

	# Update ammo count label
	if ammo_count_label:
		ammo_count_label.text = "%d / %d" % [ammo_count, ammo_capacity]

	# Update ammo slot button
	if ammo_slot_button:
		if ammo_count > 0:
			# Try to load ammo icon
			var icon_path = "res://assets/sprites/items/ammo/ammo_bullet.png"
			if ResourceLoader.exists(icon_path):
				ammo_slot_button.icon = load(icon_path)

			ammo_slot_button.text = str(ammo_count)
		else:
			ammo_slot_button.icon = null
			ammo_slot_button.text = "Empty"

func _input(event: InputEvent):
	if not visible:
		return

	# Close on Escape or Tab
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_inventory"):
		close_turret_interface()
		get_viewport().set_input_as_handled()
