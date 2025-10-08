extends Node3D
class_name Turret3D

## A 3D gun turret that automatically targets and fires at players within range.
## Uses smooth rotation interpolation for realistic aiming behavior.

## ENUMS
enum State {
	IDLE,      # No target, sweeping back and forth
	SEARCHING, # Target detected but not yet aimed
	AIMING,    # Aiming at target with line of sight
	FIRING     # Actively firing at target
}

## CONSTANTS
const NEUTRAL_ROTATION_SPEED: float = 0.5
const AIM_TOLERANCE: float = 0.98  # ~11 degrees (dot product threshold)
const MIN_FIRE_RATE: float = 0.1
const IDLE_SWEEP_SPEED: float = 0.3
const IDLE_SWEEP_ANGLE: float = 45.0  # Degrees to sweep left/right

## EXPORT VARIABLES (Editable in the Inspector)
@export_group("Rotation")
@export_range(0.1, 10.0, 0.1) var rotation_speed: float = 1.0

@export_group("Combat")
@export_range(0.1, 20.0, 0.1) var fire_rate: float = 2.0  # Shots per second
@export var projectile_scene: PackedScene

@export_group("Pitch Limits")
@export_range(-90.0, 90.0, 1.0) var max_pitch_angle: float = 30.0  # How far up it can aim
@export_range(-90.0, 90.0, 1.0) var min_pitch_angle: float = -15.0  # How far down it can aim

@export_group("Targeting")
@export var target_group: String = "animals"  # Which group to target (animals, player, enemies, etc.)
@export var line_of_sight_required: bool = true  # Require clear line of sight to fire

@export_group("Line of Sight")
@export_flags_3d_physics var los_collision_mask: int = 1  # Physics layers to check for obstacles
@export var target_height_offset: float = 1.0  # Offset to aim at target's center (not feet)

@export_group("Ammo System")
@export var ammo_capacity: int = 100  # Maximum ammo storage
@export var ammo_per_shot: int = 1  # Ammo consumed per shot
@export var ammo_consumption_interval: float = 3.0  # Seconds between ammo consumption
@export var accepted_ammo_type: String = "SCRAP_BULLETS"  # Which ammo type this turret uses

@export_group("Audio")
@export var shoot_sound: AudioStream = preload("res://assets/sound/effects/Pow.wav")
@export var shoot_sound_volume: float = 0.0  # Volume in dB (0.0 is default)

## NODE REFERENCES (Use % for unique names for robustness)
@onready var turret_pivot: Node3D = %TurretPivot
@onready var gun_pivot: Node3D = %GunPivot
@onready var muzzle: Marker3D = %Muzzle
@onready var detection_area: Area3D = %DetectionArea
@onready var fire_rate_timer: Timer = %FireRateTimer

## PRIVATE VARIABLES
var _target: Node3D = null
var _can_fire: bool = true
var _current_state: State = State.IDLE
var _sweep_direction: int = 1  # 1 for right, -1 for left
var _sweep_angle: float = 0.0

# Inventory system - simple ammo storage
var _ammo_storage: Dictionary = {}  # {"ammo_id": quantity}
var _ammo_consumption_timer: float = 0.0
var _interaction_area: Area3D = null
var _interaction_prompt: Label3D = null
var _player_in_range: bool = false

# TurretUI compatibility - keeping for backward compatibility but not needed
var storage_inventory: Dictionary = {}
var max_slots: int = 1

# Audio
var _audio_player: AudioStreamPlayer3D = null


func _ready() -> void:
	_validate_setup()
	_configure_fire_rate()
	_connect_signals()
	_setup_inventory()
	_setup_interaction_area()
	_setup_audio()


func _physics_process(delta: float) -> void:
	if not _is_ready_to_operate():
		return

	_update_state()
	_process_current_state(delta)
	_update_ammo_consumption(delta)


## Updates the state machine based on current conditions
func _update_state() -> void:
	match _current_state:
		State.IDLE:
			if _has_valid_target():
				_change_state(State.SEARCHING)

		State.SEARCHING:
			if not _has_valid_target():
				_change_state(State.IDLE)
			elif _is_aimed_at_target(_get_direction_to_target()):
				if _has_line_of_sight():
					_change_state(State.AIMING)

		State.AIMING:
			if not _has_valid_target():
				_change_state(State.IDLE)
			elif not _has_line_of_sight():
				_change_state(State.SEARCHING)
			elif not _has_ammo():
				_change_state(State.SEARCHING)  # Can't fire without ammo
			elif _can_fire:
				_change_state(State.FIRING)

		State.FIRING:
			if not _has_valid_target():
				_change_state(State.IDLE)
			elif not _has_line_of_sight():
				_change_state(State.SEARCHING)
			elif not _has_ammo():
				_change_state(State.SEARCHING)  # Out of ammo
			elif not _is_aimed_at_target(_get_direction_to_target()):
				_change_state(State.SEARCHING)


## Processes behavior based on the current state
func _process_current_state(delta: float) -> void:
	match _current_state:
		State.IDLE:
			_process_idle_state(delta)

		State.SEARCHING:
			_process_searching_state(delta)

		State.AIMING:
			_process_aiming_state(delta)

		State.FIRING:
			_process_firing_state(delta)


## Changes the state and performs any necessary transitions
func _change_state(new_state: State) -> void:
	if _current_state == new_state:
		return

	# Exit current state
	_exit_state(_current_state)

	# Change state
	var old_state := _current_state
	_current_state = new_state

	# Enter new state
	_enter_state(new_state)


## Called when entering a new state
func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			_sweep_angle = 0.0
			_sweep_direction = 1

		State.FIRING:
			# Start playing shooting sound on loop
			if _audio_player and shoot_sound:
				_audio_player.play()
				print("Turret: Started shooting sound")


## Called when exiting a state
func _exit_state(state: State) -> void:
	match state:
		State.FIRING:
			# Stop shooting sound when no longer firing
			if _audio_player:
				_audio_player.stop()
				print("Turret: Stopped shooting sound")


## IDLE state: Slowly sweep back and forth
func _process_idle_state(delta: float) -> void:
	# Sweep horizontally
	_sweep_angle += IDLE_SWEEP_SPEED * _sweep_direction * delta * 60.0

	# Reverse direction at sweep limits
	if abs(_sweep_angle) >= IDLE_SWEEP_ANGLE:
		_sweep_direction *= -1
		_sweep_angle = clampf(_sweep_angle, -IDLE_SWEEP_ANGLE, IDLE_SWEEP_ANGLE)

	# Apply sweep rotation
	turret_pivot.rotation.y = lerp_angle(
		turret_pivot.rotation.y,
		deg_to_rad(_sweep_angle),
		delta * IDLE_SWEEP_SPEED
	)

	# Return gun to neutral pitch
	gun_pivot.rotation.x = lerp_angle(
		gun_pivot.rotation.x,
		0.0,
		delta * NEUTRAL_ROTATION_SPEED
	)


## SEARCHING state: Track target but don't fire yet
func _process_searching_state(delta: float) -> void:
	var target_pos := _get_target_position()
	var pivot_pos := turret_pivot.global_position
	var direction_to_target := (target_pos - pivot_pos).normalized()

	_rotate_horizontal(direction_to_target, delta)
	_rotate_vertical(target_pos, delta)


## AIMING state: Locked onto target with clear LOS
func _process_aiming_state(delta: float) -> void:
	var target_pos := _get_target_position()
	var pivot_pos := turret_pivot.global_position
	var direction_to_target := (target_pos - pivot_pos).normalized()

	_rotate_horizontal(direction_to_target, delta)
	_rotate_vertical(target_pos, delta)


## FIRING state: Actively shooting at target
func _process_firing_state(delta: float) -> void:
	var target_pos := _get_target_position()
	var pivot_pos := turret_pivot.global_position
	var direction_to_target := (target_pos - pivot_pos).normalized()

	_rotate_horizontal(direction_to_target, delta)
	_rotate_vertical(target_pos, delta)

	# Fire the weapon
	_fire()


## Validates that all required nodes and resources are present
func _validate_setup() -> void:
	var missing_nodes: Array[String] = []

	if not turret_pivot:
		missing_nodes.append("TurretPivot")
	if not gun_pivot:
		missing_nodes.append("GunPivot")
	if not muzzle:
		missing_nodes.append("Muzzle")
	if not detection_area:
		missing_nodes.append("DetectionArea")
	if not fire_rate_timer:
		missing_nodes.append("FireRateTimer")

	if not missing_nodes.is_empty():
		push_error("Turret: Missing required child nodes: %s" % ", ".join(missing_nodes))
		set_physics_process(false)

	if not projectile_scene:
		push_warning("Turret: No projectile scene assigned. Turret will not be able to fire.")


## Configures the fire rate timer based on the fire_rate export variable
func _configure_fire_rate() -> void:
	if not fire_rate_timer:
		return

	var clamped_fire_rate := maxf(fire_rate, MIN_FIRE_RATE)
	fire_rate_timer.wait_time = 1.0 / clamped_fire_rate
	fire_rate_timer.one_shot = true


## Connects signals from child nodes
func _connect_signals() -> void:
	if detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)

	if fire_rate_timer:
		fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)


## Sets up the turret's inventory system
func _setup_inventory() -> void:
	# Initialize storage_inventory for StorageUI compatibility
	storage_inventory["0"] = {
		"item_id": "",
		"quantity": 0
	}
	print("Turret: Inventory system initialized with %d slots" % max_slots)


## Sets up the audio player for shooting sounds
func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "ShootAudioPlayer"
	_audio_player.stream = shoot_sound
	_audio_player.volume_db = shoot_sound_volume
	_audio_player.max_distance = 50.0  # Can be heard from 50 meters
	_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(_audio_player)
	print("Turret: Audio system initialized")


## Sets up the interaction area for player access
func _setup_interaction_area() -> void:
	# Add to interactable group so player can find us
	add_to_group("interactable")

	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	add_child(_interaction_area)

	# Create a collision shape for the interaction area
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 2.0  # Player can interact within 2 meters
	collision_shape.shape = sphere_shape
	_interaction_area.add_child(collision_shape)

	# Configure area to detect player (same as storage box)
	_interaction_area.collision_layer = 1 << 7  # Interactables layer (layer 8)
	_interaction_area.collision_mask = 1 << 1   # Player layer (layer 2)
	_interaction_area.monitoring = true
	_interaction_area.monitorable = true

	# Connect signals
	_interaction_area.body_entered.connect(_on_interaction_area_entered)
	_interaction_area.body_exited.connect(_on_interaction_area_exited)

	# Create interaction prompt
	call_deferred("_create_interaction_prompt")


## Checks if the turret has all required nodes and is ready to operate
func _is_ready_to_operate() -> bool:
	return turret_pivot != null and gun_pivot != null and muzzle != null


## Checks if the current target is still valid
func _has_valid_target() -> bool:
	return is_instance_valid(_target)


## Checks if the turret has ammo
func _has_ammo() -> bool:
	return _get_ammo_count() > 0


## Gets the current ammo count
func _get_ammo_count() -> int:
	return _ammo_storage.get(accepted_ammo_type, 0)


## Updates ammo consumption timer while firing
func _update_ammo_consumption(delta: float) -> void:
	if _current_state != State.FIRING:
		_ammo_consumption_timer = 0.0
		return

	_ammo_consumption_timer += delta

	# Consume ammo every 3 seconds (or configured interval)
	if _ammo_consumption_timer >= ammo_consumption_interval:
		_consume_ammo()
		_ammo_consumption_timer = 0.0


## Consumes ammo from the turret's inventory
func _consume_ammo() -> bool:
	var current_ammo = _ammo_storage.get(accepted_ammo_type, 0)

	if current_ammo >= ammo_per_shot:
		_ammo_storage[accepted_ammo_type] = current_ammo - ammo_per_shot
		print("Turret consumed %d ammo. Remaining: %d" % [ammo_per_shot, _ammo_storage[accepted_ammo_type]])
		return true

	return false


## Gets the direction vector to the target
func _get_direction_to_target() -> Vector3:
	if not _target or not turret_pivot:
		return Vector3.FORWARD
	var target_pos := _get_target_position()
	var pivot_pos := turret_pivot.global_position
	return (target_pos - pivot_pos).normalized()


## Rotates the turret horizontally (yaw) to face the target
func _rotate_horizontal(direction: Vector3, delta: float) -> void:
	var look_at_horizontal := Transform3D().looking_at(direction, Vector3.UP)
	turret_pivot.basis = turret_pivot.basis.slerp(
		look_at_horizontal.basis,
		delta * rotation_speed
	)


## Rotates the gun vertically (pitch) to aim at the target
func _rotate_vertical(target_pos: Vector3, delta: float) -> void:
	# Get the local direction to the target relative to the turret pivot
	var local_target_pos := turret_pivot.to_local(target_pos)
	var local_direction := local_target_pos.normalized()

	# Create a target transform for the vertical pivot
	var look_at_vertical := Transform3D().looking_at(local_direction, Vector3.UP)
	gun_pivot.basis = gun_pivot.basis.slerp(
		look_at_vertical.basis,
		delta * rotation_speed
	)

	# Clamp the pitch angle to prevent over-rotation
	_clamp_pitch_angle()


## Clamps the gun's pitch angle within the configured limits
func _clamp_pitch_angle() -> void:
	var pitch_angle := rad_to_deg(gun_pivot.rotation.x)
	gun_pivot.rotation.x = deg_to_rad(
		clampf(pitch_angle, min_pitch_angle, max_pitch_angle)
	)


## Gets the target position with height offset applied
func _get_target_position() -> Vector3:
	if not _target:
		return Vector3.ZERO
	return _target.global_position + Vector3(0, target_height_offset, 0)


## Checks if the turret is aimed close enough to the target to fire
func _is_aimed_at_target(direction_to_target: Vector3) -> bool:
	var forward_dir := -gun_pivot.global_transform.basis.z
	return forward_dir.dot(direction_to_target) > AIM_TOLERANCE


## Performs a raycast to check if there's a clear line of sight to the target
func _has_line_of_sight() -> bool:
	# If line of sight check is disabled, always return true
	if not line_of_sight_required:
		return true

	# Ensure we have a valid target and muzzle
	if not _target or not muzzle:
		return false

	# Setup the raycast query
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()

	# Cast from the muzzle to the target's center
	query.from = muzzle.global_position
	query.to = _get_target_position()
	query.collision_mask = los_collision_mask

	# Exclude the turret itself from the raycast
	query.exclude = [self]

	# Perform the raycast
	var result := space_state.intersect_ray(query)

	# If nothing was hit, we have clear line of sight
	if result.is_empty():
		return true

	# If we hit the target, we have line of sight
	if result.collider == _target:
		return true

	# We hit something else (a wall/obstacle), no line of sight
	return false


## Fires a projectile from the turret
func _fire() -> void:
	if not _can_fire or not projectile_scene or not muzzle:
		return

	var projectile := projectile_scene.instantiate()
	projectile.global_transform = muzzle.global_transform

	# Add to the scene root to avoid parent transform issues
	get_tree().get_root().add_child(projectile)

	# Start the fire rate cooldown
	_can_fire = false
	if fire_rate_timer:
		fire_rate_timer.start()


## Called when a body enters the detection area
func _on_body_entered(body: Node3D) -> void:
	print("Turret: Body entered detection area - %s (groups: %s)" % [body.name, body.get_groups()])

	if body.is_in_group(target_group):
		_target = body
		print("Turret: Target acquired - %s" % body.name)


## Called when a body exits the detection area
func _on_body_exited(body: Node3D) -> void:
	if body == _target:
		_target = null
		print("Turret: Target lost - %s" % body.name)


## Called when the fire rate timer times out
func _on_fire_rate_timer_timeout() -> void:
	_can_fire = true


## Creates the interaction prompt label
func _create_interaction_prompt() -> void:
	_interaction_prompt = Label3D.new()
	_interaction_prompt.text = "[E] Load Ammo"
	_interaction_prompt.pixel_size = 0.01
	_interaction_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interaction_prompt.position = Vector3(0, 2.0, 0)  # Float above turret
	_interaction_prompt.modulate = Color.YELLOW
	_interaction_prompt.outline_modulate = Color.BLACK
	_interaction_prompt.outline_size = 2
	_interaction_prompt.visible = false
	add_child(_interaction_prompt)


## Shows the interaction prompt
func _show_interaction_prompt() -> void:
	if _interaction_prompt:
		# Update text to show current ammo
		var current_ammo = _get_ammo_count()
		_interaction_prompt.text = "[E] Load Ammo (%d/%d)" % [current_ammo, ammo_capacity]
		_interaction_prompt.visible = true


## Hides the interaction prompt
func _hide_interaction_prompt() -> void:
	if _interaction_prompt:
		_interaction_prompt.visible = false


## Called when a player enters the interaction area
func _on_interaction_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		_show_interaction_prompt()
		print("Turret: Player in range - Press E to load ammo")


## Called when a player exits the interaction area
func _on_interaction_area_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		_hide_interaction_prompt()
		print("Turret: Player out of range")


## Called by player when pressing E near the turret
func interact() -> void:
	print("Turret: interact() called - opening ammo storage UI")
	open_storage()


## Opens the turret UI for ammo management
func open_storage() -> void:
	print("Opening turret ammo UI...")

	# Use the TurretUI instance
	if TurretUI.instance:
		print("Opening turret UI interface...")
		TurretUI.instance.open_turret_interface(self)
	else:
		print("ERROR: TurretUI.instance not found")


## Closes the turret UI
func close_storage() -> void:
	if TurretUI.instance:
		TurretUI.instance.close_turret_interface()


## Syncs _ammo_storage with storage_inventory for UI display
func _sync_storage() -> void:
	storage_inventory["0"] = {
		"item_id": accepted_ammo_type if _get_ammo_count() > 0 else "",
		"quantity": _get_ammo_count()
	}


## Called by StorageUI when adding items
func add_item_to_storage(item_id: String, quantity: int) -> int:
	# Only accept the configured ammo type
	if item_id != accepted_ammo_type:
		print("Turret: Wrong ammo type. This turret only accepts %s" % accepted_ammo_type)
		return quantity  # Return all as remaining

	var current_ammo = _get_ammo_count()
	var space_available = ammo_capacity - current_ammo
	var amount_to_add = mini(quantity, space_available)

	if amount_to_add > 0:
		_ammo_storage[accepted_ammo_type] = current_ammo + amount_to_add
		_sync_storage()  # Update storage_inventory for UI
		print("Turret: Added %d ammo. Total: %d/%d" % [amount_to_add, _ammo_storage[accepted_ammo_type], ammo_capacity])
		return quantity - amount_to_add  # Return remaining

	return quantity  # Full, return all


## Called by StorageUI when removing items
func remove_item_from_storage(slot_index: int, quantity: int) -> Dictionary:
	if slot_index != 0:  # We only have 1 slot
		return {"item_id": "", "quantity": 0}

	var current_ammo = _get_ammo_count()
	var amount_to_remove = mini(quantity, current_ammo)

	if amount_to_remove > 0:
		_ammo_storage[accepted_ammo_type] = current_ammo - amount_to_remove
		_sync_storage()  # Update storage_inventory for UI
		print("Turret: Removed %d ammo. Remaining: %d/%d" % [amount_to_remove, _ammo_storage[accepted_ammo_type], ammo_capacity])
		return {"item_id": accepted_ammo_type, "quantity": amount_to_remove}

	return {"item_id": "", "quantity": 0}


## Public API: Manually set a target (useful for scripted behaviors)
func set_target(new_target: Node3D) -> void:
	_target = new_target


## Public API: Clear the current target
func clear_target() -> void:
	_target = null


## Public API: Check if the turret has a target
func has_target() -> bool:
	return _has_valid_target()


## Public API: Get the current state
func get_current_state() -> State:
	return _current_state


## Public API: Get the current state as a string
func get_current_state_name() -> String:
	match _current_state:
		State.IDLE:
			return "IDLE"
		State.SEARCHING:
			return "SEARCHING"
		State.AIMING:
			return "AIMING"
		State.FIRING:
			return "FIRING"
		_:
			return "UNKNOWN"


## Public API: Add ammo to the turret
func add_ammo(ammo_id: String, quantity: int) -> bool:
	# Only accept the configured ammo type
	if ammo_id != accepted_ammo_type:
		push_warning("Turret: Wrong ammo type. This turret uses %s" % accepted_ammo_type)
		return false

	var current_ammo = _ammo_storage.get(accepted_ammo_type, 0)
	var space_available = ammo_capacity - current_ammo
	var amount_to_add = mini(quantity, space_available)

	if amount_to_add > 0:
		_ammo_storage[accepted_ammo_type] = current_ammo + amount_to_add
		print("Turret: Added %d ammo. Total: %d/%d" % [amount_to_add, _ammo_storage[accepted_ammo_type], ammo_capacity])
		return true

	return false


## Public API: Get current ammo count
func get_ammo_count() -> int:
	return _get_ammo_count()


## Public API: Get max ammo capacity
func get_ammo_capacity() -> int:
	return ammo_capacity


## Public API: Check if player can interact with turret
func can_interact() -> bool:
	return _interaction_area != null
