extends ResourceNode

class_name TreeNode

# Tree-specific properties
@export var wood_yield_min: int = 2
@export var wood_yield_max: int = 4
@export var health_points: int = 3
@export var required_axe_tier: int = 1

var current_health: int
var hit_feedback_timer: Timer

# Visual feedback
var shake_tween: Tween
var damage_particles: CPUParticles2D

func _ready() -> void:
	print("TreeNode: _ready() called for ", name)
	
	# Initialize as wood resource node
	resource_type = "WOOD"
	resource_amount = randi_range(wood_yield_min, wood_yield_max)
	current_amount = resource_amount
	current_health = health_points
	required_tool = "axe"
	harvest_time = 0.0  # Immediate harvest after health depleted
	respawn_time = 300.0  # 5 minutes
	
	print("TreeNode: Initialized with health=", current_health, ", wood_amount=", resource_amount)
	print("TreeNode: Groups before parent ready: ", get_groups())
	
	# Call parent ready
	super._ready()
	
	print("TreeNode: Groups after parent ready: ", get_groups())
	print("TreeNode: Has interact method: ", has_method("interact"))
	print("TreeNode: Collision layer: ", collision_layer)
	print("TreeNode: Collision mask: ", collision_mask)
	
	# Set collision layer for both solid collision and interaction
	collision_layer = 1 + 128  # Layer 1 (World) + Layer 8 (Interactables) = 1 + 128 = 129
	print("TreeNode: Updated collision layer to: ", collision_layer, " (World + Interactables)")
	
	# Setup tree-specific components
	setup_tree_components()

func setup_tree_components():
	# Hit feedback timer
	hit_feedback_timer = Timer.new()
	hit_feedback_timer.wait_time = 0.5
	hit_feedback_timer.one_shot = true
	add_child(hit_feedback_timer)
	
	# Damage particles (wood chips)
	damage_particles = CPUParticles2D.new()
	damage_particles.emitting = false
	damage_particles.amount = 10
	damage_particles.lifetime = 1.0
	damage_particles.direction = Vector2(0, -1)
	damage_particles.initial_velocity_min = 50.0
	damage_particles.initial_velocity_max = 100.0
	damage_particles.angular_velocity_min = -180.0
	damage_particles.angular_velocity_max = 180.0
	damage_particles.scale_amount_min = 0.5
	damage_particles.scale_amount_max = 1.5
	add_child(damage_particles)

func interact(player: Node) -> void:
	print("TreeNode: interact() called by player")
	
	if is_depleted:
		print("TreeNode: Tree is already depleted")
		return
	
	print("TreeNode: Checking for equipped tool...")
	
	# Check if player has required axe
	var equipped_tool = get_player_equipped_tool(player)
	print("TreeNode: Equipped tool = ", equipped_tool)
	
	if not equipped_tool:
		print("TreeNode: No tool equipped")
		show_tool_requirement_message(player)
		return
	
	if not is_valid_axe(equipped_tool):
		print("TreeNode: Tool is not a valid axe - ID: ", equipped_tool.id if equipped_tool else "null")
		show_tool_requirement_message(player)
		return
	
	print("TreeNode: Valid axe found, hitting tree")
	# Perform axe hit
	hit_tree(player, equipped_tool)

func get_player_equipped_tool(player: Node) -> Equipment:
	print("TreeNode: Getting player equipped tool...")
	print("TreeNode: Player node = ", player)
	print("TreeNode: Player has get_equipped_item method = ", player.has_method("get_equipped_item"))
	
	if not player.has_method("get_equipped_item"):
		print("TreeNode: Player does not have get_equipped_item method")
		return null
	
	var tool = player.get_equipped_item("TOOL")
	print("TreeNode: Player equipped TOOL = ", tool)
	return tool

func is_valid_axe(tool: Equipment) -> bool:
	if not tool:
		return false
	# Check if tool ID contains 'axe' and meets tier requirement
	return tool.id.to_lower().contains("axe") and tool.tier >= required_axe_tier

func hit_tree(player: Node, axe_tool: Equipment):
	print("TreeNode: hit_tree() called")
	print("TreeNode: Current health = ", current_health)
	print("TreeNode: Axe tool tier = ", axe_tool.tier)
	
	# Prevent spam clicking
	if not hit_feedback_timer.is_stopped():
		print("TreeNode: Hit feedback timer still running, ignoring hit")
		return
	
	hit_feedback_timer.start()
	
	# Calculate damage based on axe effectiveness
	var damage = 1
	if axe_tool.tier >= 2:
		damage = 2  # Steel/Advanced axes do more damage
	
	print("TreeNode: Damage to apply = ", damage)
	
	# Apply damage
	current_health -= damage
	print("TreeNode: New health = ", current_health)
	
	# Visual and audio feedback
	play_hit_effects()
	
	# Reduce tool durability
	if axe_tool.has_method("reduce_durability"):
		axe_tool.reduce_durability(1)
		print("TreeNode: Reduced axe durability")
	else:
		print("TreeNode: Axe does not have reduce_durability method")
	
	# Update visual to show damage
	update_damage_visual()
	
	# Check if tree is chopped down
	if current_health <= 0:
		print("TreeNode: Tree health depleted, chopping down")
		chop_down_tree(player)
	else:
		print("TreeNode: Tree still has health, continuing")

func play_hit_effects():
	# Screen shake
	if GameManager.player_node:
		GameManager.player_node.add_screen_shake(2.0)
	
	# Tree shake animation
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	var original_pos = global_position
	shake_tween.tween_property(self, "global_position", original_pos + Vector2(5, 0), 0.1)
	shake_tween.tween_property(self, "global_position", original_pos - Vector2(5, 0), 0.1)
	shake_tween.tween_property(self, "global_position", original_pos, 0.1)
	
	# Emit wood particles
	if damage_particles:
		damage_particles.restart()

func update_damage_visual():
	# Change color based on damage taken
	var damage_ratio = float(health_points - current_health) / float(health_points)
	if sprite:
		sprite.modulate = Color(1.0, 1.0 - damage_ratio * 0.5, 1.0 - damage_ratio * 0.5)

func chop_down_tree(player: Node):
	# Drop wood resources as physical items
	var wood_amount = current_amount
	spawn_dropped_resources("WOOD", wood_amount)
	
	# Grant scavenging XP
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		# Base XP + bonus for chopping trees
		skill_system.add_xp("SCAVENGING", 15, "tree_chopped")
	
	# Emit signals
	resource_harvested.emit("WOOD", wood_amount)
	
	# Visual feedback for tree falling
	play_chop_down_animation()
	
	# Start respawn timer
	deplete()

func play_chop_down_animation():
	# Tree falling animation
	if sprite:
		var fall_tween = create_tween()
		fall_tween.set_parallel(true)
		fall_tween.tween_property(sprite, "rotation", PI/2, 1.0)
		fall_tween.tween_property(sprite, "modulate:a", 0.3, 1.0)

func show_tool_requirement_message(player: Node):
	# Show message about needing an axe
	if player.has_method("show_message"):
		var tier_name = ["Basic", "Steel", "Advanced"][required_axe_tier - 1]
		player.show_message("Requires %s Axe or better" % tier_name)

func _on_respawn() -> void:
	# Reset health when respawning
	current_health = health_points
	resource_amount = randi_range(wood_yield_min, wood_yield_max)
	current_amount = resource_amount
	
	# Call parent respawn
	super._on_respawn()
	
	# Reset visual
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0

func get_info() -> Dictionary:
	var base_info = super.get_info()
	base_info["health"] = current_health
	base_info["max_health"] = health_points
	base_info["required_axe_tier"] = required_axe_tier
	return base_info
