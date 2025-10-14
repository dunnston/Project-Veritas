extends Control
class_name InteractionPromptUI

## Shows interaction prompts like "Press E to Build [Building Name]"

@onready var prompt_label: RichTextLabel = $CenterContainer/PromptLabel

var player: Node = null
var current_prompt: String = ""

func _ready():
	# Start hidden
	visible = false

	# Find player
	call_deferred("connect_to_player")

func connect_to_player():
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("InteractionPromptUI: Connected to player ✓")
	else:
		print("InteractionPromptUI: ERROR - Could not find player!")

func is_any_menu_open() -> bool:
	"""Check if any UI menu is currently open"""
	# Check workbench menu
	var workbench_menu = get_tree().get_first_node_in_group("crafting_menu")
	if workbench_menu and workbench_menu.visible:
		return true

	# Check inventory
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.visible:
		return true

	# Check build menu
	var build_menu = get_tree().get_first_node_in_group("build_menu")
	if build_menu and build_menu.visible:
		return true

	# Check storage UI
	var storage_ui = get_tree().get_first_node_in_group("storage_ui")
	if storage_ui and storage_ui.visible:
		return true

	return false

func _process(_delta):
	if not player:
		return

	# Hide prompt if any UI menu is open
	if is_any_menu_open():
		hide_prompt()
		return

	# Priority 1: Check if player is near a building template
	var nearest_template = player.find_nearest_building_template() if player.has_method("find_nearest_building_template") else null

	if nearest_template:
		# Show prompt with materials
		var template_name = nearest_template.get_display_name() if nearest_template.has_method("get_display_name") else "Building"
		var cost_text = get_cost_text(nearest_template)

		if cost_text:
			show_prompt("[center]Hold E to Build: %s\n%s[/center]" % [template_name, cost_text])
		else:
			show_prompt("[center]Hold E to Build: %s[/center]" % template_name)
		return

	# Priority 2: Check for other interactable objects (workbenches, etc.)
	if "nearby_interactables" in player and not player.nearby_interactables.is_empty():
		var nearest_interactable = get_nearest_interactable()
		if nearest_interactable:
			var interact_text = get_interactable_prompt(nearest_interactable)
			show_prompt("[center]%s[/center]" % interact_text)
			return

	# No interactions available
	hide_prompt()

func get_cost_text(template: Node) -> String:
	"""Get formatted cost text showing required materials"""
	if not template.has_method("can_afford"):
		return ""

	# Get building cost from template
	var building_cost = template.building_cost if "building_cost" in template else {}

	if building_cost.is_empty():
		return ""

	var cost_parts = []
	for resource_id in building_cost.keys():
		var required_amount = building_cost[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id) if InventorySystem else 0

		# Get resource name
		var resource_name = resource_id
		if InventorySystem:
			var item_data = InventorySystem.get_item_data(resource_id)
			resource_name = item_data.get("name", resource_id)

		# Format with color coding
		var has_enough = current_amount >= required_amount
		var color = "green" if has_enough else "red"
		cost_parts.append("[color=%s]%s: %d/%d[/color]" % [color, resource_name, current_amount, required_amount])

	return " | ".join(cost_parts)

func show_prompt(text: String):
	if current_prompt != text:
		current_prompt = text
		prompt_label.text = text
		visible = true
		print("InteractionPromptUI: Showing prompt: %s" % text)

func hide_prompt():
	if visible:
		visible = false
		current_prompt = ""
		prompt_label.text = ""

func get_nearest_interactable() -> Node:
	"""Get the nearest interactable object from the player's nearby list"""
	if not player or not "nearby_interactables" in player:
		return null

	var interactables = player.nearby_interactables
	if interactables.is_empty():
		return null

	# Find the closest one
	var nearest = interactables[0]
	var min_distance = player.global_position.distance_to(nearest.global_position)

	for interactable in interactables:
		var distance = player.global_position.distance_to(interactable.global_position)
		if distance < min_distance:
			nearest = interactable
			min_distance = distance

	return nearest

func get_interactable_prompt(interactable: Node) -> String:
	"""Get the interaction prompt text for an interactable object"""
	if not interactable:
		return ""

	# Check if the object has a custom prompt (must be a String, not a Node)
	if "interaction_prompt" in interactable and interactable.interaction_prompt is String:
		return interactable.interaction_prompt

	# Check for common object names and provide appropriate prompts
	var object_name = interactable.name

	if "workbench" in object_name.to_lower():
		return "Press E to Open Workbench"
	elif "storage" in object_name.to_lower() or "chest" in object_name.to_lower():
		return "Press E to Open Storage"
	elif "door" in object_name.to_lower():
		return "Press E to Open/Close Door"
	elif "turret" in object_name.to_lower():
		return "Press E to Access Turret"
	else:
		# Generic interact prompt
		return "Press E to Interact"
