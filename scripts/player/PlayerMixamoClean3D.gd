extends CharacterBody3D

@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 8.0
@export var mouse_sensitivity: float = 0.002

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var character_model: Node3D
var animation_player: AnimationPlayer
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO
var current_anim: String = ""

# Available animations mapped from files
var idle_anim: String = ""
var walk_anim: String = ""
var run_anim: String = ""
var jump_anim: String = ""

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("setup_character")

func setup_character():
	var mixamo_files = get_mixamo_files()

	if mixamo_files.size() > 0:
		print("Found Mixamo files: ", mixamo_files)
		load_character(mixamo_files[0])
		if animation_player:
			map_animations()
			start_animation()
	else:
		print("No Mixamo files found")

func get_mixamo_files():
	var files = []
	var dir = DirAccess.open("res://assets/models/")

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".fbx"):
				files.append("res://assets/models/" + file_name)
			file_name = dir.get_next()

	return files

func load_character(file_path: String):
	print("Loading: ", file_path)
	var scene = load(file_path)
	if scene:
		character_model = scene.instantiate()
		add_child(character_model)
		character_model.position = Vector3.ZERO
		character_model.rotation = Vector3(0, PI, 0)

		animation_player = find_animation_player(character_model)
		if animation_player:
			print("Found AnimationPlayer with animations: ", animation_player.get_animation_list())
		else:
			print("No AnimationPlayer found")

func find_animation_player(node: Node):
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = find_animation_player(child)
		if result:
			return result

	return null

func map_animations():
	var all_anims = animation_player.get_animation_list()
	print("Mapping animations: ", all_anims)

	for anim_name in all_anims:
		var lower = anim_name.to_lower()

		if "idle" in lower or "breathing" in lower:
			idle_anim = anim_name
			print("Idle: ", anim_name)
		elif "walk" in lower:
			walk_anim = anim_name
			print("Walk: ", anim_name)
		elif "run" in lower:
			run_anim = anim_name
			print("Run: ", anim_name)
		elif "jump" in lower:
			jump_anim = anim_name
			print("Jump: ", anim_name)

func start_animation():
	var first_anim = ""

	if idle_anim != "":
		first_anim = idle_anim
	elif walk_anim != "":
		first_anim = walk_anim
	elif run_anim != "":
		first_anim = run_anim
	else:
		var all_anims = animation_player.get_animation_list()
		if all_anims.size() > 0:
			first_anim = all_anims[0]

	if first_anim != "":
		print("Starting animation: ", first_anim)
		animation_player.play(first_anim)
		current_anim = first_anim
	else:
		print("No animations to play!")

func play_anim(anim_name: String):
	if animation_player and anim_name != "" and anim_name != current_anim:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
			current_anim = anim_name
			print("Playing: ", anim_name)

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
	apply_camera_rotation(delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	handle_movement(delta)
	update_animations()
	rotate_character()

	move_and_slide()

func apply_camera_rotation(delta: float):
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, camera_rotation.x, 10.0 * delta)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, camera_rotation.y, 10.0 * delta)

func handle_movement(delta: float):
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")
	input_dir = input_dir.normalized()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction = Vector3.ZERO
	if input_dir.length() > 0:
		var cam_transform = camera_pivot.global_transform
		var forward = -cam_transform.basis.z
		var right = cam_transform.basis.x

		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()

		direction = forward * input_dir.y + right * input_dir.x
		direction = direction.normalized()
		last_direction = direction

	var target_speed = walk_speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	elif input_dir.length() > 0.5:
		target_speed = run_speed

	if direction.length() > 0:
		velocity.x = lerp(velocity.x, direction.x * target_speed, 10.0 * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, 10.0 * delta)
		movement_speed = lerp(movement_speed, target_speed / sprint_speed, 10.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)
		movement_speed = lerp(movement_speed, 0.0, 10.0 * delta)

func update_animations():
	if not animation_player:
		return

	var target_anim = ""

	if not is_on_floor() and velocity.y > 0 and jump_anim != "":
		target_anim = jump_anim
	elif movement_speed > 0.2:
		if movement_speed > 0.7 and run_anim != "":
			target_anim = run_anim
		elif walk_anim != "":
			target_anim = walk_anim
	else:
		if idle_anim != "":
			target_anim = idle_anim

	if target_anim != "":
		play_anim(target_anim)

func rotate_character():
	if character_model and last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation, 0.15)