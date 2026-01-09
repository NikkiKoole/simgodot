## DebugCommands Singleton
## Provides a testable API layer for all debug operations
## All debug functionality flows through this singleton for headless testability
## Access via the DebugCommands autoload (do not use class_name to avoid conflicts)
extends Node

# Signals for UI updates and testing
signal entity_selected(entity: Node)
signal entity_deselected()

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
