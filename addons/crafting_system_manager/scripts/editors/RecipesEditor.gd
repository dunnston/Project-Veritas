@tool
extends BaseEditor  
class_name RecipesEditor

# Recipes editor - handles CRUD operations for crafting recipes

var ingredients_container: VBoxContainer

func get_data_file_path() -> String:
	return "res://data/recipes.json"

func get_editor_title() -> String:
	return "Recipes Editor"

func create_form_fields(form_container: VBoxContainer) -> void:
	# Recipe ID field (disabled - auto-generated)
	create_text_field(form_container, "Recipe ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Recipe name field  
	create_text_field(form_container, "Recipe Name", "NameField", "Recipe Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 60)
	
	# Craft time field
	create_number_field(form_container, "Craft Time (seconds)", "CraftTimeField", 0.1, 3600, 10)
	
	# Required building field
	create_text_field(form_container, "Required Building", "RequiredBuildingField", "workbench")
	
	# Ingredients section
	var ingredients_label = Label.new()
	ingredients_label.text = "Ingredients:"
	ingredients_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(ingredients_label)
	
	var ingredients_scroll = ScrollContainer.new()
	ingredients_scroll.set_custom_minimum_size(Vector2(0, 150))
	ingredients_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	form_container.add_child(ingredients_scroll)
	
	ingredients_container = VBoxContainer.new()
	ingredients_container.name = "IngredientsContainer"
	ingredients_scroll.add_child(ingredients_container)
	
	var add_ingredient_btn = Button.new()
	add_ingredient_btn.text = "Add Ingredient"
	add_ingredient_btn.pressed.connect(_on_add_ingredient_pressed)
	form_container.add_child(add_ingredient_btn)
	
	# Output section
	var output_label = Label.new()
	output_label.text = "Output:"
	output_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(output_label)
	
	var output_container = HBoxContainer.new()
	form_container.add_child(output_container)
	
	# Output item dropdown
	var output_dropdown = OptionButton.new()
	output_dropdown.name = "OutputDropdown"
	populate_output_dropdown(output_dropdown)
	output_container.add_child(output_dropdown)
	
	# Output amount
	var output_amount = SpinBox.new()
	output_amount.name = "OutputAmountField"
	output_amount.min_value = 1
	output_amount.max_value = 999
	output_amount.value = 1
	output_amount.set_custom_minimum_size(Vector2(80, 0))
	output_container.add_child(output_amount)

func populate_output_dropdown(dropdown: OptionButton):
	dropdown.clear()
	var total_items = 0
	
	# Load items from resources.json
	var items_data = {}
	var items_editor = get_parent().get_parent().get_node_or_null("TabContainer/Items")
	
	if items_editor and items_editor.data:
		items_data = items_editor.data
		print("PopulateOutput: Using ItemsEditor data with ", items_data.size(), " items")
	else:
		# Fallback: load items data directly
		var file = FileAccess.open("res://data/resources.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				items_data = json.data
				print("PopulateOutput: Loaded ", items_data.size(), " items from resources.json")
	
	# Add items to dropdown
	for item_id in items_data:
		var item_data = items_data[item_id]
		dropdown.add_item(item_data.get("name", item_id) + " (Item)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "item", "id": item_id})
		total_items += 1
	
	# Load buildings from buildings.json
	var buildings_file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if buildings_file:
		var json_string = buildings_file.get_as_text()
		buildings_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var buildings_data = json.data
			print("PopulateOutput: Loaded ", buildings_data.size(), " buildings from buildings.json")
			for building_id in buildings_data:
				var building_data = buildings_data[building_id]
				dropdown.add_item(building_data.get("name", building_id) + " (Building)", -1)
				dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "building", "id": building_id})
				total_items += 1
	
	# Load equipment from equipment.json
	var equipment_file = FileAccess.open("res://data/equipment.json", FileAccess.READ)
	if equipment_file:
		var json_string = equipment_file.get_as_text()
		equipment_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var equipment_data = json.data
			print("PopulateOutput: Loaded ", equipment_data.size(), " equipment from equipment.json")
			for equipment_id in equipment_data:
				var equipment_item = equipment_data[equipment_id]
				dropdown.add_item(equipment_item.get("name", equipment_id) + " (Equipment)", -1)
				dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "equipment", "id": equipment_id})
				total_items += 1
	
	# Load weapons from weapons.json
	var weapons_file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if weapons_file:
		var json_string = weapons_file.get_as_text()
		weapons_file.close()
		var json = JSON.new()
		if json.parse(json_string) == OK:
			var weapons_data = json.data
			print("PopulateOutput: Loaded ", weapons_data.size(), " weapons from weapons.json")
			for weapon_id in weapons_data:
				var weapon_data = weapons_data[weapon_id]
				dropdown.add_item(weapon_data.get("name", weapon_id) + " (Weapon)", -1)
				dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "weapon", "id": weapon_id})
				total_items += 1
	
	print("PopulateOutput: Added total of ", total_items, " items to dropdown")

func _on_add_ingredient_pressed():
	add_ingredient_row()

func add_ingredient_row(set_ingredient_id: String = "", set_amount: float = 1.0):
	if not ingredients_container:
		return
	
	var row = HBoxContainer.new()
	ingredients_container.add_child(row)
	
	# Ingredient dropdown
	var ingredient_dropdown = OptionButton.new()
	ingredient_dropdown.name = "IngredientDropdown"
	populate_ingredient_dropdown(ingredient_dropdown)
	row.add_child(ingredient_dropdown)
	
	# Set the ingredient if specified
	if set_ingredient_id != "":
		print("AddIngredientRow: Setting ingredient to: ", set_ingredient_id)
		var found = false
		for i in range(ingredient_dropdown.get_item_count()):
			var metadata = ingredient_dropdown.get_item_metadata(i)
			if metadata and metadata.has("id") and metadata["id"] == set_ingredient_id:
				ingredient_dropdown.selected = i
				found = true
				print("AddIngredientRow: Found ", set_ingredient_id, " at index ", i)
				break
		if not found:
			print("AddIngredientRow: WARNING - Could not find ingredient: ", set_ingredient_id)
	
	# Amount spinner
	var amount_spin = SpinBox.new()
	amount_spin.name = "IngredientAmount"
	amount_spin.min_value = 1
	amount_spin.max_value = 999
	amount_spin.value = set_amount
	amount_spin.set_custom_minimum_size(Vector2(80, 0))
	row.add_child(amount_spin)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.set_custom_minimum_size(Vector2(30, 0))
	remove_btn.pressed.connect(_on_remove_ingredient_pressed.bind(row))
	row.add_child(remove_btn)

func populate_ingredient_dropdown(dropdown: OptionButton):
	dropdown.clear()
	print("PopulateIngredient: Starting dropdown population...")
	
	# Get items data (same as output dropdown)
	var items_data = {}
	var items_editor = get_parent().get_parent().get_node_or_null("TabContainer/Items")
	print("PopulateIngredient: Items editor found: ", items_editor != null)
	
	if items_editor and items_editor.data:
		items_data = items_editor.data
		print("PopulateIngredient: Using ItemsEditor data with ", items_data.size(), " items")
	else:
		# Fallback: load items data directly
		print("PopulateIngredient: Using fallback - loading from resources.json")
		var file = FileAccess.open("res://data/resources.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				items_data = json.data
				print("PopulateIngredient: Loaded ", items_data.size(), " items from JSON")
			else:
				print("PopulateIngredient: ERROR - Failed to parse JSON")
		else:
			print("PopulateIngredient: ERROR - Could not open resources.json")
	
	# Add items to dropdown - use same metadata structure as output
	for item_id in items_data:
		var item_data = items_data[item_id]
		dropdown.add_item(item_data.get("name", item_id), -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "item", "id": item_id})
	
	print("PopulateIngredient: Added ", dropdown.get_item_count(), " items to dropdown")

func _on_remove_ingredient_pressed(row: Control):
	row.queue_free()

func load_item_into_form(item_id: String) -> void:
	var recipe_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", recipe_data.get("name", ""))
	set_field_value("DescriptionField", recipe_data.get("description", ""))
	set_field_value("CraftTimeField", recipe_data.get("craft_time", 10))
	set_field_value("RequiredBuildingField", recipe_data.get("requires_building", "workbench"))
	
	# Load output
	var output = recipe_data.get("output", {})
	print("LoadRecipe: Output data: ", output)
	if not output.is_empty():
		var output_dropdown = editor_container.find_child("OutputDropdown", true, false)
		var output_amount_field = editor_container.find_child("OutputAmountField", true, false)
		
		if output_dropdown and output_amount_field:
			var output_id = output.keys()[0]
			print("LoadRecipe: Looking for output ID: ", output_id)
			
			# Set output item
			var found = false
			for i in range(output_dropdown.get_item_count()):
				var metadata = output_dropdown.get_item_metadata(i)
				print("LoadRecipe: Checking output item ", i, " metadata: ", metadata)
				if metadata and metadata.has("id") and metadata["id"] == output_id:
					output_dropdown.selected = i
					found = true
					print("LoadRecipe: Found output match at index ", i)
					break
			
			if not found:
				print("LoadRecipe: WARNING - Could not find output ID: ", output_id)
			
			# Set output amount
			output_amount_field.value = output.values()[0]
			print("LoadRecipe: Set output amount to: ", output.values()[0])
	
	# Load ingredients
	clear_ingredients()
	var ingredients = recipe_data.get("ingredients", {})
	print("LoadRecipe: Loading ", ingredients.size(), " ingredients for recipe: ", item_id)
	for ingredient_id in ingredients:
		print("LoadRecipe: Processing ingredient: ", ingredient_id, " amount: ", ingredients[ingredient_id])
		# Pass the ingredient ID and amount directly to add_ingredient_row
		add_ingredient_row(ingredient_id, ingredients[ingredient_id])

func _set_ingredient_values(ingredient_id: String, amount: float):
	if not ingredients_container:
		print("SetIngredient: No ingredients container")
		return
	
	var rows = ingredients_container.get_children()
	if rows.size() == 0:
		print("SetIngredient: No ingredient rows")
		return
	
	var last_row = rows[-1]
	var dropdown = last_row.find_child("IngredientDropdown")
	var amount_spin = last_row.find_child("IngredientAmount")
	
	print("SetIngredient: Looking for ingredient_id: ", ingredient_id, " in dropdown with ", dropdown.get_item_count() if dropdown else 0, " items")
	
	if dropdown:
		var found = false
		for i in range(dropdown.get_item_count()):
			var metadata = dropdown.get_item_metadata(i)
			print("SetIngredient: Item ", i, " metadata: ", metadata)
			if metadata and metadata.has("id") and metadata["id"] == ingredient_id:
				dropdown.selected = i
				found = true
				print("SetIngredient: Found match at index ", i)
				break
		if not found:
			print("SetIngredient: WARNING - No match found for ingredient_id: ", ingredient_id)
	
	if amount_spin:
		amount_spin.value = amount
		print("SetIngredient: Set amount to: ", amount)

func clear_ingredients():
	if not ingredients_container:
		return
	for child in ingredients_container.get_children():
		child.queue_free()

func save_form_data() -> Dictionary:
	var recipe_data = {
		"name": get_field_value("NameField"),
		"description": get_field_value("DescriptionField"),
		"craft_time": get_field_value("CraftTimeField"),
		"requires_building": get_field_value("RequiredBuildingField"),
		"ingredients": {},
		"output": {}
	}
	
	# Validate required fields
	if recipe_data["name"] == "" or recipe_data["name"] == null:
		print("Recipe name cannot be empty")
		return {}
	
	# Get ingredients
	if ingredients_container:
		for row in ingredients_container.get_children():
			var dropdown = row.find_child("IngredientDropdown")
			var amount_spin = row.find_child("IngredientAmount")
			
			if dropdown and amount_spin and dropdown.selected >= 0:
				var metadata = dropdown.get_item_metadata(dropdown.selected)
				if metadata and metadata.has("id"):
					var ingredient_id = metadata["id"]
					recipe_data["ingredients"][ingredient_id] = amount_spin.value
	
	# Get output
	var output_dropdown = editor_container.find_child("OutputDropdown", true, false)
	var output_amount_field = editor_container.find_child("OutputAmountField", true, false)
	
	if output_dropdown and output_amount_field and output_dropdown.selected >= 0:
		var metadata = output_dropdown.get_item_metadata(output_dropdown.selected)
		if metadata and metadata.has("id"):
			recipe_data["output"][metadata["id"]] = output_amount_field.value
	
	return recipe_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("CraftTimeField", 10)
	set_field_value("RequiredBuildingField", "workbench")
	
	# Clear output
	var output_dropdown = editor_container.find_child("OutputDropdown", true, false)
	var output_amount_field = editor_container.find_child("OutputAmountField", true, false)
	if output_dropdown:
		output_dropdown.selected = -1
	if output_amount_field:
		output_amount_field.value = 1
	
	# Clear ingredients
	clear_ingredients()