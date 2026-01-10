extends TestRunner

## Tests for NPC station output pickup during hauling (US-007)

const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var level: Node2D


func _ready() -> void:
	_test_name = "NPC Station Output Hauling"
	level = get_parent()
	super._ready()


func run_tests() -> void:
	_log_header()

	await test_npc_pathfinds_to_station_output()
	await test_npc_picks_up_station_output()
	await test_station_output_removed()
	await test_station_output_location_changes()
	await test_npc_continues_after_station_pickup()

	_log_summary()


func test_npc_pathfinds_to_station_output() -> void:
	test("NPC pathfinds to station with output items")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(50, 50)
	level.add_child(npc)
	npc.is_initialized = true
	npc.set_astar(level.astar)
	npc.set_walkable_positions(level.walkable_positions)

	# Create station with output item
	var station: Station = level.add_station(Vector2(200, 50), "counter")
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	output_item.item_tag = "cooked_meal"
	station.place_output_item(output_item, 0)

	# Set up NPC with no containers but with stations
	var empty_containers: Array[ItemContainer] = []
	var stations: Array[Station] = [station]
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(stations)

	# Set up items to gather
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "cooked_meal", "quantity": 1})

	# Start gathering - should find station output
	var result: bool = npc._start_gathering_next_item()

	assert_true(result, "Should successfully start gathering")
	assert_eq(npc.target_station_output, station, "Should target the station")
	assert_eq(npc.current_state, npc.State.HAULING, "Should be in HAULING state")
	assert_true(npc.current_path.size() > 0, "Should have a path to the station")

	# Cleanup
	level.remove_station(station)
	npc.queue_free()
	await get_tree().process_frame


func test_npc_picks_up_station_output() -> void:
	test("NPC picks up item from station output slot on arrival")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Create station with output item at NPC position
	var station: Station = level.add_station(Vector2(100, 100), "counter")
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	output_item.item_tag = "cooked_meal"
	station.place_output_item(output_item, 0)

	# Set up NPC
	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Set up NPC targeting the station output
	npc.target_station_output = station
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "cooked_meal", "quantity": 1})

	# Simulate arrival
	npc._on_arrived_at_station_output()

	assert_true(npc.held_items.has(output_item), "Item should be in held_items")
	assert_eq(npc.target_station_output, null, "target_station_output should be cleared")

	# Cleanup
	level.remove_station(station)
	npc.queue_free()
	await get_tree().process_frame


func test_station_output_removed() -> void:
	test("Station no longer has item in output slot after pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Create station with output item
	var station: Station = level.add_station(Vector2(100, 100), "counter")
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	output_item.item_tag = "cooked_meal"
	station.place_output_item(output_item, 0)

	assert_true(station.has_output_items(), "Station should have output items before pickup")

	# Set up NPC
	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Set up NPC targeting the station output
	npc.target_station_output = station
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "cooked_meal", "quantity": 1})

	# Simulate arrival and pickup
	npc._on_arrived_at_station_output()

	assert_false(station.has_output_items(), "Station should not have output items after pickup")
	assert_eq(station.get_output_item(0), null, "Output slot 0 should be empty")

	# Cleanup
	level.remove_station(station)
	npc.queue_free()
	await get_tree().process_frame


func test_station_output_location_changes() -> void:
	test("Station output item location changes to IN_HAND after pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Create station with output item
	var station: Station = level.add_station(Vector2(100, 100), "counter")
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	output_item.item_tag = "cooked_meal"
	station.place_output_item(output_item, 0)

	assert_eq(output_item.location, ItemEntity.ItemLocation.IN_SLOT, "Item starts IN_SLOT")

	# Set up NPC
	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Set up NPC and simulate pickup
	npc.target_station_output = station
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "cooked_meal", "quantity": 1})
	npc._on_arrived_at_station_output()

	assert_eq(output_item.location, ItemEntity.ItemLocation.IN_HAND, "Item location should be IN_HAND")

	# Cleanup
	level.remove_station(station)
	npc.queue_free()
	await get_tree().process_frame


func test_npc_continues_after_station_pickup() -> void:
	test("NPC proceeds to next step after station output pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true
	npc.set_astar(level.astar)
	npc.set_walkable_positions(level.walkable_positions)

	# Create station with output item
	var station: Station = level.add_station(Vector2(100, 100), "counter")
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	output_item.item_tag = "cooked_meal"
	station.place_output_item(output_item, 0)

	# Create a ground item as next item to gather
	var ground_item: ItemEntity = level.add_item(Vector2(150, 100), "seasoning")

	# Set up NPC
	var empty_containers: Array[ItemContainer] = []
	var stations: Array[Station] = [station]
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(stations)

	# Set up multiple items to gather
	npc.target_station_output = station
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "cooked_meal", "quantity": 1})
	npc.items_to_gather.append({"tag": "seasoning", "quantity": 1})

	# Pick up first item from station
	npc._on_arrived_at_station_output()

	# Should have picked up cooked_meal
	assert_true(npc.held_items.size() >= 1, "Should have at least one held item")
	assert_eq(npc.held_items[0].item_tag, "cooked_meal", "First held item should be cooked_meal")

	# Should now be looking for seasoning
	if npc.items_to_gather.size() > 0:
		assert_eq(npc.items_to_gather[0]["tag"], "seasoning", "Next item to gather should be seasoning")

	# Cleanup
	level.remove_item(ground_item)
	level.remove_station(station)
	npc.queue_free()
	await get_tree().process_frame
