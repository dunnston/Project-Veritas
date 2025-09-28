extends Node2D
class_name RoomBounds

# Define room boundaries in world coordinates
# Based on tilemap analysis: tiles from (8,2) to (28,14) with 16px tiles
@export var room_min: Vector2 = Vector2(128, 32)    # Top-left corner (8*16, 2*16)
@export var room_max: Vector2 = Vector2(448, 224)   # Bottom-right corner (28*16, 14*16)
@export var room_name: String = "Bedroom"

# Margin from walls for building placement
@export var building_margin: float = 32.0

func _ready():
	# Add visual debug boundary in editor
	if Engine.is_editor_hint():
		queue_redraw()

func _draw():
	if Engine.is_editor_hint():
		# Draw room boundary rectangle in editor
		draw_rect(Rect2(room_min, room_max - room_min), Color.YELLOW, false, 2.0)
		# Draw building area (with margin)
		var building_min = room_min + Vector2(building_margin, building_margin)
		var building_max = room_max - Vector2(building_margin, building_margin)
		draw_rect(Rect2(building_min, building_max - building_min), Color.GREEN, false, 2.0)

func is_position_in_room(pos: Vector2) -> bool:
	return pos.x >= room_min.x and pos.x <= room_max.x and \
		   pos.y >= room_min.y and pos.y <= room_max.y

func is_position_valid_for_building(pos: Vector2, building_size: Vector2 = Vector2(64, 64)) -> bool:
	# Check if building would fit within room boundaries with margin
	var building_min = room_min + Vector2(building_margin, building_margin)
	var building_max = room_max - Vector2(building_margin, building_margin)
	
	var half_size = building_size * 0.5
	var building_rect_min = pos - half_size
	var building_rect_max = pos + half_size
	
	return building_rect_min.x >= building_min.x and \
		   building_rect_max.x <= building_max.x and \
		   building_rect_min.y >= building_min.y and \
		   building_rect_max.y <= building_max.y


func clamp_position_to_room(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, room_min.x, room_max.x),
		clamp(pos.y, room_min.y, room_max.y)
	)

func clamp_camera_to_room(camera_position: Vector2, viewport_size: Vector2, zoom: Vector2) -> Vector2:
	# Calculate the camera bounds based on viewport size and zoom
	var half_viewport = viewport_size * 0.5 / zoom
	
	var camera_min = room_min + half_viewport
	var camera_max = room_max - half_viewport
	
	return Vector2(
		clamp(camera_position.x, camera_min.x, camera_max.x),
		clamp(camera_position.y, camera_min.y, camera_max.y)
	)

func get_room_center() -> Vector2:
	return (room_min + room_max) * 0.5
