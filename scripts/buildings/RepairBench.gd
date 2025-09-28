extends StaticBody2D

class_name RepairBench

# Signal for future UI integration
# signal repair_interface_requested(repair_bench: RepairBench)

@export var building_id: String = "repair_bench"
@export var interaction_range: float = 64.0

var health: float = 80.0
var max_health: float = 80.0

func _ready():
	add_to_group("buildings")
	add_to_group("interactable")

func interact(player: Node):
	if not player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	if distance > interaction_range:
		print("Too far from repair bench")
		return
	
	# Open repair interface
	print("Opening repair bench interface...")
	
	# For now, just show what items could be repaired
	show_repair_preview(player)

func show_repair_preview(player: Node):
	print("=== REPAIR BENCH ===")
	print("Items that can be repaired:")
	
	var repairable_items = get_repairable_items(player)
	if repairable_items.is_empty():
		print("No damaged items found.")
		return
	
	for item in repairable_items:
		var condition = item.get_equipment_condition_text() if item.has_method("get_equipment_condition_text") else item.get_weapon_condition_text()
		var durability_pct = int(item.get_durability_percentage() * 100)
		var repair_cost = calculate_repair_cost(item)
		
		print("- %s (%s - %d%% durability)" % [item.name, condition, durability_pct])
		print("  Repair cost: %s" % format_repair_cost(repair_cost))

func get_repairable_items(_player: Node) -> Array:
	var items = []
	
	# Check equipped items
	if EquipmentManager:
		for slot in EquipmentManager.EQUIPMENT_SLOTS:
			var equipment = EquipmentManager.get_equipped_item(slot)
			if equipment and equipment.has_method("get_durability_percentage"):
				if equipment.get_durability_percentage() < 1.0:
					items.append(equipment)
	
	# Check equipped weapons
	if WeaponManager:
		var primary_weapon = WeaponManager.get_equipped_weapon("PRIMARY_WEAPON")
		if primary_weapon and primary_weapon.get_durability_percentage() < 1.0:
			items.append(primary_weapon)
		
		var secondary_weapon = WeaponManager.get_equipped_weapon("SECONDARY_WEAPON")
		if secondary_weapon and secondary_weapon.get_durability_percentage() < 1.0:
			items.append(secondary_weapon)
	
	# TODO: Check inventory items as well
	
	return items

func calculate_repair_cost(item) -> Dictionary:
	var base_cost = {}
	var durability_lost = item.durability - item.current_durability
	var tier = item.tier if item.has("tier") else 1
	
	# Base repair materials based on item tier and damage
	var scrap_needed = int(durability_lost * tier * 0.1)  # 0.1 scrap per durability per tier
	var electronics_needed = int(durability_lost * tier * 0.05)  # Electronics for higher-tier items
	
	if scrap_needed > 0:
		base_cost["SCRAP_METAL"] = scrap_needed
	
	if tier >= 2 and electronics_needed > 0:
		base_cost["ELECTRONICS"] = electronics_needed
	
	# Additional materials for weapons
	if item.has_method("is_melee") or item.has_method("is_ranged"):
		if item.tier >= 3:
			base_cost["GEARS"] = max(1, int(durability_lost * 0.02))
	
	return base_cost

func format_repair_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "Free"
	
	var cost_parts = []
	for resource in cost:
		cost_parts.append("%d %s" % [cost[resource], resource])
	
	return cost_parts.join(", ")

func can_afford_repair(item, _player: Node) -> bool:
	var cost = calculate_repair_cost(item)
	
	for resource in cost:
		var needed = cost[resource]
		if not InventorySystem.has_item(resource, needed):
			return false
	
	return true

func repair_item(item, player: Node) -> bool:
	var cost = calculate_repair_cost(item)
	
	if not can_afford_repair(item, player):
		print("Insufficient materials for repair!")
		return false
	
	# Consume resources
	for resource in cost:
		var needed = cost[resource]
		if not InventorySystem.remove_item(resource, needed):
			print("Failed to consume %s for repair" % resource)
			return false
	
	# Repair the item to full durability
	if item.has_method("repair_equipment"):
		item.repair_equipment(item.durability - item.current_durability)
	elif item.has_method("repair_weapon"):
		item.repair_weapon(item.durability - item.current_durability)
	
	print("Successfully repaired %s!" % item.name)
	
	# Update equipment stats if it's equipped
	if EquipmentManager:
		EquipmentManager.update_total_stats()
	
	# Grant Life Support XP for maintenance work
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var xp_amount = item.tier * 10  # XP based on item complexity
		skill_system.add_xp("LIFE_SUPPORT", xp_amount, "equipment_repair")
	
	return true

func get_building_id() -> String:
	return building_id

func take_damage(damage_amount: float):
	health = max(0, health - damage_amount)
	if health <= 0:
		destroy_building()

func destroy_building():
	print("Repair bench destroyed!")
	queue_free()

func get_health_percentage() -> float:
	return health / max_health if max_health > 0 else 0.0
