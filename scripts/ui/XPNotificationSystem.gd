extends Control

class_name XPNotificationSystem

# Scene for individual XP notifications (removed preload - creating notifications dynamically)

# Container for notifications
var notifications_container: VBoxContainer

func _ready() -> void:
	# Create notifications container
	notifications_container = VBoxContainer.new()
	notifications_container.position = Vector2(50, 50)
	add_child(notifications_container)
	
	# Connect to skill system signals
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		skill_system.skill_xp_gained.connect(_on_xp_gained)
		skill_system.skill_level_up.connect(_on_level_up)

func _on_xp_gained(skill: String, amount: int) -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var skill_name = skill_system.SKILLS[skill].display_name
		show_xp_notification(skill_name, amount, false)

func _on_level_up(skill: String, new_level: int) -> void:
	if has_node("/root/SkillSystem"):
		var skill_system = get_node("/root/SkillSystem")
		var skill_name = skill_system.SKILLS[skill].display_name
		show_level_up_notification(skill_name, new_level)

func show_xp_notification(skill_name: String, amount: int, is_level_up: bool = false) -> void:
	var notification = create_xp_notification(skill_name, amount, is_level_up)
	notifications_container.add_child(notification)
	
	# Animate in
	notification.modulate.a = 0.0
	notification.position.x = -200
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "position:x", 0, 0.3)
	
	# Auto-remove after delay
	tween.tween_delay(2.0)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): notification.queue_free())

func show_level_up_notification(skill_name: String, new_level: int) -> void:
	var notification = create_level_up_notification(skill_name, new_level)
	notifications_container.add_child(notification)
	
	# Special level-up animation
	notification.modulate.a = 0.0
	notification.scale = Vector2.ZERO
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.5)
	tween.tween_property(notification, "scale", Vector2.ONE, 0.5)
	
	# Pulse effect
	tween.tween_delay(0.5)
	tween.tween_property(notification, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(notification, "scale", Vector2.ONE, 0.2)
	
	# Auto-remove after longer delay for level-ups
	tween.tween_delay(2.0)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): notification.queue_free())

func create_xp_notification(skill_name: String, amount: int, is_level_up: bool) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(250, 40)
	
	var label = Label.new()
	label.text = "+%d XP - %s" % [amount, skill_name]
	label.position = Vector2(10, 10)
	label.add_theme_color_override("font_color", Color.LIGHT_BLUE)
	panel.add_child(label)
	
	return panel

func create_level_up_notification(skill_name: String, new_level: int) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 60)
	
	# Add glow effect
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.6, 1.0, 0.8)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color.GOLD
	panel.add_theme_stylebox_override("panel", style_box)
	
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	panel.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "🎉 LEVEL UP!"
	title_label.add_theme_color_override("font_color", Color.GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	
	var skill_label = Label.new()
	skill_label.text = "%s reached Level %d" % [skill_name, new_level]
	skill_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(skill_label)
	
	return panel