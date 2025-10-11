@tool
extends BaseEditor
class_name AmmoEditor

# Ammo editor - handles CRUD operations for ammunition types and items

var stats_container: VBoxContainer

func get_data_file_path() -> String:
	return "res://data/ammo.json"

func get_editor_title() -> String:
	return "Ammo Editor"

# Override to handle nested ammo structure (ammo_items)
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
				# Extract ammo_items nested data for main editing
				data = full_data.get("ammo_items", {})
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
	
	# Load existing ammo types to preserve them
	var ammo_types = {}
	if FileAccess.file_exists(file_path):
		var existing_file = FileAccess.open(file_path, FileAccess.READ)
		if existing_file:
			var json_text = existing_file.get_as_text()
			existing_file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				ammo_types = json.data.get("ammo_types", {})
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Wrap data in nested structure, preserving ammo_types
		var full_data = {
			"ammo_types": ammo_types,
			"ammo_items": data
		}
		var json_text = JSON.stringify(full_data, "\t")
		file.store_string(json_text)
		file.close()
		return true
	else:
		return false

func create_form_fields(form_container: VBoxContainer) -> void:
	
	# Ammo ID field (disabled - auto-generated)
	create_text_field(form_container, "Ammo ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Ammo name field
	create_text_field(form_container, "Ammo Name", "NameField", "Ammo Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 60)
	
	# Ammo type dropdown
	var ammo_types = ["BULLET", "ARROW", "ENERGY", "PLASMA"]
	create_dropdown(form_container, "Ammo Type", "TypeField", ammo_types)
	
	# Icon field (with file browser)
	create_file_field(form_container, "Icon", "IconField", "*.png,*.jpg,*.jpeg,*.svg")
	
	# Stack size field
	create_number_field(form_container, "Stack Size", "StackSizeField", 1, 999, 50)
	
	# Damage and accuracy modifiers
	create_number_field(form_container, "Damage Modifier", "DamageModifierField", 0.1, 5.0, 1.0)
	create_number_field(form_container, "Accuracy Modifier", "AccuracyModifierField", 0.1, 2.0, 1.0)
	
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
	stats_label.text = "Ammo Stats:"
	stats_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(stats_label)
	
	var stats_scroll = ScrollContainer.new()
	stats_scroll.set_custom_minimum_size(Vector2(0, 100))
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

func add_stat_row(stat_name: String = "", stat_value = 0.0):
	if not stats_container:
		return
	
	var row = HBoxContainer.new()
	stats_container.add_child(row)
	
	# Stat name field
	var name_field = LineEdit.new()
	name_field.name = "StatName"
	name_field.placeholder_text = "Stat name (e.g., fire_damage)"
	name_field.text = stat_name
	name_field.set_custom_minimum_size(Vector2(150, 0))
	row.add_child(name_field)
	
	# Stat value field - handle different value types
	var value_field
	if typeof(stat_value) == TYPE_BOOL:
		value_field = CheckBox.new()
		value_field.button_pressed = stat_value
	else:
		value_field = SpinBox.new()
		value_field.min_value = -999
		value_field.max_value = 999
		value_field.step = 0.1
		value_field.value = float(stat_value)
	
	value_field.name = "StatValue"
	value_field.set_custom_minimum_size(Vector2(100, 0))
	row.add_child(value_field)
	
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
	var ammo_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", ammo_data.get("name", ""))
	set_field_value("DescriptionField", ammo_data.get("description", ""))
	set_field_value("TypeField", ammo_data.get("type", "BULLET"))
	set_field_value("IconField", ammo_data.get("icon", ""))
	set_field_value("StackSizeField", ammo_data.get("stack_size", 50))
	set_field_value("DamageModifierField", ammo_data.get("damage_modifier", 1.0))
	set_field_value("AccuracyModifierField", ammo_data.get("accuracy_modifier", 1.0))
	
	# Load recipe reference (if using new system)
	var recipe_id = ammo_data.get("recipe_id", "")
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		for i in range(recipe_dropdown.get_item_count()):
			var metadata = recipe_dropdown.get_item_metadata(i)
			if metadata == recipe_id:
				recipe_dropdown.selected = i
				break
	
	# Load stats
	clear_stat_rows()
	var stats = ammo_data.get("stats", {})
	for stat_name in stats:
		add_stat_row(stat_name, stats[stat_name])

func save_form_data() -> Dictionary:
	var ammo_data = {
		"name": get_field_value("NameField"),
		"description": get_field_value("DescriptionField"),
		"type": get_field_value("TypeField"),
		"icon": get_field_value("IconField"),
		"stack_size": get_field_value("StackSizeField"),
		"damage_modifier": get_field_value("DamageModifierField"),
		"accuracy_modifier": get_field_value("AccuracyModifierField"),
		"stats": {}
	}
	
	# Validate required fields
	if ammo_data["name"] == "" or ammo_data["name"] == null:
		return {}
	
	# Get recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown and recipe_dropdown.selected >= 0:
		var recipe_id = recipe_dropdown.get_item_metadata(recipe_dropdown.selected)
		if recipe_id != "":
			ammo_data["recipe_id"] = recipe_id
	
	# Get stats
	if stats_container:
		for row in stats_container.get_children():
			var name_field = row.find_child("StatName")
			var value_field = row.find_child("StatValue")
			
			if name_field and value_field and name_field.text.strip_edges() != "":
				var stat_name = name_field.text.strip_edges()
				var stat_value
				if value_field is CheckBox:
					stat_value = value_field.button_pressed
				else:
					stat_value = value_field.value
				ammo_data["stats"][stat_name] = stat_value
	
	return ammo_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("TypeField", "BULLET")
	set_field_value("IconField", "")
	set_field_value("StackSizeField", 50)
	set_field_value("DamageModifierField", 1.0)
	set_field_value("AccuracyModifierField", 1.0)
	
	# Clear recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		recipe_dropdown.selected = 0  # Select "(No Recipe)"
	
	# Clear stats
	clear_stat_rows()