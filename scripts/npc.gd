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

# Reference to positions (set by level)
var walkable_positions: Array[Vector2] = []  # All walkable tiles (for pathfinding)
var wander_positions: Array[Vector2] = []    # Only empty floor tiles (for random wandering)
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

	# Get the most urgent motive first
	var urgent_motive := motives.get_most_urgent_motive()

	# First, try to find an object that fulfills the most urgent need
	var best_object: InteractableObject = null
	var best_score: float = 0.0

	for obj in available_objects:
		# Check if object is available (not occupied or reserved by someone else)
		if not obj.is_available_for(self):
			continue

		# Only consider objects that can fulfill the urgent motive
		if not obj.can_fulfill(urgent_motive):
			continue

		# Score based on fulfillment rate for this specific motive
		var fulfillment_rate := obj.get_fulfillment_rate(urgent_motive)
		if fulfillment_rate <= 0:
			continue

		# Factor in distance - closer objects are better
		var distance := global_position.distance_to(obj.global_position)
		# Distance penalty: score is divided by distance factor
		var distance_factor := 1.0 + (distance / 320.0)
		var final_score := fulfillment_rate / distance_factor

		if final_score > best_score:
			best_score = final_score
			best_object = obj

	# If no object found for urgent motive, try any critical motive
	if best_object == null:
		var critical_motives := motives.get_critical_motives()
		for motive in critical_motives:
			for obj in available_objects:
				if not obj.is_available_for(self):
					continue
				if obj.can_fulfill(motive):
					return obj

	return best_object

func _pathfind_to_object(obj: InteractableObject) -> void:
	# Cancel any existing reservation first
	_cancel_current_reservation()

	# Try to reserve the object
	if not obj.reserve(self):
		# Object got reserved/occupied by someone else, try to find another
		print("[NPC ", npc_id, "] Could not reserve ", obj.get_object_name(), ", finding alternative")
		_start_waiting()
		return

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
		# No path found, cancel reservation and wait
		_cancel_current_reservation()
		target_object = null
		_start_waiting()

func _cancel_current_reservation() -> void:
	if target_object != null:
		target_object.cancel_reservation(self)

func _pick_random_destination() -> void:
	# Cancel any existing reservation when wandering
	_cancel_current_reservation()
	target_object = null

	if wander_positions.is_empty() or astar == null:
		return

	# Pick a random empty floor position (not on objects)
	var target: Vector2 = wander_positions.pick_random()

	# Make sure it's not too close to current position
	var attempts := 0
	while target.distance_to(global_position) < 100.0 and attempts < 10:
		target = wander_positions.pick_random() as Vector2
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
	if target_object == null:
		_start_waiting()
		return

	if not target_object.start_use(self):
		# Failed to start using - cancel reservation and clear target
		target_object.cancel_reservation(self)
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

	# Object use timer runs on real time
	object_use_timer -= delta
	if object_use_timer <= 0.0:
		print("[NPC ", npc_id, "] Timer done, stopping use")
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
	print("[NPC ", npc_id, "] Looking for object to fulfill ", Motive.get_motive_name(motive_type), ", available_objects count: ", available_objects.size())
	for obj in available_objects:
		var can_fulfill := obj.can_fulfill(motive_type)
		var is_available := obj.is_available_for(self)
		print("[NPC ", npc_id, "]   - ", obj.name, " can_fulfill=", can_fulfill, " is_available=", is_available)
		if can_fulfill and is_available:
			_pathfind_to_object(obj)
			return
	print("[NPC ", npc_id, "] No object available to fulfill ", Motive.get_motive_name(motive_type))

# Called by level to set available objects
func set_available_objects(objects: Array[InteractableObject]) -> void:
	# Make a copy so each NPC has their own list
	available_objects = objects.duplicate()

func set_walkable_positions(positions: Array[Vector2]) -> void:
	walkable_positions = positions

func set_wander_positions(positions: Array[Vector2]) -> void:
	wander_positions = positions

func set_astar(astar_ref: AStarGrid2D) -> void:
	astar = astar_ref
	print("[NPC ", npc_id, "] AStar set")

func set_game_clock(clock: GameClock) -> void:
	game_clock = clock

# For interaction with objects via collision
func can_interact_with_object(_obj: InteractableObject) -> bool:
	return true

func on_object_in_range(_obj: InteractableObject) -> void:
	# NPCs know about all objects globally, no need to track by range
	pass

func on_object_out_of_range(_obj: InteractableObject) -> void:
	# NPCs know about all objects globally, no need to track by range
	pass
