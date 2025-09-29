extends Node

# Use the generic 3D pickup scene for all items
const GENERIC_PICKUP_3D_SCENE = "res://scenes/items/item_pickup_3d.tscn"

func _ready():
	# Connect to the inventory system's item_dropped signal
	if InventorySystem:
		InventorySystem.item_dropped.connect(_on_item_dropped)
		print("ItemDropManager: Connected to InventorySystem.item_dropped signal")
	else:
		print("ItemDropManager: ERROR - InventorySystem not found!")

func _on_item_dropped(item_id: String, quantity: int, drop_position: Vector3):
	print("ItemDropManager: Spawning %d %s at %s" % [quantity, item_id, drop_position])

	# For stacks greater than 1, split into individual items for better visual feedback
	if quantity > 1:
		for i in range(quantity):
			# Create random spread for multiple items
			var spread_offset = Vector3(
				randf_range(-1.0, 1.0),
				0,
				randf_range(-1.0, 1.0)
			)
			spawn_item_pickup_3d(GENERIC_PICKUP_3D_SCENE, drop_position + spread_offset, item_id, 1)
	else:
		# Single item, spawn normally
		spawn_item_pickup_3d(GENERIC_PICKUP_3D_SCENE, drop_position, item_id, quantity)

func spawn_item_pickup_3d(scene_path: String, position: Vector3, item_id: String = "", quantity: int = 1):
	# Load and instantiate the pickup scene
	var pickup_scene = load(scene_path)
	if not pickup_scene:
		print("Failed to load pickup scene: %s" % scene_path)
		return

	var pickup_instance = pickup_scene.instantiate()
	if not pickup_instance:
		print("Failed to instantiate pickup scene: %s" % scene_path)
		return

	# Get the current scene (world) to add the pickup to first
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("No current scene found to add item pickup")
		pickup_instance.queue_free()
		return

	# Add to scene first
	current_scene.add_child(pickup_instance)

	# Add some random offset to prevent items from spawning on top of each other
	var random_offset = Vector3(
		randf_range(-0.2, 0.2),
		0,
		randf_range(-0.2, 0.2)
	)
	pickup_instance.global_position = position + random_offset

	# Configure the pickup with item data AFTER adding to scene
	if pickup_instance.has_method("setup"):
		pickup_instance.setup(item_id, quantity)
	else:
		# Fallback to setting properties directly
		if not item_id.is_empty():
			pickup_instance.item_id = item_id
			pickup_instance.amount = quantity

	print("Spawned 3D item pickup for %s x%d at position: %s" % [item_id, quantity, position])
