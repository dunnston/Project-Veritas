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
@onready var animation_tree: AnimationTree = $CharacterModel/AnimationTree
@onready var animation_player: AnimationPlayer = $CharacterModel/AnimationPlayer

var is_sprinting: bool = false
var is_crouching: bool = false
var is_running: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO

enum AnimationState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING
}

var current_animation_state: AnimationState = AnimationState.IDLE

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Set up animation library with proper animations
	setup_animations()

func setup_animations():
	# Create animation library
	var anim_library = AnimationLibrary.new()

	# Load idle animation
	var idle_anim = Animation.new()
	idle_anim.length = 1.0
	idle_anim.loop_mode = Animation.LOOP_LINEAR
	anim_library.add_animation("idle", idle_anim)

	# Load walk animation
	var walk_anim = Animation.new()
	walk_anim.length = 1.0
	walk_anim.loop_mode = Animation.LOOP_LINEAR
	anim_library.add_animation("walk", walk_anim)

	# Load run animation
	var run_anim = Animation.new()
	run_anim.length = 0.7
	run_anim.loop_mode = Animation.LOOP_LINEAR
	anim_library.add_animation("run", run_anim)

	# Load jump animation
	var jump_anim = Animation.new()
	jump_anim.length = 1.0
	anim_library.add_animation("jump", jump_anim)

	# Load fall animation
	var fall_anim = Animation.new()
	fall_anim.length = 0.5
	fall_anim.loop_mode = Animation.LOOP_LINEAR
	anim_library.add_animation("fall", fall_anim)

	# Add library to animation player
	animation_player.add_animation_library("", anim_library)

	# Start animation tree
	var state_machine = animation_tree.get("parameters/playback")
	state_machine.travel("ground_locomotion")

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

	# Add gravity
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
		current_animation_state = AnimationState.JUMPING

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

func update_animations():
	var state_machine = animation_tree.get("parameters/playback")

	# Handle air states
	if not is_on_floor():
		if velocity.y > 0:
			if current_animation_state != AnimationState.JUMPING:
				state_machine.travel("jump")
				current_animation_state = AnimationState.JUMPING
		else:
			if current_animation_state != AnimationState.FALLING:
				state_machine.travel("fall")
				current_animation_state = AnimationState.FALLING
	else:
		# Ground locomotion
		if current_animation_state != AnimationState.IDLE and current_animation_state != AnimationState.WALKING and current_animation_state != AnimationState.RUNNING:
			state_machine.travel("ground_locomotion")

		# Update blend position for ground locomotion (0 = idle, 0.5 = walk, 1 = run)
		animation_tree.set("parameters/ground_locomotion/blend_position", movement_speed)

		# Update state based on speed
		if movement_speed < 0.1:
			current_animation_state = AnimationState.IDLE
		elif movement_speed < 0.6:
			current_animation_state = AnimationState.WALKING
		else:
			current_animation_state = AnimationState.RUNNING

func rotate_character_model():
	# Rotate character model to face movement direction
	if last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)