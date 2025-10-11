@tool
extends EditorPlugin

var dock_instance

func _enter_tree():
	print("Crafting System Manager: Loading...")
	
	# Load the modular dock
	print("Creating dock instance...")
	dock_instance = preload("res://addons/crafting_system_manager/scripts/CraftingManagerDock.gd").new()
	print("Dock instance created successfully")
	
	print("Adding dock to editor...")
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, dock_instance)
	print("Dock added to editor")
	
	print("Crafting System Manager: Plugin enabled successfully")

func _exit_tree():
	print("Crafting System Manager: Disabling...")
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
		dock_instance = null
	print("Crafting System Manager: Plugin disabled")