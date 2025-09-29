extends Control
class_name DevMenu

@onready var item_container: GridContainer = $Panel/ScrollContainer/ItemContainer
@onready var close_button: Button = $Panel/VBoxContainer/TitleBar/CloseButton
@onready var search_bar: LineEdit = $Panel/VBoxContainer/SearchBar

var all_items: Dictionary = {}

func _ready():
	visible = false
	load_all_items()
	create_item_buttons()
	
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	if search_bar:
		search_bar.text_changed.connect(_on_search_changed)

func _input(event: InputEvent):
	if event.is_action_pressed("open_dev_menu"):
		toggle_menu()

func toggle_menu():
	visible = !visible
	if visible:
		# Release mouse for UI interaction
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		refresh_item_buttons()
	else:
		# Recapture mouse for gameplay
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func load_all_items():
	# Get all items from InventorySystem
	if InventorySystem:
		# Load all defined items from InventorySystem
		var items_to_add = [
			"WOOD_SCRAPS", "METAL_SCRAPS", "SCRAP_METAL", "ELECTRONICS", 
			"ENERGY_CELLS", "BIO_MATTER", "RARE_MINERALS", "WATER", "FOOD",
			"METAL_SHEETS", "RUBBER_SEAL", "COPPER_WIRE", "STEEL_GEARS",
			"CHEMICAL_CATALYST", "OXYGEN_TANK", "HAND_CRANK_GENERATOR",
			"crowbar", "TIRE", "SPEAKERS", "GEARS", "SPRING",
			"STEEL_SHEET", "METAL_ROD", "GEAR_ASSEMBLY", "METAL_VALVE", "MAGNETS"
		]
		
		for item_id in items_to_add:
			var item_data = InventorySystem.get_item_data(item_id)
			if item_data and item_data.get("name") != "Unknown Item":
				all_items[item_id] = item_data

func create_item_buttons():
	# Clear existing buttons
	for child in item_container.get_children():
		child.queue_free()
	
	# Create button for each item
	for item_id in all_items.keys():
		var item_data = all_items[item_id]
		var button = create_item_button(item_id, item_data)
		item_container.add_child(button)

func create_item_button(item_id: String, item_data: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	button.text = item_data.get("name", item_id)
	button.tooltip_text = "Click to add 1 to inventory\nShift+Click for 10\nCtrl+Click for max stack"
	
	# Add icon if available
	var icon_path = item_data.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.expand_icon = true
	
	# Connect click signal
	button.pressed.connect(_on_item_button_pressed.bind(item_id))
	
	return button

func _on_item_button_pressed(item_id: String):
	if not InventorySystem:
		return
	
	var amount = 1
	var item_data = all_items.get(item_id, {})
	var max_stack = item_data.get("max_stack", 1)
	
	# Check for modifier keys
	if Input.is_key_pressed(KEY_SHIFT):
		amount = 10
	elif Input.is_key_pressed(KEY_CTRL):
		amount = max_stack
	
	# Add item to inventory
	var success = InventorySystem.add_item(item_id, amount)
	
	if success:
		print("[DEV] Added %d %s to inventory" % [amount, item_data.get("name", item_id)])
	else:
		print("[DEV] Failed to add %s - inventory may be full" % item_data.get("name", item_id))
	
	refresh_item_buttons()

func refresh_item_buttons():
	# Update button states to show current inventory counts
	var button_index = 0
	for item_id in all_items.keys():
		if button_index >= item_container.get_child_count():
			break
			
		var button = item_container.get_child(button_index)
		var current_count = InventorySystem.get_item_count(item_id)
		var item_data = all_items[item_id]
		var max_stack = item_data.get("max_stack", 1)
		
		# Update button text to show count
		button.text = "%s (%d/%d)" % [item_data.get("name", item_id), current_count, max_stack]
		
		# Disable if at max stack
		button.disabled = (current_count >= max_stack * 20)  # Allow up to 20 stacks
		
		button_index += 1

func _on_search_changed(search_text: String):
	var search_lower = search_text.to_lower()
	
	for i in range(item_container.get_child_count()):
		var button = item_container.get_child(i)
		var item_name = button.text.split(" (")[0].to_lower()
		
		# Show/hide based on search
		button.visible = search_lower.is_empty() or item_name.contains(search_lower)

func _on_close_pressed():
	visible = false
	# Recapture mouse for gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
