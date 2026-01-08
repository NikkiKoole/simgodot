extends Camera2D

## How quickly the camera catches up to the player (higher = faster)
@export var lerp_speed: float = 5.0
## Dead zone size - camera won't move until player exits this area
@export var dead_zone: Vector2 = Vector2(150, 100)

var target_position: Vector2

func _ready() -> void:
	# Start at the player's position
	target_position = get_parent().global_position
	global_position = target_position

func _process(delta: float) -> void:
	var player_pos: Vector2 = get_parent().global_position

	# Calculate offset from current target to player
	var offset := player_pos - target_position

	# Only update target if player is outside the dead zone
	if abs(offset.x) > dead_zone.x:
		target_position.x = player_pos.x - sign(offset.x) * dead_zone.x
	if abs(offset.y) > dead_zone.y:
		target_position.y = player_pos.y - sign(offset.y) * dead_zone.y

	# Smoothly lerp camera to target position
	global_position = global_position.lerp(target_position, lerp_speed * delta)
