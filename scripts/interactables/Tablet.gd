extends Area2D
class_name Tablet

signal tablet_read()

@onready var interaction_prompt: Label = $InteractionPrompt
var player_in_range: bool = false
var has_been_read: bool = false

# The wake-up message
const WAKE_UP_MESSAGE = """If you are reading this, I had to leave fast. 

I am not sure how much longer the backup oxygen system will last. 

The emergency systems are running on backup power - you have 72 hours before the oxygen runs out completely.

To restore oxygen you'll need to build:
• Oxygen Tank 
• Hand Crank Generator

Check the workbench for crafting recipes. Some parts may be in the locked storage room - you'll need a crowbar to get in.

Good luck,
- Marcus"""

func _ready():
	# Setup collision layers
	collision_layer = 16  # Interaction layer
	collision_mask = 2    # Player layer
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Ready and waiting for interaction

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

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		if player_in_range and not has_been_read:
			read_tablet()

func read_tablet():
	print("Tablet: Player reading tablet")
	has_been_read = true
	
	# Hide interaction prompt
	show_interaction_prompt(false)
	
	# Show the wake-up message (this will emit the signal after dialog closes)
	show_wake_up_message()

func show_wake_up_message():
	# Create a popup dialog for the message
	var dialog = AcceptDialog.new()
	dialog.title = "Personal Data Pad - Marcus Chen"
	dialog.dialog_text = WAKE_UP_MESSAGE
	dialog.size = Vector2(500, 400)
	
	# Add to UI layer so it appears on top
	var ui_layer = get_tree().current_scene.get_node("UI")
	if ui_layer:
		ui_layer.add_child(dialog)
		dialog.popup_centered()
		
		# Remove dialog when closed and trigger emergency
		dialog.confirmed.connect(func(): 
			dialog.queue_free()
			# Emit signal after dialog closes to start emergency
			tablet_read.emit()
		)
	else:
		print("Tablet: Could not find UI layer for dialog")
		print("Message: ", WAKE_UP_MESSAGE)
		# Still emit signal even if dialog fails
		tablet_read.emit()
