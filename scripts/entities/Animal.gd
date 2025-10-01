## Animal.gd
## Base script for all animal entities
## Handles AI behavior (passive, neutral, aggressive), health, and loot drops
class_name Animal
extends CharacterBody3D

signal died

enum BehaviorType {
	PASSIVE,   ## Runs away when attacked or player approaches
	NEUTRAL,   ## Only attacks when attacked, otherwise avoids player
	AGGRESSIVE ## Attacks player on sight within aggro range
}

## Animal configuration
var animal_name: String = "Animal"
var behavior_type: BehaviorType = BehaviorType.NEUTRAL
var max_health: float = 100.0
var current_health: float = 100.0
var move_speed: float = 5.0
var run_speed: float = 8.0
var aggro_range: float = 10.0
var flee_range: float = 15.0
var attack_range: float = 2.0
var attack_damage: float = 10.0
var attack_cooldown: float = 1.5
var loot_drops: Array[AnimalDrop] = []

## AI State
enum AIState {
	IDLE,
	WANDER,
	FLEE,
	CHASE,
	ATTACK
}

var current_state: AIState = AIState.IDLE
var target_player: Node3D = null
var wander_timer: float = 0.0
var wander_duration: float = 3.0
var idle_timer: float = 0.0
var idle_duration: float = 2.0
var attack_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO

## Physics
const GRAVITY: float = 20.0

func _ready() -> void:
	add_to_group("animals")
	_set_random_idle_time()

func configure_from_template(template: AnimalTemplate) -> void:
	animal_name = template.animal_name
	behavior_type = template.behavior_type
	max_health = template.max_health
	current_health = max_health
	move_speed = template.move_speed
	run_speed = template.run_speed
	aggro_range = template.aggro_range
	flee_range = template.flee_range
	attack_range = template.attack_range
	attack_damage = template.attack_damage
	attack_cooldown = template.attack_cooldown
	loot_drops = template.loot_drops.duplicate()

	# Apply mesh if available
	if template.mesh and has_node("MeshInstance3D"):
		get_node("MeshInstance3D").mesh = template.mesh

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Update AI
	_update_ai(delta)

	# Move
	move_and_slide()

func _update_ai(delta: float) -> void:
	# Find player
	if not target_player:
		target_player = get_tree().get_first_node_in_group("player")

	if not target_player:
		_state_idle(delta)
		return

	var distance_to_player = global_position.distance_to(target_player.global_position)

	# State machine
	match current_state:
		AIState.IDLE:
			_state_idle(delta)
			_check_player_proximity(distance_to_player)

		AIState.WANDER:
			_state_wander(delta)
			_check_player_proximity(distance_to_player)

		AIState.FLEE:
			_state_flee(delta, distance_to_player)

		AIState.CHASE:
			_state_chase(delta, distance_to_player)

		AIState.ATTACK:
			_state_attack(delta, distance_to_player)

func _check_player_proximity(distance: float) -> void:
	match behavior_type:
		BehaviorType.PASSIVE:
			if distance < flee_range:
				_enter_flee_state()

		BehaviorType.NEUTRAL:
			if distance < aggro_range * 0.5: # Only flee if very close
				_enter_flee_state()

		BehaviorType.AGGRESSIVE:
			if distance < aggro_range:
				_enter_chase_state()

func _state_idle(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0

	idle_timer += delta
	if idle_timer >= idle_duration:
		_enter_wander_state()

func _state_wander(delta: float) -> void:
	velocity.x = wander_direction.x * move_speed
	velocity.z = wander_direction.z * move_speed

	wander_timer += delta
	if wander_timer >= wander_duration:
		_enter_idle_state()

func _state_flee(delta: float, distance_to_player: float) -> void:
	if distance_to_player > flee_range * 1.5:
		_enter_idle_state()
		return

	# Run away from player
	var flee_direction = (global_position - target_player.global_position).normalized()
	velocity.x = flee_direction.x * run_speed
	velocity.z = flee_direction.z * run_speed

	# Rotate to face flee direction
	_look_at_direction(flee_direction)

func _state_chase(delta: float, distance_to_player: float) -> void:
	if distance_to_player > aggro_range * 1.5:
		_enter_idle_state()
		return

	if distance_to_player <= attack_range:
		_enter_attack_state()
		return

	# Move toward player
	var chase_direction = (target_player.global_position - global_position).normalized()
	velocity.x = chase_direction.x * run_speed
	velocity.z = chase_direction.z * run_speed

	# Rotate to face player
	_look_at_direction(chase_direction)

func _state_attack(delta: float, distance_to_player: float) -> void:
	# Stop moving
	velocity.x = 0
	velocity.z = 0

	# Face player
	var to_player = (target_player.global_position - global_position).normalized()
	_look_at_direction(to_player)

	# Attack cooldown
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		_perform_attack()
		attack_timer = 0.0

	# Check if player moved out of range
	if distance_to_player > attack_range * 1.5:
		_enter_chase_state()

func _perform_attack() -> void:
	if not target_player or not target_player.has_method("take_damage"):
		return

	# Simple melee attack
	var distance = global_position.distance_to(target_player.global_position)
	if distance <= attack_range:
		target_player.take_damage(attack_damage)

func _look_at_direction(direction: Vector3) -> void:
	if direction.length_squared() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

func _enter_idle_state() -> void:
	current_state = AIState.IDLE
	idle_timer = 0.0
	_set_random_idle_time()

func _enter_wander_state() -> void:
	current_state = AIState.WANDER
	wander_timer = 0.0
	wander_duration = randf_range(2.0, 5.0)
	wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

func _enter_flee_state() -> void:
	current_state = AIState.FLEE

func _enter_chase_state() -> void:
	current_state = AIState.CHASE

func _enter_attack_state() -> void:
	current_state = AIState.ATTACK
	attack_timer = 0.0

func _set_random_idle_time() -> void:
	idle_duration = randf_range(1.0, 4.0)

## Damage handling
func take_damage(amount: float, attacker: Node3D = null) -> void:
	current_health -= amount

	# React to damage based on behavior
	match behavior_type:
		BehaviorType.PASSIVE:
			_enter_flee_state()

		BehaviorType.NEUTRAL:
			if attacker:
				target_player = attacker
			_enter_chase_state()

		BehaviorType.AGGRESSIVE:
			if attacker:
				target_player = attacker
			_enter_chase_state()

	# Check death
	if current_health <= 0:
		_die()

func _die() -> void:
	# Drop loot
	_drop_loot()

	# Emit signal
	died.emit()

	# Remove from scene
	queue_free()

func _drop_loot() -> void:
	for drop in loot_drops:
		# Check drop chance
		if randf() > drop.drop_chance:
			continue

		# Determine quantity
		var quantity = randi_range(drop.min_amount, drop.max_amount)

		# Spawn item pickup
		if drop.item_id and quantity > 0:
			_spawn_item_drop(drop.item_id, quantity)

func _spawn_item_drop(item_id: String, quantity: int) -> void:
	# Use ItemPickup3D similar to resource nodes
	var pickup_scene = preload("res://scenes/items/ItemPickup3D.tscn")
	var pickup = pickup_scene.instantiate()

	pickup.item_id = item_id
	pickup.quantity = quantity
	pickup.global_position = global_position + Vector3.UP * 0.5

	# Add impulse for scatter effect
	get_tree().current_scene.add_child(pickup)
	if pickup is RigidBody3D:
		var random_direction = Vector3(randf_range(-1, 1), 1, randf_range(-1, 1)).normalized()
		pickup.apply_central_impulse(random_direction * 3.0)
