@tool
extends EditorScript

## SciFiSpace Material Fixer
## This script automatically fixes missing textures in scifispace prefabs
## Run this from Editor -> Run Script

const MATERIAL_LIST_PATH = "res://assets/enviroment/scifispace/MaterialList_PolygonSciFiSpace.txt"
const PREFABS_DIR = "res://assets/enviroment/scifispace/Prefabs"
const TEXTURES_DIR = "res://assets/enviroment/scifispace/Textures"

var material_map = {}
var processed_count = 0
var failed_count = 0

func _run():
	print("============================================================")
	print("🔧 SciFiSpace Material Fixer")
	print("============================================================")

	# Parse the material list
	if not parse_material_list():
		print("❌ Failed to parse material list")
		return

	print("\n📖 Found %d prefabs in MaterialList" % material_map.size())

	# Get all prefab scenes
	var prefab_files = get_prefab_files()
	print("🔍 Found %d scene files" % prefab_files.size())

	print("\n============================================================")
	print("🚀 Starting batch processing...")
	print("============================================================\n")

	# Process each prefab
	for scene_path in prefab_files:
		var prefab_name = scene_path.get_file().get_basename()

		if material_map.has(prefab_name):
			process_scene(scene_path, prefab_name)
		else:
			print("⏭️  Skipping %s (not in MaterialList)" % prefab_name)

	print("\n============================================================")
	print("✨ Complete!")
	print("   Processed: %d" % processed_count)
	print("   Failed: %d" % failed_count)
	print("============================================================")

	# Refresh the file system to ensure changes are visible
	print("\n🔄 Refreshing file system...")
	EditorInterface.get_resource_filesystem().scan()
	print("✅ Done! You may need to reopen any currently open scenes to see changes.")

func parse_material_list() -> bool:
	var file = FileAccess.open(MATERIAL_LIST_PATH, FileAccess.READ)
	if not file:
		print("❌ Could not open MaterialList at: %s" % MATERIAL_LIST_PATH)
		return false

	var current_prefab = ""
	var current_mesh = ""

	while not file.eof_reached():
		var line = file.get_line().strip_edges()

		# Match prefab name
		if line.begins_with("Prefab Name: "):
			current_prefab = line.substr(13).strip_edges()
			if not material_map.has(current_prefab):
				material_map[current_prefab] = []

		# Match mesh name
		elif line.begins_with("Mesh Name: "):
			current_mesh = line.substr(11).strip_edges()

		# Match slot (texture)
		elif line.begins_with("Slot: ") and current_prefab != "" and current_mesh != "":
			var regex = RegEx.new()
			regex.compile("\\((.+)\\)")
			var result = regex.search(line)
			if result:
				var texture_name = result.get_string(1)
				material_map[current_prefab].append({
					"mesh": current_mesh,
					"texture": texture_name
				})

	file.close()
	return true

func get_prefab_files() -> Array:
	var files = []
	var dir = DirAccess.open(PREFABS_DIR)

	if not dir:
		print("❌ Could not open prefabs directory: %s" % PREFABS_DIR)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tscn"):
			files.append(PREFABS_DIR + "/" + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	return files

func process_scene(scene_path: String, prefab_name: String):
	print("\n📝 Processing: %s" % prefab_name)

	# Load the scene
	var scene = load(scene_path)
	if not scene:
		print("  ❌ Failed to load scene")
		failed_count += 1
		return

	var root = scene.instantiate()
	if not root:
		print("  ❌ Failed to instantiate scene")
		failed_count += 1
		return

	# Get texture mappings for this prefab
	var mappings = material_map[prefab_name]
	if mappings.is_empty():
		print("  ⚠️  No texture mappings found")
		return

	# Find all MeshInstance3D nodes
	var mesh_instances = find_mesh_instances(root)

	if mesh_instances.is_empty():
		print("  ⚠️  No MeshInstance3D nodes found")
		return

	# Apply textures to meshes
	var updated = false
	for mesh_instance in mesh_instances:
		# Use the first mapping (most prefabs have a single mesh)
		var texture_name = mappings[0]["texture"]
		var texture_path = find_texture_path(texture_name)

		print("  🎨 Applying texture: %s" % texture_name)

		if apply_texture_to_mesh(mesh_instance, texture_path):
			updated = true
		else:
			print("  ⚠️  Failed to apply texture")

	if updated:
		# Save the scene
		var packed_scene = PackedScene.new()
		var result = packed_scene.pack(root)

		if result == OK:
			result = ResourceSaver.save(packed_scene, scene_path)
			if result == OK:
				print("  ✅ Saved successfully")
				processed_count += 1
			else:
				print("  ❌ Failed to save scene")
				failed_count += 1
		else:
			print("  ❌ Failed to pack scene")
			failed_count += 1

	root.queue_free()

func find_mesh_instances(node: Node) -> Array:
	var instances = []

	if node is MeshInstance3D:
		instances.append(node)

	for child in node.get_children():
		instances.append_array(find_mesh_instances(child))

	return instances

func find_texture_path(texture_name: String) -> String:
	# Try main Textures folder
	var main_path = TEXTURES_DIR + "/" + texture_name + ".png"
	if FileAccess.file_exists(main_path):
		return main_path

	# Try Alts subfolder
	var alts_path = TEXTURES_DIR + "/Alts/" + texture_name + ".png"
	if FileAccess.file_exists(alts_path):
		return alts_path

	# Try FX_Textures subfolder
	var fx_path = TEXTURES_DIR + "/FX_Textures/" + texture_name + ".png"
	if FileAccess.file_exists(fx_path):
		return fx_path

	# Default to main path even if it doesn't exist
	return main_path

func apply_texture_to_mesh(mesh_instance: MeshInstance3D, texture_path: String) -> bool:
	# Load texture first
	var texture = load(texture_path)
	if not texture:
		print("  ⚠️  Could not load texture: %s" % texture_path)
		return false

	# Create new StandardMaterial3D
	var material = StandardMaterial3D.new()
	material.resource_name = "MI_PolygonSciFiSpace_01_A"
	material.roughness = 0.8
	material.albedo_texture = texture

	# Apply as material override (this ensures it's saved with the scene)
	mesh_instance.material_override = material

	print("  🎨 Texture applied: %s" % texture_path)
	return true
