extends Node2D

const TILE_SIZE := 32
const WALL_COLOR := Color(0.35, 0.35, 0.45)
const FLOOR_COLOR := Color(0.15, 0.12, 0.1)

## Number of NPCs to spawn
@export var npc_count: int = 64

@onready var player: CharacterBody2D = $Player

var npc_scene: PackedScene = preload("res://scenes/npc.tscn")
var bed_scene: PackedScene = preload("res://scenes/objects/bed.tscn")
var fridge_scene: PackedScene = preload("res://scenes/objects/fridge.tscn")
var toilet_scene: PackedScene = preload("res://scenes/objects/toilet.tscn")
var shower_scene: PackedScene = preload("res://scenes/objects/shower.tscn")
var tv_scene: PackedScene = preload("res://scenes/objects/tv.tscn")
var computer_scene: PackedScene = preload("res://scenes/objects/computer.tscn")
var bookshelf_scene: PackedScene = preload("res://scenes/objects/bookshelf.tscn")
var container_scene: PackedScene = preload("res://scenes/objects/container.tscn")
var item_entity_scene: PackedScene = preload("res://scenes/objects/item_entity.tscn")
var station_scene: PackedScene = preload("res://scenes/objects/station.tscn")

# ASCII map of the world - '#' = wall, ' ' = floor, 'P' = player start
# Object markers: B=bed, F=fridge, T=toilet, S=shower, V=tv, C=computer, K=bookshelf
# New objects: O=container, i=item, W=station (workstation)
const WORLD_MAP := """
#################
#       #       #
# B   B #   F   #
#               #
# B   B #   O   #
#       #       #
###  ####       #
#       #########
#  P        V   #
#     i     W   #
###  #####      #
#   C   #   T   #
#       #       #
#   K   #   S   #
#       #       #
#################
"""

var wall_shape: RectangleShape2D
var walkable_positions: Array[Vector2] = []  # All walkable tiles (for pathfinding)
var wander_positions: Array[Vector2] = []    # Only empty floor tiles (for random wandering)
var map_width: int = 0
var map_height: int = 0
var astar: AStarGrid2D
var all_objects: Array[InteractableObject] = []
var game_clock: GameClock

func _ready() -> void:
	# Create game clock
	game_clock = GameClock.new()
	add_child(game_clock)

	# Create clock UI
	var clock_ui := ClockUI.new()
	clock_ui.set_game_clock(game_clock)
	add_child(clock_ui)

	# Create reusable collision shape
	wall_shape = RectangleShape2D.new()
	wall_shape.size = Vector2(TILE_SIZE, TILE_SIZE)

	_parse_and_build_world()
	_setup_astar()
	_spawn_npcs()

	# Give player reference to game clock
	player.set_game_clock(game_clock)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _parse_and_build_world() -> void:
	var lines := WORLD_MAP.strip_edges().split("\n")
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
				"B":
					_spawn_object(bed_scene, pos)
					walkable_positions.append(pos)
					# Don't add to wander_positions - NPCs shouldn't idle on objects
				"F":
					_spawn_object(fridge_scene, pos)
					walkable_positions.append(pos)
				"T":
					_spawn_object(toilet_scene, pos)
					walkable_positions.append(pos)
				"S":
					_spawn_object(shower_scene, pos)
					walkable_positions.append(pos)
				"V":
					_spawn_object(tv_scene, pos)
					walkable_positions.append(pos)
				"C":
					_spawn_object(computer_scene, pos)
					walkable_positions.append(pos)
				"K":
					_spawn_object(bookshelf_scene, pos)
					walkable_positions.append(pos)
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



func _spawn_object(scene: PackedScene, pos: Vector2) -> void:
	var obj: InteractableObject = scene.instantiate()
	obj.position = pos
	add_child(obj)
	all_objects.append(obj)


func _spawn_container(pos: Vector2, container_name: String = "Storage") -> ItemContainer:
	var container: ItemContainer = container_scene.instantiate()
	container.position = pos
	container.container_name = container_name
	add_child(container)
	return container


func _spawn_item(pos: Vector2, item_tag: String = "raw_food") -> ItemEntity:
	var item: ItemEntity = item_entity_scene.instantiate()
	item.position = pos
	item.item_tag = item_tag
	item.location = ItemEntity.ItemLocation.ON_GROUND
	add_child(item)
	return item


func _spawn_station(pos: Vector2, station_tag: String = "counter") -> Station:
	var station: Station = station_scene.instantiate()
	station.position = pos
	station.station_tag = station_tag
	add_child(station)
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

func _setup_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, map_width, map_height)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()

	# Mark walls as solid
	var lines := WORLD_MAP.strip_edges().split("\n")
	for y in range(lines.size()):
		var line: String = lines[y]
		for x in range(line.length()):
			if line[x] == "#":
				astar.set_point_solid(Vector2i(x, y), true)



func get_astar() -> AStarGrid2D:
	return astar

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
		npc.set_available_objects(all_objects)
		npc.set_game_clock(game_clock)

		add_child(npc)
