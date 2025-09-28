extends CharacterBody2D

class_name Enemy

signal health_changed(new_health: int)
signal died()

enum Direction {
	SOUTH,
	SOUTHWEST, 
	WEST,
	NORTHWEST,
	NORTH,
	NORTHEAST,
	EAST,
	SOUTHEAST
}

@export var max_health: int = 50
@export var move_speed: float = 100.0
@export var attack_damage: int = 10
@export var attack_range: float = 50.0
@export var detection_range: float = 200.0

var health: int
var current_direction: Direction = Direction.SOUTH
var target: Node2D = null
var animated_sprite: AnimatedSprite2D

func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	animated_sprite = get_node_or_null("AnimatedSprite2D")
	
func _physics_process(delta: float) -> void:
	if target and is_instance_valid(target):
		move_toward_target(delta)
	else:
		find_target()
	
	move_and_slide()
	update_animation()

func move_toward_target(delta: float) -> void:
	var direction = (target.global_position - global_position).normalized()
	velocity = direction * move_speed
	
	var distance = global_position.distance_to(target.global_position)
	if distance <= attack_range:
		attack()

func find_target() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) <= detection_range:
		target = player

func attack() -> void:
	if target and target.has_method("modify_health"):
		target.modify_health(-attack_damage)

func take_damage(damage: int, damage_type: String = "physical", attacker: Node = null) -> void:
	health = max(health - damage, 0)
	health_changed.emit(health)

	if health <= 0:
		die()

func die() -> void:
	died.emit()
	queue_free()

func update_animation() -> void:
	if not animated_sprite or velocity.length() == 0:
		return
	
	var angle = velocity.angle()
	var direction_index = int((angle + PI + PI/8) / (PI/4)) % 8
	current_direction = direction_index as Direction
	
	var animation_name = get_animation_name_for_direction(current_direction)
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)

func get_animation_name_for_direction(direction: Direction) -> String:
	match direction:
		Direction.SOUTH:
			return "walk_south"
		Direction.SOUTHWEST:
			return "walk_southwest"
		Direction.WEST:
			return "walk_west"
		Direction.NORTHWEST:
			return "walk_northwest"
		Direction.NORTH:
			return "walk_north"
		Direction.NORTHEAST:
			return "walk_northeast"
		Direction.EAST:
			return "walk_east"
		Direction.SOUTHEAST:
			return "walk_southeast"
		_:
			return "walk_south"