extends Node2D

# Minimal test to check if AnimatedPlayer loads at all

func _ready() -> void:
	print("=== MINIMAL PLAYER TEST ===")
	
	# Try to load the player scene directly
	var player_scene = load("res://scenes/player/Player.tscn")
	if not player_scene:
		print("ERROR: Could not load player scene!")
		return
	
	print("Player scene loaded successfully")
	
	# Try to instantiate it
	var player = player_scene.instantiate()
	if not player:
		print("ERROR: Could not instantiate player!")
		return
		
	print("Player instantiated successfully")
	print("Player type: ", player.get_class())
	print("Player script: ", player.get_script())
	
	# Add to scene
	player.position = Vector2(400, 300)
	add_child(player)
	
	print("Player added to scene")
	
	# Wait a frame for _ready to be called
	await get_tree().process_frame
	
	# Check if it has the AnimatedSprite2D
	var animated_sprite = player.get_node("AnimatedSprite2D")
	if not animated_sprite:
		print("ERROR: No AnimatedSprite2D found!")
		return
		
	print("AnimatedSprite2D found")
	
	# Check if sprite_frames is set
	if not animated_sprite.sprite_frames:
		print("ERROR: No sprite_frames found!")
		return
		
	print("SpriteFrames found")
	print("Available animations: ", animated_sprite.sprite_frames.get_animation_names())
	
	# Try to play an animation
	if animated_sprite.sprite_frames.has_animation("idle_south"):
		animated_sprite.play("idle_south")
		print("Playing idle_south animation")
	else:
		print("ERROR: idle_south animation not found!")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.physical_keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.physical_keycode == KEY_SPACE:
			print("Space pressed - trying manual animation test")
			var player = get_child(1)  # Should be the player
			if player and player.has_method("play_jump_animation"):
				print("Calling play_jump_animation...")
				player.play_jump_animation()
			else:
				print("No play_jump_animation method found!")