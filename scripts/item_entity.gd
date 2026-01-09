class_name ItemEntity
extends Node2D

## Physical item entity that exists in the game world
## Items can be picked up, placed in containers, held by agents, or dropped on the ground

## Possible states an item can be in
enum ItemState {
	RAW,
	PREPPED,
	COOKED,
	DIRTY,
	BROKEN
}

## Where the item is currently located
enum ItemLocation {
	IN_CONTAINER,
	IN_HAND,
	IN_SLOT,
	ON_GROUND
}

## Unique identifier for this item instance
@export var item_id: String = ""

## Tag for item type matching (e.g., "raw_food", "toilet_paper")
@export var item_tag: String = ""

## Current state of the item
@export var state: ItemState = ItemState.RAW

## Current location type
@export var location: ItemLocation = ItemLocation.ON_GROUND

## Reference to the agent that has reserved this item (null if unreserved)
var reserved_by: Node = null

## Visual representation
@onready var sprite: ColorRect = $Sprite2D if has_node("Sprite2D") else null

signal state_changed(new_state: ItemState)
signal location_changed(new_location: ItemLocation)
signal reserved(by_agent: Node)
signal released()

func _ready() -> void:
	# Generate unique ID if not set
	if item_id.is_empty():
		item_id = str(get_instance_id())

## Reserve this item for an agent
func reserve_item(agent: Node) -> bool:
	if reserved_by != null and reserved_by != agent:
		return false
	reserved_by = agent
	reserved.emit(agent)
	return true

## Release reservation on this item
func release_item() -> void:
	reserved_by = null
	released.emit()

## Check if this item is reserved
func is_reserved() -> bool:
	return reserved_by != null

## Check if this item is reserved by a specific agent
func is_reserved_by(agent: Node) -> bool:
	return reserved_by == agent

## Set the item state and emit signal
func set_state(new_state: ItemState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)

## Set the item location and emit signal
func set_location(new_location: ItemLocation) -> void:
	if location != new_location:
		location = new_location
		location_changed.emit(new_location)

## Drop this item at the current position
func drop() -> void:
	set_location(ItemLocation.ON_GROUND)
	# Clear parent if held
	if get_parent() and get_parent().has_method("remove_held_item"):
		get_parent().remove_held_item(self)

## Pick up this item (called when agent takes it)
func pick_up(agent: Node) -> void:
	set_location(ItemLocation.IN_HAND)
	reserved_by = agent

## Place in a container
func place_in_container() -> void:
	set_location(ItemLocation.IN_CONTAINER)

## Place in a slot (at a station)
func place_in_slot() -> void:
	set_location(ItemLocation.IN_SLOT)

## Get human-readable state name
static func get_state_name(item_state: ItemState) -> String:
	match item_state:
		ItemState.RAW: return "Raw"
		ItemState.PREPPED: return "Prepped"
		ItemState.COOKED: return "Cooked"
		ItemState.DIRTY: return "Dirty"
		ItemState.BROKEN: return "Broken"
		_: return "Unknown"

## Get human-readable location name
static func get_location_name(item_location: ItemLocation) -> String:
	match item_location:
		ItemLocation.IN_CONTAINER: return "In Container"
		ItemLocation.IN_HAND: return "In Hand"
		ItemLocation.IN_SLOT: return "In Slot"
		ItemLocation.ON_GROUND: return "On Ground"
		_: return "Unknown"

## Debug print
func debug_print() -> void:
	print("=== Item: ", item_tag, " (", item_id, ") ===")
	print("  State: ", get_state_name(state))
	print("  Location: ", get_location_name(location))
	print("  Reserved: ", "Yes by " + str(reserved_by) if reserved_by else "No")
