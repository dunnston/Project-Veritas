extends Area2D
class_name OxygenTankBuilding

var player_in_range: bool = false
var player_ref: Node2D = null
var interaction_prompt: Label = null

# Oxygen tank state
var is_powered: bool = false
var is_producing_oxygen: bool = false
var oxygen_capacity: float = 1000.0
var current_oxygen: float = 500.0  # Start with some oxygen
var oxygen_production_rate: float = 5.0  # Units per second when powered
var oxygen_consumption_rate: float = 1.0  # Units per second when supplying

# Visual indicators
var power_indicator: ColorRect = null
var oxygen_indicator: Node2D = null
var bubble_effect: CPUParticles2D = null

signal oxygen_tank_interacted(tank: OxygenTankBuilding)
signal oxygen_production_started()
signal oxygen_production_stopped()
signal powered_state_changed(powered: bool)

func _ready():
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create interaction prompt
	create_interaction_prompt()
	
	# Create visual indicators
	create_visual_indicators()
	
	# Register with systems
	if PowerSystem:
		PowerSystem.register_powered_device(self)
	
	if OxygenSystem:
		OxygenSystem.register_oxygen_source(self)
	
	print("Oxygen Tank created and ready")

func _exit_tree():
	# Unregister from systems when destroyed
	if PowerSystem:
		PowerSystem.unregister_powered_device(self)
	
	if OxygenSystem:
		OxygenSystem.unregister_oxygen_source(self)

func _process(delta: float):
	# Update oxygen levels
	if is_powered and current_oxygen < oxygen_capacity:
		# Produce oxygen when powered
		current_oxygen = min(current_oxygen + oxygen_production_rate * delta, oxygen_capacity)
	
	if is_producing_oxygen and current_oxygen > 0:
		# Consume oxygen when supplying
		current_oxygen = max(current_oxygen - oxygen_consumption_rate * delta, 0.0)
		
		if current_oxygen <= 0:
			stop_oxygen_production()
	
	# Update production state based on power and oxygen availability
	update_production_state()
	
	# Update visual effects
	update_visual_effects()

func create_interaction_prompt():
	interaction_prompt = Label.new()
	interaction_prompt.text = "Press E to check oxygen tank"
	interaction_prompt.position = Vector2(-70, -80)
	interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 1)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 1)
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func create_visual_indicators():
	# Power indicator light
	power_indicator = ColorRect.new()
	power_indicator.size = Vector2(6, 6)
	power_indicator.position = Vector2(-3, -45)
	power_indicator.color = Color.RED
	add_child(power_indicator)
	
	# Oxygen level indicator (vertical bar)
	oxygen_indicator = Node2D.new()
	oxygen_indicator.name = "OxygenIndicator"
	
	var bg_bar = ColorRect.new()
	bg_bar.color = Color(0.2, 0.2, 0.2)
	bg_bar.size = Vector2(8, 30)
	bg_bar.position = Vector2(20, -30)
	oxygen_indicator.add_child(bg_bar)
	
	var fill_bar = ColorRect.new()
	fill_bar.name = "FillBar"
	fill_bar.color = Color(0.3, 0.8, 1.0)  # Light blue for oxygen
	fill_bar.size = Vector2(8, 15)  # Will be updated based on oxygen level
	fill_bar.position = Vector2(20, -15)  # Bottom aligned
	oxygen_indicator.add_child(fill_bar)
	
	add_child(oxygen_indicator)
	
	# Bubble particle effect for oxygen production
	bubble_effect = CPUParticles2D.new()
	bubble_effect.amount = 8
	bubble_effect.lifetime = 2.0
	bubble_effect.preprocess = 0.5
	bubble_effect.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	bubble_effect.spread = 15.0
	bubble_effect.initial_velocity_min = 20.0
	bubble_effect.initial_velocity_max = 40.0
	bubble_effect.angular_velocity_min = -180.0
	bubble_effect.angular_velocity_max = 180.0
	bubble_effect.gravity = Vector2(0, -50)  # Bubbles float up
	bubble_effect.scale_amount_min = 0.5
	bubble_effect.scale_amount_max = 1.5
	bubble_effect.color = Color(0.6, 0.9, 1.0, 0.5)
	bubble_effect.emitting = false
	bubble_effect.position = Vector2(0, -20)
	add_child(bubble_effect)

func update_visual_effects():
	# Update power indicator
	if power_indicator:
		power_indicator.color = Color.GREEN if is_powered else Color.RED
	
	# Update oxygen level bar
	if oxygen_indicator:
		var fill_bar = oxygen_indicator.get_node_or_null("FillBar")
		if fill_bar:
			var fill_percent = current_oxygen / oxygen_capacity
			fill_bar.size.y = 30 * fill_percent
			fill_bar.position.y = -15 + (30 * (1.0 - fill_percent))
			
			# Change color based on oxygen level
			if fill_percent > 0.5:
				fill_bar.color = Color(0.3, 0.8, 1.0)  # Light blue
			elif fill_percent > 0.25:
				fill_bar.color = Color(1.0, 0.8, 0.3)  # Yellow
			else:
				fill_bar.color = Color(1.0, 0.3, 0.3)  # Red
	
	# Update bubble effect
	if bubble_effect:
		bubble_effect.emitting = is_producing_oxygen

func _input(event: InputEvent):
	if player_in_range and event.is_action_pressed("interact"):
		interact_with_tank()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		show_interaction_prompt()

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func interact_with_tank():
	print("Oxygen Tank Status:")
	print("  Powered: ", is_powered)
	print("  Oxygen Level: %.1f/%.1f" % [current_oxygen, oxygen_capacity])
	print("  Producing: ", is_producing_oxygen)
	
	# Show dialog with tank status
	var dialog = AcceptDialog.new()
	dialog.title = "Oxygen Tank Status"
	dialog.dialog_text = """Power Status: %s
Oxygen Level: %.1f/%.1f (%.0f%%)
Production: %s

%s""" % [
		"POWERED" if is_powered else "NO POWER",
		current_oxygen, oxygen_capacity, (current_oxygen/oxygen_capacity) * 100,
		"ACTIVE" if is_producing_oxygen else "INACTIVE",
		get_status_message()
	]
	dialog.size = Vector2(400, 250)
	
	var ui_layer = get_tree().current_scene.get_node_or_null("UI")
	if ui_layer:
		ui_layer.add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(func(): dialog.queue_free())
	
	oxygen_tank_interacted.emit(self)

func get_status_message() -> String:
	if not is_powered:
		return "Tank requires power from a nearby generator to produce oxygen."
	elif current_oxygen <= 0:
		return "WARNING: Tank is empty! Oxygen production halted."
	elif current_oxygen < oxygen_capacity * 0.25:
		return "WARNING: Oxygen levels critical!"
	elif is_producing_oxygen:
		return "Tank is supplying oxygen to the area."
	else:
		return "Tank is refilling oxygen reserves."

func set_powered(powered: bool):
	if is_powered == powered:
		return
	
	is_powered = powered
	print("Oxygen Tank power state: ", "ON" if powered else "OFF")
	powered_state_changed.emit(powered)
	
	update_production_state()

func update_production_state():
	var was_producing = is_producing_oxygen
	
	# Can only produce oxygen if powered and has oxygen
	is_producing_oxygen = is_powered and current_oxygen > 0
	
	if was_producing != is_producing_oxygen:
		if is_producing_oxygen:
			start_oxygen_production()
		else:
			stop_oxygen_production()

func start_oxygen_production():
	if not is_producing_oxygen:
		return
	
	print("Oxygen Tank: Starting oxygen production")
	oxygen_production_started.emit()

func stop_oxygen_production():
	is_producing_oxygen = false
	print("Oxygen Tank: Stopping oxygen production")
	oxygen_production_stopped.emit()

func get_is_powered() -> bool:
	return is_powered

func get_is_producing_oxygen() -> bool:
	return is_producing_oxygen

func get_oxygen_level() -> float:
	return current_oxygen

func get_oxygen_percentage() -> float:
	return (current_oxygen / oxygen_capacity) * 100.0

func move_tank():
	print("Moving oxygen tank...")
	# Return materials to inventory
	if InventorySystem:
		InventorySystem.add_item("METAL_PLATING", 5)
		InventorySystem.add_item("RUBBER_TUBING", 3)
		InventorySystem.add_item("PRESSURE_VALVE", 2)
		InventorySystem.add_item("ELECTRONICS", 1)
	
	# Remove current tank
	queue_free()
	# Start building mode for replacement
	if BuildingSystem:
		BuildingSystem.start_building_mode("oxygen_tank")

func destroy_tank():
	print("Destroying oxygen tank...")
	
	# Return materials to inventory
	if InventorySystem:
		InventorySystem.add_item("METAL_PLATING", 5)
		InventorySystem.add_item("RUBBER_TUBING", 3)
		InventorySystem.add_item("PRESSURE_VALVE", 2)
		InventorySystem.add_item("ELECTRONICS", 1)
	
	# Remove the tank
	queue_free()
