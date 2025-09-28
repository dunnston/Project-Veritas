extends Control
class_name RoofDebugUI

@onready var debug_panel: PanelContainer = $DebugPanel
@onready var info_label: RichTextLabel = $DebugPanel/VBoxContainer/InfoLabel
@onready var toggle_button: Button = $DebugPanel/VBoxContainer/HBoxContainer/ToggleVisibilityButton
@onready var refresh_button: Button = $DebugPanel/VBoxContainer/HBoxContainer/RefreshButton
@onready var test_button: Button = $DebugPanel/VBoxContainer/HBoxContainer/TestButton

var is_visible: bool = false

func _ready():
	visible = false
	
	# Connect buttons
	toggle_button.pressed.connect(_on_toggle_visibility_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	test_button.pressed.connect(_on_test_pressed)
	
	# Update every second
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(update_debug_info)
	add_child(timer)
	timer.start()

func _input(event: InputEvent):
	# Changed from R key to F3 to avoid conflict with ammo selection
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		toggle_debug_panel()
		get_viewport().set_input_as_handled()

func toggle_debug_panel():
	is_visible = not is_visible
	visible = is_visible
	
	if is_visible:
		update_debug_info()

func update_debug_info():
	if not visible:
		return
		
	var info_text = "[b]SHELTER DEBUG (Press R to toggle)[/b]\n\n"
	
	# Interior detection status
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system:
		var is_inside = interior_system.is_player_inside()
		var current_building = interior_system.get_current_building_id()
		
		info_text += "[color=cyan]PLAYER STATUS:[/color]\n"
		info_text += "  Inside Building: [color=%s]%s[/color]\n" % ["green" if is_inside else "red", is_inside]
		
		if is_inside:
			info_text += "  Building ID: [color=yellow]%s[/color]\n" % current_building
			
			var building_data = interior_system.get_building_data(current_building)
			if not building_data.is_empty():
				var complete_color = "green" if building_data.is_complete else "red"
				info_text += "  Complete Structure: [color=%s]%s[/color]\n" % [complete_color, building_data.is_complete]
				info_text += "  Floor Tiles: %d\n" % building_data.floor_positions.size()
				info_text += "  Wall Coverage: %d/%d\n" % [building_data.wall_coverage, building_data.required_walls.size()]
				info_text += "  Roof Coverage: %d/%d\n" % [building_data.roof_coverage, building_data.required_roofs.size()]
				info_text += "  Doors: %d\n" % building_data.door_count
		
		info_text += "\n[color=cyan]BUILDINGS DETECTED:[/color] %d\n" % interior_system.building_structures.size()
	else:
		info_text += "[color=red]Interior Detection: NOT WORKING[/color]\n"
	
	# Storm protection status
	var shelter_system = get_node_or_null("/root/ShelterSystem")
	if shelter_system:
		var protection = shelter_system.get_shelter_protection_multiplier() * 100
		var protection_color = "green" if protection >= 75 else ("yellow" if protection >= 25 else "red")
		info_text += "\n[color=cyan]STORM PROTECTION:[/color]\n"
		info_text += "  Protection Level: [color=%s]%.1f%%[/color]\n" % [protection_color, protection]
		info_text += "  Quality: [color=yellow]%s[/color]\n" % shelter_system.get_current_shelter_quality()
	else:
		info_text += "\n[color=red]Storm Protection: NOT WORKING[/color]\n"
	
	# Roof visibility status
	var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
	if roof_manager:
		var roof_count = roof_manager.get_roof_count()
		var opacity = roof_manager.get_current_opacity()
		var opacity_color = "green" if opacity < 0.1 else ("yellow" if opacity < 0.9 else "red")
		
		info_text += "\n[color=cyan]ROOF VISIBILITY:[/color]\n"
		info_text += "  Roof Tiles: %d\n" % roof_count
		info_text += "  Opacity: [color=%s]%.2f[/color] (0=hidden, 1=visible)\n" % [opacity_color, opacity]
	else:
		info_text += "\n[color=red]Roof Visibility: NOT WORKING[/color]\n"
	
	# Storm status
	var storm_system = get_node_or_null("/root/StormSystem")
	if storm_system:
		info_text += "\n[color=cyan]STORM STATUS:[/color]\n"
		info_text += "  Active: [color=yellow]%s[/color]\n" % storm_system.current_storm_active
	
	info_label.text = info_text

func _on_toggle_visibility_pressed():
	var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
	if roof_manager:
		var current_opacity = roof_manager.get_current_opacity()
		print("DEBUG: Toggle pressed - current opacity: %.2f" % current_opacity)
		if current_opacity > 0.5:
			print("DEBUG: Setting to HIDDEN")
			roof_manager.set_roof_visibility_state(roof_manager.VisibilityState.HIDDEN)
		else:
			print("DEBUG: Setting to VISIBLE")
			roof_manager.set_roof_visibility_state(roof_manager.VisibilityState.VISIBLE)

func _on_refresh_pressed():
	var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
	if roof_manager:
		roof_manager.force_refresh_roofs()
	
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system:
		interior_system.refresh_building_structures()
	
	update_debug_info()

func _on_test_pressed():
	print("=== ROOF DEBUG TEST ===")
	
	var interior_system = get_node_or_null("/root/InteriorDetectionSystem")
	if interior_system:
		print("Interior Detection:")
		print("  Player inside: %s" % interior_system.is_player_inside())
		print("  Current building: %s" % interior_system.get_current_building_id())
		print("  Total buildings: %d" % interior_system.building_structures.size())
		
		for building_id in interior_system.building_structures.keys():
			var data = interior_system.building_structures[building_id]
			print("  Building %s: Complete=%s, Floors=%d" % [building_id, data.is_complete, data.floor_positions.size()])
	
	var roof_manager = get_node_or_null("/root/RoofVisibilityManager")
	if roof_manager:
		print("Roof Visibility:")
		print("  Roof count: %d" % roof_manager.get_roof_count())
		print("  Current opacity: %.2f" % roof_manager.get_current_opacity())
		print("  Roof positions: %s" % roof_manager.get_roof_positions())
		
		# Test immediate visibility change
		print("TEST: Forcing immediate visibility to 0.0")
		roof_manager.force_immediate_visibility(0.0)
		
		# Wait a bit then restore
		await get_tree().create_timer(2.0).timeout
		print("TEST: Forcing immediate visibility to 1.0")
		roof_manager.force_immediate_visibility(1.0)
	
	print("=== END DEBUG TEST ===")
