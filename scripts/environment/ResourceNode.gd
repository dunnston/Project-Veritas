extends StaticBody2D

class_name ResourceNode

signal resource_depleted()
signal resource_harvested(resource_type: String, amount: int)

@export var resource_type: String = "SCRAP_METAL"
@export var resource_amount: int = 10
@export var harvest_time: float = 2.0
@export var respawn_time: float = 60.0
@export var required_tool: String = ""

var current_amount: int
var is_depleted: bool = false
var is_being_harvested: bool = false

var sprite: ColorRect
var collision_shape: CollisionShape2D
var harvest_timer: Timer
var respawn_timer: Timer

func _ready() -> void:
	# Get node references
	sprite = get_node("ColorRect")
	collision_shape = get_node("CollisionShape2D")
	harvest_timer = get_node("HarvestTimer")
	respawn_timer = get_node("RespawnTimer")
	
	add_to_group("resource_nodes")
	add_to_group("interactables")
	current_amount = resource_amount
	
	harvest_timer.one_shot = true
	harvest_timer.timeout.connect(_on_harvest_complete)
	
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_on_respawn)

func interact(player: Node) -> void:
	print("ResourceNode: interact() called with player: ", player)
	if is_depleted or is_being_harvested:
		print("ResourceNode: Node is depleted or being harvested, cannot interact")
		return
	
	if required_tool != "":
		print("ResourceNode: Required tool: ", required_tool)
		if not player.inventory.has_item(required_tool):
			print("ResourceNode: Player does not have required tool: " + required_tool)
			return
	
	print("ResourceNode: Starting harvest")
	start_harvest(player)

func start_harvest(player: Node) -> void:
	is_being_harvested = true
	harvest_timer.wait_time = harvest_time
	harvest_timer.start()
	
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "modulate:a", 0.5, 0.1)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.1)

func _on_harvest_complete() -> void:
	is_being_harvested = false
	
	var harvest_amount = min(randi_range(1, 3), current_amount)
	current_amount -= harvest_amount
	
	if GameManager.player_node:
		GameManager.player_node.collect_resource(resource_type, harvest_amount)
	
	resource_harvested.emit(resource_type, harvest_amount)
	
	# Grant bonus XP for discovering a new node (first harvest)
	if has_node("/root/SkillSystem") and current_amount == resource_amount - harvest_amount:
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RESOURCE_NODE_DISCOVERED, "node_discovery")
	
	if current_amount <= 0:
		deplete()
	else:
		update_visual()

func deplete() -> void:
	is_depleted = true
	resource_depleted.emit()
	
	if sprite:
		sprite.modulate.a = 0.3
	
	if collision_shape:
		collision_shape.disabled = true
	
	respawn_timer.wait_time = respawn_time
	respawn_timer.start()

func _on_respawn() -> void:
	is_depleted = false
	current_amount = resource_amount
	
	if sprite:
		sprite.modulate.a = 1.0
	
	if collision_shape:
		collision_shape.disabled = false
	
	update_visual()

func update_visual() -> void:
	if not sprite:
		return
	
	var percentage = float(current_amount) / float(resource_amount)
	sprite.modulate = Color(1, percentage, percentage, sprite.modulate.a)

func get_info() -> Dictionary:
	return {
		"type": resource_type,
		"amount": current_amount,
		"max_amount": resource_amount,
		"depleted": is_depleted
	}

# Spawn dropped resources with physics
func spawn_dropped_resources(res_type: String, total_amount: int):
	var dropped_resource_scene = preload("res://scenes/environment/DroppedResource.tscn")
	
	# Spawn individual resource drops (1-3 per drop for spread)
	var remaining = total_amount
	while remaining > 0:
		var drop_amount = min(randi_range(1, 3), remaining)
		remaining -= drop_amount
		
		# Create dropped resource instance
		var dropped_resource = dropped_resource_scene.instantiate()
		dropped_resource.set_resource_data(res_type, drop_amount)
		
		# Position near the resource node with some randomization
		var spawn_pos = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		dropped_resource.global_position = spawn_pos
		
		# Add to the world
		get_tree().current_scene.add_child(dropped_resource)
