extends Node2D

@onready var player: AnimatedPlayer = $Player
@onready var instructions: RichTextLabel = $UI/Instructions

func _ready() -> void:
	if player:
		player.animation_finished.connect(_on_animation_finished)
		player.direction_changed.connect(_on_direction_changed)

func _process(_delta: float) -> void:
	if player and instructions:
		var current_anim = player.animated_sprite.animation
		var direction = player.get_direction_name()
		var state = "idle"
		
		if player.is_moving:
			state = "running" if player.is_sprinting else "walking"
		
		instructions.text = "[b]Animation Test Controls:[/b]
WASD - Move (Walking)
Shift+WASD - Sprint (Running) 
E - Pickup Animation (in tutorial)
Q - Drink Animation
Space - Jump Animation
Escape - Quit Test

[b]Current Animation:[/b] " + current_anim + "
[b]Direction:[/b] " + direction + "
[b]State:[/b] " + state + "
[b]Action Playing:[/b] " + str(player.action_playing)

func _input(event: InputEvent) -> void:
	if not player:
		return
		
	# Use physical key presses instead of action mappings for testing
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:  # Use physical_keycode for better compatibility
			KEY_SPACE:  # Space for jump
				print("Space pressed - triggering jump")
				if not player.action_playing:
					player.play_jump_animation()
			KEY_Q:  # Q for drink
				print("Q pressed - triggering drink")
				if not player.action_playing:
					player.play_drink_animation()
			KEY_ESCAPE:  # Escape to quit
				print("Escape pressed - quitting")
				get_tree().quit()
			KEY_E:  # E for pickup (testing)
				print("E pressed - triggering pickup")
				if not player.action_playing:
					player.play_pickup_animation()

func _on_animation_finished(anim_name: String) -> void:
	print("Animation finished: ", anim_name)

func _on_direction_changed(new_direction) -> void:
	print("Direction changed to: ", new_direction)