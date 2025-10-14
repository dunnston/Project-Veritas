@tool
extends Control

# Data storage
var resources_data: Dictionary = {}
var recipes_data: Dictionary = {}
var buildings_data: Dictionary = {}
var equipment_data: Dictionary = {}
var equipment_slots_data: Dictionary = {}
var weapons_data: Dictionary = {}
var ammo_data: Dictionary = {}

# Currently selected items
var selected_item_id: String = ""
var selected_recipe_id: String = ""
var selected_building_id: String = ""
var selected_equipment_id: String = ""
var selected_weapon_id: String = ""

# UI references
var items_list: VBoxContainer
var recipes_list: VBoxContainer
var buildings_list: VBoxContainer
var equipment_list: VBoxContainer
var weapons_list: VBoxContainer

func _ready():
	print("FullDock: Initializing with basic functionality...")
	
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainContainer"
	add_child(main_vbox)
	
	var title = Label.new()
	title.text = "Neon Wasteland Crafting Manager"
	title.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title)
	
	# Tab container
	var tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	# Create tabs
	create_items_tab(tab_container)
	create_recipes_tab(tab_container)
	create_buildings_tab(tab_container)
	create_equipment_tab(tab_container)
	create_weapons_tab(tab_container)
	
	# Save button
	var save_button = Button.new()
	save_button.text = "Save All Changes"
	save_button.pressed.connect(_on_save_pressed)
	main_vbox.add_child(save_button)
	
	# Load data
	load_items()
	load_recipes()
	load_buildings()
	load_equipment()
	load_weapons()
	
	print("FullDock: Basic version loaded successfully")
	
	# Populate dropdowns after all data is loaded
	populate_recipe_dropdowns()

# Callback functions - defined here so they can be referenced in UI creation
func _on_save_pressed():
	save_all_data()

# Item editor callbacks
func _on_item_selected(item_id: String):
	selected_item_id = item_id
	load_item_into_editor(item_id)
	
func _on_add_item_pressed():
	clear_item_editor()
	selected_item_id = ""
	
func _on_edit_item_pressed():
	if selected_item_id == "":
		print("No item selected for editing")
		return
	load_item_into_editor(selected_item_id)
	
func _on_delete_item_pressed():
	if selected_item_id == "":
		print("No item selected for deletion")
		return
	if resources_data.has(selected_item_id):
		resources_data.erase(selected_item_id)
		update_item_list()
		clear_item_editor()
		selected_item_id = ""
		print("Deleted item: ", selected_item_id)
	
func _on_save_item_pressed():
	save_current_item()

# Recipe editor callbacks
func _on_recipe_selected(recipe_id: String):
	selected_recipe_id = recipe_id
	load_recipe_into_editor(recipe_id)
	
func _on_add_recipe_pressed():
	clear_recipe_editor()
	selected_recipe_id = ""
	
func _on_edit_recipe_pressed():
	if selected_recipe_id == "":
		print("No recipe selected for editing")
		return
	load_recipe_into_editor(selected_recipe_id)
	
func _on_delete_recipe_pressed():
	if selected_recipe_id == "":
		print("No recipe selected for deletion")
		return
	if recipes_data.has(selected_recipe_id):
		recipes_data.erase(selected_recipe_id)
		update_recipes_list()
		clear_recipe_editor()
		selected_recipe_id = ""
		print("Deleted recipe: ", selected_recipe_id)
	
func _on_save_recipe_pressed():
	save_current_recipe()

# Building editor callbacks  
func _on_building_selected(building_id: String):
	selected_building_id = building_id
	load_building_into_editor(building_id)
	
func _on_add_building_pressed():
	clear_building_editor()
	selected_building_id = ""
	
func _on_edit_building_pressed():
	if selected_building_id == "":
		print("No building selected for editing")
		return
	load_building_into_editor(selected_building_id)
	
func _on_delete_building_pressed():
	if selected_building_id == "":
		print("No building selected for deletion")
		return
	if buildings_data.has(selected_building_id):
		buildings_data.erase(selected_building_id)
		update_buildings_list()
		clear_building_editor()
		selected_building_id = ""
		print("Deleted building: ", selected_building_id)
	
func _on_save_building_pressed():
	save_current_building()

# Equipment editor callbacks
func _on_equipment_selected(equipment_id: String):
	selected_equipment_id = equipment_id
	load_equipment_into_editor(equipment_id)
	
func _on_add_equipment_pressed():
	clear_equipment_editor()
	selected_equipment_id = ""
	
func _on_edit_equipment_pressed():
	if selected_equipment_id == "":
		print("No equipment selected for editing")
		return
	load_equipment_into_editor(selected_equipment_id)
	
func _on_delete_equipment_pressed():
	if selected_equipment_id == "":
		print("No equipment selected for deletion")
		return
	if equipment_data.has(selected_equipment_id):
		equipment_data.erase(selected_equipment_id)
		update_equipment_list()
		clear_equipment_editor()
		selected_equipment_id = ""
		print("Deleted equipment: ", selected_equipment_id)
	
func _on_save_equipment_pressed():
	save_current_equipment()

# Weapon editor callbacks  
func _on_weapon_selected(weapon_id: String):
	selected_weapon_id = weapon_id
	load_weapon_into_editor(weapon_id)
	
func _on_add_weapon_pressed():
	clear_weapon_editor()
	selected_weapon_id = ""
	
func _on_edit_weapon_pressed():
	if selected_weapon_id == "":
		print("No weapon selected for editing")
		return
	load_weapon_into_editor(selected_weapon_id)
	
func _on_delete_weapon_pressed():
	if selected_weapon_id == "":
		print("No weapon selected for deletion")
		return
	if weapons_data.has(selected_weapon_id):
		weapons_data.erase(selected_weapon_id)
		update_weapons_list()
		clear_weapon_editor()
		selected_weapon_id = ""
		print("Deleted weapon: ", selected_weapon_id)
	
func _on_save_weapon_pressed():
	save_current_weapon()

func _on_add_ingredient_pressed():
	add_ingredient_row()

# Forward declare functions that are called by UI elements
func add_ingredient_row():
	var editor = get_node("MainContainer/TabContainer/Recipes/RecipeEditor")
	var ingredients_container = editor.find_child("IngredientsContainer")
	
	if not ingredients_container:
		return
	
	var row = HBoxContainer.new()
	ingredients_container.add_child(row)
	
	# Ingredient dropdown
	var ingredient_dropdown = OptionButton.new()
	ingredient_dropdown.name = "IngredientDropdown"
	populate_ingredient_dropdown(ingredient_dropdown)
	row.add_child(ingredient_dropdown)
	
	# Amount spinner
	var amount_spin = SpinBox.new()
	amount_spin.name = "IngredientAmount"
	amount_spin.min_value = 1
	amount_spin.max_value = 999
	amount_spin.value = 1
	amount_spin.set_custom_minimum_size(Vector2(80, 0))
	row.add_child(amount_spin)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.set_custom_minimum_size(Vector2(30, 0))
	remove_btn.pressed.connect(_on_remove_ingredient_pressed.bind(row))
	row.add_child(remove_btn)

func _on_remove_ingredient_pressed(row: Control):
	row.queue_free()

func populate_ingredient_dropdown(dropdown: OptionButton):
	dropdown.clear()
	
	# Add items (most common ingredients)
	for item_id in resources_data:
		var item_data = resources_data[item_id]
		dropdown.add_item(item_data.get("name", item_id), -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, item_id)

func populate_output_dropdown(dropdown: OptionButton):
	dropdown.clear()
	
	# Add items
	for item_id in resources_data:
		var item_data = resources_data[item_id]
		dropdown.add_item(item_data.get("name", item_id) + " (Item)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "item", "id": item_id})
	
	# Add buildings
	for building_id in buildings_data:
		var building_data = buildings_data[building_id]
		dropdown.add_item(building_data.get("name", building_id) + " (Building)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "building", "id": building_id})
	
	# Add weapons
	for weapon_id in weapons_data:
		var weapon_data = weapons_data[weapon_id]
		dropdown.add_item(weapon_data.get("name", weapon_id) + " (Weapon)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "weapon", "id": weapon_id})
	
	# Add ammo
	for ammo_id in ammo_data:
		var ammo_item = ammo_data[ammo_id]
		dropdown.add_item(ammo_item.get("name", ammo_id) + " (Ammo)", -1)
		dropdown.set_item_metadata(dropdown.get_item_count() - 1, {"type": "ammo", "id": ammo_id})

func populate_recipe_dropdowns():
	var editor = get_node_or_null("MainContainer/TabContainer/Recipes/RecipeEditor")
	if not editor:
		return
		
	var output_dropdown = editor.find_child("RecipeOutputDropdown")
	if output_dropdown:
		populate_output_dropdown(output_dropdown)

func create_items_tab(parent: TabContainer):
	var items_tab = HSplitContainer.new()
	items_tab.name = "Items"
	parent.add_child(items_tab)
	
	# Left panel - items list
	var left_panel = VBoxContainer.new()
	left_panel.name = "ItemsList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	items_tab.add_child(left_panel)
	
	# Items list scroll
	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(items_scroll)
	
	items_list = VBoxContainer.new()
	items_list.name = "ItemsList"
	items_scroll.add_child(items_list)
	
	# Right panel - item editor
	var right_panel = VBoxContainer.new()
	right_panel.name = "ItemEditor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	items_tab.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = "Item Editor"
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_item_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_item_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_item_pressed)
	buttons_container.add_child(delete_button)
	
	# Item form
	var form_container = VBoxContainer.new()
	right_panel.add_child(form_container)
	
	# ID field
	var id_label = Label.new()
	id_label.text = "Item ID:"
	form_container.add_child(id_label)
	var item_id_field = LineEdit.new()
	item_id_field.name = "ItemIdField"
	form_container.add_child(item_id_field)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Display Name:"
	form_container.add_child(name_label)
	var item_name_field = LineEdit.new()
	item_name_field.name = "ItemNameField"
	form_container.add_child(item_name_field)
	
	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	form_container.add_child(desc_label)
	var item_desc_field = TextEdit.new()
	item_desc_field.name = "ItemDescField"
	item_desc_field.set_custom_minimum_size(Vector2(0, 80))
	form_container.add_child(item_desc_field)
	
	# Category field
	var category_label = Label.new()
	category_label.text = "Category:"
	form_container.add_child(category_label)
	var item_category_field = LineEdit.new()
	item_category_field.name = "ItemCategoryField"
	form_container.add_child(item_category_field)
	
	# Stack size field
	var stack_label = Label.new()
	stack_label.text = "Stack Size:"
	form_container.add_child(stack_label)
	var item_stack_field = SpinBox.new()
	item_stack_field.name = "ItemStackField"
	item_stack_field.min_value = 1
	item_stack_field.max_value = 999
	item_stack_field.value = 1
	form_container.add_child(item_stack_field)
	
	# Save button
	var save_item_button = Button.new()
	save_item_button.text = "Save Item Changes"
	save_item_button.pressed.connect(_on_save_item_pressed)
	form_container.add_child(save_item_button)

func create_recipes_tab(parent: TabContainer):
	var recipes_tab = HSplitContainer.new()
	recipes_tab.name = "Recipes"
	parent.add_child(recipes_tab)
	
	# Left panel - recipes list
	var left_panel = VBoxContainer.new()
	left_panel.name = "RecipesList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	recipes_tab.add_child(left_panel)
	
	# Recipes list scroll
	var recipes_scroll = ScrollContainer.new()
	recipes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(recipes_scroll)
	
	recipes_list = VBoxContainer.new()
	recipes_list.name = "RecipesList"
	recipes_scroll.add_child(recipes_list)
	
	# Right panel - recipe editor
	var right_panel = VBoxContainer.new()
	right_panel.name = "RecipeEditor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	recipes_tab.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = "Recipe Editor"
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_recipe_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_recipe_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_recipe_pressed)
	buttons_container.add_child(delete_button)
	
	# Recipe form
	var form_container = VBoxContainer.new()
	right_panel.add_child(form_container)
	
	# ID field
	var id_label = Label.new()
	id_label.text = "Recipe ID:"
	form_container.add_child(id_label)
	var recipe_id_field = LineEdit.new()
	recipe_id_field.name = "RecipeIdField"
	form_container.add_child(recipe_id_field)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Display Name:"
	form_container.add_child(name_label)
	var recipe_name_field = LineEdit.new()
	recipe_name_field.name = "RecipeNameField"
	form_container.add_child(recipe_name_field)
	
	# Category field
	var category_label = Label.new()
	category_label.text = "Category:"
	form_container.add_child(category_label)
	var recipe_category_field = LineEdit.new()
	recipe_category_field.name = "RecipeCategoryField"
	form_container.add_child(recipe_category_field)
	
	# Craft time field
	var craft_time_label = Label.new()
	craft_time_label.text = "Craft Time (seconds):"
	form_container.add_child(craft_time_label)
	var recipe_craft_time_field = SpinBox.new()
	recipe_craft_time_field.name = "RecipeCraftTimeField"
	recipe_craft_time_field.min_value = 0.1
	recipe_craft_time_field.max_value = 999
	recipe_craft_time_field.step = 0.1
	recipe_craft_time_field.value = 1.0
	form_container.add_child(recipe_craft_time_field)
	
	# Ingredients section
	var ingredients_label = Label.new()
	ingredients_label.text = "Ingredients:"
	form_container.add_child(ingredients_label)
	
	# Ingredients container (scrollable for multiple ingredients)
	var ingredients_scroll = ScrollContainer.new()
	ingredients_scroll.name = "IngredientsScroll"
	ingredients_scroll.set_custom_minimum_size(Vector2(0, 120))
	form_container.add_child(ingredients_scroll)
	
	var ingredients_container = VBoxContainer.new()
	ingredients_container.name = "IngredientsContainer"
	ingredients_scroll.add_child(ingredients_container)
	
	# Add ingredient button
	var add_ingredient_btn = Button.new()
	add_ingredient_btn.text = "Add Ingredient"
	add_ingredient_btn.pressed.connect(_on_add_ingredient_pressed)
	form_container.add_child(add_ingredient_btn)
	
	# Output section
	var output_label = Label.new()
	output_label.text = "Output:"
	form_container.add_child(output_label)
	
	var output_container = HBoxContainer.new()
	form_container.add_child(output_container)
	
	var output_dropdown = OptionButton.new()
	output_dropdown.name = "RecipeOutputDropdown"
	output_container.add_child(output_dropdown)
	
	var output_amount = SpinBox.new()
	output_amount.name = "RecipeOutputAmount"
	output_amount.min_value = 1
	output_amount.max_value = 999
	output_amount.value = 1
	output_container.add_child(output_amount)
	
	# Save button
	var save_recipe_button = Button.new()
	save_recipe_button.text = "Save Recipe Changes"
	save_recipe_button.pressed.connect(_on_save_recipe_pressed)
	form_container.add_child(save_recipe_button)

func create_buildings_tab(parent: TabContainer):
	var buildings_tab = HSplitContainer.new()
	buildings_tab.name = "Buildings"
	parent.add_child(buildings_tab)
	
	# Left panel - buildings list
	var left_panel = VBoxContainer.new()
	left_panel.name = "BuildingsList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	buildings_tab.add_child(left_panel)
	
	# Buildings list scroll
	var buildings_scroll = ScrollContainer.new()
	buildings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(buildings_scroll)
	
	buildings_list = VBoxContainer.new()
	buildings_list.name = "BuildingsList"
	buildings_scroll.add_child(buildings_list)
	
	# Right panel - building editor
	var right_panel = VBoxContainer.new()
	right_panel.name = "BuildingEditor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	buildings_tab.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = "Building Editor"
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_building_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_building_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_building_pressed)
	buttons_container.add_child(delete_button)
	
	# Building form
	var form_container = VBoxContainer.new()
	right_panel.add_child(form_container)
	
	# ID field
	var id_label = Label.new()
	id_label.text = "Building ID:"
	form_container.add_child(id_label)
	var building_id_field = LineEdit.new()
	building_id_field.name = "BuildingIdField"
	form_container.add_child(building_id_field)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Display Name:"
	form_container.add_child(name_label)
	var building_name_field = LineEdit.new()
	building_name_field.name = "BuildingNameField"
	form_container.add_child(building_name_field)
	
	# Category field
	var category_label = Label.new()
	category_label.text = "Category:"
	form_container.add_child(category_label)
	var building_category_field = LineEdit.new()
	building_category_field.name = "BuildingCategoryField"
	form_container.add_child(building_category_field)
	
	# Size fields
	var size_label = Label.new()
	size_label.text = "Size (width x height):"
	form_container.add_child(size_label)
	
	var size_container = HBoxContainer.new()
	form_container.add_child(size_container)
	
	var size_width_field = SpinBox.new()
	size_width_field.name = "BuildingSizeWidthField"
	size_width_field.min_value = 1
	size_width_field.max_value = 10
	size_width_field.value = 1
	size_container.add_child(size_width_field)
	
	var x_label = Label.new()
	x_label.text = " x "
	size_container.add_child(x_label)
	
	var size_height_field = SpinBox.new()
	size_height_field.name = "BuildingSizeHeightField"
	size_height_field.min_value = 1
	size_height_field.max_value = 10
	size_height_field.value = 1
	size_container.add_child(size_height_field)
	
	# Health field
	var health_label = Label.new()
	health_label.text = "Max Health:"
	form_container.add_child(health_label)
	var building_health_field = SpinBox.new()
	building_health_field.name = "BuildingHealthField"
	building_health_field.min_value = 1
	building_health_field.max_value = 999
	building_health_field.value = 50
	form_container.add_child(building_health_field)
	
	# Cost section
	var cost_label = Label.new()
	cost_label.text = "Cost (ID:Amount pairs, one per line):"
	form_container.add_child(cost_label)
	var building_cost_field = TextEdit.new()
	building_cost_field.name = "BuildingCostField"
	building_cost_field.set_custom_minimum_size(Vector2(0, 80))
	building_cost_field.placeholder_text = "SCRAP_METAL:5\nELECTRONICS:2"
	form_container.add_child(building_cost_field)
	
	# Save button
	var save_building_button = Button.new()
	save_building_button.text = "Save Building Changes"
	save_building_button.pressed.connect(_on_save_building_pressed)
	form_container.add_child(save_building_button)

func create_equipment_tab(parent: TabContainer):
	var equipment_tab = HSplitContainer.new()
	equipment_tab.name = "Equipment"
	parent.add_child(equipment_tab)
	
	# Left panel - equipment list
	var left_panel = VBoxContainer.new()
	left_panel.name = "EquipmentList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	equipment_tab.add_child(left_panel)
	
	# Equipment list scroll
	var equipment_scroll = ScrollContainer.new()
	equipment_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(equipment_scroll)
	
	equipment_list = VBoxContainer.new()
	equipment_list.name = "EquipmentList"
	equipment_scroll.add_child(equipment_list)
	
	# Right panel - equipment editor
	var right_panel = VBoxContainer.new()
	right_panel.name = "EquipmentEditor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	equipment_tab.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = "Equipment Editor"
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_equipment_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_equipment_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_equipment_pressed)
	buttons_container.add_child(delete_button)
	
	# Equipment form
	var form_container = VBoxContainer.new()
	right_panel.add_child(form_container)
	
	# ID field
	var id_label = Label.new()
	id_label.text = "Equipment ID:"
	form_container.add_child(id_label)
	var equipment_id_field = LineEdit.new()
	equipment_id_field.name = "EquipmentIdField"
	form_container.add_child(equipment_id_field)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Display Name:"
	form_container.add_child(name_label)
	var equipment_name_field = LineEdit.new()
	equipment_name_field.name = "EquipmentNameField"
	form_container.add_child(equipment_name_field)
	
	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	form_container.add_child(desc_label)
	var equipment_desc_field = TextEdit.new()
	equipment_desc_field.name = "EquipmentDescField"
	equipment_desc_field.set_custom_minimum_size(Vector2(0, 60))
	form_container.add_child(equipment_desc_field)
	
	# Slot dropdown
	var slot_label = Label.new()
	slot_label.text = "Equipment Slot:"
	form_container.add_child(slot_label)
	var equipment_slot_field = OptionButton.new()
	equipment_slot_field.name = "EquipmentSlotField"
	# Populate with equipment slots
	for slot_id in ["HEAD", "CHEST", "PANTS", "FEET", "BACKPACK", "TRINKET_1", "TRINKET_2", "TRINKET_3", "PRIMARY_WEAPON", "SECONDARY_WEAPON"]:
		equipment_slot_field.add_item(slot_id)
	form_container.add_child(equipment_slot_field)
	
	# Tier field
	var tier_label = Label.new()
	tier_label.text = "Tier:"
	form_container.add_child(tier_label)
	var equipment_tier_field = SpinBox.new()
	equipment_tier_field.name = "EquipmentTierField"
	equipment_tier_field.min_value = 1
	equipment_tier_field.max_value = 5
	equipment_tier_field.value = 1
	form_container.add_child(equipment_tier_field)
	
	# Icon field
	var icon_label = Label.new()
	icon_label.text = "Icon:"
	form_container.add_child(icon_label)
	var equipment_icon_field = LineEdit.new()
	equipment_icon_field.name = "EquipmentIconField"
	form_container.add_child(equipment_icon_field)
	
	# Stats section
	var stats_label = Label.new()
	stats_label.text = "Stats:"
	stats_label.add_theme_font_size_override("font_size", 12)
	form_container.add_child(stats_label)
	
	# Stats container
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	form_container.add_child(stats_container)
	
	# Common stats
	var common_stats = ["defense", "inventory_slots", "movement_speed", "max_stamina", "stamina_regen", "radiation_resist", "oxygen_efficiency"]
	for stat in common_stats:
		var stat_row = HBoxContainer.new()
		stats_container.add_child(stat_row)
		
		var stat_label_field = Label.new()
		stat_label_field.text = stat.capitalize() + ":"
		stat_label_field.set_custom_minimum_size(Vector2(150, 0))
		stat_row.add_child(stat_label_field)
		
		var stat_value = SpinBox.new()
		stat_value.name = stat.capitalize() + "StatField"
		stat_value.min_value = -999
		stat_value.max_value = 999
		stat_value.step = 0.1
		stat_value.value = 0
		stat_value.set_custom_minimum_size(Vector2(80, 0))
		stat_row.add_child(stat_value)
	
	# Save button
	var save_button = Button.new()
	save_button.text = "Save Equipment"
	save_button.pressed.connect(_on_save_equipment_pressed)
	form_container.add_child(save_button)

func create_weapons_tab(parent: TabContainer):
	var weapons_tab = HSplitContainer.new()
	weapons_tab.name = "Weapons"
	parent.add_child(weapons_tab)
	
	# Left panel - weapons list
	var left_panel = VBoxContainer.new()
	left_panel.name = "WeaponsList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	weapons_tab.add_child(left_panel)
	
	# Weapons list scroll
	var weapons_scroll = ScrollContainer.new()
	weapons_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(weapons_scroll)
	
	weapons_list = VBoxContainer.new()
	weapons_list.name = "WeaponsList"
	weapons_scroll.add_child(weapons_list)
	
	# Right panel - weapon editor
	var right_panel = VBoxContainer.new()
	right_panel.name = "WeaponEditor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	weapons_tab.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = "Weapon Editor"
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_weapon_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_weapon_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_weapon_pressed)
	buttons_container.add_child(delete_button)
	
	# Weapon form
	var form_container = VBoxContainer.new()
	right_panel.add_child(form_container)
	
	# ID field
	var id_label = Label.new()
	id_label.text = "Weapon ID:"
	form_container.add_child(id_label)
	var weapon_id_field = LineEdit.new()
	weapon_id_field.name = "WeaponIdField"
	form_container.add_child(weapon_id_field)
	
	# Name field
	var name_label = Label.new()
	name_label.text = "Display Name:"
	form_container.add_child(name_label)
	var weapon_name_field = LineEdit.new()
	weapon_name_field.name = "WeaponNameField"
	form_container.add_child(weapon_name_field)
	
	# Description field
	var desc_label = Label.new()
	desc_label.text = "Description:"
	form_container.add_child(desc_label)
	var weapon_desc_field = TextEdit.new()
	weapon_desc_field.name = "WeaponDescField"
	weapon_desc_field.set_custom_minimum_size(Vector2(0, 60))
	form_container.add_child(weapon_desc_field)
	
	# Weapon type dropdown
	var type_label = Label.new()
	type_label.text = "Weapon Type:"
	form_container.add_child(type_label)
	var weapon_type_field = OptionButton.new()
	weapon_type_field.name = "WeaponTypeField"
	# Populate with weapon types
	for weapon_type in ["melee", "ranged", "explosive", "energy", "tool"]:
		weapon_type_field.add_item(weapon_type.capitalize())
	form_container.add_child(weapon_type_field)
	
	# Damage field
	var damage_label = Label.new()
	damage_label.text = "Damage:"
	form_container.add_child(damage_label)
	var weapon_damage_field = SpinBox.new()
	weapon_damage_field.name = "WeaponDamageField"
	weapon_damage_field.min_value = 0
	weapon_damage_field.max_value = 999
	weapon_damage_field.value = 10
	form_container.add_child(weapon_damage_field)
	
	# Fire rate field
	var fire_rate_label = Label.new()
	fire_rate_label.text = "Fire Rate:"
	form_container.add_child(fire_rate_label)
	var weapon_fire_rate_field = SpinBox.new()
	weapon_fire_rate_field.name = "WeaponFireRateField"
	weapon_fire_rate_field.min_value = 0.1
	weapon_fire_rate_field.max_value = 10.0
	weapon_fire_rate_field.step = 0.1
	weapon_fire_rate_field.value = 1.0
	form_container.add_child(weapon_fire_rate_field)
	
	# Range field
	var range_label = Label.new()
	range_label.text = "Range:"
	form_container.add_child(range_label)
	var weapon_range_field = SpinBox.new()
	weapon_range_field.name = "WeaponRangeField"
	weapon_range_field.min_value = 0
	weapon_range_field.max_value = 1000
	weapon_range_field.value = 100
	form_container.add_child(weapon_range_field)
	
	# Ammo type field
	var ammo_label = Label.new()
	ammo_label.text = "Ammo Type:"
	form_container.add_child(ammo_label)
	var weapon_ammo_field = LineEdit.new()
	weapon_ammo_field.name = "WeaponAmmoField"
	form_container.add_child(weapon_ammo_field)
	
	# Icon field
	var icon_label = Label.new()
	icon_label.text = "Icon:"
	form_container.add_child(icon_label)
	var weapon_icon_field = LineEdit.new()
	weapon_icon_field.name = "WeaponIconField"
	form_container.add_child(weapon_icon_field)
	
	# Save button
	var save_button = Button.new()
	save_button.text = "Save Weapon"
	save_button.pressed.connect(_on_save_weapon_pressed)
	form_container.add_child(save_button)

func load_items():
	print("Loading items...")
	var file = FileAccess.open("res://data/resources.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			# resources.json has items at the root level, not under "resources" key
			resources_data = data
			print("Loaded ", resources_data.size(), " items")
			update_item_list()
		else:
			print("Failed to parse resources.json")
	else:
		print("Failed to open resources.json")

func load_recipes():
	print("Loading recipes...")
	var file = FileAccess.open("res://data/recipes.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			recipes_data = data
			print("Loaded ", recipes_data.size(), " recipes")
			update_recipes_list()
		else:
			print("Failed to parse recipes.json")
	else:
		print("Failed to open recipes.json")

func load_buildings():
	print("Loading buildings...")
	var file = FileAccess.open("res://data/buildings.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			buildings_data = data
			print("Loaded ", buildings_data.size(), " buildings")
			update_buildings_list()
		else:
			print("Failed to parse buildings.json")
	else:
		print("Failed to open buildings.json")

func load_equipment():
	print("Loading equipment...")
	var file = FileAccess.open("res://data/equipment.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("equipment_items"):
				equipment_data = data.equipment_items
				print("Loaded ", equipment_data.size(), " equipment items")
				update_equipment_list()
			if data.has("equipment_slots"):
				equipment_slots_data = data.equipment_slots
				print("Loaded ", equipment_slots_data.size(), " equipment slots")
		else:
			print("Failed to parse equipment.json")
	else:
		print("Failed to open equipment.json")

func load_weapons():
	print("Loading weapons...")
	var file = FileAccess.open("res://data/weapons.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var data = json.data
			if data.has("weapons"):
				weapons_data = data.weapons
				print("Loaded ", weapons_data.size(), " weapons")
				update_weapons_list()
			if data.has("ammo_items"):
				ammo_data = data.ammo_items
				print("Loaded ", ammo_data.size(), " ammo items")
		else:
			print("Failed to parse weapons.json")
	else:
		print("Failed to open weapons.json")

func update_item_list():
	if not items_list:
		return
	
	for child in items_list.get_children():
		child.queue_free()
	
	for item_id in resources_data:
		var item_data = resources_data[item_id]
		var btn = Button.new()
		btn.text = item_data.get("name", item_id)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_item_selected.bind(item_id))
		items_list.add_child(btn)

func update_recipes_list():
	if not recipes_list:
		return
	
	for child in recipes_list.get_children():
		child.queue_free()
	
	for recipe_id in recipes_data:
		var recipe_data = recipes_data[recipe_id]
		var btn = Button.new()
		btn.text = recipe_data.get("name", recipe_id) + " (" + recipe_data.get("category", "UNKNOWN") + ")"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_recipe_selected.bind(recipe_id))
		recipes_list.add_child(btn)

func update_buildings_list():
	if not buildings_list:
		return
	
	for child in buildings_list.get_children():
		child.queue_free()
	
	for building_id in buildings_data:
		var building_data = buildings_data[building_id]
		var btn = Button.new()
		btn.text = building_data.get("name", building_id) + " (" + building_data.get("category", "UNKNOWN") + ")"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_building_selected.bind(building_id))
		buildings_list.add_child(btn)

func update_equipment_list():
	if not equipment_list:
		return
	
	for child in equipment_list.get_children():
		child.queue_free()
	
	for equipment_id in equipment_data:
		var equipment_data_item = equipment_data[equipment_id]
		var btn = Button.new()
		btn.text = equipment_data_item.get("name", equipment_id) + " (" + equipment_data_item.get("slot", "UNKNOWN") + ")"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		equipment_list.add_child(btn)

func update_weapons_list():
	if not weapons_list:
		return
	
	for child in weapons_list.get_children():
		child.queue_free()
	
	for weapon_id in weapons_data:
		var weapon_data = weapons_data[weapon_id]
		var btn = Button.new()
		btn.text = weapon_data.get("name", weapon_id) + " (" + weapon_data.get("type", "UNKNOWN") + ")"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		weapons_list.add_child(btn)

# Helper functions for editors (moved here to avoid duplicate definitions)
func load_item_into_editor(item_id: String):
	var item_data = resources_data.get(item_id, {})
	var editor = get_node("MainContainer/TabContainer/Items/ItemEditor")
	
	var id_field = editor.find_child("ItemIdField")
	var name_field = editor.find_child("ItemNameField")
	var desc_field = editor.find_child("ItemDescField")
	var category_field = editor.find_child("ItemCategoryField")
	var stack_field = editor.find_child("ItemStackField")
	
	if id_field: id_field.text = item_id
	if name_field: name_field.text = item_data.get("name", "")
	if desc_field: desc_field.text = item_data.get("description", "")
	if category_field: category_field.text = item_data.get("category", "")
	if stack_field: stack_field.value = item_data.get("stack_size", 1)

func clear_item_editor():
	var editor = get_node("MainContainer/TabContainer/Items/ItemEditor")
	
	var id_field = editor.find_child("ItemIdField")
	var name_field = editor.find_child("ItemNameField")
	var desc_field = editor.find_child("ItemDescField")
	var category_field = editor.find_child("ItemCategoryField")
	var stack_field = editor.find_child("ItemStackField")
	
	if id_field: id_field.text = ""
	if name_field: name_field.text = ""
	if desc_field: desc_field.text = ""
	if category_field: category_field.text = ""
	if stack_field: stack_field.value = 1

func save_current_item():
	var editor = get_node("MainContainer/TabContainer/Items/ItemEditor")
	
	var id_field = editor.find_child("ItemIdField")
	var name_field = editor.find_child("ItemNameField")
	var desc_field = editor.find_child("ItemDescField")
	var category_field = editor.find_child("ItemCategoryField")
	var stack_field = editor.find_child("ItemStackField")
	
	if not id_field or id_field.text.strip_edges() == "":
		print("Item ID is required")
		return
		
	var item_id = id_field.text.strip_edges()
	var item_data = {
		"name": name_field.text if name_field else "",
		"description": desc_field.text if desc_field else "",
		"category": category_field.text if category_field else "",
		"stack_size": int(stack_field.value) if stack_field else 1
	}
	
	resources_data[item_id] = item_data
	selected_item_id = item_id
	update_item_list()
	print("Saved item: ", item_id)

func load_recipe_into_editor(recipe_id: String):
	var recipe_data = recipes_data.get(recipe_id, {})
	var editor = get_node("MainContainer/TabContainer/Recipes/RecipeEditor")
	
	var id_field = editor.find_child("RecipeIdField")
	var name_field = editor.find_child("RecipeNameField")
	var category_field = editor.find_child("RecipeCategoryField")
	var craft_time_field = editor.find_child("RecipeCraftTimeField")
	var ingredients_container = editor.find_child("IngredientsContainer")
	var output_dropdown = editor.find_child("RecipeOutputDropdown")
	var output_amount = editor.find_child("RecipeOutputAmount")
	
	if id_field: id_field.text = recipe_id
	if name_field: name_field.text = recipe_data.get("name", "")
	if category_field: category_field.text = recipe_data.get("category", "")
	if craft_time_field: craft_time_field.value = recipe_data.get("craft_time", 1.0)
	
	# Clear existing ingredients
	if ingredients_container:
		for child in ingredients_container.get_children():
			child.queue_free()
		
		# Add ingredient rows
		var ingredients_dict = recipe_data.get("ingredients", {})
		for ingredient_id in ingredients_dict:
			add_ingredient_row()
			# Set the values after the row is created
			call_deferred("_set_ingredient_values", ingredient_id, ingredients_dict[ingredient_id])
	
	# Set output dropdown
	if output_dropdown:
		var output_data = recipe_data.get("output", {})
		if output_data.size() > 0:
			var output_id = output_data.keys()[0]
			var amount = output_data[output_id]
			
			# Find the correct dropdown item
			for i in range(output_dropdown.get_item_count()):
				var metadata = output_dropdown.get_item_metadata(i)
				if metadata and metadata.has("id") and metadata.id == output_id:
					output_dropdown.selected = i
					break
			
			if output_amount: output_amount.value = amount

func clear_recipe_editor():
	var editor = get_node("MainContainer/TabContainer/Recipes/RecipeEditor")
	
	var id_field = editor.find_child("RecipeIdField")
	var name_field = editor.find_child("RecipeNameField")
	var category_field = editor.find_child("RecipeCategoryField")
	var craft_time_field = editor.find_child("RecipeCraftTimeField")
	var ingredients_container = editor.find_child("IngredientsContainer")
	var output_dropdown = editor.find_child("RecipeOutputDropdown")
	var output_amount = editor.find_child("RecipeOutputAmount")
	
	if id_field: id_field.text = ""
	if name_field: name_field.text = ""
	if category_field: category_field.text = ""
	if craft_time_field: craft_time_field.value = 1.0
	if output_dropdown: output_dropdown.selected = -1
	if output_amount: output_amount.value = 1
	
	# Clear ingredients
	if ingredients_container:
		for child in ingredients_container.get_children():
			child.queue_free()

func save_current_recipe():
	var editor = get_node("MainContainer/TabContainer/Recipes/RecipeEditor")
	
	var id_field = editor.find_child("RecipeIdField")
	var name_field = editor.find_child("RecipeNameField")
	var category_field = editor.find_child("RecipeCategoryField")
	var craft_time_field = editor.find_child("RecipeCraftTimeField")
	var ingredients_container = editor.find_child("IngredientsContainer")
	var output_dropdown = editor.find_child("RecipeOutputDropdown")
	var output_amount = editor.find_child("RecipeOutputAmount")
	
	if not id_field or id_field.text.strip_edges() == "":
		print("Recipe ID is required")
		return
		
	var recipe_id = id_field.text.strip_edges()
	
	# Collect ingredients from dropdown rows
	var ingredients_dict = {}
	if ingredients_container:
		for row in ingredients_container.get_children():
			var dropdown = row.find_child("IngredientDropdown")
			var amount_spin = row.find_child("IngredientAmount")
			
			if dropdown and amount_spin and dropdown.selected >= 0:
				var ingredient_id = dropdown.get_item_metadata(dropdown.selected)
				var amount = amount_spin.value
				ingredients_dict[ingredient_id] = amount
	
	# Collect output
	var output_dict = {}
	if output_dropdown and output_amount and output_dropdown.selected >= 0:
		var metadata = output_dropdown.get_item_metadata(output_dropdown.selected)
		if metadata and metadata.has("id"):
			output_dict[metadata.id] = output_amount.value
	
	var recipe_data = {
		"name": name_field.text if name_field else "",
		"category": category_field.text if category_field else "",
		"craft_time": craft_time_field.value if craft_time_field else 1.0,
		"ingredients": ingredients_dict,
		"output": output_dict
	}
	
	recipes_data[recipe_id] = recipe_data
	selected_recipe_id = recipe_id
	update_recipes_list()
	print("Saved recipe: ", recipe_id)

func load_building_into_editor(building_id: String):
	var building_data = buildings_data.get(building_id, {})
	var editor = get_node("MainContainer/TabContainer/Buildings/BuildingEditor")
	
	var id_field = editor.find_child("BuildingIdField")
	var name_field = editor.find_child("BuildingNameField")
	var category_field = editor.find_child("BuildingCategoryField")
	var size_width_field = editor.find_child("BuildingSizeWidthField")
	var size_height_field = editor.find_child("BuildingSizeHeightField")
	var health_field = editor.find_child("BuildingHealthField")
	var cost_field = editor.find_child("BuildingCostField")
	
	if id_field: id_field.text = building_id
	if name_field: name_field.text = building_data.get("name", "")
	if category_field: category_field.text = building_data.get("category", "")
	if health_field: health_field.value = building_data.get("max_health", 50)
	
	# Handle size
	var size_data = building_data.get("size", {"x": 1, "y": 1})
	if size_width_field: size_width_field.value = size_data.get("x", 1)
	if size_height_field: size_height_field.value = size_data.get("y", 1)
	
	# Format cost for display
	if cost_field:
		var cost_text = ""
		var cost_dict = building_data.get("cost", {})
		for resource_id in cost_dict:
			cost_text += resource_id + ":" + str(cost_dict[resource_id]) + "\n"
		cost_field.text = cost_text.strip_edges()

func clear_building_editor():
	var editor = get_node("MainContainer/TabContainer/Buildings/BuildingEditor")
	
	var id_field = editor.find_child("BuildingIdField")
	var name_field = editor.find_child("BuildingNameField")
	var category_field = editor.find_child("BuildingCategoryField")
	var size_width_field = editor.find_child("BuildingSizeWidthField")
	var size_height_field = editor.find_child("BuildingSizeHeightField")
	var health_field = editor.find_child("BuildingHealthField")
	var cost_field = editor.find_child("BuildingCostField")
	
	if id_field: id_field.text = ""
	if name_field: name_field.text = ""
	if category_field: category_field.text = ""
	if size_width_field: size_width_field.value = 1
	if size_height_field: size_height_field.value = 1
	if health_field: health_field.value = 50
	if cost_field: cost_field.text = ""

func save_current_building():
	var editor = get_node("MainContainer/TabContainer/Buildings/BuildingEditor")
	
	var id_field = editor.find_child("BuildingIdField")
	var name_field = editor.find_child("BuildingNameField")
	var category_field = editor.find_child("BuildingCategoryField")
	var size_width_field = editor.find_child("BuildingSizeWidthField")
	var size_height_field = editor.find_child("BuildingSizeHeightField")
	var health_field = editor.find_child("BuildingHealthField")
	var cost_field = editor.find_child("BuildingCostField")
	
	if not id_field or id_field.text.strip_edges() == "":
		print("Building ID is required")
		return
		
	var building_id = id_field.text.strip_edges()
	
	# Parse cost
	var cost_dict = {}
	if cost_field:
		var cost_lines = cost_field.text.split("\n")
		for line in cost_lines:
			line = line.strip_edges()
			if line != "" and ":" in line:
				var parts = line.split(":", false, 1)
				if parts.size() >= 2:
					var resource_id = parts[0].strip_edges()
					var amount = float(parts[1].strip_edges())
					cost_dict[resource_id] = amount
	
	var building_data = {
		"name": name_field.text if name_field else "",
		"category": category_field.text if category_field else "",
		"max_health": health_field.value if health_field else 50,
		"size": {
			"x": size_width_field.value if size_width_field else 1,
			"y": size_height_field.value if size_height_field else 1
		},
		"cost": cost_dict,
		"blocks_movement": true,
		"blocks_placement": true,
		"interactable": false
	}
	
	buildings_data[building_id] = building_data
	selected_building_id = building_id
	update_buildings_list()
	print("Saved building: ", building_id)

# Equipment editor support functions (duplicate function removed)

func load_equipment_into_editor(equipment_id: String):
	var equipment_editor = get_node("MainContainer/TabContainer/Equipment/EquipmentEditor")
	if not equipment_editor:
		return
	
	var equipment_item = equipment_data.get(equipment_id, {})
	
	# Load basic fields
	var id_field = equipment_editor.find_child("EquipmentIdField")
	if id_field:
		id_field.text = equipment_id
	
	var name_field = equipment_editor.find_child("EquipmentNameField")
	if name_field:
		name_field.text = equipment_item.get("name", "")
	
	var desc_field = equipment_editor.find_child("EquipmentDescField")
	if desc_field:
		desc_field.text = equipment_item.get("description", "")
	
	var slot_field = equipment_editor.find_child("EquipmentSlotField")
	if slot_field:
		var slot = equipment_item.get("slot", "HEAD")
		for i in range(slot_field.get_item_count()):
			if slot_field.get_item_text(i) == slot:
				slot_field.selected = i
				break
	
	var tier_field = equipment_editor.find_child("EquipmentTierField")
	if tier_field:
		tier_field.value = equipment_item.get("tier", 1)
	
	var icon_field = equipment_editor.find_child("EquipmentIconField")
	if icon_field:
		icon_field.text = equipment_item.get("icon", "")
	
	# Load stats
	var stats = equipment_item.get("stats", {})
	var stat_names = ["defense", "inventory_slots", "movement_speed", "max_stamina", "stamina_regen", "radiation_resist", "oxygen_efficiency"]
	for stat_name in stat_names:
		var stat_field = equipment_editor.find_child(stat_name.capitalize() + "StatField")
		if stat_field:
			stat_field.value = stats.get(stat_name, 0)

func clear_equipment_editor():
	var equipment_editor = get_node("MainContainer/TabContainer/Equipment/EquipmentEditor")
	if not equipment_editor:
		return
	
	# Clear basic fields
	var id_field = equipment_editor.find_child("EquipmentIdField")
	if id_field:
		id_field.text = ""
	
	var name_field = equipment_editor.find_child("EquipmentNameField")
	if name_field:
		name_field.text = ""
	
	var desc_field = equipment_editor.find_child("EquipmentDescField")
	if desc_field:
		desc_field.text = ""
	
	var slot_field = equipment_editor.find_child("EquipmentSlotField")
	if slot_field:
		slot_field.selected = 0
	
	var tier_field = equipment_editor.find_child("EquipmentTierField")
	if tier_field:
		tier_field.value = 1
	
	var icon_field = equipment_editor.find_child("EquipmentIconField")
	if icon_field:
		icon_field.text = ""
	
	# Clear stats
	var stat_names = ["defense", "inventory_slots", "movement_speed", "max_stamina", "stamina_regen", "radiation_resist", "oxygen_efficiency"]
	for stat_name in stat_names:
		var stat_field = equipment_editor.find_child(stat_name.capitalize() + "StatField")
		if stat_field:
			stat_field.value = 0

func save_current_equipment():
	var equipment_editor = get_node("MainContainer/TabContainer/Equipment/EquipmentEditor")
	if not equipment_editor:
		return
	
	# Get basic fields
	var id_field = equipment_editor.find_child("EquipmentIdField")
	var name_field = equipment_editor.find_child("EquipmentNameField")
	var desc_field = equipment_editor.find_child("EquipmentDescField")
	var slot_field = equipment_editor.find_child("EquipmentSlotField")
	var tier_field = equipment_editor.find_child("EquipmentTierField")
	var icon_field = equipment_editor.find_child("EquipmentIconField")
	
	if not id_field or not name_field or not slot_field:
		print("Required equipment fields missing")
		return
	
	var equipment_id = id_field.text.strip_edges()
	if equipment_id == "":
		print("Equipment ID cannot be empty")
		return
	
	# Collect stats
	var stats = {}
	var stat_names = ["defense", "inventory_slots", "movement_speed", "max_stamina", "stamina_regen", "radiation_resist", "oxygen_efficiency"]
	for stat_name in stat_names:
		var stat_field = equipment_editor.find_child(stat_name.capitalize() + "StatField")
		if stat_field and stat_field.value != 0:
			stats[stat_name] = stat_field.value
	
	# Create equipment data
	var equipment_item = {
		"name": name_field.text.strip_edges(),
		"description": desc_field.text.strip_edges() if desc_field else "",
		"slot": slot_field.get_item_text(slot_field.selected),
		"tier": tier_field.value if tier_field else 1,
		"icon": icon_field.text.strip_edges() if icon_field else "",
		"stats": stats
	}
	
	# Save to data
	equipment_data[equipment_id] = equipment_item
	selected_equipment_id = equipment_id
	
	# Update UI
	update_equipment_list()
	
	print("Saved equipment: ", equipment_id)

# Weapon editor support functions
func update_weapons_list():
	if not weapons_list:
		return
	
	# Clear existing items
	for child in weapons_list.get_children():
		child.queue_free()
	
	# Add weapon items
	for weapon_id in weapons_data:
		var weapon_item = weapons_data[weapon_id]
		var button = Button.new()
		button.text = weapon_item.get("name", weapon_id)
		button.pressed.connect(_on_weapon_selected.bind(weapon_id))
		weapons_list.add_child(button)

func load_weapon_into_editor(weapon_id: String):
	var weapon_editor = get_node("MainContainer/TabContainer/Weapons/WeaponEditor")
	if not weapon_editor:
		return
	
	var weapon_item = weapons_data.get(weapon_id, {})
	
	# Load basic fields
	var id_field = weapon_editor.find_child("WeaponIdField")
	if id_field:
		id_field.text = weapon_id
	
	var name_field = weapon_editor.find_child("WeaponNameField")
	if name_field:
		name_field.text = weapon_item.get("name", "")
	
	var desc_field = weapon_editor.find_child("WeaponDescField")
	if desc_field:
		desc_field.text = weapon_item.get("description", "")
	
	var type_field = weapon_editor.find_child("WeaponTypeField")
	if type_field:
		var weapon_type = weapon_item.get("type", "melee")
		for i in range(type_field.get_item_count()):
			if type_field.get_item_text(i).to_lower() == weapon_type:
				type_field.selected = i
				break
	
	var damage_field = weapon_editor.find_child("WeaponDamageField")
	if damage_field:
		damage_field.value = weapon_item.get("damage", 10)
	
	var fire_rate_field = weapon_editor.find_child("WeaponFireRateField")
	if fire_rate_field:
		fire_rate_field.value = weapon_item.get("fire_rate", 1.0)
	
	var range_field = weapon_editor.find_child("WeaponRangeField")
	if range_field:
		range_field.value = weapon_item.get("range", 100)
	
	var ammo_field = weapon_editor.find_child("WeaponAmmoField")
	if ammo_field:
		ammo_field.text = weapon_item.get("ammo_type", "")
	
	var icon_field = weapon_editor.find_child("WeaponIconField")
	if icon_field:
		icon_field.text = weapon_item.get("icon", "")

func clear_weapon_editor():
	var weapon_editor = get_node("MainContainer/TabContainer/Weapons/WeaponEditor")
	if not weapon_editor:
		return
	
	# Clear basic fields
	var id_field = weapon_editor.find_child("WeaponIdField")
	if id_field:
		id_field.text = ""
	
	var name_field = weapon_editor.find_child("WeaponNameField")
	if name_field:
		name_field.text = ""
	
	var desc_field = weapon_editor.find_child("WeaponDescField")
	if desc_field:
		desc_field.text = ""
	
	var type_field = weapon_editor.find_child("WeaponTypeField")
	if type_field:
		type_field.selected = 0
	
	var damage_field = weapon_editor.find_child("WeaponDamageField")
	if damage_field:
		damage_field.value = 10
	
	var fire_rate_field = weapon_editor.find_child("WeaponFireRateField")
	if fire_rate_field:
		fire_rate_field.value = 1.0
	
	var range_field = weapon_editor.find_child("WeaponRangeField")
	if range_field:
		range_field.value = 100
	
	var ammo_field = weapon_editor.find_child("WeaponAmmoField")
	if ammo_field:
		ammo_field.text = ""
	
	var icon_field = weapon_editor.find_child("WeaponIconField")
	if icon_field:
		icon_field.text = ""

func save_current_weapon():
	var weapon_editor = get_node("MainContainer/TabContainer/Weapons/WeaponEditor")
	if not weapon_editor:
		return
	
	# Get basic fields
	var id_field = weapon_editor.find_child("WeaponIdField")
	var name_field = weapon_editor.find_child("WeaponNameField")
	var desc_field = weapon_editor.find_child("WeaponDescField")
	var type_field = weapon_editor.find_child("WeaponTypeField")
	var damage_field = weapon_editor.find_child("WeaponDamageField")
	var fire_rate_field = weapon_editor.find_child("WeaponFireRateField")
	var range_field = weapon_editor.find_child("WeaponRangeField")
	var ammo_field = weapon_editor.find_child("WeaponAmmoField")
	var icon_field = weapon_editor.find_child("WeaponIconField")
	
	if not id_field or not name_field or not type_field:
		print("Required weapon fields missing")
		return
	
	var weapon_id = id_field.text.strip_edges()
	if weapon_id == "":
		print("Weapon ID cannot be empty")
		return
	
	# Create weapon data
	var weapon_item = {
		"name": name_field.text.strip_edges(),
		"description": desc_field.text.strip_edges() if desc_field else "",
		"type": type_field.get_item_text(type_field.selected).to_lower(),
		"damage": damage_field.value if damage_field else 10,
		"fire_rate": fire_rate_field.value if fire_rate_field else 1.0,
		"range": range_field.value if range_field else 100,
		"ammo_type": ammo_field.text.strip_edges() if ammo_field else "",
		"icon": icon_field.text.strip_edges() if icon_field else ""
	}
	
	# Save to data
	weapons_data[weapon_id] = weapon_item
	selected_weapon_id = weapon_id
	
	# Update UI
	update_weapons_list()
	
	print("Saved weapon: ", weapon_id)