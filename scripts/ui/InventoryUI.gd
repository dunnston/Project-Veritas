extends Control
class_name InventoryUI

@onready var inventory_panel: NinePatchRect = $InventoryPanel
@onready var equipment_panel: NinePatchRect = $EquipmentPanel
@onready var grid_container: GridContainer = $InventoryPanel/GridContainer
@onready var close_button: TextureButton = $InventoryPanel/CloseButton
@onready var item_info_label: RichTextLabel = $InventoryPanel/ItemInfoPanel/ItemInfoLabel

var inventory_system: Node
var inventory_slots_ui: Array[InventorySlotUI] = []
var equipment_slots_ui: Dictionary = {}

class EquipmentSlotUI:
	var background: TextureRect
	var icon: TextureRect
	var slot_type: String
	var equipped_item: Equipment
	
	func _init(slot_name: String, background_node: TextureRect):
		slot_type = slot_name
		background = background_node
		setup_ui()
	
	func setup_ui():
		# Create icon display for equipment
		icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.anchor_left = 0.5
		icon.anchor_top = 0.5
		icon.anchor_right = 0.5
		icon.anchor_bottom = 0.5
		icon.offset_left = -20
		icon.offset_top = -20
		icon.offset_right = 20
		icon.offset_bottom = 20
		icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		background.add_child(icon)
		
		# Connect mouse events
		background.gui_input.connect(_on_equipment_slot_input)
		background.mouse_entered.connect(_on_equipment_slot_mouse_entered)
		background.mouse_exited.connect(_on_equipment_slot_mouse_exited)
	
	func _on_equipment_slot_input(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				InventoryUI.instance._on_equipment_slot_clicked(slot_type)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				InventoryUI.instance._on_equipment_slot_right_clicked(slot_type)
	
	func _on_equipment_slot_mouse_entered():
		if InventoryUI.instance:
			InventoryUI.instance.show_equipment_info(slot_type)
	
	func _on_equipment_slot_mouse_exited():
		if InventoryUI.instance:
			InventoryUI.instance.hide_item_info()
	
	func update_display(equipment: Equipment):
		equipped_item = equipment
		if equipment:
			icon.texture = equipment.icon
		else:
			icon.texture = null

class InventorySlotUI:
	var panel: PanelContainer
	var icon: TextureRect
	var quantity_label: Label
	var slot_index: int
	
	func _init(index: int):
		slot_index = index
		setup_ui()
	
	func setup_ui():
		# Create panel container for the slot
		panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(64, 64)
		
		# Create icon display
		icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(icon)
		
		# Create quantity label
		quantity_label = Label.new()
		quantity_label.anchor_left = 1.0
		quantity_label.anchor_top = 1.0
		quantity_label.anchor_right = 1.0
		quantity_label.anchor_bottom = 1.0
		quantity_label.offset_left = -20
		quantity_label.offset_top = -15
		quantity_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		quantity_label.size_flags_vertical = Control.SIZE_SHRINK_END
		quantity_label.add_theme_color_override("font_color", Color.WHITE)
		quantity_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		quantity_label.add_theme_constant_override("shadow_offset_x", 1)
		quantity_label.add_theme_constant_override("shadow_offset_y", 1)
		panel.add_child(quantity_label)
		
		# Connect mouse events
		panel.gui_input.connect(_on_slot_input)
		panel.mouse_entered.connect(_on_slot_mouse_entered)
		panel.mouse_exited.connect(_on_slot_mouse_exited)
	
	func _on_slot_input(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# Check if storage is open - if so, transfer to storage instead of normal click
				if StorageUI.instance and StorageUI.instance.visible:
					InventoryUI.instance.transfer_item_to_storage(slot_index)
				elif event.shift_pressed:
					# Shift+click to add to hotbar
					InventoryUI.instance.add_item_to_hotbar(slot_index)
				elif event.ctrl_pressed:
					# Ctrl+click to try to equip item
					InventoryUI.instance.try_equip_item_from_slot(slot_index)
				else:
					# Check if this is a tool - if so, equip it directly
					var slot = InventoryUI.instance.inventory_system.inventory_slots[slot_index]
					if not slot.is_empty() and EquipmentManager.equipment_data.has(slot.item_id):
						var equipment_data = EquipmentManager.equipment_data[slot.item_id]
						if equipment_data.get("slot") == "TOOL":
							# Tools can be equipped with just left-click
							InventoryUI.instance.try_equip_item_from_slot(slot_index)
							return
					
					# Try to consume the item (original behavior)
					InventoryUI.instance.try_consume_item(slot_index)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				InventoryUI.instance.handle_item_drop(slot_index, event.shift_pressed, event.ctrl_pressed)
	
	func _on_slot_mouse_entered():
		if InventoryUI.instance:
			InventoryUI.instance.show_item_info(slot_index)
	
	func _on_slot_mouse_exited():
		if InventoryUI.instance:
			InventoryUI.instance.hide_item_info()
	
	func update_display(slot):
		if slot.is_empty():
			icon.texture = null
			quantity_label.text = ""
		else:
			print("Updating inventory slot display for item: ", slot.item_id)
			var item_data = InventoryUI.instance.inventory_system.get_item_data(slot.item_id)
			var icon_path = item_data.get("icon_path", "")
			
			# Check if this is an equipment item (prioritize equipment icons)
			if EquipmentManager.equipment_data.has(slot.item_id):
				var equipment_data = EquipmentManager.equipment_data[slot.item_id]
				var icon_name = equipment_data.get("icon", "")
				if not icon_name.is_empty():
					icon_path = "res://assets/sprites/items/equipment/" + icon_name + ".png"
					if not ResourceLoader.exists(icon_path):
						print("Icon file NOT found at: ", icon_path)
			# Check if this is a weapon item
			elif WeaponManager.weapon_data.has(slot.item_id):
				print("Found weapon item: ", slot.item_id)
				var weapon_data = WeaponManager.weapon_data[slot.item_id]
				var icon_name = weapon_data.get("icon", "")
				if not icon_name.is_empty():
					icon_path = "res://assets/sprites/items/weapons/" + icon_name + ".png"
					print("Constructed weapon icon path: ", icon_path)
					if ResourceLoader.exists(icon_path):
						print("Weapon icon file exists!")
					else:
						print("Weapon icon file NOT found at: ", icon_path)
				else:
					print("No icon name found in weapon data")
			
			if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
				icon.texture = load(icon_path)
			else:
				icon.texture = null
			
			if slot.quantity > 1:
				quantity_label.text = str(slot.quantity)
			else:
				quantity_label.text = ""

static var instance: InventoryUI

func _ready() -> void:
	instance = self

	# Add to group for input blocking detection
	add_to_group("inventory_ui")

	# Get reference to autoloaded inventory system
	inventory_system = InventorySystem
	
	# Connect signals (check if not already connected)
	if close_button and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	inventory_system.inventory_changed.connect(_on_inventory_changed)
	
	# Connect to equipment manager
	if EquipmentManager:
		EquipmentManager.equipment_changed.connect(_on_equipment_changed)
	
	# Connect to weapon manager
	if WeaponManager:
		WeaponManager.weapon_equipped.connect(_on_weapon_equipped)
		WeaponManager.weapon_unequipped.connect(_on_weapon_unequipped)
	
	# Connect to GameManager for state changes
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	# Initialize UI slots
	setup_inventory_slots()
	setup_equipment_slots()
	
	# Start hidden
	visible = false

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SLASH:
			# Debug: Load equipment items (/)
			load_debug_equipment()
		elif event.keycode == KEY_BACKSLASH:
			# Debug: Show inventory contents (\)
			debug_show_inventory_contents()

	# Handle inventory toggle
	if Input.is_action_just_pressed("toggle_inventory"):
		toggle_inventory()

func setup_inventory_slots():
	# Clear existing slots
	for child in grid_container.get_children():
		child.queue_free()
	
	inventory_slots_ui.clear()
	
	# Update inventory system size first
	inventory_system.update_inventory_size()
	
	# Create UI slots based on current max slots (including bonuses)
	var max_slots = inventory_system.get_max_slots()
	
	# Calculate grid dimensions
	var columns = 5  # Keep 5 columns as defined in the scene
	var rows = ceili(float(max_slots) / float(columns))
	
	# Calculate required sizes
	var slot_size = 64 + 5  # 64px slot + 5px separation
	var grid_width = columns * slot_size - 5  # Remove last separator
	var grid_height = rows * slot_size - 5    # Remove last separator
	
	# Update grid container size and position
	var margin = 30  # Margin from panel edges
	grid_container.size = Vector2(grid_width, grid_height)
	
	# Update grid container position relative to the panel
	grid_container.position = Vector2(margin, 60)  # 60px top margin for title
	
	# Calculate required panel size
	var panel_width = grid_width + (margin * 2)
	var panel_height = grid_height + margin + 60  # 60px for top margin (title area)
	
	# Resize the inventory panel using offsets (it's anchored to center)
	inventory_panel.offset_left = -panel_width/2
	inventory_panel.offset_top = -panel_height/2
	inventory_panel.offset_right = panel_width/2
	inventory_panel.offset_bottom = panel_height/2
	
	# Create UI slots
	for i in range(max_slots):
		var slot_ui = InventorySlotUI.new(i)
		inventory_slots_ui.append(slot_ui)
		grid_container.add_child(slot_ui.panel)
	
	print("InventoryUI: Created %d inventory slots (%d base + %d bonus) in %dx%d grid" % [max_slots, inventory_system.BASE_SLOTS, max_slots - inventory_system.BASE_SLOTS, columns, rows])
	print("InventoryUI: Panel resized to %dx%d" % [panel_width, panel_height])
	
	# Update display
	_on_inventory_changed()

func setup_equipment_slots():
	# Map slot names to their TextureRect nodes
	var slot_mappings = {
		"HEAD": equipment_panel.get_node("EquipmentSlot1"),
		"TRINKET_1": equipment_panel.get_node("EquipmentSlot2"),
		"TRINKET_2": equipment_panel.get_node("EquipmentSlot3"),
		"CHEST": equipment_panel.get_node("EquipmentSlot4"),
		"PANTS": equipment_panel.get_node("EquipmentSlot5"),
		"FEET": equipment_panel.get_node("EquipmentSlot6"),
		"PRIMARY_WEAPON": equipment_panel.get_node("EquipmentSlot7"),
		"SECONDARY_WEAPON": equipment_panel.get_node("EquipmentSlot8"),
		"TOOL": equipment_panel.get_node("ToolSlot"),
		"BACKPACK": equipment_panel.get_node("EquipmentSlot10")
	}
	
	for slot_name in slot_mappings:
		var texture_rect = slot_mappings[slot_name]
		if texture_rect:
			var equipment_slot = EquipmentSlotUI.new(slot_name, texture_rect)
			equipment_slots_ui[slot_name] = equipment_slot
	
	# Update equipment display
	update_equipment_display()

func toggle_inventory():
	visible = not visible
	
	if visible:
		# Refresh inventory display when opened
		_on_inventory_changed()

func _on_close_button_pressed():
	GameManager.change_state(GameManager.GameState.IN_GAME)

func _on_game_state_changed(new_state: GameManager.GameState):
	# Show/hide inventory based on game state
	if new_state == GameManager.GameState.INVENTORY:
		visible = true
		# Refresh inventory display when opened
		_on_inventory_changed()
	else:
		visible = false

func _on_inventory_changed():
	# Update all slot displays
	for i in range(inventory_slots_ui.size()):
		if i < inventory_system.inventory_slots.size():
			inventory_slots_ui[i].update_display(inventory_system.inventory_slots[i])

func show_item_info(slot_index: int):
	if slot_index >= inventory_system.inventory_slots.size():
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		item_info_label.text = "[center]Hover over items for details[/center]"
		return
	
	# Get item data from appropriate manager
	var item_data = {}
	var is_equipment = EquipmentManager.equipment_data.has(slot.item_id)
	var is_weapon = WeaponManager.weapon_data.has(slot.item_id)
	
	if is_equipment:
		var equipment_data = EquipmentManager.equipment_data[slot.item_id]
		item_data = {
			"name": equipment_data.get("name", "Unknown Equipment"),
			"description": equipment_data.get("description", "No description available."),
			"category": "Equipment"
		}
	elif is_weapon:
		var weapon_data = WeaponManager.weapon_data[slot.item_id]
		item_data = {
			"name": weapon_data.get("name", "Unknown Weapon"),
			"description": weapon_data.get("description", "No description available."),
			"category": "Weapon"
		}
	else:
		item_data = inventory_system.get_item_data(slot.item_id)
	
	var info_text = "[center][b]%s[/b][/center]\n" % item_data.get("name", "Unknown Item")
	info_text += "%s\n\n" % item_data.get("description", "No description available.")
	info_text += "[color=gray]Category: %s[/color]\n" % item_data.get("category", "Misc")
	info_text += "[color=gray]Quantity: %d[/color]" % slot.quantity
	
	if slot.max_stack > 1:
		info_text += "[color=gray] / %d[/color]" % slot.max_stack
	
	# Show if item is already equipped
	if is_item_already_equipped(slot.item_id):
		info_text += "\n[color=yellow]⚡ EQUIPPED[/color]"
	
	# Add interaction instructions - change based on storage state
	if StorageUI.instance and StorageUI.instance.visible:
		info_text += "\n\n[color=orange]Storage Mode:[/color]\n"
		info_text += "[color=gray]Left-click: Transfer to storage[/color]\n"
		info_text += "[color=gray]Item dropping disabled while storage open[/color]"
	else:
		# Check if item is consumable
		var category = item_data.get("category", "").to_lower()
		if category == "consumable":
			info_text += "\n\n[color=lightgreen]Consumable Item:[/color]\n"
			info_text += "[color=gray]Left-click: Consume item[/color]\n"
		
		# Add equipment info if applicable
		if is_equipment:
			var equipment_data = EquipmentManager.equipment_data[slot.item_id]
			info_text += "\n\n[color=orange]Equipment:[/color]\n"
			info_text += "[color=gray]Slot: %s[/color]\n" % equipment_data.get("slot", "Unknown").replace("_", " ").capitalize()
			info_text += "[color=gray]Tier: %s[/color]\n" % equipment_data.get("tier", 1)
			
			# Show durability info
			var durability = equipment_data.get("durability", 100)
			var durability_pct = 100  # Assume new item is at 100%
			var condition_text = "Excellent"
			var condition_color = "lightgreen"
			
			info_text += "[color=gray]Max Durability: %d[/color]\n" % durability
			info_text += "[color=%s]Condition: %s (%d%%)[/color]\n" % [condition_color, condition_text, durability_pct]
			
			# Show stats if available
			if equipment_data.has("stats") and equipment_data.stats.size() > 0:
				info_text += "[color=lightgreen]Stats:[/color]\n"
				for stat_name in equipment_data.stats:
					var stat_value = equipment_data.stats[stat_name]
					var display_name = stat_name.replace("_", " ").capitalize()
					if stat_value is bool:
						if stat_value:
							info_text += "[color=gray]%s[/color]\n" % display_name
					else:
						var prefix = "+" if (stat_value is float or stat_value is int) and stat_value > 0 else ""
						info_text += "[color=gray]%s: %s%s[/color]\n" % [display_name, prefix, stat_value]
			
			# Show different instructions for tools vs other equipment
			var equipment_item_data = EquipmentManager.equipment_data[slot.item_id]
			var is_tool = equipment_item_data.get("slot") == "TOOL"
			
			if not is_item_already_equipped(slot.item_id):
				if is_tool:
					info_text += "[color=gray]Left-click: Equip tool[/color]\n"
				else:
					info_text += "[color=gray]Ctrl+Left-click: Equip item[/color]\n"
			else:
				if is_tool:
					info_text += "[color=gray]Left-click: Swap with equipped tool[/color]\n"
				else:
					info_text += "[color=gray]Ctrl+Left-click: Swap with equipped item[/color]\n"
		
		# Add weapon info if applicable
		elif is_weapon:
			var weapon_data = WeaponManager.weapon_data[slot.item_id]
			info_text += "\n\n[color=orange]Weapon:[/color]\n"
			info_text += "[color=gray]Type: %s[/color]\n" % weapon_data.get("type", "Unknown").capitalize()
			info_text += "[color=gray]Tier: %s[/color]\n" % weapon_data.get("tier", 1)
			info_text += "[color=gray]Damage: %s[/color]\n" % weapon_data.get("damage", 0)
			info_text += "[color=gray]Attack Speed: %s[/color]\n" % weapon_data.get("attack_speed", 1.0)
			info_text += "[color=gray]Range: %s[/color]\n" % weapon_data.get("range", 1.0)
			
			# Show durability info for new weapon
			var durability = weapon_data.get("durability", 100)
			var durability_pct = 100  # Assume new weapon is at 100%
			var condition_text = "Excellent"
			var condition_color = "lightgreen"
			
			info_text += "[color=gray]Max Durability: %d[/color]\n" % durability
			info_text += "[color=%s]Condition: %s (%d%%)[/color]\n" % [condition_color, condition_text, durability_pct]
			
			if weapon_data.get("type") == "RANGED":
				info_text += "[color=gray]Magazine: %s[/color]\n" % weapon_data.get("magazine_size", 1)
				info_text += "[color=gray]Reload Time: %s[/color]\n" % weapon_data.get("reload_time", 2.0)
			
			# Show weapon stats if available
			if weapon_data.has("stats") and weapon_data.stats.size() > 0:
				info_text += "[color=lightgreen]Stats:[/color]\n"
				for stat_name in weapon_data.stats:
					var stat_value = weapon_data.stats[stat_name]
					var display_name = stat_name.replace("_", " ").capitalize()
					if stat_value is bool:
						if stat_value:
							info_text += "[color=gray]%s[/color]\n" % display_name
					else:
						var prefix = "+" if (stat_value is float or stat_value is int) and stat_value > 0 else ""
						info_text += "[color=gray]%s: %s%s[/color]\n" % [display_name, prefix, stat_value]
			
			if not is_item_already_equipped(slot.item_id):
				info_text += "[color=gray]Ctrl+Left-click: Equip weapon[/color]\n"
			else:
				info_text += "[color=gray]Ctrl+Left-click: Swap with equipped weapon[/color]\n"
		
		info_text += "\n\n[color=cyan]Hotbar:[/color]\n"
		info_text += "[color=gray]Shift+Left-click: Add to hotbar[/color]\n"
		
		info_text += "\n\n[color=yellow]Drop Controls:[/color]\n"
		info_text += "[color=gray]Right-click: Drop 1[/color]\n"
		info_text += "[color=gray]Shift+Right-click: Drop half[/color]\n"
		info_text += "[color=gray]Ctrl+Right-click: Drop all[/color]"
	
	item_info_label.text = info_text

func hide_item_info():
	item_info_label.text = "[center]Hover over items for details[/center]"

func transfer_item_to_storage(slot_index: int):
	print("Inventory slot %d clicked - attempting to transfer to storage" % slot_index)
	
	if slot_index >= inventory_system.inventory_slots.size():
		print("Invalid slot index")
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		print("Slot is empty, nothing to transfer")
		return
	
	var item_id = slot.item_id
	var quantity = 1  # Transfer 1 item at a time
	
	print("Transferring %s (quantity: %d) from inventory to storage" % [item_id, quantity])
	
	# Call StorageUI to handle the transfer
	if StorageUI.instance and StorageUI.instance.visible:
		if StorageUI.instance.transfer_from_inventory_to_storage(item_id, quantity):
			print("Successfully transferred %s to storage" % item_id)
		else:
			print("Failed to transfer %s to storage (storage might be full)" % item_id)
	else:
		print("StorageUI not available")

func handle_item_drop(slot_index: int, shift_pressed: bool, ctrl_pressed: bool):
	# Check if storage is open - disable dropping when using storage
	if StorageUI.instance and StorageUI.instance.visible:
		print("Storage is open - item dropping disabled. Use storage transfer instead.")
		return
	
	if slot_index >= inventory_system.inventory_slots.size():
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		return
	
	# Get player position for drop location
	var player = GameManager.player_node
	if not player:
		print("No player found for item drop")
		return
	
	var drop_position = player.global_position + Vector2(randf_range(-32, 32), randf_range(-32, 32))
	
	# Determine drop quantity based on modifiers
	var drop_quantity = 1
	if shift_pressed:
		# Shift + Right click: drop half the stack (rounded up)
		drop_quantity = ceili(float(slot.quantity) / 2.0)
	elif ctrl_pressed:
		# Ctrl + Right click: drop entire stack
		drop_quantity = slot.quantity
	
	# Drop the item(s)
	if inventory_system.drop_item_from_slot(slot_index, drop_quantity, drop_position):
		print("Dropped %d items from slot %d" % [drop_quantity, slot_index])

func try_consume_item(slot_index: int):
	if slot_index >= inventory_system.inventory_slots.size():
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		return
	
	var item_id = slot.item_id
	var item_data = inventory_system.get_item_data(item_id)
	var category = item_data.get("category", "").to_lower()
	
	# Check if the item is consumable
	if category == "consumable":
		# Get the player and try to consume the item
		var player = GameManager.player_node
		if player and player.has_method("consume_item"):
			# Remove item from InventorySystem and let player consume it
			if inventory_system.remove_item(item_id, 1):
				# Add to player's personal inventory temporarily for consumption
				if player.inventory.add_item(item_id, 1) > 0:
					if player.consume_item(item_id):
						print("Successfully consumed %s" % item_data.get("name", item_id))
					else:
						# If consumption failed, add the item back to InventorySystem
						player.inventory.remove_item(item_id, 1)
						inventory_system.add_item(item_id, 1)
						print("Failed to consume %s" % item_data.get("name", item_id))
				else:
					# If couldn't add to player inventory, add back to InventorySystem
					inventory_system.add_item(item_id, 1)
					print("Player inventory full, couldn't consume")
		else:
			print("No player found or player can't consume items")
	else:
		print("%s is not consumable" % item_data.get("name", item_id))

func add_item_to_hotbar(slot_index: int):
	if slot_index >= inventory_system.inventory_slots.size():
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		return
	
	# Find the hotbar through HUD
	var hud = get_tree().get_nodes_in_group("hud")
	if hud.is_empty():
		print("No HUD found to access hotbar")
		return
	
	var hotbar = hud[0].hotbar
	if not hotbar:
		print("Hotbar not found in HUD")
		return
	
	var item_id = slot.item_id
	var quantity = slot.quantity
	var item_data = inventory_system.get_item_data(item_id)
	
	var result = hotbar.add_item_to_hotbar(item_id, quantity)
	if result >= 0:
		print("Added %s to hotbar slot %d" % [item_data.get("name", item_id), result + 1])
	else:
		print("Hotbar is full, cannot add %s" % item_data.get("name", item_id))

func is_item_already_equipped(item_id: String) -> bool:
	# Check if item is equipped as equipment
	var all_equipped_items = EquipmentManager.get_all_equipped_items()
	for equipped_item in all_equipped_items:
		if equipped_item and equipped_item.id == item_id:
			return true
	
	# Check if item is equipped as a weapon
	var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
	if primary_weapon and primary_weapon.id == item_id:
		return true
	
	var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
	if secondary_weapon and secondary_weapon.id == item_id:
		return true
	
	return false

func try_equip_item_from_slot(slot_index: int):
	if slot_index >= inventory_system.inventory_slots.size():
		return
	
	var slot = inventory_system.inventory_slots[slot_index]
	if slot.is_empty():
		return
	
	var item_id = slot.item_id
	
	# Check if this item is equipment
	if EquipmentManager.equipment_data.has(item_id):
		# Create equipment instance
		var equipment = EquipmentManager.create_equipment(item_id)
		if not equipment:
			print("Failed to create equipment for %s" % item_id)
			return
		
		# Check if same item type is already equipped in this slot
		var target_slot = equipment.slot
		var currently_equipped = EquipmentManager.get_equipped_item(target_slot)
		
		if currently_equipped and currently_equipped.id == item_id:
			# Same item is equipped - this is a direct swap with inventory
			print("Swapping %s with equipped item" % equipment.name)
			# The equip process will automatically unequip current and equip new
		
		# Try to equip it (this handles swapping automatically)
		if EquipmentManager.equip_item(equipment):
			# Remove from inventory
			if inventory_system.remove_item(item_id, 1):
				if currently_equipped and currently_equipped.id == item_id:
					print("Successfully swapped %s" % equipment.name)
				else:
					print("Successfully equipped %s" % equipment.name)
			else:
				# If removal failed, unequip and give back
				EquipmentManager.unequip_item(equipment.slot)
				print("Failed to remove item from inventory")
		else:
			print("Failed to equip %s" % equipment.name)
	
	# Check if this item is a weapon
	elif WeaponManager.weapon_data.has(item_id):
		# Create weapon instance
		var weapon = WeaponManager.create_weapon(item_id)
		if not weapon:
			print("Failed to create weapon for %s" % item_id)
			return
		
		# Check if same weapon is already equipped somewhere
		var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
		var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
		var target_slot = "PRIMARY_WEAPON"
		var is_swapping = false
		
		if primary_weapon and primary_weapon.id == item_id:
			# Same weapon in primary - swap with it
			target_slot = "PRIMARY_WEAPON"
			is_swapping = true
			print("Swapping weapon with primary slot")
		elif secondary_weapon and secondary_weapon.id == item_id:
			# Same weapon in secondary - swap with it  
			target_slot = "SECONDARY_WEAPON"
			is_swapping = true
			print("Swapping weapon with secondary slot")
		else:
			# Different weapon - use normal slot selection logic
			if primary_weapon:
				if not secondary_weapon:
					target_slot = "SECONDARY_WEAPON"
				# If both occupied, replace primary (default behavior)
		
		# Try to equip it
		if WeaponManager.equip_weapon(weapon, target_slot):
			# Remove from inventory
			if inventory_system.remove_item(item_id, 1):
				if is_swapping:
					print("Successfully swapped weapon %s in %s" % [weapon.name, target_slot])
				else:
					print("Successfully equipped weapon %s to %s" % [weapon.name, target_slot])
			else:
				# If removal failed, unequip and give back
				WeaponManager.unequip_weapon(target_slot)
				print("Failed to remove weapon from inventory")
		else:
			print("Failed to equip weapon %s" % weapon.name)
	
	else:
		print("Item %s is not equippable" % item_id)
		return

func _on_equipment_slot_clicked(slot_type: String):
	# Check if this is a weapon slot
	if slot_type == "PRIMARY_WEAPON" or slot_type == "SECONDARY_WEAPON":
		# Handle weapon unequipping - WeaponManager handles adding back to inventory
		var equipped_weapon = WeaponManager.get_equipped_weapon(slot_type)
		if equipped_weapon:
			var unequipped_weapon = WeaponManager.unequip_weapon(slot_type)
			if unequipped_weapon:
				print("Unequipped weapon %s" % unequipped_weapon.name)
	else:
		# Handle equipment unequipping - EquipmentManager handles adding back to inventory
		var equipped_item = EquipmentManager.get_equipped_item(slot_type)
		if equipped_item:
			if EquipmentManager.unequip_item(slot_type):
				print("Unequipped %s" % equipped_item.name)

func _on_equipment_slot_right_clicked(slot_type: String):
	# Same as left click for now - could add different behavior later
	_on_equipment_slot_clicked(slot_type)

func _on_equipment_changed(_slot: String, _equipment: Equipment):
	# Check if this equipment change affects inventory slots
	if _slot == "BACKPACK" or (_equipment and _equipment.stats.has("inventory_slots")):
		# Refresh inventory slots to account for bonus slots
		setup_inventory_slots()
	
	# Update the equipment slot display
	update_equipment_display()

func _on_weapon_equipped(_weapon: Weapon, _slot: String):
	# Update the equipment slot display when weapon is equipped
	update_equipment_display()

func _on_weapon_unequipped(_slot: String):
	# Update the equipment slot display when weapon is unequipped
	update_equipment_display()

func update_equipment_display():
	for slot_name in equipment_slots_ui:
		var slot_ui = equipment_slots_ui[slot_name]
		
		# Handle weapon slots differently
		if slot_name == "PRIMARY_WEAPON" or slot_name == "SECONDARY_WEAPON":
			var equipped_weapon = WeaponManager.get_equipped_weapon(slot_name)
			# For weapons, we need to treat them as equipment for display purposes
			if equipped_weapon:
				# Create a temporary equipment-like object for display
				var temp_equipment = Equipment.new()
				temp_equipment.id = equipped_weapon.id
				temp_equipment.name = equipped_weapon.name
				temp_equipment.icon = equipped_weapon.icon
				slot_ui.update_display(temp_equipment)
			else:
				slot_ui.update_display(null)
		else:
			# Handle regular equipment
			var equipped_item = EquipmentManager.get_equipped_item(slot_name)
			slot_ui.update_display(equipped_item)

func show_equipment_info(slot_type: String):
	# Check if this is a weapon slot
	if slot_type == "PRIMARY_WEAPON" or slot_type == "SECONDARY_WEAPON":
		var equipped_weapon = WeaponManager.get_equipped_weapon(slot_type)
		if not equipped_weapon:
			item_info_label.text = "[center][b]%s Slot[/b][/center]\n\nEmpty weapon slot\n\n[color=cyan]Equipment:[/color]\n[color=gray]Ctrl+Left-click weapons to equip[/color]\n\n[color=yellow]Debug:[/color]\n[color=gray]/: Load test equipment[/color]\n[color=gray]\\: Show inventory contents[/color]" % slot_type.replace("_", " ").capitalize()
			return
		
		var info_text = "[center][b]%s[/b][/center]\n" % equipped_weapon.name
		info_text += "%s\n\n" % equipped_weapon.description
		info_text += "[color=gray]Type: %s[/color]\n" % equipped_weapon.type.capitalize()
		info_text += "[color=gray]Damage: %s[/color]\n" % equipped_weapon.damage
		info_text += "[color=gray]Attack Speed: %s[/color]\n" % equipped_weapon.attack_speed
		info_text += "[color=gray]Range: %s[/color]\n" % equipped_weapon.attack_range
		
		# Show weapon durability with condition
		var durability_pct = equipped_weapon.get_durability_percentage()
		var condition_text = equipped_weapon.get_weapon_condition_text() if equipped_weapon.has_method("get_weapon_condition_text") else "Unknown"
		var condition_color = "lightgreen"
		
		# Set color based on condition
		if durability_pct <= 0.0:
			condition_color = "red"
		elif durability_pct <= 0.25:
			condition_color = "orange"
		elif durability_pct <= 0.5:
			condition_color = "yellow"
		elif durability_pct <= 0.75:
			condition_color = "lightblue"
		else:
			condition_color = "lightgreen"
		
		info_text += "[color=gray]Durability: %d/%d[/color]\n" % [equipped_weapon.current_durability, equipped_weapon.durability]
		info_text += "[color=%s]Condition: %s (%d%%)[/color]\n" % [condition_color, condition_text, int(durability_pct * 100)]
		
		# Show warning if broken
		if equipped_weapon.has_method("is_broken") and equipped_weapon.is_broken():
			info_text += "[color=red]⚠ BROKEN - Cannot be used![/color]\n"
		
		info_text += "\n"
		
		if equipped_weapon.is_ranged():
			info_text += "[color=gray]Magazine: %d/%d[/color]\n" % [equipped_weapon.current_ammo, equipped_weapon.magazine_size]
			info_text += "[color=gray]Reload Time: %s[/color]\n\n" % equipped_weapon.reload_time
		
		info_text += "[color=yellow]Controls:[/color]\n"
		info_text += "[color=gray]Left-click: Unequip weapon[/color]"
		
		item_info_label.text = info_text
	else:
		# Handle regular equipment
		var equipped_item = EquipmentManager.get_equipped_item(slot_type)
		if not equipped_item:
			var slot_display_name = slot_type.replace("_", " ").capitalize()
			var equip_instruction = "Ctrl+Left-click items to equip"
			
			# Special instructions for tool slot
			if slot_type == "TOOL":
				equip_instruction = "Left-click tools to equip"
			
			item_info_label.text = "[center][b]%s Slot[/b][/center]\n\nEmpty equipment slot\n\n[color=cyan]Equipment:[/color]\n[color=gray]%s[/color]\n\n[color=yellow]Debug:[/color]\n[color=gray]/: Load test equipment[/color]\n[color=gray]\\: Show inventory contents[/color]" % [slot_display_name, equip_instruction]
			return
		
		var info_text = "[center][b]%s[/b][/center]\n" % equipped_item.name
		info_text += "%s\n\n" % equipped_item.description
		info_text += "[color=gray]Slot: %s[/color]\n" % slot_type.replace("_", " ").capitalize()
		info_text += "[color=gray]Tier: %d[/color]\n" % equipped_item.tier
		
		# Show durability information
		if equipped_item.has_method("get_durability_percentage"):
			var durability_pct = equipped_item.get_durability_percentage()
			var condition_text = equipped_item.get_equipment_condition_text() if equipped_item.has_method("get_equipment_condition_text") else "Unknown"
			var condition_color = "lightgreen"
			
			# Set color based on condition
			if durability_pct <= 0.0:
				condition_color = "red"
			elif durability_pct <= 0.25:
				condition_color = "orange" 
			elif durability_pct <= 0.5:
				condition_color = "yellow"
			elif durability_pct <= 0.75:
				condition_color = "lightblue"
			else:
				condition_color = "lightgreen"
			
			info_text += "[color=gray]Durability: %d/%d[/color]\n" % [equipped_item.current_durability, equipped_item.durability]
			info_text += "[color=%s]Condition: %s (%d%%)[/color]\n\n" % [condition_color, condition_text, int(durability_pct * 100)]
			
			# Show warning if broken
			if equipped_item.has_method("is_broken") and equipped_item.is_broken():
				info_text += "[color=red]⚠ BROKEN - No stat bonuses![/color]\n\n"
		else:
			info_text += "\n"
		
		# Add stats (show effective stats if equipment has durability)
		var stats_to_show = equipped_item.get_effective_stats() if equipped_item.has_method("get_effective_stats") else equipped_item.stats
		if stats_to_show.size() > 0:
			info_text += "[color=lightgreen]Current Stats:[/color]\n"
			for stat_name in stats_to_show:
				var stat_value = stats_to_show[stat_name]
				var display_name = stat_name.replace("_", " ").capitalize()
				if stat_value is bool:
					if stat_value:
						info_text += "[color=gray]%s[/color]\n" % display_name
				else:
					var prefix = "+" if (stat_value is float or stat_value is int) and stat_value > 0 else ""
					info_text += "[color=gray]%s: %s%s[/color]\n" % [display_name, prefix, stat_value]
			info_text += "\n"
		
		info_text += "[color=yellow]Controls:[/color]\n"
		info_text += "[color=gray]Left-click: Unequip item[/color]"
		
		item_info_label.text = info_text

func load_debug_equipment():
	print("Loading debug equipment items...")
	
	# Clear inventory first to prevent duplicates
	inventory_system.clear_inventory()
	print("Cleared inventory for fresh debug load")
	
	# List of equipment items to load for testing
	var equipment_items = [
		"SCRAP_HELMET",      # HEAD
		"HAZMAT_HELMET",     # HEAD (for swapping test)
		"SCRAP_VEST",        # CHEST  
		"LUCKY_CHARM",       # TRINKET
		"SMALL_BACKPACK",    # BACKPACK
		"COMBAT_BOOTS",      # FEET
		"CARGO_PANTS",       # PANTS
		"BASIC_AXE",         # TOOL
		"BASIC_PICKAXE"      # TOOL
	]
	
	# List of weapons to load for testing
	var weapon_items = [
		"SCRAP_KNIFE",       # PRIMARY_WEAPON
		"ASSAULT_RIFLE",     # SECONDARY_WEAPON
		"MAKESHIFT_BOW"      # RANGED (for swapping test)
	]

	# List of ammo items to load for testing ranged weapons
	var ammo_items = [
		"SCRAP_BULLETS",     # For assault rifle and other guns
		"WOOD_ARROWS",       # For makeshift bow
		"FIRE_BULLETS",      # Special bullets
		"STEEL_ARROWS"       # Better arrows
	]
	
	var items_added = 0
	
	# Add equipment items
	for item_id in equipment_items:
		# Check if item exists in equipment data
		if EquipmentManager.equipment_data.has(item_id):
			print("Adding equipment item: %s" % item_id)
			var add_result = inventory_system.add_item(item_id, 1)
			if typeof(add_result) in [TYPE_INT, TYPE_FLOAT] and add_result > 0:
				items_added += 1
				print("Successfully added %s to inventory" % item_id)
			else:
				print("Failed to add %s - inventory might be full" % item_id)
		else:
			print("Equipment item %s not found in equipment data" % item_id)
	
	# Add weapon items
	for item_id in weapon_items:
		# Check if item exists in weapon data
		if WeaponManager.weapon_data.has(item_id):
			print("Adding weapon item: %s" % item_id)
			var add_result = inventory_system.add_item(item_id, 1)
			if typeof(add_result) in [TYPE_INT, TYPE_FLOAT] and add_result > 0:
				items_added += 1
				print("Successfully added %s to inventory" % item_id)
			else:
				print("Failed to add %s - inventory might be full" % item_id)
		else:
			print("Weapon item %s not found in weapon data" % item_id)

	# Add ammo items for testing ranged weapons
	for item_id in ammo_items:
		# Use InventorySystem to check if item exists (same as other items)
		var item_data = inventory_system.get_item_data(item_id)
		if item_data.get("name") != "Unknown Item":
			print("Adding ammo item: %s" % item_id)
			# Add multiple stacks of ammo (50 per stack) for testing
			var add_result = inventory_system.add_item(item_id, 50)
			if typeof(add_result) in [TYPE_INT, TYPE_FLOAT] and add_result > 0:
				items_added += 1
				print("Successfully added 50x %s to inventory" % item_id)
			else:
				print("Failed to add %s - inventory might be full" % item_id)
		else:
			print("Ammo item %s not found in resource data" % item_id)
	
	# Note: Ammo selection now handled by EquipedWeaponUI

	print("Debug equipment loading complete: %d items added" % items_added)

	# Refresh inventory display
	_on_inventory_changed()

func auto_select_ammo_for_weapons():
	# Get all equipped weapons and select ammo for them
	if not WeaponManager:
		return

	var primary_weapon = WeaponManager.get_primary_weapon()
	var secondary_weapon = WeaponManager.get_secondary_weapon()

	for weapon in [primary_weapon, secondary_weapon]:
		if weapon and weapon.is_ranged() and weapon.selected_ammo_id.is_empty():
			# Find compatible ammo in inventory
			var compatible_types = weapon.get_compatible_ammo_types()
			for ammo_type in compatible_types:
				# Find ammo items of this type that we have in inventory
				var matching_ammo_id = find_ammo_of_type(ammo_type)
				if matching_ammo_id != "":
					# Select this ammo type for the weapon
					weapon.selected_ammo_id = matching_ammo_id
					var ammo_data = inventory_system.get_item_data(matching_ammo_id)
					print("Auto-selected %s for %s" % [ammo_data.get("name", matching_ammo_id), weapon.name])
					break

func find_ammo_of_type(ammo_type: String) -> String:
	# Check which ammo items we have that match the type
	var ammo_mapping = {
		"BULLET": ["SCRAP_BULLETS", "FIRE_BULLETS"],
		"ARROW": ["WOOD_ARROWS", "STEEL_ARROWS"]
	}

	if ammo_mapping.has(ammo_type):
		for ammo_id in ammo_mapping[ammo_type]:
			if inventory_system.has_item(ammo_id):
				return ammo_id

	return ""

func debug_show_inventory_contents():
	print("\n=== INVENTORY DEBUG CONTENTS ===")
	
	if not inventory_system:
		print("ERROR: No inventory system found!")
		return
	
	var total_slots = inventory_system.inventory_slots.size()
	var used_slots = 0
	var total_items = 0
	
	print("Total inventory slots: %d" % total_slots)
	print("Max slots allowed: %d" % inventory_system.MAX_SLOTS)
	
	for i in range(total_slots):
		var slot = inventory_system.inventory_slots[i]
		if not slot.is_empty():
			used_slots += 1
			total_items += slot.quantity
			
			# Get item data from appropriate manager (same logic as show_item_info)
			var item_data = {}
			var is_equipment = EquipmentManager.equipment_data.has(slot.item_id)
			var is_weapon = WeaponManager.weapon_data.has(slot.item_id)
			
			if is_equipment:
				var equipment_data = EquipmentManager.equipment_data[slot.item_id]
				item_data = {
					"name": equipment_data.get("name", "Unknown Equipment"),
					"category": "Equipment"
				}
			elif is_weapon:
				var weapon_data = WeaponManager.weapon_data[slot.item_id]
				item_data = {
					"name": weapon_data.get("name", "Unknown Weapon"),
					"category": "Weapon"
				}
			else:
				item_data = inventory_system.get_item_data(slot.item_id)
			
			var item_name = item_data.get("name", slot.item_id)
			var category = item_data.get("category", "Unknown")
			print("Slot %d: %s x%d (%s) [%s]" % [i + 1, item_name, slot.quantity, slot.item_id, category])
	
	if used_slots == 0:
		print("Inventory is empty!")
	else:
		print("\nSUMMARY:")
		print("- Used slots: %d/%d" % [used_slots, total_slots])
		print("- Total items: %d" % total_items)
		print("- Empty slots: %d" % (total_slots - used_slots))
	
	print("=== END INVENTORY DEBUG ===\n")
