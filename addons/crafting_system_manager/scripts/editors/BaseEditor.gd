@tool
extends Control
class_name BaseEditor

# Base class for all editor tabs - provides common CRUD functionality

# Signals
signal data_changed()

# Data storage - to be overridden by child classes
var data: Dictionary = {}
var selected_id: String = ""

# UI references - to be set by child classes
var items_list: VBoxContainer
var editor_container: Control
var search_field: LineEdit

# Virtual methods - to be implemented by child classes
func get_data_file_path() -> String:
	push_error("get_data_file_path() must be implemented by child class")
	return ""

func get_editor_title() -> String:
	push_error("get_editor_title() must be implemented by child class")
	return "Editor"

func create_form_fields(form_container: VBoxContainer) -> void:
	push_error("create_form_fields() must be implemented by child class")

func load_item_into_form(item_id: String) -> void:
	push_error("load_item_into_form() must be implemented by child class")

func save_form_data() -> Dictionary:
	push_error("save_form_data() must be implemented by child class")
	return {}

func clear_form() -> void:
	push_error("clear_form() must be implemented by child class")

func get_item_display_name(item_id: String) -> String:
	var item_data = data.get(item_id, {})
	return item_data.get("name", item_id)

# Common functionality
func _ready():
	create_ui()
	load_data()
	update_items_list()

func create_ui():
	var main_container = HSplitContainer.new()
	main_container.name = "MainContainer"
	add_child(main_container)
	
	# Left panel - items list
	create_items_list_panel(main_container)
	
	# Right panel - editor
	create_editor_panel(main_container)

func create_items_list_panel(parent: Control):
	var left_panel = VBoxContainer.new()
	left_panel.name = "ItemsList"
	left_panel.set_custom_minimum_size(Vector2(300, 0))
	parent.add_child(left_panel)
	
	# Search field
	var search_label = Label.new()
	search_label.text = "Search:"
	left_panel.add_child(search_label)
	
	search_field = LineEdit.new()
	search_field.name = "SearchField"
	search_field.placeholder_text = "Filter items..."
	search_field.text_changed.connect(_on_search_changed)
	left_panel.add_child(search_field)
	var items_scroll = ScrollContainer.new()
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(items_scroll)
	items_list = VBoxContainer.new()
	items_list.name = "ItemsList"
	items_scroll.add_child(items_list)

func create_editor_panel(parent: Control):
	var right_panel = VBoxContainer.new()
	right_panel.name = "Editor"
	right_panel.set_custom_minimum_size(Vector2(400, 0))
	parent.add_child(right_panel)
	
	# Editor title
	var editor_title = Label.new()
	editor_title.text = get_editor_title()
	editor_title.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(editor_title)
	
	# Buttons container
	var buttons_container = HBoxContainer.new()
	right_panel.add_child(buttons_container)
	
	var add_button = Button.new()
	add_button.text = "Add New"
	add_button.pressed.connect(_on_add_pressed)
	buttons_container.add_child(add_button)
	
	var edit_button = Button.new()
	edit_button.text = "Edit Selected"
	edit_button.pressed.connect(_on_edit_pressed)
	buttons_container.add_child(edit_button)
	
	var delete_button = Button.new()
	delete_button.text = "Delete Selected"
	delete_button.pressed.connect(_on_delete_pressed)
	buttons_container.add_child(delete_button)
	
	# Save button - moved to top for visibility
	var save_button = Button.new()
	save_button.text = "Save Changes"
	save_button.pressed.connect(_on_save_pressed)
	buttons_container.add_child(save_button)
	
	# Form container
	var form_container = VBoxContainer.new()
	form_container.name = "FormContainer"
	right_panel.add_child(form_container)
	
	# Let child class create specific form fields
	create_form_fields(form_container)
	
	editor_container = right_panel

# CRUD operations
func _on_add_pressed():
	clear_form()
	selected_id = ""

func _on_edit_pressed():
	if selected_id == "":
		return
	load_item_into_form(selected_id)

func _on_delete_pressed():
	if selected_id == "":
		return
	if data.has(selected_id):
		data.erase(selected_id)
		update_items_list()
		clear_form()
		selected_id = ""

func _on_save_pressed():
	var form_data = save_form_data()
	if form_data.is_empty():
		return
	
	var id_field = editor_container.find_child("IdField", true, false)
	if not id_field:
		id_field = _find_child_recursive(editor_container, "IdField")
	
	if not id_field:
		return
	
	var item_id = id_field.text.strip_edges()
	
	# If no ID (new item), generate one
	if item_id == "":
		item_id = generate_new_id(form_data.get("name", "NEW_ITEM"))
		id_field.text = item_id
	
	# Save to data
	data[item_id] = form_data
	selected_id = item_id
	
	# Update UI
	update_items_list()
	save_data()

func _on_item_selected(item_id: String):
	selected_id = item_id
	load_item_into_form(item_id)

# ID generation
func generate_new_id(item_name: String) -> String:
	# Convert name to uppercase snake_case ID
	var base_id = item_name.strip_edges().to_upper().replace(" ", "_").replace("-", "_")
	
	# Remove any non-alphanumeric characters except underscores
	var clean_id = ""
	for char in base_id:
		if char.is_valid_identifier() or char == "_":
			clean_id += char
	
	# Ensure ID starts with a letter
	if clean_id.length() > 0 and not clean_id[0].is_valid_identifier():
		clean_id = "ITEM_" + clean_id
	
	# If still empty, use default
	if clean_id == "":
		clean_id = "NEW_ITEM"
	
	# Make sure ID is unique
	var final_id = clean_id
	var counter = 1
	while data.has(final_id):
		final_id = clean_id + "_" + str(counter)
		counter += 1
	
	return final_id

# Data operations
func load_data():
	var file_path = get_data_file_path()
	if file_path == "":
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var json_data = json.data
			# Handle different JSON structures
			if json_data.has("equipment_items"):
				data = json_data["equipment_items"]
			elif json_data.has("weapons"):
				data = json_data["weapons"]
			else:
				data = json_data
		else:
			pass
	else:
		pass

func save_data():
	var file_path = get_data_file_path()
	if file_path == "":
		return
	
	var output_data: Dictionary
	# Handle different JSON structures based on file type
	if file_path.ends_with("equipment.json"):
		output_data = {"equipment_items": data, "equipment_slots": {}}
	elif file_path.ends_with("weapons.json"):
		output_data = {"weapons": data, "ammo_items": {}}
	else:
		output_data = data
	
	var json_output = JSON.stringify(output_data, "\t")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_output)
		file.close()
	else:
		pass

# Search functionality
func _on_search_changed(search_text: String):
	update_items_list()

func get_search_filter() -> String:
	if search_field:
		var filter_text = search_field.text.strip_edges().to_lower()
		return filter_text
	return ""

func matches_search_filter(item_id: String, search_filter: String) -> bool:
	if search_filter == "":
		return true
	
	var item_data = data.get(item_id, {})
	var search_targets = [
		item_id.to_lower(),
		item_data.get("name", "").to_lower(),
		item_data.get("description", "").to_lower(),
		item_data.get("category", "").to_lower()
	]
	
	for target in search_targets:
		if target.contains(search_filter):
			return true
	
	return false

# UI updates
func update_items_list():
	print("Updating items list...")
	if not items_list:
		print("Items list not found!")
		return
	
	print("Clearing existing items...")
	# Clear existing items
	for child in items_list.get_children():
		child.queue_free()
	
	var search_filter = get_search_filter()
	print("Adding items to list. Data size: ", data.size(), ", Search filter: '", search_filter, "'")
	
	# Add items (filtered by search)
	var filtered_count = 0
	for item_id in data:
		if matches_search_filter(item_id, search_filter):
			var button = Button.new()
			button.text = get_item_display_name(item_id)
			button.pressed.connect(_on_item_selected.bind(item_id))
			items_list.add_child(button)
			filtered_count += 1
	
	print("Added ", filtered_count, " filtered items")

# Helper functions for child classes
func create_text_field(container: Control, label_text: String, field_name: String, placeholder: String = "", disabled: bool = false) -> LineEdit:
	print("Creating text field: ", label_text)
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	var field = LineEdit.new()
	field.name = field_name
	field.placeholder_text = placeholder
	field.editable = not disabled
	if disabled:
		field.modulate = Color(0.7, 0.7, 0.7)  # Gray out disabled field
	container.add_child(field)
	
	return field

func create_text_area(container: Control, label_text: String, field_name: String, min_height: int = 60) -> TextEdit:
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	var field = TextEdit.new()
	field.name = field_name
	field.set_custom_minimum_size(Vector2(0, min_height))
	container.add_child(field)
	
	return field

func create_number_field(container: Control, label_text: String, field_name: String, min_val: float = 0, max_val: float = 999, default_val: float = 0) -> SpinBox:
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	var field = SpinBox.new()
	field.name = field_name
	field.min_value = min_val
	field.max_value = max_val
	field.value = default_val
	container.add_child(field)
	
	return field

func create_dropdown(container: Control, label_text: String, field_name: String, options: Array) -> OptionButton:
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	var field = OptionButton.new()
	field.name = field_name
	for option in options:
		field.add_item(str(option))
	container.add_child(field)
	
	return field

func create_file_field(container: Control, label_text: String, field_name: String, file_filter: String = "*.png,*.jpg,*.jpeg") -> Control:
	var label = Label.new()
	label.text = label_text + ":"
	container.add_child(label)
	
	var file_container = HBoxContainer.new()
	file_container.name = field_name + "Container"
	container.add_child(file_container)
	
	# Text field to show selected file
	var field = LineEdit.new()
	field.name = field_name
	field.placeholder_text = "Select a file..."
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	file_container.add_child(field)
	
	# Browse button
	var browse_button = Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_on_browse_file_pressed.bind(field, file_filter))
	file_container.add_child(browse_button)
	
	return file_container

func _on_browse_file_pressed(field: LineEdit, file_filter: String):
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	
	# Set file filters
	var filters = file_filter.split(",")
	for filter in filters:
		file_dialog.add_filter(filter, filter.replace("*.", "").to_upper() + " files")
	
	# Add to this control's scene tree
	add_child(file_dialog)
	
	# Connect file selected signal
	file_dialog.file_selected.connect(_on_file_selected.bind(field, file_dialog))
	file_dialog.canceled.connect(_on_file_dialog_canceled.bind(file_dialog))
	
	# Show dialog
	file_dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected(field: LineEdit, file_dialog: FileDialog, path: String):
	# Convert absolute path to relative resource path
	var resource_path = path
	if path.begins_with(ProjectSettings.globalize_path("res://")):
		var base_path = ProjectSettings.globalize_path("res://")
		resource_path = "res://" + path.right(-base_path.length())
	
	# Get just the filename without extension for the icon field
	var filename = resource_path.get_file().get_basename()
	field.text = filename
	
	file_dialog.queue_free()

func _on_file_dialog_canceled(file_dialog: FileDialog):
	file_dialog.queue_free()

func get_field_value(field_name: String):
	var field = editor_container.find_child(field_name, true, false)
	
	if not field:
		# Try a more thorough search
		field = _find_child_recursive(editor_container, field_name)
	
	if not field:
		return null
	
	
	if field is LineEdit:
		var value = field.text.strip_edges()
		return value
	elif field is TextEdit:
		var value = field.text.strip_edges()
		return value
	elif field is SpinBox:
		var value = field.value
		return value
	elif field is OptionButton:
		var value = field.get_item_text(field.selected) if field.selected >= 0 else ""
		return value
	
	return null

func _find_child_recursive(parent: Node, child_name: String) -> Node:
	for child in parent.get_children():
		if child.name == child_name:
			return child
		var found = _find_child_recursive(child, child_name)
		if found:
			return found
	return null

func set_field_value(field_name: String, value):
	var field = editor_container.find_child(field_name, true, false)
	if not field:
		field = _find_child_recursive(editor_container, field_name)
	if not field:
		return
	
	if field is LineEdit:
		field.text = str(value)
	elif field is TextEdit:
		field.text = str(value)
	elif field is SpinBox:
		field.value = value
	elif field is OptionButton:
		var text = str(value)
		for i in range(field.get_item_count()):
			if field.get_item_text(i) == text:
				field.selected = i
				break