extends Node

class_name TimeManagerSingleton

signal hour_passed(hour: int)
signal day_passed(day: int)
signal time_of_day_changed(is_day: bool)
signal storm_warning(time_until_storm: float)

# Now using GameTimeManager for time tracking
# These are game time durations
const STORM_CHANCE_PER_DAY = 0.3
const STORM_MIN_DURATION_GAME_SECONDS = 3600.0  # 1 game hour
const STORM_MAX_DURATION_GAME_SECONDS = 7200.0  # 2 game hours

var is_storm_active: bool = false
var storm_duration_game_seconds: float = 0.0
var next_storm_game_time: float = -1.0
var last_processed_hour: int = -1
var last_processed_day: int = -1

func _ready() -> void:
	if GameTimeManager:
		GameTimeManager.game_hour_passed.connect(_on_game_hour_passed)
		GameTimeManager.game_day_passed.connect(_on_game_day_passed)
		GameTimeManager.game_time_of_day_changed.connect(_on_game_time_of_day_changed)
		last_processed_hour = GameTimeManager.get_current_game_hour()
		last_processed_day = GameTimeManager.current_game_day
	schedule_next_storm()
	print("TimeManager initialized with GameTimeManager integration")

func _process(delta: float) -> void:
	if not GameTimeManager:
		return
	
	# Handle storm duration
	if is_storm_active:
		storm_duration_game_seconds -= GameTimeManager.real_to_game_seconds(delta)
		if storm_duration_game_seconds <= 0:
			end_storm()
	
	# Check for storm warning and start
	var current_game_time = GameTimeManager.get_total_game_seconds()
	if next_storm_game_time > 0 and current_game_time >= next_storm_game_time - 3600:  # 1 game hour warning
		if not is_storm_active:
			storm_warning.emit(next_storm_game_time - current_game_time)
		if current_game_time >= next_storm_game_time:
			start_storm()

func _on_game_hour_passed(hour: int) -> void:
	if hour != last_processed_hour:
		last_processed_hour = hour
		hour_passed.emit(hour)

func _on_game_day_passed(day: int) -> void:
	if day != last_processed_day:
		last_processed_day = day
		day_passed.emit(day)
		check_for_storm()

func _on_game_time_of_day_changed(is_day: bool) -> void:
	time_of_day_changed.emit(is_day)

func get_current_hour() -> int:
	if GameTimeManager:
		return GameTimeManager.get_current_game_hour()
	return 0

func get_time_string() -> String:
	if GameTimeManager:
		return GameTimeManager.get_game_time_string()
	return "00:00"

func get_day_string() -> String:
	if GameTimeManager:
		return GameTimeManager.get_game_day_string()
	return "Day 1"

func set_time_scale(scale: float) -> void:
	if GameTimeManager:
		GameTimeManager.set_time_scale(scale)

func pause_time() -> void:
	if GameTimeManager:
		GameTimeManager.pause_game_time()

func resume_time() -> void:
	if GameTimeManager:
		GameTimeManager.resume_game_time()

func skip_to_next_day() -> void:
	if GameTimeManager:
		GameTimeManager.skip_to_next_game_day()

func check_for_storm() -> void:
	if randf() < STORM_CHANCE_PER_DAY:
		schedule_next_storm()

func schedule_next_storm() -> void:
	if not GameTimeManager:
		return
	# Schedule storm for random time during the current game day
	var current_game_time = GameTimeManager.get_total_game_seconds()
	var current_day_start = floor(current_game_time / 86400.0) * 86400.0
	next_storm_game_time = current_day_start + randf_range(86400.0 * 0.3, 86400.0 * 0.8)
	print("Storm scheduled for game time: %f" % next_storm_game_time)

func start_storm() -> void:
	if is_storm_active:
		return
	
	is_storm_active = true
	storm_duration_game_seconds = randf_range(STORM_MIN_DURATION_GAME_SECONDS, STORM_MAX_DURATION_GAME_SECONDS)
	var intensity = randf_range(0.5, 1.0)
	if EventBus:
		EventBus.emit_storm_started(intensity)
	print("Storm started with duration: %f game seconds" % storm_duration_game_seconds)

func end_storm() -> void:
	is_storm_active = false
	storm_duration_game_seconds = 0.0
	next_storm_game_time = -1.0
	if EventBus:
		EventBus.emit_storm_ended()
	schedule_next_storm()
	print("Storm ended")

func is_safe_time() -> bool:
	if not GameTimeManager:
		return true
	var current_game_time = GameTimeManager.get_total_game_seconds()
	return not is_storm_active and (next_storm_game_time < 0 or current_game_time < next_storm_game_time - 7200)  # 2 game hours buffer

func get_environment_danger_level() -> float:
	if is_storm_active:
		return 1.0
	elif GameTimeManager and not GameTimeManager.is_day_time():
		return 0.3
	else:
		return 0.1
