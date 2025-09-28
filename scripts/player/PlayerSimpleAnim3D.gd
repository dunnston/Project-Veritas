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
@onready var character_model: Node3D = $CharacterModel

var animation_player: AnimationPlayer

var is_sprinting: bool = false
var is_crouching: bool = false
var is_running: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO

var was_on_floor: bool = false
var current_anim: String = ""

# Animation state tracking
var idle_time: float = 0.0
var walk_time: float = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	setup_animations()
	print("Simple animated player character loaded successfully!")

func setup_animations():
	# Find the AnimationPlayer in the character model
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer

	if animation_player:
		print("Found existing AnimationPlayer")

		# Check all animation libraries
		var libraries = animation_player.get_animation_library_list()
		print("Animation libraries: ", libraries)

		var total_animations = 0
		for lib_name in libraries:
			var lib = animation_player.get_animation_library(lib_name)
			if lib:
				var anim_list = lib.get_animation_list()
				total_animations += anim_list.size()
				print("Library '", lib_name, "' has ", anim_list.size(), " animations:")
				for anim_name in anim_list:
					print("  - ", anim_name)

		# Try to play any available animation to get out of T-pose
		if total_animations > 0:
			# Try the default library first
			var default_lib = animation_player.get_animation_library("")
			if default_lib and default_lib.get_animation_list().size() > 0:
				var first_anim = default_lib.get_animation_list()[0]
				print("Playing first animation from default library: ", first_anim)
				animation_player.play(first_anim)
				current_anim = first_anim
			else:
				# Try any other library
				for lib_name in libraries:
					var lib = animation_player.get_animation_library(lib_name)
					if lib and lib.get_animation_list().size() > 0:
						var first_anim = lib.get_animation_list()[0]
						var full_name = lib_name + "/" + first_anim if lib_name != "" else first_anim
						print("Playing first animation from library '", lib_name, "': ", full_name)
						animation_player.play(full_name)
						current_anim = full_name
						break
		else:
			print("No animations found in any library!")
	else:
		print("No AnimationPlayer found in character model")

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

	# Track floor state
	was_on_floor = is_on_floor()

	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	handle_jump()
	handle_movement(delta)
	update_animations(delta)
	rotate_character_model()

	move_and_slide()

func handle_movement_state():
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching
	is_crouching = Input.is_action_pressed("crouch")
	is_running = not is_sprinting and not is_crouching

	# Adjust collision shape for crouching
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

	# Determine target speed based on state
	var target_speed = walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_running and input_vector.length() > 0.5:
		target_speed = run_speed
	elif is_crouching:
		target_speed = crouch_speed

	# Apply movement with different control in air
	var control_factor = 1.0 if is_on_floor() else air_control

	if direction.length() > 0:
		velocity.x = lerp(velocity.x, direction.x * target_speed, acceleration * control_factor * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, acceleration * control_factor * delta)
		movement_speed = lerp(movement_speed, target_speed / sprint_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * control_factor * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * control_factor * delta)
		movement_speed = lerp(movement_speed, 0.0, friction * delta)

func update_animations(delta: float):
	if not animation_player:
		return

	# Get all available animations from all libraries
	var all_animations = get_all_animations()
	if all_animations.size() == 0:
		return

	# Simple animation selection based on movement and state
	var target_anim = ""

	# Check what animations are available and pick the best one
	if not is_on_floor():
		# Look for jump/fall animations
		target_anim = find_best_animation(all_animations, ["jump", "air", "fall"])
	elif movement_speed > 0.1:
		# Moving - look for walk/run animations
		if movement_speed > 0.6:
			target_anim = find_best_animation(all_animations, ["run", "sprint"])
		if target_anim == "":
			target_anim = find_best_animation(all_animations, ["walk"])
	else:
		# Idle - look for idle animations
		target_anim = find_best_animation(all_animations, ["idle", "stand"])

	# Use first available animation as fallback
	if target_anim == "" and all_animations.size() > 0:
		target_anim = all_animations.keys()[0]

	# Play the selected animation
	if target_anim != "" and target_anim != current_anim:
		print("Switching to animation: ", target_anim)
		animation_player.play(target_anim)
		current_anim = target_anim

	# Update animation speed based on movement
	if animation_player and movement_speed > 0:
		# Speed up animation based on movement speed
		var speed_multiplier = 1.0 + (movement_speed * 0.5)
		animation_player.speed_scale = speed_multiplier
	elif animation_player:
		animation_player.speed_scale = 1.0

func get_all_animations() -> Dictionary:
	var all_anims = {}
	var libraries = animation_player.get_animation_library_list()

	for lib_name in libraries:
		var lib = animation_player.get_animation_library(lib_name)
		if lib:
			var anim_list = lib.get_animation_list()
			for anim_name in anim_list:
				var full_name = lib_name + "/" + anim_name if lib_name != "" else anim_name
				all_anims[full_name] = anim_name

	return all_anims

func find_best_animation(animations: Dictionary, keywords: Array[String]) -> String:
	for full_name in animations.keys():
		var anim_name = animations[full_name]
		var lower_name = anim_name.to_lower()
		for keyword in keywords:
			if keyword.to_lower() in lower_name:
				return full_name
	return ""


func rotate_character_model():
	# Rotate character model to face movement direction
	if last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)