extends VBoxContainer
## Wall Paint Tool - UI for adding and removing walls at runtime.
## When active, clicking or dragging in the game world adds/removes walls at grid positions.
## All wall operations go through the DebugCommands API.

# Paint mode enum
enum PaintMode { NONE, ADD, REMOVE }

# Current paint mode
var current_mode: PaintMode = PaintMode.NONE

# Preview node for showing wall placement
var preview_node: Node2D = null

# Grid overlay node for showing grid when tool is active
var grid_overlay: Node2D = null

# Track if we're currently dragging
var is_dragging: bool = false

# Reference to debug_ui for coordinate conversion
var debug_ui: CanvasLayer = null

# UI elements
@onready var add_btn: Button = $ModeSection/AddButton
@onready var remove_btn: Button = $ModeSection/RemoveButton
@onready var cancel_btn: Button = $CancelButton
@onready var status_label: Label = $StatusLabel

# Grid and preview constants
const TILE_SIZE := 32
const PREVIEW_ADD_COLOR := Color(0.35, 0.35, 0.45, 0.6)  # Wall color, semi-transparent
const PREVIEW_REMOVE_COLOR := Color(1.0, 0.2, 0.2, 0.6)  # Red, semi-transparent
const GRID_LINE_COLOR := Color(0.5, 0.5, 0.5, 0.3)  # Light gray, very transparent
const GRID_VISIBLE_RANGE := 20  # Number of grid cells to show in each direction


func _ready() -> void:
	# Find the DebugUI parent
	debug_ui = _find_debug_ui()

	# Connect button signals
	add_btn.pressed.connect(_on_add_pressed)
	remove_btn.pressed.connect(_on_remove_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

	# Initially hide cancel button and clear status
	cancel_btn.visible = false
	status_label.text = ""


func _find_debug_ui() -> CanvasLayer:
	var parent: Node = get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return null


func _on_add_pressed() -> void:
	current_mode = PaintMode.ADD
	cancel_btn.visible = true
	status_label.text = "Click or drag to add walls"
	_update_button_states()
	_create_preview()
	_create_grid_overlay()


func _on_remove_pressed() -> void:
	current_mode = PaintMode.REMOVE
	cancel_btn.visible = true
	status_label.text = "Click or drag to remove walls"
	_update_button_states()
	_create_preview()
	_create_grid_overlay()


func _on_cancel_pressed() -> void:
	_cancel_paint_mode()


func _cancel_paint_mode() -> void:
	current_mode = PaintMode.NONE
	is_dragging = false
	cancel_btn.visible = false
	status_label.text = ""
	_update_button_states()
	_remove_preview()
	_remove_grid_overlay()


func _update_button_states() -> void:
	# Update button visual states based on current mode
	add_btn.button_pressed = (current_mode == PaintMode.ADD)
	remove_btn.button_pressed = (current_mode == PaintMode.REMOVE)


func _process(_delta: float) -> void:
	if current_mode != PaintMode.NONE:
		_update_preview_position()
		_update_grid_overlay_position()


func _input(event: InputEvent) -> void:
	if current_mode == PaintMode.NONE:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is over UI - if so, ignore
				if _is_click_over_ui(event.position):
					return

				is_dragging = true
				_paint_at_screen_position(event.position)
				get_viewport().set_input_as_handled()
			else:
				# Mouse released, stop dragging
				is_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click cancels paint mode
			_cancel_paint_mode()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if is_dragging:
			# Check if drag is over UI - if so, ignore
			if _is_click_over_ui(event.position):
				return

			_paint_at_screen_position(event.position)
			get_viewport().set_input_as_handled()


func _is_click_over_ui(screen_pos: Vector2) -> bool:
	if debug_ui == null:
		return false

	var side_panel: Node = debug_ui.get_node_or_null("SidePanel")
	var job_panel: Node = debug_ui.get_node_or_null("JobPanel")

	if side_panel != null and side_panel is Control:
		if side_panel.get_global_rect().has_point(screen_pos):
			return true

	if job_panel != null and job_panel is Control:
		if job_panel.get_global_rect().has_point(screen_pos):
			return true

	return false


func _screen_to_world(screen_position: Vector2) -> Vector2:
	# Find the camera for coordinate conversion
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_position

	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _paint_at_screen_position(screen_position: Vector2) -> void:
	var world_pos: Vector2 = _screen_to_world(screen_position)
	var grid_pos: Vector2i = DebugCommands.world_to_grid(world_pos)

	var add_wall: bool = (current_mode == PaintMode.ADD)
	var success: bool = DebugCommands.paint_wall(grid_pos, add_wall)

	if success:
		if add_wall:
			status_label.text = "Added wall at " + str(grid_pos)
		else:
			status_label.text = "Removed wall at " + str(grid_pos)
	else:
		if add_wall:
			status_label.text = "Cannot add wall at " + str(grid_pos)
		else:
			status_label.text = "Cannot remove wall at " + str(grid_pos)


# =============================================================================
# Preview Management
# =============================================================================

func _create_preview() -> void:
	_remove_preview()

	# Create a simple preview node
	preview_node = Node2D.new()
	preview_node.name = "WallPaintPreview"
	preview_node.z_index = 100

	# Add visual - a colored square for the tile
	var visual: ColorRect = ColorRect.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.size = Vector2(TILE_SIZE, TILE_SIZE)
	visual.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)

	if current_mode == PaintMode.ADD:
		visual.color = PREVIEW_ADD_COLOR
	else:
		visual.color = PREVIEW_REMOVE_COLOR

	preview_node.add_child(visual)

	# Add to the game world
	var level: Node = _get_level_node()
	if level != null:
		level.add_child(preview_node)
	else:
		var root: Node = get_tree().current_scene
		if root != null:
			root.add_child(preview_node)


func _remove_preview() -> void:
	if preview_node != null and is_instance_valid(preview_node):
		preview_node.queue_free()
	preview_node = null


func _update_preview_position() -> void:
	if preview_node == null or not is_instance_valid(preview_node):
		return

	var mouse_screen_pos: Vector2 = get_viewport().get_mouse_position()

	# Check if over UI - hide preview
	if _is_click_over_ui(mouse_screen_pos):
		preview_node.visible = false
		return

	preview_node.visible = true
	var world_pos: Vector2 = _screen_to_world(mouse_screen_pos)

	# Snap to grid center
	var grid_pos: Vector2i = DebugCommands.world_to_grid(world_pos)
	var snapped_pos: Vector2 = DebugCommands.grid_to_world(grid_pos)

	preview_node.global_position = snapped_pos


# =============================================================================
# Grid Overlay Management
# =============================================================================

func _create_grid_overlay() -> void:
	_remove_grid_overlay()

	# Create grid overlay node
	grid_overlay = Node2D.new()
	grid_overlay.name = "GridOverlay"
	grid_overlay.z_index = 50  # Below preview but above game objects

	# Connect draw signal
	grid_overlay.draw.connect(_draw_grid)

	# Add to game world
	var level: Node = _get_level_node()
	if level != null:
		level.add_child(grid_overlay)
	else:
		var root: Node = get_tree().current_scene
		if root != null:
			root.add_child(grid_overlay)


func _remove_grid_overlay() -> void:
	if grid_overlay != null and is_instance_valid(grid_overlay):
		grid_overlay.queue_free()
	grid_overlay = null


func _update_grid_overlay_position() -> void:
	if grid_overlay == null or not is_instance_valid(grid_overlay):
		return

	# Grid overlay follows camera/viewport center
	var mouse_screen_pos: Vector2 = get_viewport().get_mouse_position()
	var world_pos: Vector2 = _screen_to_world(mouse_screen_pos)

	# Snap to grid for cleaner lines
	var grid_pos: Vector2i = DebugCommands.world_to_grid(world_pos)
	var snapped_pos: Vector2 = DebugCommands.grid_to_world(grid_pos)

	grid_overlay.global_position = snapped_pos
	grid_overlay.queue_redraw()


func _draw_grid() -> void:
	if grid_overlay == null or not is_instance_valid(grid_overlay):
		return

	var half_range: int = GRID_VISIBLE_RANGE / 2
	var start_offset: float = -half_range * TILE_SIZE
	var end_offset: float = half_range * TILE_SIZE

	# Draw vertical lines
	for i in range(-half_range, half_range + 1):
		var x: float = i * TILE_SIZE
		grid_overlay.draw_line(
			Vector2(x, start_offset),
			Vector2(x, end_offset),
			GRID_LINE_COLOR,
			1.0
		)

	# Draw horizontal lines
	for i in range(-half_range, half_range + 1):
		var y: float = i * TILE_SIZE
		grid_overlay.draw_line(
			Vector2(start_offset, y),
			Vector2(end_offset, y),
			GRID_LINE_COLOR,
			1.0
		)


func _get_level_node() -> Node:
	var levels: Array[Node] = get_tree().get_nodes_in_group("level")
	if levels.size() > 0:
		return levels[0]
	return get_tree().current_scene


## Check if paint mode is active (for external coordination)
func is_paint_mode_active() -> bool:
	return current_mode != PaintMode.NONE
