extends CharacterBody2D

const TILE_SIZE := 32

## Movement speed in pixels per second
@export var speed: float = 80.0
## Minimum wait time at destination (seconds)
@export var min_wait_time: float = 1.0
## Maximum wait time at destination (seconds)
@export var max_wait_time: float = 4.0

enum State { IDLE, WALKING, WAITING }
var current_state: State = State.IDLE
var wait_timer: float = 0.0
var is_initialized: bool = false
var npc_id: int = 0
static var npc_counter: int = 0

# Reference to walkable positions (set by level)
var walkable_positions: Array[Vector2] = []
var astar: AStarGrid2D
var current_path: PackedVector2Array = []
var path_index: int = 0

func _ready() -> void:
	npc_id = npc_counter
	npc_counter += 1
	print("[NPC ", npc_id, "] _ready called, position: ", global_position)

	# Initialize if astar was set before _ready
	if astar != null and not walkable_positions.is_empty() and not is_initialized:
		is_initialized = true
		# Small delay before first move so NPCs don't all move at once
		await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
		_pick_new_destination()

func _physics_process(delta: float) -> void:
	if not is_initialized:
		return

	match current_state:
		State.IDLE:
			_pick_new_destination()

		State.WALKING:
			_follow_path(delta)

		State.WAITING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				current_state = State.IDLE

func _follow_path(delta: float) -> void:
	if path_index >= current_path.size():
		# Reached end of path
		print("[NPC ", npc_id, "] Reached destination")
		_start_waiting()
		return

	var target_pos := current_path[path_index]
	var direction := global_position.direction_to(target_pos)
	var distance := global_position.distance_to(target_pos)

	if distance < 4.0:
		# Reached this waypoint, move to next
		path_index += 1
		return

	velocity = direction * speed
	move_and_slide()

func _pick_new_destination() -> void:
	if walkable_positions.is_empty() or astar == null:
		print("[NPC ", npc_id, "] ERROR: No walkable positions or astar not set!")
		return

	# Pick a random walkable position
	var target: Vector2 = walkable_positions.pick_random()

	# Make sure it's not too close to current position
	var attempts := 0
	while target.distance_to(global_position) < 100.0 and attempts < 10:
		target = walkable_positions.pick_random() as Vector2
		attempts += 1

	# Convert world positions to grid coordinates
	var from_grid := Vector2i(
		int(global_position.x / TILE_SIZE),
		int(global_position.y / TILE_SIZE)
	)
	var to_grid := Vector2i(
		int(target.x / TILE_SIZE),
		int(target.y / TILE_SIZE)
	)

	# Get path from AStar
	current_path = astar.get_point_path(from_grid, to_grid)
	path_index = 0

	print("[NPC ", npc_id, "] Path from ", from_grid, " to ", to_grid, " = ", current_path.size(), " points")

	if current_path.size() > 0:
		current_state = State.WALKING
	else:
		# No path found, wait and try again
		print("[NPC ", npc_id, "] No path found, waiting...")
		_start_waiting()

func _start_waiting() -> void:
	velocity = Vector2.ZERO
	wait_timer = randf_range(min_wait_time, max_wait_time)
	current_state = State.WAITING

func set_walkable_positions(positions: Array[Vector2]) -> void:
	walkable_positions = positions

func set_astar(astar_ref: AStarGrid2D) -> void:
	astar = astar_ref
	print("[NPC ", npc_id, "] AStar set")
