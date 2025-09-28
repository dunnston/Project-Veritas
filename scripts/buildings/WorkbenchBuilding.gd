extends Area2D
class_name WorkbenchBuilding

var player_in_range: bool = false
var player_ref: Node2D = null
var interaction_prompt: Label = null

# Workbench crafting data
var crafting_recipes: Dictionary = {}

@warning_ignore("unused_signal")
signal workbench_interacted(workbench: WorkbenchBuilding)

func _ready():
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Load crafting recipes
	load_crafting_recipes()
	
	# Create interaction prompt
	create_interaction_prompt()
	
	print("Workbench building created and ready for interaction")

func load_crafting_recipes():
	# Load recipes from JSON file
	var file_path = "res://data/recipes.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var all_recipes = json.data
			
			# Filter recipes that require workbench
			for recipe_id in all_recipes.keys():
				var recipe_data = all_recipes[recipe_id]
				if recipe_data.get("workbench_required", false):
					# Convert ingredient names to match inventory system
					var ingredients = recipe_data.get("ingredients", {})
					var required_resources = {}
					for ingredient_id in ingredients.keys():
						required_resources[ingredient_id] = ingredients[ingredient_id]
					
					# Store recipe in workbench format
					crafting_recipes[recipe_id] = {
						"name": recipe_data.get("name", recipe_id),
						"description": recipe_data.get("description", ""),
						"icon_path": get_recipe_icon_path(recipe_id),
						"required_resources": required_resources,
						"category": recipe_data.get("category", "Misc"),
						"craft_time": recipe_data.get("craft_time", 1.0),
						"output": recipe_data.get("output", {})
					}
			print("Loaded %d workbench recipes" % crafting_recipes.size())
		else:
			push_error("Failed to parse recipes.json")
	else:
		push_error("recipes.json not found")

func get_recipe_icon_path(recipe_id: String) -> String:
	# First check if recipe has icon field in JSON
	var file_path = "res://data/recipes.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var all_recipes = json.data
			if all_recipes.has(recipe_id):
				var recipe_data = all_recipes[recipe_id]
				var icon_name = recipe_data.get("icon", "")
				if not icon_name.is_empty():
					# Try common icon paths
					var paths_to_try = [
						"res://assets/sprites/items/" + icon_name,
						"res://assets/sprites/buildings/" + icon_name,
						"res://assets/sprites/tools/" + icon_name
					]
					for path in paths_to_try:
						if ResourceLoader.exists(path):
							return path
	
	# Fallback to hardcoded map for legacy support
	var icon_map = {
		"crowbar": "res://assets/sprites/tools/crowbar.png",
		"rubber_seal_from_tire": "res://assets/sprites/items/rubber seal.png",
		"metal_rod": "res://assets/sprites/items/metal-rod.png", 
		"copper_wire_from_speakers": "res://assets/sprites/items/copper-wire.png",
		"gear_assembly": "res://assets/sprites/items/gear-assembly.png",
		"metal_valve": "res://assets/sprites/items/Metal-Valve.png",
		"steel_sheet": "res://assets/sprites/items/steel_sheet.png",
		"storage_box": "res://assets/sprites/items/Chest.png"
	}
	return icon_map.get(recipe_id, "")

func create_interaction_prompt():
	# Create a simple text prompt for now
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press E to use workbench"
	interaction_prompt.position = Vector2(-50, -80)  # Above the workbench
	interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 1)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 1)
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func _input(event: InputEvent):
	if player_in_range and event.is_action_pressed("interact"):
		interact_with_workbench()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		show_interaction_prompt()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func interact_with_workbench():
	print("Player interacted with workbench!")
	
	# Open workbench crafting menu
	if WorkbenchCraftingMenu.instance:
		WorkbenchCraftingMenu.instance.open_workbench_menu(self)
	else:
		print("WorkbenchCraftingMenu not found!")

func get_available_recipes() -> Dictionary:
	return crafting_recipes

func can_craft_item(item_id: String) -> bool:
	if not crafting_recipes.has(item_id):
		return false
	
	var recipe = crafting_recipes[item_id]
	var required_resources = recipe.get("required_resources", {})
	
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id) if InventorySystem else 0
		if current_amount < required_amount:
			return false
	
	return true

func craft_item(item_id: String) -> bool:
	if not can_craft_item(item_id):
		return false
	
	var recipe = crafting_recipes[item_id]
	var required_resources = recipe.get("required_resources", {})
	
	# Consume resources
	for resource_id in required_resources.keys():
		var required_amount = required_resources[resource_id]
		if not InventorySystem.remove_item(resource_id, required_amount):
			print("Failed to remove resource: %s" % resource_id)
			return false
	
	# Check if output is a building or an item
	var output = recipe.get("output", {})
	for output_item in output.keys():
		var output_amount = output[output_item]
		
		# Check if this is a building by looking in buildings.json
		if is_building(output_item):
			print("Crafted building: %s - entering placement mode" % output_item)
			# Close the crafting menu
			if WorkbenchCraftingMenu.instance:
				WorkbenchCraftingMenu.instance.visible = false
			# Start building placement mode
			if BuildingSystem:
				BuildingSystem.start_building_mode(output_item)
			else:
				print("BuildingSystem not found!")
				return false
		else:
			# Regular item - add to inventory
			if not InventorySystem.add_item(output_item, output_amount):
				print("Failed to add crafted item to inventory: %s" % output_item)
				return false
	
	print("Successfully crafted: %s" % recipe.get("name", item_id))
	return true

func is_building(item_id: String) -> bool:
	# Check if this ID exists in buildings.json
	var file_path = "res://data/buildings.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_text) == OK:
			var buildings_data = json.data
			return buildings_data.has(item_id)
	return false

func move_workbench():
	print("Moving workbench...")
	# Enter building mode with this workbench type
	if BuildingSystem:
		# Remove current workbench
		queue_free()
		# Start building mode for replacement
		BuildingSystem.start_building_mode("workbench")

func destroy_workbench():
	print("Destroying workbench...")
	
	# Return materials to inventory (workbench costs 5 wood scraps)
	if InventorySystem:
		InventorySystem.add_item("WOOD_SCRAPS", 5)
	
	# Remove the workbench
	queue_free()
