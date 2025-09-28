extends Node

# Loot system for managing enemy drops and item pickups

signal loot_dropped(item_id: String, position: Vector2)
signal loot_picked_up(item_id: String, amount: int)

# Loot rarity levels
enum LootRarity {
	COMMON,    # White - basic materials
	UNCOMMON,  # Green - consumables, ammo
	RARE,      # Blue - equipment, weapons
	EPIC       # Purple - special components
}

# Loot despawn time (in seconds)
const LOOT_DESPAWN_TIME = 60.0

# Color coding for rarity
const RARITY_COLORS = {
	LootRarity.COMMON: Color.WHITE,
	LootRarity.UNCOMMON: Color.GREEN,
	LootRarity.RARE: Color.CYAN,
	LootRarity.EPIC: Color.MAGENTA
}

var active_loot_items: Array[Node] = []

func _ready():
	print("Loot system initialized")

# Create loot drop at enemy death location
func create_loot_drop(enemy_type: String, position: Vector2) -> void:
	var loot_table = get_loot_table(enemy_type)
	var dropped_items = roll_loot(loot_table)

	for item_data in dropped_items:
		spawn_loot_item(item_data.item_id, item_data.amount, item_data.rarity, position)

# Get loot table based on enemy type
func get_loot_table(enemy_type: String) -> Dictionary:
	var loot_tables = {
		"BasicEnemy": {
			"drops": [
				{"item_id": "SCRAP_METAL", "chance": 0.8, "min_amount": 1, "max_amount": 3, "rarity": LootRarity.COMMON},
				{"item_id": "WOOD_PLANKS", "chance": 0.6, "min_amount": 1, "max_amount": 2, "rarity": LootRarity.COMMON},
				{"item_id": "SCRAP_BULLETS", "chance": 0.3, "min_amount": 5, "max_amount": 10, "rarity": LootRarity.UNCOMMON},
				{"item_id": "BASIC_MEDKIT", "chance": 0.2, "min_amount": 1, "max_amount": 1, "rarity": LootRarity.UNCOMMON}
			]
		},
		"RangedEnemy": {
			"drops": [
				{"item_id": "SCRAP_BULLETS", "chance": 0.9, "min_amount": 10, "max_amount": 20, "rarity": LootRarity.UNCOMMON},
				{"item_id": "FIRE_BULLETS", "chance": 0.4, "min_amount": 5, "max_amount": 10, "rarity": LootRarity.UNCOMMON},
				{"item_id": "SCRAP_METAL", "chance": 0.7, "min_amount": 2, "max_amount": 4, "rarity": LootRarity.COMMON},
				{"item_id": "ELECTRONICS", "chance": 0.3, "min_amount": 1, "max_amount": 2, "rarity": LootRarity.RARE}
			]
		},
		"HeavyMelee": {
			"drops": [
				{"item_id": "STEEL_INGOT", "chance": 0.8, "min_amount": 2, "max_amount": 5, "rarity": LootRarity.UNCOMMON},
				{"item_id": "SCRAP_METAL", "chance": 0.9, "min_amount": 3, "max_amount": 6, "rarity": LootRarity.COMMON},
				{"item_id": "SCRAP_VEST", "chance": 0.4, "min_amount": 1, "max_amount": 1, "rarity": LootRarity.RARE},
				{"item_id": "BASIC_AXE", "chance": 0.2, "min_amount": 1, "max_amount": 1, "rarity": LootRarity.RARE}
			]
		},
		"Scout": {
			"drops": [
				{"item_id": "SCRAP_BULLETS", "chance": 0.9, "min_amount": 15, "max_amount": 25, "rarity": LootRarity.UNCOMMON},
				{"item_id": "WOOD_ARROWS", "chance": 0.7, "min_amount": 8, "max_amount": 15, "rarity": LootRarity.UNCOMMON},
				{"item_id": "SMALL_BACKPACK", "chance": 0.3, "min_amount": 1, "max_amount": 1, "rarity": LootRarity.RARE},
				{"item_id": "ENERGY_CELLS", "chance": 0.4, "min_amount": 3, "max_amount": 8, "rarity": LootRarity.UNCOMMON}
			]
		},
		"Engineer": {
			"drops": [
				{"item_id": "ELECTRONICS", "chance": 0.9, "min_amount": 2, "max_amount": 4, "rarity": LootRarity.RARE},
				{"item_id": "CIRCUITS", "chance": 0.7, "min_amount": 1, "max_amount": 3, "rarity": LootRarity.RARE},
				{"item_id": "ENERGY_CELLS", "chance": 0.8, "min_amount": 5, "max_amount": 12, "rarity": LootRarity.UNCOMMON},
				{"item_id": "PLASMA_CHARGES", "chance": 0.5, "min_amount": 2, "max_amount": 6, "rarity": LootRarity.RARE},
				{"item_id": "ADVANCED_COMPONENTS", "chance": 0.3, "min_amount": 1, "max_amount": 2, "rarity": LootRarity.EPIC}
			]
		}
	}

	return loot_tables.get(enemy_type, loot_tables["BasicEnemy"])

# Roll for loot drops based on loot table
func roll_loot(loot_table: Dictionary) -> Array:
	var dropped_items = []

	for drop in loot_table.drops:
		if randf() <= drop.chance:
			var amount = randi_range(drop.min_amount, drop.max_amount)
			dropped_items.append({
				"item_id": drop.item_id,
				"amount": amount,
				"rarity": drop.rarity
			})

	return dropped_items

# Spawn physical loot item in the world
func spawn_loot_item(item_id: String, amount: int, rarity: LootRarity, position: Vector2) -> void:
	var loot_scene = preload("res://scenes/items/LootItem.tscn")
	var loot_item = loot_scene.instantiate()

	# Set up the loot item - convert LootSystem rarity to LootItem rarity
	var item_rarity = convert_rarity_to_item(rarity)
	loot_item.setup(item_id, amount, item_rarity)
	loot_item.global_position = position + Vector2(randf_range(-20, 20), randf_range(-20, 20))

	# Connect pickup signal
	loot_item.picked_up.connect(_on_loot_picked_up)

	# Add to scene
	get_tree().current_scene.add_child(loot_item)
	active_loot_items.append(loot_item)

	# Set up despawn timer
	var timer = Timer.new()
	timer.wait_time = LOOT_DESPAWN_TIME
	timer.one_shot = true
	timer.timeout.connect(func(): despawn_loot_item(loot_item))
	loot_item.add_child(timer)
	timer.start()

	print("Spawned loot: %s x%d (rarity: %s)" % [item_id, amount, LootRarity.keys()[rarity]])
	loot_dropped.emit(item_id, position)

# Handle loot pickup
func _on_loot_picked_up(item_id: String, amount: int) -> void:
	if InventorySystem:
		InventorySystem.add_item(item_id, amount)
		create_pickup_feedback(item_id, amount)
		loot_picked_up.emit(item_id, amount)
		print("Picked up: %s x%d" % [item_id, amount])

# Create visual feedback for loot pickup
func create_pickup_feedback(item_id: String, amount: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var feedback_label = Label.new()
	var item_data = InventorySystem.get_item_data(item_id)
	var item_name = item_data.get("name", item_id)

	feedback_label.text = "+ %s x%d" % [item_name, amount]
	feedback_label.add_theme_color_override("font_color", Color.YELLOW)
	feedback_label.add_theme_font_size_override("font_size", 20)
	feedback_label.position = player.global_position - Vector2(40, 60)
	feedback_label.z_index = 300

	get_tree().current_scene.add_child(feedback_label)

	var tween = create_tween()
	tween.tween_property(feedback_label, "position", feedback_label.position + Vector2(0, -40), 2.0)
	tween.parallel().tween_property(feedback_label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(feedback_label.queue_free)

# Despawn loot item after timeout
func despawn_loot_item(loot_item: Node) -> void:
	if loot_item and is_instance_valid(loot_item):
		active_loot_items.erase(loot_item)
		loot_item.queue_free()

# Clean up all loot items (useful for scene transitions)
func clear_all_loot() -> void:
	for loot_item in active_loot_items:
		if is_instance_valid(loot_item):
			loot_item.queue_free()
	active_loot_items.clear()

# Convert LootSystem rarity to LootItem rarity (they should match)
func convert_rarity_to_item(loot_rarity: LootRarity) -> int:
	# Both enums should have the same values, so just return the int value
	return loot_rarity

# Get loot rarity color
func get_rarity_color(rarity: LootRarity) -> Color:
	var colors = {
		LootRarity.COMMON: Color.WHITE,
		LootRarity.UNCOMMON: Color.GREEN,
		LootRarity.RARE: Color.CYAN,
		LootRarity.EPIC: Color.MAGENTA
	}
	return colors.get(rarity, Color.WHITE)