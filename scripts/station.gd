class_name Station
extends Node2D
## Smart station for agent interactions (stove, toilet, TV, etc.)
## Has input/output slots for items and an agent footprint for positioning

## Tag identifying this station type (e.g., "stove", "toilet", "counter")
@export var station_tag: String = ""

## Display name for the station
@export var station_name: String = ""

## Input slots where items are placed for processing
@export var input_slots: Array[Marker2D] = []

## Output slots where processed items appear
@export var output_slots: Array[Marker2D] = []

## Position where the agent stands when using this station
@export var agent_footprint: Marker2D = null

## Reference to the agent that has reserved this station (null if unreserved)
var reserved_by: Node = null

## Dictionary mapping slot index to ItemEntity placed there
var input_slot_items: Dictionary = {}
var output_slot_items: Dictionary = {}

signal reserved(by_agent: Node)
signal released()
signal item_placed(slot_index: int, item: ItemEntity, is_input: bool)
signal item_removed(slot_index: int, item: ItemEntity, is_input: bool)

## Visual representation
@onready var sprite: ColorRect = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	if station_name.is_empty():
		station_name = name

	# Auto-find child Marker2D nodes if not set via export
	_auto_discover_markers()

## Auto-discover Marker2D children for slots and footprint
func _auto_discover_markers() -> void:
	# Find input slots
	if input_slots.is_empty():
		for child in get_children():
			if child is Marker2D and child.name.begins_with("InputSlot"):
				input_slots.append(child)

	# Find output slots
	if output_slots.is_empty():
		for child in get_children():
			if child is Marker2D and child.name.begins_with("OutputSlot"):
				output_slots.append(child)

	# Find agent footprint
	if agent_footprint == null:
		for child in get_children():
			if child is Marker2D and child.name == "AgentFootprint":
				agent_footprint = child
				break

## Reserve this station for an agent
## Returns true if reservation successful, false if already reserved by another agent
func reserve(agent: Node) -> bool:
	if reserved_by != null and reserved_by != agent:
		return false
	reserved_by = agent
	reserved.emit(agent)
	return true

## Release reservation on this station
func release() -> void:
	reserved_by = null
	released.emit()

## Check if this station is available (not reserved)
func is_available() -> bool:
	return reserved_by == null

## Check if this station is reserved by a specific agent
func is_reserved_by(agent: Node) -> bool:
	return reserved_by == agent

## Get the global position where an agent should stand
func get_agent_position() -> Vector2:
	if agent_footprint != null:
		return agent_footprint.global_position
	# Default to station position if no footprint defined
	return global_position

## Get the number of input slots
func get_input_slot_count() -> int:
	return input_slots.size()

## Get the number of output slots
func get_output_slot_count() -> int:
	return output_slots.size()

## Get item currently in an input slot
## Returns null if slot is empty or index is invalid
func get_item_in_slot(slot_index: int, is_input: bool = true) -> ItemEntity:
	var slot_dict := input_slot_items if is_input else output_slot_items
	if slot_dict.has(slot_index):
		return slot_dict[slot_index]
	return null

## Get item in an input slot (convenience method)
func get_input_item(slot_index: int) -> ItemEntity:
	return get_item_in_slot(slot_index, true)

## Get item in an output slot (convenience method)
func get_output_item(slot_index: int) -> ItemEntity:
	return get_item_in_slot(slot_index, false)

## Place an item in a slot
## Returns true if successful, false if slot is invalid or occupied
func place_item_in_slot(item: ItemEntity, slot_index: int, is_input: bool = true) -> bool:
	if item == null:
		return false

	var slots := input_slots if is_input else output_slots
	var slot_dict := input_slot_items if is_input else output_slot_items

	# Check valid slot index
	if slot_index < 0 or slot_index >= slots.size():
		return false

	# Check if slot is already occupied
	if slot_dict.has(slot_index):
		return false

	# Place the item
	slot_dict[slot_index] = item
	item.place_in_slot()

	# Reparent and position item at slot
	var slot_marker := slots[slot_index]
	if item.get_parent() != self:
		if item.get_parent():
			item.get_parent().remove_child(item)
		add_child(item)
	item.position = slot_marker.position

	item_placed.emit(slot_index, item, is_input)
	return true

## Place an item in an input slot (convenience method)
func place_input_item(item: ItemEntity, slot_index: int) -> bool:
	return place_item_in_slot(item, slot_index, true)

## Place an item in an output slot (convenience method)
func place_output_item(item: ItemEntity, slot_index: int) -> bool:
	return place_item_in_slot(item, slot_index, false)

## Remove an item from a slot
## Returns the removed item or null if slot was empty
func remove_item_from_slot(slot_index: int, is_input: bool = true) -> ItemEntity:
	var slot_dict := input_slot_items if is_input else output_slot_items

	if not slot_dict.has(slot_index):
		return null

	var item: ItemEntity = slot_dict[slot_index]
	slot_dict.erase(slot_index)
	item_removed.emit(slot_index, item, is_input)
	return item

## Remove an item from an input slot (convenience method)
func remove_input_item(slot_index: int) -> ItemEntity:
	return remove_item_from_slot(slot_index, true)

## Remove an item from an output slot (convenience method)
func remove_output_item(slot_index: int) -> ItemEntity:
	return remove_item_from_slot(slot_index, false)

## Find the first empty input slot
## Returns -1 if all slots are occupied
func find_empty_input_slot() -> int:
	for i in range(input_slots.size()):
		if not input_slot_items.has(i):
			return i
	return -1

## Find the first empty output slot
## Returns -1 if all slots are occupied
func find_empty_output_slot() -> int:
	for i in range(output_slots.size()):
		if not output_slot_items.has(i):
			return i
	return -1

## Check if station has any items in input slots
func has_input_items() -> bool:
	return not input_slot_items.is_empty()

## Check if station has any items in output slots
func has_output_items() -> bool:
	return not output_slot_items.is_empty()

## Get all items currently in input slots
func get_all_input_items() -> Array[ItemEntity]:
	var items: Array[ItemEntity] = []
	for item in input_slot_items.values():
		items.append(item)
	return items

## Get all items currently in output slots
func get_all_output_items() -> Array[ItemEntity]:
	var items: Array[ItemEntity] = []
	for item in output_slot_items.values():
		items.append(item)
	return items

## Clear all items from slots (does not free them)
func clear_all_slots() -> void:
	for slot_index in input_slot_items.keys():
		remove_item_from_slot(slot_index, true)
	for slot_index in output_slot_items.keys():
		remove_item_from_slot(slot_index, false)

## Get the position of a specific input slot
func get_input_slot_position(slot_index: int) -> Vector2:
	if slot_index >= 0 and slot_index < input_slots.size():
		return input_slots[slot_index].global_position
	return global_position

## Get the position of a specific output slot
func get_output_slot_position(slot_index: int) -> Vector2:
	if slot_index >= 0 and slot_index < output_slots.size():
		return output_slots[slot_index].global_position
	return global_position

## Debug print
func debug_print() -> void:
	print("=== Station: ", station_name, " (", station_tag, ") ===")
	print("  Reserved: ", "Yes by " + str(reserved_by) if reserved_by else "No")
	print("  Agent footprint: ", "Set" if agent_footprint else "Not set")
	print("  Input slots: ", input_slots.size())
	for i in range(input_slots.size()):
		var item := get_input_item(i)
		if item:
			print("    [", i, "] ", item.item_tag)
		else:
			print("    [", i, "] Empty")
	print("  Output slots: ", output_slots.size())
	for i in range(output_slots.size()):
		var item := get_output_item(i)
		if item:
			print("    [", i, "] ", item.item_tag)
		else:
			print("    [", i, "] Empty")
