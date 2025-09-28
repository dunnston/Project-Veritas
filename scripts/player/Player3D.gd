extends CharacterBody3D

@export_group("Movement Settings")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 8.0
@export var crouch_speed: float = 2.5
@export var acceleration: float = 10.0
@export var friction: float = 10.0

@export_group("Camera Settings")
@export var mouse_sensitivity: float = 0.002
@export var camera_smoothing: float = 15.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var is_sprinting: bool = false
var is_crouching: bool = false
var camera_rotation: Vector2 = Vector2.ZERO

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

	move_and_slide()

func handle_movement_state():
	is_sprinting = Input.is_action_pressed("sprint") and not is_crouching
	is_crouching = Input.is_action_pressed("crouch")

	if is_crouching:
		var shape = collision_shape.shape as CapsuleShape3D
		shape.height = 1.0
		collision_shape.position.y = 0.5
	else:
		var shape = collision_shape.shape as CapsuleShape3D
		shape.height = 2.0
		collision_shape.position.y = 1.0

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

	var target_speed = walk_speed
	if is_sprinting:
		target_speed = sprint_speed
	elif is_crouching:
		target_speed = crouch_speed

	if direction.length() > 0:
		velocity.x = lerp(velocity.x, direction.x * target_speed, acceleration * delta)
		velocity.z = lerp(velocity.z, direction.z * target_speed, acceleration * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)
