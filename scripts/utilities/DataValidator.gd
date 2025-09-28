extends Node

# SAFEGUARD UTILITY: Validates data consistency across all JSON files and systems
class_name DataValidator

static func validate_all_data() -> bool:
	print("=== DATA VALIDATION STARTING ===")
	
	var resources_valid = validate_resources_data()
	var recipes_valid = validate_recipes_data() 
	var buildings_valid = validate_buildings_data()
	var cross_references_valid = validate_cross_references()
	
	var all_valid = resources_valid and recipes_valid and buildings_valid and cross_references_valid
	
	if all_valid:
		print("=== DATA VALIDATION PASSED ===")
	else:
		push_error("=== DATA VALIDATION FAILED - PLEASE FIX ISSUES ABOVE ===")
	
	return all_valid

static func validate_resources_data() -> bool:
	print("Validating resources.json...")
	
	var file_path = "res://data/resources.json"
	if not FileAccess.file_exists(file_path):
		push_error("CRITICAL: resources.json not found!")
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("CRITICAL: resources.json is invalid JSON!")
		return false
	
	var data = json.data
	var required_fields = ["name", "description", "category", "stack_size"]
	var valid = true
	
	for resource_id in data.keys():
		var resource = data[resource_id]
		for field in required_fields:
			if not resource.has(field):
				push_error("Resource '%s' missing required field: %s" % [resource_id, field])
				valid = false
	
	print("Resources validation: %s" % ("PASSED" if valid else "FAILED"))
	return valid

static func validate_recipes_data() -> bool:
	print("Validating recipes.json...")
	
	var file_path = "res://data/recipes.json" 
	if not FileAccess.file_exists(file_path):
		push_error("CRITICAL: recipes.json not found!")
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("CRITICAL: recipes.json is invalid JSON!")
		return false
	
	var data = json.data
	var required_fields = ["name", "description", "ingredients", "output"]
	var valid = true
	
	for recipe_id in data.keys():
		var recipe = data[recipe_id]
		for field in required_fields:
			if not recipe.has(field):
				push_error("Recipe '%s' missing required field: %s" % [recipe_id, field])
				valid = false
	
	print("Recipes validation: %s" % ("PASSED" if valid else "FAILED"))
	return valid

static func validate_buildings_data() -> bool:
	print("Validating buildings.json...")
	
	var file_path = "res://data/buildings.json"
	if not FileAccess.file_exists(file_path):
		push_error("CRITICAL: buildings.json not found!")
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("CRITICAL: buildings.json is invalid JSON!")
		return false
	
	var data = json.data
	var required_fields = ["name", "description", "cost", "max_health"]
	var valid = true
	
	for building_id in data.keys():
		var building = data[building_id]
		for field in required_fields:
			if not building.has(field):
				push_error("Building '%s' missing required field: %s" % [building_id, field])
				valid = false
	
	print("Buildings validation: %s" % ("PASSED" if valid else "FAILED"))
	return valid

static func validate_cross_references() -> bool:
	print("Validating cross-references between files...")
	
	# Load all data files
	var resources_data = load_json_data("res://data/resources.json")
	var recipes_data = load_json_data("res://data/recipes.json") 
	var buildings_data = load_json_data("res://data/buildings.json")
	
	if resources_data.is_empty() or recipes_data.is_empty() or buildings_data.is_empty():
		push_error("Could not load data files for cross-reference validation")
		return false
	
	var valid = true
	
	# Check recipe ingredients reference valid resources
	for recipe_id in recipes_data.keys():
		var recipe = recipes_data[recipe_id]
		if recipe.has("ingredients"):
			for ingredient_id in recipe["ingredients"].keys():
				if ingredient_id not in resources_data:
					push_error("Recipe '%s' references unknown resource: %s" % [recipe_id, ingredient_id])
					valid = false
	
	# Check building costs reference valid resources
	for building_id in buildings_data.keys():
		var building = buildings_data[building_id]
		if building.has("cost"):
			for resource_id in building["cost"].keys():
				if resource_id not in resources_data:
					push_error("Building '%s' references unknown resource: %s" % [building_id, resource_id])
					valid = false
	
	print("Cross-reference validation: %s" % ("PASSED" if valid else "FAILED"))
	return valid

static func load_json_data(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		return {}
	
	return json.data

# NOTE: ResourceManager validation removed - now using unified InventorySystem
# Resources are validated through InventorySystem's item data loading
