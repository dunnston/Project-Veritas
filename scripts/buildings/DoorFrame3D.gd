extends StaticBody3D
class_name DoorFrame3D

## 3D Door Frame System
## Provides a static door frame structure that can hold a Door3D

# Components
var frame_mesh: MeshInstance3D = null
var door_instance: Door3D = null

# Configuration
@export var frame_width: float = 1.2  # Width of the doorway
@export var frame_height: float = 2.2  # Height of the doorway
@export var frame_thickness: float = 0.1  # Thickness of frame walls
@export var wall_depth: float = 0.2  # Depth of the wall

# Door settings
@export var has_door: bool = true
@export var door_on_left: bool = true  # If true, door hinges on left side

func _ready():
	add_to_group("building")
	add_to_group("door_frame")

	# Set collision layers
	collision_layer = 1 << 2  # Buildings layer (layer 3)
	collision_mask = 0

	# Setup components
	call_deferred("setup_components")

	print("DoorFrame3D created at position %s" % global_position)

func setup_components():
	# Create frame mesh
	create_frame_mesh()

	# Create collision shapes for the frame
	create_frame_collision()

	# Create door if needed
	if has_door:
		create_door()

func create_frame_mesh():
	frame_mesh = MeshInstance3D.new()
	frame_mesh.name = "FrameMesh"
	add_child(frame_mesh)

	# Create a combined mesh for the door frame
	var array_mesh = ArrayMesh.new()

	# Frame material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.3, 0.3)  # Gray concrete/metal color

	# Create left post
	var left_post = BoxMesh.new()
	left_post.size = Vector3(frame_thickness, frame_height, wall_depth)

	# Create right post
	var right_post = BoxMesh.new()
	right_post.size = Vector3(frame_thickness, frame_height, wall_depth)

	# Create top lintel
	var lintel = BoxMesh.new()
	lintel.size = Vector3(frame_width, frame_thickness, wall_depth)

	# For now, use a simple box mesh as placeholder
	# In production, you'd combine these into one mesh or use separate MeshInstance3Ds
	var combined_mesh = BoxMesh.new()
	combined_mesh.size = Vector3(frame_width, frame_height, wall_depth)
	frame_mesh.mesh = combined_mesh
	frame_mesh.set_surface_override_material(0, material)

	# Position the frame mesh
	frame_mesh.position = Vector3(0, frame_height / 2, 0)

func create_frame_collision():
	# Left post collision
	var left_collision = CollisionShape3D.new()
	var left_shape = BoxShape3D.new()
	left_shape.size = Vector3(frame_thickness, frame_height, wall_depth)
	left_collision.shape = left_shape
	left_collision.position = Vector3(-frame_width / 2 + frame_thickness / 2, frame_height / 2, 0)
	add_child(left_collision)

	# Right post collision
	var right_collision = CollisionShape3D.new()
	var right_shape = BoxShape3D.new()
	right_shape.size = Vector3(frame_thickness, frame_height, wall_depth)
	right_collision.shape = right_shape
	right_collision.position = Vector3(frame_width / 2 - frame_thickness / 2, frame_height / 2, 0)
	add_child(right_collision)

	# Top lintel collision
	var top_collision = CollisionShape3D.new()
	var top_shape = BoxShape3D.new()
	top_shape.size = Vector3(frame_width - (frame_thickness * 2), frame_thickness, wall_depth)
	top_collision.shape = top_shape
	top_collision.position = Vector3(0, frame_height - frame_thickness / 2, 0)
	add_child(top_collision)

func create_door():
	# Load or create door scene
	var door_scene = load("res://scenes/buildings/Door3D.tscn")
	if door_scene:
		door_instance = door_scene.instantiate()
	else:
		# Create door manually if scene doesn't exist
		door_instance = Door3D.new()

	door_instance.name = "Door"

	# Position door based on hinge side
	var door_width = frame_width - (frame_thickness * 2)
	var hinge_x = 0.0

	if door_on_left:
		# Hinge on left, opens to the right
		hinge_x = -door_width / 2
		door_instance.open_angle = -90.0  # Opens inward
	else:
		# Hinge on right, opens to the left
		hinge_x = door_width / 2
		door_instance.open_angle = 90.0  # Opens inward

	door_instance.position = Vector3(hinge_x, 0, 0)

	add_child(door_instance)

	print("Door created and positioned at %s" % door_instance.position)

# Get the door instance for external control
func get_door() -> Door3D:
	return door_instance

# Control door from door frame
func open_door():
	if door_instance:
		door_instance.open_door()

func close_door():
	if door_instance:
		door_instance.close_door()

func lock_door():
	if door_instance:
		door_instance.lock_door()

func unlock_door():
	if door_instance:
		door_instance.unlock_door()

# Save/Load support
func get_save_data() -> Dictionary:
	var data = {
		"position": global_position,
		"rotation": global_rotation,
		"has_door": has_door,
		"door_on_left": door_on_left
	}

	if door_instance:
		data["door_data"] = door_instance.get_save_data()

	return data

func load_save_data(data: Dictionary):
	if data.has("position"):
		global_position = data["position"]

	if data.has("rotation"):
		global_rotation = data["rotation"]

	if data.has("has_door"):
		has_door = data["has_door"]

	if data.has("door_on_left"):
		door_on_left = data["door_on_left"]

	if data.has("door_data") and door_instance:
		door_instance.load_save_data(data["door_data"])
