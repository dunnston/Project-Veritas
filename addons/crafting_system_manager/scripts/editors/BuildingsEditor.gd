@tool
extends BaseEditor
class_name BuildingsEditor

# Buildings editor - handles CRUD operations for buildings

var refund_container: VBoxContainer

func get_data_file_path() -> String:
	return "res://data/buildings.json"

func get_editor_title() -> String:
	return "Buildings Editor"

func create_form_fields(form_container: VBoxContainer) -> void:
	
	# Building ID field (disabled - auto-generated)
	create_text_field(form_container, "Building ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Building name field
	create_text_field(form_container, "Building Name", "NameField", "Building Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 60)
	
	# Category field
	var categories = ["structure", "crafting", "storage", "power", "production", "defense"]
	create_dropdown(form_container, "Category", "CategoryField", categories)
	
	# Icon field (with file browser)
	create_file_field(form_container, "Icon", "IconField", "*.png,*.jpg,*.jpeg,*.svg")

	# Scene path field (with file browser)
	create_file_field(form_container, "Scene Path", "ScenePathField", "*.tscn,*.scn")

	# Size section
	var size_label = Label.new()
	size_label.text = "Building Size:"
	size_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(size_label)
	
	var size_container = HBoxContainer.new()
	form_container.add_child(size_container)
	
	create_number_field(size_container, "Width (X)", "SizeXField", 1, 10, 1)
	create_number_field(size_container, "Height (Y)", "SizeYField", 1, 10, 1)
	
	# Health and power
	create_number_field(form_container, "Max Health", "MaxHealthField", 1, 1000, 100)
	create_number_field(form_container, "Power Consumption", "PowerConsumptionField", 0, 100, 0)
	
	# Interaction settings
	create_checkbox(form_container, "Interactable", "InteractableField")
	create_number_field(form_container, "Interaction Range", "InteractionRangeField", 0, 256, 64)
	
	# Movement/placement blocking
	create_checkbox(form_container, "Blocks Movement", "BlocksMovementField")
	create_checkbox(form_container, "Blocks Placement", "BlocksPlacementField")

	# Crafting station checkbox
	create_checkbox(form_container, "Is Crafting Station", "IsCraftingStationField")

	# Refund section
	var refund_label = Label.new()
	refund_label.text = "Refund on Deconstruction:"
	refund_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(refund_label)
	
	var refund_scroll = ScrollContainer.new()
	refund_scroll.set_custom_minimum_size(Vector2(0, 100))
	form_container.add_child(refund_scroll)
	
	refund_container = VBoxContainer.new()
	refund_container.name = "RefundContainer"
	refund_scroll.add_child(refund_container)
	
	var add_refund_btn = Button.new()
	add_refund_btn.text = "Add Refund Item"
	add_refund_btn.pressed.connect(_on_add_refund_pressed)
	form_container.add_child(add_refund_btn)

func create_checkbox(parent: Control, label_text: String, field_name: String) -> CheckBox:
	var container = HBoxContainer.new()
	parent.add_child(container)
	
	var label = Label.new()
	label.text = label_text + ":"
	label.set_custom_minimum_size(Vector2(150, 0))
	container.add_child(label)
	
	var checkbox = CheckBox.new()
	checkbox.name = field_name
	container.add_child(checkbox)
	
	return checkbox

func _on_add_refund_pressed():
	add_resource_row(refund_container, "refund")

func add_resource_row(container: VBoxContainer, type: String, set_resource_id: String = "", set_amount: float = 1.0):
	if not container:
		return
	
	var row = HBoxContainer.new()
	container.add_child(row)
	
	# Resource dropdown
	var resource_dropdown = OptionButton.new()
	resource_dropdown.name = "ResourceDropdown"
	populate_resource_dropdown(resource_dropdown)
	row.add_child(resource_dropdown)
	
	# Set the resource if specified
	if set_resource_id != "":
		for i in range(resource_dropdown.get_item_count()):
			var item_id = resource_dropdown.get_item_metadata(i)
			if item_id == set_resource_id:
				resource_dropdown.selected = i
				break
	
	# Amount spinner
	var amount_spin = SpinBox.new()
	amount_spin.name = "ResourceAmount"
	amount_spin.min_value = 1
	amount_spin.max_value = 999
	amount_spin.value = set_amount
	amount_spin.set_custom_minimum_size(Vector2(80, 0))
	row.add_child(amount_spin)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.set_custom_minimum_size(Vector2(30, 0))
	remove_btn.pressed.connect(_on_remove_resource_pressed.bind(row))
	row.add_child(remove_btn)

func populate_resource_dropdown(dropdown: OptionButton):
	dropdown.clear()
	
	# Load items from resources.json
	var items_data = {}
	var items_editor = get_parent().get_parent().get_node_or_null("TabContainer/Items")
	
	if items_editor and items_editor.data:
		items_data = items_editor.data
	else:
		# Fallback: load items data directly
		var file = FileAccess.open("res://data/resources.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				items_data = json.data
	
	# Add items to dropdown
	for item_id in items_data:
		var item_data = items_data[item_id]
		dropdown.add_item(item_data.get("name", item_id), -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, item_id)

func _on_remove_resource_pressed(row: Control):
	row.queue_free()

func clear_resource_rows(container: VBoxContainer):
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func load_item_into_form(item_id: String) -> void:
	var building_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", building_data.get("name", ""))
	set_field_value("DescriptionField", building_data.get("description", ""))
	set_field_value("CategoryField", building_data.get("category", "structure"))
	set_field_value("IconField", building_data.get("icon", ""))
	set_field_value("ScenePathField", building_data.get("scene_path", ""))

	# Load size
	var size = building_data.get("size", {"x": 1, "y": 1})
	set_field_value("SizeXField", size.get("x", 1))
	set_field_value("SizeYField", size.get("y", 1))
	
	# Load other properties
	set_field_value("MaxHealthField", building_data.get("max_health", 100))
	set_field_value("PowerConsumptionField", building_data.get("power_consumption", 0))
	set_field_value("InteractableField", building_data.get("interactable", false))
	set_field_value("InteractionRangeField", building_data.get("interaction_range", 64))
	set_field_value("BlocksMovementField", building_data.get("blocks_movement", true))
	set_field_value("BlocksPlacementField", building_data.get("blocks_placement", true))
	set_field_value("IsCraftingStationField", building_data.get("is_crafting_station", false))

	# Load refund
	clear_resource_rows(refund_container)
	var refund = building_data.get("refund", {})
	for resource_id in refund:
		add_resource_row(refund_container, "refund", resource_id, refund[resource_id])

func save_form_data() -> Dictionary:
	var building_data = {
		"name": get_field_value("NameField"),
		"description": get_field_value("DescriptionField"),
		"category": get_field_value("CategoryField"),
		"icon": get_field_value("IconField"),
		"scene_path": get_field_value("ScenePathField"),
		"size": {
			"x": get_field_value("SizeXField"),
			"y": get_field_value("SizeYField")
		},
		"max_health": get_field_value("MaxHealthField"),
		"power_consumption": get_field_value("PowerConsumptionField"),
		"interactable": get_field_value("InteractableField"),
		"interaction_range": get_field_value("InteractionRangeField"),
		"blocks_movement": get_field_value("BlocksMovementField"),
		"blocks_placement": get_field_value("BlocksPlacementField"),
		"is_crafting_station": get_field_value("IsCraftingStationField"),
		"refund": {}
	}
	
	# Validate required fields
	if building_data["name"] == "" or building_data["name"] == null:
		return {}

	# Get refund
	if refund_container:
		for row in refund_container.get_children():
			var dropdown = row.find_child("ResourceDropdown")
			var amount_spin = row.find_child("ResourceAmount")
			
			if dropdown and amount_spin and dropdown.selected >= 0:
				var resource_id = dropdown.get_item_metadata(dropdown.selected)
				building_data["refund"][resource_id] = amount_spin.value
	
	return building_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("CategoryField", "structure")
	set_field_value("IconField", "")
	set_field_value("ScenePathField", "")
	set_field_value("SizeXField", 1)
	set_field_value("SizeYField", 1)
	set_field_value("MaxHealthField", 100)
	set_field_value("PowerConsumptionField", 0)
	set_field_value("InteractableField", false)
	set_field_value("InteractionRangeField", 64)
	set_field_value("BlocksMovementField", true)
	set_field_value("BlocksPlacementField", true)
	set_field_value("IsCraftingStationField", false)

	# Clear refund
	clear_resource_rows(refund_container)