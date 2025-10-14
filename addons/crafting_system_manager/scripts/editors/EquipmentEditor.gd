@tool
extends BaseEditor
class_name EquipmentEditor

# Equipment editor - handles CRUD operations for equipment

var stats_container: VBoxContainer

func get_data_file_path() -> String:
	return "res://data/equipment.json"

func get_editor_title() -> String:
	return "Equipment Editor"

# Override to handle nested equipment_items structure
func load_data() -> void:
	var file_path = get_data_file_path()
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			if parse_result == OK:
				var full_data = json.data
				# Extract equipment_items nested data
				data = full_data.get("equipment_items", {})
			else:
				data = {}
		else:
			data = {}
	else:
		data = {}
	
	emit_signal("data_changed")

# Override to save nested structure
func save_data() -> bool:
	var file_path = get_data_file_path()
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Wrap data in equipment_items structure
		var full_data = {
			"equipment_items": data
		}
		var json_text = JSON.stringify(full_data, "\t")
		file.store_string(json_text)
		file.close()
		return true
	else:
		return false

func create_form_fields(form_container: VBoxContainer) -> void:
	
	# Equipment ID field (disabled - auto-generated)
	create_text_field(form_container, "Equipment ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Equipment name field
	create_text_field(form_container, "Equipment Name", "NameField", "Equipment Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 60)
	
	# Equipment slot
	var slots = ["HEAD", "CHEST", "PANTS", "FEET", "HANDS", "BACK", "ACCESSORY"]
	create_dropdown(form_container, "Equipment Slot", "SlotField", slots)
	
	# Tier field
	create_number_field(form_container, "Tier", "TierField", 1, 10, 1)
	
	# Icon field (with file browser)
	create_file_field(form_container, "Icon", "IconField", "*.png,*.jpg,*.jpeg,*.svg")
	
	# Recipe reference section
	var recipe_label = Label.new()
	recipe_label.text = "Recipe Reference (for crafting):"
	recipe_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(recipe_label)
	
	var recipe_dropdown = OptionButton.new()
	recipe_dropdown.name = "RecipeField"
	populate_recipe_dropdown(recipe_dropdown)
	form_container.add_child(recipe_dropdown)
	
	# Stats section
	var stats_label = Label.new()
	stats_label.text = "Equipment Stats:"
	stats_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(stats_label)
	
	var stats_scroll = ScrollContainer.new()
	stats_scroll.set_custom_minimum_size(Vector2(0, 150))
	form_container.add_child(stats_scroll)
	
	stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_scroll.add_child(stats_container)
	
	var add_stat_btn = Button.new()
	add_stat_btn.text = "Add Stat"
	add_stat_btn.pressed.connect(_on_add_stat_pressed)
	form_container.add_child(add_stat_btn)

func populate_recipe_dropdown(dropdown: OptionButton):
	dropdown.clear()
	dropdown.add_item("(No Recipe)", -1)
	dropdown.set_item_metadata(0, "")
	
	# Load recipes data
	var recipes_data = {}
	var recipes_editor = get_parent().get_parent().get_node_or_null("TabContainer/Recipes")
	
	if recipes_editor and recipes_editor.data:
		recipes_data = recipes_editor.data
	else:
		# Fallback: load recipes data directly
		var file = FileAccess.open("res://data/recipes.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				recipes_data = json.data
	
	# Add recipes to dropdown
	for recipe_id in recipes_data:
		var recipe_data = recipes_data[recipe_id]
		dropdown.add_item(recipe_data.get("name", recipe_id) + " (Recipe)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, recipe_id)

func _on_add_stat_pressed():
	add_stat_row()

func add_stat_row(stat_name: String = "", stat_value: float = 0.0):
	if not stats_container:
		return
	
	var row = HBoxContainer.new()
	stats_container.add_child(row)
	
	# Stat name field
	var name_field = LineEdit.new()
	name_field.name = "StatName"
	name_field.placeholder_text = "Stat name (e.g., defense)"
	name_field.text = stat_name
	name_field.set_custom_minimum_size(Vector2(150, 0))
	row.add_child(name_field)
	
	# Stat value field
	var value_spin = SpinBox.new()
	value_spin.name = "StatValue"
	value_spin.min_value = -999
	value_spin.max_value = 999
	value_spin.step = 0.1
	value_spin.value = stat_value
	value_spin.set_custom_minimum_size(Vector2(100, 0))
	row.add_child(value_spin)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.set_custom_minimum_size(Vector2(30, 0))
	remove_btn.pressed.connect(_on_remove_stat_pressed.bind(row))
	row.add_child(remove_btn)

func _on_remove_stat_pressed(row: Control):
	row.queue_free()

func clear_stat_rows():
	if not stats_container:
		return
	for child in stats_container.get_children():
		child.queue_free()

func load_item_into_form(item_id: String) -> void:
	var equipment_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", equipment_data.get("name", ""))
	set_field_value("DescriptionField", equipment_data.get("description", ""))
	set_field_value("SlotField", equipment_data.get("slot", "HEAD"))
	set_field_value("TierField", equipment_data.get("tier", 1))
	set_field_value("IconField", equipment_data.get("icon", ""))
	
	# Load recipe reference (if using new system)
	var recipe_id = equipment_data.get("recipe_id", "")
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		for i in range(recipe_dropdown.get_item_count()):
			var metadata = recipe_dropdown.get_item_metadata(i)
			if metadata == recipe_id:
				recipe_dropdown.selected = i
				break
	
	# Load stats
	clear_stat_rows()
	var stats = equipment_data.get("stats", {})
	for stat_name in stats:
		add_stat_row(stat_name, stats[stat_name])

func save_form_data() -> Dictionary:
	var equipment_data = {
		"name": get_field_value("NameField"),
		"description": get_field_value("DescriptionField"),
		"slot": get_field_value("SlotField"),
		"tier": get_field_value("TierField"),
		"icon": get_field_value("IconField"),
		"stats": {}
	}
	
	# Validate required fields
	if equipment_data["name"] == "" or equipment_data["name"] == null:
		return {}
	
	# Get recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown and recipe_dropdown.selected >= 0:
		var recipe_id = recipe_dropdown.get_item_metadata(recipe_dropdown.selected)
		if recipe_id != "":
			equipment_data["recipe_id"] = recipe_id
	
	# Get stats
	if stats_container:
		for row in stats_container.get_children():
			var name_field = row.find_child("StatName")
			var value_spin = row.find_child("StatValue")
			
			if name_field and value_spin and name_field.text.strip_edges() != "":
				var stat_name = name_field.text.strip_edges()
				equipment_data["stats"][stat_name] = value_spin.value
	
	return equipment_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("SlotField", "HEAD")
	set_field_value("TierField", 1)
	set_field_value("IconField", "")
	
	# Clear recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		recipe_dropdown.selected = 0  # Select "(No Recipe)"
	
	# Clear stats
	clear_stat_rows()
