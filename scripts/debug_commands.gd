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
signal wall_changed(grid_position: Vector2i, is_wall: bool)
signal container_spawned(container: ItemContainer)

# Grid size for snapping station positions (in pixels)
const GRID_SIZE: int = 32

# Currently selected entity
var selected_entity: Node = null


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
		# Match NPC.State enum (USING_OBJECT removed)
		match state:
			0: return "IDLE"
			1: return "WALKING"
			2: return "WAITING"
			3: return "HAULING"
			4: return "WORKING"
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
		var job = npc.current_job
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
func _get_job_state_name(job) -> String:
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

	# Handle based on target type
	if position_or_target is Vector2:
		return _spawn_item_on_ground(tag, position_or_target)
	elif position_or_target is ItemContainer:
		return _spawn_item_in_container(tag, position_or_target)
	elif position_or_target is Station:
		return _spawn_item_at_station(tag, position_or_target)
	else:
		push_error("DebugCommands.spawn_item: position_or_target must be Vector2, ItemContainer, or Station")
		return null


## Spawn an item on the ground at a world position
func _spawn_item_on_ground(tag: String, world_position: Vector2) -> ItemEntity:
	# Add to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		return null

	# Use level's unified API
	var item: ItemEntity = level.add_item(world_position, tag)
	if item == null:
		push_error("DebugCommands.spawn_item: level.add_item returned null")
		return null

	item_spawned.emit(item)
	return item


## Spawn an item inside a container
func _spawn_item_in_container(tag: String, container: ItemContainer) -> ItemEntity:
	# Check if container has space and allows this tag
	if not container.has_space():
		push_error("DebugCommands.spawn_item: Container is full")
		return null

	if not container.is_tag_allowed(tag):
		push_error("DebugCommands.spawn_item: Container does not allow tag '" + tag + "'")
		return null

	# Add item to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		return null

	# Use level's unified API to create item on ground first
	var item: ItemEntity = level.add_item(container.global_position, tag)
	if item == null:
		push_error("DebugCommands.spawn_item: level.add_item returned null")
		return null

	# Add to container (this sets location to IN_CONTAINER and reparents)
	var success: bool = container.add_item(item)
	if not success:
		push_error("DebugCommands.spawn_item: Failed to add item to container")
		level.remove_item(item)
		return null

	item_spawned.emit(item)
	return item


## Spawn an item at a station's first available input slot
func _spawn_item_at_station(tag: String, station: Station) -> ItemEntity:
	# Find first empty input slot
	var slot_index: int = station.find_empty_input_slot()
	if slot_index == -1:
		push_error("DebugCommands.spawn_item: Station has no empty input slots")
		return null

	# Add item to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_item: Could not find Level node")
		return null

	# Use level's unified API to create item on ground first
	var item: ItemEntity = level.add_item(station.global_position, tag)
	if item == null:
		push_error("DebugCommands.spawn_item: level.add_item returned null")
		return null

	# Place in station slot (this sets location to IN_SLOT and reparents)
	var success: bool = station.place_input_item(item, slot_index)
	if not success:
		push_error("DebugCommands.spawn_item: Failed to place item in station slot")
		level.remove_item(item)
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

	# Snap position to grid
	var snapped_position: Vector2 = snap_to_grid(position)

	# Add to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_station: Could not find Level node")
		return null

	# Use level's unified API (it handles NPC notification)
	var station_name: String = type.capitalize() + " (Debug)"
	var station: Station = level.add_station(snapped_position, type, station_name)
	if station == null:
		push_error("DebugCommands.spawn_station: level.add_station returned null")
		return null

	# Apply color to the sprite
	_apply_station_color(station, type)

	# Emit signal
	station_spawned.emit(station)

	return station


## Remove a station from the level
## Returns true if station was removed, false otherwise
func remove_station(station: Station) -> bool:
	if station == null:
		push_error("DebugCommands.remove_station: station is null")
		return false

	if not is_instance_valid(station):
		push_error("DebugCommands.remove_station: station is not a valid instance")
		return false

	# Clear selection if this station was selected
	if selected_entity == station:
		deselect_entity()

	# Emit signal before freeing
	station_removed.emit(station)

	# Remove via level's API
	var level: Node = _get_level_node()
	if level != null and level.has_method("remove_station"):
		return level.remove_station(station)

	# Fallback: just free directly
	station.queue_free()
	return true


## Snap a position to the grid
func snap_to_grid(position: Vector2, grid_size: int = GRID_SIZE) -> Vector2:
	return Vector2(
		round(position.x / grid_size) * grid_size,
		round(position.y / grid_size) * grid_size
	)


# ============================================================================
# CONTAINER SPAWNING
# ============================================================================

## Valid container types for spawning
const VALID_CONTAINER_TYPES: Array[String] = [
	"fridge", "crate", "shelf", "bin", "chest", "stockpile"
]

## Container colors for visual differentiation
const CONTAINER_COLORS: Dictionary = {
	"fridge": Color(0.7, 0.85, 0.9, 1.0),    # Light blue (cold)
	"crate": Color(0.6, 0.45, 0.3, 1.0),     # Brown (wood)
	"shelf": Color(0.5, 0.4, 0.35, 1.0),     # Dark brown
	"bin": Color(0.4, 0.45, 0.4, 1.0),       # Gray-green
	"chest": Color(0.55, 0.4, 0.25, 1.0),    # Brown-orange
	"stockpile": Color(0.5, 0.5, 0.45, 1.0)  # Gray
}

## Default allowed tags for each container type
const CONTAINER_ALLOWED_TAGS: Dictionary = {
	"fridge": ["raw_food", "prepped_food", "cooked_meal"],
	"crate": [],       # Allow all
	"shelf": [],       # Allow all
	"bin": [],         # Allow all
	"chest": [],       # Allow all
	"stockpile": []    # Allow all
}


## Get valid container types for UI dropdowns
func get_valid_container_types() -> Array[String]:
	return VALID_CONTAINER_TYPES.duplicate()


## Spawn a container at a position
## type: Container type from VALID_CONTAINER_TYPES
## position: World position (will be snapped to grid)
## allowed_tags: Optional array of allowed item tags (empty = allow all)
## Returns the spawned ItemContainer or null on failure
func spawn_container(type: String, position: Vector2, allowed_tags: Array = []) -> ItemContainer:
	# Validate container type
	if type not in VALID_CONTAINER_TYPES:
		push_error("DebugCommands.spawn_container: Invalid container type '" + type + "'. Valid types: " + str(VALID_CONTAINER_TYPES))
		return null

	# Snap position to grid
	var snapped_position: Vector2 = snap_to_grid(position)

	# Add to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_container: Could not find Level node")
		return null

	# Apply allowed tags - use defaults for type if not specified
	var tags_to_use: Array = allowed_tags
	if tags_to_use.is_empty() and CONTAINER_ALLOWED_TAGS.has(type):
		tags_to_use = CONTAINER_ALLOWED_TAGS[type]

	# Use level's unified API (it handles NPC notification)
	var container_name: String = type.capitalize() + " (Debug)"
	var container: ItemContainer = level.add_container(snapped_position, container_name, tags_to_use)
	if container == null:
		push_error("DebugCommands.spawn_container: level.add_container returned null")
		return null

	# Apply color to the sprite
	_apply_container_color(container, type)

	# Emit signal
	container_spawned.emit(container)

	return container


## Remove a container from the level
## Returns true if container was removed, false otherwise
func remove_container(container: ItemContainer) -> bool:
	if container == null:
		push_error("DebugCommands.remove_container: container is null")
		return false

	if not is_instance_valid(container):
		push_error("DebugCommands.remove_container: container is not a valid instance")
		return false

	# Clear selection if this container was selected
	if selected_entity == container:
		deselect_entity()

	# Remove via level's API
	var level: Node = _get_level_node()
	if level != null and level.has_method("remove_container"):
		return level.remove_container(container)

	# Fallback: just free directly
	container.queue_free()
	return true


## Get all containers from the level
func get_runtime_containers() -> Array[ItemContainer]:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_containers"):
		return level.get_all_containers()
	return []


## Remove all containers from the level
func clear_runtime_containers() -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	# Make a copy to avoid modifying array while iterating
	var containers: Array[ItemContainer] = get_runtime_containers().duplicate()
	for container in containers:
		if is_instance_valid(container):
			level.remove_container(container)


## Apply the appropriate color to a container's sprite based on its type
func _apply_container_color(container: ItemContainer, type: String) -> void:
	var sprite: ColorRect = container.get_node_or_null("Sprite2D")
	if sprite != null and CONTAINER_COLORS.has(type):
		sprite.color = CONTAINER_COLORS[type]


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


## Get all stations from the level
func get_runtime_stations() -> Array[Station]:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_stations"):
		return level.get_all_stations()
	return []


## Remove all stations from the level
func clear_runtime_stations() -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	# Make a copy to avoid modifying array while iterating
	var stations: Array[Station] = get_runtime_stations().duplicate()
	for station in stations:
		if is_instance_valid(station):
			station_removed.emit(station)
			level.remove_station(station)


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
	# Add to scene tree via level's API
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.spawn_npc: Could not find Level node")
		return null

	# Use level's unified API (it handles initialization)
	var npc: Node = level.add_npc(position)
	if npc == null:
		push_error("DebugCommands.spawn_npc: level.add_npc returned null")
		return null

	# Set motives after NPC is in the tree
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

	# Emit signal
	npc_spawned.emit(npc)

	return npc


## Get all NPCs from the level
func _get_all_npcs() -> Array:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_npcs"):
		return level.get_all_npcs()
	return []


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


## Get all NPCs from the level
func get_runtime_npcs() -> Array[Node]:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_npcs"):
		return level.get_all_npcs()
	return []


## Remove all NPCs from the level
func clear_runtime_npcs() -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	# Make a copy to avoid modifying array while iterating
	var npcs: Array[Node] = get_runtime_npcs().duplicate()
	for npc in npcs:
		if is_instance_valid(npc):
			level.remove_npc(npc)


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


# =============================================================================
# JOB MANAGEMENT (US-005)
# =============================================================================

# Signals for job management
signal job_posted_debug(job: Job)
signal job_interrupted_debug(job: Job)


## Post a new job by loading a recipe from a resource path
## recipe_path: Path to the recipe resource (e.g., "res://resources/recipes/cook_simple_meal.tres")
## Returns the created Job, or null if recipe could not be loaded
func post_job(recipe_path: String) -> Job:
	if recipe_path.is_empty():
		push_error("DebugCommands.post_job: recipe_path cannot be empty")
		return null

	# Load the recipe resource
	var recipe: Recipe = load(recipe_path) as Recipe
	if recipe == null:
		push_error("DebugCommands.post_job: Could not load recipe from '" + recipe_path + "'")
		return null

	# Post the job via JobBoard
	var job: Job = JobBoard.post_job(recipe)
	if job == null:
		push_error("DebugCommands.post_job: JobBoard.post_job returned null")
		return null

	# Emit debug signal
	job_posted_debug.emit(job)

	return job


## Interrupt an in-progress job
## job: The Job to interrupt
## Returns true if job was interrupted, false otherwise
func interrupt_job(job: Job) -> bool:
	if job == null:
		push_error("DebugCommands.interrupt_job: job is null")
		return false

	# Get the NPC that's working on this job before interrupting
	var npc = job.claimed_by

	# If there's an NPC actively working on this job (has current_job set),
	# use their interrupt method which properly handles dropping items, releasing stations, etc.
	if npc != null and npc.has_method("interrupt_current_job") and npc.get("current_job") == job:
		var result: bool = npc.interrupt_current_job()
		if result:
			job_interrupted_debug.emit(job)
		return result

	# Fallback: Delegate to JobBoard (for jobs where NPC isn't actively working via current_job)
	var result: bool = JobBoard.interrupt_job(job)

	if result:
		job_interrupted_debug.emit(job)

	return result


## Get all jobs from the JobBoard
## Returns array of all jobs in any state
func get_all_jobs() -> Array[Job]:
	return JobBoard.jobs.duplicate()


## Get jobs filtered by state
## state: The JobState to filter by (e.g., Job.JobState.POSTED)
## Returns array of jobs matching the specified state
func get_jobs_by_state(state: Job.JobState) -> Array[Job]:
	return JobBoard.get_jobs_by_state(state)


# =============================================================================
# WALL PAINTING (US-006)
# =============================================================================

## Wall visual properties
const WALL_COLOR := Color(0.35, 0.35, 0.45)
const WALL_TILE_SIZE := 32


## Paint or remove a wall at a grid position
## grid_position: The grid coordinates (not world position) where the wall should be placed
## add_wall: If true, adds a wall; if false, removes a wall
## Returns true if the operation succeeded, false otherwise
func paint_wall(grid_position: Vector2i, add_wall: bool) -> bool:
	var level: Node = _get_level_node()
	if level == null:
		push_error("DebugCommands.paint_wall: Could not find Level node")
		return false

	# Check if level has AStar
	if not level.has_method("get_astar"):
		push_error("DebugCommands.paint_wall: Level does not have get_astar method")
		return false

	var astar: AStarGrid2D = level.get_astar()
	if astar == null:
		push_error("DebugCommands.paint_wall: Level AStar is null")
		return false

	# Check if position is within map bounds
	if not _is_grid_position_valid(grid_position, astar):
		push_error("DebugCommands.paint_wall: Grid position " + str(grid_position) + " is out of bounds")
		return false

	if add_wall:
		return _add_wall_at(grid_position, level, astar)
	else:
		return _remove_wall_at(grid_position, level, astar)


## Check if a wall exists at a grid position
## grid_position: The grid coordinates to check
## Returns true if a wall exists at that position, false otherwise
func get_wall_at(grid_position: Vector2i) -> bool:
	var level: Node = _get_level_node()
	if level == null:
		return false

	if not level.has_method("get_astar"):
		return false

	var astar: AStarGrid2D = level.get_astar()
	if astar == null:
		return false

	# Check if position is within bounds
	if not _is_grid_position_valid(grid_position, astar):
		return false

	# AStar reports solid points as walls
	return astar.is_point_solid(grid_position)


## Check if a grid position is within the AStar region bounds
func _is_grid_position_valid(grid_position: Vector2i, astar: AStarGrid2D) -> bool:
	var region: Rect2i = astar.region
	return grid_position.x >= region.position.x and grid_position.x < region.position.x + region.size.x \
		and grid_position.y >= region.position.y and grid_position.y < region.position.y + region.size.y


## Add a wall at a grid position
func _add_wall_at(grid_position: Vector2i, level: Node, astar: AStarGrid2D) -> bool:
	# Check if wall already exists
	if astar.is_point_solid(grid_position):
		# Wall already exists, no-op but return true
		return true

	# Use level's add_wall method
	if not level.has_method("add_wall"):
		push_error("DebugCommands._add_wall_at: Level does not have add_wall method")
		return false

	var success: bool = level.add_wall(grid_position)
	if success:
		wall_changed.emit(grid_position, true)
	return success


## Remove a wall at a grid position
func _remove_wall_at(grid_position: Vector2i, level: Node, astar: AStarGrid2D) -> bool:
	# Check if wall exists
	if not astar.is_point_solid(grid_position):
		# No wall exists, no-op but return true
		return true

	# Use level's remove_wall method
	if not level.has_method("remove_wall"):
		push_error("DebugCommands._remove_wall_at: Level does not have remove_wall method")
		return false

	var success: bool = level.remove_wall(grid_position)
	if success:
		wall_changed.emit(grid_position, false)
	return success

## Convert a world position to grid position
func world_to_grid(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(world_position.x / WALL_TILE_SIZE),
		int(world_position.y / WALL_TILE_SIZE)
	)


## Convert a grid position to world position (center of tile)
func grid_to_world(grid_position: Vector2i) -> Vector2:
	return Vector2(
		grid_position.x * WALL_TILE_SIZE + WALL_TILE_SIZE / 2.0,
		grid_position.y * WALL_TILE_SIZE + WALL_TILE_SIZE / 2.0
	)


## Get all walls from the level
## Returns dictionary of {grid_position: wall_node}
func get_runtime_walls() -> Dictionary:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_walls"):
		return level.get_all_walls()
	return {}


## Remove all walls from the level
func clear_runtime_walls() -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	# Make a copy to avoid modifying dictionary while iterating
	var walls: Dictionary = get_runtime_walls().duplicate()
	for grid_pos in walls:
		if level.has_method("remove_wall"):
			level.remove_wall(grid_pos)
			wall_changed.emit(grid_pos, false)


# =============================================================================
# SCENARIO SAVE/LOAD (US-007)
# =============================================================================

# Signals for scenario operations
signal scenario_saved(path: String)
signal scenario_loaded(path: String)
signal scenario_cleared()


## Save the current scenario to a JSON file
## path: File path to save the scenario (e.g., "user://scenarios/test_setup.json")
## Returns true if save was successful, false otherwise
func save_scenario(path: String) -> bool:
	if path.is_empty():
		push_error("DebugCommands.save_scenario: path cannot be empty")
		return false

	var scenario_data: Dictionary = {
		"version": 1,
		"stations": _collect_station_data(),
		"containers": _collect_container_data(),
		"items": _collect_item_data(),
		"npcs": _collect_npc_data(),
		"walls": _collect_wall_data()
	}

	# Convert to JSON
	var json_string: String = JSON.stringify(scenario_data, "\t")

	# Ensure directory exists
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Write to file
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("DebugCommands.save_scenario: Failed to open file for writing: " + path + " (Error: " + str(FileAccess.get_open_error()) + ")")
		return false

	file.store_string(json_string)
	file.close()

	scenario_saved.emit(path)
	return true


## Load a scenario from a JSON file
## path: File path to load the scenario from
## clear_first: If true, removes existing runtime entities before loading
## Returns true if load was successful, false otherwise
func load_scenario(path: String, clear_first: bool = true) -> bool:
	if path.is_empty():
		push_error("DebugCommands.load_scenario: path cannot be empty")
		return false

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("DebugCommands.load_scenario: File does not exist: " + path)
		return false

	# Read file
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DebugCommands.load_scenario: Failed to open file for reading: " + path)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	# Parse JSON
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("DebugCommands.load_scenario: Failed to parse JSON: " + json.get_error_message())
		return false

	var scenario_data: Dictionary = json.data
	if not scenario_data is Dictionary:
		push_error("DebugCommands.load_scenario: Invalid scenario data format")
		return false

	# Clear existing entities if requested
	if clear_first:
		clear_scenario()

	# Load entities
	_load_stations(scenario_data.get("stations", []))
	_load_containers(scenario_data.get("containers", []))
	_load_items(scenario_data.get("items", []))
	_load_npcs(scenario_data.get("npcs", []))
	_load_walls(scenario_data.get("walls", []))

	scenario_loaded.emit(path)
	return true


## Clear all runtime-spawned entities
func clear_scenario() -> void:
	clear_runtime_stations()
	clear_runtime_containers()
	clear_runtime_items()
	clear_runtime_npcs()
	clear_runtime_walls()
	scenario_cleared.emit()


## Get all items from the level
func get_runtime_items() -> Array[ItemEntity]:
	var level: Node = _get_level_node()
	if level != null and level.has_method("get_all_items"):
		return level.get_all_items()
	return []


## Remove all items from the level
func clear_runtime_items() -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	# Make a copy to avoid modifying array while iterating
	var items: Array[ItemEntity] = get_runtime_items().duplicate()
	for item in items:
		if is_instance_valid(item):
			level.remove_item(item)


# -----------------------------------------------------------------------------
# Scenario Data Collection Helpers
# -----------------------------------------------------------------------------

## Collect data for all stations
func _collect_station_data() -> Array:
	var stations_data: Array = []
	for station in get_runtime_stations():
		if is_instance_valid(station):
			stations_data.append({
				"type": station.station_tag,
				"name": station.station_name,
				"position": {"x": station.global_position.x, "y": station.global_position.y}
			})
	return stations_data


## Collect data for all containers
func _collect_container_data() -> Array:
	var containers_data: Array = []
	for container in get_runtime_containers():
		if is_instance_valid(container):
			containers_data.append({
				"name": container.container_name,
				"position": {"x": container.global_position.x, "y": container.global_position.y},
				"allowed_tags": container.allowed_tags.duplicate()
			})
	return containers_data


## Collect data for all runtime items
func _collect_item_data() -> Array:
	var items_data: Array = []
	for item in get_runtime_items():
		if is_instance_valid(item):
			var item_data: Dictionary = {
				"tag": item.item_tag,
				"location": _get_item_location_name(item)
			}

			# Add container/station info based on location
			match item.location:
				ItemEntity.ItemLocation.ON_GROUND:
					item_data["position"] = {"x": item.global_position.x, "y": item.global_position.y}
				ItemEntity.ItemLocation.IN_CONTAINER:
					var parent: Node = item.get_parent()
					if is_instance_valid(parent) and parent is ItemContainer:
						item_data["container_index"] = _find_runtime_container_index(parent)
				ItemEntity.ItemLocation.IN_SLOT:
					var parent: Node = item.get_parent()
					if is_instance_valid(parent):
						# Find station by traversing up
						var station: Station = _find_parent_station(parent)
						if station != null:
							item_data["station_index"] = _find_runtime_station_index(station)
							item_data["slot_index"] = _find_item_slot_index(item, station)

			items_data.append(item_data)
	return items_data


## Collect data for all runtime NPCs
func _collect_npc_data() -> Array:
	var npcs_data: Array = []
	for npc in get_runtime_npcs():
		if is_instance_valid(npc):
			var motives_dict: Dictionary = {}
			for motive_name in VALID_MOTIVE_NAMES:
				motives_dict[motive_name] = get_npc_motive(npc, motive_name)

			npcs_data.append({
				"position": {"x": npc.global_position.x, "y": npc.global_position.y},
				"motives": motives_dict
			})
	return npcs_data


## Collect data for all runtime walls
func _collect_wall_data() -> Array:
	var walls_data: Array = []
	for grid_pos in get_runtime_walls():
		walls_data.append({
			"grid_x": grid_pos.x,
			"grid_y": grid_pos.y
		})
	return walls_data


## Find the index of a container in the level's containers
func _find_runtime_container_index(container: ItemContainer) -> int:
	var containers: Array[ItemContainer] = get_runtime_containers()
	return containers.find(container)


## Find the parent station of a node
func _find_parent_station(node: Node) -> Station:
	var current: Node = node
	while current != null:
		if current is Station:
			return current
		current = current.get_parent()
	return null


## Find the index of a station in the level's stations
func _find_runtime_station_index(station: Station) -> int:
	var stations: Array[Station] = get_runtime_stations()
	return stations.find(station)


## Find the slot index of an item in a station
func _find_item_slot_index(item: ItemEntity, station: Station) -> int:
	# Check input slots
	for i in range(station.get_input_slot_count()):
		var slot_item: ItemEntity = station.get_input_item(i)
		if slot_item == item:
			return i
	# Check output slots
	for i in range(station.get_output_slot_count()):
		var slot_item: ItemEntity = station.get_output_item(i)
		if slot_item == item:
			return i + station.get_input_slot_count()  # Offset for output slots
	return -1


# -----------------------------------------------------------------------------
# Scenario Data Loading Helpers
# -----------------------------------------------------------------------------

## Load stations from scenario data
func _load_stations(stations_data: Array) -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	for station_data in stations_data:
		var type: String = station_data.get("type", "generic")
		var station_name: String = station_data.get("name", "")
		var pos_data: Dictionary = station_data.get("position", {})
		var position := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))

		# Use level's API directly to preserve the station name
		var station: Station = level.add_station(position, type, station_name)
		if station != null:
			_apply_station_color(station, type)
			station_spawned.emit(station)


## Load containers from scenario data
func _load_containers(containers_data: Array) -> void:
	var level: Node = _get_level_node()
	if level == null:
		return

	for container_data in containers_data:
		var container_name: String = container_data.get("name", "Storage")
		var pos_data: Dictionary = container_data.get("position", {})
		var position := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
		var allowed_tags: Array = container_data.get("allowed_tags", [])

		# Use level's API directly
		var container: ItemContainer = level.add_container(position, container_name, allowed_tags)
		if container != null:
			container_spawned.emit(container)


## Load items from scenario data
func _load_items(items_data: Array) -> void:
	var stations: Array[Station] = get_runtime_stations()

	for item_data in items_data:
		var tag: String = item_data.get("tag", "")
		if tag.is_empty():
			continue

		var location: String = item_data.get("location", "ON_GROUND")

		match location:
			"ON_GROUND":
				var pos_data: Dictionary = item_data.get("position", {})
				var position := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
				spawn_item(tag, position)
			"IN_SLOT":
				var station_index: int = item_data.get("station_index", -1)
				if station_index >= 0 and station_index < stations.size():
					var station: Station = stations[station_index]
					spawn_item(tag, station)
			"IN_CONTAINER":
				var container_index: int = item_data.get("container_index", -1)
				var containers: Array[ItemContainer] = get_runtime_containers()
				if container_index >= 0 and container_index < containers.size():
					var container: ItemContainer = containers[container_index]
					spawn_item(tag, container)


## Load NPCs from scenario data
func _load_npcs(npcs_data: Array) -> void:
	for npc_data in npcs_data:
		var pos_data: Dictionary = npc_data.get("position", {})
		var position := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
		var motives: Dictionary = npc_data.get("motives", {})

		spawn_npc(position, motives)


## Load walls from scenario data
func _load_walls(walls_data: Array) -> void:
	for wall_data in walls_data:
		var grid_x: int = wall_data.get("grid_x", 0)
		var grid_y: int = wall_data.get("grid_y", 0)
		var grid_pos := Vector2i(grid_x, grid_y)

		paint_wall(grid_pos, true)
