extends Node2D

class_name WeatherSystem

signal weather_changed(weather_type: String)

enum WeatherType {
	CLEAR,
	TOXIC_STORM,
	ACID_RAIN,
	RADIATION_FOG
}

var current_weather: WeatherType = WeatherType.CLEAR
var storm_intensity: float = 0.0
var weather_particles: CPUParticles2D
var fog_overlay: ColorRect
var storm_audio: AudioStreamPlayer2D

var environment_canvas: CanvasModulate

func _ready() -> void:
	# Get node reference safely
	environment_canvas = get_node_or_null("CanvasModulate")
	
	EventBus.storm_started.connect(_on_storm_started)
	EventBus.storm_ended.connect(_on_storm_ended)
	TimeManager.time_of_day_changed.connect(_on_time_of_day_changed)
	
	setup_weather_effects()

func setup_weather_effects() -> void:
	weather_particles = CPUParticles2D.new()
	add_child(weather_particles)
	weather_particles.emitting = false
	weather_particles.amount = 200
	weather_particles.lifetime = 2.0
	weather_particles.preprocess = 1.0
	weather_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	weather_particles.emission_rect_extents = Vector2(1920, 10)
	weather_particles.direction = Vector2(0.2, 1)
	weather_particles.initial_velocity_min = 100.0
	weather_particles.initial_velocity_max = 200.0
	weather_particles.scale_amount_min = 0.5
	weather_particles.scale_amount_max = 1.5
	
	fog_overlay = ColorRect.new()
	add_child(fog_overlay)
	fog_overlay.color = Color(0.5, 0.8, 0.3, 0.0)
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _on_storm_started(intensity: float) -> void:
	storm_intensity = intensity
	var storm_type = randi() % 3
	
	match storm_type:
		0:
			start_toxic_storm(intensity)
		1:
			start_acid_rain(intensity)
		2:
			start_radiation_fog(intensity)

func _on_storm_ended() -> void:
	storm_intensity = 0.0
	end_all_weather()

func start_toxic_storm(intensity: float) -> void:
	current_weather = WeatherType.TOXIC_STORM
	weather_changed.emit("toxic_storm")
	
	weather_particles.emitting = true
	weather_particles.color = Color(0.3, 1.0, 0.3, 0.8)
	weather_particles.amount = int(200 * intensity)
	
	if environment_canvas:
		var tween = create_tween()
		tween.tween_property(environment_canvas, "color", Color(0.7, 1.0, 0.7), 2.0)
	
	apply_storm_damage(intensity)

func start_acid_rain(intensity: float) -> void:
	current_weather = WeatherType.ACID_RAIN
	weather_changed.emit("acid_rain")
	
	weather_particles.emitting = true
	weather_particles.color = Color(0.8, 0.8, 0.3, 0.9)
	weather_particles.amount = int(300 * intensity)
	weather_particles.initial_velocity_min = 150.0
	weather_particles.initial_velocity_max = 250.0
	
	if environment_canvas:
		var tween = create_tween()
		tween.tween_property(environment_canvas, "color", Color(0.9, 0.9, 0.7), 2.0)
	
	apply_storm_damage(intensity * 1.2)

func start_radiation_fog(intensity: float) -> void:
	current_weather = WeatherType.RADIATION_FOG
	weather_changed.emit("radiation_fog")
	
	if fog_overlay:
		var tween = create_tween()
		tween.tween_property(fog_overlay, "color:a", 0.3 * intensity, 3.0)
	
	if environment_canvas:
		var tween = create_tween()
		tween.tween_property(environment_canvas, "color", Color(0.8, 0.9, 0.6), 2.0)
	
	apply_storm_damage(intensity * 0.8)

func end_all_weather() -> void:
	current_weather = WeatherType.CLEAR
	weather_changed.emit("clear")
	
	weather_particles.emitting = false
	
	if fog_overlay:
		var tween = create_tween()
		tween.tween_property(fog_overlay, "color:a", 0.0, 2.0)
	
	if environment_canvas:
		var tween = create_tween()
		tween.tween_property(environment_canvas, "color", Color.WHITE, 2.0)

func apply_storm_damage(intensity: float) -> void:
	if not GameManager.player_node:
		return
	
	if not is_player_protected():
		var damage = int(intensity * 10)
		EventBus.emit_player_damaged(damage)
	
	await get_tree().create_timer(5.0).timeout
	if current_weather != WeatherType.CLEAR:
		apply_storm_damage(storm_intensity)

func is_player_protected() -> bool:
	if not GameManager.player_node:
		return false
	
	var player_pos = GameManager.player_node.global_position
	var grid_pos = BuildingManager.snap_to_grid(player_pos)
	
	for x in range(-1, 2):
		for y in range(-1, 2):
			var check_pos = grid_pos + Vector2(x * BuildingManager.GRID_SIZE, y * BuildingManager.GRID_SIZE)
			var building = BuildingManager.get_building_at(check_pos)
			if building and building.get("provides_shelter", false):
				return true
	
	return false

func _on_time_of_day_changed(is_day: bool) -> void:
	if current_weather == WeatherType.CLEAR:
		if environment_canvas:
			var target_color = Color.WHITE if is_day else Color(0.5, 0.5, 0.7)
			var tween = create_tween()
			tween.tween_property(environment_canvas, "color", target_color, 10.0)

func get_visibility_modifier() -> float:
	match current_weather:
		WeatherType.RADIATION_FOG:
			return 0.5
		WeatherType.TOXIC_STORM:
			return 0.7
		WeatherType.ACID_RAIN:
			return 0.8
		_:
			return 1.0