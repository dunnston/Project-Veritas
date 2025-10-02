extends Node3D

# This script sets up the desert demo scene with proper collision and materials
# Attach this to the root DesertDemoScene node

const DesertMaterialApplier = preload("res://scripts/world/DesertMaterialApplier.gd")

func _ready():
	setup_terrain_collision()
	setup_boundary_walls()
	setup_desert_material()
	# Wait a bit for props to spawn, then apply materials
	await get_tree().create_timer(0.5).timeout
	apply_materials_to_props()
	print("Desert scene setup complete - 1000m x 1000m playable area")

func setup_terrain_collision():
	var ground_plane = get_node_or_null("Terrain/GroundPlane")
	if not ground_plane:
		push_error("Ground plane not found!")
		return

	var collision_shape = ground_plane.get_node_or_null("CollisionShape3D")
	if collision_shape:
		# Create box shape for ground collision
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(1000, 0.1, 1000)
		collision_shape.shape = box_shape
		print("Terrain collision set up: 1000m x 1000m")

func setup_boundary_walls():
	# Set up invisible walls at map boundaries to prevent falling off
	var boundaries = get_node_or_null("Boundaries")
	if not boundaries:
		push_error("Boundaries node not found!")
		return

	# North and South walls (run along X axis)
	setup_wall("Boundaries/NorthWall/CollisionShape3D", Vector3(1000, 50, 1))
	setup_wall("Boundaries/SouthWall/CollisionShape3D", Vector3(1000, 50, 1))

	# East and West walls (run along Z axis)
	setup_wall("Boundaries/EastWall/CollisionShape3D", Vector3(1, 50, 1000))
	setup_wall("Boundaries/WestWall/CollisionShape3D", Vector3(1, 50, 1000))

	print("Boundary walls configured - invisible barriers at edges")

func setup_wall(path: String, size: Vector3):
	var collision_shape = get_node_or_null(path)
	if collision_shape:
		var box_shape = BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape

func setup_desert_material():
	var ground_mesh = get_node_or_null("Terrain/GroundPlane/MeshInstance3D")
	if not ground_mesh:
		push_error("Ground mesh not found!")
		return

	# Create desert sand material
	var desert_material = StandardMaterial3D.new()

	# Try to load desert texture
	var texture_path = "res://3d Assets/Textures/Dirt_Texture_Arid_01.png"
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		desert_material.albedo_texture = texture
		desert_material.uv1_scale = Vector3(50, 50, 1)  # Tile the texture
		print("Loaded desert texture: " + texture_path)
	else:
		# Fallback to sand color
		desert_material.albedo_color = Color(0.85, 0.75, 0.55, 1)  # Sandy beige
		print("Using fallback desert color (texture not found)")

	# Desert material properties
	desert_material.roughness = 0.9
	desert_material.metallic = 0.0

	ground_mesh.material_override = desert_material
	print("Desert material applied to terrain")

func apply_materials_to_props():
	var env_props = get_node_or_null("EnvironmentProps")
	if env_props:
		DesertMaterialApplier.apply_materials_to_node(env_props)
		print("Applied materials to environment props")
