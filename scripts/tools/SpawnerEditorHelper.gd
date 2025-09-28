@tool
extends EditorScript
## Editor helper for visualizing and configuring enemy spawners

func _run():
	var editor_selection = EditorInterface.get_selection()
	var selected_nodes = editor_selection.get_selected_nodes()

	if selected_nodes.is_empty():
		print("Please select one or more EnemySpawner nodes")
		return

	for node in selected_nodes:
		if node is EnemySpawner:
			enhance_spawner_visualization(node)

func enhance_spawner_visualization(spawner: EnemySpawner):
	"""Add enhanced visualization to spawner in editor"""
	print("Enhancing spawner visualization for: ", spawner.name)

	# Create or update visual indicators
	var icon = spawner.get_node_or_null("EditorIcon")
	if not icon:
		icon = Sprite2D.new()
		icon.name = "EditorIcon"
		spawner.add_child(icon)
		icon.owner = spawner.get_tree().edited_scene_root

	# Set icon appearance
	var icon_texture = create_spawner_icon()
	icon.texture = icon_texture
	icon.modulate = Color(1.0, 0.5, 0.0, 0.8)

	# Update label
	var label = spawner.get_node_or_null("Label")
	if not label:
		label = Label.new()
		label.name = "Label"
		spawner.add_child(label)
		label.owner = spawner.get_tree().edited_scene_root

	label.text = "Spawner\nMax: %d\nRate: %.1fs" % [spawner.max_concurrent_enemies, spawner.spawn_frequency]
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(-30, -60)

	print("Spawner visualization enhanced")

func create_spawner_icon() -> ImageTexture:
	"""Create a simple icon texture for the spawner"""
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	# Draw a simple spawner icon (circle with plus sign)
	for x in range(32):
		for y in range(32):
			var center = Vector2(16, 16)
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)

			# Outer circle
			if dist >= 14 and dist <= 16:
				image.set_pixel(x, y, Color.ORANGE)
			# Plus sign horizontal
			elif y >= 15 and y <= 17 and x >= 8 and x <= 24:
				image.set_pixel(x, y, Color.ORANGE)
			# Plus sign vertical
			elif x >= 15 and x <= 17 and y >= 8 and y <= 24:
				image.set_pixel(x, y, Color.ORANGE)

	var texture = ImageTexture.create_from_image(image)
	return texture