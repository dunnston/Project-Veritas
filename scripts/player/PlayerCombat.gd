extends Node
class_name PlayerCombat

@export var base_punch_damage: int = 5
@export var base_punch_range: float = 50.0
@export var base_attack_cooldown: float = 0.5
@export var attack_arc: float = 90.0

var can_attack: bool = true
var attack_timer: float = 0.0
var is_attacking: bool = false
var current_attack_cooldown: float = 0.5

@onready var player: CharacterBody3D = get_parent()
@onready var combat_system: Node = get_node_or_null("/root/CombatSystem")
@onready var weapon_manager: Node = get_node_or_null("/root/WeaponManager")
@onready var projectile_system: Node = get_node_or_null("/root/ProjectileSystem")

signal attack_started()
signal attack_finished()
signal hit_enemy(enemy: Node)
signal weapon_switched()

func _ready() -> void:
	if not player:
		print("ERROR: PlayerCombat must be child of player (CharacterBody3D)")
		return

	if weapon_manager:
		weapon_manager.weapon_switched.connect(_on_weapon_switched)

	print("Player combat system initialized")

func _process(delta: float) -> void:
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
			attack_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Don't allow attacks when UI is open
	if is_ui_blocking_input():
		print("PlayerCombat: Blocking input due to UI")
		return

	if event.is_action_pressed("attack") and can_attack and not is_attacking:
		print("PlayerCombat: Processing attack input")
		var weapon_data = get_current_weapon_data()

		if weapon_data.weapon and weapon_data.weapon.is_ranged():
			perform_ranged_attack(event.global_position)
		else:
			perform_melee_attack()

		get_viewport().set_input_as_handled()

	if event.is_action_pressed("switch_weapon"):
		cycle_weapons()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("reload") or (event is InputEventKey and event.pressed and event.keycode == KEY_R):
		reload_weapon()
		get_viewport().set_input_as_handled()

func perform_melee_attack() -> void:
	if not can_attack or is_attacking:
		return

	is_attacking = true
	can_attack = false

	var weapon_data = get_current_weapon_data(true)  # Calculate crits for actual attacks
	current_attack_cooldown = weapon_data.cooldown
	attack_timer = current_attack_cooldown

	attack_started.emit()

	var using_punch_animation = false

	if weapon_data.weapon:
		print("Attacking with %s (damage: %d, range: %.1f)" % [weapon_data.name, weapon_data.damage, weapon_data.range])
		# Play weapon swing animation (white flash for now)
		player.modulate = Color(1.5, 1.5, 1.5)
	else:
		print("Punching (damage: %d, range: %.1f)" % [weapon_data.damage, weapon_data.range])
		# Play punch animation for unarmed attacks
		if player.has_method("play_punch_animation"):
			player.play_punch_animation()
			using_punch_animation = true

	# Check for hits mid-animation (timing it with the punch)
	if using_punch_animation:
		# Wait for punch to reach impact point (about halfway through animation)
		await get_tree().create_timer(0.15).timeout

	var hit_something = check_melee_hit(weapon_data)

	# Only reduce weapon durability if we hit something
	if hit_something and weapon_data.weapon:
		weapon_data.weapon.use_weapon()
		print("Weapon durability: %d/%d" % [weapon_data.weapon.current_durability, weapon_data.weapon.durability])

	# Wait for animation to finish or flash to end
	if using_punch_animation:
		# Punch animation handles itself, just wait for it to finish
		await get_tree().create_timer(0.35).timeout
	else:
		# Weapon flash effect
		await get_tree().create_timer(0.2).timeout
		player.modulate = Color.WHITE
	is_attacking = false
	attack_finished.emit()

func perform_ranged_attack(_target_pos: Vector3) -> void:
	if not can_attack or is_attacking:
		print("Cannot attack: can_attack=%s, is_attacking=%s" % [can_attack, is_attacking])
		return

	var weapon_data = get_current_weapon_data()
	if not weapon_data.weapon:
		print("No weapon equipped")
		return

	if not weapon_data.weapon.is_ranged():
		print("Weapon is not ranged: %s" % weapon_data.weapon.name)
		return

	# Check if weapon can attack (has ammo)
	if not weapon_data.weapon.can_attack():
		if weapon_data.weapon.current_ammo <= 0:
			print("Need to reload! Press R to reload %s" % weapon_data.weapon.name)
		else:
			print("Cannot attack with %s (durability: %d)" % [weapon_data.weapon.name, weapon_data.weapon.current_durability])
		return

	is_attacking = true
	can_attack = false
	current_attack_cooldown = weapon_data.cooldown
	attack_timer = current_attack_cooldown

	attack_started.emit()

	print("Firing %s (damage: %d, ammo: %d/%d)" % [weapon_data.name, weapon_data.damage, weapon_data.weapon.current_ammo, weapon_data.weapon.magazine_size])

	# Get camera and raycast for target position
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var world_target = to

	# Create projectile data
	var projectile_data = {
		"damage": weapon_data.damage,
		"speed": weapon_data.range * 10,  # Convert range to speed
		"range": weapon_data.range * 50,   # Convert to pixel range
		"projectile_speed": weapon_data.weapon.attack_speed * 200
	}

	# Fire projectile
	if projectile_system:
		var start_pos = player.global_position + Vector3(0, 1.5, 0)  # Spawn at chest height
		print("Firing projectile from %s to %s" % [start_pos, world_target])
		var projectile = projectile_system.create_projectile(player, start_pos, world_target, projectile_data)
		if projectile:
			print("Projectile created successfully")
		else:
			print("Failed to create projectile!")
	else:
		print("ERROR: ProjectileSystem not found!")

	# Consume ammo and reduce durability
	weapon_data.weapon.use_weapon()

	# Visual feedback for shooting
	player.modulate = Color(1.2, 1.2, 0.8)

	await get_tree().create_timer(0.1).timeout
	player.modulate = Color.WHITE

	is_attacking = false
	attack_finished.emit()

func get_current_weapon_data(calculate_crit: bool = false) -> Dictionary:
	var data = {
		"weapon": null,
		"name": "Fists",
		"damage": base_punch_damage,
		"range": base_punch_range,
		"cooldown": base_attack_cooldown,
		"knockback": 100.0
	}

	if weapon_manager:
		var weapon = weapon_manager.get_active_weapon()
		if weapon:
			data.weapon = weapon
			data.name = weapon.name
			data.damage = weapon.get_effective_damage()
			data.cooldown = base_attack_cooldown / weapon.attack_speed

			if weapon.is_melee():
				data.range = base_punch_range * weapon.attack_range
				data.knockback = 150.0
			elif weapon.is_ranged():
				data.range = weapon.attack_range * 50  # Convert to pixel range for ranged weapons
				data.knockback = 50.0  # Less knockback for ranged weapons

			# Only calculate critical hits during actual attacks
			if calculate_crit and weapon.has_stat("critical_chance"):
				var crit_roll = randf()
				if crit_roll < weapon.get_stat_value("critical_chance"):
					data.damage = int(data.damage * 1.5)
					data.is_critical = true

	if player.has_method("get_damage_modifier"):
		data.damage = int(data.damage * player.get_damage_modifier())

	return data

func check_melee_hit(weapon_data: Dictionary) -> bool:
	var space_state = player.get_world_3d().direct_space_state
	var player_pos = player.global_position
	var facing_direction = -player.global_transform.basis.z  # Forward direction in 3D

	var attack_center = player_pos + (facing_direction * weapon_data.range * 0.5)

	var enemies_hit = []
	# Check both enemies and animals
	var all_bodies = get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("animals")

	for enemy in all_bodies:
		if not is_instance_valid(enemy):
			continue

		var to_enemy = enemy.global_position - player_pos
		var distance = to_enemy.length()

		if distance > weapon_data.range:
			continue

		var angle_to_enemy = rad_to_deg(facing_direction.angle_to(to_enemy.normalized()))
		if abs(angle_to_enemy) <= attack_arc / 2:
			enemies_hit.append(enemy)

	for enemy in enemies_hit:
		if combat_system:
			combat_system.deal_damage(player, enemy, weapon_data.damage, "melee")
			combat_system.apply_knockback(player, enemy, weapon_data.knockback)

		hit_enemy.emit(enemy)

		create_damage_number(enemy.global_position, weapon_data.damage, weapon_data.get("is_critical", false))

	return enemies_hit.size() > 0

func create_damage_number(pos: Vector3, damage: int, is_critical: bool = false) -> void:
	var damage_label = Label3D.new()
	damage_label.text = str(damage)
	damage_label.modulate = Color.RED if is_critical else Color.ORANGE
	damage_label.font_size = 32 if is_critical else 24
	damage_label.outline_size = 4
	damage_label.outline_modulate = Color.BLACK
	damage_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	damage_label.global_position = pos + Vector3(randf_range(-0.3, 0.3), 1.5, randf_range(-0.3, 0.3))

	get_tree().current_scene.add_child(damage_label)

	var tween = create_tween()
	tween.tween_property(damage_label, "global_position", damage_label.global_position + Vector3(0, 1, 0), 0.8)
	tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(damage_label.queue_free)

func cycle_weapons() -> void:
	if not weapon_manager:
		print("No weapon manager available")
		return

	# Cycle through: Primary → Secondary → Fists → Primary...
	var current_slot = weapon_manager.active_weapon_slot
	var next_slot = ""

	if current_slot == "PRIMARY_WEAPON":
		# Check if secondary weapon exists
		if weapon_manager.secondary_weapon:
			next_slot = "SECONDARY_WEAPON"
		else:
			next_slot = ""  # Go to fists
	elif current_slot == "SECONDARY_WEAPON":
		next_slot = ""  # Go to fists
	else:  # Currently on fists or empty
		# Check if primary weapon exists
		if weapon_manager.primary_weapon:
			next_slot = "PRIMARY_WEAPON"
		elif weapon_manager.secondary_weapon:
			next_slot = "SECONDARY_WEAPON"
		else:
			print("No weapons equipped!")
			return

	weapon_manager.active_weapon_slot = next_slot

	# Emit WeaponManager's signal so HUD updates
	var new_weapon = weapon_manager.get_active_weapon()
	if new_weapon:
		weapon_manager.weapon_switched.emit(new_weapon)

	weapon_switched.emit()

	# Visual feedback
	player.modulate = Color(1.2, 1.2, 1.5)
	await get_tree().create_timer(0.2).timeout
	player.modulate = Color.WHITE

	# Print what we switched to
	if next_slot == "PRIMARY_WEAPON":
		print("Switched to Primary: %s" % weapon_manager.primary_weapon.name)
	elif next_slot == "SECONDARY_WEAPON":
		print("Switched to Secondary: %s" % weapon_manager.secondary_weapon.name)
	else:
		print("Switched to Fists")

func _on_weapon_switched(weapon: Weapon) -> void:
	if weapon:
		print("Combat system updated for weapon: %s" % weapon.name)

func get_attack_cooldown_progress() -> float:
	if can_attack:
		return 1.0
	return 1.0 - (attack_timer / current_attack_cooldown)

func can_perform_attack() -> bool:
	return can_attack and not is_attacking

func reload_weapon() -> void:
	if not weapon_manager:
		print("No weapon manager available")
		return

	var weapon = weapon_manager.get_active_weapon()
	if not weapon or not weapon.is_ranged():
		print("No ranged weapon equipped")
		return

	if not weapon.needs_reload():
		print("%s doesn't need reloading (%d/%d)" % [weapon.name, weapon.current_ammo, weapon.magazine_size])
		show_reload_message("WEAPON FULL!")
		return

	# Try to reload from inventory
	if weapon.reload_from_inventory():
		# Visual feedback for successful reload
		show_reload_message("RELOADING...")
		player.modulate = Color(1.2, 1.2, 1.5)  # Blue flash
		await get_tree().create_timer(weapon.reload_time).timeout
		player.modulate = Color.WHITE
		show_reload_message("RELOAD COMPLETE!")
	else:
		show_reload_message("NO AMMO TO RELOAD!")

func get_ammo_ids_of_type(ammo_type: String) -> Array[String]:
	# Map ammo types to specific ammo IDs available in the game
	var ammo_mapping = {
		"BULLET": ["SCRAP_BULLETS", "FIRE_BULLETS"],
		"ARROW": ["WOOD_ARROWS", "STEEL_ARROWS"],
		"ENERGY": ["ENERGY_CELLS"],
		"PLASMA": ["PLASMA_CHARGES"]
	}

	var result: Array[String] = []
	if ammo_mapping.has(ammo_type):
		for ammo_id in ammo_mapping[ammo_type]:
			result.append(ammo_id)

	return result

func is_ui_blocking_input() -> bool:
	# Check if any UI that should block combat input is open
	var inventory_ui = get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui and inventory_ui.visible:
		return true

	var build_menu = get_tree().get_first_node_in_group("build_menu")
	if build_menu and build_menu.visible:
		return true

	var crafting_menu = get_tree().get_first_node_in_group("crafting_menu")
	if crafting_menu and crafting_menu.visible:
		return true

	# Check if any popups are active (like ammo selection)
	# Check all nodes in the weapon_ui group for active popups
	var weapon_uis = get_tree().get_nodes_in_group("weapon_ui")
	for weapon_ui in weapon_uis:
		# Check if the weapon UI has a specific blocking flag
		if weapon_ui.has_method("is_blocking_input") and weapon_ui.is_blocking_input():
			print("Blocking input: Weapon UI is blocking")
			return true

		if weapon_ui.get_child_count() > 0:
			# Check if there are any popup menus active
			for child in weapon_ui.get_children():
				if child is PopupMenu and child.visible:
					print("Blocking input: Found active popup menu")
					return true

	# Add other UIs that should block input here
	return false

func show_reload_message(message: String) -> void:
	var reload_label = Label3D.new()
	reload_label.text = message
	reload_label.modulate = Color.CYAN
	reload_label.font_size = 28
	reload_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reload_label.global_position = player.global_position + Vector3(0, 2, 0)

	get_tree().current_scene.add_child(reload_label)

	var tween = create_tween()
	tween.tween_property(reload_label, "global_position", reload_label.global_position + Vector3(0, 1, 0), 1.5)
	tween.parallel().tween_property(reload_label, "modulate:a", 0.0, 1.5)
	tween.tween_callback(reload_label.queue_free)

func get_weapon_info() -> String:
	var weapon_data = get_current_weapon_data()
	if weapon_data.weapon:
		var weapon = weapon_data.weapon
		return "%s (%d dmg, %d/%d dur)" % [weapon.name, weapon_data.damage, weapon.current_durability, weapon.durability]
	else:
		return "Fists (%d dmg)" % weapon_data.damage
