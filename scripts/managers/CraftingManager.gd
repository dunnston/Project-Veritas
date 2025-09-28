extends Node

class_name CraftingManagerSingleton

signal recipe_unlocked(recipe_id: String)
signal crafting_started(recipe_id: String)
signal crafting_completed(recipe_id: String)

var recipes: Dictionary = {}
var unlocked_recipes: Array[String] = []
var crafting_queue: Array = []

func _ready() -> void:
	load_recipes()
	initialize_unlocked_recipes()
	print("CraftingManager initialized")

func load_recipes() -> void:
	var file_path = "res://data/recipes.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			recipes = json.data
		else:
			push_error("Failed to parse recipes.json")

func initialize_unlocked_recipes() -> void:
	unlocked_recipes.append("basic_wall")
	unlocked_recipes.append("basic_floor")
	unlocked_recipes.append("workbench")
	unlocked_recipes.append("storage_box")
	unlocked_recipes.append("scrap_pickaxe")
	unlocked_recipes.append("metal_sheets")
	unlocked_recipes.append("rubber_seal")
	unlocked_recipes.append("copper_wire")
	unlocked_recipes.append("steel_gears")
	unlocked_recipes.append("chemical_catalyst")
	unlocked_recipes.append("oxygen_tank")
	unlocked_recipes.append("hand_crank_generator")
	unlocked_recipes.append("crowbar")

func unlock_recipe(recipe_id: String) -> void:
	if recipe_id not in unlocked_recipes and recipe_id in recipes:
		unlocked_recipes.append(recipe_id)
		recipe_unlocked.emit(recipe_id)
		print("Recipe unlocked: " + recipe_id)
		
		# Grant Research XP for unlocking recipes
		if has_node("/root/SkillSystem"):
			var skill_system = get_node("/root/SkillSystem")
			skill_system.add_xp("RESEARCH", skill_system.XP_VALUES.RECIPE_UNLOCKED, "recipe_unlock")

func is_recipe_unlocked(recipe_id: String) -> bool:
	return recipe_id in unlocked_recipes

func can_craft(recipe_id: String) -> bool:
	if not is_recipe_unlocked(recipe_id):
		return false
	
	if recipe_id not in recipes:
		return false
	
	var recipe = recipes[recipe_id]
	if "ingredients" in recipe:
		return can_afford_ingredients(recipe["ingredients"])
	return false

func can_afford_ingredients(ingredients: Dictionary) -> bool:
	for ingredient_id in ingredients:
		var required_amount = ingredients[ingredient_id]
		if not InventorySystem.has_item(ingredient_id, required_amount):
			return false
	return true

func craft_item(recipe_id: String, instant: bool = false) -> bool:
	if not can_craft(recipe_id):
		return false
	
	var recipe = recipes[recipe_id]
	
	if not pay_ingredient_cost(recipe["ingredients"]):
		return false
	
	if instant or recipe.get("craft_time", 0) == 0:
		complete_crafting(recipe_id)
	else:
		start_crafting(recipe_id, recipe["craft_time"])
	
	return true

func pay_ingredient_cost(ingredients: Dictionary) -> bool:
	# First check if we can afford all ingredients
	if not can_afford_ingredients(ingredients):
		return false
	
	# Then remove all ingredients from inventory
	for ingredient_id in ingredients:
		var required_amount = ingredients[ingredient_id]
		if not InventorySystem.remove_item(ingredient_id, required_amount):
			# If removal fails, this shouldn't happen since we checked can_afford first
			push_error("Failed to remove ingredient %s x%d from inventory" % [ingredient_id, required_amount])
			return false
	
	return true

func start_crafting(recipe_id: String, craft_time: float) -> void:
	crafting_started.emit(recipe_id)
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = craft_time
	timer.one_shot = true
	timer.timeout.connect(_on_crafting_complete.bind(recipe_id, timer))
	timer.start()

func _on_crafting_complete(recipe_id: String, timer: Timer) -> void:
	timer.queue_free()
	complete_crafting(recipe_id)

func complete_crafting(recipe_id: String) -> void:
	var recipe = recipes[recipe_id]
	
	if "output" in recipe:
		for item_id in recipe["output"]:
			var amount = recipe["output"][item_id]
			InventorySystem.add_item(item_id, amount)
	
	crafting_completed.emit(recipe_id)
	EventBus.emit_item_crafted(recipe_id)
	
	# Grant Technology XP for crafting
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		# Check if it's an electronic item (expand this list as needed)
		var electronic_items = ["copper_wire", "circuit_board", "battery", "solar_panel", "computer_chip"]
		if recipe_id in electronic_items:
			skill_system.add_xp("ELECTRONICS", skill_system.XP_VALUES.ELECTRONIC_CRAFTED, "crafting_electronics")
	
	# Notify EmergencySystem for critical items
	if recipe_id == "oxygen_tank":
		var emergency_system = get_tree().get_first_node_in_group("emergency_system")
		if emergency_system:
			emergency_system.set_oxygen_tank_built(true)
	elif recipe_id == "hand_crank_generator":
		var emergency_system = get_tree().get_first_node_in_group("emergency_system")
		if emergency_system:
			emergency_system.set_hand_crank_generator_built(true)
		
		# Activate all hand crank generators in the scene
		var generators = get_tree().get_nodes_in_group("hand_crank_generators")
		for generator in generators:
			if generator.has_method("activate_generator"):
				generator.activate_generator()
	
	print("Crafted: " + recipe_id)

func get_recipe(recipe_id: String) -> Dictionary:
	if recipe_id in recipes:
		return recipes[recipe_id]
	return {}

func get_unlocked_recipes() -> Array:
	var unlocked = []
	for recipe_id in unlocked_recipes:
		if recipe_id in recipes:
			unlocked.append(recipes[recipe_id])
	return unlocked