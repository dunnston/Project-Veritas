extends Node

# Removed class_name to avoid conflict with autoload singleton

static func create_character(description: String, n_directions: int = 8) -> PackedScene:
	var character_scene = PackedScene.new()
	var root = CharacterBody2D.new()
	root.name = "Character"
	
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	root.add_child(animated_sprite)
	animated_sprite.owner = root
	
	var sprite_frames = SpriteFrames.new()
	
	var directions = get_direction_names(n_directions)
	for direction in directions:
		sprite_frames.add_animation("walk_" + direction)
		sprite_frames.add_animation("idle_" + direction)
		sprite_frames.add_animation("attack_" + direction)
	
	sprite_frames.add_animation("tongue_attack")
	sprite_frames.add_animation("death")
	
	animated_sprite.sprite_frames = sprite_frames
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = CapsuleShape2D.new()
	shape.radius = 16
	shape.height = 48
	collision_shape.shape = shape
	root.add_child(collision_shape)
	collision_shape.owner = root
	
	if description.contains("purple beast"):
		var script = load("res://scripts/enemies/PurpleBeast.gd")
		root.set_script(script)
		root.modulate = Color(0.7, 0.3, 0.9, 1.0)
		
		var staff_sprite = Sprite2D.new()
		staff_sprite.name = "StaffSprite"
		staff_sprite.position = Vector2(20, 0)
		root.add_child(staff_sprite)
		staff_sprite.owner = root
	
	character_scene.pack(root)
	return character_scene

static func get_direction_names(n_directions: int) -> Array:
	if n_directions == 4:
		return ["north", "south", "east", "west"]
	elif n_directions == 8:
		return ["north", "northeast", "east", "southeast", 
				"south", "southwest", "west", "northwest"]
	else:
		push_error("Unsupported number of directions: " + str(n_directions))
		return []

static func create_purple_beast() -> Node:
	var beast = PurpleBeast.new()
	beast.name = "PurpleBeast"
	
	var animated_sprite = AnimatedSprite2D.new()
	animated_sprite.name = "AnimatedSprite2D"
	
	var sprite_frames = SpriteFrames.new()
	var directions = get_direction_names(8)
	
	for direction in directions:
		sprite_frames.add_animation("walk_" + direction)
		sprite_frames.set_animation_speed("walk_" + direction, 8.0)
		
		sprite_frames.add_animation("exhausted_" + direction)
		sprite_frames.set_animation_speed("exhausted_" + direction, 4.0)
	
	sprite_frames.add_animation("tongue_attack")
	sprite_frames.set_animation_speed("tongue_attack", 10.0)
	
	animated_sprite.sprite_frames = sprite_frames
	beast.add_child(animated_sprite)
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var shape = CapsuleShape2D.new()
	shape.radius = 20
	shape.height = 60
	collision_shape.shape = shape
	beast.add_child(collision_shape)
	
	var staff_sprite = Sprite2D.new()
	staff_sprite.name = "StaffSprite"
	staff_sprite.position = Vector2(25, -5)
	staff_sprite.modulate = Color(0.5, 0.3, 0.2, 1.0)
	beast.add_child(staff_sprite)
	
	var detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	var detection_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 250.0
	detection_shape.shape = circle
	detection_area.add_child(detection_shape)
	beast.add_child(detection_area)
	
	return beast
