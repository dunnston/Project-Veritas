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
var animation_tree: AnimationTree

var is_sprinting: bool = false
var is_crouching: bool = false
var is_running: bool = false
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO

var was_on_floor: bool = false
var jump_time: float = 0.0
var current_anim_state: String = "idle"

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame  # Wait for scene to be fully ready
	setup_animation_system()
	print("Animated player character loaded successfully!")

func setup_animation_system():
	# Find existing AnimationPlayer in the character model or create one
	animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not animation_player:
		animation_player = AnimationPlayer.new()
		animation_player.name = "PlayerAnimationPlayer"
		character_model.add_child(animation_player)

	# Create and setup AnimationTree
	animation_tree = AnimationTree.new()
	animation_tree.name = "PlayerAnimationTree"
	character_model.add_child(animation_tree)

	# Load animations
	setup_animations()

	# Create state machine
	create_animation_state_machine()

	# Start the animation tree
	animation_tree.anim_player = NodePath("../PlayerAnimationPlayer")
	animation_tree.active = true

func setup_animations():
	# Create animation library
	var anim_library = AnimationLibrary.new()

	# Try to load FBX animations, fall back to simple ones
	var animations_loaded = false

	# Try to get animations from the character model's existing AnimationPlayer
	var existing_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if existing_player and existing_player.has_animation_library(""):
		var existing_lib = existing_player.get_animation_library("")
		var anim_names = existing_lib.get_animation_list()
		if anim_names.size() > 0:
			# Copy animations from existing player
			for anim_name in anim_names:
				var anim = existing_lib.get_animation(anim_name)
				anim_library.add_animation("imported_" + anim_name, anim)
			animations_loaded = true
			print("Found ", anim_names.size(), " existing animations")

	# Create our own named animations
	if not animations_loaded:
		print("Creating fallback animations")
		create_fallback_animations(anim_library)
	else:
		# Map imported animations to our names
		map_imported_animations(anim_library)

	# Add library to our animation player
	animation_player.add_animation_library("", anim_library)
	animation_player.add_animation_library("", anim_library)

func map_imported_animations(library: AnimationLibrary):
	# Try to map imported animations to standard names
	var anim_names = library.get_animation_list()

	# Create standard named versions pointing to imported ones
	if anim_names.size() > 0:
		# Use the first animation as idle
		var first_anim = library.get_animation(anim_names[0])
		library.add_animation("idle", first_anim.duplicate())
		library.add_animation("walk", first_anim.duplicate())
		library.add_animation("run", first_anim.duplicate())
		library.add_animation("jump", first_anim.duplicate())
		library.add_animation("fall", first_anim.duplicate())

func create_fallback_animations(library: AnimationLibrary):
	var idle = create_simple_animation("idle", 2.0, true)
	var walk = create_simple_animation("walk", 1.0, true)
	var run = create_simple_animation("run", 0.6, true)
	var jump = create_simple_animation("jump", 0.5, false)
	var fall = create_simple_animation("fall", 0.3, true)

	library.add_animation("idle", idle)
	library.add_animation("walk", walk)
	library.add_animation("run", run)
	library.add_animation("jump", jump)
	library.add_animation("fall", fall)

func create_simple_animation(name: String, length: float, loop: bool) -> Animation:
	var anim = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	# Add a dummy track
	var track_index = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_index, NodePath("."))
	anim.track_insert_key(track_index, 0.0, Vector3.ZERO)
	anim.track_insert_key(track_index, length, Vector3.ZERO)

	return anim

func create_animation_state_machine():
	# Create simple state machine nodes
	var idle_node = AnimationNodeAnimation.new()
	idle_node.animation = "idle"

	var walk_node = AnimationNodeAnimation.new()
	walk_node.animation = "walk"

	var run_node = AnimationNodeAnimation.new()
	run_node.animation = "run"

	var jump_node = AnimationNodeAnimation.new()
	jump_node.animation = "jump"

	var fall_node = AnimationNodeAnimation.new()
	fall_node.animation = "fall"

	# Create blend space for locomotion
	var locomotion_blend = AnimationNodeBlendSpace1D.new()
	locomotion_blend.add_blend_point(idle_node, 0.0)
	locomotion_blend.add_blend_point(walk_node, 0.5)
	locomotion_blend.add_blend_point(run_node, 1.0)

	# Create state machine
	var state_machine = AnimationNodeStateMachine.new()

	# Add states
	state_machine.add_node("locomotion", locomotion_blend)
	state_machine.add_node("jump", jump_node)
	state_machine.add_node("fall", fall_node)

	# Add transitions
	var start_to_locomotion = AnimationNodeStateMachineTransition.new()
	start_to_locomotion.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("Start", "locomotion", start_to_locomotion)

	var locomotion_to_jump = AnimationNodeStateMachineTransition.new()
	locomotion_to_jump.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("locomotion", "jump", locomotion_to_jump)

	var jump_to_fall = AnimationNodeStateMachineTransition.new()
	jump_to_fall.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("jump", "fall", jump_to_fall)

	var fall_to_locomotion = AnimationNodeStateMachineTransition.new()
	fall_to_locomotion.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	state_machine.add_transition("fall", "locomotion", fall_to_locomotion)

	animation_tree.tree_root = state_machine

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
		jump_time += delta

	handle_jump()
	handle_movement(delta)
	update_animations()
	rotate_character_model()

	move_and_slide()

	# Check for landing
	if not was_on_floor and is_on_floor():
		on_landed()

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
		jump_time = 0.0

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
	if not animation_tree or not animation_tree.active:
		return

	var state_machine = animation_tree.get("parameters/playbook") as AnimationNodeStateMachinePlayback
	if not state_machine:
		# Try simple animation switching
		play_simple_animation()
		return

	# Handle air states
	if not is_on_floor():
		if velocity.y > 0 and jump_time < 0.3:  # Rising (jumping)
			if current_anim_state != "jump":
				state_machine.travel("jump")
				current_anim_state = "jump"
		else:  # Falling
			if current_anim_state != "fall":
				state_machine.travel("fall")
				current_anim_state = "fall"
	else:
		# Grounded
		if current_anim_state != "locomotion":
			state_machine.travel("locomotion")
			current_anim_state = "locomotion"

		# Update locomotion blend space
		animation_tree.set("parameters/locomotion/blend_position", movement_speed)

func play_simple_animation():
	# Simple fallback animation system
	var target_anim = "idle"

	if not is_on_floor():
		if velocity.y > 0:
			target_anim = "jump"
		else:
			target_anim = "fall"
	else:
		if movement_speed > 0.7:
			target_anim = "run"
		elif movement_speed > 0.1:
			target_anim = "walk"
		else:
			target_anim = "idle"

	if animation_player.has_animation(target_anim) and current_anim_state != target_anim:
		animation_player.play(target_anim)
		current_anim_state = target_anim

func on_landed():
	# Called when player lands on ground
	current_anim_state = "locomotion"

func rotate_character_model():
	# Rotate character model to face movement direction
	if last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation - camera_pivot.rotation.y, 0.1)
