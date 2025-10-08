extends CharacterBody3D

@export var walk_speed: float = 6.0
@export var run_speed: float = 9.0
@export var sprint_speed: float = 12.0
@export var jump_velocity: float = 6.5
@export var mouse_sensitivity: float = 0.002

@export_group("Interaction Settings")
@export var drop_distance: float = 2.0
@export var interact_range: float = 3.0

@export_group("Mining Settings")
@export var mining_damage_per_hit: float = 10.0
@export var mining_hit_rate: float = 0.5  # Time between mining hits

@export_group("Survival Stats")
@export var max_health: int = 100
@export var max_energy: int = 100
@export var max_hunger: int = 100
@export var max_thirst: int = 100
@export var max_radiation_damage: float = 100.0

@export_group("Grapple Settings")
@export var grapple_range: float = 75.0
@export var grapple_speed: float = 40.0

@export_group("Combat Settings")
@export var invincibility_duration: float = 0.8  # Invincibility frames after taking damage
@export var damage_flash_duration: float = 0.2  # How long the red flash lasts

# Current survival stats
var health: int = 100
var energy: int = 100
var hunger: int = 100
var thirst: int = 100
var current_radiation_damage: float = 0.0

# Stat signals for HUD updates
signal health_changed(new_health: int)
signal energy_changed(new_energy: int)
signal hunger_changed(new_hunger: int)
signal thirst_changed(new_thirst: int)
signal radiation_changed(current_radiation: float, max_radiation: float)

# Stat modifiers from equipment/skills
var speed_modifier: float = 1.0
var defense: int = 0
var bonus_inventory_slots: int = 0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera_3d: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var character_model: Node3D = $CharacterModel
@onready var grapple_raycast: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/GrappleRayCast
@onready var grapple_hook_point: Node3D = $GrappleHookPoint
@onready var grapple_rope: MeshInstance3D = $GrappleRope

var animation_player: AnimationPlayer
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO
var current_anim: String = ""
var is_crouching: bool = false
var model_base_position: Vector3 = Vector3.ZERO
var is_jumping: bool = false
var was_on_floor: bool = true
var crouch_offset: float = -0.45  # Adjust this value until the feet look right

# Collision shape height management for crouching
var stand_height: float = 1.8  # Default capsule height (standing)
var crouch_height: float = 1.8 # Target height when crouched
var stand_collider_position: Vector3  # Store original collider position

# Interaction system for 3D
var nearby_interactables: Array = []
var interaction_area: Area3D = null

# Mining system
var is_mining: bool = false
var current_mining_target: ResourceNode = null
var mining_timer: Timer = null
var interact_hold_time: float = 0.0
const INTERACT_HOLD_THRESHOLD: float = 0.3  # Hold E for 0.3s to mine

# Survival stat depletion timers
var hunger_timer: Timer
var thirst_timer: Timer
const HUNGER_DEPLETION_RATE: float = 60.0  # Lose 1 hunger every 60 seconds
const THIRST_DEPLETION_RATE: float = 45.0  # Lose 1 thirst every 45 seconds

# Grappling hook system
var is_grappling: bool = false
var grapple_point: Vector3 = Vector3.ZERO

# Combat/Damage system
var is_invincible: bool = false
var invincibility_timer: Timer
var damage_flash_timer: Timer
var original_model_materials: Array = []  # Store original materials for damage flash

# Animation names (will be detected from AnimationPlayer)
var idle_anim: String = ""
var walk_anim: String = ""
var run_anim: String = ""
var jump_anim: String = ""
var crouch_anim: String = ""
var crouch_walk_anim: String = ""
var fall_anim: String = ""
var grapple_anim: String = ""
var death_anim: String = ""

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Set up collision layers
	# Player is on layer 2, and should collide with World (layer 1)
	collision_layer = 2  # Player layer
	collision_mask = 1   # Collide with World layer (ground, walls, etc.)

	# Add player to grapple raycast exceptions
	grapple_raycast.add_exception(self)

	add_to_group("player")

	# Initialize survival stats
	initialize_stats()

	# Register with GameManager (defer to avoid autoload conflicts)
	call_deferred("_register_with_game_manager")
	# Store the original position of the character model
	model_base_position = character_model.position
	stand_collider_position = collision_shape.position
	call_deferred("setup_animations")

	# Connect to inventory system if available
	if InventorySystem:
		print("PlayerAnimated3D: Connected to InventorySystem")
		# Add some test items for testing drops
		call_deferred("add_test_items")

	# Set up 3D interaction system
	call_deferred("setup_interaction_area")

	# Set up survival stat depletion timers
	call_deferred("setup_depletion_timers")

	# Set up mining timer
	call_deferred("setup_mining_timer")

	# Set up combat timers (invincibility, damage flash)
	call_deferred("setup_combat_timers")

func initialize_stats():
	"""Initialize all survival stats to their maximum values"""
	health = max_health
	energy = max_energy
	hunger = max_hunger
	thirst = max_thirst
	current_radiation_damage = 0.0

	# Emit initial values for HUD
	health_changed.emit(health)
	energy_changed.emit(energy)
	hunger_changed.emit(hunger)
	thirst_changed.emit(thirst)
	radiation_changed.emit(current_radiation_damage, max_radiation_damage)

func _register_with_game_manager():
	# Get GameManager specifically to avoid autoload conflicts
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.has_method("register_player"):
		game_manager.register_player(self)
		print("Player registered with GameManager successfully")
	else:
		print("ERROR: GameManager not found or register_player method missing")

func setup_animations():
	animation_player = find_animation_player(character_model)

	if animation_player:
		# Check if using animation libraries (like RadiationAnims)
		var all_anims = []
		var libraries = animation_player.get_animation_library_list()

		if libraries.size() > 0:
			# Get animations from all libraries
			for lib_name in libraries:
				var lib = animation_player.get_animation_library(lib_name)
				if lib:
					var lib_anims = lib.get_animation_list()
					# Prefix animations with library name if not default
					for anim in lib_anims:
						if lib_name != "":
							all_anims.append(lib_name + "/" + anim)
						else:
							all_anims.append(anim)
		else:
			# Fallback to old method
			all_anims = animation_player.get_animation_list()

		# Disable root motion if AnimationPlayer supports it
		if animation_player.has_method("set_root_motion_track"):
			animation_player.set_root_motion_track(NodePath())

		# Ensure animations are set to loop where appropriate
		for anim_name in all_anims:
			# Get animation from library if needed
			var animation = null
			if "/" in anim_name:
				var parts = anim_name.split("/")
				if parts.size() == 2:
					var lib = animation_player.get_animation_library(parts[0])
					if lib:
						animation = lib.get_animation(parts[1])
			else:
				animation = animation_player.get_animation(anim_name)

			if animation:
				var lower = anim_name.to_lower()
				# Set looping for continuous animations
				if "idle" in lower or "walk" in lower or "run" in lower or "crouch" in lower or "grapple" in lower or "hook" in lower:
					animation.loop_mode = Animation.LOOP_LINEAR
					# Remove position tracks that cause jumping
					remove_position_tracks(animation, anim_name)
				elif "jump" in lower or "death" in lower or "die" in lower:
					animation.loop_mode = Animation.LOOP_NONE

		# Map animations based on common naming patterns
		# Process in order: specific patterns first, then general
		for anim_name in all_anims:
			var lower = anim_name.to_lower()

			# Check for crouch walk first (more specific than just "crouch")
			if "crouch" in lower and ("walk" in lower or "forward" in lower or "move" in lower):
				crouch_walk_anim = anim_name
			elif "crouch" in lower and "idle" in lower:
				crouch_anim = anim_name
			elif "jump" in lower:
				jump_anim = anim_name
			elif "fall" in lower:
				fall_anim = anim_name
			elif "grapple" in lower or "grappling" in lower or "hook" in lower:
				grapple_anim = anim_name
			elif "death" in lower or "die" in lower or "dead" in lower:
				death_anim = anim_name
			# Map plain "_run" without shoot as RUN
			elif (lower.ends_with("_run") or lower.ends_with("/run")) and "shoot" not in lower:
				run_anim = anim_name
			# Map "runshoot" as sprint (faster run)
			elif "shoot" in lower and "run" in lower:
				# This is sprint/combat run, don't use it for regular run
				pass
			elif "walk" in lower or "walkforward" in lower or "walkcycle" in lower or "walking" in lower:
				walk_anim = anim_name
			elif "idle" in lower and "crouch" not in lower:
				idle_anim = anim_name
			elif "breathing" in lower:
				if idle_anim == "":
					idle_anim = anim_name

		# If no walk animation found, use run animation for both walk and run
		if walk_anim == "" and run_anim != "":
			walk_anim = run_anim

		# Ensure we start with idle animation, not first in list
		if idle_anim != "":
			animation_player.play(idle_anim)
			current_anim = idle_anim
		elif walk_anim != "":
			animation_player.play(walk_anim)
			current_anim = walk_anim
		elif all_anims.size() > 0:
			# Only use first animation as last resort
			animation_player.play(all_anims[0])
			current_anim = all_anims[0]

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
			elif "Root" in path_str or "Hips" in path_str or "Pelvis" in path_str:
				# Remove all position tracks to prevent sliding/floating
				# We'll handle crouch lowering manually via model offset
				tracks_to_remove.append(i)

	# Remove tracks in reverse order to maintain indices
	tracks_to_remove.reverse()
	for track_idx in tracks_to_remove:
		animation.remove_track(track_idx)

func play_anim(anim_name: String, blend_time: float = 0.2):
	if animation_player and anim_name != "":
		# Check if animation exists (handles both library/name and plain name formats)
		var anim_exists = false
		if "/" in anim_name:
			# Library format: "LibraryName/AnimationName"
			var parts = anim_name.split("/")
			if parts.size() == 2:
				var lib = animation_player.get_animation_library(parts[0])
				if lib and lib.has_animation(parts[1]):
					anim_exists = true
		else:
			# Plain name format
			anim_exists = animation_player.has_animation(anim_name)

		if anim_exists:
			# Only restart animation if it's a different one
			if anim_name != current_anim:
				# Use smooth blending between animations
				animation_player.play(anim_name, blend_time)
				current_anim = anim_name
			# If same animation and not playing, restart it (for looping)
			elif not animation_player.is_playing():
				animation_player.play(anim_name, blend_time)

func _input(event: InputEvent):
	# Handle mouse look
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			camera_rotation.x -= event.relative.x * mouse_sensitivity
			camera_rotation.y -= event.relative.y * mouse_sensitivity
			camera_rotation.y = clamp(camera_rotation.y, -1.4, 1.4)
		return

	# Menu toggle
	if event.is_action("menu") and event.is_action_pressed("menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Handle interactions (items, workbenches, doors, etc.)
	# Only trigger on quick tap (released before hold threshold)
	if event.is_action("interact") and event.is_action_released("interact"):
		if interact_hold_time < INTERACT_HOLD_THRESHOLD:
			interact_with_nearest()
		interact_hold_time = 0.0

	# Handle inventory toggle
	if event.is_action("inventory") and event.is_action_pressed("inventory"):
		toggle_inventory()

	# Handle grappling hook
	if event.is_action("grapple"):
		if event.is_action_pressed("grapple"):
			fire_grapple()
		elif event.is_action_released("grapple"):
			if is_grappling:
				release_grapple()

	# Debug: Test damage system with H key
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		take_damage(10, "test", null)
		print("DEBUG: Triggered test damage (10 HP)")

func _physics_process(delta: float):
	apply_camera_rotation(delta)

	# Track floor state changes
	var on_floor_now = is_on_floor()

	if is_grappling:
		# ---- GRAPPLING HOOK MOVEMENT ----
		handle_grapple_movement(delta)
		update_animations()  # Update animations during grappling to show grapple animation
		rotate_character()
	else:
		# ---- NORMAL MOVEMENT LOGIC ----
		if not on_floor_now:
			velocity += get_gravity() * delta

		handle_movement(delta)
		update_animations()
		rotate_character()
		update_collision_shape(delta)

		# Handle mining - hold E to mine (after threshold)
		if Input.is_action_pressed("interact"):
			interact_hold_time += delta

			# Start mining after holding for threshold duration
			if interact_hold_time >= INTERACT_HOLD_THRESHOLD:
				var nearest_node = find_nearest_resource_node()
				if nearest_node and not is_mining:
					start_mining()
				elif not nearest_node and is_mining:
					stop_mining()
		else:
			# Stop mining when E is released
			if is_mining:
				stop_mining()
			interact_hold_time = 0.0

	# Update floor state for next frame
	was_on_floor = on_floor_now

	# This must be called in both cases
	move_and_slide()

	# Keep character model at base position to prevent animation drift
	# Apply crouch offset when crouching with smooth transition
	if character_model:
		var target_y = model_base_position.y
		if is_crouching:
			# Use a smaller offset if moving
			if movement_speed > 0.1:
				target_y += crouch_offset / 2.0  # Less crouch when moving
			else:
				target_y += crouch_offset
		# Smoother lerp for crouch transition (slower speed = 5.0 instead of 10.0)
		character_model.position.y = lerp(character_model.position.y, target_y, 5.0 * delta)
		character_model.position.x = model_base_position.x
		character_model.position.z = model_base_position.z

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

	# Priority order: Grapple -> Jump (active) -> Fall -> Crouch (moving/idle) -> Movement -> Idle
	if is_grappling and grapple_anim != "":
		# Keep playing grapple animation while grappling
		if not animation_player.is_playing() or current_anim != grapple_anim:
			target_anim = grapple_anim
		else:
			# Let grapple animation continue playing
			return
	elif is_jumping and jump_anim != "":
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
	elif is_crouching:
		# Check if moving while crouched
		if movement_speed > 0.1 and crouch_walk_anim != "":
			target_anim = crouch_walk_anim
		elif crouch_anim != "":
			target_anim = crouch_anim
		else:
			# Fallback to regular idle if no crouch animations
			target_anim = idle_anim
	elif movement_speed > 0.2:
		# Use target_speed to determine animation (sprint uses run_speed)
		if Input.is_action_pressed("sprint") and run_anim != "":
			target_anim = run_anim
		elif walk_anim != "":
			target_anim = walk_anim
		else:
			target_anim = idle_anim
	else:
		target_anim = idle_anim

	if target_anim != "" and target_anim != current_anim:
		play_anim(target_anim)

	# Sync animation speed with movement speed
	sync_animation_speed()

func sync_animation_speed():
	"""Sync animation playback speed with movement speed to prevent foot sliding"""
	if not animation_player:
		return

	# Only sync movement animations
	if current_anim in [walk_anim, run_anim, crouch_walk_anim]:
		# Calculate speed scale based on actual velocity
		var horizontal_velocity = Vector2(velocity.x, velocity.z).length()

		# Get the expected speed for the current animation
		var expected_speed = walk_speed
		if current_anim == run_anim:
			expected_speed = run_speed
		elif current_anim == crouch_walk_anim:
			expected_speed = walk_speed * 0.5  # Crouch speed

		# Calculate speed scale with tighter clamping to avoid extreme speeds
		var raw_scale = horizontal_velocity / expected_speed if expected_speed > 0 else 1.0
		var speed_scale = clamp(raw_scale, 0.8, 1.2)  # Limit between 80% and 120% speed

		# Apply speed scale
		animation_player.speed_scale = speed_scale
	else:
		# Reset to normal speed for non-movement animations
		animation_player.speed_scale = 1.0

func rotate_character():
	if character_model and last_direction.length() > 0.1:
		var target_rotation = atan2(last_direction.x, last_direction.z)
		character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation, 0.15)

func update_collision_shape(delta: float):
	"""Smoothly adjust collision shape height AND position when crouching/standing"""
	var target_height = stand_height if not is_crouching else crouch_height

	if collision_shape.shape is CapsuleShape3D:
		var current_shape: CapsuleShape3D = collision_shape.shape

		# Smoothly interpolate the height
		current_shape.height = lerp(current_shape.height, target_height, 10.0 * delta)

		# Smoothly interpolate the position to keep the bottom of the capsule on the floor
		var target_pos_y = stand_collider_position.y + (stand_height - current_shape.height) / 2.0
		collision_shape.position.y = lerp(collision_shape.position.y, target_pos_y, 10.0 * delta)

# Item Interaction Functions
func drop_selected_item():
	if not InventorySystem:
		return

	# Drop the first item found in inventory
	for slot in InventorySystem.inventory_slots:
		if not slot.is_empty():
			var drop_position = get_drop_position()
			if InventorySystem.drop_item_from_slot(InventorySystem.inventory_slots.find(slot), 1, drop_position):
				print("Dropped %s at player feet" % slot.item_id)
				return

func get_drop_position() -> Vector3:
	# Drop position: right at player's feet with slight offset
	var drop_pos = Vector3(global_position.x, global_position.y + 1.0, global_position.z)

	# Add small random offset so multiple items don't stack exactly
	drop_pos.x += randf_range(-0.3, 0.3)
	drop_pos.z += randf_range(-0.3, 0.3)

	return drop_pos

func pickup_nearest_item():
	# Find the nearest item pickup
	var nearest_item = null
	var min_distance = interact_range

	# Get all item pickups in the scene
	var items = get_tree().get_nodes_in_group("item_pickups")
	for item in items:
		if item.has_method("collect_item"):
			var distance = global_position.distance_to(item.global_position)
			if distance < min_distance:
				nearest_item = item
				min_distance = distance

	if nearest_item:
		print("Picking up item at distance: %f" % min_distance)
		nearest_item.collect_item()
	else:
		print("No items nearby to pick up")

func add_test_items():
	# Add some test items to inventory for testing drops
	if InventorySystem:
		InventorySystem.add_item("WOOD_SCRAPS", 10)
		InventorySystem.add_item("METAL_SCRAPS", 5)
		InventorySystem.add_item("GEARS", 3)
		print("Added test items to inventory for drop testing")

func toggle_inventory():
	# Toggle inventory UI directly
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui:
		inventory_ui.toggle_inventory()
	else:
		print("InventoryUI not found")

# 3D Interaction System
func setup_interaction_area():
	# Create Area3D for detecting interactable objects
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)

	# Create collision shape for interaction range
	var interaction_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interact_range
	interaction_shape.shape = sphere_shape
	interaction_area.add_child(interaction_shape)

	# Configure area to detect interactables
	interaction_area.collision_layer = 1 << 1  # Put on player layer (layer 2)
	interaction_area.collision_mask = 0xFFFFFFFF  # Detect everything
	interaction_area.monitoring = true
	interaction_area.monitorable = false  # Player doesn't need to be detected by other areas

	# Also connect area signals for Area3D detection
	interaction_area.area_entered.connect(_on_area_entered_interaction)
	interaction_area.area_exited.connect(_on_area_exited_interaction)

	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered_interaction)
	interaction_area.body_exited.connect(_on_body_exited_interaction)

	print("PlayerAnimated3D: Interaction area set up with range: %f" % interact_range)

func interact_with_nearest() -> void:
	# print("Player3D: interact_with_nearest() called")
	# print("Player3D: Number of nearby interactables = ", nearby_interactables.size())

	if nearby_interactables.is_empty():
		# print("Player3D: No nearby interactables found")  # Debug: Too spammy
		# Fallback to old item pickup behavior if no interactables
		pickup_nearest_item()
		return

	var nearest = nearby_interactables[0]
	var min_dist = global_position.distance_to(nearest.global_position)

	for interactable in nearby_interactables:
		# print("Player3D: Found interactable: ", interactable.name, " of type: ", interactable.get_class())  # Debug: Too spammy
		var dist = global_position.distance_to(interactable.global_position)
		if dist < min_dist:
			nearest = interactable
			min_dist = dist

	# print("Player3D: Interacting with nearest: ", nearest.name, " at distance: ", min_dist)
	nearest.interact()

func _on_body_entered_interaction(body: Node3D) -> void:
	# print("Player3D: Body entered interaction area: ", body.name, " (", body.get_class(), ")")
	# print("Player3D: Body has interact method: ", body.has_method("interact"))
	if body.has_method("interact"):
		nearby_interactables.append(body)
		# print("Player3D: Added to nearby_interactables. Total count: ", nearby_interactables.size())  # Debug: Too spammy
	# else:
		# print("Player3D: Body does not have interact method, not adding to interactables")  # Debug: Too spammy

func _on_body_exited_interaction(body: Node3D) -> void:
	# print("Player3D: Body exited interaction area: ", body.name)
	nearby_interactables.erase(body)
	# print("Player3D: Remaining nearby_interactables: ", nearby_interactables.size())

func _on_area_entered_interaction(area: Area3D) -> void:
	# print("Player3D: Area entered interaction area: ", area.name, " (", area.get_class(), ")")
	var parent = area.get_parent()
	if parent and parent.has_method("interact"):
		# print("Player3D: Area's parent has interact method: ", parent.name)  # Debug: Too spammy
		nearby_interactables.append(parent)
		# print("Player3D: Added area parent to nearby_interactables. Total count: ", nearby_interactables.size())  # Debug: Too spammy
	# else:
		# print("Player3D: Area's parent does not have interact method")  # Debug: Too spammy

func _on_area_exited_interaction(area: Area3D) -> void:
	# print("Player3D: Area exited interaction area: ", area.name)
	var parent = area.get_parent()
	if parent:
		nearby_interactables.erase(parent)
		# print("Player3D: Remaining nearby_interactables: ", nearby_interactables.size())  # Debug: Too spammy

# ============================================================================
# SURVIVAL STAT MANAGEMENT
# ============================================================================

func modify_health(amount: int) -> void:
	"""Modify health by amount (positive or negative)"""
	var old_health = health
	health = clampi(health + amount, 0, max_health)
	print("  modify_health: %d -> %d (change: %d)" % [old_health, health, amount])
	print("  Emitting health_changed signal with value: %d" % health)
	health_changed.emit(health)
	if health <= 0:
		die()

func modify_energy(amount: int) -> void:
	"""Modify energy by amount (positive or negative)"""
	energy = clampi(energy + amount, 0, max_energy)
	energy_changed.emit(energy)

func modify_hunger(amount: int) -> void:
	"""Modify hunger by amount (positive or negative)"""
	hunger = clampi(hunger + amount, 0, max_hunger)
	hunger_changed.emit(hunger)
	if hunger <= 0:
		# Starving - take health damage
		modify_health(-1)

func modify_thirst(amount: int) -> void:
	"""Modify thirst by amount (positive or negative)"""
	thirst = clampi(thirst + amount, 0, max_thirst)
	thirst_changed.emit(thirst)
	if thirst <= 0:
		# Dehydrated - take health damage
		modify_health(-2)

func modify_radiation(amount: float) -> void:
	"""Modify radiation damage by amount (positive or negative)"""
	current_radiation_damage = clampf(current_radiation_damage + amount, 0.0, max_radiation_damage)
	radiation_changed.emit(current_radiation_damage, max_radiation_damage)

func get_radiation_level_text() -> String:
	"""Get text description of radiation level"""
	var rad_pct = current_radiation_damage / max_radiation_damage
	if rad_pct <= 0.25:
		return "Safe"
	elif rad_pct <= 0.5:
		return "Mild"
	elif rad_pct <= 0.75:
		return "Moderate"
	else:
		return "Severe"

func consume_item(item_id: String) -> bool:
	"""Consume an item for its effects"""
	var item_data = InventorySystem.get_item_data(item_id)
	if item_data.get("category", "").to_lower() != "consumable":
		return false

	# Apply consumable effects
	var effects = item_data.get("effects", {})
	if effects.has("health"):
		modify_health(effects.health)
	if effects.has("energy"):
		modify_energy(effects.energy)
	if effects.has("hunger"):
		modify_hunger(effects.hunger)
	if effects.has("thirst"):
		modify_thirst(effects.thirst)
	if effects.has("radiation"):
		modify_radiation(effects.radiation)

	return true

func setup_depletion_timers() -> void:
	"""Set up timers for hunger and thirst depletion"""
	# Create hunger timer
	hunger_timer = Timer.new()
	hunger_timer.name = "HungerTimer"
	hunger_timer.wait_time = HUNGER_DEPLETION_RATE
	hunger_timer.autostart = true
	hunger_timer.timeout.connect(_on_hunger_timer_timeout)
	add_child(hunger_timer)

	# Create thirst timer
	thirst_timer = Timer.new()
	thirst_timer.name = "ThirstTimer"
	thirst_timer.wait_time = THIRST_DEPLETION_RATE
	thirst_timer.autostart = true
	thirst_timer.timeout.connect(_on_thirst_timer_timeout)
	add_child(thirst_timer)

	print("Survival depletion timers initialized (Hunger: %ss, Thirst: %ss)" % [HUNGER_DEPLETION_RATE, THIRST_DEPLETION_RATE])

func _on_hunger_timer_timeout() -> void:
	"""Called when hunger timer times out - deplete hunger by 1"""
	modify_hunger(-1)
	if hunger <= 20:
		print("WARNING: Hunger is low! (%d/100)" % hunger)

func _on_thirst_timer_timeout() -> void:
	"""Called when thirst timer times out - deplete thirst by 1"""
	modify_thirst(-1)
	if thirst <= 20:
		print("WARNING: Thirst is low! (%d/100)" % thirst)

func die() -> void:
	"""Handle player death"""
	print("Player died!")

	# Play death animation if available
	if death_anim != "" and animation_player:
		animation_player.play(death_anim)
		current_anim = death_anim
		# Disable player controls during death
		set_physics_process(false)
		# Wait for animation to complete before respawning
		if animation_player.has_animation(death_anim):
			var anim_length = animation_player.get_animation(death_anim).length
			await get_tree().create_timer(anim_length).timeout
		set_physics_process(true)

	# TODO: Implement death handling (respawn, game over, etc.)
	# For now, just reset health
	health = max_health
	health_changed.emit(health)

# ============================================================================
# COMBAT SYSTEM
# ============================================================================

func setup_combat_timers() -> void:
	"""Set up timers for invincibility frames and damage flash"""
	print("Setting up combat timers...")

	# Invincibility timer
	invincibility_timer = Timer.new()
	invincibility_timer.name = "InvincibilityTimer"
	invincibility_timer.wait_time = invincibility_duration
	invincibility_timer.one_shot = true
	invincibility_timer.timeout.connect(_on_invincibility_timeout)
	add_child(invincibility_timer)
	print("  Invincibility timer created: %s seconds" % invincibility_duration)

	# Damage flash timer
	damage_flash_timer = Timer.new()
	damage_flash_timer.name = "DamageFlashTimer"
	damage_flash_timer.wait_time = damage_flash_duration
	damage_flash_timer.one_shot = true
	damage_flash_timer.timeout.connect(_on_damage_flash_timeout)
	add_child(damage_flash_timer)
	print("  Damage flash timer created: %s seconds" % damage_flash_duration)

func take_damage(amount: int, damage_type: String = "physical", source: Node = null) -> void:
	"""Take damage from external sources"""
	print("=== take_damage() called ===")
	print("  Amount: %d, Type: %s, Source: %s" % [amount, damage_type, source.name if source else "unknown"])
	print("  Current health: %d" % health)
	print("  Is invincible: %s" % is_invincible)

	# Check invincibility frames
	if is_invincible:
		print("  BLOCKED: Player is invincible!")
		return

	# Apply damage
	print("  Applying damage via modify_health(-amount)")
	modify_health(-amount)
	print("  Health after damage: %d" % health)

	# Start invincibility frames
	is_invincible = true
	print("  Starting invincibility timer (%s seconds)" % invincibility_duration)
	invincibility_timer.start()

	# Trigger damage flash effect
	print("  Triggering damage flash")
	apply_damage_flash()
	print("=== take_damage() complete ===")

func apply_damage_flash() -> void:
	"""Apply red flash effect to character model"""
	print("  apply_damage_flash() - character_model exists: %s" % (character_model != null))
	if not character_model:
		print("  ERROR: No character_model found!")
		return

	if original_model_materials.is_empty():
		print("  Storing original materials...")
		store_original_materials(character_model)
		print("  Stored %d materials" % original_model_materials.size())

	print("  Applying red tint to model...")
	apply_red_tint_to_model(character_model)
	print("  Starting damage flash timer (%s seconds)" % damage_flash_duration)
	damage_flash_timer.start()

func store_original_materials(node: Node) -> void:
	"""Recursively store original materials from all MeshInstance3D nodes"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var surface_count = mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0

		for i in range(surface_count):
			# Store any existing override material
			var override_mat = mesh_instance.get_surface_override_material(i)
			# Also get the base surface material for reference
			var surface_mat = mesh_instance.mesh.surface_get_material(i) if mesh_instance.mesh else null

			# Store the material we'll need to restore (prefer override, fallback to surface)
			var material_to_store = override_mat if override_mat else surface_mat
			if material_to_store:
				original_model_materials.append({
					"mesh": mesh_instance,
					"surface": i,
					"material": material_to_store,
					"was_override": (override_mat != null)
				})
				print("    Stored material from %s surface %d" % [mesh_instance.name, i])

	for child in node.get_children():
		store_original_materials(child)

func apply_red_tint_to_model(node: Node) -> void:
	"""Recursively apply red tint to all MeshInstance3D nodes"""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		# Check both override materials and surface materials
		var surface_count = mesh_instance.mesh.get_surface_count() if mesh_instance.mesh else 0

		for i in range(surface_count):
			# Try to get override material first
			var material = mesh_instance.get_surface_override_material(i)
			# If no override, get the surface material from the mesh
			if not material and mesh_instance.mesh:
				material = mesh_instance.mesh.surface_get_material(i)

			if material:
				print("    Found material on %s surface %d: %s" % [mesh_instance.name, i, material.get_class()])
				# Create red tinted version
				var red_material = material.duplicate()
				if red_material is StandardMaterial3D:
					red_material.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
				elif red_material is BaseMaterial3D:
					red_material.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
				mesh_instance.set_surface_override_material(i, red_material)

	for child in node.get_children():
		apply_red_tint_to_model(child)

func restore_original_materials() -> void:
	"""Restore all original materials"""
	for mat_data in original_model_materials:
		var mesh_instance = mat_data.mesh as MeshInstance3D
		if mesh_instance and is_instance_valid(mesh_instance):
			mesh_instance.set_surface_override_material(mat_data.surface, mat_data.material)

	original_model_materials.clear()

func _on_invincibility_timeout() -> void:
	"""Called when invincibility timer expires"""
	is_invincible = false
	print("Invincibility expired")

func _on_damage_flash_timeout() -> void:
	"""Called when damage flash timer expires"""
	restore_original_materials()

# ============================================================================
# MINING SYSTEM
# ============================================================================

func setup_mining_timer() -> void:
	"""Set up timer for mining hits"""
	mining_timer = Timer.new()
	mining_timer.name = "MiningTimer"
	mining_timer.wait_time = mining_hit_rate
	mining_timer.timeout.connect(_on_mining_timer_timeout)
	add_child(mining_timer)
	print("Mining timer initialized (Hit rate: %ss)" % mining_hit_rate)

func start_mining() -> void:
	"""Start mining the nearest resource node"""
	if is_mining:
		return

	# Find nearest resource node
	var nearest_node = find_nearest_resource_node()
	if not nearest_node:
		return

	# Check if player has required tool equipped
	var equipped_tool = get_equipped_tool()
	var tool_level = get_equipped_tool_level()

	if not nearest_node.can_mine(equipped_tool, tool_level):
		print("Cannot mine %s - requires %s level %d (you have: %s level %d)" % [
			nearest_node.name,
			nearest_node.required_tool,
			nearest_node.required_tool_level,
			equipped_tool,
			tool_level
		])
		return

	# Start mining
	is_mining = true
	current_mining_target = nearest_node
	mining_timer.start()

	# Immediate first hit
	_on_mining_timer_timeout()

	print("Started mining %s" % nearest_node.name)

func stop_mining() -> void:
	"""Stop mining"""
	if not is_mining:
		return

	is_mining = false
	mining_timer.stop()

	# Stop visual effect on target
	if current_mining_target and is_instance_valid(current_mining_target):
		current_mining_target.stop_mining_effect()

	current_mining_target = null
	print("Stopped mining")

func _on_mining_timer_timeout() -> void:
	"""Called when mining timer times out - apply damage to node"""
	if not is_mining or not current_mining_target or not is_instance_valid(current_mining_target):
		stop_mining()
		return

	# Check if still in range
	var distance = global_position.distance_to(current_mining_target.global_position)
	if distance > interact_range:
		print("Mining target out of range")
		stop_mining()
		return

	# Get current tool info
	var equipped_tool = get_equipped_tool()
	var tool_level = get_equipped_tool_level()

	# Apply damage
	var destroyed = current_mining_target.mine(mining_damage_per_hit, equipped_tool, tool_level)

	if destroyed:
		print("Destroyed resource node!")
		stop_mining()

func find_nearest_resource_node() -> ResourceNode:
	"""Find the nearest resource node within interact range"""
	var nearest: ResourceNode = null
	var min_distance = interact_range

	# Check all nodes in the resource_nodes group
	var nodes = get_tree().get_nodes_in_group("resource_nodes")
	for node in nodes:
		if node is ResourceNode and not node.is_destroyed:
			var distance = global_position.distance_to(node.global_position)
			if distance < min_distance:
				nearest = node
				min_distance = distance

	return nearest

func get_equipped_tool() -> String:
	"""Get the currently equipped tool type - prioritizes TOOL slot over WEAPON slot"""
	if not EquipmentManager:
		return "None"

	# First check TOOL slot (dedicated tool slot)
	var tool_equipment = EquipmentManager.get_equipped_item("TOOL")
	if tool_equipment:
		# Get data from EquipmentManager's equipment_data, not InventorySystem
		if EquipmentManager.equipment_data.has(tool_equipment.id):
			var equipment_data = EquipmentManager.equipment_data[tool_equipment.id]
			if equipment_data.has("tool_type"):
				return equipment_data.tool_type

	# Fallback to WEAPON slot (for backwards compatibility)
	var weapon_equipment = EquipmentManager.get_equipped_item("WEAPON")
	if weapon_equipment:
		if EquipmentManager.equipment_data.has(weapon_equipment.id):
			var equipment_data = EquipmentManager.equipment_data[weapon_equipment.id]
			if equipment_data.has("tool_type"):
				return equipment_data.tool_type

	return "None"

func get_equipped_tool_level() -> int:
	"""Get the level of the currently equipped tool - prioritizes TOOL slot over WEAPON slot"""
	if not EquipmentManager:
		return 0

	# First check TOOL slot (dedicated tool slot)
	var tool_equipment = EquipmentManager.get_equipped_item("TOOL")
	if tool_equipment:
		# Get data from EquipmentManager's equipment_data, not InventorySystem
		if EquipmentManager.equipment_data.has(tool_equipment.id):
			var equipment_data = EquipmentManager.equipment_data[tool_equipment.id]
			if equipment_data.has("tool_level"):
				return equipment_data.tool_level

	# Fallback to WEAPON slot (for backwards compatibility)
	var weapon_equipment = EquipmentManager.get_equipped_item("WEAPON")
	if weapon_equipment:
		if EquipmentManager.equipment_data.has(weapon_equipment.id):
			var equipment_data = EquipmentManager.equipment_data[weapon_equipment.id]
			if equipment_data.has("tool_level"):
				return equipment_data.tool_level

	return 0

# ============================================================================
# GRAPPLING HOOK SYSTEM
# ============================================================================

func fire_grapple() -> void:
	"""Fire the grappling hook"""
	if is_grappling:
		return

	# Check if raycast hits something
	if grapple_raycast.is_colliding():
		var collision_point = grapple_raycast.get_collision_point()
		var distance = global_position.distance_to(collision_point)

		# Check if within range
		if distance <= grapple_range:
			is_grappling = true
			grapple_point = collision_point

			# Show hook point at collision
			grapple_hook_point.global_position = collision_point
			grapple_hook_point.visible = true

			# Show rope
			grapple_rope.visible = true
			update_grapple_rope()

			print("Grapple fired! Distance: %.1f" % distance)

func release_grapple() -> void:
	"""Release the grappling hook"""
	if not is_grappling:
		return

	is_grappling = false
	grapple_hook_point.visible = false
	grapple_rope.visible = false

	# Give a small upward boost when releasing
	velocity.y = jump_velocity * 0.5

	print("Grapple released!")

func handle_grapple_movement(delta: float) -> void:
	"""Handle player movement while grappling"""
	if not is_grappling:
		return

	# Calculate direction to grapple point
	var direction = (grapple_point - global_position).normalized()

	# Pull player toward grapple point
	var target_velocity = direction * grapple_speed
	velocity = velocity.lerp(target_velocity, delta * 5.0) # Smoothly accelerate	

	# Update rope visual
	update_grapple_rope()

	# Check if player is close enough to stop grappling
	if global_position.distance_to(grapple_point) < 2.0:
		release_grapple()

func update_grapple_rope() -> void:
	"""Update the rope mesh to stretch between player and hook"""
	if not is_grappling:
		return

	# Calculate midpoint and distance
	var start_pos = global_position + Vector3(0, 1.5, 0)  # From player's chest area
	var end_pos = grapple_hook_point.global_position
	var midpoint = (start_pos + end_pos) / 2.0
	var distance = start_pos.distance_to(end_pos)

	# Position rope at midpoint
	grapple_rope.global_position = midpoint

	# Scale rope to match distance
	var rope_mesh = grapple_rope.mesh as CylinderMesh
	if rope_mesh:
		rope_mesh.height = distance

	# Rotate rope to point from player to hook
	grapple_rope.look_at(end_pos, Vector3.UP)
	grapple_rope.rotate_object_local(Vector3.RIGHT, PI / 2)  # Cylinders are vertical by default
