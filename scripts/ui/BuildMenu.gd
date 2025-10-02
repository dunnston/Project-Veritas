extends Control
class_name BuildMenu

@onready var build_panel: PanelContainer = $BuildPanel
@onready var close_button: Button = $BuildPanel/VBoxContainer/TitleBar/CloseButton
@onready var category_tabs: TabContainer = $BuildPanel/VBoxContainer/MainContainer/LeftPanel/CategoryTabs
@onready var item_title: Label = $BuildPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemTitle
@onready var item_icon: TextureRect = $BuildPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemIcon
@onready var item_description: RichTextLabel = $BuildPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemDescription
@onready var resources_list: VBoxContainer = $BuildPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ResourcesList
@onready var build_button: Button = $BuildPanel/VBoxContainer/MainContainer/RightPanel/BuildButton

var building_system: Node
var selected_item_id: String = ""
var build_item_buttons: Array[Button] = []
var build_data: Dictionary = {}

signal item_to_build_selected(item_id: String)

static var instance: BuildMenu

func _ready() -> void:
	instance = self

	# Add to build_menu group so PlayerCombat can detect it
	add_to_group("build_menu")

	# Get building system reference
	building_system = get_node("/root/BuildingSystem") if get_node_or_null("/root/BuildingSystem") else null

	# Setup initial state
	visible = false
	setup_build_items()
	clear_selection()

func _input(event: InputEvent):
	# Only handle build_mode toggle when menu is not visible or when clicking outside the panel
	if event.is_action_pressed("build_mode"):
		toggle_build_menu()
		get_viewport().set_input_as_handled()

func toggle_build_menu():
	visible = not visible

	if visible:
		refresh_build_items()
		# Disable camera mouse control when menu opens
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Ensure the menu can receive mouse input
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# Re-enable camera mouse control when menu closes
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func setup_build_items():
	# UNIFIED SYSTEM: Load buildable items from unified JSON sources
	load_build_data_from_json()
	
	# SAFEGUARD: Check if UI nodes exist before accessing them
	if not category_tabs:
		push_error("BuildMenu: category_tabs node not found!")
		return
	
	# Create tabs dynamically for each category in the data
	for category_name in build_data.keys():
		var category_data = build_data[category_name]
		
		# Create or get the tab for this category
		var tab_container = get_or_create_category_tab(category_name)
		if not tab_container:
			continue
		
		var item_grid = tab_container.get_node_or_null("ItemGrid")
		if not item_grid:
			# Create ItemGrid if it doesn't exist
			item_grid = GridContainer.new()
			item_grid.name = "ItemGrid"
			item_grid.columns = 4  # 4 items per row
			tab_container.add_child(item_grid)
		
		# Clear existing items
		for child in item_grid.get_children():
			child.queue_free()
		
		# Add items to this category
		for item_id in category_data.keys():
			var item_data = category_data[item_id]
			var item_button = create_build_item_button(item_id, item_data)
			item_grid.add_child(item_button)
			build_item_buttons.append(item_button)

func get_or_create_category_tab(category_name: String) -> Control:
	# Try to find existing tab
	var existing_tab = category_tabs.get_node_or_null(category_name)
	if existing_tab:
		return existing_tab
	
	# Create new tab
	var new_tab = ScrollContainer.new()
	new_tab.name = category_name
	category_tabs.add_child(new_tab)
	category_tabs.set_tab_title(category_tabs.get_tab_count() - 1, category_name)
	
	return new_tab

func create_build_item_button(item_id: String, item_data: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(80, 80)
	button.name = "BuildItem_" + item_id
	button.mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure button receives clicks
	button.focus_mode = Control.FOCUS_ALL  # Allow button to receive focus

	# Set icon if available
	var icon_path = item_data.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		button.icon = load(icon_path)
		button.text = ""  # Remove text when we have an icon
		button.expand_icon = true
	else:
		button.text = item_data.get("name", item_id)

	# Connect button signal
	button.pressed.connect(_on_build_item_selected.bind(item_id, item_data))

	return button

func _on_build_item_selected(item_id: String, item_data: Dictionary):
	selected_item_id = item_id
	update_item_info(item_data)

func update_item_info(item_data: Dictionary):
	item_title.text = item_data.get("name", "Unknown Item")
	item_description.text = item_data.get("description", "No description available.")
	
	# Update icon if available
	var icon_path = item_data.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path)
	else:
		item_icon.texture = null
	
	# Update required resources
	update_required_resources(item_data.get("required_resources", {}))
	
	# Enable build button
	build_button.disabled = false

func update_required_resources(required_resources: Dictionary):
	# Clear existing resource displays
	for child in resources_list.get_children():
		child.queue_free()
	
	# Add resource requirements
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id) if InventorySystem else 0
		
		var resource_label = Label.new()
		var resource_data = InventorySystem.get_item_data(resource_id) if InventorySystem else {}
		var resource_name = resource_data.get("name", resource_id)
		
		# Color code based on availability
		var color = "green" if current_amount >= required_amount else "red"
		resource_label.text = "[color=%s]%s: %d/%d[/color]" % [color, resource_name, current_amount, required_amount]
		resource_label.add_theme_color_override("font_color", Color.WHITE)
		
		# Enable rich text for coloring
		var rich_label = RichTextLabel.new()
		rich_label.bbcode_enabled = true
		rich_label.text = "[color=%s]%s: %d/%d[/color]" % [color, resource_name, current_amount, required_amount]
		rich_label.fit_content = true
		rich_label.custom_minimum_size = Vector2(0, 20)
		
		resources_list.add_child(rich_label)

func refresh_build_items():
	# Refresh the resource displays for the selected item
	if not selected_item_id.is_empty():
		var item_data = get_item_data_by_id(selected_item_id)
		if not item_data.is_empty():
			update_required_resources(item_data.get("required_resources", {}))

func get_item_data_by_id(item_id: String) -> Dictionary:
	# Search through all categories to find the item
	for category_name in build_data.keys():
		var category_data = build_data[category_name]
		if item_id in category_data:
			return category_data[item_id]
	return {}

func can_afford_item(item_data: Dictionary) -> bool:
	var required_resources = item_data.get("required_resources", {})
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id) if InventorySystem else 0
		if current_amount < required_amount:
			return false
	return true

func consume_resources(item_data: Dictionary) -> bool:
	var required_resources = item_data.get("required_resources", {})
	
	# Check if we can afford all resources
	if not can_afford_item(item_data):
		return false
	
	# Consume the resources
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		if InventorySystem:
			var success = InventorySystem.remove_item(resource_id, required_amount)
			if not success:
				print("Failed to remove resource: %s" % resource_id)
				return false
	
	return true

func clear_selection():
	selected_item_id = ""
	item_title.text = "Select an item"
	item_icon.texture = null
	item_description.text = "Select an item to see details"
	build_button.disabled = true
	
	# Clear resources list
	for child in resources_list.get_children():
		child.queue_free()

func _on_close_button_pressed():
	visible = false
	# Re-enable camera mouse control when menu closes
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# UNIFIED SYSTEM: Load build data from recipes.json (you were right - recipes create buildings!)
func load_build_data_from_json():
	build_data = {}
	
	# Load recipes.json to get buildable items via recipes
	var recipes_file = "res://data/recipes.json"
	if FileAccess.file_exists(recipes_file):
		var file = FileAccess.open(recipes_file, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var recipes_data = json.data
			
			# Organize recipes by category for UI
			for recipe_id in recipes_data.keys():
				var recipe = recipes_data[recipe_id]
				
				# Skip recipes that shouldn't be in build menu
				if not recipe.get("include_in_build_menu", false):
					continue
				
				var raw_category = recipe.get("category", "misc")
				
				# Map categories to build menu categories
				var category = ""
				match raw_category.to_lower():
					"crafting_station":
						category = "Crafting"
					"building":
						category = "Building"  
					"emergency":
						category = "Emergency"
					"power":
						category = "Power"
					"production":
						category = "Production"
					"storage":
						category = "Storage"
					_:
						category = "Tools"  # Default fallback
				
				# Add to build menu data
				if category not in build_data:
					build_data[category] = {}
				
				build_data[category][recipe_id] = {
					"name": recipe.get("name", recipe_id),
					"description": recipe.get("description", "No description"),
					"icon_path": get_icon_path_for_recipe(recipe_id),
					"required_resources": recipe.get("ingredients", {})  # recipes use "ingredients"
				}
		else:
			push_error("BuildMenu: Failed to parse recipes.json")
	
	# Add fallback items if no data loaded
	if build_data.is_empty():
		build_data = {
			"Crafting": {
				"workbench": {
					"name": "Workbench",
					"description": "Essential crafting station",
					"icon_path": "res://assets/sprites/buildings/pixellab-A-sci-fi-workbench-with-a-meta-1756949376631.png",
					"required_resources": {"WOOD_SCRAPS": 5}  # Match recipes.json
				}
			}
		}

func get_icon_path_for_recipe(recipe_id: String) -> String:
	# Map recipe IDs to their icon paths - expandable for new items
	var icon_map = {
		"workbench": "res://assets/sprites/buildings/pixellab-A-sci-fi-workbench-with-a-meta-1756949376631.png",
		"oxygen_tank": "res://assets/sprites/items/oxygentank.png",
		"hand_crank_generator": "res://assets/sprites/items/generator2.png",
		"assembler": "res://assets/sprites/buildings/assembler.png",
		"battery": "res://assets/sprites/buildings/battery.png",
		"solar_panel": "res://assets/sprites/buildings/solar_panel.png",
		"food_processor": "res://assets/sprites/buildings/food_processor.png",
		"water_purifier": "res://assets/sprites/buildings/water_purifier.png",
		"storage_box": "res://assets/sprites/items/Chest.png",
		"basic_wall": "res://assets/sprites/buildings/basic_wall.png",
		"basic_floor": "res://assets/sprites/buildings/basic_floor.png"
	}
	
	var icon_path = icon_map.get(recipe_id, "")
	
	# Fallback: try to find icon based on recipe name
	if icon_path.is_empty():
		icon_path = "res://assets/sprites/items/" + recipe_id + ".png"
		# Check if file exists, if not use generic icon
		if not ResourceLoader.exists(icon_path):
			icon_path = "res://assets/sprites/ui/placeholder_icon.png"
	
	return icon_path

func _on_build_button_pressed():
	if selected_item_id.is_empty():
		return
	
	var item_data = get_item_data_by_id(selected_item_id)
	if item_data.is_empty():
		return
	
	# Check if we can afford the item
	if not can_afford_item(item_data):
		print("Cannot afford to build: %s" % selected_item_id)
		return
	
	# Don't consume resources yet - pass the item data to building system
	print("Starting building placement mode for: %s" % selected_item_id)
	
	# Emit signal with both item ID and cost data
	item_to_build_selected.emit(selected_item_id)
	
	# Close the build menu
	visible = false
