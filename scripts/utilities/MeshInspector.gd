extends Node
class_name MeshInspector

## Utility for inspecting GLB/GLTF mesh files to extract geometry data
## Used to determine actual dimensions and offsets for building placement
##
## Usage:
##   var inspector = MeshInspector.new()
##   var info = inspector.inspect_mesh("res://path/to/mesh.glb")
##   print("Size: ", info.size)
##   print("Visual center: ", info.visual_center)

## Inspect a mesh file and extract its geometry information
## @param scene_path: Path to GLB/GLTF scene file
## @returns: Dictionary with geometry data or empty dict on failure
static func inspect_mesh(scene_path: String) -> Dictionary:
	if not ResourceLoader.exists(scene_path):
		push_error("MeshInspector: Scene not found: %s" % scene_path)
		return {}

	# Load the scene
	var packed_scene = load(scene_path)
	if not packed_scene:
		push_error("MeshInspector: Failed to load scene: %s" % scene_path)
		return {}

	# Instantiate to inspect
	var instance = packed_scene.instantiate()
	if not instance:
		push_error("MeshInspector: Failed to instantiate scene: %s" % scene_path)
		return {}

	# Extract geometry data
	var result = {
		"scene_path": scene_path,
		"size": Vector3.ZERO,
		"visual_center": Vector3.ZERO,
		"geometry_offset": Vector3.ZERO,
		"mesh_position": Vector3.ZERO,
		"aabb": AABB(),  # Full AABB object
		"aabb_size": Vector3.ZERO,
		"aabb_position": Vector3.ZERO,
		"aabb_center": Vector3.ZERO,
		"aabb_end": Vector3.ZERO,
		"has_mesh": false,
		"mesh_type": "",
		"material_count": 0
	}

	# Find MeshInstance3D (could be nested)
	var mesh_instance = _find_mesh_instance(instance)
	if mesh_instance:
		result.has_mesh = true
		result.mesh_position = mesh_instance.position

		# Get AABB (axis-aligned bounding box)
		var mesh = mesh_instance.mesh
		if mesh:
			var aabb = mesh.get_aabb()
			result.aabb = aabb
			result.aabb_size = aabb.size
			result.aabb_position = aabb.position  # Position of the AABB corner
			result.aabb_center = aabb.get_center()
			result.aabb_end = aabb.end
			result.mesh_type = mesh.get_class()

			# Count materials
			if mesh.get_surface_count() > 0:
				result.material_count = mesh.get_surface_count()

			# Visual center = mesh_position + aabb_center
			# This is where the visual geometry actually appears in local space
			# Example: Floor mesh at (-2.5, 0, -2.5) with AABB center (-2.5, 0, 2.5)
			#          Visual center = (-2.5, 0, -2.5) + (-2.5, 0, 2.5) = (-5, 0, 0)
			result.visual_center = result.mesh_position + result.aabb_center

			# Geometry offset is the negative of visual center
			# This is what we add to root position to make visuals appear at desired location
			result.geometry_offset = -result.visual_center

			print("MeshInspector: %s" % scene_path.get_file())
			print("  Mesh Type: %s" % result.mesh_type)
			print("  Mesh Position: %s" % result.mesh_position)
			print("  AABB Size: %s" % result.aabb_size)
			print("  AABB Position: %s" % result.aabb_position)
			print("  AABB Center: %s" % result.aabb_center)
			print("  AABB End: %s" % result.aabb_end)
			print("  Visual Center: %s" % result.visual_center)
			print("  Geometry Offset: %s" % result.geometry_offset)
			print("  Materials: %d" % result.material_count)
	else:
		push_warning("MeshInspector: No MeshInstance3D found in %s" % scene_path)

	# Clean up
	instance.queue_free()

	return result

## Recursively find the first MeshInstance3D in a node tree
static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found:
			return found

	return null

## Batch inspect multiple mesh files and return results
## @param scene_paths: Array of scene file paths
## @returns: Dictionary mapping scene_path to geometry data
static func batch_inspect(scene_paths: Array) -> Dictionary:
	var results = {}
	for path in scene_paths:
		if path is String and not path.is_empty():
			results[path] = inspect_mesh(path)
	return results

## Print formatted geometry data for debugging
static func print_geometry_info(info: Dictionary) -> void:
	if info.is_empty():
		print("No geometry info available")
		return

	print("=== Geometry Info ===")
	print("Scene: %s" % info.get("scene_path", "unknown"))
	print("Has Mesh: %s" % info.get("has_mesh", false))
	print("Mesh Type: %s" % info.get("mesh_type", "unknown"))
	print("")
	print("Mesh Position: %s" % info.get("mesh_position", Vector3.ZERO))
	print("")
	print("AABB Size: %s" % info.get("aabb_size", Vector3.ZERO))
	print("AABB Position: %s" % info.get("aabb_position", Vector3.ZERO))
	print("AABB Center: %s" % info.get("aabb_center", Vector3.ZERO))
	print("AABB End: %s" % info.get("aabb_end", Vector3.ZERO))
	print("")
	print("Visual Center: %s" % info.get("visual_center", Vector3.ZERO))
	print("Geometry Offset: %s" % info.get("geometry_offset", Vector3.ZERO))
	print("")
	print("Materials: %d" % info.get("material_count", 0))
	print("===================")
