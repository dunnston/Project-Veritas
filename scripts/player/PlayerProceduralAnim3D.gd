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

@export_group("Procedural Animation")
@export var bob_height: float = 0.1
@export var bob_speed: float = 8.0
@export var lean_amount: float = 0.1

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var character_model: Node3D = $CharacterModel

var is_sprinting: bool = false
var is_crouching: bool = false
var is_running: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO

# Animation variables
var bob_timer: float = 0.0
var original_model_position: Vector3
var original_model_rotation: Vector3

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	original_model_position = character_model.position
	original_model_rotation = character_model.rotation
	print("Procedural animated player character loaded successfully!")

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
	update_procedural_animations(delta)
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

func update_procedural_animations(delta: float):
	# Walking/running bob animation
	if is_on_floor() and movement_speed > 0.1:
		bob_timer += delta * bob_speed * (1.0 + movement_speed)

		# Vertical bobbing
		var bob_offset = sin(bob_timer) * bob_height * movement_speed
		character_model.position.y = original_model_position.y + bob_offset

		# Side-to-side sway
		var sway_offset = sin(bob_timer * 0.5) * bob_height * 0.3 * movement_speed
		character_model.position.x = original_model_position.x + sway_offset

		# Slight forward lean when moving
		var lean_forward = movement_speed * lean_amount
		character_model.rotation.x = original_model_rotation.x + lean_forward

		# Running vs walking differences
		if movement_speed > 0.6:  # Running
			# More pronounced bobbing and leaning
			character_model.position.y += sin(bob_timer * 2.0) * bob_height * 0.3
			character_model.rotation.x += lean_forward * 0.5
	else:
		# Return to neutral position when not moving
		character_model.position.x = lerp(character_model.position.x, original_model_position.x, delta * 5.0)
		character_model.position.y = lerp(character_model.position.y, original_model_position.y, delta * 5.0)
		character_model.rotation.x = lerp_angle(character_model.rotation.x, original_model_rotation.x, delta * 5.0)
		bob_timer = 0.0

	# Jumping/falling animations
	if not is_on_floor():
		if velocity.y > 0:  # Jumping
			# Slight backward lean
			character_model.rotation.x = original_model_rotation.x - 0.2
		else:  # Falling
			# Slight forward lean
			character_model.rotation.x = original_model_rotation.x + 0.1

	# Crouching animation
	if is_crouching:
		# Lower the character model
		character_model.position.y = original_model_position.y - 0.3
		# Slight forward lean
		character_model.rotation.x = original_model_rotation.x + 0.3
	elif not is_crouching and is_on_floor() and movement_speed < 0.1:
		# Return to normal height when not crouching and not moving
		character_model.position.y = lerp(character_model.position.y, original_model_position.y, delta * 5.0)

func rotate_character_model():
	# Rotate character model to face movement direction
	if last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)