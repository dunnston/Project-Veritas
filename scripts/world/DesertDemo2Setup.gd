extends Node3D

# Setup script for Desert_Demo_Scene2
# This script dynamically adds player, camera, and UI to the scene

func _ready():
	# Add ground collision first
	add_ground_collision()

	# Add player
	var player_scene = load("res://scenes/player/player_procedural.tscn")
	var player = player_scene.instantiate()
	player.name = "PlayerMixamo"
	player.position = Vector3(0, 2, 0)
	add_child(player)

	# Add UI Canvas Layer
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	add_child(ui_layer)

	# Add HUD
	var hud_scene = load("res://scenes/ui/HUD.tscn")
	var hud = hud_scene.instantiate()
	hud.name = "HUD"
	ui_layer.add_child(hud)

	# Add Hotbar
	var hotbar_scene = load("res://scenes/ui/Hotbar.tscn")
	var hotbar = hotbar_scene.instantiate()
	hotbar.name = "Hotbar"
	ui_layer.add_child(hotbar)

	# Add InventoryUI
	var inventory_scene = load("res://scenes/ui/InventoryUI.tscn")
	var inventory = inventory_scene.instantiate()
	inventory.name = "InventoryUI"
	ui_layer.add_child(inventory)

	# Add StorageUI
	var storage_scene = load("res://scenes/ui/StorageUI.tscn")
	var storage = storage_scene.instantiate()
	storage.name = "StorageUI"
	ui_layer.add_child(storage)

	# Add CombatHUD
	var combat_scene = load("res://scenes/ui/CombatHUD.tscn")
	var combat = combat_scene.instantiate()
	combat.name = "CombatHUD"
	ui_layer.add_child(combat)

	# Add DevMenu
	var devmenu_scene = load("res://scenes/ui/DevMenu.tscn")
	var devmenu = devmenu_scene.instantiate()
	devmenu.name = "DevMenu"
	ui_layer.add_child(devmenu)

	# Add BuildMenu
	var buildmenu_scene = load("res://scenes/ui/BuildMenu.tscn")
	var buildmenu = buildmenu_scene.instantiate()
	buildmenu.name = "BuildMenu"
	ui_layer.add_child(buildmenu)

	# Add AttributesUI
	var attributes_scene = load("res://scenes/ui/AttributesUI.tscn")
	var attributes = attributes_scene.instantiate()
	attributes.name = "AttributesUI"
	ui_layer.add_child(attributes)

	# Add EquipedWeaponUI
	var weapon_scene = load("res://scenes/ui/EquipedWeaponUI.tscn")
	var weapon = weapon_scene.instantiate()
	weapon.name = "EquipedWeaponUI"
	ui_layer.add_child(weapon)

	# Add GeneratorMenu
	var generator_scene = load("res://scenes/ui/GeneratorMenu.tscn")
	var generator = generator_scene.instantiate()
	generator.name = "GeneratorMenu"
	ui_layer.add_child(generator)

	# Add SkillDebugUI
	var skill_scene = load("res://scenes/ui/SkillDebugUI.tscn")
	var skill = skill_scene.instantiate()
	skill.name = "SkillDebugUI"
	ui_layer.add_child(skill)

	# Add WorkbenchCraftingMenu
	var workbench_scene = load("res://scenes/ui/WorkbenchCraftingMenu.tscn")
	var workbench = workbench_scene.instantiate()
	workbench.name = "WorkbenchCraftingMenu"
	ui_layer.add_child(workbench)

	print("Desert Demo Scene 2 setup complete - Player, Camera, and UI added")

func add_ground_collision():
	# Create a large ground plane with collision
	var ground = StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)

	# Add collision shape
	var collision = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(2000, 1, 2000)  # Large flat plane
	collision.shape = box_shape
	collision.position = Vector3(0, -0.5, 0)  # Half below ground level
	ground.add_child(collision)

	# Add visual mesh (optional, for debugging)
	var mesh_instance = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(2000, 2000)
	mesh_instance.mesh = plane_mesh
	mesh_instance.position = Vector3(0, 0, 0)
	ground.add_child(mesh_instance)

	# Apply a simple material so we can see it
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.7, 0.5)  # Sandy color
	mesh_instance.material_override = material

	print("Ground collision added at Y=0 with 2000x2000 size")
