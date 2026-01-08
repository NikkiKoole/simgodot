extends CharacterBody2D

## Movement speed in pixels per second
@export var max_speed: float = 200.0
## How quickly the player reaches max speed (higher = snappier)
@export var acceleration: float = 1600.0
## How quickly the player stops (higher = less slide)
@export var friction: float = 1200.0

# Motive system
var motives: Motive
var game_clock: GameClock

# Object interaction
var nearby_objects: Array[InteractableObject] = []
var current_object: InteractableObject = null
var is_using_object: bool = false
var object_use_timer: float = 0.0

func _ready() -> void:
	# Initialize motive system
	motives = Motive.new("Player")
	motives.motive_depleted.connect(_on_motive_depleted)
	motives.critical_level.connect(_on_motive_critical)

	# Add motive bars UI
	var motive_bars := MotiveBars.new()
	motive_bars.set_motives(motives)
	add_child(motive_bars)

func _physics_process(delta: float) -> void:
	# Update motives using game time
	var game_delta := delta
	if game_clock != null:
		game_delta = game_clock.get_game_delta(delta)
	motives.update(game_delta)

	# Handle object interaction
	if is_using_object:
		_use_object(delta, game_delta)
		return

	# Check for interaction input
	if Input.is_action_just_pressed("interact") and not nearby_objects.is_empty():
		_start_using_nearest_object()
		return

	# Get input direction
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# Normalize diagonal movement so it's not faster
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Apply acceleration or friction
	if input_dir != Vector2.ZERO:
		# Accelerate towards target velocity
		var target_velocity := input_dir * max_speed
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		# Apply friction when no input
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

func _start_using_nearest_object() -> void:
	# Find the closest non-occupied object
	var closest: InteractableObject = null
	var closest_dist := INF

	for obj in nearby_objects:
		if obj.is_occupied:
			continue
		var dist := global_position.distance_to(obj.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = obj

	if closest == null:
		return

	if not closest.start_use(self):
		return

	current_object = closest
	is_using_object = true
	object_use_timer = closest.use_duration  # This is in game minutes
	velocity = Vector2.ZERO
	print("[Player] Started using ", closest.get_object_name())

func _use_object(real_delta: float, game_delta: float) -> void:
	if current_object == null:
		is_using_object = false
		return

	# Fulfill motives while using object (using game time)
	for motive_type in current_object.advertisements:
		var rate: float = current_object.get_fulfillment_rate(motive_type)
		motives.fulfill(motive_type, rate * game_delta)

	# Timer counts down in game minutes
	object_use_timer -= game_delta

	# Allow canceling with movement or interaction
	if Input.is_action_just_pressed("interact") or _has_movement_input():
		_stop_using_object()
		return

	if object_use_timer <= 0.0:
		_stop_using_object()

func _stop_using_object() -> void:
	if current_object != null:
		print("[Player] Finished using ", current_object.get_object_name())
		current_object.stop_use(self)
		current_object = null
	is_using_object = false

func _has_movement_input() -> bool:
	return Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") or \
		   Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")

func _on_motive_depleted(motive_type: Motive.MotiveType) -> void:
	print("[Player] WARNING: ", Motive.get_motive_name(motive_type), " depleted! Find a ", _get_object_hint(motive_type), "!")

func _on_motive_critical(motive_type: Motive.MotiveType) -> void:
	print("[Player] ", Motive.get_motive_name(motive_type), " is getting low!")

func _get_object_hint(motive_type: Motive.MotiveType) -> String:
	match motive_type:
		Motive.MotiveType.HUNGER: return "fridge"
		Motive.MotiveType.ENERGY: return "bed"
		Motive.MotiveType.BLADDER: return "toilet"
		Motive.MotiveType.HYGIENE: return "shower"
		_: return "object"

func set_game_clock(clock: GameClock) -> void:
	game_clock = clock

# For interaction with objects via collision
func can_interact_with_object(_obj: InteractableObject) -> bool:
	return true

func on_object_in_range(obj: InteractableObject) -> void:
	if not nearby_objects.has(obj):
		nearby_objects.append(obj)
		print("[Player] ", obj.get_object_name(), " is nearby (press E to interact)")

func on_object_out_of_range(obj: InteractableObject) -> void:
	nearby_objects.erase(obj)
