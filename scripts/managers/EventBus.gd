extends Node

class_name EventBusSingleton

signal resource_collected(resource_type: String, amount: int)
signal item_crafted(item_id: String)
signal building_placed(building_id: String, position: Vector3)
signal building_removed(building_id: String, position: Vector3)
signal player_damaged(damage: int)
signal player_healed(amount: int)
signal player_stat_changed(stat_name: String, new_value: float)
signal storm_started(intensity: float)
signal storm_ended()
signal day_night_changed(is_day: bool)
signal quest_started(quest_id: String)
signal quest_completed(quest_id: String)
signal achievement_unlocked(achievement_id: String)
signal equipment_ui_toggle_requested()
# Skill progression signals (emitted by SkillSystem, used by UI components)
signal skill_xp_gained(skill: String, amount: int)
signal skill_level_up(skill: String, new_level: int)

func _ready() -> void:
	print("EventBus initialized")

func emit_resource_collected(resource_type: String, amount: int) -> void:
	resource_collected.emit(resource_type, amount)

func emit_item_crafted(item_id: String) -> void:
	item_crafted.emit(item_id)

func emit_building_placed(building_id: String, pos: Vector3) -> void:
	building_placed.emit(building_id, pos)

func emit_building_removed(building_id: String, pos: Vector3) -> void:
	building_removed.emit(building_id, pos)

func emit_player_damaged(damage: int) -> void:
	player_damaged.emit(damage)

func emit_player_healed(amount: int) -> void:
	player_healed.emit(amount)

func emit_player_stat_changed(stat_name: String, value: float) -> void:
	player_stat_changed.emit(stat_name, value)

func emit_storm_started(intensity: float) -> void:
	storm_started.emit(intensity)

func emit_storm_ended() -> void:
	storm_ended.emit()

func emit_day_night_changed(is_day: bool) -> void:
	day_night_changed.emit(is_day)

func emit_quest_started(quest_id: String) -> void:
	quest_started.emit(quest_id)

func emit_quest_completed(quest_id: String) -> void:
	quest_completed.emit(quest_id)

func emit_achievement_unlocked(achievement_id: String) -> void:
	achievement_unlocked.emit(achievement_id)

func emit_equipment_ui_toggle_requested() -> void:
	equipment_ui_toggle_requested.emit()

func emit_skill_xp_gained(skill: String, amount: int) -> void:
	skill_xp_gained.emit(skill, amount)

func emit_skill_level_up(skill: String, new_level: int) -> void:
	skill_level_up.emit(skill, new_level)
