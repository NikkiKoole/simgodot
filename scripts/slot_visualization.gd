extends Node2D
## Slot Visualization - Draws station slot positions and contents for debugging.
## Shows input and output slots as overlay rectangles when a station is selected.
## Empty slots shown as dotted outlines, occupied slots show item tag labels.
## Input and output slots are distinguished by color.

# Reference to the station being visualized
var target_station: Node = null

# Visibility toggle
var is_visible: bool = true

# Slot drawing constants
const SLOT_SIZE := Vector2(20, 20)  # Size of slot rectangle
const SLOT_OUTLINE_WIDTH := 2.0

# Colors for different slot types
const INPUT_SLOT_COLOR := Color(0.2, 0.6, 1.0, 0.8)  # Blue for input slots
const INPUT_SLOT_EMPTY_COLOR := Color(0.2, 0.6, 1.0, 0.4)  # Lighter blue for empty
const OUTPUT_SLOT_COLOR := Color(1.0, 0.6, 0.2, 0.8)  # Orange for output slots
const OUTPUT_SLOT_EMPTY_COLOR := Color(1.0, 0.6, 0.2, 0.4)  # Lighter orange for empty

# Agent footprint marker
const FOOTPRINT_COLOR := Color(0.0, 1.0, 0.5, 0.8)  # Green
const FOOTPRINT_RADIUS := 8.0
const FOOTPRINT_OUTLINE_WIDTH := 2.0

# Label settings
const LABEL_FONT_SIZE := 10
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 1.0)  # White
const LABEL_BG_COLOR := Color(0.0, 0.0, 0.0, 0.6)  # Semi-transparent black

# Dotted line settings for empty slots
const DOT_LENGTH := 4.0
const GAP_LENGTH := 3.0


func _ready() -> void:
	# Ensure this draws above game elements
	z_index = 50


func _process(_delta: float) -> void:
	# Redraw each frame to update slot visualization
	if target_station != null and is_instance_valid(target_station) and is_visible:
		queue_redraw()


func _draw() -> void:
	if not is_visible:
		return

	if target_station == null or not is_instance_valid(target_station):
		return

	# Draw input slots
	var input_slots: Array = target_station.input_slots
	var input_slot_items: Dictionary = target_station.input_slot_items

	for i in range(input_slots.size()):
		var slot_marker: Marker2D = input_slots[i]
		if slot_marker == null:
			continue

		var slot_pos: Vector2 = slot_marker.global_position
		var is_occupied: bool = input_slot_items.has(i)
		var item: Node = input_slot_items.get(i) if is_occupied else null

		_draw_slot(slot_pos, i, true, is_occupied, item)

	# Draw output slots
	var output_slots: Array = target_station.output_slots
	var output_slot_items: Dictionary = target_station.output_slot_items

	for i in range(output_slots.size()):
		var slot_marker: Marker2D = output_slots[i]
		if slot_marker == null:
			continue

		var slot_pos: Vector2 = slot_marker.global_position
		var is_occupied: bool = output_slot_items.has(i)
		var item: Node = output_slot_items.get(i) if is_occupied else null

		_draw_slot(slot_pos, i, false, is_occupied, item)

	# Draw agent footprint marker
	var agent_footprint: Marker2D = target_station.agent_footprint
	if agent_footprint != null:
		_draw_agent_footprint(agent_footprint.global_position)


## Draw a single slot with index label and optional item tag
func _draw_slot(world_pos: Vector2, index: int, is_input: bool, is_occupied: bool, item: Node) -> void:
	var local_pos := world_pos - global_position
	var half_size := SLOT_SIZE / 2.0
	var rect := Rect2(local_pos - half_size, SLOT_SIZE)

	if is_occupied:
		# Draw filled rectangle for occupied slot
		var fill_color := INPUT_SLOT_COLOR if is_input else OUTPUT_SLOT_COLOR
		draw_rect(rect, fill_color, true)
		draw_rect(rect, fill_color, false, SLOT_OUTLINE_WIDTH)

		# Draw item tag label
		if item != null and item.get("item_tag") != null:
			var tag: String = item.item_tag
			_draw_label(local_pos + Vector2(0, SLOT_SIZE.y / 2 + 8), tag)
	else:
		# Draw dotted outline for empty slot
		var outline_color := INPUT_SLOT_EMPTY_COLOR if is_input else OUTPUT_SLOT_EMPTY_COLOR
		_draw_dotted_rect(rect, outline_color)

	# Draw slot index label
	var index_text := str(index)
	var type_prefix := "I" if is_input else "O"
	_draw_index_label(local_pos - Vector2(0, SLOT_SIZE.y / 2 + 6), type_prefix + index_text)


## Draw a dotted rectangle outline
func _draw_dotted_rect(rect: Rect2, color: Color) -> void:
	# Draw each edge as a dotted line
	var corners: Array[Vector2] = [
		rect.position,  # Top-left
		rect.position + Vector2(rect.size.x, 0),  # Top-right
		rect.position + rect.size,  # Bottom-right
		rect.position + Vector2(0, rect.size.y),  # Bottom-left
	]

	for i in range(4):
		var from_pos: Vector2 = corners[i]
		var to_pos: Vector2 = corners[(i + 1) % 4]
		_draw_dotted_line(from_pos, to_pos, color)


## Draw a dotted line from start to end
func _draw_dotted_line(from_pos: Vector2, to_pos: Vector2, color: Color) -> void:
	var direction: Vector2 = (to_pos - from_pos).normalized()
	var total_length: float = from_pos.distance_to(to_pos)
	var current_length: float = 0.0

	while current_length < total_length:
		var segment_end: float = min(current_length + DOT_LENGTH, total_length)
		var start: Vector2 = from_pos + direction * current_length
		var end: Vector2 = from_pos + direction * segment_end
		draw_line(start, end, color, SLOT_OUTLINE_WIDTH)
		current_length += DOT_LENGTH + GAP_LENGTH


## Draw a text label at the given position
func _draw_label(local_pos: Vector2, text: String) -> void:
	# Get the default font
	var font := ThemeDB.fallback_font
	if font == null:
		return

	# Calculate text size for background
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
	var padding := Vector2(4, 2)
	var bg_rect := Rect2(
		local_pos - Vector2(text_size.x / 2 + padding.x, text_size.y + padding.y),
		text_size + padding * 2
	)

	# Draw background
	draw_rect(bg_rect, LABEL_BG_COLOR, true)

	# Draw text
	var text_pos := local_pos - Vector2(text_size.x / 2, 0)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)


## Draw a slot index label (smaller, above slot)
func _draw_index_label(local_pos: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, LABEL_FONT_SIZE)
	var text_pos := local_pos - Vector2(text_size.x / 2, 0)

	# Draw text with small background
	var padding := Vector2(2, 1)
	var bg_rect := Rect2(
		text_pos - Vector2(padding.x, text_size.y + padding.y),
		text_size + padding * 2
	)
	draw_rect(bg_rect, LABEL_BG_COLOR, true)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)


## Draw the agent footprint marker
func _draw_agent_footprint(world_pos: Vector2) -> void:
	var local_pos := world_pos - global_position

	# Draw a circle with cross for agent footprint
	draw_circle(local_pos, FOOTPRINT_RADIUS, Color(FOOTPRINT_COLOR.r, FOOTPRINT_COLOR.g, FOOTPRINT_COLOR.b, 0.3))
	draw_arc(local_pos, FOOTPRINT_RADIUS, 0, TAU, 32, FOOTPRINT_COLOR, FOOTPRINT_OUTLINE_WIDTH)

	# Draw cross inside
	var cross_size := FOOTPRINT_RADIUS * 0.6
	draw_line(local_pos - Vector2(cross_size, 0), local_pos + Vector2(cross_size, 0), FOOTPRINT_COLOR, FOOTPRINT_OUTLINE_WIDTH)
	draw_line(local_pos - Vector2(0, cross_size), local_pos + Vector2(0, cross_size), FOOTPRINT_COLOR, FOOTPRINT_OUTLINE_WIDTH)

	# Draw "Agent" label below
	_draw_label(local_pos + Vector2(0, FOOTPRINT_RADIUS + 10), "Agent")


## Set the station to visualize
func set_station(station: Node) -> void:
	target_station = station
	queue_redraw()


## Clear the visualization
func clear() -> void:
	target_station = null
	queue_redraw()


## Toggle visibility
func set_slots_visible(visible: bool) -> void:
	is_visible = visible
	queue_redraw()


## Get current visibility state
func is_slots_visible() -> bool:
	return is_visible
