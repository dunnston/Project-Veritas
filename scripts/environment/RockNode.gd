extends ResourceNode

class_name RockNode

## DEPRECATED: This class uses the old 2D resource node API
## TODO: Migrate to new 3D ResourceNode API or create new Rock3D class
## For now, this file is disabled to prevent parse errors

# Rock-specific properties (OLD API - NOT COMPATIBLE)
#@export var stone_yield_min: int = 1
#@export var stone_yield_max: int = 3
#@export var metal_chance: float = 0.15  # 15% chance for metal scraps
#@export var health_points: int = 4
#@export var required_pickaxe_tier: int = 1

# NOTE: current_health is inherited from ResourceNode base class

#var hit_feedback_timer: Timer
#var shake_tween: Tween
#var damage_particles: CPUParticles2D  # 2D particles - incompatible with 3D

func _ready() -> void:
	# Configure for new API
	required_tool = "Pickaxe"
	required_tool_level = 1
	max_health = 100.0
	current_health = max_health
	can_respawn = true
	respawn_time = 600.0  # 10 minutes

	super._ready()

# OLD 2D API METHODS - ALL COMMENTED OUT TO PREVENT ERRORS
# These methods need to be completely rewritten for the new 3D ResourceNode API

#func setup_rock_components():
#	pass

#func interact(player: Node) -> void:
#	pass

#func get_player_equipped_tool(player: Node) -> Equipment:
#	return null

#func is_valid_pickaxe(tool: Equipment) -> bool:
#	return false

#func hit_rock(player: Node, pickaxe_tool: Equipment):
#	pass

#func play_hit_effects():
#	pass

#func update_damage_visual():
#	pass

#func break_rock(player: Node):
#	pass

#func play_break_animation():
#	pass

#func show_tool_requirement_message(player: Node):
#	pass

#func _on_respawn() -> void:
#	pass

#func get_info() -> Dictionary:
#	return {}