extends Node2D

class_name BuildingGhost

var building_id: String = ""
var is_valid_placement: bool = false
var grid_size: int = BuildingManager.GRID_SIZE

@onready var sprite: Sprite2D = $Sprite2D
@onready var area_2d: Area2D = $Area2D

func _ready() -> void:
	modulate = Color(0, 1, 0, 0.5)
	
	if area_2d:
		area_2d.body_entered.connect(_on_body_entered)
		area_2d.body_exited.connect(_on_body_exited)

func setup(building_data: Dictionary) -> void:
	building_id = building_data.get("id", "")
	
	if sprite and building_data.has("texture"):
		sprite.texture = load(building_data["texture"])

func _process(_delta: float) -> void:
	var mouse_pos = get_global_mouse_position()
	var snapped_pos = BuildingManager.snap_to_grid(mouse_pos)
	global_position = snapped_pos
	
	update_placement_validity()

func update_placement_validity() -> void:
	is_valid_placement = BuildingManager.can_place_building(building_id, global_position)
	
	if is_valid_placement:
		modulate = Color(0, 1, 0, 0.5)
	else:
		modulate = Color(1, 0, 0, 0.5)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("buildings") or body.is_in_group("player"):
		is_valid_placement = false
		update_placement_validity()

func _on_body_exited(body: Node2D) -> void:
	update_placement_validity()

func place_building() -> bool:
	if is_valid_placement:
		return BuildingManager.place_building(building_id, global_position)
	return false