extends CharacterBody2D

const TILE_SIZE := 32

## Movement speed in pixels per second
@export var speed: float = 80.0
## Minimum wait time at destination (seconds)
@export var min_wait_time: float = 1.0
## Maximum wait time at destination (seconds)
@export var max_wait_time: float = 4.0

## Steering/Avoidance settings
@export var avoidance_radius: float = 40.0  # How far to look for others
@export var avoidance_strength: float = 60.0  # How hard to steer away
@export var stuck_threshold: float = 1.0  # Seconds without progress before wiggling
@export var wiggle_strength: float = 40.0  # Random force when stuck

enum State { IDLE, WALKING, WAITING, USING_OBJECT, HAULING, WORKING }
var current_state: State = State.IDLE
var wait_timer: float = 0.0
var is_initialized: bool = false
var npc_id: int = 0
static var npc_counter: int = 0

# Stuck detection
var last_position: Vector2 = Vector2.ZERO
var stuck_timer: float = 0.0
var wiggle_direction: Vector2 = Vector2.ZERO

# Dynamic collision shrinking when stuck
const DEFAULT_COLLISION_RADIUS: float = 8.0
const MIN_COLLISION_RADIUS: float = 1.0
const SHRINK_RATE: float = 10.0  # Radius shrink per second when stuck (fast!)
const GROW_RATE: float = 2.0    # Radius grow per second when moving (slow to recover)
var current_collision_radius: float = DEFAULT_COLLISION_RADIUS
var collision_shape: CollisionShape2D

# External push velocity (from player bumping)
var push_velocity: Vector2 = Vector2.ZERO

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

# Job system / Hauling
var current_job: Job = null
var held_items: Array[ItemEntity] = []
var available_containers: Array[ItemContainer] = []
var target_container: ItemContainer = null
var items_to_gather: Array[Dictionary] = []  # [{tag: String, quantity: int}]

# Job system / Working
var available_stations: Array[Station] = []
var target_station: Station = null
var work_timer: float = 0.0
var current_animation: String = ""  # Animation being played for current step

func _ready() -> void:
	npc_id = npc_counter
	npc_counter += 1

	# Get reference to collision shape for dynamic resizing
	collision_shape = $CollisionShape2D

	# Initialize motive system
	motives = Motive.new("NPC " + str(npc_id))
	motives.motive_depleted.connect(_on_motive_depleted)
	motives.critical_level.connect(_on_motive_critical)

	# Add motive bars UI
	var motive_bars := MotiveBars.new()
	motive_bars.set_motives(motives)
	add_child(motive_bars)



	# Enable drawing and trigger initial draw
	set_notify_transform(true)
	queue_redraw()

	# Initialize if astar was already set
	_initialize_if_ready()

func _draw() -> void:
	# Draw collision circle outline for debugging
	var color := Color(0, 1, 0, 1.0)  # Bright green
	if stuck_timer > stuck_threshold:
		color = Color(1, 0, 1, 1.0)  # Bright magenta when stuck
	# Draw as arc (full circle outline) with 2px width
	draw_arc(Vector2.ZERO, current_collision_radius, 0, TAU, 32, color, 2.0)

func _initialize_if_ready() -> void:
	# Initialize if astar was set before _ready
	if astar != null and not walkable_positions.is_empty() and not is_initialized:
		is_initialized = true
		# Small delay before first move so NPCs don't all move at once
		await get_tree().create_timer(randf_range(0.1, 0.5)).timeout
		_decide_next_action()

func _physics_process(delta: float) -> void:
	if not is_initialized:
		return

	# Get speed multiplier and scaled deltas from game clock
	var speed_mult := 1.0
	var game_delta := delta  # For motive updates (in game minutes)
	var scaled_delta := delta  # For timers (scaled by speed)
	if game_clock != null:
		speed_mult = game_clock.speed_multiplier if not game_clock.is_paused else 0.0
		game_delta = game_clock.get_game_delta(delta)
		scaled_delta = game_clock.get_scaled_delta(delta)

	# Handle push velocity from player
	if push_velocity.length() > 0:
		velocity = push_velocity
		# Subdivide push movement to prevent tunneling
		var max_step := current_collision_radius * 0.25
		var push_dist := velocity.length() * delta
		if push_dist > max_step and velocity.length() > 0:
			var substeps := ceili(push_dist / max_step)
			var substep_vel := velocity / substeps
			for i in substeps:
				velocity = substep_vel
				move_and_slide()
		else:
			move_and_slide()
		push_velocity = push_velocity.move_toward(Vector2.ZERO, 200.0 * delta)

	# Keep NPC within valid bounds (prevent clipping through walls)
	_clamp_to_valid_position()

	# Update motives using game time
	motives.update(game_delta)

	# Always redraw debug circle
	queue_redraw()

	match current_state:
		State.IDLE:
			_decide_next_action()

		State.WALKING:
			_follow_path(speed_mult)

		State.WAITING:
			wait_timer -= scaled_delta
			if wait_timer <= 0.0:
				current_state = State.IDLE

		State.USING_OBJECT:
			_use_object(scaled_delta, game_delta)

		State.HAULING:
			_follow_path_hauling(speed_mult)

		State.WORKING:
			_do_work(scaled_delta, game_delta)

func _follow_path(speed_mult: float) -> void:
	if path_index >= current_path.size():
		# Reached end of path
		if target_object != null:
			_start_using_object()
		else:
			_start_waiting()
		stuck_timer = 0.0
		return

	# Dynamic look-ahead: periodically check if we can skip waypoints
	# Use scaled delta so checks happen at consistent game-time intervals
	if path_smoothing_enabled:
		var delta := get_physics_process_delta_time() * speed_mult
		lookahead_timer -= delta
		if lookahead_timer <= 0.0:
			lookahead_timer = dynamic_lookahead_interval
			_try_skip_waypoints()

	var target_pos := current_path[path_index]
	var distance := global_position.distance_to(target_pos)
	var delta := get_physics_process_delta_time()

	# Calculate how far we'd move this frame
	var move_distance := speed * speed_mult * delta

	# If we're close enough (or would overshoot), snap to waypoint and move to next
	if distance <= move_distance + 2.0:
		# Snap to waypoint and move to next
		global_position = target_pos
		path_index += 1
		stuck_timer = 0.0
		return

	# Calculate desired direction to target
	var desired_direction := global_position.direction_to(target_pos)

	# Get avoidance force from nearby entities (disabled when stuck to allow pushing through)
	var avoidance := _calculate_avoidance()
	if stuck_timer > stuck_threshold:
		avoidance = Vector2.ZERO  # No avoidance when stuck

	# Check if stuck (not making meaningful progress toward goal)
	var progress_toward_goal := last_position.distance_to(target_pos) - global_position.distance_to(target_pos)
	var expected_progress := speed * speed_mult * delta * 0.3  # Need 30% of expected speed to count as progress
	if progress_toward_goal < expected_progress:
		stuck_timer += delta * speed_mult  # Scale with game speed
	else:
		# Only reset timer if making good progress, otherwise just reduce it slowly
		if progress_toward_goal > expected_progress * 2:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
		else:
			stuck_timer = maxf(0.0, stuck_timer - delta * speed_mult * 0.5)  # Scale with game speed
	last_position = global_position

	# Dynamic collision shrinking/growing based on stuck state
	if stuck_timer > stuck_threshold:
		# Already at minimum collision and still stuck? Give up and find new route
		if current_collision_radius <= MIN_COLLISION_RADIUS + 0.1:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
			current_state = State.IDLE  # Will pick new destination
			return
		# Shrink collision when stuck (scale with game speed)
		_update_collision_radius(current_collision_radius - SHRINK_RATE * delta * speed_mult)
	elif current_collision_radius < DEFAULT_COLLISION_RADIUS:
		# Grow back when moving normally (scale with game speed)
		_update_collision_radius(current_collision_radius + GROW_RATE * delta * speed_mult)

	# If stuck, add wiggle force
	var wiggle := Vector2.ZERO
	if stuck_timer > stuck_threshold:
		if wiggle_direction == Vector2.ZERO:
			# Pick a random perpendicular direction to wiggle
			wiggle_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wiggle = wiggle_direction * wiggle_strength

	# Combine forces: desired movement + avoidance + wiggle
	var final_velocity := desired_direction * speed + avoidance * avoidance_strength + wiggle

	# Apply speed multiplier and clamp
	final_velocity *= speed_mult
	var max_speed := speed * speed_mult * 1.3  # Allow slight overspeed when avoiding
	if final_velocity.length() > max_speed:
		final_velocity = final_velocity.normalized() * max_speed

	velocity = final_velocity

	# Subdivide movement when moving fast to prevent tunneling through other bodies
	# Max safe movement per step is roughly half the collision radius
	var max_step_distance := current_collision_radius * 0.25
	var frame_distance := velocity.length() * delta

	if frame_distance > max_step_distance and velocity.length() > 0:
		# Calculate how many substeps we need (no cap - let it scale with speed)
		var substeps := ceili(frame_distance / max_step_distance)



		# Reduce velocity for each substep
		var substep_velocity := velocity / substeps
		for i in substeps:
			velocity = substep_velocity
			move_and_slide()
	else:
		move_and_slide()

func _calculate_avoidance() -> Vector2:
	var avoidance := Vector2.ZERO

	# Find nearby bodies using physics query
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = avoidance_radius
	query.shape = circle
	query.transform = Transform2D(0, global_position)
	query.collision_mask = 6  # Layer 2 (NPCs) + Layer 4 (Player)
	query.exclude = [get_rid()]

	var results := space_state.intersect_shape(query, 10)

	for result in results:
		var other: Node2D = result.collider
		if other == self:
			continue

		var to_self := global_position - other.global_position
		var dist := to_self.length()

		if dist > 0 and dist < avoidance_radius:
			# Stronger avoidance when closer (inverse square falloff)
			var strength := pow(1.0 - (dist / avoidance_radius), 2)
			avoidance += to_self.normalized() * strength

	return avoidance

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
	# Stop using current object if we were using one
	if current_state == State.USING_OBJECT:
		_stop_using_object()

	# Cancel any existing reservation first
	_cancel_current_reservation()

	# Try to reserve the object
	if not obj.reserve(self):
		# Object got reserved/occupied by someone else, try to find another

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

	# Pre-smooth the path to remove unnecessary waypoints
	if path_smoothing_enabled and current_path.size() > 2:
		current_path = _smooth_path(current_path)

	path_index = 0



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

	# Pre-smooth the path to remove unnecessary waypoints
	if path_smoothing_enabled and current_path.size() > 2:
		current_path = _smooth_path(current_path)

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

	# Object use timer runs on game time
	object_use_timer -= game_delta
	if object_use_timer <= 0.0:
		_stop_using_object()
	# Also stop early if the motive is fully satisfied
	elif _is_motive_satisfied():
		_stop_using_object()

func _is_motive_satisfied() -> bool:
	if target_object == null:
		return true
	# Check if all motives this object fulfills are above 90%
	for motive_type in target_object.advertisements:
		if motives.get_value(motive_type) < 90.0:
			return false
	return true

func _stop_using_object() -> void:
	if target_object != null:
		target_object.stop_use(self)
		target_object = null
	current_state = State.IDLE

func _start_waiting() -> void:
	velocity = Vector2.ZERO
	wait_timer = randf_range(min_wait_time, max_wait_time)
	current_state = State.WAITING

func _on_motive_depleted(motive_type: Motive.MotiveType) -> void:
	_force_fulfill_motive(motive_type)

func _on_motive_critical(_motive_type: Motive.MotiveType) -> void:
	if current_state != State.USING_OBJECT:
		current_state = State.IDLE

func _force_fulfill_motive(motive_type: Motive.MotiveType) -> void:
	for obj in available_objects:
		if obj.can_fulfill(motive_type) and obj.is_available_for(self):
			_pathfind_to_object(obj)
			return

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

# Called by player when bumping into this NPC
func receive_push(push: Vector2) -> void:
	push_velocity = push

# Called by level to set available containers for hauling
func set_available_containers(containers: Array[ItemContainer]) -> void:
	available_containers = containers.duplicate()

# ============================================================================
# HAULING STATE - Gathering items for jobs
# ============================================================================

## Start hauling items for a job
## Returns true if hauling started, false if requirements can't be met
func start_hauling_for_job(job: Job) -> bool:
	if job == null or job.recipe == null:
		return false

	current_job = job
	held_items.clear()
	items_to_gather.clear()

	# Build list of items to gather from recipe inputs and tools
	for input_data in job.recipe.inputs:
		var input := Recipe.RecipeInput.from_dict(input_data)
		items_to_gather.append({"tag": input.item_tag, "quantity": input.quantity})

	for tool_tag in job.recipe.tools:
		items_to_gather.append({"tag": tool_tag, "quantity": 1})

	# Start gathering the first item
	return _start_gathering_next_item()

## Find and pathfind to the next item that needs to be gathered
func _start_gathering_next_item() -> bool:
	if items_to_gather.is_empty():
		# All items gathered, transition to moving to station
		_on_all_items_gathered()
		return true

	# Find a container with the required item
	var needed := items_to_gather[0]
	var tag: String = needed["tag"]
	var quantity: int = needed["quantity"]

	# Count how many of this tag we already have
	var held_count := 0
	for item in held_items:
		if item.item_tag == tag:
			held_count += 1

	# If we have enough of this item, move to next
	if held_count >= quantity:
		items_to_gather.remove_at(0)
		return _start_gathering_next_item()

	# Find a container with an available item of this tag
	target_container = _find_container_with_item(tag)
	if target_container == null:
		# No container found with this item, job cannot proceed
		_cancel_hauling()
		return false

	# Pathfind to the container
	_pathfind_to_container(target_container)
	return true

## Find a container that has an available item with the given tag
func _find_container_with_item(tag: String) -> ItemContainer:
	for container in available_containers:
		if container.has_available_item(tag):
			return container
	return null

## Pathfind to a container
func _pathfind_to_container(container: ItemContainer) -> void:
	if astar == null:
		_cancel_hauling()
		return

	var target_pos := container.global_position

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

	# Pre-smooth the path
	if path_smoothing_enabled and current_path.size() > 2:
		current_path = _smooth_path(current_path)

	path_index = 0

	if current_path.size() > 0:
		current_state = State.HAULING
	else:
		# No path found
		_cancel_hauling()

## Follow path while in HAULING state (similar to _follow_path but handles arrival differently)
func _follow_path_hauling(speed_mult: float) -> void:
	if path_index >= current_path.size():
		# Reached container, pick up item
		_on_arrived_at_container()
		return

	# Use the same path following logic as WALKING state
	var target_pos := current_path[path_index]
	var distance := global_position.distance_to(target_pos)
	var delta := get_physics_process_delta_time()

	var move_distance := speed * speed_mult * delta

	if distance <= move_distance + 2.0:
		global_position = target_pos
		path_index += 1
		stuck_timer = 0.0
		return

	var desired_direction := global_position.direction_to(target_pos)
	var avoidance := _calculate_avoidance()

	if stuck_timer > stuck_threshold:
		avoidance = Vector2.ZERO

	# Check stuck progress
	var progress_toward_goal := last_position.distance_to(target_pos) - global_position.distance_to(target_pos)
	var expected_progress := speed * speed_mult * delta * 0.3

	if progress_toward_goal < expected_progress:
		stuck_timer += delta * speed_mult
	else:
		if progress_toward_goal > expected_progress * 2:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
		else:
			stuck_timer = maxf(0.0, stuck_timer - delta * speed_mult * 0.5)

	last_position = global_position

	# Dynamic collision shrinking
	if stuck_timer > stuck_threshold:
		if current_collision_radius <= MIN_COLLISION_RADIUS + 0.1:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
			_cancel_hauling()
			return
		_update_collision_radius(current_collision_radius - SHRINK_RATE * delta * speed_mult)
	elif current_collision_radius < DEFAULT_COLLISION_RADIUS:
		_update_collision_radius(current_collision_radius + GROW_RATE * delta * speed_mult)

	var wiggle := Vector2.ZERO
	if stuck_timer > stuck_threshold:
		if wiggle_direction == Vector2.ZERO:
			wiggle_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wiggle = wiggle_direction * wiggle_strength

	var final_velocity := desired_direction * speed + avoidance * avoidance_strength + wiggle
	final_velocity *= speed_mult

	var max_speed := speed * speed_mult * 1.3
	if final_velocity.length() > max_speed:
		final_velocity = final_velocity.normalized() * max_speed

	velocity = final_velocity

	var max_step_distance := current_collision_radius * 0.25
	var frame_distance := velocity.length() * delta

	if frame_distance > max_step_distance and velocity.length() > 0:
		var substeps := ceili(frame_distance / max_step_distance)
		var substep_velocity := velocity / substeps
		for i in substeps:
			velocity = substep_velocity
			move_and_slide()
	else:
		move_and_slide()

## Called when agent arrives at the target container
func _on_arrived_at_container() -> void:
	if target_container == null or items_to_gather.is_empty():
		_cancel_hauling()
		return

	var needed := items_to_gather[0]
	var tag: String = needed["tag"]

	# Find and pick up the item
	var item := target_container.find_item_by_tag(tag)
	if item == null or item.is_reserved():
		# Item no longer available, try to find another container
		target_container = null
		if not _start_gathering_next_item():
			_cancel_hauling()
		return

	# Pick up the item
	_pick_up_item(item)

	# Check if we need more of this item
	var quantity_needed: int = needed["quantity"]
	var held_count := 0
	for held_item in held_items:
		if held_item.item_tag == tag:
			held_count += 1

	if held_count >= quantity_needed:
		# Got enough of this item, move to next requirement
		items_to_gather.remove_at(0)

	# Continue gathering
	target_container = null
	_start_gathering_next_item()

## Pick up an item from a container
func _pick_up_item(item: ItemEntity) -> void:
	if item == null:
		return

	# Remove from container
	var parent := item.get_parent()
	if parent is ItemContainer:
		parent.remove_item(item)

	# Set item state
	item.pick_up(self)

	# Add to held items
	held_items.append(item)

	# Add to job's gathered items if we have a job
	if current_job != null:
		current_job.add_gathered_item(item)

	# Reparent to agent (optional - could keep at world level)
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	add_child(item)
	item.position = Vector2.ZERO  # Hide at agent's position

## Called when all required items have been gathered
func _on_all_items_gathered() -> void:
	target_container = null

	# Start working on the job - find station for first step
	if current_job != null and current_job.recipe != null:
		current_job.start()
		_start_next_work_step()
	else:
		current_state = State.IDLE

## Cancel hauling and release resources
func _cancel_hauling() -> void:
	# Drop all held items (make a copy since _drop_item modifies held_items)
	var items_to_drop := held_items.duplicate()
	for item in items_to_drop:
		if is_instance_valid(item):
			_drop_item(item)
	held_items.clear()

	# Release job if we have one
	if current_job != null:
		current_job.release()
		current_job = null

	items_to_gather.clear()
	target_container = null
	current_state = State.IDLE

## Drop an item at the current position
func _drop_item(item: ItemEntity) -> void:
	if item == null or not is_instance_valid(item):
		return

	# Remove from held items if present
	var idx := held_items.find(item)
	if idx >= 0:
		held_items.remove_at(idx)

	# Remove from job's gathered items
	if current_job != null:
		current_job.remove_gathered_item(item)

	# Reparent to world
	if item.get_parent() == self:
		remove_child(item)
		get_parent().add_child(item)
		item.global_position = global_position

	# Update item state
	item.drop()
	item.release_item()

## Get the array of currently held items
func get_held_items() -> Array[ItemEntity]:
	return held_items

## Check if agent is currently holding any items
func is_holding_items() -> bool:
	return not held_items.is_empty()

## Remove a held item (called when item is consumed or placed)
func remove_held_item(item: ItemEntity) -> bool:
	var idx := held_items.find(item)
	if idx >= 0:
		held_items.remove_at(idx)
		return true
	return false

# Path smoothing settings
@export var path_smoothing_enabled: bool = true
@export var dynamic_lookahead_interval: float = 0.2  # How often to check for shortcuts while walking
var lookahead_timer: float = 0.0

# Check if there's a clear line of sight between two points (no walls)
func _has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1  # Wall layer
	var result := space_state.intersect_ray(query)
	return result.is_empty()

# Pre-smooth path by removing unnecessary waypoints
func _smooth_path(path: PackedVector2Array) -> PackedVector2Array:
	if path.size() <= 2:
		return path

	var smoothed: PackedVector2Array = []
	smoothed.append(path[0])

	var current_index := 0
	while current_index < path.size() - 1:
		# Look ahead as far as possible from current point
		var furthest_visible := current_index + 1
		# Check from the end backwards to find furthest visible point
		for i in range(path.size() - 1, current_index + 1, -1):
			if _has_line_of_sight(path[current_index], path[i]):
				furthest_visible = i
				break
		smoothed.append(path[furthest_visible])
		current_index = furthest_visible

	return smoothed

# Dynamic look-ahead: check if we can skip to a further waypoint while walking
func _try_skip_waypoints() -> void:
	if current_path.is_empty() or path_index >= current_path.size() - 1:
		return

	# Check from the end of the path backwards to find furthest visible point
	for i in range(current_path.size() - 1, path_index, -1):
		if _has_line_of_sight(global_position, current_path[i]):
			if i > path_index:
				#print("[NPC ", npc_id, "] Skipping from waypoint ", path_index, " to ", i)
				path_index = i
			break

# Clamp NPC position to valid walkable area
func _clamp_to_valid_position() -> void:
	if astar == null:
		return

	# Convert current position to grid coordinates
	var grid_pos := Vector2i(
		int(global_position.x / TILE_SIZE),
		int(global_position.y / TILE_SIZE)
	)

	# Check if current grid cell is solid (wall)
	if astar.is_point_solid(grid_pos):
		# Find nearest walkable position
		var nearest_dist := INF
		var nearest_pos := global_position
		for pos in walkable_positions:
			var dist := global_position.distance_to(pos)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = pos

		# Teleport to nearest valid position
		global_position = nearest_pos
		print("[NPC ", npc_id, "] Corrected position - was in wall!")

# Update the collision shape radius
func _update_collision_radius(new_radius: float) -> void:
	current_collision_radius = clamp(new_radius, MIN_COLLISION_RADIUS, DEFAULT_COLLISION_RADIUS)
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = current_collision_radius
	queue_redraw()

# ============================================================================
# WORKING STATE - Executing recipe steps at stations
# ============================================================================

## Called by level to set available stations
func set_available_stations(stations: Array[Station]) -> void:
	available_stations = stations.duplicate()

## Start the next work step in the current job's recipe
func _start_next_work_step() -> void:
	if current_job == null or current_job.recipe == null:
		_finish_job()
		return

	var step := current_job.get_current_step()
	if step == null:
		# No more steps, job is complete
		_finish_job()
		return

	# Find station for this step
	var station := _find_station_for_step(step)
	if station == null:
		# No available station found, fail the job
		_cancel_working("No station available for step: " + step.station_tag)
		return

	# Reserve the station
	if not station.reserve(self):
		_cancel_working("Could not reserve station: " + station.station_tag)
		return

	target_station = station
	current_job.target_station = station

	# Pathfind to station's agent footprint
	_pathfind_to_station(station)

## Find an available station matching the step's station_tag
func _find_station_for_step(step: RecipeStep) -> Station:
	if not step.requires_station():
		return null

	for station in available_stations:
		if station.station_tag == step.station_tag and station.is_available():
			return station

	# Also check if we already reserved one that matches
	for station in available_stations:
		if station.station_tag == step.station_tag and station.is_reserved_by(self):
			return station

	return null

## Pathfind to a station's agent footprint position
func _pathfind_to_station(station: Station) -> void:
	if astar == null:
		_cancel_working("No pathfinding available")
		return

	var target_pos := station.get_agent_position()

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

	# Pre-smooth the path
	if path_smoothing_enabled and current_path.size() > 2:
		current_path = _smooth_path(current_path)

	path_index = 0

	if current_path.size() > 0:
		current_state = State.WORKING
	else:
		# Already at station or no path needed
		_on_arrived_at_station()

## Follow path while in WORKING state (moving to station)
func _follow_path_working(speed_mult: float) -> void:
	if path_index >= current_path.size():
		# Reached station
		_on_arrived_at_station()
		return

	# Use the same path following logic as other states
	var target_pos := current_path[path_index]
	var distance := global_position.distance_to(target_pos)
	var delta := get_physics_process_delta_time()

	var move_distance := speed * speed_mult * delta

	if distance <= move_distance + 2.0:
		global_position = target_pos
		path_index += 1
		stuck_timer = 0.0
		return

	var desired_direction := global_position.direction_to(target_pos)
	var avoidance := _calculate_avoidance()

	if stuck_timer > stuck_threshold:
		avoidance = Vector2.ZERO

	# Check stuck progress
	var progress_toward_goal := last_position.distance_to(target_pos) - global_position.distance_to(target_pos)
	var expected_progress := speed * speed_mult * delta * 0.3

	if progress_toward_goal < expected_progress:
		stuck_timer += delta * speed_mult
	else:
		if progress_toward_goal > expected_progress * 2:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
		else:
			stuck_timer = maxf(0.0, stuck_timer - delta * speed_mult * 0.5)

	last_position = global_position

	# Dynamic collision shrinking
	if stuck_timer > stuck_threshold:
		if current_collision_radius <= MIN_COLLISION_RADIUS + 0.1:
			stuck_timer = 0.0
			wiggle_direction = Vector2.ZERO
			_cancel_working("Got stuck while moving to station")
			return
		_update_collision_radius(current_collision_radius - SHRINK_RATE * delta * speed_mult)
	elif current_collision_radius < DEFAULT_COLLISION_RADIUS:
		_update_collision_radius(current_collision_radius + GROW_RATE * delta * speed_mult)

	var wiggle := Vector2.ZERO
	if stuck_timer > stuck_threshold:
		if wiggle_direction == Vector2.ZERO:
			wiggle_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		wiggle = wiggle_direction * wiggle_strength

	var final_velocity := desired_direction * speed + avoidance * avoidance_strength + wiggle
	final_velocity *= speed_mult

	var max_speed := speed * speed_mult * 1.3
	if final_velocity.length() > max_speed:
		final_velocity = final_velocity.normalized() * max_speed

	velocity = final_velocity

	var max_step_distance := current_collision_radius * 0.25
	var frame_distance := velocity.length() * delta

	if frame_distance > max_step_distance and velocity.length() > 0:
		var substeps := ceili(frame_distance / max_step_distance)
		var substep_velocity := velocity / substeps
		for i in substeps:
			velocity = substep_velocity
			move_and_slide()
	else:
		move_and_slide()

## Called when agent arrives at the target station
func _on_arrived_at_station() -> void:
	if target_station == null or current_job == null:
		_cancel_working("No station or job on arrival")
		return

	velocity = Vector2.ZERO

	# Place held items in station input slots if needed
	_place_items_in_station()

	# Start the work timer for current step
	_start_step_work()

## Place held items into station input slots
func _place_items_in_station() -> void:
	if target_station == null:
		return

	# Place each held item in an available input slot
	var items_to_place := held_items.duplicate()
	for item in items_to_place:
		if not is_instance_valid(item):
			continue

		var slot_index := target_station.find_empty_input_slot()
		if slot_index >= 0:
			# Remove from held items
			remove_held_item(item)
			# Remove from our child if it's parented to us
			if item.get_parent() == self:
				remove_child(item)
			# Place in station slot
			target_station.place_input_item(item, slot_index)

## Start working on the current step
func _start_step_work() -> void:
	if current_job == null:
		_cancel_working("No job for step work")
		return

	var step := current_job.get_current_step()
	if step == null:
		_finish_job()
		return

	# Set up timer and animation
	work_timer = step.duration
	current_animation = step.animation

	# Play animation if specified (agent would need AnimationPlayer)
	if not current_animation.is_empty():
		_play_animation(current_animation)

## Do work on the current step (called each frame in WORKING state)
func _do_work(scaled_delta: float, _game_delta: float) -> void:
	# If we're still pathfinding to station, follow the path
	if path_index < current_path.size():
		# Get speed multiplier
		var speed_mult := 1.0
		if game_clock != null:
			speed_mult = game_clock.speed_multiplier if not game_clock.is_paused else 0.0
		_follow_path_working(speed_mult)
		return

	# We're at the station, count down work timer
	if work_timer > 0.0:
		work_timer -= scaled_delta
		if work_timer <= 0.0:
			_on_step_complete()

## Called when the current step's timer completes
func _on_step_complete() -> void:
	if current_job == null:
		_cancel_working("No job on step complete")
		return

	var step := current_job.get_current_step()
	if step != null:
		# Apply input transforms to items
		_apply_step_transforms(step)

	# Stop animation
	if not current_animation.is_empty():
		_stop_animation()
		current_animation = ""

	# Release current station if we're done with it
	if target_station != null:
		# Check if next step uses a different station
		var next_step_index := current_job.current_step_index + 1
		var next_step: RecipeStep = null
		if next_step_index < current_job.get_total_steps():
			next_step = current_job.recipe.get_step(next_step_index)

		# Release station if next step uses different station or no next step
		if next_step == null or next_step.station_tag != target_station.station_tag:
			# Pick up items from station before leaving
			_pick_up_items_from_station()
			target_station.release()
			target_station = null
			current_job.target_station = null

	# Advance to next step
	if current_job.advance_step():
		# More steps remaining
		_start_next_work_step()
	else:
		# All steps complete
		_finish_job()

## Apply input_transform from step to items at the station
func _apply_step_transforms(step: RecipeStep) -> void:
	if step.input_transform.is_empty():
		return

	# Get all items at station (in input slots and held)
	var items_to_transform: Array[ItemEntity] = []

	if target_station != null:
		items_to_transform.append_array(target_station.get_all_input_items())

	# Also check held items
	for item in held_items:
		if is_instance_valid(item):
			items_to_transform.append(item)

	# Apply transforms
	for item in items_to_transform:
		if not is_instance_valid(item):
			continue

		if step.transforms_item(item.item_tag):
			var new_tag := step.get_transformed_tag(item.item_tag)
			item.item_tag = new_tag

			# Also update state based on common patterns
			if new_tag.contains("prepped"):
				item.set_state(ItemEntity.ItemState.PREPPED)
			elif new_tag.contains("cooked"):
				item.set_state(ItemEntity.ItemState.COOKED)

## Pick up items from station input/output slots
func _pick_up_items_from_station() -> void:
	if target_station == null:
		return

	# Pick up from output slots first
	for i in range(target_station.get_output_slot_count()):
		var item := target_station.remove_output_item(i)
		if item != null and is_instance_valid(item):
			_pick_up_item(item)

	# Then input slots
	for i in range(target_station.get_input_slot_count()):
		var item := target_station.remove_input_item(i)
		if item != null and is_instance_valid(item):
			_pick_up_item(item)

## Complete the job successfully
func _finish_job() -> void:
	if current_job == null:
		current_state = State.IDLE
		return

	# Apply motive effects from recipe
	if current_job.recipe != null:
		for motive_name in current_job.recipe.motive_effects:
			var effect: float = current_job.recipe.motive_effects[motive_name]
			# Convert motive name to MotiveType if possible
			var motive_type := _motive_name_to_type(motive_name)
			if motive_type >= 0:
				motives.fulfill(motive_type, effect)

	# Handle consumed items - remove them
	if current_job.recipe != null:
		var consumed_tags := current_job.recipe.get_consumed_input_tags()
		var items_to_remove: Array[ItemEntity] = []
		for item in held_items:
			if is_instance_valid(item) and consumed_tags.has(item.item_tag):
				items_to_remove.append(item)
		for item in items_to_remove:
			remove_held_item(item)
			item.queue_free()

	# Release station if still reserved
	if target_station != null:
		if target_station.is_reserved_by(self):
			target_station.release()
		target_station = null

	# Complete the job
	current_job.complete()
	current_job = null

	# Drop any remaining held items
	var remaining_items := held_items.duplicate()
	for item in remaining_items:
		if is_instance_valid(item):
			_drop_item(item)
	held_items.clear()

	current_state = State.IDLE

## Cancel working and release resources
func _cancel_working(reason: String = "") -> void:
	if reason != "":
		print("[NPC ", npc_id, "] Cancel working: ", reason)

	# Release station
	if target_station != null:
		# Pick up any items we placed
		_pick_up_items_from_station()
		if target_station.is_reserved_by(self):
			target_station.release()
		target_station = null

	# Stop animation
	if not current_animation.is_empty():
		_stop_animation()
		current_animation = ""

	# Drop all held items
	var items_to_drop := held_items.duplicate()
	for item in items_to_drop:
		if is_instance_valid(item):
			_drop_item(item)
	held_items.clear()

	# Fail the job if we have one
	if current_job != null:
		current_job.fail(reason)
		current_job = null

	work_timer = 0.0
	current_state = State.IDLE

## Play an animation (stub - agents may not have AnimationPlayer)
func _play_animation(anim_name: String) -> void:
	# Check if we have an AnimationPlayer child
	var anim_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player != null and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

## Stop current animation
func _stop_animation() -> void:
	var anim_player := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if anim_player != null:
		anim_player.stop()

## Convert motive name string to MotiveType enum
func _motive_name_to_type(motive_name: String) -> int:
	match motive_name.to_lower():
		"hunger": return Motive.MotiveType.HUNGER
		"energy": return Motive.MotiveType.ENERGY
		"social": return Motive.MotiveType.SOCIAL
		"hygiene": return Motive.MotiveType.HYGIENE
		"bladder": return Motive.MotiveType.BLADDER
		"fun", "entertainment": return Motive.MotiveType.FUN
		_: return -1

## Get current work progress (0.0 to 1.0 for current step)
func get_work_progress() -> float:
	if current_job == null:
		return 0.0
	var step := current_job.get_current_step()
	if step == null or step.duration <= 0:
		return 1.0
	return 1.0 - (work_timer / step.duration)

## Check if agent is currently working
func is_working() -> bool:
	return current_state == State.WORKING
