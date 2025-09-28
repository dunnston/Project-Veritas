extends Node

# Status Effect System for Neon Wasteland
# Handles DoT, buffs, debuffs, and timed effects

signal status_effect_applied(effect_name: String, duration: float)
signal status_effect_removed(effect_name: String)
signal status_effect_tick(effect_name: String, value: float)

enum StatusType {
	DAMAGE_OVER_TIME,  # Fire burning, poison, radiation
	HEAL_OVER_TIME,    # Regeneration effects
	MOVEMENT_MODIFIER, # Speed changes (slow/fast)
	ATTRIBUTE_MODIFIER,# Temporary stat changes
	DISABLE_EFFECT     # Stun, silence, etc.
}

class StatusEffect:
	var name: String
	var type: StatusType
	var duration: float
	var max_duration: float
	var tick_interval: float
	var tick_timer: float
	var value: float  # Damage per tick, speed modifier, etc.
	var attribute_name: String = ""  # For attribute modifiers
	var is_stacking: bool = false  # Can multiple instances stack?
	var source: String = ""
	
	func _init(effect_name: String, effect_type: StatusType, effect_duration: float, 
			   effect_value: float = 0.0, interval: float = 1.0):
		name = effect_name
		type = effect_type
		duration = effect_duration
		max_duration = effect_duration
		tick_interval = interval
		tick_timer = 0.0
		value = effect_value

var active_effects: Dictionary = {}
var player_reference: Node = null

func _ready():
	set_process(true)

func _process(delta: float):
	if active_effects.is_empty():
		return
	
	var effects_to_remove = []
	
	for effect_name in active_effects:
		var effect = active_effects[effect_name]
		effect.duration -= delta
		effect.tick_timer -= delta
		
		# Apply tick effects
		if effect.tick_timer <= 0.0:
			effect.tick_timer = effect.tick_interval
			_apply_status_tick(effect)
		
		# Remove expired effects
		if effect.duration <= 0.0:
			effects_to_remove.append(effect_name)
	
	# Clean up expired effects
	for effect_name in effects_to_remove:
		remove_status_effect(effect_name)

func apply_status_effect(effect_name: String, type: StatusType, duration: float, 
						 value: float = 0.0, source: String = "", 
						 tick_interval: float = 1.0, stacking: bool = false):
	
	# Check if effect already exists
	if active_effects.has(effect_name):
		if stacking:
			# Stack the effect by increasing value
			active_effects[effect_name].value += value
			active_effects[effect_name].duration = max(active_effects[effect_name].duration, duration)
		else:
			# Refresh duration and update value
			active_effects[effect_name].duration = duration
			active_effects[effect_name].value = value
		return
	
	# Create new effect
	var new_effect = StatusEffect.new(effect_name, type, duration, value, tick_interval)
	new_effect.source = source
	new_effect.is_stacking = stacking
	
	active_effects[effect_name] = new_effect
	
	# Apply initial effect if needed
	_apply_status_initial(new_effect)
	
	status_effect_applied.emit(effect_name, duration)
	print("[STATUS] Applied %s for %.1fs (value: %.1f)" % [effect_name, duration, value])

func remove_status_effect(effect_name: String):
	if not active_effects.has(effect_name):
		return
	
	var effect = active_effects[effect_name]
	
	# Remove effect influence
	_remove_status_influence(effect)
	
	active_effects.erase(effect_name)
	status_effect_removed.emit(effect_name)
	print("[STATUS] Removed %s" % effect_name)

func _apply_status_initial(effect: StatusEffect):
	if not player_reference:
		player_reference = GameManager.player_node
	
	if not player_reference:
		return
	
	match effect.type:
		StatusType.MOVEMENT_MODIFIER:
			# Apply movement speed change
			if effect.name == "cold_slow":
				if player_reference.has_method("apply_speed_modifier"):
					player_reference.apply_speed_modifier(effect.value)
				else:
					player_reference.speed_modifier *= effect.value
		
		StatusType.DISABLE_EFFECT:
			if effect.name == "shock_stun":
				# Disable player input
				if player_reference.has_method("set_input_disabled"):
					player_reference.set_input_disabled(true)
		
		StatusType.ATTRIBUTE_MODIFIER:
			# Apply temporary attribute change
			if has_node("/root/AttributeManager"):
				var attr_mgr = get_node("/root/AttributeManager")
				attr_mgr.add_temporary_modifier(effect.attribute_name, effect.value, effect.duration)

func _apply_status_tick(effect: StatusEffect):
	if not player_reference:
		player_reference = GameManager.player_node
	
	if not player_reference:
		return
	
	match effect.type:
		StatusType.DAMAGE_OVER_TIME:
			# Apply damage over time
			if player_reference.has_method("take_damage"):
				var damage_type = "fire"  # Default
				if effect.name.begins_with("burn"):
					damage_type = "fire"
				elif effect.name.begins_with("poison"):
					damage_type = "physical"
				elif effect.name.begins_with("radiation"):
					damage_type = "radiation"
				
				player_reference.take_damage(effect.value, damage_type)
				status_effect_tick.emit(effect.name, effect.value)
		
		StatusType.HEAL_OVER_TIME:
			# Apply healing over time
			if player_reference.has_method("modify_health"):
				player_reference.modify_health(int(effect.value))
				status_effect_tick.emit(effect.name, effect.value)

func _remove_status_influence(effect: StatusEffect):
	if not player_reference:
		player_reference = GameManager.player_node
	
	if not player_reference:
		return
	
	match effect.type:
		StatusType.MOVEMENT_MODIFIER:
			# Restore movement speed
			if effect.name == "cold_slow":
				if player_reference.has_method("remove_speed_modifier"):
					player_reference.remove_speed_modifier()
				else:
					player_reference.speed_modifier = 1.0
		
		StatusType.DISABLE_EFFECT:
			if effect.name == "shock_stun":
				# Re-enable player input
				if player_reference.has_method("set_input_disabled"):
					player_reference.set_input_disabled(false)

# Predefined status effect presets
func apply_fire_burn(duration: float = 5.0, damage_per_second: float = 3.0):
	apply_status_effect("fire_burn", StatusType.DAMAGE_OVER_TIME, 
						duration, damage_per_second, "fire_damage")

func apply_cold_slow(duration: float = 3.0, speed_reduction: float = 0.5):
	apply_status_effect("cold_slow", StatusType.MOVEMENT_MODIFIER, 
						duration, speed_reduction, "cold_damage")

func apply_shock_stun(duration: float = 1.0):
	apply_status_effect("shock_stun", StatusType.DISABLE_EFFECT, 
						duration, 0.0, "shock_damage")

func apply_radiation_poisoning(duration: float = 10.0, damage_per_second: float = 1.0):
	apply_status_effect("radiation_poison", StatusType.DAMAGE_OVER_TIME, 
						duration, damage_per_second, "radiation_damage")

func apply_healing_over_time(duration: float = 10.0, healing_per_second: float = 2.0, source: String = "medical"):
	apply_status_effect("healing_regen", StatusType.HEAL_OVER_TIME, 
						duration, healing_per_second, source)

# Query methods
func has_status_effect(effect_name: String) -> bool:
	return active_effects.has(effect_name)

func get_status_effect_duration(effect_name: String) -> float:
	if active_effects.has(effect_name):
		return active_effects[effect_name].duration
	return 0.0

func get_all_active_effects() -> Array:
	var effect_list = []
	for effect_name in active_effects:
		var effect = active_effects[effect_name]
		effect_list.append({
			"name": effect.name,
			"duration": effect.duration,
			"max_duration": effect.max_duration,
			"value": effect.value,
			"source": effect.source
		})
	return effect_list

func clear_all_effects():
	for effect_name in active_effects.keys():
		remove_status_effect(effect_name)

# Debug methods
func debug_print_active_effects():
	print("=== Active Status Effects ===")
	for effect_name in active_effects:
		var effect = active_effects[effect_name]
		print("%s: %.1fs remaining, value: %.1f" % [effect.name, effect.duration, effect.value])