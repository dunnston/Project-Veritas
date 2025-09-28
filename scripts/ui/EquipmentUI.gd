extends Control

signal equipment_slot_clicked(slot: String)
signal equipment_removed(slot: String)

@onready var equipment_slots: Dictionary = {}
@onready var stats_label: Label
@onready var close_button: Button

var slot_scenes: Dictionary = {}

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	setup_ui()
	connect_signals()
	
	EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	EquipmentManager.stats_updated.connect(_on_stats_updated)
	
	EventBus.equipment_ui_toggle_requested.connect(_on_toggle_requested)

func setup_ui():
	var panel = PanelContainer.new()
	panel.size = Vector2(600, 700)
	panel.position = Vector2(660, 50)
	add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "Equipment"
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	
	header.add_spacer(false)
	
	close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(_on_close_pressed)
	header.add_child(close_button)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var equipment_grid = GridContainer.new()
	equipment_grid.columns = 2
	equipment_grid.add_theme_constant_override("h_separation", 20)
	equipment_grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(equipment_grid)
	
	create_equipment_slots(equipment_grid)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	var stats_header = Label.new()
	stats_header.text = "Total Stats"
	stats_header.add_theme_font_size_override("font_size", 18)
	vbox.add_child(stats_header)
	
	stats_label = Label.new()
	stats_label.text = "No equipment bonuses"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stats_label)

func create_equipment_slots(parent: GridContainer):
	var slots = [
		{"id": "HEAD", "name": "Head"},
		{"id": "CHEST", "name": "Chest"},
		{"id": "PANTS", "name": "Pants"},
		{"id": "FEET", "name": "Feet"},
		{"id": "TRINKET_1", "name": "Trinket 1"},
		{"id": "TRINKET_2", "name": "Trinket 2"},
		{"id": "TRINKET_3", "name": "Trinket 3"},
		{"id": "BACKPACK", "name": "Backpack"}
	]
	
	for slot_data in slots:
		var slot_container = HBoxContainer.new()
		slot_container.custom_minimum_size = Vector2(250, 80)
		parent.add_child(slot_container)
		
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(80, 80)
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_button.expand_icon = true
		slot_button.pressed.connect(_on_slot_clicked.bind(slot_data.id))
		slot_container.add_child(slot_button)
		
		var info_vbox = VBoxContainer.new()
		slot_container.add_child(info_vbox)
		
		var slot_label = Label.new()
		slot_label.text = slot_data.name
		slot_label.add_theme_font_size_override("font_size", 14)
		info_vbox.add_child(slot_label)
		
		var item_label = Label.new()
		item_label.text = "Empty"
		item_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_label.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(item_label)
		
		var stats_label = Label.new()
		stats_label.text = ""
		stats_label.add_theme_font_size_override("font_size", 10)
		stats_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		info_vbox.add_child(stats_label)
		
		equipment_slots[slot_data.id] = {
			"button": slot_button,
			"item_label": item_label,
			"stats_label": stats_label
		}

func connect_signals():
	if GameManager:
		GameManager.state_changed.connect(_on_game_state_changed)

func _on_slot_clicked(slot: String):
	var equipment = EquipmentManager.get_equipped_item(slot)
	if equipment:
		if Input.is_action_pressed("sprint"):
			EquipmentManager.unequip_item(slot)
			equipment_removed.emit(slot)
		else:
			show_equipment_details(equipment)
	else:
		equipment_slot_clicked.emit(slot)

func _on_equipment_changed(slot: String, equipment: Equipment):
	if not equipment_slots.has(slot):
		return
	
	var slot_data = equipment_slots[slot]
	
	if equipment:
		slot_data.button.icon = equipment.icon
		slot_data.item_label.text = equipment.name
		slot_data.item_label.add_theme_color_override("font_color", get_tier_color(equipment.tier))
		
		var stats_text = ""
		for stat in equipment.stats:
			var value = equipment.stats[stat]
			if value is bool:
				if value:
					stats_text += stat.replace("_", " ").capitalize() + "\n"
			elif value is float or value is int:
				var display_value = value
				if stat.ends_with("_speed") or stat.ends_with("_regen"):
					display_value = str(value * 100) + "%"
				elif stat.ends_with("_resist") or stat.ends_with("_reduction"):
					display_value = str(value) + "%"
				else:
					display_value = str(value)
				
				var prefix = "+" if value > 0 else ""
				stats_text += stat.replace("_", " ").capitalize() + ": " + prefix + display_value + "\n"
		
		slot_data.stats_label.text = stats_text.strip_edges()
	else:
		slot_data.button.icon = null
		slot_data.item_label.text = "Empty"
		slot_data.item_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot_data.stats_label.text = ""

func _on_stats_updated(total_stats: Dictionary):
	if total_stats.is_empty():
		stats_label.text = "No equipment bonuses"
		return
	
	var stats_text = ""
	for stat in total_stats:
		var value = total_stats[stat]
		var display_name = stat.replace("_", " ").capitalize()
		
		if value is bool:
			if value:
				stats_text += display_name + "\n"
		elif value is float or value is int:
			var display_value = value
			if stat.ends_with("_speed") or stat.ends_with("_regen"):
				display_value = str(value * 100) + "%"
			elif stat.ends_with("_resist") or stat.ends_with("_reduction") or stat.ends_with("_bonus") or stat.ends_with("_efficiency"):
				display_value = str(value) + "%"
			else:
				display_value = str(value)
			
			var prefix = "+" if value > 0 else ""
			stats_text += display_name + ": " + prefix + display_value + "\n"
	
	stats_label.text = stats_text.strip_edges()

func get_tier_color(tier: int) -> Color:
	match tier:
		1:
			return Color(0.7, 0.7, 0.7)
		2:
			return Color(0.3, 0.8, 0.3)
		3:
			return Color(0.3, 0.5, 1.0)
		4:
			return Color(0.8, 0.3, 0.8)
		5:
			return Color(1.0, 0.7, 0.2)
		_:
			return Color.WHITE

func show_equipment_details(equipment: Equipment):
	var details_text = equipment.name + "\n"
	details_text += "Tier " + str(equipment.tier) + "\n\n"
	details_text += equipment.description + "\n\n"
	details_text += "Stats:\n" + equipment.get_formatted_stats()
	
	print(details_text)

func _on_close_pressed():
	hide_equipment()
	if GameManager.current_state == GameManager.GameState.INVENTORY:
		GameManager.change_state(GameManager.GameState.IN_GAME)

func _on_toggle_requested():
	visible = !visible

func _on_game_state_changed(old_state, new_state):
	if new_state == GameManager.GameState.INVENTORY:
		show_equipment()
	else:
		hide_equipment()

func show_equipment():
	visible = true
	refresh_all_slots()

func hide_equipment():
	visible = false

func refresh_all_slots():
	for slot in EquipmentManager.EQUIPMENT_SLOTS:
		var equipment = EquipmentManager.get_equipped_item(slot)
		_on_equipment_changed(slot, equipment)
