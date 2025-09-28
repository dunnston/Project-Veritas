extends Area2D
class_name ResourcePickup

@export var resource_type: String = "WOOD"
@export var resource_amount: int = 1
@export var pickup_name: String = "Resource"
@export var auto_pickup: bool = true
@export var respawn_time: float = 0.0  # 0 = no respawn

var can_pickup: bool = true
var player_nearby: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

signal picked_up(resource_type: String, amount: int)

func _ready() -> void:
	add_to_group("pickups")
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_entered)
		interaction_area.body_exited.connect(_on_interaction_exited)
	
	# Floating animation
	_create_float_animation()

func _create_float_animation() -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "position:y", sprite.position.y - 2, 1.0)
	tween.tween_property(sprite, "position:y", sprite.position.y + 2, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if auto_pickup and can_pickup and body.is_in_group("player"):
		_pickup(body)

func _on_interaction_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true
		_show_interaction_hint()

func _on_interaction_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false
		_hide_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not auto_pickup and player_nearby and can_pickup:
		if event.is_action_pressed("interact"):
			var player = get_tree().get_first_node_in_group("player")
			if player:
				_pickup(player)

func _pickup(player: Node2D) -> void:
	if not can_pickup:
		return
	
	can_pickup = false
	
	# Play pickup animation on player if supported
	if player.has_method("play_pickup_animation"):
		player.play_pickup_animation()
	
	# Emit to EventBus
	EventBus.emit_resource_collected(resource_type, resource_amount)
	
	# Emit local signal
	picked_up.emit(resource_type, resource_amount)
	
	# Visual feedback
	_play_pickup_effect()
	
	# Handle respawn or removal
	if respawn_time > 0:
		_start_respawn()
	else:
		queue_free()

func _play_pickup_effect() -> void:
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	
	if respawn_time > 0:
		visible = false
	else:
		queue_free()

func _start_respawn() -> void:
	visible = false
	
	await get_tree().create_timer(respawn_time).timeout
	
	visible = true
	sprite.modulate.a = 1.0
	sprite.scale = Vector2.ONE
	can_pickup = true
	
	# Respawn effect
	var tween = create_tween()
	sprite.modulate.a = 0.0
	tween.tween_property(sprite, "modulate:a", 1.0, 0.3)

func _show_interaction_hint() -> void:
	# Show "Press E to pickup" hint
	if not auto_pickup:
		# You can emit a signal here to show UI hint
		pass

func _hide_interaction_hint() -> void:
	# Hide interaction hint
	if not auto_pickup:
		# You can emit a signal here to hide UI hint
		pass