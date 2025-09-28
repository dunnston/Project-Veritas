extends Node2D

class_name SpawnPoint

@export var spawn_point_name: String = "default"
@export var facing_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	add_to_group("spawn_points")
	
	# Check if this is the spawn point we should use
	var spawn_data = get_tree().get_meta("spawn_data", null)
	if spawn_data and spawn_data.has("spawn_point"):
		if spawn_data.spawn_point == spawn_point_name:
			spawn_player_here()
			# Clear the spawn data
			get_tree().remove_meta("spawn_data")

func spawn_player_here():
	# Wait a frame for the scene to fully load
	await get_tree().process_frame
	
	# Find the player in the scene
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = global_position
		print("Player spawned at %s (position: %s)" % [spawn_point_name, global_position])
		
		# Set facing direction if the player has a method for it
		if player.has_method("set_facing_direction"):
			player.set_facing_direction(facing_direction)
	else:
		print("Warning: Player not found for spawn point %s" % spawn_point_name)

# Debug visualization
func _draw():
	if Engine.is_editor_hint():
		# Draw spawn point indicator in editor
		draw_circle(Vector2.ZERO, 20, Color.BLUE)
		draw_line(Vector2.ZERO, facing_direction * 30, Color.RED, 3)
