extends StaticBody2D

class_name Building

signal building_destroyed()
signal building_interacted(player: Node)

@export var building_id: String = ""
@export var max_health: int = 100

var current_health: int
var building_data: Dictionary = {}

var sprite: ColorRect
var collision_shape: CollisionShape2D
var interaction_area: Area2D

func _ready() -> void:
	# Get node references
	sprite = get_node("ColorRect")
	collision_shape = get_node("CollisionShape2D")
	interaction_area = get_node("InteractionArea")
	
	add_to_group("buildings")
	add_to_group("interactables")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

func setup(id: String) -> void:
	building_id = id
	building_data = BuildingManager.building_data.get(id, {})
	current_health = building_data.get("max_health", max_health)
	
	update_appearance()

func update_appearance() -> void:
	if not sprite or building_data.is_empty():
		return
	
	# Set color based on building type
	match building_id:
		"workbench":
			sprite.color = Color(0.8, 0.6, 0.2, 1)
		"storage_box":
			sprite.color = Color(0.6, 0.4, 0.8, 1)
		"basic_wall":
			sprite.color = Color(0.7, 0.7, 0.7, 1)
		_:
			sprite.color = Color(0.5, 0.5, 0.8, 1)
	
	var size = building_data.get("size", {"x": 1, "y": 1})
	
	# Update sprite size
	var sprite_size = Vector2(
		size.x * BuildingManager.GRID_SIZE,
		size.y * BuildingManager.GRID_SIZE
	)
	sprite.size = sprite_size
	sprite.position = -sprite_size / 2
	
	# Update collision shape
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = sprite_size

func interact(player: Node) -> void:
	building_interacted.emit(player)
	
	match building_id:
		"workbench":
			open_crafting_interface(player)
		"storage_box":
			open_storage_interface(player)
		_:
			print("Interacted with " + building_id)

func open_crafting_interface(_player: Node) -> void:
	print("Opening crafting interface for workbench")

func open_storage_interface(_player: Node) -> void:
	print("Opening storage interface for storage box")

func take_damage(amount: int) -> void:
	current_health = max(0, current_health - amount)
	update_damage_visual()
	
	if current_health <= 0:
		destroy_building()

func update_damage_visual() -> void:
	if not sprite:
		return
	
	var health_percentage = float(current_health) / float(max_health)
	sprite.modulate = Color(1, health_percentage, health_percentage)

func destroy_building() -> void:
	building_destroyed.emit()
	
	var grid_pos = BuildingManager.snap_to_grid(global_position)
	BuildingManager.remove_building(grid_pos)
	
	queue_free()

func _on_interaction_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player near " + building_id)

func _on_interaction_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("Player left " + building_id)

func get_building_info() -> Dictionary:
	return {
		"id": building_id,
		"health": current_health,
		"max_health": max_health,
		"position": global_position,
		"data": building_data
	}
