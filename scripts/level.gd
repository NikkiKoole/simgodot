extends Node2D

const TILE_SIZE := 32
const WALL_COLOR := Color(0.35, 0.35, 0.45)
const FLOOR_COLOR := Color(0.15, 0.12, 0.1)

# Default map for normal gameplay
# ASCII map of the world - '#' = wall, ' ' = floor, 'P' = player start
# Object markers: O=container, i=item, W=station (workstation)
const DEFAULT_WORLD_MAP := """
#################
#       #       #
#       #       #
#               #
#       #   O   #
#       #       #
###  ####       #
#       #########
#  P            #
#     i     W   #
###  #####      #
#       #       #
#       #       #
#       #       #
#       #       #
#################
"""

## The ASCII map to use. Empty string = empty grid (for testing)
@export_multiline var world_map: String = DEFAULT_WORLD_MAP

## Whether to auto-spawn NPCs on ready
@export var auto_spawn_npcs: bool = true

## Number of NPCs to spawn (only if auto_spawn_npcs is true)
@export var npc_count: int = 1

## Grid size for empty levels (when world_map is empty)
@export var empty_grid_width: int = 20
@export var empty_grid_height: int = 20

@onready var player: CharacterBody2D = get_node_or_null("Player")

var npc_scene: PackedScene = preload("res://scenes/npc.tscn")
var container_scene: PackedScene = preload("res://scenes/objects/container.tscn")
var item_entity_scene: PackedScene = preload("res://scenes/objects/item_entity.tscn")
var station_scene: PackedScene = preload("res://scenes/objects/station.tscn")

var wall_shape: RectangleShape2D
var walkable_positions: Array[Vector2] = []  # All walkable tiles (for pathfinding)
var wander_positions: Array[Vector2] = []    # Only empty floor tiles (for random wandering)
var map_width: int = 0
var map_height: int = 0
var astar: AStarGrid2D
var all_containers: Array[ItemContainer] = []
var all_stations: Array[Station] = []
var all_items: Array[ItemEntity] = []
var all_npcs: Array[Node] = []
var game_clock: GameClock
var walls: Dictionary = {}  # grid_position (Vector2i) -> wall node (StaticBody2D)

func _ready() -> void:
	add_to_group("level")

	# Create game clock (always needed for NPC behavior)
	game_clock = GameClock.new()
	add_child(game_clock)

	# Create clock UI (skip if no player - i.e., test mode)
	if player != null:
		var clock_ui := ClockUI.new()
		clock_ui.set_game_clock(game_clock)
		add_child(clock_ui)

	# Create reusable collision shape
	wall_shape = RectangleShape2D.new()
	wall_shape.size = Vector2(TILE_SIZE, TILE_SIZE)

	# Parse map OR create empty grid
	if world_map.strip_edges().is_empty():
		_setup_empty_grid()
	else:
		_parse_and_build_world()

	_setup_astar()

	# Only spawn NPCs if enabled
	if auto_spawn_npcs and npc_count > 0:
		_spawn_npcs()

	# Give player reference to game clock (if player exists)
	if player != null:
		player.set_game_clock(game_clock)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

## Setup an empty grid with no walls - all positions walkable
func _setup_empty_grid() -> void:
	map_width = empty_grid_width
	map_height = empty_grid_height

	# Create floor background
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(map_width * TILE_SIZE, map_height * TILE_SIZE)
	floor_rect.z_index = -10
	add_child(floor_rect)

	# All positions are walkable in empty grid
	for y in range(map_height):
		for x in range(map_width):
			var pos := Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
			walkable_positions.append(pos)
			wander_positions.append(pos)


func _parse_and_build_world() -> void:
	var lines := world_map.strip_edges().split("\n")
	map_height = lines.size()

	for line in lines:
		map_width = max(map_width, line.length())

	# Create floor background
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.position = Vector2.ZERO
	floor_rect.size = Vector2(map_width * TILE_SIZE, map_height * TILE_SIZE)
	floor_rect.z_index = -10
	add_child(floor_rect)

	# Parse the map
	for y in range(lines.size()):
		var line: String = lines[y]
		for x in range(line.length()):
			var char := line[x]
			var pos := Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)

			match char:
				"#":
					_create_wall(pos)
				"P":
					player.position = pos
					walkable_positions.append(pos)
					wander_positions.append(pos)
				"O":
					_spawn_container(pos)
					walkable_positions.append(pos)
				"i":
					_spawn_item(pos)
					walkable_positions.append(pos)
				"W":
					_spawn_station(pos)
					walkable_positions.append(pos)
				" ":
					walkable_positions.append(pos)
					wander_positions.append(pos)



func _spawn_container(pos: Vector2, container_name: String = "Storage") -> ItemContainer:
	var container: ItemContainer = container_scene.instantiate()
	container.position = pos
	container.container_name = container_name
	add_child(container)
	all_containers.append(container)
	return container


## Spawn an item at the given position
func _spawn_item(pos: Vector2, item_tag: String = "raw_food") -> ItemEntity:
	var item: ItemEntity = item_entity_scene.instantiate()
	item.position = pos
	item.item_tag = item_tag
	item.location = ItemEntity.ItemLocation.ON_GROUND
	add_child(item)
	all_items.append(item)
	return item


func _spawn_station(pos: Vector2, station_tag: String = "counter") -> Station:
	var station: Station = station_scene.instantiate()
	station.position = pos
	station.station_tag = station_tag
	add_child(station)
	all_stations.append(station)
	return station

func _create_wall(pos: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.position = pos
	wall.collision_layer = 1
	wall.collision_mask = 0

	var collision := CollisionShape2D.new()
	collision.shape = wall_shape
	wall.add_child(collision)

	var visual := ColorRect.new()
	visual.color = WALL_COLOR
	visual.size = Vector2(TILE_SIZE, TILE_SIZE)
	visual.position = Vector2(-TILE_SIZE / 2.0, -TILE_SIZE / 2.0)
	wall.add_child(visual)

	add_child(wall)

	# Track wall by grid position for removal support
	var grid_pos := Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))
	walls[grid_pos] = wall


## Remove a wall at the given grid position
## Returns true if wall was removed, false if no wall exists there
func remove_wall(grid_pos: Vector2i) -> bool:
	if not walls.has(grid_pos):
		return false

	var wall: StaticBody2D = walls[grid_pos]
	if is_instance_valid(wall):
		wall.queue_free()
	walls.erase(grid_pos)

	# Update AStar to mark position as walkable
	if astar != null:
		astar.set_point_solid(grid_pos, false)

	# Add to walkable positions
	var world_pos := Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0, grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	if world_pos not in walkable_positions:
		walkable_positions.append(world_pos)
		wander_positions.append(world_pos)

	return true


## Add a wall at the given grid position
## Returns true if wall was added, false if wall already exists there
func add_wall(grid_pos: Vector2i) -> bool:
	if walls.has(grid_pos):
		return false

	var world_pos := Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0, grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	_create_wall(world_pos)

	# Update AStar to mark position as solid
	if astar != null:
		astar.set_point_solid(grid_pos, true)

	# Remove from walkable positions
	walkable_positions.erase(world_pos)
	wander_positions.erase(world_pos)

	return true


## Check if a wall exists at the given grid position
func has_wall(grid_pos: Vector2i) -> bool:
	return walls.has(grid_pos)

func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, map_width, map_height)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()

	# Only mark walls if we have a map (not empty grid)
	if not world_map.strip_edges().is_empty():
		var lines := world_map.strip_edges().split("\n")
		for y in range(lines.size()):
			var line: String = lines[y]
			for x in range(line.length()):
				if line[x] == "#":
					astar.set_point_solid(Vector2i(x, y), true)



func get_astar() -> AStarGrid2D:
	return astar


# =============================================================================
# PUBLIC API - Entity Management
# These methods are the unified interface for spawning/removing entities.
# Used by both level initialization and DebugCommands.
# =============================================================================

## Add a station to the level at the given position
## Returns the created station
func add_station(pos: Vector2, station_tag: String = "counter", station_name: String = "") -> Station:
	var station: Station = station_scene.instantiate()
	station.position = pos
	station.station_tag = station_tag
	if not station_name.is_empty():
		station.station_name = station_name
	add_child(station)
	all_stations.append(station)
	# Notify all NPCs about the new station
	_notify_npcs_of_new_station(station)
	return station


## Remove a station from the level
## Returns true if removed, false if station wasn't tracked
func remove_station(station: Station) -> bool:
	var idx := all_stations.find(station)
	if idx < 0:
		return false
	all_stations.remove_at(idx)
	if is_instance_valid(station):
		station.queue_free()
	return true


## Add a container to the level at the given position
## Returns the created container
func add_container(pos: Vector2, container_name: String = "Storage", allowed_tags: Array = []) -> ItemContainer:
	var container: ItemContainer = container_scene.instantiate()
	container.position = pos
	container.container_name = container_name
	for tag in allowed_tags:
		container.allowed_tags.append(tag)
	add_child(container)
	all_containers.append(container)
	# Notify all NPCs about the new container
	_notify_npcs_of_new_container(container)
	return container


## Remove a container from the level
## Returns true if removed, false if container wasn't tracked
func remove_container(container: ItemContainer) -> bool:
	var idx := all_containers.find(container)
	if idx < 0:
		return false
	all_containers.remove_at(idx)
	if is_instance_valid(container):
		container.queue_free()
	return true


## Add an item to the level at the given position (on ground)
## Returns the created item
func add_item(pos: Vector2, item_tag: String = "raw_food") -> ItemEntity:
	var item: ItemEntity = item_entity_scene.instantiate()
	item.position = pos
	item.item_tag = item_tag
	item.location = ItemEntity.ItemLocation.ON_GROUND
	add_child(item)
	all_items.append(item)
	return item


## Remove an item from the level
## Returns true if removed, false if item wasn't tracked
func remove_item(item: ItemEntity) -> bool:
	var idx := all_items.find(item)
	if idx < 0:
		return false
	all_items.remove_at(idx)
	if is_instance_valid(item):
		item.queue_free()
	return true


## Add an NPC to the level at the given position
## Returns the created NPC
func add_npc(pos: Vector2) -> Node:
	var npc := npc_scene.instantiate()
	npc.position = pos

	# Initialize the NPC with level data
	npc.set_walkable_positions(walkable_positions)
	npc.set_wander_positions(wander_positions)
	npc.set_astar(astar)
	npc.set_game_clock(game_clock)
	npc.set_available_containers(all_containers)
	npc.set_available_stations(all_stations)

	add_child(npc)
	all_npcs.append(npc)
	return npc


## Remove an NPC from the level
## Returns true if removed, false if NPC wasn't tracked
func remove_npc(npc: Node) -> bool:
	var idx := all_npcs.find(npc)
	if idx < 0:
		return false
	all_npcs.remove_at(idx)
	if is_instance_valid(npc):
		npc.queue_free()
	return true


## Notify all NPCs about a new station
func _notify_npcs_of_new_station(station: Station) -> void:
	for npc in all_npcs:
		if is_instance_valid(npc) and npc.has_method("set_available_stations"):
			var stations: Array[Station] = npc.available_stations.duplicate()
			if station not in stations:
				stations.append(station)
				npc.set_available_stations(stations)


## Notify all NPCs about a new container
func _notify_npcs_of_new_container(container: ItemContainer) -> void:
	for npc in all_npcs:
		if is_instance_valid(npc) and npc.has_method("set_available_containers"):
			var containers: Array[ItemContainer] = npc.available_containers.duplicate()
			if container not in containers:
				containers.append(container)
				npc.set_available_containers(containers)


## Get all stations
func get_all_stations() -> Array[Station]:
	return all_stations


## Get all containers
func get_all_containers() -> Array[ItemContainer]:
	return all_containers


## Get all items
func get_all_items() -> Array[ItemEntity]:
	return all_items


## Get all NPCs
func get_all_npcs() -> Array[Node]:
	var valid_npcs: Array[Node] = []
	for npc in all_npcs:
		if is_instance_valid(npc):
			valid_npcs.append(npc)
	all_npcs = valid_npcs
	return all_npcs


## Get all walls as dictionary of grid_pos -> wall_node
func get_all_walls() -> Dictionary:
	return walls


## Clear all entities (stations, containers, items, npcs, walls added via add_wall)
## Does not clear walls from the original ASCII map
func clear_all_entities() -> void:
	# Clear stations
	for station in all_stations.duplicate():
		if is_instance_valid(station):
			station.queue_free()
	all_stations.clear()

	# Clear containers
	for container in all_containers.duplicate():
		if is_instance_valid(container):
			container.queue_free()
	all_containers.clear()

	# Clear items
	for item in all_items.duplicate():
		if is_instance_valid(item):
			item.queue_free()
	all_items.clear()

	# Clear NPCs
	for npc in all_npcs.duplicate():
		if is_instance_valid(npc):
			npc.queue_free()
	all_npcs.clear()


func _spawn_npcs() -> void:
	# Wait for everything to be ready
	await get_tree().physics_frame

	# Filter walkable positions to avoid spawning too close to player
	var spawn_positions := walkable_positions.filter(func(pos: Vector2) -> bool:
		return pos.distance_to(player.position) > 200.0
	)

	for i in range(npc_count):
		var npc := npc_scene.instantiate()

		# Pick a random spawn position
		if not spawn_positions.is_empty():
			npc.position = spawn_positions.pick_random()
		else:
			npc.position = walkable_positions.pick_random()

		# Give the NPC the list of positions and the astar reference
		npc.set_walkable_positions(walkable_positions)
		npc.set_wander_positions(wander_positions)
		npc.set_astar(astar)
		npc.set_game_clock(game_clock)

		# Give NPC access to containers and stations for job system
		npc.set_available_containers(all_containers)
		npc.set_available_stations(all_stations)

		add_child(npc)
		all_npcs.append(npc)
