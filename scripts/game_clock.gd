class_name GameClock
extends Node

## Game clock system using ticks
## 1 tick = 1 game minute
## At 1x speed: 1 tick = 1 real second (24-hour day = 24 real minutes)

signal minute_passed(hour: int, minute: int)
signal hour_passed(hour: int)
signal day_passed(day: int)

## Base tick duration in real seconds (at 1x speed)
const BASE_SECONDS_PER_TICK := 1.0

## Available speed levels
const SPEED_LEVELS := [1, 2, 4, 8, 16, 32, 64, 128, 256]
var speed_index: int = 0

## Current game time
var day: int = 1
var hour: int = 8  # Start at 8 AM
var minute: int = 0

## Time accumulator
var time_accumulator: float = 0.0

## Pause state
var is_paused: bool = false

## Current speed multiplier (1, 2, 4, or 8)
var speed_multiplier: int:
	get:
		return SPEED_LEVELS[speed_index]

func _ready() -> void:
	print("[GameClock] Speed: ", speed_multiplier, "x")

func _process(delta: float) -> void:
	if is_paused:
		return

	# At higher speeds, ticks happen faster
	# 1x: 1 tick per second, 2x: 2 ticks per second, etc.
	time_accumulator += delta * speed_multiplier

	# Check if a tick (game minute) has passed
	while time_accumulator >= BASE_SECONDS_PER_TICK:
		time_accumulator -= BASE_SECONDS_PER_TICK
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

func _advance_day() -> void:
	day += 1
	day_passed.emit(day)

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

## Increase speed to next level
func speed_up() -> void:
	if speed_index < SPEED_LEVELS.size() - 1:
		speed_index += 1
		print("[GameClock] Speed: ", speed_multiplier, "x")

## Decrease speed to previous level
func slow_down() -> void:
	if speed_index > 0:
		speed_index -= 1
		print("[GameClock] Speed: ", speed_multiplier, "x")

## Pause/unpause the clock
func set_paused(paused: bool) -> void:
	is_paused = paused

func toggle_pause() -> void:
	set_paused(not is_paused)

## Set time directly
func set_time(new_hour: int, new_minute: int = 0) -> void:
	hour = clampi(new_hour, 0, 23)
	minute = clampi(new_minute, 0, 59)

## Get delta scaled by game speed (for simulation: movement, timers, etc.)
func get_scaled_delta(real_delta: float) -> float:
	if is_paused:
		return 0.0
	return real_delta * speed_multiplier

## Get game minutes delta (for motive updates)
## At 1x: 1 real second = 1 game minute
## At 2x: 1 real second = 2 game minutes
func get_game_delta(real_delta: float) -> float:
	if is_paused:
		return 0.0
	return real_delta * speed_multiplier
