extends Control

class_name ShelterStatusUI

@onready var shelter_label: Label = $ShelterLabel
@onready var integrity_bar: ProgressBar = $IntegrityBar
@onready var missing_label: Label = $MissingLabel

var last_shelter_quality: ShelterSystem.ShelterQuality = ShelterSystem.ShelterQuality.NO_SHELTER

func _ready() -> void:
	# Connect to ShelterSystem signals
	if ShelterSystem:
		ShelterSystem.shelter_integrity_changed.connect(_on_shelter_integrity_changed)
		ShelterSystem.shelter_status_changed.connect(_on_shelter_status_changed)
	
	# Start hidden during good weather
	visible = false
	
	# Connect to StormSystem to show/hide based on storm status
	if StormSystem:
		StormSystem.storm_phase_changed.connect(_on_storm_phase_changed)
		StormSystem.storm_warning_issued.connect(_on_storm_warning_issued)

func _on_shelter_integrity_changed(integrity_percent: float) -> void:
	if integrity_bar:
		integrity_bar.value = integrity_percent
		
		# Color code the progress bar based on integrity
		var bar_color = Color.RED
		if integrity_percent >= 75:
			bar_color = Color.GREEN
		elif integrity_percent >= 50:
			bar_color = Color.YELLOW
		elif integrity_percent >= 25:
			bar_color = Color.ORANGE
		
		# Update progress bar color (if it has a style)
		var stylebox = integrity_bar.get("theme_override_styles/fill") 
		if stylebox and stylebox.has_method("set_bg_color"):
			stylebox.set_bg_color(bar_color)

func _on_shelter_status_changed(is_fully_sheltered: bool, missing_components: Array) -> void:
	var current_quality = ShelterSystem.get_current_shelter_quality()
	last_shelter_quality = current_quality
	
	if shelter_label:
		var quality_text = ShelterSystem.get_quality_name(current_quality)
		var status_color = get_quality_color(current_quality)
		shelter_label.text = "[color=%s]%s[/color]" % [status_color.to_html(), quality_text]
		shelter_label.modulate = status_color
	
	if missing_label and missing_components.size() > 0:
		var missing_text = "Missing: " + ShelterSystem.get_missing_components_text(missing_components)
		missing_label.text = missing_text
		missing_label.visible = true
		missing_label.modulate = Color.ORANGE
	elif missing_label:
		missing_label.visible = false

func _on_storm_phase_changed(phase: StormSystem.StormPhase) -> void:
	# Show shelter status during storm warnings and active storms
	match phase:
		StormSystem.StormPhase.CALM:
			visible = false
		StormSystem.StormPhase.EARLY_WARNING:
			visible = true
			show_shelter_advice()
		StormSystem.StormPhase.INCOMING_WARNING:
			visible = true
			show_shelter_advice()
		StormSystem.StormPhase.IMMEDIATE_WARNING:
			visible = true
			show_urgent_shelter_warning()
		StormSystem.StormPhase.STORM_ACTIVE:
			visible = true

func _on_storm_warning_issued(warning_type: StormSystem.WarningType, time_remaining: float, storm_type: StormSystem.StormType) -> void:
	# Show shelter status when storm warnings are issued
	visible = true

func show_shelter_advice() -> void:
	var current_quality = ShelterSystem.get_current_shelter_quality()
	var integrity = ShelterSystem.get_current_integrity_percent()
	
	if integrity < 50.0:
		show_notification("Warning: Shelter integrity low! Storm approaching!")
	elif current_quality == ShelterSystem.ShelterQuality.NO_SHELTER:
		show_notification("No shelter detected! Build walls and roof for protection!")

func show_urgent_shelter_warning() -> void:
	var current_quality = ShelterSystem.get_current_shelter_quality()
	
	if current_quality == ShelterSystem.ShelterQuality.NO_SHELTER:
		show_notification("URGENT: Storm imminent! Seek immediate shelter!", Color.RED)
	elif current_quality < ShelterSystem.ShelterQuality.GOOD_SHELTER:
		show_notification("WARNING: Partial shelter only! Storm damage likely!", Color.ORANGE)

func show_notification(message: String, color: Color = Color.YELLOW) -> void:
	print("ShelterStatusUI: %s" % message)
	# This could be enhanced with a proper notification system

func get_quality_color(quality: ShelterSystem.ShelterQuality) -> Color:
	match quality:
		ShelterSystem.ShelterQuality.NO_SHELTER:
			return Color.RED
		ShelterSystem.ShelterQuality.BASIC_SHELTER:
			return Color.ORANGE
		ShelterSystem.ShelterQuality.PARTIAL_SHELTER:
			return Color.YELLOW
		ShelterSystem.ShelterQuality.GOOD_SHELTER:
			return Color.LIGHT_GREEN
		ShelterSystem.ShelterQuality.COMPLETE_SHELTER:
			return Color.GREEN
		_:
			return Color.WHITE

func toggle_visibility() -> void:
	visible = !visible

# Debug method to force show shelter status
func debug_show_shelter_status() -> void:
	visible = true
	if ShelterSystem:
		ShelterSystem.force_update_shelter()
		ShelterSystem.debug_print_shelter_status()