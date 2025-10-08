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
		ammo_slot_button.gui_input.connect(_on_ammo_slot_gui_input)

func _on_close_button_pressed():
	close_turret_interface()

func _on_ammo_slot_gui_input(event: InputEvent):
	if not event is InputEventMouseButton:
		return

	if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if player is dragging an item from inventory
		if DragPreviewManager and DragPreviewManager.is_dragging:
			_try_add_ammo_from_drag()

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
