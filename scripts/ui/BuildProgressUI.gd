extends Control
class_name BuildProgressUI

## UI that shows building progress when player holds E on a template

@onready var progress_container: CenterContainer = $CenterContainer
@onready var progress_bar: ProgressBar = $CenterContainer/VBoxContainer/ProgressBar
@onready var building_label: Label = $CenterContainer/VBoxContainer/BuildingLabel

var player: Node = null

func _ready():
	# Start hidden
	visible = false

	# Find player and connect to build progress signal
	call_deferred("connect_to_player")

func connect_to_player():
	player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("build_progress_changed"):
		player.build_progress_changed.connect(_on_build_progress_changed)
		print("BuildProgressUI: Connected to player build_progress_changed signal")
	else:
		print("BuildProgressUI: WARNING - Could not find player or signal")

func _on_build_progress_changed(progress: float, template_name: String):
	# Show UI when progress > 0, hide when 0
	if progress > 0.0:
		visible = true
		progress_bar.value = progress * 100.0  # Convert 0-1 to 0-100
		building_label.text = "Building: %s" % template_name
	else:
		visible = false
		progress_bar.value = 0.0
		building_label.text = ""
