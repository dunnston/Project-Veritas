extends CharacterBody2D
class_name BasicEnemy

@export var max_health: int = 30
@export var knockback_resistance: float = 0.5

var current_health: int
var is_taking_damage: bool = false
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_label: Label = $HealthLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal died(enemy: Node)
signal damaged(amount: int)

func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health

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

	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(36, 36)  # Larger hitbox for easier combat
		collision_shape.shape = shape
		add_child(collision_shape)

	update_health_display()
	print("Enemy spawned with %d health" % max_health)

func _physics_process(delta: float) -> void:
	if knockback_velocity.length() > 0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10 * delta)
		if knockback_velocity.length() < 10:
			knockback_velocity = Vector2.ZERO

	move_and_slide()

func take_damage(amount: int, damage_type: String = "physical", source: Node = null) -> void:
	if is_taking_damage:
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
		await get_tree().create_timer(0.1).timeout
		is_taking_damage = false

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force * (1.0 - knockback_resistance)

func show_damage_feedback(amount: int) -> void:
	if sprite:
		sprite.modulate = Color.WHITE

		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color(0.5, 0, 0), 0.1)

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
	print("BasicEnemy died!")
	died.emit(self)

	# Drop loot
	if LootSystem:
		LootSystem.create_loot_drop("BasicEnemy", global_position)

	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)

	if sprite:
		var death_tween = create_tween()
		death_tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		death_tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.3)
		death_tween.tween_callback(queue_free)
	else:
		queue_free()

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
	return current_health <= 0

func get_health_percentage() -> float:
	return float(current_health) / float(max_health)
