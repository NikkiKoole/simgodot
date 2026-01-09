extends Camera2D

## How quickly the camera catches up to the player (higher = faster)
@export var lerp_speed: float = 5.0
## Dead zone size - camera won't move until player exits this area
@export var dead_zone: Vector2 = Vector2(150, 100)
## Zoom settings
@export var min_zoom: float = 0.25
@export var max_zoom: float = 4.0
@export var zoom_step: float = 0.1

var target_position: Vector2
var is_dragging: bool = false
var follow_player: bool = true  # Only follow player after WASD input

func _ready() -> void:
	# Make camera independent of parent's transform
	top_level = true
	# Start at the player's position
	target_position = get_parent().global_position
	global_position = target_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Let left and right clicks pass through to other handlers
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			return
		# Middle mouse button for dragging
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				is_dragging = true
			else:
				is_dragging = false
				follow_player = false  # Stop following player after drag
			return
		# Scroll wheel for zooming
		if event.pressed:
			var new_zoom := zoom
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				new_zoom *= (1.0 + zoom_step)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				new_zoom *= (1.0 - zoom_step)
			else:
				return
			# Clamp zoom
			new_zoom.x = clampf(new_zoom.x, min_zoom, max_zoom)
			new_zoom.y = clampf(new_zoom.y, min_zoom, max_zoom)
			# Get mouse position in world space before zoom
			var mouse_world_before := get_global_mouse_position()
			# Apply new zoom
			zoom = new_zoom
			# Get mouse position in world space after zoom
			var mouse_world_after := get_global_mouse_position()
			# Adjust camera position so mouse stays over the same world point
			var offset := mouse_world_before - mouse_world_after
			global_position += offset
			target_position += offset
	# Handle drag motion - use screen-space delta for stability
	elif event is InputEventMouseMotion and is_dragging:
		var drag_delta: Vector2 = event.relative / zoom
		global_position -= drag_delta
		target_position = global_position
	# Check for WASD input to resume following player
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
			follow_player = true

func _process(delta: float) -> void:
	# Don't follow player while dragging or when follow is disabled
	if is_dragging or not follow_player:
		return
	var player_pos: Vector2 = get_parent().global_position
	# Calculate offset from current target to player
	var offset := player_pos - target_position
	# Only update target if player is outside the dead zone
	if abs(offset.x) > dead_zone.x:
		target_position.x = player_pos.x - sign(offset.x) * dead_zone.x
	if abs(offset.y) > dead_zone.y:
		target_position.y = player_pos.y - sign(offset.y) * dead_zone.y
	# Smoothly lerp camera to target position, then snap to whole pixels
	var smooth_pos = global_position.lerp(target_position, lerp_speed * delta)
	global_position = smooth_pos.round()
