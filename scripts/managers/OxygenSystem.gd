extends Node

signal oxygen_level_changed(level: float, max_level: float)
signal oxygen_state_changed(has_oxygen: bool)
signal suffocation_started()
signal suffocation_ended()
signal player_died_from_suffocation()
signal oxygen_source_added(source: Node)
signal oxygen_source_removed(source: Node)

const OXYGEN_RANGE: float = 600.0  # Range in pixels for oxygen supply
const OXYGEN_CHECK_INTERVAL: float = 0.2  # Check oxygen every 0.2 seconds
const MAX_OXYGEN: float = 100.0
const OXYGEN_DEPLETION_RATE: float = 2.0  # Oxygen depletes at 2 units per second without supply
const OXYGEN_REPLENISH_RATE: float = 10.0  # Oxygen replenishes at 10 units per second with supply
const SUFFOCATION_DAMAGE_RATE: float = 5.0  # Damage per second when suffocating

var oxygen_level: float = MAX_OXYGEN
var oxygen_sources: Array[Node] = []
var player_ref: Node = null
var is_suffocating: bool = false
var has_oxygen_supply: bool = false
var check_timer: Timer
var last_oxygen_source: Node = null

# Backup oxygen system
var backup_oxygen_active: bool = true
var emergency_started: bool = false

func _ready():
	print("OxygenSystem: Initializing...")
	add_to_group("oxygen_system")
	
	# Setup timer for periodic oxygen checks
	check_timer = Timer.new()
	check_timer.wait_time = OXYGEN_CHECK_INTERVAL
	check_timer.timeout.connect(_update_oxygen)
	add_child(check_timer)
	check_timer.start()
	
	# Wait for player to be registered
	await get_tree().process_frame
	if GameManager.player_node:
		register_player(GameManager.player_node)

func register_player(player: Node):
	player_ref = player
	print("OxygenSystem: Player registered")

func register_oxygen_source(source: Node):
	if source in oxygen_sources:
		return
	
	oxygen_sources.append(source)
	# Handle position display for both 2D and 3D sources
	var pos_display = source.global_position if source.has_property("global_position") else "unknown position"
	print("OxygenSystem: Registered oxygen source at ", pos_display)
	oxygen_source_added.emit(source)
	
	# Immediate oxygen check
	_check_oxygen_availability()

func unregister_oxygen_source(source: Node):
	if source not in oxygen_sources:
		return
	
	oxygen_sources.erase(source)
	print("OxygenSystem: Unregistered oxygen source")
	oxygen_source_removed.emit(source)
	
	if source == last_oxygen_source:
		last_oxygen_source = null
	
	_check_oxygen_availability()

func _update_oxygen():
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	# If backup oxygen is still active, maintain full oxygen
	# (This remains true during the 72-hour countdown)
	if backup_oxygen_active:
		oxygen_level = MAX_OXYGEN
		has_oxygen_supply = true
		if is_suffocating:
			_stop_suffocation()
		oxygen_level_changed.emit(oxygen_level, MAX_OXYGEN)
		return
	
	# Check if player is in range of an oxygen source
	_check_oxygen_availability()
	
	# Update oxygen level based on supply
	var delta = check_timer.wait_time
	
	if has_oxygen_supply:
		# Replenish oxygen
		oxygen_level = min(oxygen_level + OXYGEN_REPLENISH_RATE * delta, MAX_OXYGEN)
		
		if is_suffocating:
			_stop_suffocation()
	else:
		# Deplete oxygen
		oxygen_level = max(oxygen_level - OXYGEN_DEPLETION_RATE * delta, 0.0)
		
		if oxygen_level <= 0 and not is_suffocating:
			_start_suffocation()
	
	# Apply suffocation damage if needed
	if is_suffocating:
		_apply_suffocation_damage(delta)
	
	# Emit oxygen level update
	oxygen_level_changed.emit(oxygen_level, MAX_OXYGEN)

func _check_oxygen_availability():
	if not player_ref or not is_instance_valid(player_ref):
		has_oxygen_supply = false
		return
	
	var nearest_source = null
	var min_distance = OXYGEN_RANGE + 1.0
	
	# Find nearest active oxygen source within range
	for source in oxygen_sources:
		if not is_instance_valid(source):
			continue
		
		# Check if oxygen source is powered and active
		if source.has_method("get_is_producing_oxygen"):
			if not source.get_is_producing_oxygen():
				continue
		elif source.has_method("is_producing_oxygen"):
			if not source.is_producing_oxygen():
				continue
		elif source.has_method("get_is_powered"):
			if not source.get_is_powered():
				continue
		else:
			# Skip if we can't verify it's active
			continue
		
		# Handle position conversion for distance calculation between 2D/3D nodes
		var player_pos: Vector2
		var source_pos: Vector2

		# Convert player position to 2D
		if player_ref.global_position is Vector3:
			var pos_3d = player_ref.global_position
			player_pos = Vector2(pos_3d.x, pos_3d.z)  # Use X,Z for 2D distance
		else:
			player_pos = player_ref.global_position

		# Convert source position to 2D
		if source.global_position is Vector3:
			var src_pos_3d = source.global_position
			source_pos = Vector2(src_pos_3d.x, src_pos_3d.z)  # Use X,Z for 2D distance
		else:
			source_pos = source.global_position

		var distance = player_pos.distance_to(source_pos)
		if distance <= OXYGEN_RANGE and distance < min_distance:
			nearest_source = source
			min_distance = distance
	
	# Update oxygen supply state
	var had_oxygen = has_oxygen_supply
	has_oxygen_supply = nearest_source != null
	last_oxygen_source = nearest_source
	
	# Emit signal if oxygen state changed
	if had_oxygen != has_oxygen_supply:
		print("OxygenSystem: Oxygen supply ", "AVAILABLE" if has_oxygen_supply else "LOST")
		oxygen_state_changed.emit(has_oxygen_supply)

func _start_suffocation():
	if is_suffocating:
		return
	
	is_suffocating = true
	print("OxygenSystem: Player is suffocating!")
	suffocation_started.emit()
	
	# Show warning to player
	if player_ref and player_ref.has_method("show_warning"):
		player_ref.show_warning("WARNING: No oxygen supply! Find an oxygen source!")

func _stop_suffocation():
	if not is_suffocating:
		return
	
	is_suffocating = false
	print("OxygenSystem: Player stopped suffocating")
	suffocation_ended.emit()

func _apply_suffocation_damage(delta: float):
	if not player_ref or not is_instance_valid(player_ref):
		return
	
	# Apply damage to player
	var damage = SUFFOCATION_DAMAGE_RATE * delta
	if player_ref.has_method("modify_health"):
		player_ref.modify_health(-damage)
		
		# Check if player died
		if "health" in player_ref and player_ref.health <= 0:
			print("OxygenSystem: Player died from suffocation!")
			player_died_from_suffocation.emit()

func get_oxygen_level() -> float:
	return oxygen_level

func get_oxygen_percentage() -> float:
	return (oxygen_level / MAX_OXYGEN) * 100.0

func is_player_suffocating() -> bool:
	return is_suffocating

func has_oxygen() -> bool:
	return has_oxygen_supply

func get_oxygen_range() -> float:
	return OXYGEN_RANGE

func get_nearest_oxygen_source() -> Node2D:
	return last_oxygen_source

func set_oxygen_level(level: float):
	oxygen_level = clamp(level, 0.0, MAX_OXYGEN)
	oxygen_level_changed.emit(oxygen_level, MAX_OXYGEN)

func start_emergency():
	"""Called when the tablet is read and emergency countdown begins"""
	emergency_started = true
	print("OxygenSystem: Emergency countdown started - backup oxygen still active")

func end_backup_oxygen():
	"""Called when the 72-hour countdown ends"""
	backup_oxygen_active = false
	print("OxygenSystem: Backup oxygen systems offline! Player must rely on built oxygen tanks!")
	
	# Check if player has oxygen supply immediately
	_check_oxygen_availability()
	
	# If no oxygen supply available, start depleting immediately
	if not has_oxygen_supply:
		print("OxygenSystem: No oxygen sources found! Beginning oxygen depletion!")

func is_backup_active() -> bool:
	return backup_oxygen_active

func is_emergency_active() -> bool:
	return emergency_started
