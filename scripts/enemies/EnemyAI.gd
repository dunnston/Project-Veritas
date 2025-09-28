extends CharacterBody2D
class_name EnemyAI

enum State { IDLE, DETECTING, CHASING, ATTACKING, DEAD }

@export var max_health: int = 30
@export var move_speed: float = 60.0
@export var detection_radius: float = 150.0
@export var attack_range: float = 30.0
@export var attack_damage: int = 5
@export var attack_cooldown: float = 1.5
@export var knockback_resistance: float = 0.5

var current_health: int
var current_state: State = State.IDLE
var player: Node2D = null
var target_position: Vector2
var is_taking_damage: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO
var can_attack: bool = true
var attack_timer: float = 0.0
var idle_timer: float = 0.0
var idle_direction: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var state_label: Label = $StateLabel

signal died(enemy: Node)
signal damaged(amount: int)
signal state_changed(new_state: State)
signal attacked_player(damage: int)

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health

	setup_components()
	connect_signals()
	update_health_display()
	change_state(State.IDLE)

	print("Enemy AI initialized with %d health" % max_health)

func setup_components() -> void:
	if not sprite:
		sprite = Sprite2D.new()
		add_child(sprite)
		sprite.modulate = Color.RED
		var placeholder_texture = PlaceholderTexture2D.new()
		placeholder_texture.size = Vector2(32, 32)
		sprite.texture = placeholder_texture

	if not health_label:
		health_label = Label.new()
		add_child(health_label)
		health_label.position = Vector2(-20, -40)
		health_label.add_theme_font_size_override("font_size", 12)

	if not state_label:
		state_label = Label.new()
		add_child(state_label)
		state_label.position = Vector2(-30, -55)
		state_label.add_theme_font_size_override("font_size", 10)
		state_label.add_theme_color_override("font_color", Color.YELLOW)

	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(36, 36)  # Larger hitbox for easier combat
		collision_shape.shape = shape
		add_child(collision_shape)

	if not detection_area:
		detection_area = Area2D.new()
		add_child(detection_area)
		var detection_collision = CollisionShape2D.new()
		var detection_shape = CircleShape2D.new()
		detection_shape.radius = detection_radius
		detection_collision.shape = detection_shape
		detection_area.add_child(detection_collision)
		detection_area.collision_layer = 0
		detection_area.collision_mask = 2  # Player layer

	if not attack_area:
		attack_area = Area2D.new()
		add_child(attack_area)
		var attack_collision = CollisionShape2D.new()
		var attack_shape = CircleShape2D.new()
		attack_shape.radius = attack_range
		attack_collision.shape = attack_shape
		attack_area.add_child(attack_collision)
		attack_area.collision_layer = 0
		attack_area.collision_mask = 2  # Player layer

	if not navigation_agent:
		navigation_agent = NavigationAgent2D.new()
		add_child(navigation_agent)
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
		navigation_agent.avoidance_enabled = true
		navigation_agent.radius = 15.0
		navigation_agent.neighbor_distance = 50.0
		navigation_agent.max_neighbors = 10
		navigation_agent.time_horizon_agents = 2.0
		navigation_agent.max_speed = move_speed

func connect_signals() -> void:
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_detection_area_entered):
			detection_area.body_entered.connect(_on_detection_area_entered)
		if not detection_area.body_exited.is_connected(_on_detection_area_exited):
			detection_area.body_exited.connect(_on_detection_area_exited)

	if attack_area:
		if not attack_area.body_entered.is_connected(_on_attack_area_entered):
			attack_area.body_entered.connect(_on_attack_area_entered)
		if not attack_area.body_exited.is_connected(_on_attack_area_exited):
			attack_area.body_exited.connect(_on_attack_area_exited)

	if navigation_agent:
		if not navigation_agent.velocity_computed.is_connected(_on_velocity_computed):
			navigation_agent.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	handle_attack_cooldown(delta)

	match current_state:
		State.IDLE:
			handle_idle_state(delta)
		State.DETECTING:
			handle_detecting_state(delta)
		State.CHASING:
			handle_chasing_state(delta)
		State.ATTACKING:
			handle_attacking_state(delta)

	handle_knockback(delta)
	move_and_slide()

func handle_idle_state(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0:
		idle_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		idle_timer = randf_range(1.0, 3.0)

	velocity = idle_direction * move_speed * 0.3

func handle_detecting_state(_delta: float) -> void:
	if player:
		look_at_player()
		change_state(State.CHASING)

func handle_chasing_state(_delta: float) -> void:
	if not is_instance_valid(player):
		change_state(State.IDLE)
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > detection_radius * 1.5:
		player = null
		change_state(State.IDLE)
		return

	if distance_to_player <= attack_range:
		change_state(State.ATTACKING)
		return

	# Try navigation first, but fall back to direct movement if no navigation map
	if navigation_agent and navigation_agent.get_navigation_map() != RID():
		navigation_agent.target_position = player.global_position

		if not navigation_agent.is_navigation_finished():
			var next_path_position = navigation_agent.get_next_path_position()
			var direction = (next_path_position - global_position).normalized()

			if navigation_agent.avoidance_enabled:
				navigation_agent.set_velocity(direction * move_speed)
			else:
				velocity = direction * move_speed
		else:
			# Navigation finished, use direct movement for final approach
			var direction = (player.global_position - global_position).normalized()
			velocity = direction * move_speed
	else:
		# No navigation map available, use direct movement
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed

func handle_attacking_state(_delta: float) -> void:
	if not is_instance_valid(player):
		change_state(State.IDLE)
		return

	look_at_player()

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > attack_range * 1.2:
		change_state(State.CHASING)
		return

	velocity = velocity.lerp(Vector2.ZERO, 0.1)

	if can_attack:
		perform_attack()

func handle_attack_cooldown(delta: float) -> void:
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			attack_timer = 0.0

func perform_attack() -> void:
	if not is_instance_valid(player):
		return

	can_attack = false
	attack_timer = attack_cooldown

	sprite.modulate = Color(2, 0.5, 0.5)

	if player.has_method("take_damage"):
		player.take_damage(attack_damage, "physical", self)
	else:
		if player.has_method("modify_health"):
			player.modify_health(-attack_damage)

	attacked_player.emit(attack_damage)
	print("Enemy attacked player for %d damage!" % attack_damage)

	await get_tree().create_timer(0.2).timeout
	update_state_visuals()

func handle_knockback(delta: float) -> void:
	if knockback_velocity.length() > 0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)
		if knockback_velocity.length() < 10:
			knockback_velocity = Vector2.ZERO

func look_at_player() -> void:
	if is_instance_valid(player):
		var direction = (player.global_position - global_position).normalized()
		if abs(direction.x) > 0.1:
			sprite.flip_h = direction.x < 0

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	current_state = new_state
	state_changed.emit(new_state)
	update_state_visuals()

	match new_state:
		State.IDLE:
			idle_timer = randf_range(1.0, 3.0)
		State.DETECTING:
			print("Enemy detected player!")
		State.CHASING:
			print("Enemy chasing player!")
		State.ATTACKING:
			print("Enemy attacking player!")

func update_state_visuals() -> void:
	if not sprite:
		return

	match current_state:
		State.IDLE:
			sprite.modulate = Color(0.8, 0.2, 0.2)
			state_label.text = "IDLE"
		State.DETECTING:
			sprite.modulate = Color(1.0, 0.8, 0.2)
			state_label.text = "DETECT"
		State.CHASING:
			sprite.modulate = Color(1.0, 0.4, 0.2)
			state_label.text = "CHASE"
		State.ATTACKING:
			sprite.modulate = Color(1.0, 0.2, 0.2)
			state_label.text = "ATTACK"
		State.DEAD:
			sprite.modulate = Color(0.3, 0.3, 0.3)
			state_label.text = "DEAD"

func take_damage(amount: int, _damage_type: String = "physical", source: Node = null) -> void:
	if is_taking_damage or current_state == State.DEAD:
		return

	is_taking_damage = true
	current_health -= amount
	current_health = max(0, current_health)

	damaged.emit(amount)
	update_health_display()
	show_damage_feedback(amount)

	print("Enemy took %d damage. Health: %d/%d" % [amount, current_health, max_health])

	if current_health <= 0:
		die()
	else:
		if current_state == State.IDLE:
			player = get_tree().get_first_node_in_group("player")
			if player:
				change_state(State.DETECTING)

		await get_tree().create_timer(0.1).timeout
		is_taking_damage = false

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force * (1.0 - knockback_resistance)

func show_damage_feedback(amount: int) -> void:
	var damage_text = Label.new()
	damage_text.text = "-%d" % amount
	damage_text.add_theme_color_override("font_color", Color.RED)
	damage_text.add_theme_font_size_override("font_size", 16)
	damage_text.position = Vector2(-10, -50)
	damage_text.z_index = 100
	add_child(damage_text)

	var text_tween = create_tween()
	text_tween.tween_property(damage_text, "position", Vector2(-10, -70), 0.5)
	text_tween.parallel().tween_property(damage_text, "modulate:a", 0.0, 0.5)
	text_tween.tween_callback(damage_text.queue_free)

func die() -> void:
	change_state(State.DEAD)
	print("Enemy died!")
	died.emit(self)

	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)

	if detection_area:
		detection_area.set_deferred("monitoring", false)
	if attack_area:
		attack_area.set_deferred("monitoring", false)

	var death_tween = create_tween()
	death_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	death_tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.3)
	death_tween.tween_callback(queue_free)

func update_health_display() -> void:
	if health_label:
		health_label.text = "%d/%d" % [current_health, max_health]

		var health_percentage = float(current_health) / float(max_health)
		if health_percentage > 0.6:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif health_percentage > 0.3:
			health_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			health_label.add_theme_color_override("font_color", Color.RED)

func is_dead() -> bool:
	return current_state == State.DEAD

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)

func _on_detection_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and current_state == State.IDLE:
		player = body
		change_state(State.DETECTING)

func _on_detection_area_exited(body: Node2D) -> void:
	if body == player and current_state == State.CHASING:
		var distance = global_position.distance_to(body.global_position)
		if distance > detection_radius * 1.2:
			player = null
			change_state(State.IDLE)

func _on_attack_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and current_state == State.CHASING:
		player = body
		change_state(State.ATTACKING)

func _on_attack_area_exited(body: Node2D) -> void:
	if body == player and current_state == State.ATTACKING:
		change_state(State.CHASING)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
