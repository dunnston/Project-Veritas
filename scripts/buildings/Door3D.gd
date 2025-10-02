extends Node3D
class_name Door3D

## 3D Door System
## Provides interactive doors with animation, collision management, and state persistence

# Door state
var is_open: bool = false
var is_locked: bool = false
var is_animating: bool = false

# Components
var door_mesh: MeshInstance3D = null
var collision_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null
var interaction_area: Area3D = null
var interaction_prompt: Label3D = null
var animation_player: AnimationPlayer = null

# Interaction
var player_in_range: bool = false
@export var interaction_range: float = 3.0

# Animation
@export var open_angle: float = 90.0  # Degrees to rotate when opening
@export var animation_duration: float = 0.5  # Seconds to complete animation

# Signals
signal door_opened
signal door_closed
signal door_locked
signal door_unlocked

func _ready():
	add_to_group("door")
	add_to_group("interactable")

	# Setup components
	call_deferred("setup_components")

	print("Door3D created at position %s" % global_position)

func setup_components():
	# Find or create mesh
	door_mesh = get_node_or_null("DoorMesh")
	if not door_mesh:
		door_mesh = MeshInstance3D.new()
		door_mesh.name = "DoorMesh"
		add_child(door_mesh)
		# Create a simple box mesh as placeholder
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(1.0, 2.0, 0.1)  # Standard door size
		door_mesh.mesh = box_mesh
		# Create a material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.4, 0.25, 0.15)  # Wood color
		door_mesh.set_surface_override_material(0, material)

	# Find or create collision body
	collision_body = get_node_or_null("CollisionBody")
	if not collision_body:
		collision_body = StaticBody3D.new()
		collision_body.name = "CollisionBody"
		add_child(collision_body)

		collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(1.0, 2.0, 0.1)
		collision_shape.shape = box_shape
		collision_body.add_child(collision_shape)

		# Set collision layers
		collision_body.collision_layer = 1 << 2  # Buildings layer (layer 3)
		collision_body.collision_mask = 0
	else:
		collision_shape = collision_body.get_node_or_null("CollisionShape3D")

	# Create interaction area
	setup_interaction_area()

	# Create interaction prompt
	create_interaction_prompt()

	# Create animation player
	setup_animation()

func setup_interaction_area():
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)

	var interaction_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = interaction_range
	interaction_shape.shape = sphere_shape
	interaction_area.add_child(interaction_shape)

	# Configure area to detect player
	interaction_area.collision_layer = 1 << 7  # Interactables layer (layer 8)
	interaction_area.collision_mask = 1 << 1   # Player layer (layer 2)
	interaction_area.monitoring = true
	interaction_area.monitorable = true

	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func create_interaction_prompt():
	interaction_prompt = Label3D.new()
	interaction_prompt.text = "Press E to open"
	interaction_prompt.pixel_size = 0.01
	interaction_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_prompt.position = Vector3(0, 1.2, 0)  # Float above door handle height
	interaction_prompt.modulate = Color.WHITE
	interaction_prompt.outline_modulate = Color.BLACK
	interaction_prompt.outline_size = 2
	interaction_prompt.visible = false
	add_child(interaction_prompt)

func setup_animation():
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

	# Create open animation
	var open_anim = Animation.new()
	open_anim.length = animation_duration

	# Rotation track for door mesh
	var rot_track_idx = open_anim.add_track(Animation.TYPE_VALUE)
	open_anim.track_set_path(rot_track_idx, "DoorMesh:rotation:y")
	open_anim.track_insert_key(rot_track_idx, 0.0, 0.0)
	open_anim.track_insert_key(rot_track_idx, animation_duration, deg_to_rad(open_angle))
	open_anim.track_set_interpolation_type(rot_track_idx, Animation.INTERPOLATION_CUBIC)

	animation_player.add_animation_library("", AnimationLibrary.new())
	animation_player.get_animation_library("").add_animation("open", open_anim)

	# Create close animation
	var close_anim = Animation.new()
	close_anim.length = animation_duration

	rot_track_idx = close_anim.add_track(Animation.TYPE_VALUE)
	close_anim.track_set_path(rot_track_idx, "DoorMesh:rotation:y")
	close_anim.track_insert_key(rot_track_idx, 0.0, deg_to_rad(open_angle))
	close_anim.track_insert_key(rot_track_idx, animation_duration, 0.0)
	close_anim.track_set_interpolation_type(rot_track_idx, Animation.INTERPOLATION_CUBIC)

	animation_player.get_animation_library("").add_animation("close", close_anim)

	# Connect animation finished signal
	animation_player.animation_finished.connect(_on_animation_finished)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = true
		show_interaction_prompt()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = false
		hide_interaction_prompt()

func show_interaction_prompt():
	if interaction_prompt:
		update_prompt_text()
		interaction_prompt.visible = true

func hide_interaction_prompt():
	if interaction_prompt:
		interaction_prompt.visible = false

func update_prompt_text():
	if not interaction_prompt:
		return

	if is_locked:
		interaction_prompt.text = "Locked"
		interaction_prompt.modulate = Color.RED
	elif is_open:
		interaction_prompt.text = "Press E to close"
		interaction_prompt.modulate = Color.WHITE
	else:
		interaction_prompt.text = "Press E to open"
		interaction_prompt.modulate = Color.WHITE

# Called by player when pressing E
func interact():
	if is_locked:
		print("Door is locked!")
		return

	if is_animating:
		return

	if is_open:
		close_door()
	else:
		open_door()

func open_door():
	if is_open or is_animating or is_locked:
		return

	is_animating = true

	# Disable collision
	if collision_body:
		collision_body.collision_layer = 0
		collision_body.collision_mask = 0

	# Play animation
	if animation_player:
		animation_player.play("open")
	else:
		_on_animation_finished("open")

	print("Door opening...")

func close_door():
	if not is_open or is_animating:
		return

	is_animating = true

	# Play animation
	if animation_player:
		animation_player.play("close")
	else:
		_on_animation_finished("close")

	print("Door closing...")

func _on_animation_finished(anim_name: String):
	is_animating = false

	if anim_name == "open":
		is_open = true
		door_opened.emit()
		update_prompt_text()
		print("Door opened")
	elif anim_name == "close":
		is_open = false
		# Re-enable collision
		if collision_body:
			collision_body.collision_layer = 1 << 2  # Buildings layer
			collision_body.collision_mask = 0
		door_closed.emit()
		update_prompt_text()
		print("Door closed")

func lock_door():
	if is_locked:
		return

	is_locked = true
	# Close door if open
	if is_open and not is_animating:
		close_door()

	door_locked.emit()
	update_prompt_text()
	print("Door locked")

func unlock_door():
	if not is_locked:
		return

	is_locked = false
	door_unlocked.emit()
	update_prompt_text()
	print("Door unlocked")

# Save/Load support
func get_save_data() -> Dictionary:
	return {
		"is_open": is_open,
		"is_locked": is_locked,
		"position": global_position,
		"rotation": global_rotation
	}

func load_save_data(data: Dictionary):
	if data.has("is_locked"):
		is_locked = data["is_locked"]

	if data.has("is_open"):
		if data["is_open"]:
			# Set door to open state without animation
			is_open = true
			if door_mesh:
				door_mesh.rotation.y = deg_to_rad(open_angle)
			if collision_body:
				collision_body.collision_layer = 0
				collision_body.collision_mask = 0
		else:
			is_open = false

	if data.has("position"):
		global_position = data["position"]

	if data.has("rotation"):
		global_rotation = data["rotation"]
