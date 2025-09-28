extends Node

class_name StormSystemSingleton

signal storm_warning_issued(warning_type: WarningType, time_remaining: float, storm_type: StormType)
signal storm_phase_changed(phase: StormPhase)
signal storm_shelter_status_changed(is_sheltered: bool)

enum StormType {
	DUST_STORM,      # Reduced visibility, movement penalty
	RADIATION_STORM, # Increased radiation accumulation
	ELECTRICAL_STORM,# Equipment damage risk, power issues
	TOXIC_STORM      # Breathing damage without protection
}

enum WarningType {
	EARLY_WARNING,    # 5 minutes before
	INCOMING_WARNING, # 2 minutes before
	IMMEDIATE_WARNING # 30 seconds before
}

enum StormPhase {
	CALM,
	EARLY_WARNING,
	INCOMING_WARNING, 
	IMMEDIATE_WARNING,
	STORM_ACTIVE
}

# Storm timing constants
const BASE_WARNING_TIME: float = 300.0      # 5 minutes
const INCOMING_WARNING_TIME: float = 120.0  # 2 minutes  
const IMMEDIATE_WARNING_TIME: float = 30.0  # 30 seconds
const MIN_STORM_DURATION: float = 600.0     # 10 minutes
const MAX_STORM_DURATION: float = 1200.0    # 20 minutes
const MIN_STORM_INTERVAL: float = 1800.0    # 30 minutes
const MAX_STORM_INTERVAL: float = 3600.0    # 60 minutes

# Storm state
var current_storm_phase: StormPhase = StormPhase.CALM
var current_storm_type: StormType = StormType.DUST_STORM
var current_storm_active: bool = false
var storm_duration_remaining: float = 0.0
var time_until_next_storm: float = 0.0
var player_in_shelter: bool = false

# Warning state tracking
var early_warning_issued: bool = false
var incoming_warning_issued: bool = false
var immediate_warning_issued: bool = false

# Effect modifiers
var visibility_modifier: float = 1.0
var movement_modifier: float = 1.0
var radiation_multiplier: float = 1.0
var equipment_damage_risk: float = 0.0

func _ready() -> void:
	print("StormSystem: Initializing enhanced storm system...")
	schedule_next_storm()
	
	# Connect to time manager for precise timing
	if TimeManager:
		TimeManager.connect("hour_passed", _on_hour_passed)
	
	# Connect to player movement for shelter detection
	if GameManager.player_node:
		setup_player_connections()

func _process(delta: float) -> void:
	if current_storm_active:
		update_active_storm(delta)
	else:
		update_storm_countdown(delta)

func setup_player_connections() -> void:
	# This will be called when player is ready
	pass

func update_storm_countdown(delta: float) -> void:
	if time_until_next_storm <= 0:
		return
		
	time_until_next_storm -= delta
	
	# Check for warning phases
	if not early_warning_issued and time_until_next_storm <= BASE_WARNING_TIME:
		issue_early_warning()
	elif not incoming_warning_issued and time_until_next_storm <= INCOMING_WARNING_TIME:
		issue_incoming_warning() 
	elif not immediate_warning_issued and time_until_next_storm <= IMMEDIATE_WARNING_TIME:
		issue_immediate_warning()
	elif time_until_next_storm <= 0:
		start_storm(get_random_storm_type())

func update_active_storm(delta: float) -> void:
	storm_duration_remaining -= delta
	
	# Apply storm effects
	apply_storm_effects(delta)
	
	if storm_duration_remaining <= 0:
		end_storm()

func schedule_next_storm() -> void:
	time_until_next_storm = randf_range(MIN_STORM_INTERVAL, MAX_STORM_INTERVAL)
	reset_warning_flags()
	print("StormSystem: Next storm scheduled in %.1f seconds (%.1f minutes)" % [time_until_next_storm, time_until_next_storm / 60.0])

func get_random_storm_type() -> StormType:
	return randi() % StormType.size() as StormType

func get_effective_warning_time() -> float:
	# Base warning time - can be modified by perks later
	return BASE_WARNING_TIME

func issue_early_warning() -> void:
	early_warning_issued = true
	current_storm_phase = StormPhase.EARLY_WARNING
	current_storm_type = get_random_storm_type()
	
	print("StormSystem: Early warning issued - %s approaching in %.1f minutes" % [get_storm_name(current_storm_type), time_until_next_storm / 60.0])
	storm_warning_issued.emit(WarningType.EARLY_WARNING, time_until_next_storm, current_storm_type)
	storm_phase_changed.emit(current_storm_phase)

func issue_incoming_warning() -> void:
	incoming_warning_issued = true 
	current_storm_phase = StormPhase.INCOMING_WARNING
	
	print("StormSystem: Incoming warning - %s approaching fast in %.1f minutes" % [get_storm_name(current_storm_type), time_until_next_storm / 60.0])
	storm_warning_issued.emit(WarningType.INCOMING_WARNING, time_until_next_storm, current_storm_type)
	storm_phase_changed.emit(current_storm_phase)

func issue_immediate_warning() -> void:
	immediate_warning_issued = true
	current_storm_phase = StormPhase.IMMEDIATE_WARNING
	
	print("StormSystem: Immediate warning - %s imminent! Seek shelter!" % get_storm_name(current_storm_type))
	storm_warning_issued.emit(WarningType.IMMEDIATE_WARNING, time_until_next_storm, current_storm_type)
	storm_phase_changed.emit(current_storm_phase)

func start_storm(storm_type: StormType) -> void:
	if current_storm_active:
		return
		
	current_storm_active = true
	current_storm_type = storm_type
	current_storm_phase = StormPhase.STORM_ACTIVE
	storm_duration_remaining = randf_range(MIN_STORM_DURATION, MAX_STORM_DURATION)
	
	print("StormSystem: %s started! Duration: %.1f minutes" % [get_storm_name(storm_type), storm_duration_remaining / 60.0])
	
	# Apply storm-specific setup
	setup_storm_effects(storm_type)
	storm_phase_changed.emit(current_storm_phase)
	
	# Emit to existing weather system for visual effects
	if EventBus:
		EventBus.emit_storm_started(1.0)

func end_storm() -> void:
	if not current_storm_active:
		return
		
	print("StormSystem: %s ended." % get_storm_name(current_storm_type))
	
	current_storm_active = false
	current_storm_phase = StormPhase.CALM
	storm_duration_remaining = 0.0
	
	# Reset all effect modifiers
	reset_storm_effects()
	storm_phase_changed.emit(current_storm_phase)
	
	# Award Environmental Adaptation XP for surviving
	award_storm_survival_xp()
	
	# Emit to existing weather system
	if EventBus:
		EventBus.emit_storm_ended()
	
	# Schedule next storm
	schedule_next_storm()

func setup_storm_effects(storm_type: StormType) -> void:
	match storm_type:
		StormType.DUST_STORM:
			visibility_modifier = 0.6
			movement_modifier = 0.8
			equipment_damage_risk = 0.0
			radiation_multiplier = 1.0
			
		StormType.RADIATION_STORM:
			visibility_modifier = 0.8
			movement_modifier = 1.0
			equipment_damage_risk = 0.0
			radiation_multiplier = 3.0  # Triple radiation accumulation
			
		StormType.ELECTRICAL_STORM:
			visibility_modifier = 0.9
			movement_modifier = 1.0
			equipment_damage_risk = 0.1  # 10% chance per minute
			radiation_multiplier = 1.0
			
		StormType.TOXIC_STORM:
			visibility_modifier = 0.7
			movement_modifier = 0.9
			equipment_damage_risk = 0.0
			radiation_multiplier = 1.0

func reset_storm_effects() -> void:
	visibility_modifier = 1.0
	movement_modifier = 1.0
	radiation_multiplier = 1.0
	equipment_damage_risk = 0.0

func apply_storm_effects(delta: float) -> void:
	if not GameManager.player_node:
		return
		
	# Check shelter status
	var currently_sheltered = is_player_in_shelter()
	if currently_sheltered != player_in_shelter:
		player_in_shelter = currently_sheltered
		storm_shelter_status_changed.emit(player_in_shelter)
	
	# Apply effects only if not sheltered
	if not player_in_shelter:
		apply_unsheltered_storm_effects(delta)

func apply_unsheltered_storm_effects(delta: float) -> void:
	var player = GameManager.player_node
	
	# Get shelter protection multiplier (0.0 = no protection, 1.0 = full protection)
	var protection_multiplier = 0.0
	if has_node("/root/ShelterSystem"):
		var shelter_system = get_node("/root/ShelterSystem")
		protection_multiplier = shelter_system.get_shelter_protection_multiplier()
	
	# Damage reduction based on shelter quality (inverted - less protection = more damage)
	var damage_multiplier = 1.0 - protection_multiplier
	
	match current_storm_type:
		StormType.DUST_STORM:
			# Movement penalty handled by getting movement modifier
			# Dust can get through partial shelters
			if damage_multiplier > 0.25:  # Only if shelter is <75% effective
				# Minor health damage from dust inhalation
				if player.has_method("modify_health"):
					player.modify_health(-1.0 * damage_multiplier * delta)
			
		StormType.RADIATION_STORM:
			# Increased radiation exposure - partially blocked by shelter
			if player.has_method("add_radiation_damage"):
				var base_radiation = 0.5 * radiation_multiplier  # 0.5 per second base
				var actual_radiation = base_radiation * damage_multiplier
				player.add_radiation_damage(actual_radiation * delta)
				
		StormType.ELECTRICAL_STORM:
			# Equipment damage risk - reduced by shelter
			var actual_risk = equipment_damage_risk * damage_multiplier
			if randf() < actual_risk * delta / 60.0:  # Convert per-minute to per-frame
				damage_random_equipment()
				
		StormType.TOXIC_STORM:
			# Breathing damage without protection - shelter helps significantly
			if not has_breathing_protection():
				if player.has_method("modify_health"):
					var base_toxic_damage = 5.0  # 5 damage per second base
					var actual_damage = base_toxic_damage * damage_multiplier
					player.modify_health(-actual_damage * delta)

func damage_random_equipment() -> void:
	var player = GameManager.player_node
	if not player or not player.has_method("get_equipment_manager"):
		return
		
	var equipment_manager = player.get_equipment_manager()
	if not equipment_manager:
		return
		
	# Get all equipped items
	var equipped_items = []
	for slot in equipment_manager.equipment_slots.values():
		if slot != null:
			equipped_items.append(slot)
			
	if equipped_items.size() > 0:
		var item = equipped_items[randi() % equipped_items.size()]
		if item.has_method("reduce_durability"):
			item.reduce_durability(5.0)  # 5 durability damage from electrical storm
			print("StormSystem: Lightning damaged %s!" % item.item_name)

func has_breathing_protection() -> bool:
	var player = GameManager.player_node
	if not player or not player.has_method("get_equipment_manager"):
		return false
		
	var equipment_manager = player.get_equipment_manager()
	if not equipment_manager:
		return false
		
	# Check for protective equipment
	var head_item = equipment_manager.get_equipped_item("head")
	if head_item and head_item.get("provides_breathing_protection", false):
		return true
		
	var chest_item = equipment_manager.get_equipped_item("chest") 
	if chest_item and chest_item.get("provides_breathing_protection", false):
		return true
		
	return false

func is_player_in_shelter() -> bool:
	# Use new ShelterSystem for advanced shelter detection
	if has_node("/root/ShelterSystem"):
		var shelter_system = get_node("/root/ShelterSystem")
		var protection_multiplier = shelter_system.get_shelter_protection_multiplier()
		return protection_multiplier > 0.5  # Consider sheltered if >50% protection
	
	# Fallback to old system
	if not GameManager.player_node:
		return false
		
	var player_pos = GameManager.player_node.global_position
	var grid_pos = BuildingManager.snap_to_grid(player_pos)
	
	# Check 3x3 area around player for shelter
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_pos = grid_pos + Vector2(x * BuildingManager.GRID_SIZE, y * BuildingManager.GRID_SIZE)
			var building = BuildingManager.get_building_at(check_pos)
			if building and building.get("provides_shelter", false):
				return true
				
	return false

func award_storm_survival_xp() -> void:
	if not is_node_ready() or not has_node("/root/SkillSystem"):
		return
		
	var skill_system = get_node("/root/SkillSystem")
	if not skill_system or not skill_system.has_method("add_xp"):
		return
		
	# Base XP based on storm duration and type
	var base_xp = int(storm_duration_remaining / 60.0)  # 1 XP per minute survived
	var storm_multiplier = 1.0
	
	match current_storm_type:
		StormType.DUST_STORM:
			storm_multiplier = 1.0
		StormType.RADIATION_STORM:
			storm_multiplier = 1.5
		StormType.ELECTRICAL_STORM:
			storm_multiplier = 1.3
		StormType.TOXIC_STORM:
			storm_multiplier = 1.4
	
	var shelter_bonus = 1.0
	if player_in_shelter:
		shelter_bonus = 0.5  # Less XP if sheltered (but still some for preparation)
		
	var final_xp = max(int(base_xp * storm_multiplier * shelter_bonus), 3)
	
	# Award to Environmental Adaptation skill
	skill_system.add_xp("ENVIRONMENTAL_ADAPTATION", final_xp, "storm_survival")
	print("StormSystem: Awarded %d Environmental Adaptation XP for surviving %s" % [final_xp, get_storm_name(current_storm_type)])

func reset_warning_flags() -> void:
	early_warning_issued = false
	incoming_warning_issued = false
	immediate_warning_issued = false

func get_storm_name(storm_type: StormType) -> String:
	match storm_type:
		StormType.DUST_STORM:
			return "Dust Storm"
		StormType.RADIATION_STORM:
			return "Radiation Storm"
		StormType.ELECTRICAL_STORM:
			return "Electrical Storm"
		StormType.TOXIC_STORM:
			return "Toxic Storm"
		_:
			return "Unknown Storm"

func get_storm_description(storm_type: StormType) -> String:
	match storm_type:
		StormType.DUST_STORM:
			return "Reduces visibility and movement speed"
		StormType.RADIATION_STORM:
			return "Increases radiation accumulation significantly"
		StormType.ELECTRICAL_STORM:
			return "Risk of equipment damage from lightning"
		StormType.TOXIC_STORM:
			return "Toxic air causes breathing damage without protection"
		_:
			return "Unknown storm effects"

# Getters for UI and other systems
func get_current_storm_phase() -> StormPhase:
	return current_storm_phase

func get_current_storm_type() -> StormType:
	return current_storm_type

func is_storm_active() -> bool:
	return current_storm_active

func get_storm_duration_remaining() -> float:
	return storm_duration_remaining

func get_time_until_next_storm() -> float:
	return time_until_next_storm

func get_visibility_modifier() -> float:
	return visibility_modifier

func get_movement_modifier() -> float:
	return movement_modifier

func get_radiation_multiplier() -> float:
	return radiation_multiplier

func is_player_sheltered() -> bool:
	return player_in_shelter

# Debug/Testing functions
func force_storm(storm_type: StormType) -> void:
	print("StormSystem: Forcing %s for testing" % get_storm_name(storm_type))
	time_until_next_storm = 0.0
	current_storm_type = storm_type
	start_storm(storm_type)

func skip_to_warning(warning_type: WarningType) -> void:
	match warning_type:
		WarningType.EARLY_WARNING:
			time_until_next_storm = BASE_WARNING_TIME
			reset_warning_flags()
		WarningType.INCOMING_WARNING:
			time_until_next_storm = INCOMING_WARNING_TIME
			early_warning_issued = true
			incoming_warning_issued = false
			immediate_warning_issued = false
		WarningType.IMMEDIATE_WARNING:
			time_until_next_storm = IMMEDIATE_WARNING_TIME
			early_warning_issued = true
			incoming_warning_issued = true
			immediate_warning_issued = false

func _on_hour_passed(hour: int) -> void:
	# This can be used for storm scheduling adjustments
	pass
