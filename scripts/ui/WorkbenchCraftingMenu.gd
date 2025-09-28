extends Control
class_name WorkbenchCraftingMenu

@onready var title_label: Label = $CraftingPanel/VBoxContainer/TitleBar/TitleLabel
@onready var close_button: Button = $CraftingPanel/VBoxContainer/TitleBar/CloseButton
@onready var recipes_container: VBoxContainer = $CraftingPanel/VBoxContainer/MainContainer/LeftPanel/RecipesList/RecipesContainer
@onready var item_title: Label = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemTitle
@onready var item_icon: TextureRect = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemIcon
@onready var item_description: RichTextLabel = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ItemDescription
@onready var resources_list: VBoxContainer = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ItemInfoPanel/ItemInfoContainer/ResourcesList
@onready var craft_button: Button = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ButtonContainer/CraftButton
@onready var move_button: Button = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ButtonContainer/MoveButton
@onready var destroy_button: Button = $CraftingPanel/VBoxContainer/MainContainer/RightPanel/ButtonContainer/DestroyButton

var current_workbench: WorkbenchBuilding = null
var selected_recipe_id: String = ""
var recipe_buttons: Array[Button] = []

static var instance: WorkbenchCraftingMenu

func _ready():
	instance = self
	visible = false
	clear_selection()

func open_workbench_menu(workbench: WorkbenchBuilding):
	current_workbench = workbench
	visible = true
	setup_recipes()
	clear_selection()

func setup_recipes():
	# Clear existing recipe buttons
	for button in recipe_buttons:
		button.queue_free()
	recipe_buttons.clear()
	
	if not current_workbench:
		return
	
	var recipes = current_workbench.get_available_recipes()
	
	for recipe_id in recipes.keys():
		var recipe_data = recipes[recipe_id]
		var button = create_recipe_button(recipe_id, recipe_data)
		recipes_container.add_child(button)
		recipe_buttons.append(button)

func create_recipe_button(recipe_id: String, recipe_data: Dictionary) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(0, 60)
	button.text = recipe_data.get("name", recipe_id)
	
	# Set icon if available with size constraints
	var icon_path = recipe_data.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var texture = load(icon_path)
		button.icon = texture
		# Constrain icon size for recipe buttons
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Connect button signal
	button.pressed.connect(_on_recipe_selected.bind(recipe_id, recipe_data))
	
	return button

func _on_recipe_selected(recipe_id: String, recipe_data: Dictionary):
	selected_recipe_id = recipe_id
	update_item_info(recipe_data)

func update_item_info(recipe_data: Dictionary):
	item_title.text = recipe_data.get("name", "Unknown Recipe")
	item_description.text = recipe_data.get("description", "No description available.")
	
	# Update icon
	var icon_path = recipe_data.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		item_icon.texture = load(icon_path)
	else:
		item_icon.texture = null
	
	# Update required resources
	update_required_resources(recipe_data.get("required_resources", {}))
	
	# Enable craft button if we can afford it
	craft_button.disabled = not can_craft_current_recipe()

func update_required_resources(required_resources: Dictionary):
	# Clear existing resource displays
	for child in resources_list.get_children():
		child.queue_free()
	
	# Add resource requirements
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id) if InventorySystem else 0
		
		var resource_data = InventorySystem.get_item_data(resource_id) if InventorySystem else {}
		var resource_name = resource_data.get("name", resource_id)
		
		# Color code based on availability
		var color = "green" if current_amount >= required_amount else "red"
		
		var rich_label = RichTextLabel.new()
		rich_label.bbcode_enabled = true
		rich_label.text = "[color=%s]%s: %d/%d[/color]" % [color, resource_name, current_amount, required_amount]
		rich_label.fit_content = true
		rich_label.custom_minimum_size = Vector2(0, 25)
		
		resources_list.add_child(rich_label)

func can_craft_current_recipe() -> bool:
	if not current_workbench or selected_recipe_id.is_empty():
		return false
	return current_workbench.can_craft_item(selected_recipe_id)

func clear_selection():
	selected_recipe_id = ""
	item_title.text = "Select a recipe"
	item_icon.texture = null
	item_description.text = "Select a recipe to see details"
	craft_button.disabled = true
	
	# Clear resources list
	for child in resources_list.get_children():
		child.queue_free()

func _on_close_button_pressed():
	visible = false

func _on_craft_button_pressed():
	if not current_workbench or selected_recipe_id.is_empty():
		return
	
	if current_workbench.craft_item(selected_recipe_id):
		print("Successfully crafted: %s" % selected_recipe_id)
		# Refresh the display after crafting
		if not selected_recipe_id.is_empty():
			var recipes = current_workbench.get_available_recipes()
			if recipes.has(selected_recipe_id):
				update_item_info(recipes[selected_recipe_id])
	else:
		print("Failed to craft: %s" % selected_recipe_id)

func _on_move_button_pressed():
	if current_workbench:
		current_workbench.move_workbench()
		visible = false

func _on_destroy_button_pressed():
	if current_workbench:
		current_workbench.destroy_workbench()
		visible = false