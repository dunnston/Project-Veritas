extends Node

# Mapping of item IDs to their corresponding pickup scene paths
var item_scene_map = {
	"WOOD_SCRAPS": "res://scenes/items/WoodScrap.tscn",
	"METAL_SCRAPS": "res://scenes/items/MetalScrap.tscn", 
	"TIRE": "res://scenes/items/Tire.tscn",
	"SPEAKERS": "res://scenes/items/Speakers.tscn",
	"GEARS": "res://scenes/items/Gears.tscn",
	"SPRING": "res://scenes/items/Spring.tscn",
	# For items without specific scenes, we'll create a generic pickup
	"crowbar": "res://scenes/items/WoodScrap.tscn", # Temporary - could create specific scene later
	"MAGNETS": "res://scenes/items/WoodScrap.tscn", # Temporary
	"STEEL_SHEET": "res://scenes/items/MetalScrap.tscn", # Temporary
	"RUBBER_SEAL": "res://scenes/items/WoodScrap.tscn", # Temporary
	"METAL_VALVE": "res://scenes/items/MetalScrap.tscn", # Temporary
	"COPPER_WIRE": "res://scenes/items/WoodScrap.tscn", # Temporary
	"METAL_ROD": "res://scenes/items/MetalScrap.tscn", # Temporary
	"GEAR_ASSEMBLY": "res://scenes/items/Gears.tscn" # Use gears scene for now
}

func _ready():
	# Connect to the inventory system's item_dropped signal
	if InventorySystem:
		InventorySystem.item_dropped.connect(_on_item_dropped)

func _on_item_dropped(item_id: String, quantity: int, drop_position: Vector3):
	print("ItemDropManager: Spawning %d %s at %s" % [quantity, item_id, drop_position])

	# For now, just log the drop since we don't have 3D pickup scenes yet
	print("ITEM DROPPED: %d x %s at position %s" % [quantity, item_id, drop_position])
	print("Note: 3D item pickup scenes not yet implemented - items are removed from inventory but not spawned in world")

	# TODO: Implement 3D item pickup spawning
	# Get the scene path for this item
	var scene_path = item_scene_map.get(item_id, "")
	if scene_path.is_empty():
		print("No scene mapping found for item: %s (would need 3D pickup scene)" % item_id)
		return

	# Check if scene exists
	if not ResourceLoader.exists(scene_path):
		print("Scene file not found: %s (these are 2D scenes, need 3D versions)" % scene_path)
		return

	# Would spawn 3D items here when scenes are available
	# for i in range(quantity):
	#     spawn_item_pickup_3d(scene_path, drop_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), item_id)

func spawn_item_pickup(scene_path: String, position: Vector2, item_id: String = ""):
	# Load and instantiate the pickup scene
	var pickup_scene = load(scene_path)
	if not pickup_scene:
		print("Failed to load pickup scene: %s" % scene_path)
		return
	
	var pickup_instance = pickup_scene.instantiate()
	if not pickup_instance:
		print("Failed to instantiate pickup scene: %s" % scene_path)
		return
	
	# If this is a generic scene being used for a different item, update the resource_name
	if not item_id.is_empty() and pickup_instance.has_method("set"):
		# Try to set the resource_name property
		pickup_instance.set("resource_name", item_id)
		print("Set pickup resource_name to: %s" % item_id)
	
	# Get the current scene (world) to add the pickup to
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(pickup_instance)
		pickup_instance.global_position = position
		print("Spawned item pickup at position: %s" % position)
	else:
		print("No current scene found to add item pickup")
		pickup_instance.queue_free()
