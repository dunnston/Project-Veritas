extends AnimatedSprite2D
class_name AnimatedSpriteDoor

signal door_opened(door: AnimatedSpriteDoor)
signal door_closed(door: AnimatedSpriteDoor)

# Door state
var is_open: bool = false
var is_animating: bool = false
var player_in_range: bool = false

# Collision and interaction components
var collision_body: StaticBody2D
var interaction_area: Area2D
var interaction_prompt: Label

func _ready():
	
	# Set initial state
	frame = 0  # Start closed
	animation = "door"
	
	# Create collision body for closed door
	create_collision_body()
	
	# Create interaction area
	create_interaction_area()
	
	# Create interaction prompt
	create_interaction_prompt()

func create_collision_body():
	# Create collision body that blocks player when door is closed
	collision_body = StaticBody2D.new()
	collision_body.name = "DoorCollision"
	
	# Set collision layers to match walls
	collision_body.collision_layer = 1  # Same as walls
	collision_body.collision_mask = 0   # Doesn't need to detect anything
	
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(62, 50)  # Make it taller to cover the entire door opening including top
	collision_shape.shape = shape
	
	# Position the collision shape to cover both the door and the wall area above it
	collision_shape.position = Vector2(0, -5)  # Move up to cover wall tiles above door
	
	collision_body.add_child(collision_shape)
	add_child(collision_body)
	

func create_interaction_area():
	# Create area for detecting player proximity
	interaction_area = Area2D.new()
	interaction_area.name = "InteractionArea"
	
	var area_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(80, 50)  # Slightly larger than door for easier interaction
	area_shape.shape = shape
	
	interaction_area.collision_layer = 16  # Door interaction layer
	interaction_area.collision_mask = 2    # Player layer
	
	interaction_area.add_child(area_shape)
	add_child(interaction_area)
	
	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	

func create_interaction_prompt():
	# Create label for interaction prompt
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.text = "[E] Open Door"
	interaction_prompt.add_theme_color_override("font_color", Color.WHITE)
	interaction_prompt.position = Vector2(-40, -50)
	interaction_prompt.size = Vector2(80, 20)
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.visible = false
	
	add_child(interaction_prompt)
	

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
		show_interaction_prompt(true)

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
		show_interaction_prompt(false)

func show_interaction_prompt(should_show: bool):
	if interaction_prompt:
		interaction_prompt.visible = should_show
		if should_show:
			interaction_prompt.text = "[E] Open Door" if not is_open else "[E] Close Door"

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if player_in_range and not is_animating:
			toggle_door()

func toggle_door():
	if is_open:
		close_door()
	else:
		open_door()

func open_door():
	if is_animating or is_open:
		return
	
	is_animating = true
	
	# Play opening animation (frame 0 to 6)
	await animate_frames(0, 6)
	
	# Door is now open
	is_open = true
	is_animating = false
	
	# Remove collision so player can walk through
	if collision_body:
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0
	
	# Update prompt text
	if player_in_range:
		show_interaction_prompt(true)
	
	door_opened.emit(self)

func close_door():
	if is_animating or not is_open:
		return
	
	is_animating = true
	
	# Play closing animation (frame 6 to 0)
	await animate_frames(6, 0)
	
	# Door is now closed
	is_open = false
	is_animating = false
	
	# Restore collision
	if collision_body:
		collision_body.collision_layer = 1  # Same as walls
		collision_body.collision_mask = 0   # Doesn't need to detect anything
	
	# Update prompt text
	if player_in_range:
		show_interaction_prompt(true)
	
	door_closed.emit(self)

func animate_frames(start_frame: int, end_frame: int):
	# Animate from start_frame to end_frame
	var step = 1 if end_frame > start_frame else -1
	var current = start_frame
	
	while current != end_frame:
		frame = current
		await get_tree().create_timer(0.08).timeout  # Animation speed
		current += step
	
	# Set final frame
	frame = end_frame

# Public method to set door state without animation (for initialization)
func set_door_state(open: bool):
	is_open = open
	if open:
		frame = 6  # Last frame = fully open
		if collision_body:
			collision_body.collision_layer = 0
			collision_body.collision_mask = 0
	else:
		frame = 0  # First frame = fully closed
		if collision_body:
			collision_body.collision_layer = 1  # Same as walls
			collision_body.collision_mask = 0   # Doesn't need to detect anything
