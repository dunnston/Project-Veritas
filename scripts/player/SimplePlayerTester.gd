extends Node2D

@onready var player: AnimatedPlayer = $Player
@onready var label: Label = $UI/Label

func _ready() -> void:
	print("Simple Player Test Started")
	if player:
		print("Player found and ready")
	else:
		print("ERROR: Player not found!")

func _input(event: InputEvent) -> void:
	if not player:
		return
	
	# Handle key presses for testing animations
	if event is InputEventKey and event.pressed:
		print("Key pressed: ", event.physical_keycode)
		
		match event.physical_keycode:
			4194309:  # Space key
				print("SPACE: Triggering jump animation")
				if not player.action_playing:
					player.play_jump_animation()
				else:
					print("Player is busy with: ", player.animated_sprite.animation)
					
			81:  # Q key  
				print("Q: Triggering drink animation")
				if not player.action_playing:
					player.play_drink_animation()
				else:
					print("Player is busy with: ", player.animated_sprite.animation)
					
			69:  # E key
				print("E: Triggering pickup animation")
				if not player.action_playing:
					player.play_pickup_animation()
				else:
					print("Player is busy with: ", player.animated_sprite.animation)
					
			4194305:  # Escape key
				print("ESC: Quitting test")
				get_tree().quit()

func _process(_delta: float) -> void:
	if player and label:
		var current_anim = player.animated_sprite.animation if player.animated_sprite else "none"
		var is_busy = player.action_playing if player else false
		
		label.text = "Simple Animation Test
WASD = Move
Shift = Sprint  
E = Pickup
Q = Drink
Space = Jump
Esc = Quit

Current: " + current_anim + "
Action Playing: " + str(is_busy)