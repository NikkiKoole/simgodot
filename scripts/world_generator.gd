@tool
extends Node

## This is a helper script to generate walls from an ASCII map
## Run it once in the editor to create the world, then you can remove it

const TILE_SIZE := 32

# ASCII map of the world
# '#' = wall, ' ' = empty space, 'P' = player start
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

static func get_wall_positions() -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	var lines := WORLD_MAP.strip_edges().split("\n")

	for y in range(lines.size()):
		var line := lines[y]
		for x in range(line.length()):
			if line[x] == "#":
				walls.append(Vector2i(x, y))

	return walls

static func get_player_start() -> Vector2:
	var lines := WORLD_MAP.strip_edges().split("\n")

	for y in range(lines.size()):
		var line := lines[y]
		for x in range(line.length()):
			if line[x] == "P":
				return Vector2(x * TILE_SIZE + TILE_SIZE / 2, y * TILE_SIZE + TILE_SIZE / 2)

	return Vector2(100, 100)  # Default fallback
