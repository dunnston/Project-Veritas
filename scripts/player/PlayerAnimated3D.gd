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
@onready var character_model: Node3D = $CharacterModel

var animation_player: AnimationPlayer
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO
var current_anim: String = ""
var is_crouching: bool = false
var model_base_position: Vector3 = Vector3.ZERO
var is_jumping: bool = false
var was_on_floor: bool = true

# Animation names (will be detected from AnimationPlayer)
var idle_anim: String = ""
var walk_anim: String = ""
var run_anim: String = ""
var jump_anim: String = ""
var crouch_anim: String = ""
var fall_anim: String = ""

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Register with GameManager
	GameManager.register_player(self)
	# Store the original position of the character model
	model_base_position = character_model.position
	call_deferred("setup_animations")

func setup_animations():
	animation_player = find_animation_player(character_model)

	if animation_player:
		print("✅ Found AnimationPlayer with animations:")
		var all_anims = animation_player.get_animation_list()
		print("Available animations: ", all_anims)

		# Disable root motion if AnimationPlayer supports it
		if animation_player.has_method("set_root_motion_track"):
			animation_player.set_root_motion_track(NodePath())
			print("Disabled root motion")

		# Ensure animations are set to loop where appropriate
		for anim_name in all_anims:
			var animation = animation_player.get_animation(anim_name)
			if animation:
				var lower = anim_name.to_lower()
				# Set looping for continuous animations
				if "idle" in lower or "walk" in lower or "run" in lower or "crouch" in lower:
					animation.loop_mode = Animation.LOOP_LINEAR
					print("Set ", anim_name, " to loop")
					# Remove position tracks that cause jumping
					remove_position_tracks(animation, anim_name)
				elif "jump" in lower:
					animation.loop_mode = Animation.LOOP_NONE
					print("Set ", anim_name, " to play once")

		# Map animations based on common naming patterns
		for anim_name in all_anims:
			var lower = anim_name.to_lower()
			print("Checking animation: ", anim_name, " (", lower, ")")

			if "crouch" in lower:
				crouch_anim = anim_name
				print("  -> Mapped as CROUCH")
			elif "jump" in lower:
				jump_anim = anim_name
				print("  -> Mapped as JUMP")
			elif "run" in lower and "walk" not in lower:
				run_anim = anim_name
				print("  -> Mapped as RUN")
			elif "walk" in lower:
				walk_anim = anim_name
				print("  -> Mapped as WALK")
			elif "fall" in lower:
				fall_anim = anim_name
				print("  -> Mapped as FALL")
			elif "idle" in lower or "breathing" in lower:
				idle_anim = anim_name
				print("  -> Mapped as IDLE")

		print("\nFinal animation mapping:")
		print("  Idle: ", idle_anim)
		print("  Walk: ", walk_anim)
		print("  Run: ", run_anim)
		print("  Jump: ", jump_anim)
		print("  Crouch: ", crouch_anim)
		print("  Fall: ", fall_anim)

		# Ensure we start with idle animation, not first in list
		if idle_anim != "":
			animation_player.play(idle_anim)
			current_anim = idle_anim
			print("Starting with idle animation: ", idle_anim)
		elif walk_anim != "":
			animation_player.play(walk_anim)
			current_anim = walk_anim
			print("No idle found, starting with walk: ", walk_anim)
		elif all_anims.size() > 0:
			# Only use first animation as last resort
			animation_player.play(all_anims[0])
			current_anim = all_anims[0]
			print("Using first available animation: ", all_anims[0])
	else:
		print("❌ No AnimationPlayer found in character model")

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = find_animation_player(child)
		if result:
			return result

	return null

func remove_position_tracks(animation: Animation, anim_name: String):
	# Remove or modify tracks that affect the root position
	var tracks_to_remove = []

	for i in range(animation.get_track_count()):
		var track_path = animation.track_get_path(i)
		var track_type = animation.track_get_type(i)

		# Check if this is a position track on the root or main body
		if track_type == Animation.TYPE_POSITION_3D:
			var path_str = str(track_path)
			# Remove position tracks for root node or main skeleton root
			if "." == path_str or ":position" in path_str or path_str.begins_with(".:") or path_str == "":
				tracks_to_remove.append(i)
				print("  Removing root position track: ", path_str)
			elif "Root" in path_str or "Hips" in path_str or "Pelvis" in path_str:
				# For hip/pelvis, we might want to keep vertical movement but remove horizontal
				# For now, let's remove it entirely to prevent sliding
				tracks_to_remove.append(i)
				print("  Removing body position track: ", path_str)

	# Remove tracks in reverse order to maintain indices
	tracks_to_remove.reverse()
	for track_idx in tracks_to_remove:
		animation.remove_track(track_idx)

func play_anim(anim_name: String):
	if animation_player and anim_name != "":
		if animation_player.has_animation(anim_name):
			# Only restart animation if it's a different one
			if anim_name != current_anim:
				animation_player.play(anim_name)
				current_anim = anim_name
				print("Playing animation: ", anim_name)
			# If same animation and not playing, restart it (for looping)
			elif not animation_player.is_playing():
				animation_player.play(anim_name)
				print("Restarting animation: ", anim_name)
		else:
			print("Animation not found: ", anim_name)

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

	# Track floor state changes
	var on_floor_now = is_on_floor()

	if not on_floor_now:
		velocity += get_gravity() * delta

	handle_movement(delta)
	update_animations()
	rotate_character()

	move_and_slide()

	# Keep character model at base position to prevent animation drift
	if character_model:
		character_model.position = model_base_position

	# Update floor state for next frame
	was_on_floor = on_floor_now

func apply_camera_rotation(delta: float):
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, camera_rotation.x, 10.0 * delta)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, camera_rotation.y, 10.0 * delta)

func handle_movement(delta: float):
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")

	# Don't normalize yet - we need to check if there's any input first
	var has_input = input_dir.length() > 0.1

	# Handle crouching
	if Input.is_action_pressed("crouch"):
		if not is_crouching:
			is_crouching = true
	else:
		if is_crouching:
			is_crouching = false

	# Handle jumping
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity
		is_jumping = true
		# Play jump animation immediately
		if jump_anim != "":
			play_anim(jump_anim)

	# Reset jumping flag when landing
	if is_on_floor() and was_on_floor == false:
		is_jumping = false

	# Calculate movement direction
	var direction = Vector3.ZERO
	if has_input:
		input_dir = input_dir.normalized()
		var cam_transform = camera_pivot.global_transform
		var forward = cam_transform.basis.z  # Changed from -z to z to fix inversion
		var right = cam_transform.basis.x

		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()

		direction = forward * input_dir.y + right * input_dir.x
		direction = direction.normalized()
		last_direction = direction

	# Determine target speed
	var target_speed = walk_speed
	if is_crouching:
		target_speed = walk_speed * 0.5
	elif Input.is_action_pressed("sprint") and has_input:
		target_speed = sprint_speed
	elif has_input and input_dir.length() > 0.7:
		target_speed = run_speed

	# Apply movement
	if has_input and direction.length() > 0:
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

	# Priority order: Jump (active) -> Fall -> Crouch -> Movement -> Idle
	if is_jumping and jump_anim != "":
		# Keep playing jump animation while jumping
		if not animation_player.is_playing() or current_anim != jump_anim:
			target_anim = jump_anim
		else:
			# Let jump animation continue playing
			return
	elif not is_on_floor() and velocity.y < -1.0:
		# Use fall animation if available, otherwise idle
		if fall_anim != "":
			target_anim = fall_anim
		else:
			target_anim = idle_anim
	elif is_crouching and crouch_anim != "":
		target_anim = crouch_anim
	elif movement_speed > 0.2:
		if movement_speed > 0.7 and run_anim != "":
			target_anim = run_anim
		elif walk_anim != "":
			target_anim = walk_anim
		else:
			target_anim = idle_anim
	else:
		target_anim = idle_anim

	if target_anim != "" and target_anim != current_anim:
		play_anim(target_anim)

func rotate_character():
	if character_model and last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation, 0.15)