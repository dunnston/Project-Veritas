@tool
extends Control

# Main dock for the Crafting System Manager plugin
# Uses modular editor architecture for maintainability

var tab_container: TabContainer

func _ready():
	create_ui()

func create_ui():
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainContainer"
	add_child(main_vbox)
	
	# Title
	var title = Label.new()
	title.text = "Neon Wasteland Crafting Manager"
	title.add_theme_font_size_override("font_size", 16)
	main_vbox.add_child(title)
	
	# Tab container
	tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	# Create tabs - ITEMS AND RECIPES ENABLED
	create_items_tab()
	create_recipes_tab()
	create_disabled_tabs()

func create_items_tab():
	# Items tab - ENABLED
	var items_editor = ItemsEditor.new()
	items_editor.name = "Items"
	tab_container.add_child(items_editor)

func create_recipes_tab():
	# Recipes tab - ENABLED
	var recipes_editor = RecipesEditor.new()
	recipes_editor.name = "Recipes"
	tab_container.add_child(recipes_editor)

func create_disabled_tabs():
	# Buildings tab is now enabled, so we'll create it properly
	var buildings_editor = BuildingsEditor.new()
	buildings_editor.name = "Buildings"
	tab_container.add_child(buildings_editor)
	
	# Equipment tab is now enabled
	var equipment_editor = EquipmentEditor.new()
	equipment_editor.name = "Equipment"
	tab_container.add_child(equipment_editor)
	
	# Weapons tab is now enabled
	var weapons_editor = WeaponsEditor.new()
	weapons_editor.name = "Weapons"
	tab_container.add_child(weapons_editor)
	
	# Ammo tab is now enabled
	var ammo_editor = AmmoEditor.new()
	ammo_editor.name = "Ammo"
	tab_container.add_child(ammo_editor)

func create_disabled_tab(tab_name: String, message: String):
	var tab = VBoxContainer.new()
	tab.name = tab_name
	
	var label = Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab.add_child(label)
	
	tab_container.add_child(tab)

# Functions to enable tabs one by one (to be called later)
func enable_recipes_tab():
	# Replace disabled Recipes tab with actual RecipesEditor
	var recipes_tab = tab_container.get_node("Recipes")
	if recipes_tab:
		recipes_tab.queue_free()
	
	var recipes_editor = RecipesEditor.new()
	recipes_editor.name = "Recipes"  
	tab_container.add_child(recipes_editor)
	tab_container.move_child(recipes_editor, 1) # Position after Items

func enable_buildings_tab():
	# Replace disabled Buildings tab with actual BuildingsEditor
	var buildings_tab = tab_container.get_node("Buildings")
	if buildings_tab:
		buildings_tab.queue_free()
	
	var buildings_editor = BuildingsEditor.new()
	buildings_editor.name = "Buildings"
	tab_container.add_child(buildings_editor)
	tab_container.move_child(buildings_editor, 2) # Position after Recipes

func enable_equipment_tab():
	# Replace disabled Equipment tab with actual EquipmentEditor
	var equipment_tab = tab_container.get_node("Equipment")
	if equipment_tab:
		equipment_tab.queue_free()
	
	var equipment_editor = EquipmentEditor.new()
	equipment_editor.name = "Equipment"
	tab_container.add_child(equipment_editor)
	tab_container.move_child(equipment_editor, 3) # Position after Buildings

func enable_weapons_tab():
	# Replace disabled Weapons tab with actual WeaponsEditor
	var weapons_tab = tab_container.get_node("Weapons")
	if weapons_tab:
		weapons_tab.queue_free()
	
	var weapons_editor = WeaponsEditor.new()
	weapons_editor.name = "Weapons"
	tab_container.add_child(weapons_editor)
	tab_container.move_child(weapons_editor, 4) # Position after Equipment