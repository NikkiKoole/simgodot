class_name ItemContainer
extends Node2D

## Container for storing multiple ItemEntity instances
## Used for bins, chests, stockpiles, fridges, etc.
## Supports capacity limits and tag filtering

## Maximum number of items this container can hold
@export var capacity: int = 10

## Allowed item tags (empty = allow all items)
@export var allowed_tags: Array[String] = []

## Display name for the container
@export var container_name: String = ""

## Array of ItemEntity references stored in this container
var items: Array[ItemEntity] = []

signal item_added(item: ItemEntity)
signal item_removed(item: ItemEntity)
signal capacity_changed(current: int, max_capacity: int)

## Visual representation
@onready var sprite: ColorRect = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	if container_name.is_empty():
		container_name = name

## Check if an item tag is allowed in this container
func is_tag_allowed(tag: String) -> bool:
	# Empty allowed_tags means allow all
	if allowed_tags.is_empty():
		return true
	return tag in allowed_tags

## Check if container has room for more items
func has_space() -> bool:
	return items.size() < capacity

## Get current number of items
func get_item_count() -> int:
	return items.size()

## Add an item to the container
## Returns true if successful, false if container is full or tag not allowed
func add_item(item: ItemEntity) -> bool:
	if item == null:
		return false

	# Check if tag is allowed
	if not is_tag_allowed(item.item_tag):
		return false

	# Check capacity
	if not has_space():
		return false

	# Check if item is already in this container
	if item in items:
		return false

	items.append(item)
	item.place_in_container()

	# Reparent item to container if not already
	if item.get_parent() != self:
		if item.get_parent():
			item.get_parent().remove_child(item)
		add_child(item)
		item.position = Vector2.ZERO  # Hide inside container visually

	item_added.emit(item)
	capacity_changed.emit(items.size(), capacity)
	return true

## Remove an item from the container
## Returns true if successful, false if item not in container
func remove_item(item: ItemEntity) -> bool:
	if item == null:
		return false

	var index := items.find(item)
	if index == -1:
		return false

	items.remove_at(index)

	item_removed.emit(item)
	capacity_changed.emit(items.size(), capacity)
	return true

## Find an item by tag
## Returns the first matching item or null if not found
func find_item_by_tag(tag: String) -> ItemEntity:
	for item in items:
		if item.item_tag == tag:
			return item
	return null

## Find all items matching a tag
func find_all_items_by_tag(tag: String) -> Array[ItemEntity]:
	var matching: Array[ItemEntity] = []
	for item in items:
		if item.item_tag == tag:
			matching.append(item)
	return matching

## Get all unreserved items in this container
func get_available_items() -> Array[ItemEntity]:
	var available: Array[ItemEntity] = []
	for item in items:
		if not item.is_reserved():
			available.append(item)
	return available

## Get all unreserved items matching a specific tag
func get_available_items_by_tag(tag: String) -> Array[ItemEntity]:
	var available: Array[ItemEntity] = []
	for item in items:
		if item.item_tag == tag and not item.is_reserved():
			available.append(item)
	return available

## Check if container has an available (unreserved) item with the given tag
func has_available_item(tag: String) -> bool:
	for item in items:
		if item.item_tag == tag and not item.is_reserved():
			return true
	return false

## Get count of available items with a specific tag
func get_available_count(tag: String) -> int:
	var count := 0
	for item in items:
		if item.item_tag == tag and not item.is_reserved():
			count += 1
	return count

## Clear all items from the container (does not free them)
func clear() -> void:
	var items_to_remove := items.duplicate()
	for item in items_to_remove:
		remove_item(item)

## Get all items (including reserved ones)
func get_all_items() -> Array[ItemEntity]:
	return items.duplicate()

## Debug print
func debug_print() -> void:
	print("=== Container: ", container_name, " ===")
	print("  Capacity: ", items.size(), "/", capacity)
	print("  Allowed tags: ", allowed_tags if not allowed_tags.is_empty() else "All")
	print("  Items:")
	for item in items:
		var reserved_str := " [RESERVED]" if item.is_reserved() else ""
		print("    - ", item.item_tag, " (", item.item_id, ")", reserved_str)
