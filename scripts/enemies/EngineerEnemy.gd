extends CharacterBody2D
class_name EngineerEnemy

# Engineer enemy - medium stats, advanced projectiles, drops electronics

@export var max_health: int = 50
@export var move_speed: float = 70.0
@export var damage: int = 12
@export var attack_range: float = 180.0  # Long range
@export var attack_cooldown: float = 2.5  # Slower but powerful attacks
@export var detection_range: float = 200.0
@export var optimal_distance: float = 120.0  # Preferred attack distance

var current_health: int
var target: Node2D = null
var can_attack: bool = true
var state: String = "IDLE"
var attack_timer: float = 0.0
var attack_type: String = "normal"  # normal, burst, electric

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

	# Create visual distinction (tech-looking hexagon)
	setup_visuals()

	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)

	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	print("Engineer Enemy spawned with %d health" % max_health)

func setup_visuals():
	if sprite:
		# Create hexagonal tech pattern
		var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)

		# Draw hexagon pattern
		var center = Vector2(16, 16)
		for x in range(32):
			for y in range(32):
				var pos = Vector2(x, y)
				var distance = pos.distance_to(center)
				if distance <= 14 and distance >= 10:
					image.set_pixel(x, y, Color(0.2, 0.6, 0.8))  # Tech blue
				elif distance <= 10:
					image.set_pixel(x, y, Color(0.1, 0.3, 0.6))  # Darker blue center

		var texture = ImageTexture.new()
		texture.set_image(image)
		sprite.texture = texture

	if collision_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 16.0
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
				print("Engineer detected player - calculating optimal position")

		"POSITIONING":
			if abs(distance_to_target - optimal_distance) <= 20.0:
				if can_attack:
					state = "ATTACKING"
					choose_attack_type()
					perform_attack()
			elif distance_to_target > detection_range * 1.2:
				state = "IDLE"
				target = null

		"ATTACKING":
			if abs(distance_to_target - optimal_distance) > 30.0:
				state = "POSITIONING"

func choose_attack_type():
	var rand = randf()
	if rand < 0.6:
		attack_type = "normal"
	elif rand < 0.85:
		attack_type = "burst"
	else:
		attack_type = "electric"

func handle_movement():
	if not target:
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	if state == "POSITIONING":
		if distance_to_target > optimal_distance + 20:
			# Move closer
			move_towards_target()
		elif distance_to_target < optimal_distance - 20:
			# Move away
			move_away_from_target()
		else:
			# Strafe around target
			strafe_around_target()

func move_towards_target():
	if navigation_agent:
		navigation_agent.target_position = target.global_position
		var next_path_position = navigation_agent.get_next_path_position()
		var direction = (next_path_position - global_position).normalized()
		var desired_velocity = direction * move_speed
		navigation_agent.set_velocity(desired_velocity)
	else:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()

func move_away_from_target():
	var direction = (global_position - target.global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

func strafe_around_target():
	var direction_to_target = (target.global_position - global_position).normalized()
	var perpendicular = Vector2(-direction_to_target.y, direction_to_target.x)

	# Randomly choose left or right strafe
	if randf() > 0.5:
		perpendicular = -perpendicular

	velocity = perpendicular * move_speed * 0.7
	move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func perform_attack():
	if not can_attack or not target:
		return

	can_attack = false
	attack_timer = attack_cooldown

	print("Engineer performs %s attack!" % attack_type)

	# Visual feedback based on attack type
	var flash_color = Color.WHITE
	match attack_type:
		"normal":
			flash_color = Color(0.5, 1.0, 1.5)
		"burst":
			flash_color = Color(1.5, 0.8, 0.5)
		"electric":
			flash_color = Color(1.5, 1.5, 0.5)

	if sprite:
		sprite.modulate = flash_color
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = Color.WHITE

	# Execute attack based on type
	match attack_type:
		"normal":
			fire_normal_projectile()
		"burst":
			fire_burst_projectiles()
		"electric":
			fire_electric_projectile()

func fire_normal_projectile():
	var projectile_system = get_node_or_null("/root/ProjectileSystem")
	if projectile_system:
		var projectile_data = {
			"damage": damage,
			"speed": 250,
			"range": attack_range * 3,
			"projectile_speed": 250
		}
		projectile_system.create_projectile(self, global_position, target.global_position, projectile_data)

func fire_burst_projectiles():
	var projectile_system = get_node_or_null("/root/ProjectileSystem")
	if not projectile_system:
		return

	# Fire 3 projectiles in quick succession
	for i in range(3):
		await get_tree().create_timer(0.1 * i).timeout

		# Add slight spread
		var target_pos = target.global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		var projectile_data = {
			"damage": damage - 2,  # Slightly less damage per projectile
			"speed": 300,
			"range": attack_range * 3,
			"projectile_speed": 300
		}
		projectile_system.create_projectile(self, global_position, target_pos, projectile_data)

func fire_electric_projectile():
	var projectile_system = get_node_or_null("/root/ProjectileSystem")
	if projectile_system:
		var projectile_data = {
			"damage": damage + 5,  # Higher damage
			"speed": 180,  # Slower but more powerful
			"range": attack_range * 4,
			"projectile_speed": 180,
			"effect": "electric"  # Special effect
		}
		projectile_system.create_projectile(self, global_position, target.global_position, projectile_data)

func take_damage(damage_amount: int, damage_type: String = "physical", source: Node = null):
	current_health -= damage_amount
	print("Engineer took %d damage, health: %d/%d" % [damage_amount, current_health, max_health])

	if health_bar:
		health_bar.value = current_health

	# Visual damage feedback
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = Color.WHITE

	# Engineers become more aggressive when damaged
	if current_health <= max_health * 0.3:
		attack_cooldown = 1.5  # Faster attacks when low health
		print("Engineer enters emergency mode!")

	if current_health <= 0:
		die()

func die():
	print("Engineer Enemy defeated!")

	# Emit death signal for loot system
	enemy_died.emit("Engineer", global_position)

	# Tech explosion effect
	create_tech_explosion()

	# Death visual effect
	if sprite:
		sprite.modulate = Color.CYAN
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func create_tech_explosion():
	# Create sparks effect for engineer death
	for i in range(8):
		var spark = Node2D.new()
		var spark_sprite = Sprite2D.new()

		# Create spark texture
		var image = Image.create(3, 3, false, Image.FORMAT_RGBA8)
		image.fill(Color.CYAN)
		var texture = ImageTexture.new()
		texture.set_image(image)

		spark_sprite.texture = texture
		spark.add_child(spark_sprite)
		spark.global_position = global_position

		get_parent().add_child(spark)

		# Random direction for sparks
		var angle = (i / 8.0) * TAU + randf_range(-0.3, 0.3)
		var direction = Vector2(cos(angle), sin(angle))
		var distance = randf_range(30, 80)

		var tween = create_tween()
		tween.tween_property(spark, "global_position", spark.global_position + direction * distance, 0.8)
		tween.parallel().tween_property(spark_sprite, "modulate:a", 0.0, 0.8)
		tween.tween_callback(spark.queue_free)

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
