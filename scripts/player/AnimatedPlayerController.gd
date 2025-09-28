extends CharacterBody2D
class_name AnimatedPlayer

signal health_changed(new_health: int)
signal energy_changed(new_energy: int)
signal hunger_changed(new_hunger: int)
signal thirst_changed(new_thirst: int)
signal radiation_changed(current_radiation: float, max_radiation: float)

@export var speed: float = 160.0
@export var sprint_speed: float = 240.0
@export var crouch_speed: float = 80.0  # 50% of normal speed
@export var acceleration: float = 800.0
@export var friction: float = 1000.0

# Player stats
@export var max_health: int = 100
@export var max_energy: int = 100
@export var base_max_energy: int = 100  # Original max energy before radiation effects
@export var max_hunger: int = 100
@export var max_thirst: int = 100

# Attribute modifiers (for AttributeManager integration)
var speed_modifier: float = 1.0
var crafting_speed_modifier: float = 1.0
var damage_modifier: float = 1.0
var crit_chance_modifier: float = 0.0
var crit_damage_modifier: float = 1.5
var armor_pen_modifier: float = 0.0
var armor_modifier: float = 0.0
var fire_resistance_modifier: float = 0.0
var cold_resistance_modifier: float = 0.0
var defense: float = 0.0
var bonus_inventory_slots: int = 0

# Stealth attributes
@export var base_stealth: float = 50.0  # Base stealth value (0-100 scale)
var stealth_modifier: float = 1.0        # Equipment/perk multiplier
var crouch_stealth_bonus: float = 25.0   # Additional stealth when crouching

var health: float = 100.0
var energy: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0

# Radiation system - permanent accumulation
@export var max_radiation_damage: float = 100.0
var current_radiation_damage: float = 0.0
var in_radiation_zone: bool = false
var current_radiation_intensity: float = 0.0
var radiation_timer: float = 0.0

enum Direction { SOUTH, NORTH, EAST, WEST }
enum AnimationState { IDLE, WALKING, RUNNING, CROUCHED_IDLE, CROUCH_WALKING, PICKING_UP, DRINKING, COMBAT, SPECIAL }
enum StealthState { STANDING, CROUCHING }

var current_direction: Direction = Direction.SOUTH
var current_state: AnimationState = AnimationState.IDLE
var current_stealth_state: StealthState = StealthState.STANDING
var is_sprinting: bool = false
var is_moving: bool = false
var is_crouching: bool = false
var stealth_transition_in_progress: bool = false
var nearby_interactables: Array = []
var inventory: Inventory

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

# Animation state tracking
var action_playing: bool = false
var action_queue: Array = []


signal direction_changed(new_direction: Direction)
signal animation_finished(animation_name: String)

func _ready() -> void:
	# Player initialization
	add_to_group("player")
	
	if interaction_area:
		# Fix collision mask to detect interactables (layer 8)
		interaction_area.collision_mask = 128  # Layer 8 = bit 7 = 2^7 = 128
	else:
		print("ERROR: No InteractionArea found in player!")
	
	# Check if AnimatedSprite2D node exists
	if not animated_sprite:
		print("ERROR: AnimatedSprite2D not found! Looking for it...")
		animated_sprite = get_node("AnimatedSprite2D")
		if not animated_sprite:
			print("FATAL ERROR: Could not find AnimatedSprite2D node!")
			return
	
	# AnimatedSprite2D found
	
	# Delay animation setup to allow files to be properly imported
	await get_tree().process_frame
	_setup_animations()

	# Setup taking-punch animations
	_setup_taking_punch_animations()
	
	# Only play idle animation after sprite_frames is set up
	if animated_sprite and animated_sprite.sprite_frames:
		_play_idle_animation()
	else:
		print("Cannot play idle animation - sprite_frames not ready")
	
	# Animation setup complete
	
	# Initialize base stats
	base_max_energy = max_energy
	
	# Initialize inventory
	inventory = Inventory.new()
	add_child(inventory)
	
	# Initial mining tools now handled by GameManager.add_initial_mining_tools()
	
	# Register with GameManager
	if GameManager:
		GameManager.register_player(self)
	
	# Connect interaction area signals
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered_interaction)
		interaction_area.body_exited.connect(_on_body_exited_interaction)
		pass  # Signals connected successfully
	else:
		print("ERROR: Cannot connect InteractionArea signals")
	
	# Connect EventBus signals
	EventBus.player_damaged.connect(_on_damage_received)
	EventBus.player_healed.connect(_on_heal_received)
	
	# Player initialization complete

func _setup_animations() -> void:
	var sprite_frames = SpriteFrames.new()
	
	# Setting up player animations
	
	# Load core movement animations with correct frame counts
	_load_animation_fixed(sprite_frames, "idle_south", "breathing-idle/south", 4, true)
	_load_animation_fixed(sprite_frames, "idle_north", "breathing-idle/north", 4, true)
	_load_animation_fixed(sprite_frames, "idle_east", "breathing-idle/east", 4, true)
	_load_animation_fixed(sprite_frames, "idle_west", "breathing-idle/west", 4, true)
	
	_load_animation_fixed(sprite_frames, "walk_south", "walking/south", 6, true)
	_load_animation_fixed(sprite_frames, "walk_north", "walking/north", 6, true)
	_load_animation_fixed(sprite_frames, "walk_east", "walking/east", 6, true)
	_load_animation_fixed(sprite_frames, "walk_west", "walking/west", 6, true)
	
	_load_animation_fixed(sprite_frames, "run_south", "running-6-frames/south", 6, true)
	_load_animation_fixed(sprite_frames, "run_north", "running-6-frames/north", 6, true)
	_load_animation_fixed(sprite_frames, "run_east", "running-6-frames/east", 6, true)
	_load_animation_fixed(sprite_frames, "run_west", "running-6-frames/west", 6, true)
	
	# Load crouch animations (placeholder - will use crouching animations when available)
	# Using crouched-walking as fallback for both idle and walking crouching states
	_load_animation_fixed(sprite_frames, "crouch_idle_south", "crouched-walking/south", 5, true)
	_load_animation_fixed(sprite_frames, "crouch_idle_north", "crouched-walking/north", 5, true)
	_load_animation_fixed(sprite_frames, "crouch_idle_east", "crouched-walking/east", 5, true)
	_load_animation_fixed(sprite_frames, "crouch_idle_west", "crouched-walking/west", 5, true)
	
	_load_animation_fixed(sprite_frames, "crouch_walk_south", "crouched-walking/south", 6, true)
	_load_animation_fixed(sprite_frames, "crouch_walk_north", "crouched-walking/north", 6, true)
	_load_animation_fixed(sprite_frames, "crouch_walk_east", "crouched-walking/east", 6, true)
	_load_animation_fixed(sprite_frames, "crouch_walk_west", "crouched-walking/west", 6, true)
	
	# Load action animations with known frame counts
	_load_animation_fixed(sprite_frames, "pickup_south", "picking-up/south", 5, false)
	_load_animation_fixed(sprite_frames, "pickup_north", "picking-up/north", 5, false)
	_load_animation_fixed(sprite_frames, "pickup_east", "picking-up/east", 5, false)
	_load_animation_fixed(sprite_frames, "pickup_west", "picking-up/west", 5, false)
	
	_load_animation_fixed(sprite_frames, "drink_south", "drinking/south", 6, false)
	_load_animation_fixed(sprite_frames, "drink_north", "drinking/north", 6, false)
	_load_animation_fixed(sprite_frames, "drink_east", "drinking/east", 6, false)
	_load_animation_fixed(sprite_frames, "drink_west", "drinking/west", 6, false)

	# Load combat animations
	_load_animation_fixed(sprite_frames, "punch_south", "cross-punch/south", 5, false)
	_load_animation_fixed(sprite_frames, "punch_north", "cross-punch/north", 5, false)
	_load_animation_fixed(sprite_frames, "punch_east", "cross-punch/east", 5, false)
	_load_animation_fixed(sprite_frames, "punch_west", "cross-punch/west", 5, false)

	# Load special animations
	_load_animation_fixed(sprite_frames, "jump_south", "jumping-1/south", 9, false)
	_load_animation_fixed(sprite_frames, "jump_north", "jumping-1/north", 9, false)
	_load_animation_fixed(sprite_frames, "jump_east", "jumping-1/east", 9, false)
	_load_animation_fixed(sprite_frames, "jump_west", "jumping-1/west", 9, false)
	
	if animated_sprite:
		animated_sprite.sprite_frames = sprite_frames
		# Animation setup complete
	else:
		print("ERROR: Cannot assign sprite_frames - AnimatedSprite2D is null!")

func _load_animation_fixed(sprite_frames: SpriteFrames, anim_name: String, folder_path: String, frame_count: int, loop: bool) -> void:
	# Loading animation: %s" % anim_name
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_loop(anim_name, loop)
	sprite_frames.set_animation_speed(anim_name, 8.0)  # 8 FPS for pixel art
	
	var loaded_frames = 0
	for i in range(frame_count):
		var texture_path = "res://assets/sprites/player/animations/" + folder_path + "/frame_%03d.png" % i
		
		# Try to load the texture with error handling
		var texture = null
		if ResourceLoader.exists(texture_path):
			texture = load(texture_path)
		
		if texture and texture is Texture2D:
			sprite_frames.add_frame(anim_name, texture)
			loaded_frames += 1
		else:
			print("ERROR: Could not load texture or invalid texture type: ", texture_path)
	
	# Animation loaded: %s" % anim_name
	
	if loaded_frames == 0:
		print("CRITICAL: No frames loaded for animation: ", anim_name, " - removing animation")
		sprite_frames.remove_animation(anim_name)

func _load_animation_auto(sprite_frames: SpriteFrames, anim_name: String, folder_path: String, loop: bool) -> void:
	# Auto-detect frame count by checking files
	var frame_count = _count_animation_frames(folder_path)
	if frame_count == 0:
		print("Warning: No frames found for animation: ", folder_path)
		return
	
	# Loading animation: %s" % anim_name
	
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_loop(anim_name, loop)
	sprite_frames.set_animation_speed(anim_name, 8.0)  # 8 FPS for pixel art
	
	var loaded_frames = 0
	for i in range(frame_count):
		var texture_path = "res://assets/sprites/player/animations/" + folder_path + "/frame_%03d.png" % i
		
		# Try multiple loading approaches
		var texture = null
		
		# Method 1: Direct load
		if ResourceLoader.exists(texture_path):
			texture = load(texture_path)
		
		# Method 2: Try load without existence check (might work better with imports)
		if not texture:
			texture = load(texture_path)
		
		if texture:
			sprite_frames.add_frame(anim_name, texture)
			loaded_frames += 1
		else:
			print("Warning: Could not load texture: ", texture_path)
			# Don't break - some animations might have gaps
	
	# Animation loaded: %s" % anim_name
	
	# If no frames loaded, mark this animation as problematic
	if loaded_frames == 0:
		print("ERROR: No frames loaded for animation: ", anim_name)

func _count_animation_frames(folder_path: String) -> int:
	# Count existing frame files using a more reliable method
	var count = 0
	print("Counting frames for: ", folder_path)
	
	for i in range(20):  # Check up to 20 frames
		var texture_path = "res://assets/sprites/player/animations/" + folder_path + "/frame_%03d.png" % i
		
		# Try multiple methods to check if file exists
		var texture = load(texture_path)
		if texture:
			count += 1
			print("  Found frame ", i, ": ", texture_path)
		else:
			print("  Frame ", i, " not found, stopping count at: ", texture_path)
			break
	
	print("Total frames found: ", count)
	
	# Fallback: if no frames found, use known frame counts
	if count == 0:
		print("No frames found with auto-detection, trying fallback...")
		# Use exact frame counts based on actual file counts
		if "breathing-idle" in folder_path:
			count = 8  # breathing-idle has 8 frames (0-7)
		elif "walking" in folder_path:
			count = 6  # walking has 6 frames (0-5)
		elif "running-6-frames" in folder_path:
			count = 6  # running has 6 frames (0-5)
		elif "picking-up" in folder_path:
			count = 5  # pickup has 5 frames (0-4)
		elif "jumping-1" in folder_path:
			count = 9  # jumping has 9 frames (0-8)
		elif "drinking" in folder_path:
			count = 6  # drinking has 6 frames (0-5)
		print("Using fallback count: ", count)
	
	return count

func _physics_process(delta: float) -> void:
	if not action_playing:
		_handle_input()
		_handle_movement(delta)
		_update_animation()
	
	move_and_slide()
	update_stats(delta)

func _input(event: InputEvent) -> void:
	# Handle UI input first
	if event.is_action_pressed("inventory"):
		# Opening original inventory
		# I key - Open original inventory system
		toggle_inventory()
		return
		
	
	# Handle action keys that need _input instead of _handle_input
	if event is InputEventKey and event.pressed and not action_playing:
		match event.physical_keycode:
			KEY_E:
				# E key detected but not consuming in _input
				# Don't consume E key here, let it be handled in _handle_input for interactions
				pass
			KEY_SPACE:
				_play_action_animation("jump")
			KEY_Q:
				_play_action_animation("drink")

func toggle_inventory() -> void:
	# Only toggle if not in build mode or other special states
	if GameManager.current_state == GameManager.GameState.BUILD_MODE:
		return
	
	if GameManager.current_state == GameManager.GameState.INVENTORY:
		GameManager.change_state(GameManager.GameState.IN_GAME)
	else:
		GameManager.change_state(GameManager.GameState.INVENTORY)

func _handle_input() -> void:
	# Get input vector
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	# Normalize diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		is_moving = true
		_update_direction_from_input(input_vector)
	else:
		is_moving = false
	
	# Sprint input (can't sprint while crouching)
	is_sprinting = Input.is_action_pressed("sprint") and is_moving and not is_crouching
	
	# Crouch input
	if Input.is_action_just_pressed("crouch") and not stealth_transition_in_progress:
		toggle_crouch()
	
	# Action inputs for testing (only if not already playing an action)
	if not action_playing:
		if Input.is_action_just_pressed("interact"):  # E key
			# E key - interact with nearest object
			interact_with_nearest()
			_play_action_animation("pickup")

func _handle_movement(delta: float) -> void:
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		var target_speed: float
		
		# Determine base speed based on stance and movement state
		if is_crouching:
			target_speed = crouch_speed  # Crouching speed (50% of normal)
		elif is_sprinting:
			target_speed = sprint_speed  # Can't sprint while crouching
		else:
			target_speed = speed  # Normal walking speed
			
		target_speed *= speed_modifier  # Apply speed modifier from attributes
		target_speed *= get_storm_movement_modifier()  # Apply storm movement penalty
		velocity = velocity.move_toward(input_vector * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

func _update_direction_from_input(input_vector: Vector2) -> void:
	var new_direction: Direction
	
	# Prioritize vertical movement for 4-directional sprites
	if abs(input_vector.y) > abs(input_vector.x):
		if input_vector.y > 0:
			new_direction = Direction.SOUTH
		else:
			new_direction = Direction.NORTH
	else:
		if input_vector.x > 0:
			new_direction = Direction.EAST
		else:
			new_direction = Direction.WEST
	
	if new_direction != current_direction:
		current_direction = new_direction
		direction_changed.emit(current_direction)

func _update_animation() -> void:
	var direction_suffix = _get_direction_suffix()
	
	if is_moving:
		if is_crouching:
			current_state = AnimationState.CROUCH_WALKING
			_play_animation("crouch_walk_" + direction_suffix)
		elif is_sprinting:
			current_state = AnimationState.RUNNING
			_play_animation("run_" + direction_suffix)
		else:
			current_state = AnimationState.WALKING
			_play_animation("walk_" + direction_suffix)
	else:
		if is_crouching:
			current_state = AnimationState.CROUCHED_IDLE
			_play_animation("crouch_idle_" + direction_suffix)
		else:
			current_state = AnimationState.IDLE
			_play_idle_animation()

func _get_direction_suffix() -> String:
	match current_direction:
		Direction.SOUTH:
			return "south"
		Direction.NORTH:
			return "north"
		Direction.EAST:
			return "east"
		Direction.WEST:
			return "west"
		_:
			return "south"

func _play_animation(anim_name: String) -> void:
	if not animated_sprite:
		print("ERROR: No animated_sprite found!")
		return
		
	if not animated_sprite.sprite_frames:
		print("ERROR: No sprite_frames found in animated_sprite!")
		return
		
	if animated_sprite.animation != anim_name:
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)
		else:
			print("Warning: Animation not found, falling back to idle: ", anim_name)
			# Fallback to a basic idle if available
			if animated_sprite.sprite_frames.has_animation("idle_south"):
				animated_sprite.play("idle_south")

func _play_idle_animation() -> void:
	var direction_suffix = _get_direction_suffix()
	_play_animation("idle_" + direction_suffix)

func _play_action_animation(action: String) -> void:
	if action_playing:
		print("Action already playing, queuing: ", action)
		action_queue.push_back(action)
		return
	
	action_playing = true
	var direction_suffix = _get_direction_suffix()
	var anim_name = action + "_" + direction_suffix
	
	if not animated_sprite:
		print("ERROR: No animated_sprite found!")
		action_playing = false
		return
		
	if not animated_sprite.sprite_frames:
		print("ERROR: No sprite_frames found!")
		action_playing = false
		return
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		# Disconnect any existing connection to prevent multiple connections
		if animated_sprite.animation_finished.is_connected(_on_action_animation_finished):
			animated_sprite.animation_finished.disconnect(_on_action_animation_finished)
		
		# Get animation details
		var frame_count = animated_sprite.sprite_frames.get_frame_count(anim_name)
		
		# Set normal animation speed
		animated_sprite.sprite_frames.set_animation_speed(anim_name, 8.0)  # Normal speed
		animated_sprite.play(anim_name)
		
		animated_sprite.animation_finished.connect(_on_action_animation_finished, CONNECT_ONE_SHOT)
		
		# Backup timer in case signal fails
		var timeout = frame_count / 8.0 + 0.5  # Normal speed timeout
		get_tree().create_timer(timeout).timeout.connect(_on_action_timeout, CONNECT_ONE_SHOT)
		
	else:
		print("Warning: Animation not found: ", anim_name)
		print("Looking for alternatives...")
		
		# Try to find any similar animation
		var all_anims = animated_sprite.sprite_frames.get_animation_names()
		for anim in all_anims:
			if action in anim:
				print("Found similar animation: ", anim)
		
		action_playing = false

func _on_action_animation_finished() -> void:
	_reset_action_state()

func _on_action_timeout() -> void:
	_reset_action_state()

func _reset_action_state() -> void:
	if not action_playing:
		return
		
	action_playing = false
	
	# Safely emit signal
	if animated_sprite and animated_sprite.animation:
		animation_finished.emit(animated_sprite.animation)
	
	# Process queued actions
	if action_queue.size() > 0:
		var next_action = action_queue.pop_front()
		_play_action_animation(next_action)
	else:
		# Return to movement-based animation
		_update_animation()

# Public API for triggering animations
func play_pickup_animation() -> void:
	_play_action_animation("pickup")

func play_drink_animation() -> void:
	_play_action_animation("drink")

func play_jump_animation() -> void:
	_play_action_animation("jump")

func play_punch_animation() -> void:
	_play_action_animation("punch")

func play_hurt_animation() -> void:
	# Play the taking-punch animation when receiving damage
	# Try with hyphen first since that's how it's named in metadata
	if not action_playing:
		action_playing = true
		var direction_suffix = _get_direction_suffix()
		var anim_name = "taking-punch_" + direction_suffix

		if animated_sprite and animated_sprite.sprite_frames:
			if animated_sprite.sprite_frames.has_animation(anim_name):
				animated_sprite.play(anim_name)
				# Connect to animation finished signal
				if not animated_sprite.animation_finished.is_connected(_on_action_animation_finished):
					animated_sprite.animation_finished.connect(_on_action_animation_finished)
			else:
				# Try underscore version as fallback
				anim_name = "taking_punch_" + direction_suffix
				if animated_sprite.sprite_frames.has_animation(anim_name):
					animated_sprite.play(anim_name)
					if not animated_sprite.animation_finished.is_connected(_on_action_animation_finished):
						animated_sprite.animation_finished.connect(_on_action_animation_finished)
				else:
					print("Hurt animation not found: ", anim_name)
					# Debug: List all available animations
					var all_anims = animated_sprite.sprite_frames.get_animation_names()
					print("Available animations containing 'taking' or 'punch':")
					for anim in all_anims:
						if "taking" in anim.to_lower() or "hurt" in anim.to_lower():
							print("  - ", anim)
					action_playing = false

func _setup_taking_punch_animations() -> void:
	if not animated_sprite or not animated_sprite.sprite_frames:
		print("Cannot setup taking-punch animations - sprite not ready")
		return

	var sprite_frames = animated_sprite.sprite_frames
	var base_path = "res://assets/sprites/player/animations/taking-punch/"

	# Define the animations for each direction
	var directions = ["north", "south", "east", "west"]

	for direction in directions:
		var anim_name = "taking_punch_" + direction

		# Check if animation already exists
		if sprite_frames.has_animation(anim_name):
			continue

		# Add the animation
		sprite_frames.add_animation(anim_name)

		# Set animation properties
		sprite_frames.set_animation_speed(anim_name, 10.0)
		sprite_frames.set_animation_loop(anim_name, false)

		# Add frames
		for i in range(6):  # 6 frames per direction
			var frame_path = base_path + direction + "/frame_" + "%03d" % i + ".png"

			if ResourceLoader.exists(frame_path):
				var texture = load(frame_path)
				sprite_frames.add_frame(anim_name, texture)

		print("Added taking_punch animation for ", direction)

func get_facing_direction() -> Vector2:
	match current_direction:
		Direction.SOUTH:
			return Vector2.DOWN
		Direction.NORTH:
			return Vector2.UP
		Direction.EAST:
			return Vector2.RIGHT
		Direction.WEST:
			return Vector2.LEFT
		_:
			return Vector2.DOWN

func get_direction_name() -> String:
	return _get_direction_suffix()

# Utility functions for other systems
func is_facing_position(target_pos: Vector2) -> bool:
	var direction_to_target = (target_pos - global_position).normalized()
	var facing_direction = get_facing_direction()
	return direction_to_target.dot(facing_direction) > 0.5

func face_position(target_pos: Vector2) -> void:
	var direction_to_target = target_pos - global_position
	
	if abs(direction_to_target.y) > abs(direction_to_target.x):
		current_direction = Direction.SOUTH if direction_to_target.y > 0 else Direction.NORTH
	else:
		current_direction = Direction.EAST if direction_to_target.x > 0 else Direction.WEST
	
	if not is_moving:
		_play_idle_animation()

# === STAT MANAGEMENT SYSTEM ===

func update_stats(delta: float) -> void:
	# Energy management with sprinting
	if is_sprinting and velocity.length() > 0:
		modify_energy(-10.0 * delta)  # Sprint energy cost
	else:
		modify_energy(2.0 * delta)  # Passive energy recovery
	
	# Degrade hunger and thirst over time (balanced rates - no death risk)
	modify_hunger(-0.3 * delta)   # Takes ~5.5 minutes to empty
	modify_thirst(-0.4 * delta)   # Takes ~4 minutes to empty (thirst faster)
	
	# TODO: Apply debuffs when starving or dehydrated (instead of death)
	# For now, just let the bars reach 0 without consequences
	if hunger <= 0:
		print("DEBUG: Player hungry - ready for debuff system")
	if thirst <= 0:
		print("DEBUG: Player thirsty - ready for debuff system")
	
	# Radiation exposure processing
	process_radiation_exposure(delta)
	
	# Apply radiation effects on stamina/energy
	apply_radiation_effects()

func modify_health(amount: float) -> void:
	health = clamp(health + amount, 0, max_health)
	health_changed.emit(int(health))  # Convert to int for HUD compatibility
	EventBus.emit_player_stat_changed("health", health)
	
	if health <= 0:
		die()

func modify_energy(amount: float) -> void:
	energy = clamp(energy + amount, 0, max_energy)
	energy_changed.emit(int(energy))  # Convert to int for HUD compatibility
	EventBus.emit_player_stat_changed("energy", energy)

func modify_hunger(amount: float) -> void:
	hunger = clamp(hunger + amount, 0, max_hunger)
	hunger_changed.emit(int(hunger))  # Convert to int for HUD compatibility
	EventBus.emit_player_stat_changed("hunger", hunger)

func modify_thirst(amount: float) -> void:
	thirst = clamp(thirst + amount, 0, max_thirst)
	thirst_changed.emit(int(thirst))  # Convert to int for HUD compatibility
	EventBus.emit_player_stat_changed("thirst", thirst)

func die() -> void:
	print("Player died!")
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	queue_free()

func consume_item(item_id: String) -> bool:
	# Check if we have the item in our inventory
	if not inventory.has_item(item_id, 1):
		return false
	
	# Consume the item based on its type
	var consumed = false
	match item_id:
		"FOOD":
			if inventory.remove_item(item_id, 1):
				modify_hunger(25.0)  # Food restores 25 hunger
				print("Consumed food, hunger restored!")
				consumed = true
		"WATER":
			if inventory.remove_item(item_id, 1):
				modify_thirst(30.0)  # Water restores 30 thirst
				print("Consumed water, thirst quenched!")
				consumed = true
		"RAD_AWAY", "RAD_X", "IODINE_TABLETS":
			# Handle radiation treatment items
			consumed = consume_radiation_treatment(item_id)
		_:
			# Try healing items if not found in basic consumables
			if consume_healing_item(item_id):
				consumed = true
			else:
				print("Item %s is not consumable" % item_id)
	
	return consumed

func collect_resource(resource_type: String, amount: int) -> bool:
	# Add resources directly to InventorySystem instead of ResourceManager
	if InventorySystem.add_item(resource_type, amount):
		# Grant Scavenging XP for resource collection
		if has_node("/root/SkillSystem"):
			var skill_system = get_node("/root/SkillSystem")
			var xp_amount = 5  # Base XP for resource collection
			skill_system.add_xp("SCAVENGING", xp_amount, "resource_collected")
		
		return true
	else:
		print("FAILED to collect %d %s - inventory full?" % [amount, resource_type])
	return false

# Get equipped item from specific slot
func get_equipped_item(slot: String) -> Equipment:
	if not EquipmentManager:
		return null
	return EquipmentManager.get_equipped_item(slot)

# Screen shake effect for mining impacts
func add_screen_shake(intensity: float):
	# Basic screen shake implementation
	# This would normally shake the camera, but for now just print feedback
	print("Screen shake: %f intensity" % intensity)
	# TODO: Implement actual camera shake when camera system is ready

# Show message to player (for tool requirements, etc.)
func show_message(text: String):
	print("Player Message: %s" % text)
	# TODO: Implement actual UI message system

# Give player initial tools for mining
# Initial tools function removed - now handled by GameManager.add_initial_mining_tools()

func _on_damage_received(damage: int) -> void:
	modify_health(-damage)

func _on_heal_received(amount: int) -> void:
	heal_player(amount, "external")

# === ENHANCED DAMAGE & HEALING SYSTEM ===

# Enhanced damage system with status effects
func take_damage(damage: float, damage_type: String = "physical", source = null) -> float:
	# Handle different source types
	var source_name = ""
	if source is String:
		source_name = source
	elif source is Node and source != null:
		source_name = source.name
	else:
		source_name = "unknown"

	# Calculate damage reduction based on attribute system
	var reduced_damage = damage
	if AttributeManager:
		reduced_damage = AttributeManager.calculate_damage_reduction(damage, damage_type)
	else:
		# Fallback damage reduction using basic armor (if you have armor variable)
		if damage_type == "physical":
			reduced_damage = max(damage - 0.0, 1.0)  # No armor fallback

	# Apply the damage
	modify_health(-int(reduced_damage))

	# Visual feedback for taking damage
	show_damage_taken_feedback()

	# Apply durability loss to equipped armor/equipment
	apply_equipment_durability_loss(int(reduced_damage))

	# Apply status effects based on damage type with chance
	if StatusEffectSystem:
		match damage_type.to_lower():
			"fire":
				# Fire damage has chance to cause burning DoT
				if randf() < 0.4:  # 40% chance
					print("Burning!")
					StatusEffectSystem.apply_fire_burn(5.0, 3.0)
			"cold":
				# Cold damage has chance to slow movement
				if randf() < 0.3:  # 30% chance
					print("Freezing!")
					StatusEffectSystem.apply_cold_slow(4.0, 0.6)  # 40% speed reduction
			"shock":
				# Shock damage has chance to stun briefly
				if randf() < 0.15:  # 15% chance
					print("Stunned!")
					StatusEffectSystem.apply_shock_stun(1.5)
			"radiation":
				# Radiation damage increases radiation level and can cause poisoning
				# modify_radiation(damage * 0.1)  # 10% of damage becomes radiation
				if randf() < 0.25:  # 25% chance for radiation poisoning
					print("Radiation poisoning!")
					StatusEffectSystem.apply_radiation_poisoning(8.0, 1.5)
			"environmental":
				# Environmental damage (storms, toxic areas)
				if randf() < 0.2:  # 20% chance for various effects
					var effect_roll = randf()
					if effect_roll < 0.33:
						StatusEffectSystem.apply_radiation_poisoning(6.0, 1.0)
					elif effect_roll < 0.66:
						StatusEffectSystem.apply_cold_slow(3.0, 0.8)
					else:
						print("Equipment malfunction!")

	# Grant Environmental Adaptation XP for taking damage
	if has_node("/root/SkillSystem") and reduced_damage > 0:
		var skill_system = get_node("/root/SkillSystem")
		var xp_amount = int(reduced_damage / 5.0) * skill_system.XP_VALUES.ENVIRONMENTAL_DAMAGE_TAKEN
		skill_system.add_xp("ENVIRONMENTAL_ADAPTATION", max(xp_amount, 1), source_name)

	print("Player took %d damage from %s" % [int(reduced_damage), source_name])
	return reduced_damage

func show_damage_taken_feedback() -> void:
	# Play hurt animation (recoil/flinch effect)
	play_hurt_animation()

	# Red flash effect when taking damage
	modulate = Color(2, 0.5, 0.5)

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

	# Screen shake effect (if camera available)
	if has_method("add_screen_shake"):
		add_screen_shake(5.0)

# Enhanced healing system
func heal_player(amount: int, source: String = "unknown") -> int:
	if amount <= 0:
		return 0
	
	var actual_healing = min(amount, max_health - int(health))
	if actual_healing <= 0:
		return 0  # Already at full health
	
	modify_health(actual_healing)
	
	# Grant Life Support XP for healing
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var xp_amount = max(1, int(actual_healing / 10.0) * skill_system.XP_VALUES.HEALTH_RESTORED)
		skill_system.add_xp("LIFE_SUPPORT", xp_amount, source + "_healing")
	
	print("Healed %d HP from %s" % [actual_healing, source])
	return actual_healing

# Environmental damage application
func apply_environmental_damage(damage: float, environment_type: String = "storm"):
	var damage_source = "environmental_%s" % environment_type
	take_damage(damage, "environmental", damage_source)

func apply_storm_damage(storm_intensity: float):
	var base_damage = storm_intensity * 5.0  # 5 damage per intensity level
	# Storm resistance reduces damage
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		var storm_resistance = attr_mgr.get_attribute("storm_resistance")
		base_damage *= (1.0 - storm_resistance)
	
	apply_environmental_damage(base_damage, "storm")

func apply_radiation_area_damage(radiation_level: float):
	var damage = radiation_level * 2.0  # 2 damage per radiation level
	take_damage(damage, "radiation", "radiation_area")

# Enhanced consumable system with more healing items
func consume_healing_item(item_id: String) -> bool:
	if not inventory.has_item(item_id, 1):
		return false
	
	var consumed = false
	var healing_amount = 0
	var source = "consumable"
	
	match item_id:
		"MEDKIT":
			if inventory.remove_item(item_id, 1):
				healing_amount = 50
				source = "medkit"
				consumed = true
		"BANDAGE":
			if inventory.remove_item(item_id, 1):
				healing_amount = 20
				source = "bandage"
				consumed = true
		"STIMPACK":
			if inventory.remove_item(item_id, 1):
				healing_amount = 30
				# Also provides temporary healing over time
				if StatusEffectSystem:
					StatusEffectSystem.apply_healing_over_time(10.0, 2.0, "stimpack")
				source = "stimpack"
				consumed = true
		"ENERGY_DRINK":
			if inventory.remove_item(item_id, 1):
				modify_energy(40.0)
				# Temporary speed boost
				if StatusEffectSystem:
					StatusEffectSystem.apply_status_effect("energy_boost", 
													   StatusEffectSystem.StatusType.MOVEMENT_MODIFIER, 
													   30.0, 1.3, "energy_drink")
				print("Energy restored with temporary speed boost!")
				return true
	
	if consumed and healing_amount > 0:
		heal_player(healing_amount, source)
	
	return consumed

# Durability loss system for equipment
func apply_equipment_durability_loss(damage_taken: int):
	if not EquipmentManager:
		return
	
	# Calculate durability loss based on damage taken
	var durability_loss = max(1, int(damage_taken / 10.0))  # 1 durability per 10 damage
	
	# Apply durability loss to armor pieces (equipment that provides protection)
	var armor_slots = ["HEAD", "CHEST", "PANTS", "FEET"]
	for slot in armor_slots:
		var equipment = EquipmentManager.get_equipped_item(slot)
		if equipment and equipment.has_method("reduce_durability"):
			equipment.reduce_durability(durability_loss)
			
			# Check if equipment broke
			if equipment.is_broken():
				print("WARNING: %s is broken and no longer provides protection!" % equipment.name)
				# Update equipment stats to reflect broken state
				EquipmentManager.update_total_stats()

func apply_weapon_durability_loss(weapon_slot: String):
	if not WeaponManager:
		return
	
	var weapon = WeaponManager.get_equipped_weapon(weapon_slot)
	if weapon and weapon.has_method("use_weapon"):
		# Weapon durability loss is handled in weapon.use_weapon()
		if weapon.is_broken():
			print("WARNING: %s is broken and cannot be used!" % weapon.name)

# Debug stats removed for cleaner console output

# === RADIATION EXPOSURE SYSTEM ===

func process_radiation_exposure(delta: float) -> void:
	if not in_radiation_zone or current_radiation_intensity <= 0:
		return
	
	# Update radiation timer
	radiation_timer += delta
	
	# Calculate radiation interval based on intensity
	var radiation_interval: float
	if current_radiation_intensity <= 0.3:  # Low radiation (10-30%)
		radiation_interval = 300.0  # 5 minutes
	elif current_radiation_intensity <= 0.6:  # Medium radiation (40-60%)
		radiation_interval = 120.0  # 2 minutes
	elif current_radiation_intensity <= 0.9:  # High radiation (70-90%)
		radiation_interval = 30.0   # 30 seconds
	else:  # Extreme radiation (95%+)
		radiation_interval = 10.0   # 10 seconds
	
	# Apply radiation damage when timer reaches interval
	if radiation_timer >= radiation_interval:
		var storm_multiplier = get_storm_radiation_multiplier()
		add_radiation_damage(1.0 * storm_multiplier)
		radiation_timer = 0.0
		
		# Grant Environmental Adaptation XP
		if has_node("/root/SkillSystem"):
			var skill_system = get_node("/root/SkillSystem")
			var xp_amount = int(current_radiation_intensity * 10) # More XP for higher radiation
			skill_system.add_xp("ENVIRONMENTAL_ADAPTATION", max(xp_amount, 1), "radiation_exposure")

func add_radiation_damage(amount: float) -> void:
	if amount <= 0:
		return
	
	var old_radiation = current_radiation_damage
	current_radiation_damage = min(current_radiation_damage + amount, max_radiation_damage)
	
	if current_radiation_damage != old_radiation:
		radiation_changed.emit(current_radiation_damage, max_radiation_damage)
		EventBus.emit_player_stat_changed("radiation", current_radiation_damage)
		print("Radiation exposure increased: %.1f/%.1f (+ %.1f)" % [current_radiation_damage, max_radiation_damage, amount])

func remove_radiation_damage(amount: float) -> void:
	if amount <= 0:
		return
	
	var old_radiation = current_radiation_damage
	current_radiation_damage = max(current_radiation_damage - amount, 0.0)
	
	if current_radiation_damage != old_radiation:
		radiation_changed.emit(current_radiation_damage, max_radiation_damage)
		EventBus.emit_player_stat_changed("radiation", current_radiation_damage)
		print("Radiation treated: %.1f/%.1f (- %.1f)" % [current_radiation_damage, max_radiation_damage, amount])
		apply_radiation_effects()

func apply_radiation_effects() -> void:
	var radiation_percentage = current_radiation_damage / max_radiation_damage
	
	# Apply stamina reduction based on radiation level using base max energy
	if radiation_percentage <= 0.25:  # 0-25%
		# No effect on max stamina
		max_energy = base_max_energy
	elif radiation_percentage <= 0.5:  # 26-50%
		max_energy = int(base_max_energy * 0.9)  # 10% reduction
	elif radiation_percentage <= 0.75:  # 51-75%
		max_energy = int(base_max_energy * 0.75)  # 25% reduction
	else:  # 76-100%
		max_energy = int(base_max_energy * 0.5)   # 50% reduction
	
	# Clamp current energy to new max
	if energy > max_energy:
		energy = max_energy
		energy_changed.emit(int(energy))

func set_radiation_zone(intensity: float) -> void:
	in_radiation_zone = intensity > 0
	current_radiation_intensity = intensity
	radiation_timer = 0.0  # Reset timer when entering new zone
	
	if in_radiation_zone:
		print("Entered radiation zone - Intensity: %.1f%%" % (intensity * 100))
	else:
		print("Left radiation zone")

func get_radiation_percentage() -> float:
	return current_radiation_damage / max_radiation_damage if max_radiation_damage > 0 else 0.0

func get_radiation_level_text() -> String:
	var percentage = get_radiation_percentage()
	if percentage <= 0.25:
		return "Safe"
	elif percentage <= 0.5:
		return "Mild"
	elif percentage <= 0.75:
		return "Moderate" 
	else:
		return "Severe"

func consume_radiation_treatment(item_id: String) -> bool:
	if not inventory.has_item(item_id, 1):
		return false
	
	var consumed = false
	var reduction_amount = 0.0
	
	match item_id:
		"RAD_AWAY":
			if inventory.remove_item(item_id, 1):
				reduction_amount = 25.0
				consumed = true
		"RAD_X":
			if inventory.remove_item(item_id, 1):
				reduction_amount = 15.0
				consumed = true
		"IODINE_TABLETS":
			if inventory.remove_item(item_id, 1):
				reduction_amount = 10.0
				consumed = true
	
	if consumed and reduction_amount > 0:
		remove_radiation_damage(reduction_amount)
		
		# Grant Life Support XP for radiation treatment
		if has_node("/root/SkillSystem"):
			var skill_system = get_node("/root/SkillSystem")
			var xp_amount = int(reduction_amount / 5.0) * skill_system.XP_VALUES.HEALTH_RESTORED
			skill_system.add_xp("LIFE_SUPPORT", max(xp_amount, 3), "radiation_treatment")
	
	return consumed

func get_storm_movement_modifier() -> float:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system and storm_system.is_storm_active():
		return storm_system.get_movement_modifier()
	return 1.0

func get_storm_radiation_multiplier() -> float:
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system and storm_system.is_storm_active():
		return storm_system.get_radiation_multiplier()
	return 1.0

# === STEALTH SYSTEM FUNCTIONS ===

func toggle_crouch() -> void:
	if stealth_transition_in_progress:
		return
	
	stealth_transition_in_progress = true
	is_crouching = !is_crouching
	
	if is_crouching:
		current_stealth_state = StealthState.CROUCHING
		print("Player crouched - stealth increased")
	else:
		current_stealth_state = StealthState.STANDING
		print("Player standing - stealth normal")
	
	# Force animation update
	_update_animation()
	
	# End transition (immediate for now, could add smooth transition later)
	stealth_transition_in_progress = false

func get_current_stealth_value() -> float:
	var effective_stealth = base_stealth * stealth_modifier
	
	# Add crouch bonus
	if is_crouching:
		effective_stealth += crouch_stealth_bonus
	
	# Clamp to 0-100 range
	return clamp(effective_stealth, 0.0, 100.0)

func get_detection_difficulty() -> float:
	# Higher stealth = higher detection difficulty for enemies
	# This returns a multiplier that enemies will use in their detection calculations
	var stealth = get_current_stealth_value()
	# Convert 0-100 stealth to 0.1-2.0 difficulty multiplier
	# 0 stealth = 0.1x difficulty (very easy to detect)
	# 50 stealth = 1.0x difficulty (normal detection)
	# 100 stealth = 2.0x difficulty (very hard to detect)
	return 0.1 + (stealth / 100.0) * 1.9

func modify_stealth(modifier: float) -> void:
	stealth_modifier = modifier
	print("Stealth modifier updated: %.1fx (Effective stealth: %.1f)" % [stealth_modifier, get_current_stealth_value()])

func add_stealth_bonus(amount: float) -> void:
	# Temporary stealth bonus (like from equipment)
	base_stealth += amount
	base_stealth = clamp(base_stealth, 0.0, 100.0)
	print("Stealth bonus added: +%.1f (Total: %.1f)" % [amount, get_current_stealth_value()])

# Interaction methods (missing from AnimatedPlayerController)
func interact_with_nearest() -> void:
	if nearby_interactables.is_empty():
		return
	
	var nearest = nearby_interactables[0]
	var min_dist = position.distance_to(nearest.global_position)
	
	for interactable in nearby_interactables:
		var dist = position.distance_to(interactable.global_position)
		if dist < min_dist:
			nearest = interactable
			min_dist = dist
	
	if nearest.has_method("interact"):
		nearest.interact(self)
	else:
		print("Nearest interactable does not have interact method")

func _on_body_entered_interaction(body: Node2D) -> void:
	if body.has_method("interact"):
		nearby_interactables.append(body)

func _on_body_exited_interaction(body: Node2D) -> void:
	nearby_interactables.erase(body)

func is_in_stealth_mode() -> bool:
	return is_crouching

func get_stealth_state() -> StealthState:
	return current_stealth_state

func get_stealth_info() -> Dictionary:
	return {
		"is_crouching": is_crouching,
		"stealth_state": current_stealth_state,
		"base_stealth": base_stealth,
		"stealth_modifier": stealth_modifier,
		"crouch_bonus": crouch_stealth_bonus if is_crouching else 0.0,
		"effective_stealth": get_current_stealth_value(),
		"detection_difficulty": get_detection_difficulty()
	}

func get_damage_modifier() -> float:
	return damage_modifier
