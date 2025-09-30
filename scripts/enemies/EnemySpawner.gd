extends Node3D

class_name EnemySpawner

@export var spawn_radius: float = 300.0
@export var spawn_interval: float = 10.0
@export var max_enemies: int = 5

var spawn_timer: Timer
var current_enemy_count: int = 0
var purple_beast_scene = preload("res://scenes/enemies/PurpleBeast.tscn")

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timer_timeout() -> void:
	if current_enemy_count < max_enemies:
		spawn_purple_beast()

func spawn_purple_beast() -> void:
	var beast = purple_beast_scene.instantiate()

	var angle = randf() * TAU
	var distance = randf_range(50, spawn_radius)
	var spawn_position = global_position + Vector3(
		cos(angle) * distance,
		0,  # Y stays at current spawner height
		sin(angle) * distance
	)

	beast.global_position = spawn_position
	beast.died.connect(_on_enemy_died)

	get_parent().add_child(beast)
	current_enemy_count += 1

func _on_enemy_died() -> void:
	current_enemy_count -= 1
