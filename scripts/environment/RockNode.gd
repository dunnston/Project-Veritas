extends ResourceNode

class_name RockNode

# Rock-specific properties
@export var stone_yield_min: int = 1
@export var stone_yield_max: int = 3
@export var metal_chance: float = 0.15  # 15% chance for metal scraps
@export var health_points: int = 4
@export var required_pickaxe_tier: int = 1

var current_health: int
var hit_feedback_timer: Timer

# Visual feedback
var shake_tween: Tween
var damage_particles: CPUParticles2D

func _ready() -> void:
	# Initialize as stone resource node
	resource_type = "STONE"
	resource_amount = randi_range(stone_yield_min, stone_yield_max)
	current_amount = resource_amount
	current_health = health_points
	required_tool = "pickaxe"
	harvest_time = 0.0  # Immediate harvest after health depleted
	respawn_time = 600.0  # 10 minutes (rocks take longer to respawn)
	
	# Call parent ready
	super._ready()
	
	# Setup rock-specific components
	setup_rock_components()

func setup_rock_components():
	# Hit feedback timer
	hit_feedback_timer = Timer.new()
	hit_feedback_timer.wait_time = 0.7
	hit_feedback_timer.one_shot = true
	add_child(hit_feedback_timer)
	
	# Damage particles (stone chips)
	damage_particles = CPUParticles2D.new()
	damage_particles.emitting = false
	damage_particles.amount = 15
	damage_particles.lifetime = 1.5
	damage_particles.direction = Vector2(0, -1)
	damage_particles.initial_velocity_min = 30.0
	damage_particles.initial_velocity_max = 80.0
	damage_particles.angular_velocity_min = -120.0
	damage_particles.angular_velocity_max = 120.0
	damage_particles.scale_amount_min = 0.3
	damage_particles.scale_amount_max = 1.2
	add_child(damage_particles)

func interact(player: Node) -> void:
	print("RockNode: interact() called with player: ", player)
	if is_depleted:
		print("RockNode: Rock is depleted, cannot interact")
		return
	
	# Check if player has required pickaxe
	var equipped_tool = get_player_equipped_tool(player)
	print("RockNode: Equipped tool: ", equipped_tool)
	if not equipped_tool or not is_valid_pickaxe(equipped_tool):
		print("RockNode: No valid pickaxe equipped")
		show_tool_requirement_message(player)
		return
	
	# Perform pickaxe hit
	print("RockNode: Performing pickaxe hit")
	hit_rock(player, equipped_tool)

func get_player_equipped_tool(player: Node) -> Equipment:
	if not player.has_method("get_equipped_item"):
		return null
	return player.get_equipped_item("TOOL")

func is_valid_pickaxe(tool: Equipment) -> bool:
	if not tool:
		return false
	# Check if tool ID contains 'pickaxe' and meets tier requirement
	return tool.id.to_lower().contains("pickaxe") and tool.tier >= required_pickaxe_tier

func hit_rock(player: Node, pickaxe_tool: Equipment):
	# Prevent spam clicking
	if not hit_feedback_timer.is_stopped():
		return
	
	hit_feedback_timer.start()
	
	# Calculate damage based on pickaxe effectiveness
	var damage = 1
	if pickaxe_tool.tier >= 2:
		damage = 2  # Steel/Advanced pickaxes do more damage
	
	# Apply damage
	current_health -= damage
	
	# Visual and audio feedback
	play_hit_effects()
	
	# Reduce tool durability (rocks are harder on tools)
	pickaxe_tool.reduce_durability(2)
	
	# Update visual to show damage
	update_damage_visual()
	
	# Check if rock is broken
	if current_health <= 0:
		break_rock(player)

func play_hit_effects():
	# Screen shake (stronger than trees)
	if GameManager.player_node:
		GameManager.player_node.add_screen_shake(4.0)
	
	# Rock shake animation
	if shake_tween:
		shake_tween.kill()
	shake_tween = create_tween()
	var original_pos = global_position
	shake_tween.tween_property(self, "global_position", original_pos + Vector2(3, -2), 0.08)
	shake_tween.tween_property(self, "global_position", original_pos - Vector2(3, 2), 0.08)
	shake_tween.tween_property(self, "global_position", original_pos + Vector2(2, -1), 0.08)
	shake_tween.tween_property(self, "global_position", original_pos, 0.08)
	
	# Emit stone particles
	if damage_particles:
		damage_particles.restart()

func update_damage_visual():
	# Show cracks based on damage
	var damage_ratio = float(health_points - current_health) / float(health_points)
	if sprite:
		# Darken and add red tint to show damage
		var brightness = 1.0 - damage_ratio * 0.3
		sprite.modulate = Color(1.0, brightness, brightness)

func break_rock(player: Node):
	# Drop stone resources as physical items
	var stone_amount = current_amount
	spawn_dropped_resources("STONE", stone_amount)
	
	# Chance for bonus metal scraps
	var found_metal = false
	if randf() < metal_chance:
		found_metal = true
		var metal_amount = randi_range(1, 2)
		spawn_dropped_resources("METAL_SCRAPS", metal_amount)
		if player.has_method("show_message"):
			player.show_message("Found Metal Scraps!")
	
	# Grant scavenging XP
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		# Base XP + bonus for mining rocks
		var xp_amount = 10  # Base XP
		if found_metal:  # Bonus XP if metal found
			xp_amount += 15
		skill_system.add_xp("SCAVENGING", xp_amount, "rock_mined")
	
	# Emit signals
	resource_harvested.emit("STONE", stone_amount)
	
	# Visual feedback for rock breaking
	play_break_animation()
	
	# Start respawn timer
	deplete()

func play_break_animation():
	# Rock breaking animation
	if sprite:
		var break_tween = create_tween()
		break_tween.set_parallel(true)
		# Shake violently then fade
		for i in range(5):
			break_tween.tween_property(sprite, "position", sprite.position + Vector2(randf_range(-5, 5), randf_range(-5, 5)), 0.05)
		break_tween.tween_property(sprite, "modulate:a", 0.2, 0.5)
		break_tween.tween_property(sprite, "scale", Vector2(0.8, 0.8), 0.5)

func show_tool_requirement_message(player: Node):
	# Show message about needing a pickaxe
	if player.has_method("show_message"):
		var tier_name = ["Basic", "Steel", "Advanced"][required_pickaxe_tier - 1]
		player.show_message("Requires %s Pickaxe or better" % tier_name)

func _on_respawn() -> void:
	# Reset health when respawning
	current_health = health_points
	resource_amount = randi_range(stone_yield_min, stone_yield_max)
	current_amount = resource_amount
	
	# Call parent respawn
	super._on_respawn()
	
	# Reset visual
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = Vector2.ONE
		sprite.position = Vector2.ZERO

func get_info() -> Dictionary:
	var base_info = super.get_info()
	base_info["health"] = current_health
	base_info["max_health"] = health_points
	base_info["required_pickaxe_tier"] = required_pickaxe_tier
	base_info["metal_chance"] = metal_chance
	return base_info