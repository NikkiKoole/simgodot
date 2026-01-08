class_name GameClock
extends Node

## Game clock system - controls the flow of time in the game
## Inspired by The Sims where time moves in ~2 minute increments

signal minute_passed(hour: int, minute: int)
signal hour_passed(hour: int)
signal day_passed(day: int)

## How many real seconds = 1 game minute
## Default: 1 real second = 1 game minute (so 1 real minute = 1 game hour)
## Set lower for faster time, higher for slower
@export var real_seconds_per_game_minute: float = 1.0

## Current game time
var day: int = 1
var hour: int = 8  # Start at 8 AM
var minute: int = 0

## Time accumulator
var time_accumulator: float = 0.0

## Pause state
var is_paused: bool = false

## Speed multiplier (for fast-forward)
var speed_multiplier: float = 1.0

func _ready() -> void:
	print("[GameClock] Started at Day ", day, ", ", _format_time())

func _process(delta: float) -> void:
	if is_paused:
		return

	time_accumulator += delta * speed_multiplier

	# Check if a game minute has passed
	while time_accumulator >= real_seconds_per_game_minute:
		time_accumulator -= real_seconds_per_game_minute
		_advance_minute()

func _advance_minute() -> void:
	minute += 1

	if minute >= 60:
		minute = 0
		_advance_hour()

	minute_passed.emit(hour, minute)

func _advance_hour() -> void:
	hour += 1

	if hour >= 24:
		hour = 0
		_advance_day()

	hour_passed.emit(hour)
	print("[GameClock] ", _format_time())

func _advance_day() -> void:
	day += 1
	day_passed.emit(day)
	print("[GameClock] Day ", day, " started")

## Get total minutes elapsed today (0-1439)
func get_total_minutes_today() -> int:
	return hour * 60 + minute

## Get total game minutes elapsed since start
func get_total_game_minutes() -> int:
	return (day - 1) * 1440 + get_total_minutes_today()

## Get time as a formatted string (e.g., "08:30")
func get_time_string() -> String:
	return _format_time()

## Get time with AM/PM (e.g., "8:30 AM")
func get_time_string_12h() -> String:
	var h := hour % 12
	if h == 0:
		h = 12
	var ampm := "AM" if hour < 12 else "PM"
	return "%d:%02d %s" % [h, minute, ampm]

func _format_time() -> String:
	return "%02d:%02d" % [hour, minute]

## Set the time speed
## 1.0 = normal, 2.0 = double speed, 0.5 = half speed
func set_speed(multiplier: float) -> void:
	speed_multiplier = maxf(0.0, multiplier)
	print("[GameClock] Speed set to ", speed_multiplier, "x")

## Pause/unpause the clock
func set_paused(paused: bool) -> void:
	is_paused = paused
	print("[GameClock] ", "Paused" if paused else "Resumed")

## Set time directly
func set_time(new_hour: int, new_minute: int = 0) -> void:
	hour = clampi(new_hour, 0, 23)
	minute = clampi(new_minute, 0, 59)
	print("[GameClock] Time set to ", _format_time())

## Get delta time scaled by game speed (for motive updates)
func get_game_delta(real_delta: float) -> float:
	if is_paused:
		return 0.0
	# Convert real delta to game minutes
	# If 1 real second = 1 game minute, then real_delta seconds = real_delta game minutes
	return (real_delta / real_seconds_per_game_minute) * speed_multiplier
