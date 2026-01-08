extends CharacterBody2D

## Movement speed in pixels per second
@export var max_speed: float = 200.0
## How quickly the player reaches max speed (higher = snappier)
@export var acceleration: float = 1600.0
## How quickly the player stops (higher = less slide)
@export var friction: float = 1200.0

func _physics_process(delta: float) -> void:
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
