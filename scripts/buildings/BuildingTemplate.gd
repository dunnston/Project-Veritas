extends Node3D
class_name BuildingTemplate

## Represents a placed but unbuilt building template
## Players can walk through these and build them by holding E

signal construction_completed(template: BuildingTemplate)
signal construction_cancelled(template: BuildingTemplate)

@export var building_id: String = ""
@export var building_rotation_degrees: float = 0.0
@export var building_cost: Dictionary = {}

var mesh_instance: MeshInstance3D = null
var interaction_area: Area3D = null
var template_material: StandardMaterial3D = null
var is_player_nearby: bool = false
var building_data: Dictionary = {}

func _ready():
	# Add to interactable group
	add_to_group("building_template")
	add_to_group("interactable")

	# Set up template material (light blue, transparent)
	setup_template_material()

func setup_template_material():
	"""Create the light blue transparent material for templates"""
	template_material = StandardMaterial3D.new()
	template_material.albedo_color = Color(0.3, 0.7, 1.0, 0.4)  # Light blue, 40% opacity
	template_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	template_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Render both sides
	template_material.emission_enabled = true
	template_material.emission = Color(0.3, 0.7, 1.0)
	template_material.emission_energy_multiplier = 0.5

func initialize_template(id: String, pos: Vector3, rotation_deg: float, cost: Dictionary, data: Dictionary):
	"""Initialize the template with building data"""
	building_id = id
	global_position = pos
	rotation_degrees = Vector3(0, rotation_deg, 0)
	building_rotation_degrees = rotation_deg
	building_cost = cost
	building_data = data

	# Set up template material FIRST (before creating mesh)
	setup_template_material()

	# Create visual mesh
	create_template_mesh()

	# Set up interaction area
	setup_interaction_area()

	print("BuildingTemplate created: %s at %s" % [building_id, pos])

func create_template_mesh():
	"""Create the visual mesh for this template"""
	var size = building_data.get("size", Vector3(1, 1, 1))

	# Special handling for door frames
	if building_id == "door_frame" or building_id == "door_frame_with_door":
		# Create CSG-based template with door cutout
		var csg_wall = CSGBox3D.new()
		csg_wall.size = size
		csg_wall.material = template_material
		csg_wall.use_collision = false  # Templates are walkthrough

		var csg_cutout = CSGBox3D.new()
		csg_cutout.size = Vector3(1.2, 2.4, 0.3)
		csg_cutout.operation = CSGShape3D.OPERATION_SUBTRACTION
		csg_cutout.position = Vector3(0, -0.3, 0)
		csg_wall.add_child(csg_cutout)

		# If door_frame_with_door, add door preview
		if building_id == "door_frame_with_door":
			var door_mesh = CSGBox3D.new()
			door_mesh.size = Vector3(1.15, 2.35, 0.05)
			door_mesh.position = Vector3(0, -0.325, 0)
			door_mesh.material = template_material
			csg_wall.add_child(door_mesh)

		add_child(csg_wall)
	else:
		# Standard box mesh for other buildings
		mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = size
		mesh_instance.mesh = box_mesh
		mesh_instance.material_override = template_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)

func setup_interaction_area():
	"""Set up Area3D for player interaction detection"""
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 0
	interaction_area.collision_mask = 1 << 1  # Detect player on layer 2
	add_child(interaction_area)

	var collision_shape = CollisionShape3D.new()
	var size = building_data.get("size", Vector3(1, 1, 1))
	var box_shape = BoxShape3D.new()
	# Make interaction area slightly larger
	box_shape.size = size * 1.5
	collision_shape.shape = box_shape
	interaction_area.add_child(collision_shape)

	# Connect signals
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		is_player_nearby = true
		print("Player entered template area: %s" % building_id)

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		is_player_nearby = false
		print("Player left template area: %s" % building_id)

func interact():
	"""Called when player presses E near this template - does nothing (hold-to-build instead)"""
	# This is intentionally empty - we'll use hold-to-build instead
	pass

func can_afford() -> bool:
	"""Check if player can afford to build this template"""
	if building_cost.is_empty():
		return true

	if not InventorySystem:
		return false

	for resource_id in building_cost.keys():
		var required_amount = building_cost[resource_id]
		var current_amount = InventorySystem.get_item_count(resource_id)
		if current_amount < required_amount:
			return false

	return true

func start_construction():
	"""Begin construction of this template"""
	print("Starting construction of %s" % building_id)
	# Player will handle the hold-to-build mechanic
	# This function is here for future use if needed

func complete_construction():
	"""Complete construction and convert to real building"""
	print("Completing construction of %s" % building_id)
	construction_completed.emit(self)

func cancel_construction():
	"""Cancel and remove this template"""
	print("Cancelling construction of %s" % building_id)
	construction_cancelled.emit(self)
	queue_free()

func get_display_name() -> String:
	"""Get the display name for UI prompts"""
	return building_data.get("name", building_id)
