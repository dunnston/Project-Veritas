extends Node

signal damage_dealt(attacker: Node, target: Node, amount: int)
signal enemy_killed(enemy: Node, killer: Node)

@export var base_melee_damage: int = 10
@export var melee_knockback_force: float = 200.0

var combat_log: Array = []

func _ready() -> void:
	add_to_group("combat_system")
	print("Combat System initialized")

func deal_damage(attacker: Node, target: Node, damage: int, damage_type: String = "physical") -> void:
	if not is_instance_valid(target):
		return

	# Check for friendly fire - enemies shouldn't damage other enemies
	if is_friendly_fire(attacker, target):
		return

	if target.has_method("take_damage"):
		target.take_damage(damage, damage_type, attacker)
		damage_dealt.emit(attacker, target, damage)

		var log_entry = {
			"time": Time.get_ticks_msec(),
			"attacker": attacker.name if attacker else "Unknown",
			"target": target.name,
			"damage": damage,
			"type": damage_type
		}
		combat_log.append(log_entry)

		if target.has_method("is_dead") and target.is_dead():
			enemy_killed.emit(target, attacker)
			print("%s killed %s!" % [attacker.name if attacker else "Unknown", target.name])

func apply_knockback(source: Node, target: Node, force: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(source):
		return

	if target.has_method("apply_knockback"):
		var direction = (target.global_position - source.global_position).normalized()
		target.apply_knockback(direction * force)

func calculate_melee_damage(attacker: Node) -> int:
	var damage = base_melee_damage

	if attacker.has_method("get_damage_modifier"):
		damage = int(damage * attacker.get_damage_modifier())

	return damage

func get_recent_combat_log(count: int = 10) -> Array:
	var start_idx = max(0, combat_log.size() - count)
	return combat_log.slice(start_idx, combat_log.size())

func is_friendly_fire(attacker: Node, target: Node) -> bool:
	"""Check if this would be friendly fire (same team attacking same team)"""
	# Validate both nodes are still valid
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false

	# Enemies shouldn't damage other enemies
	if attacker.is_in_group("enemies") and target.is_in_group("enemies"):
		return true

	# Player attacks on enemies are allowed (not friendly fire)
	# Enemy attacks on player are allowed (not friendly fire)
	return false

func clear_combat_log() -> void:
	combat_log.clear()
