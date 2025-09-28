extends CharacterBody2D

class_name Player

signal health_changed(new_health: int)
signal energy_changed(new_energy: int)
signal hunger_changed(new_hunger: int)
signal thirst_changed(new_thirst: int)
signal radiation_changed(new_radiation: float)
signal oxygen_changed(new_oxygen: float)
signal warning_message(message: String)

const MOVE_SPEED = 200.0
const SPRINT_SPEED = 350.0
const SPRINT_ENERGY_COST = 10.0
const INTERACT_RANGE = 64.0

@export var max_health: int = 100
@export var max_energy: int = 100
@export var max_hunger: int = 100
@export var max_thirst: int = 100

var base_max_health: int = 100
var base_max_stamina: int = 100
var health: int = 100
var energy: int = 100
var hunger: int = 100
var thirst: int = 100
var radiation: float = 0.0
var oxygen: float = 100.0
var defense: float = 0.0
var speed_modifier: float = 1.0
var bonus_inventory_slots: int = 0
var input_disabled: bool = false  # For stun effects
var base_speed_modifier: float = 1.0
var temporary_speed_modifiers: Array = []

# Regeneration tracking
var regeneration_timer: float = 0.0
const REGENERATION_INTERVAL = 1.0  # Apply regen every second
var is_sprinting: bool = false
var nearby_interactables: Array = []
var inventory: Inventory

var sprite: ColorRect
var collision_shape: CollisionShape2D
var interaction_area: Area2D
var camera: Camera2D

func _ready() -> void:
	# Get node references
	sprite = get_node("ColorRect")
	collision_shape = get_node("CollisionShape2D")
	interaction_area = get_node("InteractionArea")
	camera = get_node("Camera2D")
	
	print("Player: _ready() called")
	print("Player: InteractionArea found: ", interaction_area != null)
	if interaction_area:
		print("Player: InteractionArea collision_layer: ", interaction_area.collision_layer)
		print("Player: InteractionArea collision_mask: ", interaction_area.collision_mask)
		print("Player: InteractionArea monitoring: ", interaction_area.monitoring)
	
	add_to_group("player")
	GameManager.register_player(self)
	inventory = Inventory.new()
	add_child(inventory)
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered_interaction)
		interaction_area.body_exited.connect(_on_body_exited_interaction)
		print("Player: InteractionArea signals connected")
	else:
		print("Player: ERROR - No InteractionArea found!")
	
	EventBus.player_damaged.connect(_on_damage_received)
	EventBus.player_healed.connect(_on_heal_received)
	
	# Connect to AttributeManager for attribute synchronization
	call_deferred("_connect_to_attribute_manager")

func _physics_process(delta: float) -> void:
	handle_input()
	move_and_slide()
	update_stats(delta)

func handle_input() -> void:
	# Check if input is disabled (stun effect)
	if input_disabled:
		velocity = Vector2.ZERO
		return
	
	var input_vector = Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	
	input_vector = input_vector.normalized()
	
	is_sprinting = Input.is_action_pressed("sprint") and energy > 0 and not input_disabled
	var current_speed = SPRINT_SPEED if is_sprinting else MOVE_SPEED
	current_speed *= calculate_total_speed_modifier()
	
	velocity = input_vector * current_speed
	
	if input_vector.length() > 0:
		update_sprite_direction(input_vector)

func update_sprite_direction(direction: Vector2) -> void:
	if not sprite:
		return
	
	# Change color based on movement direction for visual feedback
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.scale.x = abs(sprite.scale.x)
			sprite.color = Color(0.3, 1.0, 0.3, 1)
		else:
			sprite.scale.x = -abs(sprite.scale.x)
			sprite.color = Color(0.5, 1.0, 0.3, 1)
	else:
		sprite.color = Color(0.3, 1.0, 0.8, 1)

func update_stats(delta: float) -> void:
	if is_sprinting and velocity.length() > 0:
		modify_energy(-SPRINT_ENERGY_COST * delta)
	else:
		# Apply energy regeneration from attributes
		if has_node("/root/AttributeManager"):
			var attr_mgr = get_node("/root/AttributeManager")
			var regen_rate = attr_mgr.get_attribute("energy_regeneration_rate")
			modify_energy(regen_rate * delta)
		else:
			modify_energy(2.0 * delta)
	
	# Degrade hunger and thirst over time (balanced rates - no death risk)
	modify_hunger(-0.3 * delta)   # Takes ~5.5 minutes to empty
	modify_thirst(-0.4 * delta)   # Takes ~4 minutes to empty (thirst faster)
	
	# Handle regeneration timer
	regeneration_timer += delta
	if regeneration_timer >= REGENERATION_INTERVAL:
		regeneration_timer = 0.0
		apply_regeneration()
	
	# Apply attribute-based effects when stats are low
	apply_survival_debuffs()

func apply_regeneration():
	if not has_node("/root/AttributeManager"):
		return
	
	var attr_mgr = get_node("/root/AttributeManager")
	var regen_rates = attr_mgr.get_regeneration_rates()
	
	# Health regeneration (only if not at full health)
	if health < max_health:
		modify_health(int(regen_rates.health))
	
	# Radiation decay
	if radiation > 0:
		modify_radiation(-regen_rates.radiation_decay)

func apply_survival_debuffs():
	# Apply debuffs based on low survival stats
	var debuff_messages = []
	
	if hunger <= 0:
		# Hungry: Reduced damage and attack speed
		debuff_messages.append("Starving: Combat effectiveness reduced")
	
	if thirst <= 0:
		# Thirsty: Reduced max health and health regen
		debuff_messages.append("Dehydrated: Health recovery impaired")
	
	# Show warning messages (throttled)
	for message in debuff_messages:
		show_warning(message)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		interact_with_nearest()
	if event.is_action_pressed("inventory"):
		# I key - Open original inventory system
		toggle_inventory()
	if event.is_action_pressed("build_mode"):
		# Close any open menus before entering build mode
		if GameManager.current_state == GameManager.GameState.INVENTORY:
			GameManager.change_state(GameManager.GameState.IN_GAME)
			await get_tree().process_frame  # Wait a frame
		
		BuildingManager.toggle_building_mode()
	
	# DEBUG: Test hotbar setup with F key
	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		if GameManager:
			GameManager.debug_setup_hotbar()
	
	# DEBUG: Test player stats with G key
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		if GameManager:
			GameManager.debug_test_player_stats()

func interact_with_nearest() -> void:
	print("Player: interact_with_nearest() called")
	print("Player: Number of nearby interactables = ", nearby_interactables.size())
	
	if nearby_interactables.is_empty():
		print("Player: No nearby interactables found")
		return
	
	var nearest = nearby_interactables[0]
	var min_dist = position.distance_to(nearest.global_position)
	
	for interactable in nearby_interactables:
		print("Player: Found interactable: ", interactable.name, " of type: ", interactable.get_class())
		var dist = position.distance_to(interactable.global_position)
		if dist < min_dist:
			nearest = interactable
			min_dist = dist
	
	print("Player: Nearest interactable = ", nearest.name)
	print("Player: Distance = ", min_dist)
	print("Player: Has interact method = ", nearest.has_method("interact"))
	
	if nearest.has_method("interact"):
		print("Player: Calling interact on ", nearest.name)
		nearest.interact(self)
	else:
		print("Player: Nearest interactable does not have interact method")

func toggle_inventory() -> void:
	# Only toggle if not in build mode or other special states
	if GameManager.current_state == GameManager.GameState.BUILD_MODE:
		return
	
	if GameManager.current_state == GameManager.GameState.INVENTORY:
		GameManager.change_state(GameManager.GameState.IN_GAME)
	else:
		GameManager.change_state(GameManager.GameState.INVENTORY)

func modify_health(amount: int) -> void:
	var damage = amount
	if amount < 0:
		damage = EquipmentManager.calculate_damage_reduction(abs(amount))
		damage = -damage
	
	health = clamp(health + damage, 0, max_health)
	health_changed.emit(health)
	EventBus.emit_player_stat_changed("health", health)
	
	if health <= 0:
		die()

func modify_energy(amount: float) -> void:
	energy = clamp(energy + amount, 0, max_energy)
	energy_changed.emit(energy)
	EventBus.emit_player_stat_changed("energy", energy)

func modify_hunger(amount: float) -> void:
	hunger = clamp(hunger + amount, 0, max_hunger)
	hunger_changed.emit(hunger)
	EventBus.emit_player_stat_changed("hunger", hunger)

func modify_thirst(amount: float) -> void:
	thirst = clamp(thirst + amount, 0, max_thirst)
	thirst_changed.emit(thirst)
	EventBus.emit_player_stat_changed("thirst", thirst)

func modify_radiation(amount: float) -> void:
	var max_radiation = 100.0
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		max_radiation = attr_mgr.get_attribute("max_radiation")
	
	radiation = clamp(radiation + amount, 0, max_radiation)
	radiation_changed.emit(radiation)
	EventBus.emit_player_stat_changed("radiation", radiation)
	
	# Update AttributeManager
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		attr_mgr.set_base_attribute("radiation_level", radiation)

func modify_oxygen(amount: float) -> void:
	var max_oxygen = 100.0
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		max_oxygen = attr_mgr.get_attribute("max_oxygen")
	
	oxygen = clamp(oxygen + amount, 0, max_oxygen)
	oxygen_changed.emit(oxygen)
	EventBus.emit_player_stat_changed("oxygen", oxygen)
	
	# Update AttributeManager
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		attr_mgr.set_base_attribute("oxygen", oxygen)
	
	# Grant Life Support XP for managing oxygen
	if has_node("/root/SkillSystem") and amount != 0:
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("LIFE_SUPPORT", skill_system.XP_VALUES.OXYGEN_MANAGED, "oxygen_management")

func die() -> void:
	print("Player died!")
	GameManager.change_state(GameManager.GameState.GAME_OVER)
	queue_free()

func _on_body_entered_interaction(body: Node2D) -> void:
	print("Player: Body entered interaction area: ", body.name, " (", body.get_class(), ")")
	print("Player: Body has interact method: ", body.has_method("interact"))
	if body.has_method("interact"):
		nearby_interactables.append(body)
		print("Player: Added to nearby_interactables. Total count: ", nearby_interactables.size())
	else:
		print("Player: Body does not have interact method, not adding to interactables")

func _on_body_exited_interaction(body: Node2D) -> void:
	print("Player: Body exited interaction area: ", body.name)
	nearby_interactables.erase(body)
	print("Player: Remaining nearby_interactables: ", nearby_interactables.size())

func _on_damage_received(damage: int) -> void:
	modify_health(-damage)
	
	# Grant Environmental Adaptation XP for taking damage
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.add_xp("ENVIRONMENTAL_ADAPTATION", skill_system.XP_VALUES.ENVIRONMENTAL_DAMAGE_TAKEN, "damage_taken")

func _on_heal_received(amount: int) -> void:
	heal_player(amount, "external")

# Enhanced healing system
func heal_player(amount: int, source: String = "unknown") -> int:
	if amount <= 0:
		return 0
	
	var actual_healing = min(amount, max_health - health)
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

func collect_resource(resource_type: String, amount: int) -> bool:
	var final_amount = amount
	if EquipmentManager.has_stat("scavenge_bonus"):
		final_amount = int(amount * EquipmentManager.get_scavenge_multiplier())
	
	# Add resources directly to InventorySystem instead of ResourceManager
	if InventorySystem.add_item(resource_type, final_amount):
		print("Collected %d %s via InventorySystem" % [final_amount, resource_type])
		
		# Grant Scavenging XP for resource collection
		if has_node("/root/SkillSystem"):
			var skill_system = get_node("/root/SkillSystem")
			# Check if it's a rare resource (you can expand this list)
			var rare_resources = ["TITANIUM", "RARE_EARTH", "QUANTUM_CRYSTAL"]
			if resource_type in rare_resources:
				skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RARE_RESOURCE_FOUND, "rare_resource")
			else:
				skill_system.add_xp("SCAVENGING", skill_system.XP_VALUES.RESOURCE_GATHERED, "resource_gathering")
		
		return true
	else:
		print("FAILED to collect %d %s - InventorySystem.add_item() returned false (inventory full?)" % [final_amount, resource_type])
	return false

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
				# Grant Life Support XP for eating
				if has_node("/root/SkillSystem"):
					var skill_system = get_node("/root/SkillSystem")
					skill_system.add_xp("LIFE_SUPPORT", skill_system.XP_VALUES.FOOD_CONSUMED, "food_consumption")
		"WATER":
			if inventory.remove_item(item_id, 1):
				modify_thirst(30.0)  # Water restores 30 thirst
				print("Consumed water, thirst quenched!")
				consumed = true
				# Grant Life Support XP for drinking
				if has_node("/root/SkillSystem"):
					var skill_system = get_node("/root/SkillSystem")
					skill_system.add_xp("LIFE_SUPPORT", skill_system.XP_VALUES.WATER_CONSUMED, "water_consumption")
		_:
			print("Item %s is not consumable" % item_id)
	
	return consumed

func show_warning(message: String):
	print("WARNING: ", message)
	warning_message.emit(message)

func add_to_inventory(item) -> bool:
	if inventory:
		return inventory.add_item(item)
	return false

func equip_item(equipment: Equipment, slot: String = "") -> bool:
	return EquipmentManager.equip_item(equipment, slot)

func unequip_item(slot: String) -> Equipment:
	return EquipmentManager.unequip_item(slot)

func _connect_to_attribute_manager():
	if has_node("/root/AttributeManager"):
		var attr_mgr = get_node("/root/AttributeManager")
		if attr_mgr and not attr_mgr.attribute_changed.is_connected(_on_attribute_changed):
			attr_mgr.attribute_changed.connect(_on_attribute_changed)
			# Initialize attributes from current player values
			sync_attributes_to_manager()

# AttributeManager integration methods
func sync_attributes_to_manager():
	# Wait for AttributeManager to be ready
	await get_tree().process_frame
	
	if not has_node("/root/AttributeManager"):
		push_warning("AttributeManager not found, skipping sync")
		return
		
	var attr_mgr = get_node("/root/AttributeManager")
	if not attr_mgr:
		return
	
	# Sync current player stats to AttributeManager
	attr_mgr.set_base_attribute("health", health)
	attr_mgr.set_base_attribute("max_health", max_health)
	attr_mgr.set_base_attribute("energy", energy)
	attr_mgr.set_base_attribute("max_energy", max_energy)
	attr_mgr.set_base_attribute("hunger", hunger)
	attr_mgr.set_base_attribute("max_hunger", max_hunger)
	attr_mgr.set_base_attribute("thirst", thirst)
	attr_mgr.set_base_attribute("max_thirst", max_thirst)
	attr_mgr.set_base_attribute("radiation_level", radiation)
	attr_mgr.set_base_attribute("oxygen", oxygen)

func _on_attribute_changed(attribute_name: String, new_value: float, old_value: float):
	# Handle attribute changes from AttributeManager
	match attribute_name:
		"max_health":
			max_health = int(new_value)
			# Clamp current health to new max
			health = min(health, max_health)
			health_changed.emit(health)
		"max_energy":
			max_energy = int(new_value)
			# Clamp current energy to new max
			energy = min(energy, max_energy)
			energy_changed.emit(energy)
		"max_hunger":
			max_hunger = int(new_value)
			hunger = min(hunger, max_hunger)
			hunger_changed.emit(hunger)
		"max_thirst":
			max_thirst = int(new_value)
			thirst = min(thirst, max_thirst)
			thirst_changed.emit(thirst)

# Enhanced damage system with status effects
func take_damage(damage: float, damage_type: String = "physical", source: String = "") -> float:
	# Calculate damage reduction based on attribute system
	var reduced_damage = damage
	if AttributeManager:
		reduced_damage = AttributeManager.calculate_damage_reduction(damage, damage_type)
	else:
		# Fallback damage reduction using basic armor
		if damage_type == "physical":
			reduced_damage = max(damage - (defense * 0.5), 1.0)
	
	# Apply the damage
	modify_health(-int(reduced_damage))
	
	# Apply status effects based on damage type with chance
	if StatusEffectSystem:
		match damage_type.to_lower():
			"fire":
				# Fire damage has chance to cause burning DoT
				if randf() < 0.4:  # 40% chance
					show_warning("Burning!")
					StatusEffectSystem.apply_fire_burn(5.0, 3.0)
			"cold":
				# Cold damage has chance to slow movement
				if randf() < 0.3:  # 30% chance
					show_warning("Freezing!")
					StatusEffectSystem.apply_cold_slow(4.0, 0.6)  # 40% speed reduction
			"shock":
				# Shock damage has chance to stun briefly
				if randf() < 0.15:  # 15% chance
					show_warning("Stunned!")
					StatusEffectSystem.apply_shock_stun(1.5)
			"radiation":
				# Radiation damage increases radiation level and can cause poisoning
				modify_radiation(damage * 0.1)  # 10% of damage becomes radiation
				if randf() < 0.25:  # 25% chance for radiation poisoning
					show_warning("Radiation poisoning!")
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
						show_warning("Equipment malfunction!")
	
	# Grant Environmental Adaptation XP for taking damage
	if has_node("/root/SkillSystem") and reduced_damage > 0:
		var skill_system = get_node("/root/SkillSystem")
		var xp_amount = int(reduced_damage / 5.0) * skill_system.XP_VALUES.ENVIRONMENTAL_DAMAGE_TAKEN
		skill_system.add_xp("ENVIRONMENTAL_ADAPTATION", max(xp_amount, 1), source)
	
	return reduced_damage

func get_combat_stats() -> Dictionary:
	if AttributeManager:
		return AttributeManager.calculate_outgoing_damage()
	else:
		# Fallback for when AttributeManager isn't available
		return {
			"physical": 10.0,
			"fire": 0.0,
			"cold": 0.0,
			"shock": 0.0,
			"critical_chance": 0.05,
			"critical_multiplier": 1.5,
			"armor_penetration": 0.0
		}

# Status effect support methods
func set_input_disabled(disabled: bool):
	input_disabled = disabled
	if disabled:
		velocity = Vector2.ZERO

func apply_speed_modifier(modifier: float):
	temporary_speed_modifiers.append(modifier)

func remove_speed_modifier():
	if not temporary_speed_modifiers.is_empty():
		temporary_speed_modifiers.pop_back()

func calculate_total_speed_modifier() -> float:
	var total = speed_modifier * base_speed_modifier
	for modifier in temporary_speed_modifiers:
		total *= modifier
	return total

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
		"RAD_AWAY":
			if inventory.remove_item(item_id, 1):
				# Reduces radiation instead of healing
				modify_radiation(-25.0)
				print("Radiation reduced!")
				# Grant XP for radiation management
				if has_node("/root/SkillSystem"):
					var skill_system = get_node("/root/SkillSystem")
					skill_system.add_xp("LIFE_SUPPORT", 15, "radiation_treatment")
				return true
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
