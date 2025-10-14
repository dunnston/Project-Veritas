extends Control
class_name NotificationUI

## Shows temporary notification messages

@onready var notification_label: Label = $NotificationLabel

var current_message: String = ""
var message_timer: Timer = null

func _ready():
	# Start hidden
	visible = false

	# Create timer for auto-hiding messages
	message_timer = Timer.new()
	message_timer.name = "MessageTimer"
	message_timer.wait_time = 3.0
	message_timer.one_shot = true
	message_timer.timeout.connect(_on_message_timer_timeout)
	add_child(message_timer)

	# Connect to EventBus if available
	if EventBus and EventBus.has_signal("show_notification"):
		EventBus.show_notification.connect(_on_show_notification)
		print("NotificationUI: Connected to EventBus.show_notification")
	else:
		print("NotificationUI: WARNING - EventBus.show_notification signal not found")

func _on_show_notification(message: String, color: Color = Color.WHITE):
	show_message(message, color)

func show_message(message: String, color: Color = Color.WHITE):
	"""Show a notification message"""
	current_message = message
	notification_label.text = message
	notification_label.add_theme_color_override("font_color", color)
	visible = true

	# Restart timer
	message_timer.start()

	print("NotificationUI: Showing message: %s" % message)

func _on_message_timer_timeout():
	"""Hide message when timer expires"""
	visible = false
	current_message = ""
	notification_label.text = ""
