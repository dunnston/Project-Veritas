extends Area2D

class_name SceneTransition

signal transition_triggered(target_scene: String, spawn_point: String)

@export var target_scene_path: String = "res://scenes/levels/OuterCity.tscn"
@export var spawn_point_name: String = "from_bedroom"
@export var interaction_text: String = "Press E to go outside"
@export var require_interaction: bool = true
@export var auto_transition_delay: float = 0.5

var player_in_area: bool = false
var player_node: Node2D = null

# UI elements
var interaction_label: Label
var is_showing_prompt: bool = false

func _ready() -> void:
	add_to_group("scene_transitions")
	
	# Set collision mask to detect all layers (fix for detection issues)
	collision_mask = 0xFFFFFFFF  # Detect all 32 collision layers
	monitoring = true  # Ensure monitoring is enabled
	
	# Connect Area2D signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create interaction prompt
	create_interaction_prompt()

func create_interaction_prompt():
	# Create floating text prompt
	interaction_label = Label.new()
	interaction_label.text = interaction_text
	interaction_label.add_theme_color_override("font_color", Color.YELLOW)
	interaction_label.add_theme_font_size_override("font_size", 16)
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.position = Vector2(-75, -40)  # Float above the transition area
	interaction_label.size = Vector2(150, 30)
	interaction_label.visible = false
	add_child(interaction_label)

func _input(event: InputEvent):
	if player_in_area and require_interaction:
		if event.is_action_pressed("interact"):
			trigger_transition()

func _on_body_entered(body: Node2D):
	# Check if it's the player using multiple methods
	var is_player = false
	if body.has_method("collect_resource"):  # Player method check
		is_player = true
	elif body.is_in_group("player"):  # Group check
		is_player = true
	elif "player" in body.name.to_lower():  # Name check
		is_player = true
	
	if is_player:
		player_in_area = true
		player_node = body
		
		if require_interaction:
			show_interaction_prompt()
		else:
			# Auto transition after delay
			get_tree().create_timer(auto_transition_delay).timeout.connect(trigger_transition)

func _on_body_exited(body: Node2D):
	if body == player_node:
		player_in_area = false
		player_node = null
		hide_interaction_prompt()

func show_interaction_prompt():
	if not is_showing_prompt and interaction_label:
		is_showing_prompt = true
		interaction_label.visible = true
		
		# Add subtle pulsing animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(interaction_label, "modulate:a", 0.7, 0.8)
		tween.tween_property(interaction_label, "modulate:a", 1.0, 0.8)

func hide_interaction_prompt():
	if is_showing_prompt and interaction_label:
		is_showing_prompt = false
		interaction_label.visible = false
		
		# Stop any running tweens
		if interaction_label.get_tree():
			var existing_tweens = interaction_label.get_tree().get_nodes_in_group("tweens")
			for tween in existing_tweens:
				if tween is Tween:
					tween.kill()

func trigger_transition():
	if target_scene_path == "":
		print("Error: No target scene path set for transition")
		return
	
	# Hide prompt immediately
	hide_interaction_prompt()
	
	# Emit signal for any listeners
	transition_triggered.emit(target_scene_path, spawn_point_name)
	
	# Use GameManager to handle the actual scene transition
	if GameManager:
		GameManager.change_scene(target_scene_path, spawn_point_name)
	else:
		# Fallback: direct scene change
		get_tree().change_scene_to_file(target_scene_path)

func set_transition_data(scene_path: String, spawn_point: String, prompt_text: String = ""):
	target_scene_path = scene_path
	spawn_point_name = spawn_point
	if prompt_text != "":
		interaction_text = prompt_text
		if interaction_label:
			interaction_label.text = interaction_text

# Debug functions removed - scene transition working properly