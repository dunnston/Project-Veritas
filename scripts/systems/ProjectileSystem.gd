extends Node

signal projectile_hit(projectile: Node, target: Node, damage: int)
signal projectile_destroyed(projectile: Node)

var active_projectiles: Array[Node] = []
var projectile_scene: PackedScene

func _ready() -> void:
	add_to_group("projectile_system")
	print("Projectile System initialized")

func create_projectile(shooter: Node, start_pos: Vector3, target_pos: Vector3, weapon_data: Dictionary) -> Node:
	var projectile = Projectile.new()
	projectile.setup(shooter, start_pos, target_pos, weapon_data)

	get_tree().current_scene.add_child(projectile)
	active_projectiles.append(projectile)

	# Connect signals
	projectile.hit_target.connect(_on_projectile_hit)
	projectile.destroyed.connect(_on_projectile_destroyed)

	return projectile

func _on_projectile_hit(projectile: Node, target: Node, damage: int) -> void:
	projectile_hit.emit(projectile, target, damage)

func _on_projectile_destroyed(projectile: Node) -> void:
	active_projectiles.erase(projectile)
	projectile_destroyed.emit(projectile)

func clear_all_projectiles() -> void:
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()

func get_active_projectile_count() -> int:
	return active_projectiles.size()
