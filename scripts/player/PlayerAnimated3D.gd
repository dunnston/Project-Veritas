extends CharacterBody3D

@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var sprint_speed: float = 9.0
@export var jump_velocity: float = 8.0
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

var animation_player: AnimationPlayer
var camera_rotation: Vector2 = Vector2.ZERO
var movement_speed: float = 0.0
var last_direction: Vector3 = Vector3.ZERO
var current_anim: String = ""
var is_crouching: bool = false
var model_base_position: Vector3 = Vector3.ZERO
var is_jumping: bool = false
var was_on_floor: bool = true

# Interaction system for 3D
var nearby_interactables: Array = []
var interaction_area: Area3D = null

# Mining system
var is_mining: bool = false
var current_mining_target: ResourceNode = null
var mining_timer: Timer = null

# Survival stat depletion timers
var hunger_timer: Timer
var thirst_timer: Timer
const HUNGER_DEPLETION_RATE: float = 60.0  # Lose 1 hunger every 60 seconds
const THIRST_DEPLETION_RATE: float = 45.0  # Lose 1 thirst every 45 seconds

# Animation names (will be detected from AnimationPlayer)
var idle_anim: String = ""
var walk_anim: String = ""
var run_anim: String = ""
var jump_anim: String = ""
var crouch_anim: String = ""
var fall_anim: String = ""

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")

	# Initialize survival stats
	initialize_stats()

	# Register with GameManager (defer to avoid autoload conflicts)
	call_deferred("_register_with_game_manager")
	# Store the original position of the character model
	model_base_position = character_model.position
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
		# print("✅ Found AnimationPlayer with animations:")  # Debug: Setup only
		var all_anims = animation_player.get_animation_list()
		# print("Available animations: ", all_anims)  # Debug: Setup only

		# Disable root motion if AnimationPlayer supports it
		if animation_player.has_method("set_root_motion_track"):
			animation_player.set_root_motion_track(NodePath())
			# print("Disabled root motion")  # Debug: Setup only

		# Ensure animations are set to loop where appropriate
		for anim_name in all_anims:
			var animation = animation_player.get_animation(anim_name)
			if animation:
				var lower = anim_name.to_lower()
				# Set looping for continuous animations
				if "idle" in lower or "walk" in lower or "run" in lower or "crouch" in lower:
					animation.loop_mode = Animation.LOOP_LINEAR
					# print("Set ", anim_name, " to loop")  # Debug: Setup only
					# Remove position tracks that cause jumping
					remove_position_tracks(animation, anim_name)
				elif "jump" in lower:
					animation.loop_mode = Animation.LOOP_NONE
					# print("Set ", anim_name, " to play once")  # Debug: Setup only

		# Map animations based on common naming patterns
		for anim_name in all_anims:
			var lower = anim_name.to_lower()
			# print("Checking animation: ", anim_name, " (", lower, ")")  # Debug: Setup only

			if "crouch" in lower:
				crouch_anim = anim_name
				# print("  -> Mapped as CROUCH")  # Debug: Setup only
			elif "jump" in lower:
				jump_anim = anim_name
				# print("  -> Mapped as JUMP")  # Debug: Setup only
			elif "run" in lower and "walk" not in lower:
				run_anim = anim_name
				# print("  -> Mapped as RUN")  # Debug: Setup only
			elif "walk" in lower:
				walk_anim = anim_name
				# print("  -> Mapped as WALK")  # Debug: Setup only
			elif "fall" in lower:
				fall_anim = anim_name
				# print("  -> Mapped as FALL")  # Debug: Setup only
			elif "idle" in lower or "breathing" in lower:
				idle_anim = anim_name
				# print("  -> Mapped as IDLE")  # Debug: Setup only

		# print("\nFinal animation mapping:")  # Debug: Setup only
		# print("  Idle: ", idle_anim)
		# print("  Walk: ", walk_anim)
		# print("  Run: ", run_anim)
		# print("  Jump: ", jump_anim)
		# print("  Crouch: ", crouch_anim)
		# print("  Fall: ", fall_anim)

		# Ensure we start with idle animation, not first in list
		if idle_anim != "":
			animation_player.play(idle_anim)
			current_anim = idle_anim
			# print("Starting with idle animation: ", idle_anim)  # Debug: Setup only
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
				# print("  Removing body position track: ", path_str)  # Debug: Setup only

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
				# print("Playing animation: ", anim_name)
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

	# Removed world right-click drop functionality

	# Handle interactions (items, workbenches, doors, etc.)
	if event.is_action_pressed("interact"):
		interact_with_nearest()

	# Handle inventory toggle
	if event.is_action_pressed("inventory"):
		toggle_inventory()

	# Handle mining
	if event.is_action_pressed("attack"):  # Left click
		start_mining()
	elif event.is_action_released("attack"):
		stop_mining()

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
	# Toggle inventory UI
	if GameManager and GameManager.has_method("toggle_inventory"):
		GameManager.toggle_inventory()
	else:
		print("Inventory toggle not implemented yet")

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
	health = clampi(health + amount, 0, max_health)
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
	# TODO: Implement death handling (respawn, game over, etc.)
	# For now, just reset health
	health = max_health
	health_changed.emit(health)

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
	if not EquipmentManager or not EquipmentManager.has_method("get_equipped_item"):
		return "None"

	# First check TOOL slot (dedicated tool slot)
	var tool_slot = EquipmentManager.get_equipped_item("TOOL")
	if tool_slot and not tool_slot.is_empty():
		var item_data = InventorySystem.get_item_data(tool_slot.item_id)
		if item_data.has("tool_type"):
			return item_data.tool_type

	# Fallback to WEAPON slot (for backwards compatibility)
	var weapon_slot = EquipmentManager.get_equipped_item("WEAPON")
	if weapon_slot and not weapon_slot.is_empty():
		var item_data = InventorySystem.get_item_data(weapon_slot.item_id)
		if item_data.has("tool_type"):
			return item_data.tool_type

	return "None"

func get_equipped_tool_level() -> int:
	"""Get the level of the currently equipped tool - prioritizes TOOL slot over WEAPON slot"""
	if not EquipmentManager or not EquipmentManager.has_method("get_equipped_item"):
		return 0

	# First check TOOL slot (dedicated tool slot)
	var tool_slot = EquipmentManager.get_equipped_item("TOOL")
	if tool_slot and not tool_slot.is_empty():
		var item_data = InventorySystem.get_item_data(tool_slot.item_id)
		if item_data.has("tool_level"):
			return item_data.tool_level

	# Fallback to WEAPON slot (for backwards compatibility)
	var weapon_slot = EquipmentManager.get_equipped_item("WEAPON")
	if weapon_slot and not weapon_slot.is_empty():
		var item_data = InventorySystem.get_item_data(weapon_slot.item_id)
		if item_data.has("tool_level"):
			return item_data.tool_level

	return 0