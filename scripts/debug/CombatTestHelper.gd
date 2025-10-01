## CombatTestHelper.gd
## Debug helper to equip test weapons for combat testing
extends Node

@export var give_punch: bool = true
@export var give_knife: bool = true
@export var give_gun: bool = true
@export var give_bow: bool = false
@export var give_ammo: bool = true

func _ready() -> void:
	# Wait for systems to initialize
	await get_tree().create_timer(0.5).timeout

	if give_knife:
		add_test_knife()

	if give_gun:
		add_test_gun()

	if give_bow:
		add_test_bow()

	if give_ammo:
		add_test_ammo()

	print("=== Combat Test Helper ===")
	print("Controls:")
	print("  Left Click - Attack")
	print("  R - Reload (guns/bows)")
	print("  Q - Switch between weapons")
	print("  Z - Equip Primary Weapon")
	print("  C - Equip Secondary Weapon")
	print("  V - Unequip (use fists)")
	print("========================")

func add_test_knife() -> void:
	if not WeaponManager or not InventorySystem:
		return

	# Create a test knife
	var knife = WeaponManager.create_weapon("SCRAP_KNIFE")
	if knife:
		knife.damage = 15
		knife.attack_speed = 1.5
		knife.attack_range = 1.5
		knife.stats["critical_chance"] = 0.15  # 15% crit chance

		# Equip to primary slot
		WeaponManager.equip_weapon(knife, "PRIMARY_WEAPON")
		print("Added test knife to primary weapon slot (15 dmg, 15% crit)")
	else:
		print("Failed to create test knife - check weapons.json")

func add_test_gun() -> void:
	if not WeaponManager or not InventorySystem:
		return

	# Create a test gun
	var gun = WeaponManager.create_weapon("SCRAP_PISTOL")
	if gun:
		gun.damage = 20
		gun.attack_speed = 2.0
		gun.attack_range = 30.0
		gun.magazine_size = 10
		gun.current_ammo = 10
		gun.reload_time = 1.5
		gun.compatible_ammo_types = ["BULLET"]
		gun.selected_ammo_id = "SCRAP_BULLETS"

		# Equip to secondary slot
		WeaponManager.equip_weapon(gun, "SECONDARY_WEAPON")
		print("Added test gun to secondary weapon slot (20 dmg, 10 rounds)")
	else:
		print("Failed to create test gun - check weapons.json")

func add_test_bow() -> void:
	if not WeaponManager or not InventorySystem:
		return

	# Create a test bow
	var bow = WeaponManager.create_weapon("WOOD_BOW")
	if bow:
		bow.damage = 25
		bow.attack_speed = 0.8
		bow.attack_range = 40.0
		bow.magazine_size = 1
		bow.current_ammo = 1
		bow.reload_time = 0.8
		bow.compatible_ammo_types = ["ARROW"]
		bow.selected_ammo_id = "WOOD_ARROWS"

		WeaponManager.equip_weapon(bow, "SECONDARY_WEAPON")
		print("Added test bow to secondary weapon slot (25 dmg, reload after each shot)")
	else:
		print("Failed to create test bow - check weapons.json")

func add_test_ammo() -> void:
	if not InventorySystem:
		return

	# Add ammo to inventory
	InventorySystem.add_item("SCRAP_BULLETS", 100)
	InventorySystem.add_item("WOOD_ARROWS", 50)

	print("Added 100 bullets and 50 arrows to inventory")
