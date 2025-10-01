extends RigidBody3D
class_name Projectile

@export var speed: float = 300.0
@export var max_range: float = 500.0
@export var damage: int = 10
@export var lifetime: float = 3.0

var shooter: Node = null
var target_position: Vector3
var start_position: Vector3
var direction: Vector3
var distance_traveled: float = 0.0
var weapon_data: Dictionary

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D

signal hit_target(projectile: Node, target: Node, damage: int)
signal destroyed(projectile: Node)

func setup(p_shooter: Node, start_pos: Vector3, target_pos: Vector3, p_weapon_data: Dictionary) -> void:
	shooter = p_shooter
	start_position = start_pos
	target_position = target_pos
	weapon_data = p_weapon_data

	global_position = start_pos
	direction = (target_pos - start_pos).normalized()

	# Apply weapon-specific properties
	if weapon_data.has("projectile_speed"):
		speed = weapon_data.projectile_speed
	if weapon_data.has("range"):
		max_range = weapon_data.range
	if weapon_data.has("damage"):
		damage = weapon_data.damage

	# Set up physics
	gravity_scale = 0
	# Disable continuous collision detection for now (was causing constant errors)
	# continuous_cd = RigidBody3D.CCD_MODE_CAST_SHAPE

	# Set up collision layers
	collision_layer = 64  # Projectile layer (bit 6)
	collision_mask = 1 + 2 + 16  # World + Player + Enemies

	# Set initial velocity
	linear_velocity = direction * speed

	# Rotate to face direction (3D)
	look_at(global_position + direction, Vector3.UP)

	setup_visuals()

	# Timer will be set up in _ready() when node is in tree

func setup_visuals() -> void:
	# Create 3D mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

	# Create a simple projectile mesh (small sphere)
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	mesh_instance.mesh = sphere_mesh

	# Create a red material for projectiles
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED
	material.emission_energy = 0.5
	mesh_instance.material_override = material

	# Create 3D collision shape
	collision_shape = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.05  # Small sphere collision
	collision_shape.shape = shape
	add_child(collision_shape)

	# TODO: Add 3D trail effect if needed

func _ready() -> void:
	# Ensure we're set up as a RigidBody3D properly
	set_contact_monitor(true)
	set_max_contacts_reported(10)

	body_entered.connect(_on_body_entered)
	add_to_group("projectiles")

	# Initialize child nodes if they don't exist (for scene instantiation)
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
	# Trail effects disabled for now - was causing 2D/3D compatibility issues
	# if not trail:
	#	trail = get_node_or_null("Trail")

	# Set up auto-destroy timer
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()

func _physics_process(delta: float) -> void:
	# Update distance traveled
	distance_traveled = start_position.distance_to(global_position)

	# Check if exceeded range
	if distance_traveled > max_range:
		destroy_projectile()
		return

	# Trail effects disabled for now - was causing 2D/3D compatibility issues
	# if trail and trail.get_point_count() < 10:
	#	trail.add_point(-direction * distance_traveled * 0.1)

func _on_body_entered(body: Node) -> void:
	# Use call_deferred to handle collision safely
	call_deferred("_handle_collision_deferred", body)

func _handle_collision_deferred(body: Node) -> void:
	# Validate body is still valid after deferring
	if not is_instance_valid(body):
		return

	# Don't hit the shooter
	if body == shooter:
		return

	# Simple collision handling without complex validation
	var should_damage = true
	var is_enemy_or_player = false

	# Try to check groups, but fail safely
	if body.has_method("is_in_group"):
		var is_enemy = body.is_in_group("enemies")
		var is_animal = body.is_in_group("animals")
		var is_player = body.is_in_group("player")
		is_enemy_or_player = is_enemy or is_animal or is_player

		# Basic friendly fire check - enemies don't damage enemies
		if shooter and shooter.has_method("is_in_group"):
			if shooter.is_in_group("enemies") and is_enemy:
				should_damage = false

	# Handle collision
	if is_enemy_or_player and should_damage:
		hit_target.emit(self, body, damage)

		# Apply damage through combat system
		if has_node("/root/CombatSystem"):
			var combat_system = get_node("/root/CombatSystem")
			combat_system.deal_damage(shooter, body, damage, "ranged")

		create_hit_effect()
		destroy_projectile()

	elif body.collision_layer & 1:  # World collision
		create_impact_effect()
		destroy_projectile()

func is_friendly_fire(attacker: Node, target: Node) -> bool:
	"""Check if this would be friendly fire (same team attacking same team)"""
	# Simplified safe version
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return false

	# Basic check without complex validation
	if attacker.has_method("is_in_group") and target.has_method("is_in_group"):
		return attacker.is_in_group("enemies") and target.is_in_group("enemies")

	return false

func create_hit_effect() -> void:
	# Visual hit effect without text spam
	# Could add particle effects or flash here instead
	pass

func create_impact_effect() -> void:
	# Create 3D impact effect for world collision
	# TODO: Replace with 3D particle effect or 3D label when UI system is ready
	# For now, just print to console to avoid 2D/3D compatibility issues
	print("Projectile impact at: ", global_position)

func _on_lifetime_expired() -> void:
	destroy_projectile()

func destroy_projectile() -> void:
	destroyed.emit(self)
	queue_free()

func get_shooter() -> Node:
	return shooter

func get_damage() -> int:
	return damage

func get_weapon_data() -> Dictionary:
	return weapon_data
