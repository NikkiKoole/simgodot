extends CharacterBody2D

const TILE_SIZE := 32

## Movement speed in pixels per second
@export var speed: float = 80.0
## Minimum wait time at destination (seconds)
@export var min_wait_time: float = 1.0
## Maximum wait time at destination (seconds)
@export var max_wait_time: float = 4.0

enum State { IDLE, WALKING, WAITING, USING_OBJECT }
var current_state: State = State.IDLE
var wait_timer: float = 0.0
var is_initialized: bool = false
var npc_id: int = 0
static var npc_counter: int = 0

# Motive system
var motives: Motive

# Reference to walkable positions (set by level)
var walkable_positions: Array[Vector2] = []
var astar: AStarGrid2D
var current_path: PackedVector2Array = []
var path_index: int = 0

# Object interaction
var available_objects: Array[InteractableObject] = []
var target_object: InteractableObject = null
var object_use_timer: float = 0.0

# Game clock reference
var game_clock: GameClock

func _ready() -> void:
	npc_id = npc_counter
	npc_counter += 1

	# Initialize motive system
	motives = Motive.new("NPC " + str(npc_id))
	motives.motive_depleted.connect(_on_motive_depleted)
	motives.critical_level.connect(_on_motive_critical)

	# Add motive bars UI
	var motive_bars := MotiveBars.new()
	motive_bars.set_motives(motives)
	add_child(motive_bars)

	print("[NPC ", npc_id, "] _ready called, position: ", global_position)

	# Initialize if astar was set before _ready
	if astar != null and not walkable_positions.is_empty() and not is_initialized:
		is_initialized = true
		# Small delay before first move so NPCs don't all move at once
		await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
		_decide_next_action()

func _physics_process(delta: float) -> void:
	if not is_initialized:
		return

	# Calculate game time delta for motive updates
	var game_delta := delta
	if game_clock != null:
		game_delta = game_clock.get_game_delta(delta)

	# Update motives using game time
	motives.update(game_delta)

	match current_state:
		State.IDLE:
			_decide_next_action()

		State.WALKING:
			_follow_path(delta)

		State.WAITING:
			wait_timer -= delta
			if wait_timer <= 0.0:
				current_state = State.IDLE

		State.USING_OBJECT:
			_use_object(delta, game_delta)

func _follow_path(_delta: float) -> void:
	if path_index >= current_path.size():
		# Reached end of path
		if target_object != null:
			_start_using_object()
		else:
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

func _decide_next_action() -> void:
	# Check if we have critical motives that need addressing
	if motives.has_critical_motive():
		var best_object := _find_best_object_for_needs()
		if best_object != null:
			_pathfind_to_object(best_object)
			return

	# Otherwise, just wander randomly
	_pick_random_destination()

func _find_best_object_for_needs() -> InteractableObject:
	if available_objects.is_empty():
		return null

	var best_object: InteractableObject = null
	var best_score: float = 0.0

	for obj in available_objects:
		if obj.is_occupied:
			continue
		var score := obj.get_advertisement_score(motives)
		if score > best_score:
			best_score = score
			best_object = obj

	return best_object

func _pathfind_to_object(obj: InteractableObject) -> void:
	target_object = obj
	var target_pos := obj.get_interaction_position()

	# Convert world positions to grid coordinates
	var from_grid := Vector2i(
		int(global_position.x / TILE_SIZE),
		int(global_position.y / TILE_SIZE)
	)
	var to_grid := Vector2i(
		int(target_pos.x / TILE_SIZE),
		int(target_pos.y / TILE_SIZE)
	)

	# Get path from AStar
	current_path = astar.get_point_path(from_grid, to_grid)
	path_index = 0

	print("[NPC ", npc_id, "] Pathfinding to ", obj.get_object_name(), " for ", Motive.get_motive_name(motives.get_most_urgent_motive()))

	if current_path.size() > 0:
		current_state = State.WALKING
	else:
		# No path found, clear target and wait
		target_object = null
		_start_waiting()

func _pick_random_destination() -> void:
	target_object = null

	if walkable_positions.is_empty() or astar == null:
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

	if current_path.size() > 0:
		current_state = State.WALKING
	else:
		_start_waiting()

func _start_using_object() -> void:
	if target_object == null or not target_object.start_use(self):
		target_object = null
		_start_waiting()
		return

	print("[NPC ", npc_id, "] Started using ", target_object.get_object_name())
	object_use_timer = target_object.use_duration
	current_state = State.USING_OBJECT
	velocity = Vector2.ZERO

func _use_object(delta: float, game_delta: float) -> void:
	if target_object == null:
		current_state = State.IDLE
		return

	# Fulfill motives while using object (uses game time)
	for motive_type in target_object.advertisements:
		var rate: float = target_object.get_fulfillment_rate(motive_type)
		motives.fulfill(motive_type, rate * game_delta)

	# Object use timer runs on real time (actual animation/action duration)
	object_use_timer -= delta
	if object_use_timer <= 0.0:
		_stop_using_object()

func _stop_using_object() -> void:
	if target_object != null:
		print("[NPC ", npc_id, "] Finished using ", target_object.get_object_name())
		target_object.stop_use(self)
		target_object = null
	current_state = State.IDLE

func _start_waiting() -> void:
	velocity = Vector2.ZERO
	wait_timer = randf_range(min_wait_time, max_wait_time)
	current_state = State.WAITING

func _on_motive_depleted(motive_type: Motive.MotiveType) -> void:
	print("[NPC ", npc_id, "] FORCED ACTION: ", Motive.get_motive_name(motive_type), " depleted!")
	# Force find an object to fulfill this need
	_force_fulfill_motive(motive_type)

func _on_motive_critical(motive_type: Motive.MotiveType) -> void:
	# Interrupt current action if not already addressing needs
	if current_state != State.USING_OBJECT:
		print("[NPC ", npc_id, "] Interrupting to address critical ", Motive.get_motive_name(motive_type))
		current_state = State.IDLE

func _force_fulfill_motive(motive_type: Motive.MotiveType) -> void:
	# Find any object that can fulfill this motive
	for obj in available_objects:
		if obj.can_fulfill(motive_type) and not obj.is_occupied:
			_pathfind_to_object(obj)
			return
	print("[NPC ", npc_id, "] No object available to fulfill ", Motive.get_motive_name(motive_type))

# Called by level to set available objects
func set_available_objects(objects: Array[InteractableObject]) -> void:
	available_objects = objects

func set_walkable_positions(positions: Array[Vector2]) -> void:
	walkable_positions = positions

func set_astar(astar_ref: AStarGrid2D) -> void:
	astar = astar_ref
	print("[NPC ", npc_id, "] AStar set")

func set_game_clock(clock: GameClock) -> void:
	game_clock = clock

# For interaction with objects via collision
func can_interact_with_object(_obj: InteractableObject) -> bool:
	return true

func on_object_in_range(obj: InteractableObject) -> void:
	if not available_objects.has(obj):
		available_objects.append(obj)

func on_object_out_of_range(obj: InteractableObject) -> void:
	available_objects.erase(obj)
