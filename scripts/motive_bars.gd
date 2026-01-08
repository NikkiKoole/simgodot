class_name MotiveBars
extends Control

## Visual display of motive bars next to an entity

const BAR_WIDTH := 24
const BAR_HEIGHT := 4
const BAR_SPACING := 2
const BAR_OFFSET := Vector2(-12, -40)  # Offset from entity center

# Colors for each motive type
const MOTIVE_COLORS := {
	Motive.MotiveType.HUNGER: Color(0.9, 0.6, 0.2),   # Orange
	Motive.MotiveType.ENERGY: Color(0.3, 0.7, 0.9),   # Light blue
	Motive.MotiveType.BLADDER: Color(0.9, 0.85, 0.3), # Yellow
	Motive.MotiveType.HYGIENE: Color(0.4, 0.8, 0.5),  # Green
}

const BACKGROUND_COLOR := Color(0.2, 0.2, 0.2, 0.8)
const CRITICAL_COLOR := Color(0.9, 0.2, 0.2)  # Red when critical

var motives_ref: Motive = null
var bars: Dictionary = {}  # MotiveType -> {bg: ColorRect, fill: ColorRect}

func _ready() -> void:
	# Position offset from parent
	position = BAR_OFFSET

	# Create bars for active motives only
	var y_offset := 0
	for motive_type in Motive.ACTIVE_MOTIVES:
		_create_bar(motive_type, y_offset)
		y_offset += BAR_HEIGHT + BAR_SPACING

func _create_bar(motive_type: Motive.MotiveType, y_pos: int) -> void:
	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bg.position = Vector2(0, y_pos)
	bg.color = BACKGROUND_COLOR
	add_child(bg)

	# Fill bar
	var fill := ColorRect.new()
	fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	fill.position = Vector2(0, y_pos)
	fill.color = MOTIVE_COLORS.get(motive_type, Color.WHITE)
	add_child(fill)

	bars[motive_type] = {"bg": bg, "fill": fill}

func set_motives(motives: Motive) -> void:
	motives_ref = motives

func _process(_delta: float) -> void:
	if motives_ref == null:
		return

	# Update bar fills based on motive values
	for motive_type in bars:
		var bar_data: Dictionary = bars[motive_type]
		var fill: ColorRect = bar_data["fill"]

		var value: float = motives_ref.get_value(motive_type)
		# Convert from -100..100 to 0..1
		var normalized: float = (value - Motive.MIN_VALUE) / (Motive.MAX_VALUE - Motive.MIN_VALUE)
		normalized = clampf(normalized, 0.0, 1.0)

		# Update fill width
		fill.size.x = BAR_WIDTH * normalized

		# Change color to red if critical
		if value <= Motive.CRITICAL_THRESHOLD:
			fill.color = CRITICAL_COLOR
		else:
			fill.color = MOTIVE_COLORS.get(motive_type, Color.WHITE)
