extends Enemy

class_name PurpleBeast

@export var tongue_attack_range: float = 100.0
@export var staff_damage_multiplier: float = 1.5
@export var special_ability_cooldown: float = 5.0

var can_use_special: bool = true
var special_timer: Timer

func _ready() -> void:
	super._ready()
	
	max_health = 75
	move_speed = 80.0
	attack_damage = 15
	attack_range = tongue_attack_range
	detection_range = 250.0
	
	special_timer = Timer.new()
	special_timer.wait_time = special_ability_cooldown
	special_timer.one_shot = true
	special_timer.timeout.connect(_on_special_cooldown_finished)
	add_child(special_timer)
	
	modulate = Color(0.7, 0.3, 0.9, 1.0)

func attack() -> void:
	if can_use_special and randf() < 0.3:
		tongue_attack()
	else:
		staff_attack()

func tongue_attack() -> void:
	if target and target.has_method("modify_health"):
		target.modify_health(-attack_damage)
		
		if target.has_method("modify_energy"):
			target.modify_energy(-10)
		
		can_use_special = false
		special_timer.start()
		
		if animated_sprite:
			var current_anim = animated_sprite.animation
			animated_sprite.play("tongue_attack")
			await animated_sprite.animation_finished
			animated_sprite.play(current_anim)

func staff_attack() -> void:
	if target and target.has_method("modify_health"):
		var damage = int(attack_damage * staff_damage_multiplier)
		target.modify_health(-damage)
		
		var knockback_direction = (target.global_position - global_position).normalized()
		if target.has_method("apply_knockback"):
			target.apply_knockback(knockback_direction * 200)

func _on_special_cooldown_finished() -> void:
	can_use_special = true

func get_animation_name_for_direction(direction: Direction) -> String:
	var base_name = super.get_animation_name_for_direction(direction)
	
	if not can_use_special:
		return base_name.replace("walk_", "exhausted_")
	
	return base_name