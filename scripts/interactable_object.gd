class_name InteractableObject
extends Area2D

## Base class for objects that can fulfill motives
## Objects "advertise" what they can provide, like in The Sims

## What this object advertises (motive type -> fulfillment amount per second)
@export var advertisements: Dictionary = {}

## How long it takes to use this object (seconds)
@export var use_duration: float = 3.0

## Whether the object is currently being used
var is_occupied: bool = false
var current_user: Node2D = null

## Visual representation (ColorRect named Sprite2D for compatibility)
@onready var sprite: ColorRect = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

## Color when in use
const IN_USE_COLOR := Color(0.3, 0.9, 0.3)  # Bright green
var original_color: Color

signal interaction_started(user: Node2D)
signal interaction_finished(user: Node2D)

func _ready() -> void:
	# Store original color for later
	original_color = sprite.color

	# Connect area signals for collision detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Check if the body can interact (has motives)
	if body.has_method("can_interact_with_object") and body.can_interact_with_object(self):
		body.on_object_in_range(self)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("on_object_out_of_range"):
		body.on_object_out_of_range(self)

## Get the score for how much an entity wants to use this object
## Based on their current motive levels
func get_advertisement_score(motives: Motive) -> float:
	var total_score := 0.0

	for motive_type in advertisements:
		var fulfillment: float = advertisements[motive_type]
		var current_value: float = motives.get_value(motive_type)

		# Score is higher when the motive is lower (more urgent need)
		# Using a curve: score increases dramatically as need becomes critical
		var urgency := (Motive.MAX_VALUE - current_value) / (Motive.MAX_VALUE - Motive.MIN_VALUE)
		# Apply exponential curve for more dramatic urgency scaling
		var urgency_multiplier := pow(urgency, 2) * 2.0

		total_score += fulfillment * urgency_multiplier

	return total_score

## Check if this object can fulfill a specific motive type
func can_fulfill(motive_type: Motive.MotiveType) -> bool:
	return motive_type in advertisements and advertisements[motive_type] > 0

## Get how much this object fulfills a specific motive (per second of use)
func get_fulfillment_rate(motive_type: Motive.MotiveType) -> float:
	return advertisements.get(motive_type, 0.0)

## Start using this object
func start_use(user: Node2D) -> bool:
	if is_occupied:
		return false

	is_occupied = true
	current_user = user
	sprite.color = IN_USE_COLOR
	interaction_started.emit(user)
	return true

## Stop using this object
func stop_use(user: Node2D) -> void:
	if current_user == user:
		is_occupied = false
		current_user = null
		sprite.color = original_color
		interaction_finished.emit(user)

## Get the interaction position (where entity should stand/sit)
func get_interaction_position() -> Vector2:
	return global_position

## Get object name for debugging
func get_object_name() -> String:
	return name
