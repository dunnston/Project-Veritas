extends Area2D
class_name MetalScrapPickup

@export var resource_name: String = "METAL_SCRAPS"
@export var amount: int = 1

@onready var interaction_prompt: Sprite2D = $InteractionPrompt
@onready var sprite: Sprite2D = $Sprite2D

var player_in_range: bool = false
var player_ref: Node2D = null

signal collected(resource_name: String, amount: int)

func _ready() -> void:
	# Ensure prompt is hidden initially
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Add a subtle floating animation to the item
	_add_floating_animation()

func _input(event: InputEvent) -> void:
	# Check for E key press when player is in range
	if player_in_range and event is InputEventKey and event.pressed:
		if event.keycode == KEY_E:
			_collect_item()

func _on_interaction_area_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		_show_interaction_prompt()

func _on_interaction_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		_hide_interaction_prompt()

func _show_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.visible = true
		# Add a subtle bob animation to the prompt
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(interaction_prompt, "position:y", -25.0, 0.5)
		tween.tween_property(interaction_prompt, "position:y", -20.0, 0.5)

func _hide_interaction_prompt() -> void:
	if interaction_prompt:
		interaction_prompt.visible = false

func _collect_item() -> void:
	if not player_in_range:
		return
	
	print("Metal scrap collected!")
	
	# Add to inventory using new InventorySystem
	if InventorySystem:
		var success = InventorySystem.add_item(resource_name, amount)
		if not success:
			print("Failed to add item to inventory - may be full")
			return
	
	# Play pickup animation on player if they have the method
	if player_ref and player_ref.has_method("play_pickup_animation"):
		player_ref.play_pickup_animation()
	
	# Emit signal for tutorial or other systems
	collected.emit(resource_name, amount)
	
	# Visual feedback before removing
	_play_collection_animation()

func _play_collection_animation() -> void:
	# Disable further interaction
	player_in_range = false
	set_process_input(false)
	
	# Hide prompt immediately
	if interaction_prompt:
		interaction_prompt.visible = false
	
	# Animate the sprite
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(queue_free)

func _add_floating_animation() -> void:
	if sprite:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(sprite, "position:y", 2.0, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", -2.0, 1.0).set_trans(Tween.TRANS_SINE)