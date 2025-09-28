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
var animation_transition_time: float = 0.2
var last_animation_change: float = 0.0

# Available animations
var available_animations = {
	"idle": "",
	"walk": "",
	"run": "",
	"jump": ""
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	setup_character_and_animations()
	print("Improved Mixamo player character loaded successfully!")

func setup_character_and_animations():
	var mixamo_files = find_mixamo_files()

	if mixamo_files.size() > 0:
		print("Found ", mixamo_files.size(), " Mixamo files")
		load_character_from_mixamo(mixamo_files[0])
		if animation_player:
			map_available_animations()
			# Start with ANY available animation to get out of T-pose
			start_initial_animation()
	else:
		print("No Mixamo files found, using fallback")

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
			# Configure animation player for better blending
			animation_player.playback_default_blend_time = animation_transition_time
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

func map_available_animations():
	if not animation_player:
		print("ERROR: No animation player to map animations")
		return

	var all_animations = animation_player.get_animation_list()
	print("Found ", all_animations.size(), " animations to map: ", all_animations)

	# Reset mappings
	for key in available_animations.keys():
		available_animations[key] = ""

	for anim_name in all_animations:
		var lower_name = anim_name.to_lower()
		print("Checking animation: ", anim_name, " (", lower_name, ")")

		if "idle" in lower_name or "breathing" in lower_name:
			available_animations["idle"] = anim_name
			print("✓ Mapped idle: ", anim_name)
		elif "walk" in lower_name:
			available_animations["walk"] = anim_name
			print("✓ Mapped walk: ", anim_name)
		elif "run" in lower_name:
			available_animations["run"] = anim_name
			print("✓ Mapped run: ", anim_name)
		elif "jump" in lower_name:
			available_animations["jump"] = anim_name
			print("✓ Mapped jump: ", anim_name)
		else:
			print("? Unmapped animation: ", anim_name)

	# Print final mapping
	print("Final animation mapping:")
	for key in available_animations.keys():
		if available_animations[key] != "":
			print("  ", key, " → ", available_animations[key])
		else:
			print("  ", key, " → [NOT FOUND]")

func start_initial_animation():
	if not animation_player:
		print("ERROR: No animation player for initial animation")
		return

	var all_animations = animation_player.get_animation_list()
	if all_animations.size() == 0:
		print("ERROR: No animations available!")
		return

	# Try to play idle first
	if available_animations["idle"] != "":
		print("Starting with idle animation: ", available_animations["idle"])
		animation_player.play(available_animations["idle"])
		current_anim = available_animations["idle"]
	else:
		# Just play the first available animation
		print("No idle found, playing first animation: ", all_animations[0])
		animation_player.play(all_animations[0])
		current_anim = all_animations[0]

func play_animation_smooth(anim_name: String):
	if not animation_player:
		print("ERROR: No animation player for smooth play")
		return

	if anim_name == "":
		print("WARNING: Empty animation name provided")
		return

	if anim_name == current_anim:
		return  # Already playing this animation

	if not animation_player.has_animation(anim_name):
		print("ERROR: Animation not found: ", anim_name)
		return

	print("Playing animation: ", anim_name)
	animation_player.play(anim_name, animation_transition_time)
	current_anim = anim_name

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
	rotate_character_to_movement()

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
		# Play jump animation immediately when jumping
		if available_animations["jump"] != "":
			play_animation_smooth(available_animations["jump"])

func handle_movement(delta: float):
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_forward", "move_backward")
	input_vector = input_vector.normalized()

	var direction = Vector3.ZERO
	if input_vector.length() > 0:
		# Calculate movement direction relative to camera
		var cam_transform = camera_pivot.global_transform
		var cam_forward = -cam_transform.basis.z
		var cam_right = cam_transform.basis.x

		# Project camera directions onto horizontal plane
		cam_forward.y = 0
		cam_right.y = 0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		# Calculate movement direction
		direction = cam_forward * input_vector.y + cam_right * input_vector.x
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

	# Determine animation based on state
	if not is_on_floor():
		# Only play jump animation if we have it and we're going up
		if available_animations["jump"] != "" and velocity.y > 0:
			target_anim = available_animations["jump"]
		else:
			# Stay with current animation or use idle
			target_anim = available_animations["idle"]
	elif movement_speed > 0.15:  # Moving threshold
		if movement_speed > 0.65:  # Running threshold
			target_anim = available_animations["run"]
		else:
			target_anim = available_animations["walk"]
	else:
		target_anim = available_animations["idle"]

	# Fallback to first available animation
	if target_anim == "":
		var anims = animation_player.get_animation_list()
		if anims.size() > 0:
			target_anim = anims[0]

	# Only change animation if it's different and valid
	if target_anim != "" and target_anim != current_anim:
		play_animation_smooth(target_anim)

func rotate_character_to_movement():
	if not character_model:
		return

	# Rotate character to face movement direction (not camera direction)
	if last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation, 0.15)