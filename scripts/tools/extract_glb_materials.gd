@tool
extends EditorScript

# Extracts materials from GLB files so they persist at runtime
# Run this script to fix missing textures in the desert scene

const GLB_DIR = "res://assets/enviroment/desert/Biomes/PNB_Arid_Desert/Models/"

func _run():
	print("=== Extracting Materials from GLB Files ===")

	var glb_files = []
	glb_files.append_array(get_all_files_in_directory(GLB_DIR + "Environment/", ".glb"))
	glb_files.append_array(get_all_files_in_directory(GLB_DIR + "Props/", ".glb"))

	print("Found %d GLB files" % glb_files.size())

	var processed = 0

	for glb_path in glb_files:
		if extract_materials_from_glb(glb_path):
			processed += 1

	print("\n=== Extraction Complete ===")
	print("Processed: %d GLB files" % processed)
	print("\nNow reimport the GLB files:")
	print("1. Select all .glb files in FileSystem")
	print("2. Right-click > Reimport")

func extract_materials_from_glb(glb_path: String) -> bool:
	# Check if already has .import file
	var import_path = glb_path + ".import"

	if not FileAccess.file_exists(import_path):
		print("  No import file: %s" % glb_path.get_file())
		return false

	# Read the import file
	var import_file = FileAccess.open(import_path, FileAccess.READ)
	if not import_file:
		return false

	var import_content = import_file.get_as_text()
	import_file.close()

	# Check if materials are already being extracted
	if "_subresources" in import_content:
		# Already configured
		return false

	# Update import file to extract materials
	# Add material extraction settings
	var new_content = import_content

	# Add subresources section if it doesn't exist
	if not "[params]" in new_content:
		new_content += "\n[params]\n"

	# Find the [params] section and add material settings
	new_content = new_content.replace(
		"[params]",
		"[params]\nmeshes/ensure_tangents=true\nmeshes/generate_lods=true\nmeshes/create_shadow_meshes=true\nmeshes/light_baking=1\nmeshes/lightmap_texel_size=0.2"
	)

	# Write back
	var write_file = FileAccess.open(import_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_content)
		write_file.close()
		print("  Updated: %s" % glb_path.get_file())
		return true

	return false

func get_all_files_in_directory(path: String, extension: String = "") -> Array[String]:
	var files: Array[String] = []
	var dir = DirAccess.open(path)

	if not dir:
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
