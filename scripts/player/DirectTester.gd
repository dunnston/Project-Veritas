extends Node2D

@onready var player: AnimatedPlayer = $Player

func _ready() -> void:
	print("=== DIRECT PLAYER TEST STARTING ===")
	print(">>> IF YOU CAN SEE THIS MESSAGE, OUTPUT IS WORKING <<<")
	print("=== LOOK FOR MORE MESSAGES WHEN PRESSING KEYS ===")
	if player:
		print("Player found: ", player.name, " of type: ", player.get_class())
		print("Player has methods:", )
		var methods = []
		if player.has_method("play_pickup_animation"):
			methods.append("play_pickup_animation")
		if player.has_method("play_jump_animation"):
			methods.append("play_jump_animation")
		if player.has_method("play_drink_animation"):
			methods.append("play_drink_animation")
		print("Methods: ", methods)
	else:
		print("ERROR: Player not found!")
	
	print("Press keys to test animations. All key presses will be logged.")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("Key pressed: ", event.physical_keycode, " (", event.keycode, ")")
		match event.physical_keycode:
			KEY_E:
				print("E pressed - calling pickup animation")
				if player:
					if player.has_method("play_pickup_animation"):
						print("Player has play_pickup_animation method - calling it")
						player.play_pickup_animation()
					else:
						print("ERROR: Player does not have play_pickup_animation method")
				else:
					print("ERROR: Player is null!")
			KEY_SPACE:
				print("Space pressed - calling jump animation") 
				if player:
					if player.has_method("play_jump_animation"):
						print("Player has play_jump_animation method - calling it")
						player.play_jump_animation()
					else:
						print("ERROR: Player does not have play_jump_animation method")
				else:
					print("ERROR: Player is null!")
			KEY_Q:
				print("Q pressed - calling drink animation")
				if player:
					if player.has_method("play_drink_animation"):
						print("Player has play_drink_animation method - calling it")
						player.play_drink_animation()
					else:
						print("ERROR: Player does not have play_drink_animation method")
				else:
					print("ERROR: Player is null!")
			KEY_ESCAPE:
				print("Escape pressed - quitting")
				get_tree().quit()
		print("Input handled")