extends CharacterBody3D

@export_group("Movement Settings")
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 8.0
@export var crouch_speed: float = 1.5
@export var acceleration: float = 10.0
@export var friction: float = 10.0
@export var air_control: float = 0.3

@export_group("Camera Settings")
@export var mouse_sensitivity: float = 0.002
@export var camera_smoothing: float = 15.0

@export_group("Animation Files")
@export var character_model_path: String = "res://assets/models/"
@export var idle_animation_path: String = ""
@export var walk_animation_path: String = ""
@export var run_animation_path: String = ""
@export var jump_animation_path: String = ""

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var character_model: Node3D
var animation_player: AnimationPlayer

var is_sprinting: bool = false
var is_crouching: bool = false
var is_running: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO

var current_anim: String = ""
var was_on_floor: bool = false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	setup_character_and_animations()
	print("Mixamo animated player character loaded successfully!")

func setup_character_and_animations():
	# Load character model (try to find one in the assets/models folder)
	var character_files = find_mixamo_files()

	if character_files.size() > 0:
		print("Found ", character_files.size(), " Mixamo files")
		# Try to load character from first animation file (they should all have the same character)
		load_character_model(character_files[0])
		load_animations(character_files)
	else:
		print("No Mixamo files found in assets/models folder")
		# Fallback to the original character model
		load_fallback_character()

func find_mixamo_files() -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open("res://assets/models/")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".fbx") or file_name.ends_with(".glb"):
				files.append("res://assets/models/" + file_name)
				print("Found animation file: ", file_name)
			file_name = dir.get_next()

	return files

func load_character_model(file_path: String):
	print("Loading character from: ", file_path)
	var scene = load(file_path)
	if scene:
		character_model = scene.instantiate()
		add_child(character_model)
		character_model.transform = Transform3D.IDENTITY
		character_model.position = Vector3.ZERO
		character_model.rotation = Vector3(0, PI, 0)  # Face forward

		# Find AnimationPlayer in the model
		animation_player = find_child_recursive(character_model, "AnimationPlayer") as AnimationPlayer

		if animation_player:
			print("Found AnimationPlayer in: ", file_path)
			print("AnimationPlayer has ", animation_player.get_animation_list().size(), " animations")
		else:
			print("No AnimationPlayer found in: ", file_path)
	else:
		print("Failed to load scene from: ", file_path)

func load_fallback_character():
	print("Loading fallback character model")
	var fallback_path = "res://3d Assets/POLYGON_Prototype_SourceFiles_v4/SourceFiles/Characters/SK_Character_Dummy_Male_01.fbx"
	if ResourceLoader.exists(fallback_path):
		load_character_model(fallback_path)
	else:
		print("Fallback character not found at: ", fallback_path)

func load_animations(file_paths: Array[String]):
	if not animation_player:
		print("No animation player available for loading animations")
		return

	print("Loading animations from ", file_paths.size(), " files")

	# Check if animation player already has animations from the character model
	var existing_anims = animation_player.get_animation_list()
	if existing_anims.size() > 0:
		print("Character already has ", existing_anims.size(), " animations:")
		for anim_name in existing_anims:
			print("  - ", anim_name)

		# Play first existing animation
		play_animation(existing_anims[0])
		return

	# Create a new animation library for our animations
	var anim_library = AnimationLibrary.new()

	# Load animations from each file
	for file_path in file_paths:
		load_animation_from_file(file_path, anim_library)

	# Add the library to our animation player
	if anim_library.get_animation_list().size() > 0:
		print("Adding animation library with ", anim_library.get_animation_list().size(), " animations")
		animation_player.add_animation_library("mixamo", anim_library)

		# Play first animation to get out of T-pose
		var animations = anim_library.get_animation_list()
		if animations.size() > 0:
			var first_anim = "mixamo/" + animations[0]
			print("Playing first animation: ", first_anim)
			play_animation(first_anim)
	else:
		print("No animations were loaded from files")

func load_animation_from_file(file_path: String, library: AnimationLibrary):
	var scene = load(file_path)
	if not scene:
		return

	var instance = scene.instantiate()
	var anim_player = find_child_recursive(instance, "AnimationPlayer") as AnimationPlayer

	if anim_player:
		var source_library = anim_player.get_animation_library("")
		if source_library:
			var animations = source_library.get_animation_list()
			for anim_name in animations:
				var animation = source_library.get_animation(anim_name)
				var file_name = file_path.get_file().get_basename()

				# Name animations based on file name or content
				var new_name = get_animation_name_from_file(file_name)
				if new_name == "":
					new_name = file_name

				library.add_animation(new_name, animation)
				print("Loaded animation: ", new_name, " from ", file_name)

	instance.queue_free()

func get_animation_name_from_file(file_name: String) -> String:
	var lower_name = file_name.to_lower()

	# Map common Mixamo animation names
	if "idle" in lower_name or "standing" in lower_name:
		return "idle"
	elif "walk" in lower_name and "back" not in lower_name:
		return "walk"
	elif "run" in lower_name or "jog" in lower_name:
		return "run"
	elif "jump" in lower_name:
		return "jump"
	elif "fall" in lower_name:
		return "fall"

	return ""

func find_child_recursive(node: Node, class_name: String) -> Node:
	if node.get_class() == class_name:
		return node

	for child in node.get_children():
		var result = find_child_recursive(child, class_name)
		if result:
			return result

	return null

func play_animation(anim_name: String):
	if animation_player and animation_player.has_animation(anim_name) and current_anim != anim_name:
		animation_player.play(anim_name)
		current_anim = anim_name
		print("Playing animation: ", anim_name)

func _input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.x * mouse_sensitivity
		camera_rotation.y -= event.relative.y * mouse_sensitivity
		camera_rotation.y = clamp(camera_rotation.y, -1.4, 1.4)

	if event.is_action_pressed("menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float):
	handle_movement_state()
	apply_camera_rotation(delta)

	was_on_floor = is_on_floor()

	if not is_on_floor():
		velocity += get_gravity() * delta

	handle_jump()
	handle_movement(delta)
	update_animations()
	rotate_character_model()

	move_and_slide()

func handle_movement_state():
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching
	is_crouching = Input.is_action_pressed("crouch")
	is_running = not is_sprinting and not is_crouching

	if is_crouching:
		var shape = collision_shape.shape as CapsuleShape3D
		shape.height = 1.0
		collision_shape.position.y = 0.5
		camera_pivot.position.y = 1.0
	else:
		var shape = collision_shape.shape as CapsuleShape3D
		shape.height = 1.8
		collision_shape.position.y = 0.9
		camera_pivot.position.y = 1.5

func apply_camera_rotation(delta: float):
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, camera_rotation.x, camera_smoothing * delta)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, camera_rotation.y, camera_smoothing * delta)

func handle_jump():
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

func handle_movement(delta: float):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_forward", "move_backward")
	input_vector = input_vector.normalized()

	var direction = Vector3.ZERO
	if input_vector.length() > 0:
		direction = transform.basis * Vector3(input_vector.x, 0, input_vector.y)
		direction = direction.rotated(Vector3.UP, camera_pivot.rotation.y)
		direction = direction.normalized()
		last_direction = direction

	var target_speed = walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_running and input_vector.length() > 0.5:
		target_speed = run_speed
	elif is_crouching:
		target_speed = crouch_speed

	var control_factor = 1.0 if is_on_floor() else air_control

	if direction.length() > 0:
		velocity.x = lerp(velocity.x, direction.x * target_speed, acceleration * control_factor * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, acceleration * control_factor * delta)
		movement_speed = lerp(movement_speed, target_speed / sprint_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * control_factor * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * control_factor * delta)
		movement_speed = lerp(movement_speed, 0.0, friction * delta)

func update_animations():
	if not animation_player:
		return

	var target_anim = ""

	# Determine which animation to play
	if not is_on_floor():
		if velocity.y > 0:
			target_anim = "mixamo/jump"
		else:
			target_anim = "mixamo/fall"
	elif movement_speed > 0.1:
		if movement_speed > 0.6:
			target_anim = "mixamo/run"
		else:
			target_anim = "mixamo/walk"
	else:
		target_anim = "mixamo/idle"

	# Fallback to any available animation if specific one not found
	if not animation_player.has_animation(target_anim):
		# Try without mixamo prefix
		var simple_name = target_anim.split("/")[1] if "/" in target_anim else target_anim
		if animation_player.has_animation(simple_name):
			target_anim = simple_name
		else:
			# Use first available animation
			var library = animation_player.get_animation_library("mixamo")
			if library and library.get_animation_list().size() > 0:
				target_anim = "mixamo/" + library.get_animation_list()[0]

	play_animation(target_anim)

func rotate_character_model():
	if character_model and last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)
