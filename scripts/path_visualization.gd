extends Node2D
## Path Visualization - Draws NPC navigation paths for debugging.
## Shows the current path as a line with dots at waypoints.
## Highlights the current target position.

# Reference to the NPC being visualized
var target_npc: Node = null

# Visibility toggle
var is_visible: bool = true

# Path drawing constants
const PATH_COLOR := Color(0.3, 0.8, 1.0, 0.8)  # Light blue
const PATH_WIDTH := 2.0
const WAYPOINT_COLOR := Color(0.3, 0.8, 1.0, 1.0)  # Solid blue
const WAYPOINT_RADIUS := 4.0
const TARGET_COLOR := Color(1.0, 0.5, 0.0, 1.0)  # Orange
const TARGET_RADIUS := 8.0
const CURRENT_POS_COLOR := Color(0.0, 1.0, 0.5, 1.0)  # Green
const CURRENT_POS_RADIUS := 6.0


func _ready() -> void:
	# Ensure this draws above game elements
	z_index = 50


func _process(_delta: float) -> void:
	# Redraw each frame to update path visualization
	if target_npc != null and is_instance_valid(target_npc) and is_visible:
		queue_redraw()


func _draw() -> void:
	if not is_visible:
		return

	if target_npc == null or not is_instance_valid(target_npc):
		return

	# Get path data from NPC
	var current_path: PackedVector2Array = target_npc.current_path
	var path_index: int = target_npc.path_index
	var npc_position: Vector2 = target_npc.global_position

	if current_path.is_empty():
		return

	# Draw the remaining path (from current position to end)
	# First, draw a line from NPC's current position to the next waypoint
	if path_index < current_path.size():
		var next_waypoint: Vector2 = current_path[path_index]
		_draw_line_segment(npc_position, next_waypoint, PATH_COLOR, PATH_WIDTH)

	# Draw the rest of the path segments
	for i in range(path_index, current_path.size() - 1):
		var from_pos: Vector2 = current_path[i]
		var to_pos: Vector2 = current_path[i + 1]
		_draw_line_segment(from_pos, to_pos, PATH_COLOR, PATH_WIDTH)

	# Draw waypoint dots for remaining waypoints
	for i in range(path_index, current_path.size()):
		var waypoint_pos: Vector2 = current_path[i]
		var is_target := (i == current_path.size() - 1)

		if is_target:
			# Final destination - larger orange marker
			_draw_waypoint(waypoint_pos, TARGET_COLOR, TARGET_RADIUS)
		else:
			# Intermediate waypoint - smaller blue dot
			_draw_waypoint(waypoint_pos, WAYPOINT_COLOR, WAYPOINT_RADIUS)

	# Draw current NPC position marker
	_draw_waypoint(npc_position, CURRENT_POS_COLOR, CURRENT_POS_RADIUS)


## Draw a line segment in world coordinates (converts to local)
func _draw_line_segment(from_world: Vector2, to_world: Vector2, color: Color, width: float) -> void:
	var from_local := from_world - global_position
	var to_local := to_world - global_position
	draw_line(from_local, to_local, color, width)


## Draw a waypoint circle in world coordinates (converts to local)
func _draw_waypoint(world_pos: Vector2, color: Color, radius: float) -> void:
	var local_pos := world_pos - global_position
	draw_circle(local_pos, radius, color)


## Set the NPC to visualize
func set_npc(npc: Node) -> void:
	target_npc = npc
	queue_redraw()


## Clear the visualization
func clear() -> void:
	target_npc = null
	queue_redraw()


## Toggle visibility
func set_path_visible(visible: bool) -> void:
	is_visible = visible
	queue_redraw()


## Get current visibility state
func is_path_visible() -> bool:
	return is_visible
