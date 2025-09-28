extends CharacterBody2D
class_name ScoutEnemy

# Scout enemy - fast, low health, drops ammunition

@export var max_health: int = 25
@export var move_speed: float = 120.0  # Much faster than basic enemy
@export var damage: int = 8
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 1.2
@export var detection_range: float = 200.0
@export var retreat_distance: float = 60.0  # Maintains distance

var current_health: int
var target: Node2D = null
var can_attack: bool = true
var state: String = "IDLE"
var attack_timer: float = 0.0
var last_direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

signal enemy_died(enemy_type: String, position: Vector2)

func _ready():
	current_health = max_health
	add_to_group("enemies")

	# Connect to loot system
	if LootSystem:
		enemy_died.connect(LootSystem.create_loot_drop)

	# Create visual distinction (small, fast-looking diamond)
	call_deferred("setup_visuals")

	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	print("Scout Enemy spawned with %d health" % max_health)

func setup_visuals():
	if sprite:
		# Create diamond/triangle shape for scout
		var image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		# Draw diamond pattern
		for x in range(24):
			for y in range(24):
				var center_x = 12
				var center_y = 12
				var distance = abs(x - center_x) + abs(y - center_y)
				if distance <= 10:
					image.set_pixel(x, y, Color(0.8, 0.8, 0.2))  # Yellow/gold

		var texture = ImageTexture.new()
		texture.set_image(image)
		sprite.texture = texture

	if collision_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 12.0
		collision_shape.shape = circle_shape

func _physics_process(delta):
	handle_attack_timer(delta)
	update_ai()
	handle_movement()

func handle_attack_timer(delta):
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true

func update_ai():
	target = get_tree().get_first_node_in_group("player")

	if not target:
		state = "IDLE"
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	match state:
		"IDLE":
			if distance_to_target <= detection_range:
				state = "POSITIONING"
				print("Scout detected player - moving to attack position")

		"POSITIONING":
			if distance_to_target <= attack_range and distance_to_target >= retreat_distance:
				if can_attack:
					state = "ATTACKING"
					perform_attack()
			elif distance_to_target < retreat_distance:
				state = "RETREATING"
			elif distance_to_target > detection_range * 1.2:
				state = "IDLE"
				target = null

		"ATTACKING":
			if distance_to_target < retreat_distance:
				state = "RETREATING"
			elif distance_to_target > attack_range:
				state = "POSITIONING"

		"RETREATING":
			if distance_to_target >= retreat_distance:
				state = "POSITIONING"

func handle_movement():
	if not target:
		return

	var distance_to_target = global_position.distance_to(target.global_position)
	var direction_to_target = (target.global_position - global_position).normalized()

	match state:
		"POSITIONING":
			# Move to optimal attack range
			if distance_to_target > attack_range:
				move_towards_target(direction_to_target)
			elif distance_to_target < retreat_distance:
				move_away_from_target(direction_to_target)

		"RETREATING":
			# Move away from target while staying in detection range
			move_away_from_target(direction_to_target)

		"ATTACKING":
			# Stay in position while attacking
			velocity = Vector2.ZERO
			move_and_slide()

func move_towards_target(direction: Vector2):
	if navigation_agent:
		navigation_agent.target_position = target.global_position
		var next_path_position = navigation_agent.get_next_path_position()
		var nav_direction = (next_path_position - global_position).normalized()
		var desired_velocity = nav_direction * move_speed
		navigation_agent.set_velocity(desired_velocity)
	else:
		velocity = direction * move_speed
		move_and_slide()

func move_away_from_target(direction: Vector2):
	# Move away from target with some randomness
	var retreat_direction = -direction
	var random_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	var final_direction = (retreat_direction + random_offset).normalized()

	velocity = final_direction * move_speed
	move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func perform_attack():
	if not can_attack or not target:
		return

	can_attack = false
	attack_timer = attack_cooldown

	print("Scout performs quick ranged attack!")

	# Visual feedback - quick flash
	if sprite:
		sprite.modulate = Color(1.5, 1.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

	# Create projectile (scouts use basic projectiles)
	var projectile_system = get_node_or_null("/root/ProjectileSystem")
	if projectile_system:
		var projectile_data = {
			"damage": damage,
			"speed": 300,
			"range": 400,
			"projectile_speed": 300
		}
		projectile_system.create_projectile(self, global_position, target.global_position, projectile_data)

func take_damage(damage_amount: int, damage_type: String = "physical", source: Node = null):
	current_health -= damage_amount
	print("Scout took %d damage, health: %d/%d" % [damage_amount, current_health, max_health])

	if health_bar:
		health_bar.value = current_health

	# Visual damage feedback
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

	# Scouts retreat when damaged
	if current_health > 0 and state != "RETREATING":
		state = "RETREATING"
		print("Scout retreats after taking damage!")

	if current_health <= 0:
		die()

func die():
	print("Scout Enemy defeated!")

	# Emit death signal for loot system
	enemy_died.emit("Scout", global_position)

	# Death visual effect
	if sprite:
		sprite.modulate = Color.YELLOW
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
