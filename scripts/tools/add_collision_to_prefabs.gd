@tool
extends EditorScript

# This script adds StaticBody3D and CollisionShape3D to all desert environment prefabs
# Run this from the Godot Editor: File -> Run

func _run():
	print("Adding collisions to desert prefabs...")

	var prefab_dir = "res://assets/enviroment/desert/Prefabs/"
	var dir = DirAccess.open(prefab_dir)

	if dir == null:
		print("Failed to open directory: ", prefab_dir)
		return

	var files_processed = 0
	var files_modified = 0

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tscn") and not file_name.begins_with("."):
			var full_path = prefab_dir + file_name
			if process_prefab(full_path):
				files_modified += 1
			files_processed += 1
		file_name = dir.get_next()

	dir.list_dir_end()

	print("Processed %d files, modified %d files" % [files_processed, files_modified])

func process_prefab(path: String) -> bool:
	var scene = load(path) as PackedScene
	if scene == null:
		print("Failed to load: ", path)
		return false

	var root = scene.instantiate()
	if root == null:
		print("Failed to instantiate: ", path)
		return false

	# Check if it already has collision
	if has_collision_shape(root):
		print("Skipping (already has collision): ", path)
		root.queue_free()
		return false

	# Find all MeshInstance3D nodes
	var mesh_instances = find_mesh_instances(root)

	if mesh_instances.is_empty():
		print("Skipping (no mesh found): ", path)
		root.queue_free()
		return false

	# Add collision to the root or the first mesh
	var added = add_collision_to_node(root, mesh_instances)

	if added:
		# Save the modified scene
		var packed_scene = PackedScene.new()
		var result = packed_scene.pack(root)

		if result == OK:
			ResourceSaver.save(packed_scene, path)
			print("Added collision to: ", path)
			root.queue_free()
			return true
		else:
			print("Failed to pack scene: ", path)

	root.queue_free()
	return false

func has_collision_shape(node: Node) -> bool:
	if node is CollisionShape3D or node is StaticBody3D:
		return true

	for child in node.get_children():
		if has_collision_shape(child):
			return true

	return false

func find_mesh_instances(node: Node, results: Array = []) -> Array:
	if node is MeshInstance3D:
		results.append(node)

	for child in node.get_children():
		find_mesh_instances(child, results)

	return results

func add_collision_to_node(root: Node, mesh_instances: Array) -> bool:
	# Create a StaticBody3D as a child of root
	var static_body = StaticBody3D.new()
	static_body.name = "CollisionBody"

	# Add collision shapes for each mesh
	var collision_added = false
	for mesh_instance in mesh_instances:
		if mesh_instance.mesh != null:
			# Create collision shape from mesh
			var collision_shape = CollisionShape3D.new()
			collision_shape.name = "CollisionShape"

			# Create a convex shape from the mesh
			var shape = mesh_instance.mesh.create_convex_shape()
			if shape != null:
				collision_shape.shape = shape

				# Match the transform of the mesh instance relative to root
				collision_shape.transform = mesh_instance.transform

				static_body.add_child(collision_shape)
				collision_shape.owner = root
				collision_added = true

	if collision_added:
		root.add_child(static_body)
		static_body.owner = root
		return true

	return false
