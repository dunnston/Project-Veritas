extends Node3D

# This script sets up the desert demo scene with proper collision and materials
# Attach this to the root DesertDemoScene node

const DesertMaterialApplier = preload("res://scripts/world/DesertMaterialApplier.gd")

func _ready():
	setup_terrain_collision()
	setup_boundary_walls()
	setup_desert_material()
	# DISABLED: Material application destroys proper materials from prefabs
	# await get_tree().create_timer(0.5).timeout
	# apply_materials_to_props()
	print("Desert scene setup complete - 500m x 500m playable area")

func setup_terrain_collision():
	var ground_plane = get_node_or_null("Ground")
	if not ground_plane:
		push_error("Ground plane not found!")
		return

	# Ensure ground is on the World collision layer (layer 1)
	ground_plane.collision_layer = 1
	ground_plane.collision_mask = 0  # Ground doesn't need to detect anything

	var collision_shape = ground_plane.get_node_or_null("CollisionShape3D")
	if collision_shape:
		# Check if shape already exists and is properly sized
		if collision_shape.shape and collision_shape.shape is BoxShape3D:
			var existing_shape = collision_shape.shape as BoxShape3D
			# Only update if it's the wrong size
			if existing_shape.size != Vector3(500, 1, 500):
				var box_shape = BoxShape3D.new()
				box_shape.size = Vector3(500, 1, 500)
				collision_shape.shape = box_shape
				print("Terrain collision updated: 500m x 500m")
			else:
				print("Terrain collision already correct: 500m x 500m")
		else:
			# Create new box shape for ground collision
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(500, 1, 500)
			collision_shape.shape = box_shape
			print("Terrain collision created: 500m x 500m")

		# Ensure the collision shape is properly positioned (centered with the mesh)
		# The mesh is at Y=0, box height is 1, so shape center should be at Y=-0.5
		if collision_shape.position != Vector3(0, -0.5, 0):
			collision_shape.position = Vector3(0, -0.5, 0)
			print("Terrain collision shape positioned correctly")

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
	var ground_mesh = get_node_or_null("Ground/MeshInstance3D")
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
