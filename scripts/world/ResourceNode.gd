extends StaticBody3D
class_name ResourceNode

## Base class for all minable resource nodes
## Handles health, mining requirements, resource drops, and respawning

signal node_mined(node: ResourceNode)
signal node_destroyed(node: ResourceNode)
signal health_changed(current: float, maximum: float)

## Resource drop configuration
@export_group("Resource Drops")
@export var drop_table: Array[ResourceDrop] = []

## Mining requirements
@export_group("Mining Requirements")
@export_enum("None", "Pickaxe", "Axe") var required_tool: String = "Pickaxe"
@export_range(1, 10) var required_tool_level: int = 1

## Node health
@export_group("Health")
@export var max_health: float = 100.0
@export var current_health: float = 100.0

## Respawn settings
@export_group("Respawn")
@export var can_respawn: bool = true
@export var respawn_time: float = 300.0  # 5 minutes default

## Visual feedback
@export_group("Visuals")
@export var mining_particles: PackedScene
@export var destruction_particles: PackedScene

var is_being_mined: bool = false
var is_destroyed: bool = false
var mining_effect_instance: Node3D = null

func _ready() -> void:
	current_health = max_health
	add_to_group("resource_nodes")

## Check if player has required tool and level
func can_mine(player_tool: String, player_tool_level: int) -> bool:
	if required_tool == "None":
		return true

	if player_tool != required_tool:
		return false

	return player_tool_level >= required_tool_level

## Apply mining damage to the node
func mine(damage: float, player_tool: String, player_tool_level: int) -> bool:
	if is_destroyed:
		return false

	if not can_mine(player_tool, player_tool_level):
		return false

	current_health -= damage
	health_changed.emit(current_health, max_health)

	# Start mining visual effect
	if not is_being_mined:
		start_mining_effect()

	if current_health <= 0:
		destroy_node()
		return true

	return true

## Start visual mining effect
func start_mining_effect() -> void:
	is_being_mined = true

	if mining_particles and not mining_effect_instance:
		mining_effect_instance = mining_particles.instantiate()
		add_child(mining_effect_instance)

		# Position at center of node
		if mining_effect_instance is GPUParticles3D:
			mining_effect_instance.emitting = true

## Stop visual mining effect
func stop_mining_effect() -> void:
	is_being_mined = false

	if mining_effect_instance:
		if mining_effect_instance is GPUParticles3D:
			mining_effect_instance.emitting = false

		# Clean up after particles finish
		await get_tree().create_timer(2.0).timeout
		if mining_effect_instance:
			mining_effect_instance.queue_free()
			mining_effect_instance = null

## Destroy the node and drop resources
func destroy_node() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	stop_mining_effect()

	# Spawn destruction particles
	if destruction_particles:
		var destruction_fx = destruction_particles.instantiate()
		get_parent().add_child(destruction_fx)
		destruction_fx.global_position = global_position

		if destruction_fx is GPUParticles3D:
			destruction_fx.emitting = true
			destruction_fx.finished.connect(destruction_fx.queue_free)

	# Drop resources
	drop_resources()

	# Emit signals
	node_mined.emit(self)
	node_destroyed.emit(self)

	# Handle respawn or removal
	if can_respawn:
		hide()
		set_process(false)
		collision_layer = 0
		collision_mask = 0
		await get_tree().create_timer(respawn_time).timeout
		respawn()
	else:
		queue_free()

## Drop resources based on drop table
func drop_resources() -> void:
	if not ItemDropManager:
		push_warning("ItemDropManager not found, cannot drop resources")
		return

	for drop in drop_table:
		if drop and randf() <= drop.drop_chance:
			var amount = randi_range(drop.min_amount, drop.max_amount)
			if amount > 0:
				# Use the correct function name from ItemDropManager
				ItemDropManager.spawn_item_pickup_3d(
					ItemDropManager.GENERIC_PICKUP_3D_SCENE,
					global_position,
					drop.item_id,
					amount
				)

## Respawn the node
func respawn() -> void:
	current_health = max_health
	is_destroyed = false
	is_being_mined = false
	show()
	set_process(true)
	collision_layer = 1
	collision_mask = 1
	health_changed.emit(current_health, max_health)

## Get mining progress (0.0 to 1.0)
func get_mining_progress() -> float:
	return 1.0 - (current_health / max_health)
