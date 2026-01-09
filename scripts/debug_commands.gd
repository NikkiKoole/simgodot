## DebugCommands Singleton
## Provides a testable API layer for all debug operations
## All debug functionality flows through this singleton for headless testability
## Access via the DebugCommands autoload (do not use class_name to avoid conflicts)
extends Node

# Signals for UI updates and testing
signal entity_selected(entity: Node)
signal entity_deselected()
signal item_spawned(item: ItemEntity)
signal station_spawned(station: Station)
signal station_removed(station: Station)
signal npc_spawned(npc: Node)
signal motive_changed(npc: Node, motive_name: String, old_value: float, new_value: float)

# Scenes for spawning entities
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")
const NPCScene = preload("res://scenes/npc.tscn")

# Grid size for snapping station positions (in pixels)
const GRID_SIZE: int = 32

# Currently selected entity
var selected_entity: Node = null

# Track runtime-spawned stations for cleanup
var runtime_stations: Array[Station] = []

# Track runtime-spawned NPCs for cleanup
var runtime_npcs: Array[Node] = []


func _ready() -> void:
	pass


## Select an entity for inspection
## Emits entity_selected signal with the entity
func select_entity(entity: Node) -> void:
	if selected_entity != entity:
		selected_entity = entity
		if entity != null:
			entity_selected.emit(entity)
		else:
			entity_deselected.emit()


## Deselect the current entity
func deselect_entity() -> void:
	if selected_entity != null:
		selected_entity = null
		entity_deselected.emit()


## Get inspection data for any entity
## Returns a Dictionary with entity-specific properties
func get_inspection_data(entity: Node) -> Dictionary:
	if entity == null:
		return {}

	# Check entity type and return appropriate data
	if entity.has_method("get_all_input_items"):
		# This is a Station
		return _get_station_inspection_data(entity)
	elif entity.get("motives") != null:
		# This is an NPC (has motives property)
		return _get_npc_inspection_data(entity)
	elif entity.get("item_tag") != null:
		# This is an ItemEntity
		return _get_item_inspection_data(entity)
	elif entity.get("items") != null and entity.has_method("add_item"):
		# This is a Container
		return _get_container_inspection_data(entity)

	# Unknown entity type
	return {"type": "unknown"}


## Get inspection data for an NPC
func _get_npc_inspection_data(npc: Node) -> Dictionary:
	var data: Dictionary = {
		"type": "npc",
		"state": _get_npc_state_name(npc),
		"motives": _get_npc_motives(npc),
		"held_item": _get_npc_held_item(npc),
		"current_job": _get_npc_current_job(npc)
	}
	return data


## Get the state name for an NPC
func _get_npc_state_name(npc: Node) -> String:
	if npc.get("current_state") != null:
		var state: int = npc.current_state
		# Match NPC.State enum
		match state:
			0: return "IDLE"
			1: return "WALKING"
			2: return "WAITING"
			3: return "USING_OBJECT"
			4: return "HAULING"
			5: return "WORKING"
			_: return "UNKNOWN"
	return "UNKNOWN"


## Get NPC motives as a dictionary
func _get_npc_motives(npc: Node) -> Dictionary:
	var motives_dict: Dictionary = {}
	if npc.get("motives") != null:
		var motives: Motive = npc.motives
		if motives != null:
			# Get all motive values using Motive.MotiveType enum
			motives_dict["hunger"] = motives.get_value(Motive.MotiveType.HUNGER)
			motives_dict["energy"] = motives.get_value(Motive.MotiveType.ENERGY)
			motives_dict["bladder"] = motives.get_value(Motive.MotiveType.BLADDER)
			motives_dict["hygiene"] = motives.get_value(Motive.MotiveType.HYGIENE)
			motives_dict["fun"] = motives.get_value(Motive.MotiveType.FUN)
	return motives_dict


## Get the items held by an NPC (returns first item tag or empty string)
func _get_npc_held_item(npc: Node) -> String:
	if npc.get("held_items") != null and npc.held_items.size() > 0:
		var first_item: Node = npc.held_items[0]
		if is_instance_valid(first_item):
			return first_item.item_tag
	return ""


## Get the current job info for an NPC
func _get_npc_current_job(npc: Node) -> Dictionary:
	if npc.get("current_job") != null and is_instance_valid(npc.current_job):
		var job: Node = npc.current_job
		var job_data: Dictionary = {
			"recipe_name": "",
			"step_index": job.current_step_index if job.get("current_step_index") != null else 0,
			"state": _get_job_state_name(job)
		}
		if job.get("recipe") != null and is_instance_valid(job.recipe):
			job_data["recipe_name"] = job.recipe.recipe_name if job.recipe.get("recipe_name") != null else ""
		return job_data
	return {}


## Get job state name
func _get_job_state_name(job: Node) -> String:
	if job.get("state") != null:
		var state: int = job.state
		match state:
			0: return "POSTED"
			1: return "CLAIMED"
			2: return "IN_PROGRESS"
			3: return "INTERRUPTED"
			4: return "COMPLETED"
			5: return "FAILED"
			_: return "UNKNOWN"
	return "UNKNOWN"


## Get inspection data for a Station
func _get_station_inspection_data(station: Node) -> Dictionary:
	var data: Dictionary = {
		"type": "station",
		"tags": _get_station_tags(station),
		"slot_contents": _get_station_slot_contents(station),
		"current_user": _get_station_current_user(station)
	}
	return data


## Get station tags
func _get_station_tags(station: Node) -> Array:
	var tags: Array = []
	if station.get("station_tag") != null and station.station_tag != "":
		tags.append(station.station_tag)
	return tags


## Get contents of station slots
func _get_station_slot_contents(station: Node) -> Dictionary:
	var contents: Dictionary = {
		"input_slots": [],
		"output_slots": []
	}

	# Get input slot contents
	if station.has_method("get_all_input_items"):
		var input_items: Array = station.get_all_input_items()
		for item in input_items:
			if is_instance_valid(item):
				contents["input_slots"].append(item.item_tag)
			else:
				contents["input_slots"].append("")

	# Get output slot contents
	if station.has_method("get_all_output_items"):
		var output_items: Array = station.get_all_output_items()
		for item in output_items:
			if is_instance_valid(item):
				contents["output_slots"].append(item.item_tag)
			else:
				contents["output_slots"].append("")

	return contents


## Get the current user of a station
func _get_station_current_user(station: Node) -> String:
	if station.get("reserved_by") != null and is_instance_valid(station.reserved_by):
		if station.reserved_by.get("name") != null:
			return station.reserved_by.name
		return "Unknown NPC"
	return ""


## Get inspection data for an ItemEntity
func _get_item_inspection_data(item: Node) -> Dictionary:
	var data: Dictionary = {
		"type": "item",
		"item_tag": item.item_tag if item.get("item_tag") != null else "",
		"location_state": _get_item_location_name(item),
		"container": _get_item_container(item)
	}
	return data


## Get item location name
func _get_item_location_name(item: Node) -> String:
	if item.get("location") != null:
		var location: int = item.location
		match location:
			0: return "IN_CONTAINER"
			1: return "IN_HAND"
			2: return "IN_SLOT"
			3: return "ON_GROUND"
			_: return "UNKNOWN"
	return "UNKNOWN"


## Get the container/holder of an item
func _get_item_container(item: Node) -> String:
	# Check if item has a parent that could be a container
	var parent: Node = item.get_parent()
	if is_instance_valid(parent):
		if parent.get("container_name") != null and parent.container_name != "":
			return parent.container_name
		if parent.get("station_name") != null and parent.station_name != "":
			return parent.station_name
		if parent.get("name") != null:
			return parent.name
	return ""


## Get inspection data for a Container
func _get_container_inspection_data(container: Node) -> Dictionary:
	var items_list: Array = []
	if container.get("items") != null:
		for item in container.items:
			if is_instance_valid(item):
				items_list.append(item.item_tag)

	var data: Dictionary = {
		"type": "container",
		"name": container.container_name if container.get("container_name") != null else "",
		"tags": container.allowed_tags if container.get("allowed_tags") != null else [],
		"items": items_list,
		"capacity": container.capacity if container.get("capacity") != null else 0,
		"used": items_list.size()
	}
	return data


# =============================================================================
# ITEM SPAWNING (US-002)
# =============================================================================

## Spawn an item with the given tag at a position or into a target (Container/Station)
## position_or_target can be:
##   - Vector2: spawns item ON_GROUND at that world position
##   - ItemContainer: spawns item IN_CONTAINER
##   - Station: spawns item in the first available input slot
## Returns the spawned ItemEntity, or null if spawning failed
func spawn_item(tag: String, position_or_target: Variant) -> ItemEntity:
	if tag.is_empty():
		push_error("DebugCommands.spawn_item: tag cannot be empty")
		return null

	# Create the item instance
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = tag

	# Handle based on target type
	if position_or_target is Vector2:
		return _spawn_item_on_ground(item, position_or_target)
	elif position_or_target is ItemContainer:
		return _spawn_item_in_container(item, position_or_target)
	elif position_or_target is Station:
		return _spawn_item_at_station(item, position_or_target)
	else:
		push_error("DebugCommands.spawn_item: position_or_target must be Vector2, ItemContainer, or Station")
		item.queue_free()
		return null


## Spawn an item on the ground at a world position
func _spawn_item_on_ground(item: ItemEntity, world_position: Vector2) -> ItemEntity:
	# Add to scene tree - find Level node or use root
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		item.queue_free()
		return null

	level.add_child(item)
	item.global_position = world_position
	item.set_location(ItemEntity.ItemLocation.ON_GROUND)

	item_spawned.emit(item)
	return item


## Spawn an item inside a container
func _spawn_item_in_container(item: ItemEntity, container: ItemContainer) -> ItemEntity:
	# Check if container has space and allows this tag
	if not container.has_space():
		push_error("DebugCommands.spawn_item: Container is full")
		item.queue_free()
		return null

	if not container.is_tag_allowed(item.item_tag):
		push_error("DebugCommands.spawn_item: Container does not allow tag '" + item.item_tag + "'")
		item.queue_free()
		return null

	# Add item to scene tree first (container.add_item will reparent it)
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		item.queue_free()
		return null

	level.add_child(item)

	# Add to container (this sets location to IN_CONTAINER and reparents)
	var success: bool = container.add_item(item)
	if not success:
		push_error("DebugCommands.spawn_item: Failed to add item to container")
		item.queue_free()
		return null

	item_spawned.emit(item)
	return item


## Spawn an item at a station's first available input slot
func _spawn_item_at_station(item: ItemEntity, station: Station) -> ItemEntity:
	# Find first empty input slot
	var slot_index: int = station.find_empty_input_slot()
	if slot_index == -1:
		push_error("DebugCommands.spawn_item: Station has no empty input slots")
		item.queue_free()
		return null

	# Add item to scene tree first (station.place_input_item will reparent it)
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		item.queue_free()
		return null

	level.add_child(item)

	# Place in station slot (this sets location to IN_SLOT and reparents)
	var success: bool = station.place_input_item(item, slot_index)
	if not success:
		push_error("DebugCommands.spawn_item: Failed to place item in station slot")
		item.queue_free()
		return null

	item_spawned.emit(item)
	return item


## Get the Level node for adding spawned entities
## Returns the first node in "level" group, or falls back to current scene root
func _get_level_node() -> Node:
	var levels: Array[Node] = get_tree().get_nodes_in_group("level")
	if levels.size() > 0:
		return levels[0]

	# Fallback to current scene root
	var root: Node = get_tree().current_scene
	return root


# =============================================================================
# STATION SPAWNING (US-003)
# =============================================================================

## Valid station types that can be spawned
const VALID_STATION_TYPES: Array[String] = [
	"counter", "stove", "sink", "couch", "fridge", "toilet", "tv", "generic"
]

## Station type to color mapping for visual differentiation
const STATION_COLORS: Dictionary = {
	"counter": Color(0.6, 0.5, 0.4, 1.0),   # Brown
	"stove": Color(0.7, 0.3, 0.2, 1.0),     # Red-brown
	"sink": Color(0.3, 0.5, 0.7, 1.0),      # Blue
	"couch": Color(0.5, 0.4, 0.6, 1.0),     # Purple
	"fridge": Color(0.8, 0.8, 0.8, 1.0),    # Light gray
	"toilet": Color(0.9, 0.9, 0.95, 1.0),   # White
	"tv": Color(0.2, 0.2, 0.3, 1.0),        # Dark gray
	"generic": Color(0.3, 0.5, 0.6, 1.0),   # Default teal
}


## Spawn a station of the given type at a position
## type: One of VALID_STATION_TYPES (counter, stove, sink, couch, fridge, toilet, tv, generic)
## position: World position (will be snapped to grid)
## tags: Optional array of additional tags to apply to the station
## Returns the spawned Station, or null if spawning failed
func spawn_station(type: String, position: Vector2, tags: Array = []) -> Station:
	# Validate station type
	if type not in VALID_STATION_TYPES:
		push_error("DebugCommands.spawn_station: Invalid station type '" + type + "'. Valid types: " + str(VALID_STATION_TYPES))
		return null

	# Create the station instance
	var station: Station = StationScene.instantiate()

	# Set station properties
	station.station_tag = type
	station.station_name = type.capitalize() + " (Debug)"

	# Apply color based on type
	if STATION_COLORS.has(type):
		# Color will be applied after adding to scene tree (need access to Sprite2D child)
		pass

	# Snap position to grid
	var snapped_position: Vector2 = snap_to_grid(position)

	# Add to scene tree
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_station: Could not find Level node")
		station.queue_free()
		return null

	level.add_child(station)
	station.global_position = snapped_position

	# Apply color to the sprite
	_apply_station_color(station, type)

	# Track as runtime-spawned station
	runtime_stations.append(station)

	# Emit signal
	station_spawned.emit(station)

	return station


## Remove a runtime-spawned station
## Returns true if station was removed, false if it wasn't a runtime station
func remove_station(station: Station) -> bool:
	if station == null:
		push_error("DebugCommands.remove_station: station is null")
		return false

	if not is_instance_valid(station):
		push_error("DebugCommands.remove_station: station is not a valid instance")
		return false

	# Check if this is a runtime-spawned station
	var index: int = runtime_stations.find(station)
	if index == -1:
		push_error("DebugCommands.remove_station: station was not spawned via DebugCommands")
		return false

	# Remove from tracking array
	runtime_stations.remove_at(index)

	# Clear selection if this station was selected
	if selected_entity == station:
		deselect_entity()

	# Emit signal before freeing
	station_removed.emit(station)

	# Free the station
	station.queue_free()

	return true


## Snap a position to the grid
func snap_to_grid(position: Vector2, grid_size: int = GRID_SIZE) -> Vector2:
	return Vector2(
		round(position.x / grid_size) * grid_size,
		round(position.y / grid_size) * grid_size
	)


## Apply the appropriate color to a station's sprite based on its type
func _apply_station_color(station: Station, type: String) -> void:
	if station.has_node("Sprite2D"):
		var sprite: ColorRect = station.get_node("Sprite2D")
		if sprite is ColorRect and STATION_COLORS.has(type):
			sprite.color = STATION_COLORS[type]


## Check if a station type is valid
func is_valid_station_type(type: String) -> bool:
	return type in VALID_STATION_TYPES


## Get all valid station types
func get_valid_station_types() -> Array[String]:
	return VALID_STATION_TYPES.duplicate()


## Get all runtime-spawned stations
func get_runtime_stations() -> Array[Station]:
	# Clean up any freed stations from the list
	var valid_stations: Array[Station] = []
	for station in runtime_stations:
		if is_instance_valid(station):
			valid_stations.append(station)
	runtime_stations = valid_stations
	return runtime_stations.duplicate()


## Remove all runtime-spawned stations
func clear_runtime_stations() -> void:
	# Iterate in reverse to safely remove while iterating
	for i in range(runtime_stations.size() - 1, -1, -1):
		var station: Station = runtime_stations[i]
		if is_instance_valid(station):
			station_removed.emit(station)
			station.queue_free()
	runtime_stations.clear()


# =============================================================================
# NPC SPAWNING AND MOTIVE ADJUSTMENT (US-004)
# =============================================================================

## Valid motive names that can be adjusted
const VALID_MOTIVE_NAMES: Array[String] = [
	"hunger", "energy", "bladder", "hygiene", "fun"
]

## Motive name to MotiveType enum mapping
const MOTIVE_NAME_TO_TYPE: Dictionary = {
	"hunger": Motive.MotiveType.HUNGER,
	"energy": Motive.MotiveType.ENERGY,
	"bladder": Motive.MotiveType.BLADDER,
	"hygiene": Motive.MotiveType.HYGIENE,
	"fun": Motive.MotiveType.FUN
}


## Spawn an NPC at a position with optional initial motives
## position: World position for the NPC
## motives_dict: Optional dictionary of motive values {motive_name: value}
##               If not provided, defaults to full motives (100 for all)
## Returns the spawned NPC, or null if spawning failed
func spawn_npc(position: Vector2, motives_dict: Dictionary = {}) -> Node:
	# Create the NPC instance
	var npc: Node = NPCScene.instantiate()

	# Add to scene tree
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_npc: Could not find Level node")
		npc.queue_free()
		return null

	level.add_child(npc)
	npc.global_position = position

	# Wait for NPC to initialize (motives are created in _ready)
	# We need to set motives after the NPC is in the tree
	if npc.get("motives") != null and npc.motives != null:
		# Set motives - either from provided dict or default to full
		if motives_dict.is_empty():
			# Default to full motives (100 for all)
			_set_all_motives_to_value(npc, 100.0)
		else:
			# Set provided motives, default others to 100
			_set_all_motives_to_value(npc, 100.0)
			for motive_name in motives_dict:
				var value: float = motives_dict[motive_name]
				_set_motive_internal(npc, motive_name, value)

	# Track as runtime-spawned NPC
	runtime_npcs.append(npc)

	# Emit signal
	npc_spawned.emit(npc)

	return npc


## Set a single motive for an NPC
## npc: The NPC node
## motive_name: Name of the motive (hunger, energy, bladder, hygiene, fun)
## value: New value for the motive (will be clamped to 0-100 range, mapped to -100 to +100 internal)
## Returns true if successful, false otherwise
func set_npc_motive(npc: Node, motive_name: String, value: float) -> bool:
	if npc == null:
		push_error("DebugCommands.set_npc_motive: npc is null")
		return false

	if not is_instance_valid(npc):
		push_error("DebugCommands.set_npc_motive: npc is not a valid instance")
		return false

	if npc.get("motives") == null or npc.motives == null:
		push_error("DebugCommands.set_npc_motive: npc does not have motives")
		return false

	var lower_name: String = motive_name.to_lower()
	if lower_name not in VALID_MOTIVE_NAMES:
		push_error("DebugCommands.set_npc_motive: Invalid motive name '" + motive_name + "'. Valid names: " + str(VALID_MOTIVE_NAMES))
		return false

	return _set_motive_internal(npc, lower_name, value)


## Set multiple motives for an NPC at once
## npc: The NPC node
## motives_dict: Dictionary of {motive_name: value} pairs
## Returns true if all motives were set successfully, false if any failed
func set_npc_motives(npc: Node, motives_dict: Dictionary) -> bool:
	if npc == null:
		push_error("DebugCommands.set_npc_motives: npc is null")
		return false

	if not is_instance_valid(npc):
		push_error("DebugCommands.set_npc_motives: npc is not a valid instance")
		return false

	if npc.get("motives") == null or npc.motives == null:
		push_error("DebugCommands.set_npc_motives: npc does not have motives")
		return false

	var all_success: bool = true
	for motive_name in motives_dict:
		var value: float = motives_dict[motive_name]
		if not _set_motive_internal(npc, motive_name.to_lower(), value):
			all_success = false

	return all_success


## Internal helper to set a motive value and emit signal
## value is in 0-100 range (user-friendly), converted to -100 to +100 internal range
func _set_motive_internal(npc: Node, motive_name: String, value: float) -> bool:
	if not MOTIVE_NAME_TO_TYPE.has(motive_name):
		push_error("DebugCommands._set_motive_internal: Unknown motive '" + motive_name + "'")
		return false

	var motive_type: Motive.MotiveType = MOTIVE_NAME_TO_TYPE[motive_name]
	var motives: Motive = npc.motives

	# Clamp value to 0-100 range and convert to internal -100 to +100 range
	# User provides 0-100 where 0 = critical need, 100 = fully satisfied
	# Internal uses -100 to +100 where -100 = critical, +100 = satisfied
	var clamped_value: float = clampf(value, 0.0, 100.0)
	var internal_value: float = (clamped_value * 2.0) - 100.0  # 0->-100, 50->0, 100->+100

	# Get old value for signal (convert back to 0-100 range for consistency)
	var old_internal: float = motives.get_value(motive_type)
	var old_value: float = (old_internal + 100.0) / 2.0  # Convert -100..+100 to 0..100

	# Set the new value directly in the motives dictionary
	motives.values[motive_type] = internal_value

	# Emit signal with 0-100 range values
	motive_changed.emit(npc, motive_name, old_value, clamped_value)

	return true


## Internal helper to set all motives to a specific value
func _set_all_motives_to_value(npc: Node, value: float) -> void:
	if npc.get("motives") == null or npc.motives == null:
		return

	for motive_name in VALID_MOTIVE_NAMES:
		_set_motive_internal(npc, motive_name, value)


## Get all runtime-spawned NPCs
func get_runtime_npcs() -> Array[Node]:
	# Clean up any freed NPCs from the list
	var valid_npcs: Array[Node] = []
	for npc in runtime_npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)
	runtime_npcs = valid_npcs
	return runtime_npcs.duplicate()


## Remove all runtime-spawned NPCs
func clear_runtime_npcs() -> void:
	# Iterate in reverse to safely remove while iterating
	for i in range(runtime_npcs.size() - 1, -1, -1):
		var npc: Node = runtime_npcs[i]
		if is_instance_valid(npc):
			npc.queue_free()
	runtime_npcs.clear()


## Get motive value for an NPC in user-friendly 0-100 range
## Returns -1 if invalid
func get_npc_motive(npc: Node, motive_name: String) -> float:
	if npc == null or not is_instance_valid(npc):
		return -1.0

	if npc.get("motives") == null or npc.motives == null:
		return -1.0

	var lower_name: String = motive_name.to_lower()
	if not MOTIVE_NAME_TO_TYPE.has(lower_name):
		return -1.0

	var motive_type: Motive.MotiveType = MOTIVE_NAME_TO_TYPE[lower_name]
	var internal_value: float = npc.motives.get_value(motive_type)

	# Convert from internal -100..+100 to user-friendly 0..100
	return (internal_value + 100.0) / 2.0
