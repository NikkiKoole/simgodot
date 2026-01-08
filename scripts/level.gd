extends Node2D

const TILE_SIZE := 32
const WALL_COLOR := Color(0.35, 0.35, 0.45)
const FLOOR_COLOR := Color(0.15, 0.12, 0.1)

## Number of NPCs to spawn
@export var npc_count: int = 8

@onready var player: CharacterBody2D = $Player

var npc_scene: PackedScene = preload("res://scenes/npc.tscn")

# ASCII map of the world - '#' = wall, ' ' = floor, 'P' = player start
const WORLD_MAP := """
################################################################################
#            #         #                    #              #                   #
#            #         #                    #              #                   #
#            #         #                    #              #                   #
#            #         #                    #              #                   #
#    P       #                                                                 #
#            #         #                    #              #                   #
#            #         #                    #              #                   #
#                      #                    #              #                   #
#            #         #                    #                                  #
#            #         #                    #              #                   #
#######  #####         ##########  ##########              #############  ######
#            #                     #                       #                   #
#            #                     #                       #                   #
#            #                     #                       #                   #
#            #                     #                                           #
#                                  #                       #                   #
#            #                     #                       #                   #
#            #                     #                       #                   #
#            #                     ####  ###################                   #
#            #                          #                                      #
#            #                          #                  #                   #
####  ########                          #                  #                   #
#                                       #                                      #
#                                       #                  #                   #
#                 ################      #                  #                   #
#                 #              #                         #####  ##############
#                 #              #      #                  #                   #
#                                #      #                  #                   #
#                 #              #      #                                      #
#                 #              #      #                  #                   #
#######  ##########              #      #                  #                   #
#                 #                     #                  #                   #
#                 #              #      #                                      #
#                 #              #      #############  #####                   #
#                                #             #                               #
#                 #              #             #           #                   #
#                 #              #             #           #                   #
#                 ####  ##########                                             #
#                        #                     #           #                   #
#                        #                     #           #                   #
#                        #                     #           #                   #
########  ################                     #           #############  ######
#                   #                          #                               #
#                   #                          #                               #
#                   #                          #                               #
#                          ############  #######                               #
#                   #      #                               #                   #
#                   #      #                               #                   #
#                   #                                      #                   #
#                   #      #                               #                   #
#                   #      #                                                   #
#                   #      #                               #                   #
######  #############      #                               #                   #
#                          #         ###########  ##########                   #
#                          #         #                                         #
#                                    #                     #                   #
#                          #         #                     #                   #
#                          #                               #                   #
#                          #         #                     #                   #
#                          #         #                     #############  ######
#                          #         #                                #        #
###########  ###############         #                                #        #
#                          #                                          #        #
#                          #         #                                         #
#                          #         #                                #        #
#                                    #                                #        #
#                          #         #                                #        #
#                          #         #####################  ###########        #
#                          #                                                   #
#                          #                                          #        #
#                          #                                          #        #
################################################################################
"""

var wall_shape: RectangleShape2D
var walkable_positions: Array[Vector2] = []
var map_width: int = 0
var map_height: int = 0
var astar: AStarGrid2D

func _ready() -> void:
	# Create reusable collision shape
	wall_shape = RectangleShape2D.new()
	wall_shape.size = Vector2(TILE_SIZE, TILE_SIZE)

	_parse_and_build_world()
	_setup_astar()
	_spawn_npcs()

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
	floor_rect.z_index = -1
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
				" ":
					walkable_positions.append(pos)

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

	print("AStar grid setup complete: ", map_width, "x", map_height)

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

		# Give the NPC the list of walkable positions and the astar reference
		npc.set_walkable_positions(walkable_positions)
		npc.set_astar(astar)

		add_child(npc)

	print("Spawned ", npc_count, " NPCs with ", walkable_positions.size(), " walkable positions")
