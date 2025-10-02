@tool
extends EditorScript

# Converts prefabs from assets/enviroment/desert/Prefabs/
# to inherited scenes in scenes/environment/desert/

const SOURCE_DIR = "res://assets/enviroment/desert/Prefabs/"
const TARGET_DIR = "res://scenes/environment/desert/"

func _run():
	print("=== Starting Prefab to Scene Conversion ===")

	# Create target directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scenes/environment"):
		dir.make_dir("scenes/environment")
	if not dir.dir_exists("scenes/environment/desert"):
		dir.make_dir("scenes/environment/desert")

	# Get all prefab files
	var prefab_files = get_all_files_in_directory(SOURCE_DIR, ".tscn")
	print("Found %d prefab files to convert" % prefab_files.size())

	var converted_count = 0
	var skipped_count = 0

	for prefab_path in prefab_files:
		var result = convert_prefab_to_scene(prefab_path)
		if result:
			converted_count += 1
		else:
			skipped_count += 1

	print("\n=== Conversion Complete ===")
	print("Converted: %d scenes" % converted_count)
	print("Skipped: %d scenes (already exist)" % skipped_count)
	print("Target directory: %s" % TARGET_DIR)

func convert_prefab_to_scene(prefab_path: String) -> bool:
	# Get filename without path
	var filename = prefab_path.get_file()
	var target_path = TARGET_DIR + filename

	# Skip if target already exists
	if FileAccess.file_exists(target_path):
		print("  Skipped: %s (already exists)" % filename)
		return false

	# Load the prefab scene
	var prefab_scene = load(prefab_path)
	if not prefab_scene:
		print("  Error: Could not load %s" % prefab_path)
		return false

	# Instance the prefab
	var instance = prefab_scene.instantiate()
	if not instance:
		print("  Error: Could not instantiate %s" % prefab_path)
		return false

	# Create a new packed scene with the instance
	var packed_scene = PackedScene.new()
	var result = packed_scene.pack(instance)

	if result != OK:
		print("  Error: Could not pack scene %s" % filename)
		instance.queue_free()
		return false

	# Save the new scene
	var save_result = ResourceSaver.save(packed_scene, target_path)

	if save_result != OK:
		print("  Error: Could not save %s" % target_path)
		instance.queue_free()
		return false

	instance.queue_free()
	print("  Converted: %s" % filename)
	return true

func get_all_files_in_directory(path: String, extension: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)

	if not dir:
		print("Error: Could not open directory %s" % path)
		return files

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if extension == "" or file_name.ends_with(extension):
				files.append(path + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()
	return files
