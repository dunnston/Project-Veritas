@tool
extends BaseEditor
class_name WeaponsEditor

# Weapons editor - handles CRUD operations for weapons

var stats_container: VBoxContainer
var ammo_types_container: VBoxContainer

func get_data_file_path() -> String:
	return "res://data/weapons.json"

func get_editor_title() -> String:
	return "Weapons Editor"

# Override to handle nested weapons structure
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
				# Extract weapons nested data
				data = full_data.get("weapons", {})
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
	
	# Load existing weapon_types and weapon_stats to preserve them
	var weapon_types = {}
	var weapon_stats = {}
	if FileAccess.file_exists(file_path):
		var existing_file = FileAccess.open(file_path, FileAccess.READ)
		if existing_file:
			var json_text = existing_file.get_as_text()
			existing_file.close()
			var json = JSON.new()
			if json.parse(json_text) == OK:
				weapon_types = json.data.get("weapon_types", {})
				weapon_stats = json.data.get("weapon_stats", {})
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		# Wrap data in nested structure, preserving other sections
		var full_data = {
			"weapon_stats": weapon_stats,
			"weapon_types": weapon_types,
			"weapons": data
		}
		var json_text = JSON.stringify(full_data, "\t")
		file.store_string(json_text)
		file.close()
		return true
	else:
		return false

func create_form_fields(form_container: VBoxContainer) -> void:
	# Weapon ID field (disabled - auto-generated)
	create_text_field(form_container, "Weapon ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Weapon name field
	create_text_field(form_container, "Weapon Name", "NameField", "Weapon Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 60)
	
	# Weapon type
	var weapon_types = ["MELEE", "RANGED"]
	create_dropdown(form_container, "Weapon Type", "TypeField", weapon_types)
	
	# Tier field
	create_number_field(form_container, "Tier", "TierField", 1, 10, 1)
	
	# Icon field (with file browser)
	create_file_field(form_container, "Icon", "IconField", "*.png,*.jpg,*.jpeg,*.svg")
	
	# Basic weapon stats
	create_number_field(form_container, "Damage", "DamageField", 1, 999, 10)
	create_number_field(form_container, "Attack Speed", "AttackSpeedField", 0.1, 10.0, 1.0)
	create_number_field(form_container, "Range", "RangeField", 0.1, 50.0, 5.0)
	create_number_field(form_container, "Durability", "DurabilityField", 1, 9999, 100)
	
	# Ranged weapon specific fields
	create_number_field(form_container, "Magazine Size (Ranged)", "MagazineSizeField", 0, 999, 1)
	create_number_field(form_container, "Reload Time (Ranged)", "ReloadTimeField", 0.1, 60.0, 2.0)
	
	# Compatible ammo types section (for ranged weapons)
	var ammo_header = HBoxContainer.new()
	form_container.add_child(ammo_header)
	
	var ammo_label = Label.new()
	ammo_label.text = "Compatible Ammo Types (Ranged Weapons):"
	ammo_label.add_theme_font_size_override("font_size", 12)
	ammo_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ammo_header.add_child(ammo_label)
	
	var add_ammo_type_btn = Button.new()
	add_ammo_type_btn.text = "Add Ammo Type"
	add_ammo_type_btn.pressed.connect(_on_add_ammo_type_pressed)
	ammo_header.add_child(add_ammo_type_btn)
	
	var ammo_scroll = ScrollContainer.new()
	ammo_scroll.set_custom_minimum_size(Vector2(0, 80))
	form_container.add_child(ammo_scroll)
	
	ammo_types_container = VBoxContainer.new()
	ammo_types_container.name = "AmmoTypesContainer"
	ammo_scroll.add_child(ammo_types_container)
	
	# Recipe reference section
	var recipe_label = Label.new()
	recipe_label.text = "Recipe Reference (for crafting):"
	recipe_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(recipe_label)
	
	var recipe_dropdown = OptionButton.new()
	recipe_dropdown.name = "RecipeField"
	populate_recipe_dropdown(recipe_dropdown)
	form_container.add_child(recipe_dropdown)
	
	# Weapon stats section
	var stats_header = HBoxContainer.new()
	form_container.add_child(stats_header)
	
	var stats_label = Label.new()
	stats_label.text = "Weapon Stats:"
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_header.add_child(stats_label)
	
	var add_stat_btn = Button.new()
	add_stat_btn.text = "Add Stat"
	add_stat_btn.pressed.connect(_on_add_stat_pressed)
	stats_header.add_child(add_stat_btn)
	
	var stats_scroll = ScrollContainer.new()
	stats_scroll.set_custom_minimum_size(Vector2(0, 120))
	form_container.add_child(stats_scroll)
	
	stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	stats_scroll.add_child(stats_container)

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

func _on_add_ammo_type_pressed():
	add_ammo_type_row()

func add_ammo_type_row(ammo_type: String = ""):
	if not ammo_types_container:
		return
	
	var row = HBoxContainer.new()
	ammo_types_container.add_child(row)
	
	# Ammo type dropdown
	var ammo_dropdown = OptionButton.new()
	ammo_dropdown.name = "AmmoType"
	ammo_dropdown.add_item("BULLET")
	ammo_dropdown.add_item("ARROW")
	ammo_dropdown.add_item("ENERGY")
	ammo_dropdown.add_item("PLASMA")
	
	# Set selected ammo type
	if ammo_type != "":
		for i in range(ammo_dropdown.get_item_count()):
			if ammo_dropdown.get_item_text(i) == ammo_type:
				ammo_dropdown.selected = i
				break
	
	row.add_child(ammo_dropdown)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.set_custom_minimum_size(Vector2(30, 0))
	remove_btn.pressed.connect(_on_remove_ammo_type_pressed.bind(row))
	row.add_child(remove_btn)

func _on_remove_ammo_type_pressed(row: Control):
	row.queue_free()

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
	name_field.placeholder_text = "Stat name (e.g., accuracy)"
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

func clear_ammo_types():
	if not ammo_types_container:
		return
	for child in ammo_types_container.get_children():
		child.queue_free()

func clear_stat_rows():
	if not stats_container:
		return
	for child in stats_container.get_children():
		child.queue_free()

func load_item_into_form(item_id: String) -> void:
	var weapon_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", weapon_data.get("name", ""))
	set_field_value("DescriptionField", weapon_data.get("description", ""))
	set_field_value("TypeField", weapon_data.get("type", "MELEE"))
	set_field_value("TierField", weapon_data.get("tier", 1))
	set_field_value("IconField", weapon_data.get("icon", ""))
	set_field_value("DamageField", weapon_data.get("damage", 10))
	set_field_value("AttackSpeedField", weapon_data.get("attack_speed", 1.0))
	set_field_value("RangeField", weapon_data.get("range", 5.0))
	set_field_value("DurabilityField", weapon_data.get("durability", 100))
	set_field_value("MagazineSizeField", weapon_data.get("magazine_size", 1))
	set_field_value("ReloadTimeField", weapon_data.get("reload_time", 2.0))
	
	# Load recipe reference (if using new system)
	var recipe_id = weapon_data.get("recipe_id", "")
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		for i in range(recipe_dropdown.get_item_count()):
			var metadata = recipe_dropdown.get_item_metadata(i)
			if metadata == recipe_id:
				recipe_dropdown.selected = i
				break
	
	# Load compatible ammo types
	clear_ammo_types()
	var compatible_ammo_types = weapon_data.get("compatible_ammo_types", [])
	for ammo_type in compatible_ammo_types:
		add_ammo_type_row(ammo_type)
	
	# Load stats
	clear_stat_rows()
	var stats = weapon_data.get("stats", {})
	for stat_name in stats:
		add_stat_row(stat_name, stats[stat_name])

func save_form_data() -> Dictionary:
	var weapon_data = {
		"name": get_field_value("NameField"),
		"description": get_field_value("DescriptionField"),
		"type": get_field_value("TypeField"),
		"tier": get_field_value("TierField"),
		"icon": get_field_value("IconField"),
		"damage": get_field_value("DamageField"),
		"attack_speed": get_field_value("AttackSpeedField"),
		"range": get_field_value("RangeField"),
		"durability": get_field_value("DurabilityField"),
		"stats": {}
	}
	
	# Validate required fields
	if weapon_data["name"] == "" or weapon_data["name"] == null:
		return {}
	
	# Add ranged weapon specific fields
	var magazine_size = get_field_value("MagazineSizeField")
	var reload_time = get_field_value("ReloadTimeField")
	if magazine_size > 0:
		weapon_data["magazine_size"] = magazine_size
	if reload_time > 0:
		weapon_data["reload_time"] = reload_time
	
	# Get recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown and recipe_dropdown.selected >= 0:
		var recipe_id = recipe_dropdown.get_item_metadata(recipe_dropdown.selected)
		if recipe_id != "":
			weapon_data["recipe_id"] = recipe_id
	
	# Get compatible ammo types
	if ammo_types_container:
		var compatible_ammo_types = []
		for row in ammo_types_container.get_children():
			var ammo_dropdown = row.find_child("AmmoType")
			if ammo_dropdown and ammo_dropdown.selected >= 0:
				compatible_ammo_types.append(ammo_dropdown.get_item_text(ammo_dropdown.selected))
		if compatible_ammo_types.size() > 0:
			weapon_data["compatible_ammo_types"] = compatible_ammo_types
	
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
				weapon_data["stats"][stat_name] = stat_value
	
	return weapon_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("TypeField", "MELEE")
	set_field_value("TierField", 1)
	set_field_value("IconField", "")
	set_field_value("DamageField", 10)
	set_field_value("AttackSpeedField", 1.0)
	set_field_value("RangeField", 5.0)
	set_field_value("DurabilityField", 100)
	set_field_value("MagazineSizeField", 1)
	set_field_value("ReloadTimeField", 2.0)
	
	# Clear recipe reference
	var recipe_dropdown = editor_container.find_child("RecipeField", true, false)
	if recipe_dropdown:
		recipe_dropdown.selected = 0  # Select "(No Recipe)"
	
	# Clear ammo types and stats
	clear_ammo_types()
	clear_stat_rows()