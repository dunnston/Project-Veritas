extends Camera2D
class_name RoomCamera

var room_bounds: RoomBounds = null
var target_node: Node2D = null

func _ready():
	# Find room bounds in the scene
	find_room_bounds()
	
	# Find the target node (usually the player)
	if get_parent().is_in_group("player"):
		target_node = get_parent()

func find_room_bounds():
	var scene = get_tree().current_scene
	if scene:
		var bounds_nodes = scene.find_children("*", "RoomBounds", false, false)
		if bounds_nodes.size() > 0:
			room_bounds = bounds_nodes[0] as RoomBounds
			# Found room bounds

func _process(_delta):
	if target_node and room_bounds:
		# Get the target position
		var target_position = target_node.global_position
		
		# Calculate camera limits based on room bounds and viewport
		var viewport = get_viewport()
		if not viewport:
			return
			
		var viewport_size = viewport.get_visible_rect().size
		if viewport_size.x <= 0 or viewport_size.y <= 0:
			return
			
		# Safety check for zoom
		if zoom.x <= 0 or zoom.y <= 0:
			zoom = Vector2.ONE
			
		var half_viewport = viewport_size / (zoom * 2.0)
		
		# Calculate bounds to keep camera view within room
		var min_pos = room_bounds.room_min + half_viewport
		var max_pos = room_bounds.room_max - half_viewport
		
		# Clamp the target position
		var clamped_position = Vector2(
			clamp(target_position.x, min_pos.x, max_pos.x),
			clamp(target_position.y, min_pos.y, max_pos.y)
		)
		
		# Apply position
		global_position = clamped_position

func set_target(new_target: Node2D):
	target_node = new_target

func set_room_bounds(new_bounds: RoomBounds):
	room_bounds = new_bounds
