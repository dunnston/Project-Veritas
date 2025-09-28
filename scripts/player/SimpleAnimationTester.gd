extends Node2D

@onready var player: AnimatedPlayer = $Player

func _ready() -> void:
	print("=== ANIMATION TEST SCENE LOADED ===")
	print(">>> LOOKING FOR PLAYER NODE <<<")
	
	if player:
		print("✅ Player found successfully!")
		print("Player type: ", player.get_class())
		print("Player name: ", player.name)
	else:
		print("❌ ERROR: Player node not found!")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		print("🎮 KEY PRESSED: ", event.physical_keycode)
		
		match event.physical_keycode:
			KEY_E:
				print("🔥 E KEY - Testing pickup animation")
				if player and player.has_method("play_pickup_animation"):
					player.play_pickup_animation()
				else:
					print("❌ Player or method not found")
					
			KEY_SPACE:
				print("🚀 SPACE KEY - Testing jump animation")
				if player and player.has_method("play_jump_animation"):
					player.play_jump_animation()
				else:
					print("❌ Player or method not found")
					
			KEY_Q:
				print("🥤 Q KEY - Testing drink animation")
				if player and player.has_method("play_drink_animation"):
					player.play_drink_animation()
				else:
					print("❌ Player or method not found")
					
			KEY_ESCAPE:
				print("🚪 ESCAPE - Quitting test")
				get_tree().quit()