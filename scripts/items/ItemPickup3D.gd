extends Area3D
class_name ItemPickup3D

signal picked_up(item_id: String, amount: int)

@export_group("Pickup Settings")
@export var item_id: String = ""
@export var amount: int = 1
@export var auto_pickup: bool = true
@export var pickup_range: float = 2.0

@export_group("Visual Effects")
@export var bob_speed: float = 2.0
@export var bob_height: float = 0.2
@export var rotation_speed: float = 1.0
@export var glow_intensity: float = 0.5

@export_group("Audio")
@export var pickup_sound: AudioStream

var initial_position: Vector3
var time_elapsed: float = 0.0
var is_collected: bool = false
var player_in_range: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var label_3d: Label3D = $Label3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var particles: GPUParticles3D = $GPUParticles3D
@onready var omni_light: OmniLight3D = $OmniLight3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	add_to_group("item_pickups")
	initial_position = global_position

	# Setup visuals for scene-placed items or ones that haven't been setup yet
	if not item_id.is_empty():
		call_deferred("setup_visuals")

	if auto_pickup:
		set_collision_layer_value(8, true)  # Items layer (bit 4)
		set_collision_mask_value(2, true)   # Player layer (bit 2)

func _process(delta: float):
	if is_collected:
		return

	time_elapsed += delta
	var bob_offset = sin(time_elapsed * bob_speed) * bob_height
	global_position = initial_position + Vector3(0, bob_offset, 0)

	rotate_y(delta * rotation_speed)

	if auto_pickup and player_in_range:
		check_pickup_distance()

func setup(new_item_id: String, new_amount: int = 1):
	item_id = new_item_id
	amount = new_amount
	print("ItemPickup3D: Setting up item %s x%d" % [item_id, amount])

	# Update initial_position to current position (in case it was set by ItemDropManager)
	initial_position = global_position
	print("ItemPickup3D: Updated initial_position to %s" % initial_position)

	# Defer setup_visuals to ensure the node is fully in the tree
	call_deferred("setup_visuals")

func setup_visuals():
	if not is_inside_tree():
		print("ItemPickup3D[%s]: Not in tree yet, will retry setup_visuals" % name)
		call_deferred("setup_visuals")
		return

	if not InventorySystem:
		print("ItemPickup3D[%s]: InventorySystem not available for setup" % name)
		return

	if item_id.is_empty():
		print("ItemPickup3D[%s]: item_id is empty, cannot setup visuals" % name)
		return

	var item_data = InventorySystem.get_item_data(item_id)
	var item_name = item_data.get("name", "Unknown Item")
	print("ItemPickup3D[%s]: Setting up visuals for %s (name: %s) at position %s" % [name, item_id, item_name, global_position])

	if mesh_instance:
		if not mesh_instance.mesh:
			var box_mesh = BoxMesh.new()
			box_mesh.size = Vector3(0.4, 0.4, 0.4)
			mesh_instance.mesh = box_mesh

		var material = StandardMaterial3D.new()
		material.albedo_color = get_item_color(item_data.get("category", "Misc"))
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy = glow_intensity
		material.roughness = 0.2
		material.metallic = 0.8
		mesh_instance.set_surface_override_material(0, material)

	if collision_shape:
		if not collision_shape.shape:
			var sphere_shape = SphereShape3D.new()
			sphere_shape.radius = 0.3
			collision_shape.shape = sphere_shape

	if label_3d:
		label_3d.text = item_name
		if amount > 1:
			label_3d.text += " x%d" % amount
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.no_depth_test = true
		label_3d.modulate = Color.WHITE
		label_3d.outline_modulate = Color.BLACK
		label_3d.position = Vector3(0, 0.6, 0)

	if omni_light:
		omni_light.light_color = get_item_color(item_data.get("category", "Misc"))
		omni_light.light_energy = 0.5
		omni_light.omni_range = 2.0
		omni_light.shadow_enabled = false

func get_item_color(category: String) -> Color:
	match category.to_lower():
		"resource":
			return Color(0.2, 0.8, 0.2)  # Green
		"weapon":
			return Color(0.8, 0.2, 0.2)  # Red
		"consumable":
			return Color(0.2, 0.2, 0.8)  # Blue
		"crafting":
			return Color(0.8, 0.8, 0.2)  # Yellow
		"building":
			return Color(0.8, 0.4, 0.2)  # Orange
		"building_material":
			return Color(0.6, 0.6, 0.7)  # Stone gray
		"component":
			return Color(0.8, 0.2, 0.8)  # Magenta
		"ammo":
			return Color(0.6, 0.6, 0.6)  # Gray
		"material":
			return Color(0.4, 0.7, 0.9)  # Light cyan
		"organic":
			return Color(0.5, 0.8, 0.3)  # Lime green
		_:
			return Color(0.5, 0.5, 0.8)  # Light blue (default)

func _on_body_entered(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = true
		if auto_pickup:
			collect_item()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player"):
		player_in_range = false

func check_pickup_distance():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var distance = global_position.distance_to(player.global_position)
	if distance <= pickup_range:
		collect_item()

func collect_item():
	if is_collected:
		return

	is_collected = true

	if InventorySystem:
		if InventorySystem.add_item(item_id, amount):
			print("Collected %d %s" % [amount, item_id])
		else:
			print("Failed to add %s to inventory (inventory full?)" % item_id)
			is_collected = false
			return

	create_collection_effect()

	if audio_player and pickup_sound:
		audio_player.stream = pickup_sound
		audio_player.play()
		audio_player.finished.connect(queue_free)
	else:
		queue_free()

	picked_up.emit(item_id, amount)

func create_collection_effect():
	# Start particle effect
	if particles:
		particles.emitting = true
		particles.amount = 20
		particles.lifetime = 0.5
		particles.one_shot = true

	# Create a pickup animation with scale and fade
	if mesh_instance:
		var tween = create_tween()
		tween.parallel().tween_property(mesh_instance, "scale", Vector3(1.5, 1.5, 1.5), 0.2)
		tween.parallel().tween_property(mesh_instance, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): mesh_instance.visible = false)

	if label_3d:
		var tween = create_tween()
		tween.parallel().tween_property(label_3d, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): label_3d.visible = false)

	# Light flash effect
	if omni_light:
		var tween = create_tween()
		tween.tween_property(omni_light, "light_energy", 2.0, 0.1)
		tween.tween_property(omni_light, "light_energy", 0.0, 0.4)

	# Create floating text effect
	create_floating_text_effect()

func create_floating_text_effect():
	# Create a floating "+Item Name x1" text effect
	var floating_text = Label3D.new()
	floating_text.text = "+" + InventorySystem.get_item_data(item_id).get("name", item_id)
	if amount > 1:
		floating_text.text += " x%d" % amount

	floating_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	floating_text.no_depth_test = true
	floating_text.modulate = Color.WHITE
	floating_text.outline_modulate = Color.BLACK
	floating_text.outline_size = 2

	# Add to the current scene instead of parent to avoid cleanup issues
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(floating_text)
		floating_text.global_position = global_position + Vector3(0, 1, 0)

		# Animate the floating text with proper cleanup
		var tween = get_tree().create_tween()
		tween.parallel().tween_property(floating_text, "global_position", floating_text.global_position + Vector3(0, 1, 0), 1.0)
		tween.parallel().tween_property(floating_text, "modulate:a", 0.0, 1.0)
		tween.tween_callback(func():
			if is_instance_valid(floating_text):
				floating_text.queue_free()
		)

func _input(event: InputEvent):
	if not player_in_range or auto_pickup:
		return

	if event.is_action_pressed("interact"):
		collect_item()