extends Node3D

## Automatically adds collision shapes to environment meshes at runtime
## Attach this to the root of your scene to enable collisions for all static meshes

@export var enabled: bool = true
@export var collision_layer: int = 1  # World layer
@export var collision_mask: int = 0

func _ready():
	if not enabled:
		return

	print("Adding runtime collisions to environment objects...")
	await get_tree().process_frame  # Wait for scene to fully load
	var count = add_collisions_to_children(get_parent())
	print("Added collisions to %d objects" % count)

func add_collisions_to_children(node: Node) -> int:
	var count = 0

	for child in node.get_children():
		# Skip the collision manager itself
		if child == self:
			continue

		# Skip if it's already a physics body or is the player/UI
		if child is CharacterBody3D or child is RigidBody3D or child is Area3D or child is StaticBody3D:
			continue
		if child is CanvasLayer or child is Camera3D:
			continue

		# Check if this node has any mesh instances (directly or nested)
		var meshes = find_all_meshes(child)
		if meshes.size() > 0:
			# Add collision to this entire node
			if add_collision_to_node(child, meshes):
				count += 1

	return count

func find_all_meshes(node: Node, results: Array = []) -> Array:
	if node is MeshInstance3D:
		results.append(node)

	for child in node.get_children():
		find_all_meshes(child, results)

	return results

func add_collision_to_node(node: Node3D, meshes: Array) -> bool:
	# Check if node already has collision
	for child in node.get_children():
		if child is StaticBody3D or child is CollisionShape3D:
			return false  # Already has collision

	# Create a StaticBody3D as a child
	var static_body = StaticBody3D.new()
	static_body.name = "CollisionBody"
	static_body.collision_layer = collision_layer
	static_body.collision_mask = collision_mask

	# Add to node first so transforms work correctly
	node.add_child(static_body)

	var shapes_added = 0

	# Add collision shapes for each mesh
	for mesh_instance in meshes:
		if mesh_instance.mesh == null:
			continue

		var collision_shape = CollisionShape3D.new()
		collision_shape.name = "Shape_" + mesh_instance.name

		# Use create_trimesh_shape for static meshes (more accurate than convex)
		var shape = mesh_instance.mesh.create_trimesh_shape()
		if shape != null:
			collision_shape.shape = shape
			static_body.add_child(collision_shape)
			# Convert global transform to local relative to static_body
			collision_shape.global_transform = mesh_instance.global_transform
			shapes_added += 1
		else:
			# Fallback to convex if trimesh fails
			shape = mesh_instance.mesh.create_convex_shape()
			if shape != null:
				collision_shape.shape = shape
				static_body.add_child(collision_shape)
				collision_shape.global_transform = mesh_instance.global_transform
				shapes_added += 1

	if shapes_added == 0:
		# No shapes were added, remove the static body
		node.remove_child(static_body)
		static_body.queue_free()
		return false

	return true
