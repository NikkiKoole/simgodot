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

const COLLISION_RADIUS: float = 10.0

func _ready() -> void:
	# Initialize motive system
	motives = Motive.new("Player")
	motives.motive_depleted.connect(_on_motive_depleted)
	motives.critical_level.connect(_on_motive_critical)

	# Add motive bars UI
	var motive_bars := MotiveBars.new()
	motive_bars.set_motives(motives)
	add_child(motive_bars)

	# Enable drawing
	set_notify_transform(true)
	queue_redraw()

func _draw() -> void:
	# Draw collision circle outline
	draw_arc(Vector2.ZERO, COLLISION_RADIUS, 0, TAU, 32, Color(0.2, 0.9, 0.4), 2.0)

func _physics_process(delta: float) -> void:
	queue_redraw()

	# Update motives using game time
	var game_delta := delta
	if game_clock != null:
		game_delta = game_clock.get_game_delta(delta)
	motives.update(game_delta)

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

	# Push NPCs when colliding with them
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is CharacterBody2D and collider.has_method("receive_push"):
			var push_direction := collision.get_normal() * -1
			collider.receive_push(push_direction * 50.0)

func _on_motive_depleted(_motive_type: Motive.MotiveType) -> void:
	pass

func _on_motive_critical(_motive_type: Motive.MotiveType) -> void:
	pass

func set_game_clock(clock: GameClock) -> void:
	game_clock = clock
