extends ResourceNode

class_name TreeNode

## DEPRECATED: This class uses the old 2D resource node API
## TODO: Migrate to new 3D ResourceNode API or create new Tree3D class
## For now, this file is disabled to prevent parse errors

# Tree-specific properties (OLD API - NOT COMPATIBLE)
#@export var wood_yield_min: int = 2
#@export var wood_yield_max: int = 4
#@export var health_points: int = 3
#@export var required_axe_tier: int = 1

# NOTE: current_health is inherited from ResourceNode base class

#var hit_feedback_timer: Timer
#var shake_tween: Tween
#var damage_particles: CPUParticles2D  # 2D particles - incompatible with 3D

func _ready() -> void:
	# Configure for new API
	required_tool = "Axe"
	required_tool_level = 1
	max_health = 75.0
	current_health = max_health
	can_respawn = true
	respawn_time = 300.0  # 5 minutes

	super._ready()

# OLD 2D API METHODS - ALL COMMENTED OUT TO PREVENT ERRORS
# These methods need to be completely rewritten for the new 3D ResourceNode API

#func setup_tree_components():
#	pass

#func interact(player: Node) -> void:
#	pass

#func get_player_equipped_tool(player: Node) -> Equipment:
#	return null

#func is_valid_axe(tool: Equipment) -> bool:
#	return false

#func hit_tree(player: Node, axe_tool: Equipment):
#	pass

#func play_hit_effects():
#	pass

#func update_damage_visual():
#	pass

#func chop_down_tree(player: Node):
#	pass

#func play_chop_down_animation():
#	pass

#func show_tool_requirement_message(player: Node):
#	pass

#func _on_respawn() -> void:
#	pass

#func get_info() -> Dictionary:
#	return {}
