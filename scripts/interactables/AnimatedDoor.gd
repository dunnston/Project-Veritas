extends Area2D
class_name AnimatedDoor

signal door_opened(door: AnimatedDoor)
signal door_closed(door: AnimatedDoor)

@onready var door_sprite: Sprite2D = $DoorSprite
@onready var collision_body: StaticBody2D = $CollisionBody
@onready var interaction_prompt: Label = $InteractionPrompt

# Door state
var is_open: bool = false
var is_animating: bool = false
var player_in_range: bool = false

# Door animation textures - we'll load these from your tileset
var door_textures: Array[Texture2D] = []
var current_frame: int = 0

# Animation settings
const ANIMATION_SPEED: float = 0.08  # Time between frames
const TOTAL_FRAMES: int = 7  # Based on your door sprite sheet

func _ready():
	print("AnimatedDoor: _ready() called")
	
	# Clear any existing textures first
	door_textures.clear()
	
	# Load door textures from your tileset
	load_door_textures()
	
	# Set initial closed state
	set_door_frame(0)
	
	# Adjust the door sprite position to align with wall opening
	# Move the sprite up so it fits properly in the wall gap
	door_sprite.position.y = -10  # Adjust this value as needed
	
	# Setup collision layers
	collision_layer = 16  # Door interaction layer
	collision_mask = 2    # Player layer
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Hide prompt initially
	interaction_prompt.visible = false

func load_door_textures():
	print("AnimatedDoor: Starting texture loading...")
	
	# Load the door sprites from your sci-asset-pack
	var doors_path = "res://assets/sprites/Sci-Asset-Pack/AnimatedProps/Doors.png"
	
	print("AnimatedDoor: Checking path: ", doors_path)
	print("AnimatedDoor: Path exists: ", ResourceLoader.exists(doors_path))
	
	if not ResourceLoader.exists(doors_path):
		print("AnimatedDoor: Could not find doors.png at ", doors_path)
		create_fallback_textures()
		return
	
	var doors_texture = load(doors_path) as Texture2D
	if not doors_texture:
		print("AnimatedDoor: Could not load doors.png as Texture2D")
		create_fallback_textures()
		return
	
	print("AnimatedDoor: Loaded texture successfully")
	
	var doors_image = doors_texture.get_image()
	if not doors_image:
		print("AnimatedDoor: Could not get image from texture")
		create_fallback_textures()
		return
	
	print("AnimatedDoor: Door image size: ", doors_image.get_size())
	
	# Extract the first column of doors (first door type)  
	# Image is 384x272, let's try extracting larger sections to get complete doors
	# With 6 columns (384/6=64) and let's try full height sections
	var door_width = 64  # 384 / 6 columns
	var door_height = 38  # 272 / 7 frames (approximately)
	
	for i in range(TOTAL_FRAMES):
		# Extract from first column with calculated dimensions
		var frame_rect = Rect2i(0, i * door_height, door_width, door_height)
		print("AnimatedDoor: Extracting frame %d with rect %s" % [i, frame_rect])
		var frame_image = doors_image.get_region(frame_rect)
		
		var texture = ImageTexture.new()
		texture.set_image(frame_image)
		door_textures.append(texture)
	
	print("AnimatedDoor: Extracted door frames with adjusted coordinates")
	print("AnimatedDoor: Loaded %d door textures from doors.png" % door_textures.size())

func create_fallback_textures():
	# Fallback textures in case the doors.png file isn't found
	var colors = [
		Color.BROWN,      # Frame 0 - Closed
		Color.SADDLE_BROWN,  # Frame 1
		Color.SANDY_BROWN,   # Frame 2
		Color.BURLYWOOD,     # Frame 3
		Color.TAN,           # Frame 4
		Color.WHEAT,         # Frame 5
		Color.WHITE          # Frame 6 - Open
	]
	
	for i in range(TOTAL_FRAMES):
		var image = Image.create(32, 32, false, Image.FORMAT_RGB8)
		image.fill(colors[i])
		var texture = ImageTexture.new()
		texture.set_image(image)
		door_textures.append(texture)
	
	print("AnimatedDoor: Created %d fallback textures" % door_textures.size())

func _on_body_entered(body: Node2D):
	if body.name == "Player":
		player_in_range = true
		show_interaction_prompt(true)

func _on_body_exited(body: Node2D):
	if body.name == "Player":
		player_in_range = false
		show_interaction_prompt(false)

func show_interaction_prompt(show: bool):
	interaction_prompt.visible = show
	if show:
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
	
	print("AnimatedDoor: Opening door")
	is_animating = true
	
	# Play opening animation (frames 0 to 6)
	for frame in range(TOTAL_FRAMES):
		set_door_frame(frame)
		await get_tree().create_timer(ANIMATION_SPEED).timeout
	
	# Door is now open
	is_open = true
	is_animating = false
	
	# Remove collision so player can walk through
	collision_body.collision_layer = 0
	collision_body.collision_mask = 0
	
	# Update prompt text
	if player_in_range:
		show_interaction_prompt(true)
	
	door_opened.emit(self)

func close_door():
	if is_animating or not is_open:
		return
	
	print("AnimatedDoor: Closing door")
	is_animating = true
	
	# Play closing animation (frames 6 to 0)
	for frame in range(TOTAL_FRAMES - 1, -1, -1):
		set_door_frame(frame)
		await get_tree().create_timer(ANIMATION_SPEED).timeout
	
	# Door is now closed
	is_open = false
	is_animating = false
	
	# Restore collision
	collision_body.collision_layer = 1
	collision_body.collision_mask = 2
	
	# Update prompt text
	if player_in_range:
		show_interaction_prompt(true)
	
	door_closed.emit(self)

func set_door_frame(frame: int):
	if frame >= 0 and frame < door_textures.size():
		current_frame = frame
		door_sprite.texture = door_textures[frame]

# Public method to set door state without animation (for initialization)
func set_door_state(open: bool):
	is_open = open
	if open:
		set_door_frame(TOTAL_FRAMES - 1)  # Last frame = fully open
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0
	else:
		set_door_frame(0)  # First frame = fully closed
		collision_body.collision_layer = 1
		collision_body.collision_mask = 2