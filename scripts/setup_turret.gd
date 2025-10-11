@tool
extends EditorScript

## Turret Setup Script
## This script automatically configures the turret scene with proper mesh assignments
## Run this from Editor -> Run Script

const TURRET_FBX_PATH = "res://3d Assets/POLYGON_Scifi_Space_SourceFiles_v2/SourceFiles/FBX/SM_Prop_Turret_Small_Floor_01.fbx"

func _run():
	print("============================================================")
	print("🔧 Turret Setup Script")
	print("============================================================")

	# Get the current scene
	var current_scene = get_scene()
	if not current_scene:
		print("❌ No scene is currently open")
		return

	print("📝 Current scene: %s" % current_scene.name)

	# Load the turret FBX
	var turret_fbx = load(TURRET_FBX_PATH)
	if not turret_fbx:
		print("❌ Failed to load turret FBX at: %s" % TURRET_FBX_PATH)
		return

	print("✅ Loaded turret FBX")

	# Instance the FBX to access its meshes
	var fbx_instance = turret_fbx.instantiate()

	# Find the mesh nodes in the FBX
	var base_mesh = find_node_by_name(fbx_instance, "SM_Prop_Turret_Small_Floor_01")
	var pivot_mesh = find_node_by_name(fbx_instance, "SM_Prop_Turret_Small_Pivot_Floor_01")
	var gun_mesh = find_node_by_name(fbx_instance, "SM_Prop_Turret_Small_Gun_Floor_01")

	if not base_mesh or not pivot_mesh or not gun_mesh:
		print("❌ Could not find required meshes in FBX")
		fbx_instance.queue_free()
		return

	print("✅ Found all required meshes:")
	print("   - Base: %s" % base_mesh.name)
	print("   - Pivot: %s" % pivot_mesh.name)
	print("   - Gun: %s" % gun_mesh.name)

	# Find or create the required nodes in the turret scene
	var turret_root = current_scene
	var turret_pivot = find_node_by_name(turret_root, "TurretPivot")
	var gun_pivot = find_node_by_name(turret_root, "GunPivot")
	var muzzle = find_node_by_name(turret_root, "Muzzle")

	if not turret_pivot or not gun_pivot:
		print("❌ Required pivot nodes not found in scene")
		fbx_instance.queue_free()
		return

	print("✅ Found pivot nodes")

	# Remove old TurretModel if it exists
	var old_model = find_node_by_name(turret_root, "TurretModel")
	if old_model:
		print("🗑️  Removing old TurretModel...")
		old_model.queue_free()

	# Create Base mesh instance
	print("\n📦 Creating Base mesh...")
	var base_instance = create_mesh_instance("Base", base_mesh)
	turret_root.add_child(base_instance)
	base_instance.owner = turret_root

	# Create Body mesh instance
	print("📦 Creating Body mesh...")
	var body_instance = create_mesh_instance("Body", pivot_mesh)
	turret_pivot.add_child(body_instance)
	body_instance.owner = turret_root

	# Create Gun mesh instance
	print("📦 Creating Gun mesh...")
	var gun_instance = create_mesh_instance("Gun", gun_mesh)
	gun_pivot.add_child(gun_instance)
	gun_instance.owner = turret_root

	# Position GunPivot at the gun's rotation point
	gun_pivot.position = Vector3(0, 0.6, 0)  # Adjust height as needed

	# Position Muzzle at gun barrel tip
	if muzzle:
		muzzle.position = Vector3(0, 0, -1.8)  # Forward from gun
		print("📍 Positioned Muzzle at gun barrel tip")

	# Clean up
	fbx_instance.queue_free()

	print("\n============================================================")
	print("✨ Turret setup complete!")
	print("============================================================")
	print("\n📋 Scene structure:")
	print_scene_tree(turret_root, 0)

	# Save the scene
	var scene_path = get_scene().scene_file_path
	if scene_path:
		var packed_scene = PackedScene.new()
		packed_scene.pack(turret_root)
		ResourceSaver.save(packed_scene, scene_path)
		print("\n💾 Scene saved: %s" % scene_path)
	else:
		print("\n⚠️  Scene not saved (no file path)")


func find_node_by_name(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root

	for child in root.get_children():
		var found = find_node_by_name(child, node_name)
		if found:
			return found

	return null


func create_mesh_instance(instance_name: String, source_mesh_node: Node) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = instance_name

	if source_mesh_node is MeshInstance3D:
		mesh_instance.mesh = source_mesh_node.mesh
		print("   ✅ Assigned mesh from %s" % source_mesh_node.name)
	else:
		print("   ⚠️  Source node is not a MeshInstance3D")

	return mesh_instance


func print_scene_tree(node: Node, indent: int = 0):
	var indent_str = "  ".repeat(indent)
	print("%s├─ %s (%s)" % [indent_str, node.name, node.get_class()])

	for child in node.get_children():
		print_scene_tree(child, indent + 1)
