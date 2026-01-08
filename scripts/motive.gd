class_name Motive
extends RefCounted

## Motive system inspired by The Sims
## Each motive ranges from -100 to +100
## Negative values indicate urgent need, positive values indicate satisfaction
## Decay is calculated per GAME MINUTE, not real seconds

signal value_changed(motive_type: MotiveType, new_value: float)
signal critical_level(motive_type: MotiveType)  # Fired when value hits min
signal motive_depleted(motive_type: MotiveType)  # Fired when value reaches -100

enum MotiveType {
	# Active motives (used in gameplay)
	HUNGER,
	ENERGY,
	BLADDER,
	HYGIENE,
	# Inactive motives (defined but not decaying yet)
	FUN,
	SOCIAL,
	COMFORT,
	ROOM
}

const MIN_VALUE := -100.0
const MAX_VALUE := 100.0
const CRITICAL_THRESHOLD := -50.0  # When motive becomes urgent

## Decay rates per GAME MINUTE (how fast each motive decreases)
## 200 points total range (-100 to +100)
## Hunger: 200 points / 240 minutes (4 hours) = 0.833 per minute
## Energy: 200 points / 960 minutes (16 hours) = 0.208 per minute
## Bladder: 200 points / 360 minutes (6 hours) = 0.556 per minute
## Hygiene: 200 points / 720 minutes (12 hours) = 0.278 per minute
const DECAY_RATES_PER_MINUTE := {
	MotiveType.HUNGER: 0.833,    # ~4 hours to go from 100 to -100
	MotiveType.ENERGY: 0.208,    # ~16 hours (a full day awake)
	MotiveType.BLADDER: 0.556,   # ~6 hours
	MotiveType.HYGIENE: 0.278,   # ~12 hours
	MotiveType.FUN: 0.5,         # ~6.6 hours to go from 100 to -100
	# Inactive motives - defined but set to 0 decay
	MotiveType.SOCIAL: 0.0,      # Would be ~0.278 (~12 hours)
	MotiveType.COMFORT: 0.0,     # Would be ~1.333 (~2.5 hours standing)
	MotiveType.ROOM: 0.0         # Environment-based, not time-based
}

## Which motives are currently active (decaying)
const ACTIVE_MOTIVES := [
	MotiveType.HUNGER,
	MotiveType.ENERGY,
	MotiveType.BLADDER,
	MotiveType.HYGIENE,
	MotiveType.FUN
]

var values: Dictionary = {}
var owner_name: String = ""

func _init(entity_name: String = "Entity") -> void:
	owner_name = entity_name
	# Initialize all motives to a comfortable starting value
	for motive_type in MotiveType.values():
		values[motive_type] = 50.0  # Start at neutral-positive

## Call this every frame with game_minutes_delta (from GameClock.get_game_delta)
func update(game_minutes_delta: float) -> void:
	for motive_type in ACTIVE_MOTIVES:
		var decay_rate: float = DECAY_RATES_PER_MINUTE[motive_type]
		if decay_rate > 0:
			_decay_motive(motive_type, decay_rate * game_minutes_delta)

func _decay_motive(motive_type: MotiveType, amount: float) -> void:
	var old_value: float = values[motive_type]
	var new_value: float = clampf(old_value - amount, MIN_VALUE, MAX_VALUE)

	if new_value != old_value:
		values[motive_type] = new_value
		value_changed.emit(motive_type, new_value)

		# Check for critical level
		if old_value > CRITICAL_THRESHOLD and new_value <= CRITICAL_THRESHOLD:
			critical_level.emit(motive_type)

		# Check for depletion
		if new_value <= MIN_VALUE:
			motive_depleted.emit(motive_type)

## Increase a motive value (when fulfilled by an object)
## amount is per game minute of use
func fulfill(motive_type: MotiveType, amount: float) -> void:
	var old_value: float = values[motive_type]
	var new_value: float = clampf(old_value + amount, MIN_VALUE, MAX_VALUE)

	if new_value != old_value:
		values[motive_type] = new_value
		value_changed.emit(motive_type, new_value)

## Get the current value of a motive
func get_value(motive_type: MotiveType) -> float:
	return values.get(motive_type, 0.0)

## Get the most urgent motive (lowest value among active motives)
func get_most_urgent_motive() -> MotiveType:
	var lowest_type: MotiveType = MotiveType.HUNGER
	var lowest_value: float = MAX_VALUE + 1

	for motive_type in ACTIVE_MOTIVES:
		var value: float = values[motive_type]
		if value < lowest_value:
			lowest_value = value
			lowest_type = motive_type

	return lowest_type

## Check if any motive is at critical level
func has_critical_motive() -> bool:
	for motive_type in ACTIVE_MOTIVES:
		if values[motive_type] <= CRITICAL_THRESHOLD:
			return true
	return false

## Get all motives below critical threshold
func get_critical_motives() -> Array[MotiveType]:
	var critical: Array[MotiveType] = []
	for motive_type in ACTIVE_MOTIVES:
		if values[motive_type] <= CRITICAL_THRESHOLD:
			critical.append(motive_type)
	return critical

## Calculate overall happiness/mood (-100 to 100)
func get_overall_mood() -> float:
	var total := 0.0
	var count := 0
	for motive_type in ACTIVE_MOTIVES:
		total += values[motive_type]
		count += 1
	return total / count if count > 0 else 0.0

## Get human-readable name for a motive type
static func get_motive_name(motive_type: MotiveType) -> String:
	match motive_type:
		MotiveType.HUNGER: return "Hunger"
		MotiveType.ENERGY: return "Energy"
		MotiveType.BLADDER: return "Bladder"
		MotiveType.HYGIENE: return "Hygiene"
		MotiveType.FUN: return "Fun"
		MotiveType.SOCIAL: return "Social"
		MotiveType.COMFORT: return "Comfort"
		MotiveType.ROOM: return "Room"
		_: return "Unknown"

## Debug: Print all motive values
func debug_print() -> void:
	print("=== Motives for ", owner_name, " ===")
	for motive_type in MotiveType.values():
		var value: float = values[motive_type]
		var status := ""
		if value <= MIN_VALUE:
			status = " [DEPLETED]"
		elif value <= CRITICAL_THRESHOLD:
			status = " [CRITICAL]"
		print("  ", get_motive_name(motive_type), ": ", snapped(value, 0.1), status)
	print("  Overall Mood: ", snapped(get_overall_mood(), 0.1))
