extends RigidBody2D

class_name DroppedResource

signal picked_up(resource_type: String, amount: int)

@export var resource_type: String = "SCRAP_METAL"
@export var amount: int = 1
@export var pickup_radius: float = 32.0
@export var auto_pickup_time: float = 10.0
@export var despawn_time: float = 60.0

var sprite: ColorRect
var collision_shape: CollisionShape2D
var pickup_area: Area2D
var pickup_timer: Timer
var despawn_timer: Timer
var flash_timer: Timer

var is_picked_up: bool = false
var bounce_tween: Tween

func _ready() -> void:
	setup_dropped_resource()
	# Add to interactables group so player can press E to pick up
	add_to_group("interactables")

func setup_dropped_resource():
	# Set physics properties - no gravity for top-down game
	gravity_scale = 0.0  # No gravity in top-down view
	linear_damp = 5.0  # Quick stop after initial spread
	angular_damp = 3.0
	
	# Set collision layer so player can interact with E key
	# Layer 1 (solid) + Layer 8 (interactables) = 1 + 128 = 129
	collision_layer = 129
	
	# Create visual sprite
	sprite = ColorRect.new()
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -8)
	sprite.color = get_resource_color(resource_type)
	add_child(sprite)
	
	# Create collision shape
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Create pickup area
	pickup_area = Area2D.new()
	var pickup_collision = CollisionShape2D.new()
	var pickup_shape = CircleShape2D.new()
	pickup_shape.radius = pickup_radius
	pickup_collision.shape = pickup_shape
	pickup_area.add_child(pickup_collision)
	add_child(pickup_area)
	
	# Connect pickup area signals
	pickup_area.body_entered.connect(_on_body_entered)
	
	# Auto-pickup timer (resource gets automatically collected after delay)
	pickup_timer = Timer.new()
	pickup_timer.wait_time = auto_pickup_time
	pickup_timer.one_shot = true
	pickup_timer.timeout.connect(_auto_pickup)
	add_child(pickup_timer)
	pickup_timer.start()
	
	# Despawn timer (resource disappears if not collected)
	despawn_timer = Timer.new()
	despawn_timer.wait_time = despawn_time
	despawn_timer.one_shot = true
	despawn_timer.timeout.connect(_despawn)
	add_child(despawn_timer)
	despawn_timer.start()
	
	# Flash timer for visual warning near despawn
	flash_timer = Timer.new()
	flash_timer.wait_time = 0.3
	flash_timer.timeout.connect(_flash_warning)
	add_child(flash_timer)
	
	# Start flashing 10 seconds before despawn
	get_tree().create_timer(despawn_time - 10.0).timeout.connect(_start_flashing)
	
	# Add initial bounce effect
	start_bounce_animation()
	
	# Give initial random velocity for physics spread
	var random_force = Vector2(randf_range(-30, 30), randf_range(-40, -10))
	apply_central_impulse(random_force)

func get_resource_color(res_type: String) -> Color:
	# Color code resources for easy identification
	match res_type:
		"WOOD":
			return Color(0.6, 0.4, 0.2)  # Brown
		"STONE":
			return Color(0.7, 0.7, 0.7)  # Gray
		"METAL_SCRAPS":
			return Color(0.9, 0.7, 0.3)  # Metallic yellow
		"SCRAP_METAL":
			return Color(0.6, 0.6, 0.6)  # Dark gray
		_:
			return Color(0.8, 0.8, 0.8)  # Default white

func start_bounce_animation():
	# Subtle bounce animation to make resources more noticeable
	if bounce_tween:
		bounce_tween.kill()
	bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.tween_property(sprite, "position:y", sprite.position.y - 3, 0.8)
	bounce_tween.tween_property(sprite, "position:y", sprite.position.y, 0.8)

func _on_body_entered(body: Node2D):
	if is_picked_up:
		return
	
	# Check if it's the player
	if body.has_method("collect_resource"):
		pickup_resource(body)

# E key interaction method
func interact(player: Node) -> void:
	print("DroppedResource: interact() called via E key for ", resource_type)
	if is_picked_up:
		print("DroppedResource: Already picked up, ignoring E key")
		return
	
	# Check if it's the player
	if player.has_method("collect_resource"):
		pickup_resource(player)
	else:
		print("DroppedResource: Player doesn't have collect_resource method")

func pickup_resource(player: Node2D):
	print("DroppedResource: pickup_resource() called for ", resource_type, " x", amount)
	if is_picked_up:
		print("DroppedResource: Already picked up, ignoring")
		return
	
	is_picked_up = true
	
	# Try to give resource to player
	print("DroppedResource: Trying to give resource to player")
	if player.collect_resource(resource_type, amount):
		print("DroppedResource: Successfully gave resource to player - playing animation")
		# Success - play pickup animation
		play_pickup_animation()
		picked_up.emit(resource_type, amount)
		
		# Cleanup
		pickup_timer.stop()
		despawn_timer.stop()
		flash_timer.stop()
		
		# Remove after animation
		get_tree().create_timer(0.5).timeout.connect(queue_free)
	else:
		# Player inventory full - reset pickup state
		is_picked_up = false
		if player.has_method("show_message"):
			player.show_message("Inventory full!")

func play_pickup_animation():
	# Pickup animation - shrink and fade
	print("DroppedResource: Playing pickup animation for ", resource_type)
	if bounce_tween:
		bounce_tween.kill()
	
	if not sprite:
		print("DroppedResource: ERROR - No sprite found for pickup animation!")
		return
		
	print("DroppedResource: Starting pickup tween animation")
	var pickup_tween = create_tween()
	pickup_tween.set_parallel(true)
	pickup_tween.tween_property(sprite, "scale", Vector2.ZERO, 0.3)
	pickup_tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	pickup_tween.tween_property(sprite, "position:y", sprite.position.y - 20, 0.3)

func _auto_pickup():
	# Find nearby player for auto-pickup
	var bodies = pickup_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("collect_resource"):
			pickup_resource(body)
			return

func _start_flashing():
	if not is_picked_up:
		flash_timer.start()

func _flash_warning():
	if not is_picked_up and sprite:
		# Flash between normal and red to warn of impending despawn
		sprite.modulate = Color.RED if sprite.modulate == Color.WHITE else Color.WHITE

func _despawn():
	if not is_picked_up:
		# Resource disappears with fade animation
		var despawn_tween = create_tween()
		despawn_tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		despawn_tween.tween_callback(queue_free)

func set_resource_data(res_type: String, res_amount: int):
	resource_type = res_type
	amount = res_amount
	if sprite:
		sprite.color = get_resource_color(res_type)