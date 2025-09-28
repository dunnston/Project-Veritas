extends Area2D
class_name LootItem

# Pickupable loot item in the world

# Loot rarity levels (matching LootSystem)
enum LootRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

signal picked_up(item_id: String, amount: int)

@export var pickup_range: float = 40.0
@export var bob_speed: float = 2.0
@export var bob_height: float = 5.0

var item_id: String = ""
var amount: int = 1
var rarity: LootRarity = LootRarity.COMMON
var initial_position: Vector2
var time_elapsed: float = 0.0
var is_collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var label: Label = $Label
@onready var glow_effect: Sprite2D = $GlowEffect

func _ready():
	# Set up collision detection
	body_entered.connect(_on_body_entered)
	input_event.connect(_on_input_event)

	# Start bobbing animation
	initial_position = global_position

	# Set up visual effects
	if glow_effect:
		glow_effect.modulate = get_rarity_color(rarity)

func _process(delta: float):
	if not is_collected:
		# Bob up and down
		time_elapsed += delta
		var bob_offset = sin(time_elapsed * bob_speed) * bob_height
		global_position = initial_position + Vector2(0, bob_offset)

		# Rotate slightly for visual appeal
		rotation += delta * 0.5

		# Check for nearby player for auto-pickup
		check_auto_pickup()

func setup(new_item_id: String, new_amount: int, new_rarity: LootRarity):
	item_id = new_item_id
	amount = new_amount
	rarity = new_rarity

	# Set up visuals based on item
	setup_visuals()

func get_rarity_color(rarity_level: LootRarity) -> Color:
	match rarity_level:
		LootRarity.COMMON:
			return Color.WHITE
		LootRarity.UNCOMMON:
			return Color.GREEN
		LootRarity.RARE:
			return Color.CYAN
		LootRarity.EPIC:
			return Color.MAGENTA
		_:
			return Color.WHITE

func setup_visuals():
	if not InventorySystem:
		return

	var item_data = InventorySystem.get_item_data(item_id)
	var icon_path = item_data.get("icon_path", "")

	# Set sprite texture
	if icon_path != "" and ResourceLoader.exists(icon_path):
		if sprite:
			sprite.texture = load(icon_path)
			sprite.modulate = get_rarity_color(rarity)

	# Set up collision shape (simple circle)
	if collision_shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = 16.0
		collision_shape.shape = circle_shape

	# Set up amount label
	if label:
		if amount > 1:
			label.text = "x%d" % amount
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_font_size_override("font_size", 12)
		else:
			label.visible = false

	# Set up glow effect
	if glow_effect:
		glow_effect.texture = sprite.texture if sprite else null
		glow_effect.modulate = Color(get_rarity_color(rarity), 0.3)
		glow_effect.scale = Vector2(1.2, 1.2)

func check_auto_pickup():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)
	if distance <= pickup_range:
		collect_item()

func _on_body_entered(body):
	if body.is_in_group("player"):
		collect_item()

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		collect_item()

func collect_item():
	if is_collected:
		return

	is_collected = true

	# Visual feedback
	create_collection_effect()

	# Emit pickup signal
	picked_up.emit(item_id, amount)

	# Remove from scene
	queue_free()

func create_collection_effect():
	# Create sparkle effect
	var sparkle_count = 5
	for i in range(sparkle_count):
		var sparkle = create_sparkle()
		get_parent().add_child(sparkle)

func create_sparkle() -> Node2D:
	var sparkle = Node2D.new()
	var sparkle_sprite = Sprite2D.new()

	# Create simple sparkle texture (white dot)
	var image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture = ImageTexture.new()
	texture.set_image(image)

	sparkle_sprite.texture = texture
	sparkle.add_child(sparkle_sprite)
	sparkle.global_position = global_position

	# Random direction and speed
	var direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var speed = randf_range(50, 100)

	# Animate sparkle
	var tween = create_tween()
	tween.tween_property(sparkle, "global_position", sparkle.global_position + direction * speed, 0.5)
	tween.parallel().tween_property(sparkle_sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(sparkle.queue_free)

	return sparkle
