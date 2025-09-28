extends Node

class_name GameTimeManagerSingleton

signal game_hour_passed(hour: int)
signal game_day_passed(day: int)
signal game_time_of_day_changed(is_day: bool)

# Game time settings (30 minutes real time = 24 hours game time)
const REAL_SECONDS_PER_GAME_DAY = 1800.0  # 30 minutes in seconds
const REAL_SECONDS_PER_GAME_HOUR = 75.0  # 1800 / 24 = 75 seconds per game hour
const GAME_HOURS_PER_DAY = 24
const DAY_START_HOUR = 6  # 6 AM
const NIGHT_START_HOUR = 20  # 8 PM (20:00)
const DAY_DURATION_HOURS = 16  # 16 hours of day (6 AM to 10 PM)
const NIGHT_DURATION_HOURS = 8  # 8 hours of night (10 PM to 6 AM)
const REAL_SECONDS_FOR_DAY = 1200.0  # 20 minutes for day period
const REAL_SECONDS_FOR_NIGHT = 600.0  # 10 minutes for night period

# Internal time tracking
var current_game_time: float = 0.0  # Current time in game seconds (0-86400)
var current_game_day: int = 1
var current_game_hour: int = 6  # Start at 6 AM
var is_game_day: bool = true
var time_scale: float = 1.0  # For debugging/testing
var is_paused: bool = false

# Real time to game time conversion
var real_time_accumulator: float = 0.0

func _ready() -> void:
	set_process_priority(-100)  # Process before other managers
	print("GameTimeManager initialized - 30 real minutes = 24 game hours")
	
	# Start at 6 AM on day 1
	current_game_time = DAY_START_HOUR * 3600.0  # 6 hours in seconds
	current_game_hour = DAY_START_HOUR
	is_game_day = true

func _process(delta: float) -> void:
	if is_paused or (GameManager and GameManager.is_paused):
		return
	
	# Accumulate real time
	real_time_accumulator += delta * time_scale
	
	# Convert real time to game time
	# 30 real minutes = 24 game hours
	# 1 real second = 48 game seconds (24*3600/1800)
	var game_seconds_per_real_second = 48.0
	var game_time_delta = delta * time_scale * game_seconds_per_real_second
	
	# Update game time
	var previous_hour = current_game_hour
	current_game_time += game_time_delta
	
	# Handle day rollover
	if current_game_time >= 86400.0:  # 24 hours in seconds
		current_game_time -= 86400.0
		current_game_day += 1
		game_day_passed.emit(current_game_day)
	
	# Calculate current hour
	current_game_hour = int(current_game_time / 3600.0) % 24
	
	# Check for hour change
	if current_game_hour != previous_hour:
		game_hour_passed.emit(current_game_hour)
		
		# Check for day/night transition
		var new_is_day = current_game_hour >= DAY_START_HOUR and current_game_hour < NIGHT_START_HOUR
		if new_is_day != is_game_day:
			is_game_day = new_is_day
			game_time_of_day_changed.emit(is_game_day)
			if EventBus:
				EventBus.emit_day_night_changed(is_game_day)

func get_current_game_hour() -> int:
	return current_game_hour

func get_current_game_minute() -> int:
	return int((current_game_time / 60.0)) % 60

func get_game_time_string() -> String:
	var hour = get_current_game_hour()
	var minute = get_current_game_minute()
	var am_pm = "AM" if hour < 12 else "PM"
	var display_hour = hour % 12
	if display_hour == 0:
		display_hour = 12
	return "%02d:%02d %s" % [display_hour, minute, am_pm]

func get_game_day_string() -> String:
	return "Day %d" % current_game_day

func get_total_game_seconds() -> float:
	return (current_game_day - 1) * 86400.0 + current_game_time

func set_time_scale(scale: float) -> void:
	time_scale = clamp(scale, 0.0, 100.0)
	print("Game time scale set to: ", time_scale)

func pause_game_time() -> void:
	is_paused = true

func resume_game_time() -> void:
	is_paused = false

func skip_to_next_game_day() -> void:
	current_game_time = DAY_START_HOUR * 3600.0  # Reset to 6 AM
	current_game_day += 1
	current_game_hour = DAY_START_HOUR
	is_game_day = true
	game_day_passed.emit(current_game_day)
	game_time_of_day_changed.emit(true)

# Convert real seconds to game seconds
func real_to_game_seconds(real_seconds: float) -> float:
	# 30 real minutes = 24 game hours
	# 1800 real seconds = 86400 game seconds
	# 1 real second = 48 game seconds
	return real_seconds * 48.0

# Convert game seconds to real seconds
func game_to_real_seconds(game_seconds: float) -> float:
	# 86400 game seconds = 1800 real seconds
	# 1 game second = 0.0208333... real seconds
	return game_seconds / 48.0

# Convert real hours to game hours
func real_hours_to_game_hours(real_hours: float) -> float:
	# 0.5 real hours (30 minutes) = 24 game hours
	# 1 real hour = 48 game hours
	return real_hours * 48.0

# Convert game hours to real seconds
func game_hours_to_real_seconds(game_hours: float) -> float:
	# 24 game hours = 1800 real seconds
	# 1 game hour = 75 real seconds
	return game_hours * 75.0

# Convert game days to real seconds
func game_days_to_real_seconds(game_days: float) -> float:
	# 1 game day = 1800 real seconds (30 minutes)
	return game_days * REAL_SECONDS_PER_GAME_DAY

# Get time remaining in real seconds for a game duration
func get_real_seconds_remaining(game_seconds_remaining: float) -> float:
	return game_to_real_seconds(game_seconds_remaining)

# Format a game duration for display
func format_game_duration(game_seconds: float) -> String:
	var days = int(game_seconds / 86400.0)
	var hours = int((game_seconds / 3600.0)) % 24
	var minutes = int((game_seconds / 60.0)) % 60
	
	if days > 0:
		return "%d day(s), %d hour(s)" % [days, hours]
	elif hours > 0:
		return "%d hour(s), %d minute(s)" % [hours, minutes]
	else:
		return "%d minute(s)" % minutes

# Check if it's currently day or night
func is_day_time() -> bool:
	return is_game_day

func is_night_time() -> bool:
	return not is_game_day

# Get the current phase of day as a percentage (0.0 to 1.0)
func get_day_progress() -> float:
	if is_game_day:
		# During day: map 6 AM to 8 PM (14 hours) to 0.0 to 1.0
		var day_start_seconds = DAY_START_HOUR * 3600.0
		var day_end_seconds = NIGHT_START_HOUR * 3600.0
		var day_progress = (current_game_time - day_start_seconds) / (day_end_seconds - day_start_seconds)
		return clamp(day_progress, 0.0, 1.0)
	else:
		# During night: map 8 PM to 6 AM (10 hours) to 0.0 to 1.0
		var adjusted_time = current_game_time
		if current_game_time < DAY_START_HOUR * 3600.0:
			adjusted_time += 86400.0  # Add a day for times after midnight
		var night_start_seconds = NIGHT_START_HOUR * 3600.0
		var night_end_seconds = (DAY_START_HOUR + 24) * 3600.0  # 6 AM next day
		var night_progress = (adjusted_time - night_start_seconds) / (night_end_seconds - night_start_seconds)
		return clamp(night_progress, 0.0, 1.0)