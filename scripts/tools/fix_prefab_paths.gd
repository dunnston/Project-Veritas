@tool
extends EditorScript

# Fixes incorrect paths in desert prefab files
# Changes res://Biomes/ to res://assets/enviroment/desert/Biomes/

const PREFAB_DIR = "res://assets/enviroment/desert/Prefabs/"

func _run():
	print("=== Fixing Prefab Paths ===")

	var prefab_files = get_all_files_in_directory(PREFAB_DIR, ".tscn")
	print("Found %d prefab files" % prefab_files.size())

	var fixed_count = 0

	for prefab_path in prefab_files:
		if fix_prefab_paths(prefab_path):
			fixed_count += 1

	print("\n=== Path Fixing Complete ===")
	print("Fixed: %d prefab files" % fixed_count)

func fix_prefab_paths(prefab_path: String) -> bool:
	# Read the file
	var file = FileAccess.open(prefab_path, FileAccess.READ)
	if not file:
		print("  Error: Could not open %s" % prefab_path)
		return false

	var content = file.get_as_text()
	file.close()

	# Check if needs fixing
	if not "res://Biomes/" in content:
		return false  # Already correct

	# Fix the paths
	var new_content = content.replace(
		"res://Biomes/",
		"res://assets/enviroment/desert/Biomes/"
	)

	# Write back
	var write_file = FileAccess.open(prefab_path, FileAccess.WRITE)
	if not write_file:
		print("  Error: Could not write %s" % prefab_path)
		return false

	write_file.store_string(new_content)
	write_file.close()

	print("  Fixed: %s" % prefab_path.get_file())
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
