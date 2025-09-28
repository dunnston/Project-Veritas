extends Area2D
class_name HandCrankGenerator

signal generator_used()

var is_player_nearby: bool = false
var interaction_prompt: Label
var can_use: bool = false
var uses_remaining: int = 0  # How many times it can be used

# Generator stats
const POWER_DURATION_GAME_HOURS: float = 4.0  # 4 game hours
const POWER_DURATION_GAME_SECONDS: float = 14400.0  # 4 game hours in game seconds (4 * 60 * 60)
const MAX_USES: int = 10  # Can be used multiple times before breaking

func _ready():
	print("HandCrankGenerator: Initializing...")
	add_to_group("hand_crank_generators")
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	interaction_prompt = get_node("InteractionPrompt")
	interaction_prompt.visible = false
	
	# Check if we have a hand crank generator in inventory to activate this
	check_activation_status()

func _input(event):
	if is_player_nearby and can_use and event.is_action_pressed("interact"):
		use_generator()

func _on_body_entered(body):
	if body.is_in_group("player"):
		is_player_nearby = true
		check_activation_status()

func _on_body_exited(body):
	if body.is_in_group("player"):
		is_player_nearby = false
		interaction_prompt.visible = false

func check_activation_status():
	# Check if player has hand crank generator in inventory
	var has_generator = InventorySystem.has_item("HAND_CRANK_GENERATOR", 1)
	var emergency_active = false
	
	# Check if emergency is active
	var emergency_system = get_tree().get_first_node_in_group("emergency_system")
	if emergency_system:
		emergency_active = emergency_system.emergency_active
	
	can_use = has_generator and emergency_active and uses_remaining > 0
	
	if is_player_nearby:
		if not has_generator:
			interaction_prompt.text = "Requires Hand Crank Generator"
			interaction_prompt.visible = true
		elif not emergency_active:
			interaction_prompt.text = "No emergency power needed"
			interaction_prompt.visible = true
		elif uses_remaining <= 0:
			interaction_prompt.text = "Generator is broken"
			interaction_prompt.visible = true
		else:
			interaction_prompt.text = "[E] Crank Generator (+4 game hours)"
			interaction_prompt.visible = true

func activate_generator():
	"""Called when hand crank generator is built"""
	uses_remaining = MAX_USES
	print("HandCrankGenerator: Activated with ", MAX_USES, " uses remaining")
	check_activation_status()

func use_generator():
	if not can_use:
		return
		
	print("HandCrankGenerator: Cranking generator for emergency power!")
	
	# Add 4 game hours to the emergency timer
	var emergency_system = get_tree().get_first_node_in_group("emergency_system")
	if emergency_system:
		emergency_system.add_emergency_time(POWER_DURATION_GAME_SECONDS)
		
	# Decrease uses
	uses_remaining -= 1
	
	# Show feedback
	show_usage_feedback()
	
	# Update prompt
	check_activation_status()
	
	generator_used.emit()

func show_usage_feedback():
	var feedback_label = Label.new()
	feedback_label.text = "+4 GAME HOURS EMERGENCY POWER"
	feedback_label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))  # Bright green
	feedback_label.add_theme_font_size_override("font_size", 18)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.position = Vector2(-100, -80)
	feedback_label.size = Vector2(200, 30)
	
	add_child(feedback_label)
	
	# Animate feedback
	var tween = create_tween()
	tween.tween_property(feedback_label, "position", Vector2(-100, -120), 2.0)
	tween.parallel().tween_property(feedback_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(func(): feedback_label.queue_free())

func get_uses_remaining() -> int:
	return uses_remaining