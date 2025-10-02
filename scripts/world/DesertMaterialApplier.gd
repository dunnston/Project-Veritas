@tool
extends Node

# Auto-applies textures to 3D models based on the MaterialList
# Run this script in the editor to apply materials to imported FBX models

const TEXTURE_PATH = "res://3d Assets/Textures/"
const MATERIAL_NAME = "PolygonNatureBiomes_AridDesert_Mat_01"
const TEXTURE_NAME = "PolygonNatureBiomesS2_AridDesert_Texture_01"

static func create_desert_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()

	# Try to load main desert texture
	var albedo_path = TEXTURE_PATH + TEXTURE_NAME + ".tga"
	if not ResourceLoader.exists(albedo_path):
		albedo_path = TEXTURE_PATH + "Dirt_Texture_Arid_01.png"

	if ResourceLoader.exists(albedo_path):
		var texture = load(albedo_path)
		material.albedo_texture = texture
		print("Loaded desert texture: " + albedo_path)
	else:
		# Fallback color
		material.albedo_color = Color(0.85, 0.75, 0.55, 1)
		print("Using fallback desert color")

	# Desert material properties
	material.roughness = 0.85
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Show both sides

	return material

static func apply_material_to_mesh_instance(mesh_instance: MeshInstance3D):
	if not mesh_instance:
		return

	var desert_mat = create_desert_material()
	mesh_instance.material_override = desert_mat
	print("Applied desert material to: " + mesh_instance.name)

static func apply_materials_to_node(node: Node):
	# Recursively apply materials to all MeshInstance3D nodes
	if node is MeshInstance3D:
		apply_material_to_mesh_instance(node)

	for child in node.get_children():
		apply_materials_to_node(child)
