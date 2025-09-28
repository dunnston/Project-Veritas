extends Node

# Helper script to load animations from FBX files
# This script handles the import and setup of character animations

static func create_animation_library() -> AnimationLibrary:
	var library = AnimationLibrary.new()

	# Create placeholder animations for now
	# These will be replaced when the FBX files are properly imported by Godot

	var idle_anim = create_placeholder_animation("idle", 2.0)
	var walk_anim = create_placeholder_animation("walk", 1.0)
	var run_anim = create_placeholder_animation("run", 0.6)
	var jump_anim = create_placeholder_animation("jump", 1.0, false)
	var fall_anim = create_placeholder_animation("fall", 0.5)

	library.add_animation("idle", idle_anim)
	library.add_animation("walk", walk_anim)
	library.add_animation("run", run_anim)
	library.add_animation("jump", jump_anim)
	library.add_animation("fall", fall_anim)

	return library

static func create_placeholder_animation(name: String, length: float, loop: bool = true) -> Animation:
	var anim = Animation.new()
	anim.length = length
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	else:
		anim.loop_mode = Animation.LOOP_NONE

	# Add a dummy track to make the animation valid
	var track_index = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(track_index, NodePath("."))
	anim.track_insert_key(track_index, 0.0, Vector3.ZERO)
	anim.track_insert_key(track_index, length, Vector3.ZERO)

	return anim

# Function to extract animations from imported FBX files
static func extract_animation_from_fbx(fbx_path: String, animation_name: String) -> Animation:
	var scene = load(fbx_path)
	if scene == null:
		print("Failed to load FBX file: ", fbx_path)
		return null

	# Try to find AnimationPlayer in the scene
	var anim_player = find_animation_player_in_scene(scene)
	if anim_player == null:
		print("No AnimationPlayer found in FBX file: ", fbx_path)
		return null

	var anim_library = anim_player.get_animation_library("")
	if anim_library == null:
		print("No animation library found in: ", fbx_path)
		return null

	var animation_names = anim_library.get_animation_list()
	if animation_names.size() > 0:
		return anim_library.get_animation(animation_names[0])

	return null

static func find_animation_player_in_scene(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child in node.get_children():
		var result = find_animation_player_in_scene(child)
		if result != null:
			return result

	return null