extends Control

@onready var weapon_label: Label = $WeaponInfo
@onready var player_combat: PlayerCombat = null

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_combat = player.get_node_or_null("PlayerCombat")
		if player_combat:
			player_combat.attack_finished.connect(_on_attack_finished)
			player_combat.weapon_switched.connect(_on_weapon_switched)

	update_weapon_display()

func _process(_delta: float) -> void:
	update_weapon_display()

func update_weapon_display() -> void:
	if not weapon_label or not player_combat:
		return

	var weapon_info = player_combat.get_weapon_info()
	var cooldown_progress = player_combat.get_attack_cooldown_progress()

	var display_text = "Current Weapon: %s" % weapon_info

	if cooldown_progress < 1.0:
		display_text += "\nCooldown: %.0f%%" % (cooldown_progress * 100)
	else:
		display_text += "\nReady to Attack"

	weapon_label.text = display_text

func _on_attack_finished() -> void:
	update_weapon_display()

func _on_weapon_switched() -> void:
	update_weapon_display()