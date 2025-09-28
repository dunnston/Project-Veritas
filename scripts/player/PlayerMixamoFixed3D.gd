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

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	setup_character_and_animations()
	print("Mixamo animated player character loaded successfully!")

func setup_character_and_animations():
	var mixamo_files = find_mixamo_files()

	if mixamo_files.size() > 0:
		print("Found ", mixamo_files.size(), " Mixamo files")
		load_character_from_mixamo(mixamo_files[0])
		if animation_player:
			load_all_animations(mixamo_files)
	else:
		print("No Mixamo files found, using fallback character")
		load_fallback_character()

func find_mixamo_files():
	var files = []
	var dir = DirAccess.open("res://assets/models/")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".fbx"):
				files.append("res://assets/models/" + file_name)
				print("Found Mixamo file: ", file_name)
			file_name = dir.get_next()

	return files

func load_character_from_mixamo(file_path: String):
	print("Loading character from: ", file_path)
	var scene = load(file_path)
	if scene:
		character_model = scene.instantiate()
		add_child(character_model)
		character_model.position = Vector3.ZERO
		character_model.rotation = Vector3(0, PI, 0)

		animation_player = find_animation_player(character_model)
		if animation_player:
			print("Found AnimationPlayer with ", animation_player.get_animation_list().size(), " animations")
			# Play first animation immediately
			var anims = animation_player.get_animation_list()
			if anims.size() > 0:
				print("Playing animation: ", anims[0])
				animation_player.play(anims[0])
				current_anim = anims[0]
		else:
			print("No AnimationPlayer found in Mixamo file")

func load_fallback_character():
	var fallback_path = "res://3d Assets/POLYGON_Prototype_SourceFiles_v4/SourceFiles/Characters/SK_Character_Dummy_Male_01.fbx"
	if ResourceLoader.exists(fallback_path):
		print("Loading fallback character")
		load_character_from_mixamo(fallback_path)

func find_animation_player(node: Node):
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = find_animation_player(child)
		if result:
			return result

	return null

func load_all_animations(file_paths):
	if not animation_player:
		return

	print("Loading additional animations from ", file_paths.size(), " files")
	var anim_library = AnimationLibrary.new()

	for file_path in file_paths:
		load_single_animation(file_path, anim_library)

	if anim_library.get_animation_list().size() > 0:
		animation_player.add_animation_library("mixamo", anim_library)
		print("Added animation library with ", anim_library.get_animation_list().size(), " animations")

func load_single_animation(file_path: String, library: AnimationLibrary):
	var scene = load(file_path)
	if not scene:
		return

	var instance = scene.instantiate()
	var anim_player = find_animation_player(instance)

	if anim_player:
		var anims = anim_player.get_animation_list()
		for anim_name in anims:
			var animation = anim_player.get_animation(anim_name)
			var file_name = file_path.get_file().get_basename()
			var new_name = map_animation_name(file_name)

			if new_name == "":
				new_name = file_name

			library.add_animation(new_name, animation)
			print("Loaded animation: ", new_name)

	instance.queue_free()

func map_animation_name(file_name: String):
	var lower_name = file_name.to_lower()

	if "idle" in lower_name or "breathing" in lower_name:
		return "idle"
	elif "walk" in lower_name:
		return "walk"
	elif "run" in lower_name:
		return "run"
	elif "jump" in lower_name:
		return "jump"
	elif "fall" in lower_name:
		return "fall"

	return ""

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

	# Simple animation selection
	if not is_on_floor():
		target_anim = get_best_animation(["jump", "fall"])
	elif movement_speed > 0.1:
		if movement_speed > 0.6:
			target_anim = get_best_animation(["run"])
		else:
			target_anim = get_best_animation(["walk"])
	else:
		target_anim = get_best_animation(["idle"])

	if target_anim != "" and target_anim != current_anim:
		print("Switching to animation: ", target_anim)
		animation_player.play(target_anim)
		current_anim = target_anim

func get_best_animation(keywords):
	# Check mixamo library first
	var mixamo_lib = animation_player.get_animation_library("mixamo")
	if mixamo_lib:
		for keyword in keywords:
			if mixamo_lib.has_animation(keyword):
				return "mixamo/" + keyword

	# Check default animations
	for keyword in keywords:
		if animation_player.has_animation(keyword):
			return keyword

	# Return first available animation
	var anims = animation_player.get_animation_list()
	if anims.size() > 0:
		return anims[0]

	return ""

func rotate_character_model():
	if character_model and last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)