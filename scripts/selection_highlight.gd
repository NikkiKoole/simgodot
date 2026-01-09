extends Node2D
## SelectionHighlight - Visual highlight that follows the currently selected entity.
## Provides visual feedback for the click-to-select system.

## The entity we are following
var target_entity: Node2D = null

## Highlight visual properties
const HIGHLIGHT_COLOR := Color(1.0, 0.8, 0.0, 0.8)  # Yellow-gold
const HIGHLIGHT_WIDTH := 2.0
const HIGHLIGHT_PADDING := 4.0  # Pixels of padding around the entity

## Animation properties
var pulse_time: float = 0.0
const PULSE_SPEED := 3.0
const PULSE_MIN_ALPHA := 0.5
const PULSE_MAX_ALPHA := 1.0


func _ready() -> void:
	# Connect to DebugCommands signals
	if DebugCommands:
		DebugCommands.entity_selected.connect(_on_entity_selected)
		DebugCommands.entity_deselected.connect(_on_entity_deselected)

	# Start hidden
	visible = false


func _process(delta: float) -> void:
	if target_entity == null or not is_instance_valid(target_entity):
		visible = false
		return

	# Follow the target entity
	global_position = target_entity.global_position

	# Pulse animation
	pulse_time += delta * PULSE_SPEED
	var alpha := lerpf(PULSE_MIN_ALPHA, PULSE_MAX_ALPHA, (sin(pulse_time) + 1.0) / 2.0)
	modulate.a = alpha

	# Redraw to update the highlight
	queue_redraw()


func _draw() -> void:
	if target_entity == null or not is_instance_valid(target_entity):
		return

	# Determine the size of the highlight based on entity type
	var size := _get_entity_size()
	var half_size := size / 2.0 + Vector2(HIGHLIGHT_PADDING, HIGHLIGHT_PADDING)

	# Draw highlight rectangle outline
	var rect := Rect2(-half_size, size + Vector2(HIGHLIGHT_PADDING * 2, HIGHLIGHT_PADDING * 2))
	draw_rect(rect, HIGHLIGHT_COLOR, false, HIGHLIGHT_WIDTH)

	# Draw corner accents for extra visibility
	var corner_length := minf(half_size.x, half_size.y) * 0.3
	_draw_corner_accent(Vector2(-half_size.x, -half_size.y), corner_length, true, true)
	_draw_corner_accent(Vector2(half_size.x, -half_size.y), corner_length, false, true)
	_draw_corner_accent(Vector2(-half_size.x, half_size.y), corner_length, true, false)
	_draw_corner_accent(Vector2(half_size.x, half_size.y), corner_length, false, false)


func _draw_corner_accent(pos: Vector2, length: float, left: bool, top: bool) -> void:
	var h_dir := 1.0 if left else -1.0
	var v_dir := 1.0 if top else -1.0

	# Horizontal line
	draw_line(pos, pos + Vector2(length * h_dir, 0), HIGHLIGHT_COLOR, HIGHLIGHT_WIDTH + 1.0)
	# Vertical line
	draw_line(pos, pos + Vector2(0, length * v_dir), HIGHLIGHT_COLOR, HIGHLIGHT_WIDTH + 1.0)


func _get_entity_size() -> Vector2:
	if target_entity == null:
		return Vector2(32, 32)

	# Try to determine size from the entity's visual or collision
	# Check for ColorRect child (common visual element)
	var sprite := target_entity.get_node_or_null("Sprite2D")
	if sprite is ColorRect:
		return sprite.size

	var body := target_entity.get_node_or_null("Body")
	if body is ColorRect:
		return body.size

	# Check for collision shape to estimate size
	var click_area := target_entity.get_node_or_null("ClickArea")
	if click_area is Area2D:
		var collision := click_area.get_node_or_null("CollisionShape2D")
		if collision is CollisionShape2D and collision.shape != null:
			if collision.shape is RectangleShape2D:
				return collision.shape.size
			elif collision.shape is CircleShape2D:
				var diameter: float = collision.shape.radius * 2
				return Vector2(diameter, diameter)

	# Default size
	return Vector2(32, 32)


func _on_entity_selected(entity: Node) -> void:
	if entity is Node2D:
		target_entity = entity
		visible = true
		pulse_time = 0.0
		queue_redraw()
	else:
		target_entity = null
		visible = false


func _on_entity_deselected() -> void:
	target_entity = null
	visible = false
