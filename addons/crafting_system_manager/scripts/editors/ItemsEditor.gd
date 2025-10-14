@tool
extends BaseEditor
class_name ItemsEditor

# Items/Resources editor - handles CRUD operations for game items

func get_data_file_path() -> String:
	return "res://data/resources.json"

func get_editor_title() -> String:
	return "Items Editor"

func create_form_fields(form_container: VBoxContainer) -> void:
	# ID field (disabled - auto-generated)
	create_text_field(form_container, "Item ID (Auto-generated)", "IdField", "Auto-generated from name", true)
	
	# Name field
	create_text_field(form_container, "Display Name", "NameField", "Item Name")
	
	# Description field
	create_text_area(form_container, "Description", "DescriptionField", 80)
	
	# Category field
	var categories = ["organic", "material", "consumable", "tool", "component", "power", "equipment"]
	create_dropdown(form_container, "Category", "CategoryField", categories)
	
	# Stack size field
	create_number_field(form_container, "Stack Size", "StackSizeField", 1, 999, 50)
	
	# Icon field (with file browser)
	create_file_field(form_container, "Icon", "IconField", "*.png,*.jpg,*.jpeg,*.svg")

func load_item_into_form(item_id: String) -> void:
	var item_data = data.get(item_id, {})
	
	set_field_value("IdField", item_id)
	set_field_value("NameField", item_data.get("name", ""))
	set_field_value("DescriptionField", item_data.get("description", ""))
	set_field_value("CategoryField", item_data.get("category", "material"))
	set_field_value("StackSizeField", item_data.get("stack_size", 50.0))
	set_field_value("IconField", item_data.get("icon", ""))

func save_form_data() -> Dictionary:
	var name_val = get_field_value("NameField")
	var desc_val = get_field_value("DescriptionField")
	var cat_val = get_field_value("CategoryField")
	var stack_val = get_field_value("StackSizeField")
	var icon_val = get_field_value("IconField")
	
	var item_data = {
		"name": name_val,
		"description": desc_val,  
		"category": cat_val,
		"stack_size": stack_val,
		"icon": icon_val
	}
	
	# Validate required fields
	if name_val == "" or name_val == null:
		return {}
	
	return item_data

func clear_form() -> void:
	set_field_value("IdField", "")
	set_field_value("NameField", "")
	set_field_value("DescriptionField", "")
	set_field_value("CategoryField", "material")
	set_field_value("StackSizeField", 50.0)
	set_field_value("IconField", "")