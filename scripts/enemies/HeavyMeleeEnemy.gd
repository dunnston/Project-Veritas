extends CharacterBody2D
class_name HeavyMeleeEnemy

# Heavy melee enemy - slower but stronger with more health

@export var max_health: int = 80
@export var move_speed: float = 40.0  # Slower than basic enemy
@export var damage: int = 15  # Higher damage
@export var attack_range: float = 45.0
@export var attack_cooldown: float = 2.0  # Slower attacks
@export var detection_range: float = 150.0

var current_health: int
var target: Node2D = null
var can_attack: bool = true
var state: String = "IDLE"
var attack_timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D

signal enemy_died(enemy_type: String, position: Vector2)

func _ready():
	# Set up enemy
	current_health = max_health
	add_to_group("enemies")

	# Connect to loot system
	if LootSystem:
		enemy_died.connect(LootSystem.create_loot_drop)

	# Create visual distinction (larger, darker rectangle)
	call_deferred("setup_visuals")

	# Set up navigation
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)

	# Set up health bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	print("Heavy Melee Enemy spawned with %d health" % max_health)

func setup_visuals():
	if sprite:
		# Create larger, darker texture to distinguish from basic enemy
		var image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.3, 0.1, 0.1))  # Dark red
		var texture = ImageTexture.new()
		texture.set_image(image)
		sprite.texture = texture

	# Set up collision
	if collision_shape:
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(40, 40)
		collision_shape.shape = rect_shape

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
	# Find player target
	target = get_tree().get_first_node_in_group("player")

	if not target:
		state = "IDLE"
		return

	var distance_to_target = global_position.distance_to(target.global_position)

	match state:
		"IDLE":
			if distance_to_target <= detection_range:
				state = "CHASING"
				print("Heavy enemy detected player")

		"CHASING":
			if distance_to_target <= attack_range and can_attack:
				state = "ATTACKING"
				perform_attack()
			elif distance_to_target > detection_range * 1.2:
				state = "IDLE"
				target = null

		"ATTACKING":
			if distance_to_target > attack_range:
				state = "CHASING"

func handle_movement():
	if state == "CHASING" and target:
		# Heavy enemies move slower but more deliberately
		if navigation_agent:
			navigation_agent.target_position = target.global_position
			var next_path_position = navigation_agent.get_next_path_position()
			var direction = (next_path_position - global_position).normalized()
			var desired_velocity = direction * move_speed
			navigation_agent.set_velocity(desired_velocity)
		else:
			# Fallback direct movement
			var direction = (target.global_position - global_position).normalized()
			velocity = direction * move_speed
			move_and_slide()

func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()

func perform_attack():
	if not can_attack or not target:
		return

	can_attack = false
	attack_timer = attack_cooldown

	print("Heavy enemy performs powerful attack!")

	# Visual feedback - flash red
	if sprite:
		sprite.modulate = Color(2.0, 0.5, 0.5)
		await get_tree().create_timer(0.3).timeout
		if sprite:
			sprite.modulate = Color.WHITE

	# Deal damage to player if in range
	if not target:
		return
	var distance_to_target = global_position.distance_to(target.global_position)
	if distance_to_target <= attack_range:
		var combat_system = get_node_or_null("/root/CombatSystem")
		if combat_system:
			combat_system.deal_damage(self, target, damage, "melee")
			# Heavy knockback
			combat_system.apply_knockback(self, target, 200.0)

func take_damage(damage_amount: int, damage_type: String = "physical", source: Node = null):
	current_health -= damage_amount
	print("Heavy enemy took %d damage, health: %d/%d" % [damage_amount, current_health, max_health])

	# Update health bar
	if health_bar:
		health_bar.value = current_health

	# Visual damage feedback
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if sprite:
			sprite.modulate = Color.WHITE

	# Check for death
	if current_health <= 0:
		die()

func die():
	print("Heavy Melee Enemy defeated!")

	# Emit death signal for loot system
	enemy_died.emit("HeavyMelee", global_position)

	# Death visual effect
	if sprite:
		sprite.modulate = Color.RED
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
