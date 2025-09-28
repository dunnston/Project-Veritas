extends CharacterBody3D

@export var mouse_sensitivity: float = 0.002

@onready var camera_pivot: Node3D = $CameraPivot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var character_model: Node3D
var animation_player: AnimationPlayer
var camera_rotation: Vector2 = Vector2.ZERO

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("debug_mixamo_setup")

func debug_mixamo_setup():
	print("=== MIXAMO DEBUG START ===")

	# Test each Mixamo file individually
	var mixamo_files = [
		"res://assets/models/Breathing Idle.fbx",
		"res://assets/models/Walking.fbx",
		"res://assets/models/Running.fbx",
		"res://assets/models/Jumping.fbx"
	]

	for file_path in mixamo_files:
		print("\n--- Testing file: ", file_path, " ---")
		test_mixamo_file(file_path)

	# Load the first file as our character
	print("\n=== LOADING CHARACTER ===")
	load_character_with_debug(mixamo_files[0])

func test_mixamo_file(file_path: String):
	if not ResourceLoader.exists(file_path):
		print("❌ File does not exist: ", file_path)
		return

	print("✅ File exists, loading...")
	var scene = load(file_path)
	if not scene:
		print("❌ Failed to load scene")
		return

	print("✅ Scene loaded, instantiating...")
	var instance = scene.instantiate()

	print("Instance class: ", instance.get_class())
	print("Instance children: ", instance.get_children().size())

	# Look for AnimationPlayer
	var anim_player = find_animation_player_debug(instance)
	if anim_player:
		print("✅ Found AnimationPlayer")
		print("  Animation count: ", anim_player.get_animation_list().size())
		print("  Animations: ", anim_player.get_animation_list())

		# Check animation libraries
		var libraries = anim_player.get_animation_library_list()
		print("  Libraries: ", libraries)
		for lib_name in libraries:
			var lib = anim_player.get_animation_library(lib_name)
			if lib:
				print("    Library '", lib_name, "': ", lib.get_animation_list())
	else:
		print("❌ No AnimationPlayer found")
		print("Available children:")
		debug_node_tree(instance, "  ")

	instance.queue_free()

func find_animation_player_debug(node: Node, depth: int = 0):
	var indent = "  ".repeat(depth)
	print(indent, "Checking: ", node.name, " (", node.get_class(), ")")

	if node is AnimationPlayer:
		print(indent, "🎯 FOUND AnimationPlayer!")
		return node

	for child in node.get_children():
		var result = find_animation_player_debug(child, depth + 1)
		if result:
			return result

	return null

func debug_node_tree(node: Node, indent: String):
	print(indent, node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		debug_node_tree(child, indent + "  ")

func load_character_with_debug(file_path: String):
	print("Loading character from: ", file_path)
	var scene = load(file_path)
	if scene:
		character_model = scene.instantiate()
		add_child(character_model)
		character_model.position = Vector3.ZERO
		character_model.rotation = Vector3(0, PI, 0)

		print("Character loaded, searching for AnimationPlayer...")
		animation_player = find_animation_player_debug(character_model)

		if animation_player:
			print("✅ Character has AnimationPlayer")
			var anims = animation_player.get_animation_list()
			print("Available animations: ", anims)

			if anims.size() > 0:
				var first_anim = anims[0]
				print("Playing first animation: ", first_anim)
				animation_player.play(first_anim)

				# Check if animation is actually playing
				await get_tree().create_timer(0.1).timeout
				if animation_player.is_playing():
					print("✅ Animation is playing!")
					print("Current animation: ", animation_player.current_animation)
					print("Animation position: ", animation_player.current_animation_position)
				else:
					print("❌ Animation is NOT playing")
			else:
				print("❌ No animations found in AnimationPlayer")
		else:
			print("❌ No AnimationPlayer found in character")

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
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, camera_rotation.x, 10.0 * delta)
	camera_pivot.rotation.x = lerp_angle(camera_pivot.rotation.x, camera_rotation.y, 10.0 * delta)

	# Basic movement
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward")

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 8.0

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

	if direction.length() > 0:
		velocity.x = lerp(velocity.x, direction.x * 5.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, direction.z * 5.0, 10.0 * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, 10.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 10.0 * delta)

	move_and_slide()

	# Debug animation status
	if animation_player and Input.is_action_just_pressed("interact"):
		print("DEBUG: Animation status")
		print("  Playing: ", animation_player.is_playing())
		print("  Current: ", animation_player.current_animation)
		print("  Position: ", animation_player.current_animation_position)
		print("  Speed: ", animation_player.speed_scale)