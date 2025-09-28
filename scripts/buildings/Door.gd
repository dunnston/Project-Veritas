extends Area2D
class_name Door

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var interaction_collision: CollisionShape2D = $InteractionArea/CollisionShape2D

var is_open: bool = false
var door_body: StaticBody2D
var door_collision: CollisionShape2D
var door_sprite: ColorRect

signal door_state_changed(is_open: bool)

func _ready():
	# Connect interaction signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Set up interaction area collision
	if not interaction_collision.shape:
		var interaction_rect = RectangleShape2D.new()
		interaction_rect.size = Vector2(48, 48)  # Larger interaction area
		interaction_collision.shape = interaction_rect

func initialize_door(door_static_body: StaticBody2D):
	"""Initialize the door with reference to its StaticBody2D and collision"""
	door_body = door_static_body
	door_collision = door_body.get_node("CollisionShape2D") as CollisionShape2D
	door_sprite = door_body.get_node("ColorRect") as ColorRect
	
	# Position this Area2D at the same location as the door body
	global_position = door_body.global_position

var player_nearby: bool = false

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_nearby = true
		show_interaction_prompt(true)

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_nearby = false
		show_interaction_prompt(false)

func _input(event: InputEvent):
	if not player_nearby:
		return
		
	if event.is_action_pressed("interact"):
		toggle_door()

func toggle_door():
	"""Toggle door open/closed state"""
	is_open = not is_open
	update_door_visual()
	update_door_collision()
	door_state_changed.emit(is_open)
	
	print("Door %s" % ("opened" if is_open else "closed"))

func update_door_visual():
	"""Update door visual representation"""
	if not door_sprite:
		return
		
	if is_open:
		# Change to green when open
		door_sprite.color = Color.GREEN
	else:
		# Change to brown when closed  
		door_sprite.color = Color.SADDLE_BROWN

func update_door_collision():
	"""Enable/disable door collision based on open state"""
	if door_collision:
		door_collision.disabled = is_open

func show_interaction_prompt(show: bool):
	"""Show/hide interaction prompt - could be expanded with UI later"""
	if show:
		print("Press E to %s door" % ("close" if is_open else "open"))