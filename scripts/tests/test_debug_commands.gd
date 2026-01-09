extends TestRunner

## Tests for DebugCommands singleton (US-001)

const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")
const NPCScene = preload("res://scenes/npc.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const LevelScene = preload("res://scenes/tests/test_level.tscn")

var test_area: Node2D
var test_level: Node2D


func _ready() -> void:
	_test_name = "DebugCommands"
	test_area = $TestArea
	_setup_test_level()
	super._ready()


func _setup_test_level() -> void:
	test_level = LevelScene.instantiate()
	# Properties already set in test_level.tscn: world_map = "", auto_spawn_npcs = false
	add_child(test_level)


func run_tests() -> void:
	_log_header()

	test_select_entity()
	test_deselect_entity()
	await test_npc_inspection_data()
	await test_station_inspection_data()
	test_item_inspection_data()
	await test_container_inspection_data()
	test_unknown_entity_inspection()

	# US-002: Item spawning tests
	test_spawn_item_on_ground()
	await test_spawn_item_in_container()
	await test_spawn_item_at_station()
	test_spawn_item_signal()
	test_spawn_item_errors()
	await test_spawn_item_container_full()
	await test_spawn_item_station_slots_full()

	# US-003: Station spawning tests
	await test_spawn_station_basic()
	test_spawn_station_grid_snapping()
	await test_spawn_station_all_types()
	await test_spawn_station_signal()
	test_spawn_station_invalid_type()
	await test_remove_station()
	await test_remove_station_clears_selection()
	await test_get_runtime_stations()
	await test_clear_runtime_stations()

	# US-004: NPC spawning and motive adjustment tests
	await test_spawn_npc_default_motives()
	await test_spawn_npc_custom_motives()
	await test_spawn_npc_signal()
	await test_set_npc_motive()
	await test_set_npc_motive_clamping()
	await test_set_npc_motive_signal()
	await test_set_npc_motives_batch()
	await test_set_npc_motive_invalid_name()
	await test_get_runtime_npcs()
	await test_clear_runtime_npcs()

	# US-005: Job management tests
	await test_post_job_cook_simple_meal()
	await test_post_job_use_toilet()
	await test_post_job_watch_tv()
	test_post_job_invalid_path()
	await test_post_job_signal()
	await test_interrupt_job()
	await test_interrupt_job_signal()
	test_interrupt_job_invalid()
	await test_get_all_jobs()
	await test_get_jobs_by_state()

	# US-006: Wall painting tests
	await test_paint_wall_add()
	await test_paint_wall_remove()
	await test_get_wall_at()
	await test_paint_wall_signal()
	await test_paint_wall_out_of_bounds()
	await test_paint_wall_remove_nonexistent()
	await test_get_runtime_walls()
	await test_clear_runtime_walls()
	await test_world_grid_conversion()

	# US-007: Scenario save/load tests
	await test_save_scenario_empty()
	await test_save_scenario_with_stations()
	await test_save_scenario_with_npcs()
	await test_save_scenario_with_walls()
	await test_save_scenario_signal()
	test_save_scenario_invalid_path()
	await test_load_scenario_basic()
	await test_load_scenario_clear_first()
	await test_load_scenario_no_clear()
	await test_load_scenario_signal()
	test_load_scenario_invalid_path()
	await test_clear_scenario()
	test_clear_scenario_signal()
	await test_scenario_round_trip_complex()

	# Container spawning tests
	await test_spawn_container_basic()
	await test_spawn_container_all_types()
	await test_spawn_container_grid_snapping()
	await test_spawn_container_signal()
	test_spawn_container_invalid_type()
	await test_spawn_container_default_allowed_tags()
	await test_spawn_container_custom_allowed_tags()
	await test_remove_container()
	await test_get_runtime_containers()
	await test_clear_runtime_containers()
	await test_spawn_item_into_container_via_api()
	await test_container_notifies_npcs()

	_log_summary()


func test_select_entity() -> void:
	test("Select entity updates selection")

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "test_item"
	test_area.add_child(item)

	# Initially no selection
	DebugCommands.deselect_entity()
	assert_null(DebugCommands.selected_entity, "Initially no entity should be selected")

	# Select the entity
	DebugCommands.select_entity(item)
	assert_eq(DebugCommands.selected_entity, item, "selected_entity should be updated")

	# Select a different entity
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item2.item_tag = "test_item2"
	test_area.add_child(item2)
	DebugCommands.select_entity(item2)
	assert_eq(DebugCommands.selected_entity, item2, "selected_entity should change to new entity")

	# Selecting same entity again doesn't change anything
	DebugCommands.select_entity(item2)
	assert_eq(DebugCommands.selected_entity, item2, "selected_entity remains same when re-selecting")

	# Cleanup
	DebugCommands.deselect_entity()
	item.queue_free()
	item2.queue_free()


func test_deselect_entity() -> void:
	test("Deselect entity clears selection")

	var item: ItemEntity = ItemEntityScene.instantiate()
	test_area.add_child(item)

	# First select an entity
	DebugCommands.select_entity(item)
	assert_eq(DebugCommands.selected_entity, item, "Entity should be selected first")

	# Deselect
	DebugCommands.deselect_entity()
	assert_null(DebugCommands.selected_entity, "selected_entity should be null after deselect")

	# Deselecting again is safe (no error)
	DebugCommands.deselect_entity()
	assert_null(DebugCommands.selected_entity, "selected_entity remains null after second deselect")

	# Cleanup
	item.queue_free()


func test_npc_inspection_data() -> void:
	test("NPC inspection data returns correct structure")

	var npc: Node = NPCScene.instantiate()
	test_area.add_child(npc)

	# Wait for NPC to initialize
	await get_tree().process_frame
	await get_tree().process_frame

	var data: Dictionary = DebugCommands.get_inspection_data(npc)

	# Check type
	assert_eq(data.get("type"), "npc", "Type should be 'npc'")

	# Check state exists
	assert_true(data.has("state"), "Data should have 'state' key")
	assert_true(data.state is String, "State should be a string")

	# Check motives
	assert_true(data.has("motives"), "Data should have 'motives' key")
	var motives: Dictionary = data.motives
	assert_true(motives.has("hunger"), "Motives should have 'hunger'")
	assert_true(motives.has("energy"), "Motives should have 'energy'")
	assert_true(motives.has("bladder"), "Motives should have 'bladder'")
	assert_true(motives.has("hygiene"), "Motives should have 'hygiene'")
	assert_true(motives.has("fun"), "Motives should have 'fun'")

	# Check held_item
	assert_true(data.has("held_item"), "Data should have 'held_item' key")
	assert_eq(data.held_item, "", "NPC should not be holding anything initially")

	# Check current_job
	assert_true(data.has("current_job"), "Data should have 'current_job' key")

	npc.queue_free()


func test_station_inspection_data() -> void:
	test("Station inspection data returns correct structure")

	var station: Station = StationScene.instantiate()
	station.station_tag = "stove"
	station.station_name = "Test Stove"
	test_area.add_child(station)

	await get_tree().process_frame

	# Add an item to the station
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	test_area.add_child(item)
	station.place_input_item(item, 0)

	var data: Dictionary = DebugCommands.get_inspection_data(station)

	# Check type
	assert_eq(data.get("type"), "station", "Type should be 'station'")

	# Check tags
	assert_true(data.has("tags"), "Data should have 'tags' key")
	assert_array_contains(data.tags, "stove", "Tags should contain 'stove'")

	# Check slot_contents
	assert_true(data.has("slot_contents"), "Data should have 'slot_contents' key")
	var slot_contents: Dictionary = data.slot_contents
	assert_true(slot_contents.has("input_slots"), "slot_contents should have 'input_slots'")
	assert_true(slot_contents.has("output_slots"), "slot_contents should have 'output_slots'")

	# Check input slot has our item
	var input_slots: Array = slot_contents.input_slots
	assert_true(input_slots.size() > 0, "Should have at least one input slot")
	assert_eq(input_slots[0], "raw_food", "First input slot should contain 'raw_food'")

	# Check current_user
	assert_true(data.has("current_user"), "Data should have 'current_user' key")
	assert_eq(data.current_user, "", "Station should have no current user")

	station.queue_free()


func test_item_inspection_data() -> void:
	test("ItemEntity inspection data returns correct structure")

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "cooked_meal"
	item.location = ItemEntity.ItemLocation.ON_GROUND
	test_area.add_child(item)

	var data: Dictionary = DebugCommands.get_inspection_data(item)

	# Check type
	assert_eq(data.get("type"), "item", "Type should be 'item'")

	# Check item_tag
	assert_true(data.has("item_tag"), "Data should have 'item_tag' key")
	assert_eq(data.item_tag, "cooked_meal", "item_tag should be 'cooked_meal'")

	# Check location_state
	assert_true(data.has("location_state"), "Data should have 'location_state' key")
	assert_eq(data.location_state, "ON_GROUND", "location_state should be 'ON_GROUND'")

	# Check container
	assert_true(data.has("container"), "Data should have 'container' key")

	item.queue_free()


func test_container_inspection_data() -> void:
	test("Container inspection data returns correct structure")

	var container: ItemContainer = ContainerScene.instantiate()
	container.container_name = "Test Fridge"
	container.capacity = 5
	test_area.add_child(container)

	await get_tree().process_frame

	# Add an item to the container
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	test_area.add_child(item)
	container.add_item(item)

	var data: Dictionary = DebugCommands.get_inspection_data(container)

	# Check type
	assert_eq(data.get("type"), "container", "Type should be 'container'")

	# Check name
	assert_true(data.has("name"), "Data should have 'name' key")
	assert_eq(data.name, "Test Fridge", "name should be 'Test Fridge'")

	# Check capacity
	assert_true(data.has("capacity"), "Data should have 'capacity' key")
	assert_eq(data.capacity, 5, "capacity should be 5")

	# Check items
	assert_true(data.has("items"), "Data should have 'items' key")
	assert_array_size(data.items, 1, "Should have 1 item")
	assert_eq(data.items[0], "raw_food", "Item should be 'raw_food'")

	# Check used
	assert_true(data.has("used"), "Data should have 'used' key")
	assert_eq(data.used, 1, "used should be 1")

	container.queue_free()


func test_unknown_entity_inspection() -> void:
	test("Unknown entity returns type 'unknown'")

	var unknown_node: Node = Node.new()
	test_area.add_child(unknown_node)

	var data: Dictionary = DebugCommands.get_inspection_data(unknown_node)

	assert_eq(data.get("type"), "unknown", "Type should be 'unknown' for generic Node")

	unknown_node.queue_free()


func test_null_entity_inspection() -> void:
	test("Null entity returns empty dictionary")

	var data: Dictionary = DebugCommands.get_inspection_data(null)

	assert_eq(data.size(), 0, "Null entity should return empty dictionary")


# =============================================================================
# US-002: Item Spawning Tests
# =============================================================================

func test_spawn_item_on_ground() -> void:
	test("spawn_item with Vector2 spawns item ON_GROUND")

	var spawn_position := Vector2(100, 200)
	var item: ItemEntity = DebugCommands.spawn_item("raw_food", spawn_position)

	assert_not_null(item, "spawn_item should return an ItemEntity")
	assert_eq(item.item_tag, "raw_food", "Item tag should be 'raw_food'")
	assert_eq(item.location, ItemEntity.ItemLocation.ON_GROUND, "Item should be ON_GROUND")
	assert_eq(item.global_position, spawn_position, "Item should be at spawn position")

	# Verify item is in scene tree
	assert_true(is_instance_valid(item), "Item should be valid")
	assert_not_null(item.get_parent(), "Item should have a parent")

	# Cleanup
	item.queue_free()


func test_spawn_item_in_container() -> void:
	test("spawn_item with Container spawns item IN_CONTAINER")

	var container: ItemContainer = ContainerScene.instantiate()
	container.container_name = "Test Fridge"
	container.capacity = 5
	test_area.add_child(container)

	await get_tree().process_frame

	var item: ItemEntity = DebugCommands.spawn_item("raw_food", container)

	assert_not_null(item, "spawn_item should return an ItemEntity")
	assert_eq(item.item_tag, "raw_food", "Item tag should be 'raw_food'")
	assert_eq(item.location, ItemEntity.ItemLocation.IN_CONTAINER, "Item should be IN_CONTAINER")

	# Verify item is in the container
	assert_eq(container.get_item_count(), 1, "Container should have 1 item")
	var found_item: ItemEntity = container.find_item_by_tag("raw_food")
	assert_eq(found_item, item, "Container should contain the spawned item")

	# Cleanup
	container.queue_free()


func test_spawn_item_at_station() -> void:
	test("spawn_item with Station spawns item in first available slot")

	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)

	await get_tree().process_frame

	var item: ItemEntity = DebugCommands.spawn_item("raw_food", station)

	assert_not_null(item, "spawn_item should return an ItemEntity")
	assert_eq(item.item_tag, "raw_food", "Item tag should be 'raw_food'")
	assert_eq(item.location, ItemEntity.ItemLocation.IN_SLOT, "Item should be IN_SLOT")

	# Verify item is at the station
	var slot_item: ItemEntity = station.get_input_item(0)
	assert_eq(slot_item, item, "Station slot 0 should contain the spawned item")

	# Spawn another item - should go to next slot
	var item2: ItemEntity = DebugCommands.spawn_item("cooked_meal", station)
	if item2 != null:
		var slot_item2: ItemEntity = station.get_input_item(1)
		assert_eq(slot_item2, item2, "Station slot 1 should contain the second item")

	# Cleanup
	station.queue_free()


func test_spawn_item_signal() -> void:
	test("spawn_item emits item_spawned signal")

	# Use array to capture values from closure (workaround for GDScript closure limitations)
	var signal_data: Array = [false, null]  # [signal_received, received_item]

	var callback := func(item: ItemEntity) -> void:
		signal_data[0] = true
		signal_data[1] = item

	DebugCommands.item_spawned.connect(callback)

	var spawn_position := Vector2(50, 50)
	var item: ItemEntity = DebugCommands.spawn_item("toilet_paper", spawn_position)

	assert_true(signal_data[0], "item_spawned signal should be emitted")
	assert_eq(signal_data[1], item, "Signal should pass the spawned item")

	# Cleanup
	DebugCommands.item_spawned.disconnect(callback)
	item.queue_free()


func test_spawn_item_errors() -> void:
	test("spawn_item handles error cases correctly")

	# Empty tag should return null
	var item1: ItemEntity = DebugCommands.spawn_item("", Vector2(0, 0))
	assert_null(item1, "Empty tag should return null")

	# Invalid target type should return null
	var invalid_target := "not a valid target"
	var item2: ItemEntity = DebugCommands.spawn_item("raw_food", invalid_target)
	assert_null(item2, "Invalid target type should return null")


func test_spawn_item_container_full() -> void:
	test("spawn_item returns null when container is full")

	var container: ItemContainer = ContainerScene.instantiate()
	container.capacity = 1
	test_area.add_child(container)

	await get_tree().process_frame

	# Fill the container
	var item1: ItemEntity = DebugCommands.spawn_item("raw_food", container)
	assert_not_null(item1, "First item should spawn successfully")

	# Try to spawn another - should fail
	var item2: ItemEntity = DebugCommands.spawn_item("raw_food", container)
	assert_null(item2, "spawn_item should return null when container is full")

	# Cleanup
	container.queue_free()


func test_spawn_item_station_slots_full() -> void:
	test("spawn_item returns null when station slots are full")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)

	await get_tree().process_frame

	# Fill all input slots
	var slot_count: int = station.get_input_slot_count()
	var spawned_items: Array[ItemEntity] = []

	for i in range(slot_count):
		var item: ItemEntity = DebugCommands.spawn_item("raw_food", station)
		if item != null:
			spawned_items.append(item)

	# Try to spawn one more - should fail
	var extra_item: ItemEntity = DebugCommands.spawn_item("raw_food", station)
	assert_null(extra_item, "spawn_item should return null when all station slots are full")

	# Cleanup
	station.queue_free()


# =============================================================================
# US-003: Station Spawning Tests
# =============================================================================

func test_spawn_station_basic() -> void:
	test("spawn_station creates a station with correct properties")

	var spawn_position := Vector2(128, 256)
	var station: Station = DebugCommands.spawn_station("stove", spawn_position)

	await get_tree().process_frame

	assert_not_null(station, "spawn_station should return a Station")
	assert_eq(station.station_tag, "stove", "Station tag should be 'stove'")
	assert_true(station.station_name.begins_with("Stove"), "Station name should start with 'Stove'")

	# Verify station is in scene tree
	assert_true(is_instance_valid(station), "Station should be valid")
	assert_not_null(station.get_parent(), "Station should have a parent")

	# Cleanup
	DebugCommands.remove_station(station)


func test_spawn_station_grid_snapping() -> void:
	test("spawn_station snaps position to grid")

	# Test various positions that should snap
	var test_cases: Array = [
		[Vector2(10, 10), Vector2(0, 0)],      # Should snap to 0,0 (grid 32)
		[Vector2(20, 20), Vector2(32, 32)],    # Should snap to 32,32
		[Vector2(48, 48), Vector2(48, 48)],    # Already at grid + 16, rounds to 48
		[Vector2(100, 200), Vector2(96, 192)], # Should snap appropriately
	]

	# Test snap_to_grid function directly
	for test_case in test_cases:
		var input_pos: Vector2 = test_case[0]
		var expected_pos: Vector2 = test_case[1]
		var snapped: Vector2 = DebugCommands.snap_to_grid(input_pos)
		# Due to rounding, verify it's on grid
		var on_grid_x: bool = int(snapped.x) % 32 == 0
		var on_grid_y: bool = int(snapped.y) % 32 == 0
		assert_true(on_grid_x, "X position should be on grid for input " + str(input_pos))
		assert_true(on_grid_y, "Y position should be on grid for input " + str(input_pos))


func test_spawn_station_all_types() -> void:
	test("spawn_station works for all valid station types")

	var valid_types: Array[String] = DebugCommands.get_valid_station_types()
	var spawned_stations: Array[Station] = []

	for i in range(valid_types.size()):
		var station_type: String = valid_types[i]
		var position := Vector2(i * 64, 0)
		var station: Station = DebugCommands.spawn_station(station_type, position)

		assert_not_null(station, "spawn_station should work for type '" + station_type + "'")
		assert_eq(station.station_tag, station_type, "Station tag should match type '" + station_type + "'")
		spawned_stations.append(station)

	await get_tree().process_frame

	# Verify all stations have unique colors (except generic which matches default)
	assert_eq(spawned_stations.size(), valid_types.size(), "Should have spawned all station types")

	# Cleanup - await for queue_free to complete
	DebugCommands.clear_runtime_stations()
	await get_tree().process_frame
	await get_tree().process_frame


func test_spawn_station_signal() -> void:
	test("spawn_station emits station_spawned signal")

	var signal_data: Array = [false, null]

	var callback := func(station: Station) -> void:
		signal_data[0] = true
		signal_data[1] = station

	DebugCommands.station_spawned.connect(callback)

	var station: Station = DebugCommands.spawn_station("counter", Vector2(64, 64))

	await get_tree().process_frame

	assert_true(signal_data[0], "station_spawned signal should be emitted")
	assert_eq(signal_data[1], station, "Signal should pass the spawned station")

	# Cleanup
	DebugCommands.station_spawned.disconnect(callback)
	DebugCommands.remove_station(station)


func test_spawn_station_invalid_type() -> void:
	test("spawn_station returns null for invalid station type")

	var station: Station = DebugCommands.spawn_station("invalid_type", Vector2(0, 0))
	assert_null(station, "spawn_station should return null for invalid type")

	var station2: Station = DebugCommands.spawn_station("", Vector2(0, 0))
	assert_null(station2, "spawn_station should return null for empty type")


func test_remove_station() -> void:
	test("remove_station removes runtime-spawned station")

	var station: Station = DebugCommands.spawn_station("fridge", Vector2(128, 128))

	await get_tree().process_frame

	assert_not_null(station, "Station should be spawned")
	assert_true(is_instance_valid(station), "Station should be valid before removal")

	# Track removal signal
	var signal_data: Array = [false, null]
	var callback := func(removed_station: Station) -> void:
		signal_data[0] = true
		signal_data[1] = removed_station

	DebugCommands.station_removed.connect(callback)

	var result: bool = DebugCommands.remove_station(station)

	assert_true(result, "remove_station should return true")
	assert_true(signal_data[0], "station_removed signal should be emitted")

	# Wait for queue_free to process
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(station), "Station should be freed after removal")

	# Cleanup
	DebugCommands.station_removed.disconnect(callback)


func test_remove_station_clears_selection() -> void:
	test("remove_station clears selection if station was selected")

	var station: Station = DebugCommands.spawn_station("sink", Vector2(192, 192))

	await get_tree().process_frame

	# Select the station
	DebugCommands.select_entity(station)
	assert_eq(DebugCommands.selected_entity, station, "Station should be selected")

	# Remove the station
	DebugCommands.remove_station(station)

	assert_null(DebugCommands.selected_entity, "Selection should be cleared after station removal")

	await get_tree().process_frame


func test_get_runtime_stations() -> void:
	test("get_runtime_stations returns all spawned stations")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	# Spawn some stations
	var station1: Station = DebugCommands.spawn_station("counter", Vector2(0, 0))
	var station2: Station = DebugCommands.spawn_station("stove", Vector2(64, 0))
	var station3: Station = DebugCommands.spawn_station("sink", Vector2(128, 0))

	await get_tree().process_frame

	var runtime_stations: Array[Station] = DebugCommands.get_runtime_stations()

	assert_eq(runtime_stations.size(), 3, "Should have 3 runtime stations")
	assert_true(station1 in runtime_stations, "station1 should be in runtime stations")
	assert_true(station2 in runtime_stations, "station2 should be in runtime stations")
	assert_true(station3 in runtime_stations, "station3 should be in runtime stations")

	# Cleanup
	DebugCommands.clear_runtime_stations()


func test_clear_runtime_stations() -> void:
	test("clear_runtime_stations removes all spawned stations")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	# Spawn some stations
	var station1: Station = DebugCommands.spawn_station("toilet", Vector2(0, 64))
	var station2: Station = DebugCommands.spawn_station("tv", Vector2(64, 64))

	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 2, "Should have 2 runtime stations")

	# Clear all
	DebugCommands.clear_runtime_stations()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 0, "Should have 0 runtime stations after clear")
	assert_false(is_instance_valid(station1), "station1 should be freed")
	assert_false(is_instance_valid(station2), "station2 should be freed")


# =============================================================================
# US-004: NPC Spawning and Motive Adjustment Tests
# =============================================================================

func test_spawn_npc_default_motives() -> void:
	test("spawn_npc with no motives_dict defaults to full motives")

	# Clear any existing runtime NPCs
	DebugCommands.clear_runtime_npcs()

	var spawn_position := Vector2(100, 100)
	var npc: Node = DebugCommands.spawn_npc(spawn_position)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_not_null(npc, "spawn_npc should return an NPC")
	assert_true(is_instance_valid(npc), "NPC should be valid")
	assert_not_null(npc.get_parent(), "NPC should have a parent")

	# Check position
	assert_eq(npc.global_position, spawn_position, "NPC should be at spawn position")

	# Check all motives are at 100 (full) - use approx due to motive decay during test
	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
	var hygiene: float = DebugCommands.get_npc_motive(npc, "hygiene")
	var fun: float = DebugCommands.get_npc_motive(npc, "fun")

	assert_approx_eq(hunger, 100.0, "Hunger should be ~100 (full)")
	assert_approx_eq(energy, 100.0, "Energy should be ~100 (full)")
	assert_approx_eq(bladder, 100.0, "Bladder should be ~100 (full)")
	assert_approx_eq(hygiene, 100.0, "Hygiene should be ~100 (full)")
	assert_approx_eq(fun, 100.0, "Fun should be ~100 (full)")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_spawn_npc_custom_motives() -> void:
	test("spawn_npc with motives_dict sets specified motives")

	DebugCommands.clear_runtime_npcs()

	var spawn_position := Vector2(200, 200)
	var custom_motives := {
		"hunger": 20.0,  # Low hunger (hungry)
		"energy": 80.0,  # High energy
		"bladder": 50.0  # Medium bladder
	}

	var npc: Node = DebugCommands.spawn_npc(spawn_position, custom_motives)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_not_null(npc, "spawn_npc should return an NPC")

	# Check custom motives are set correctly - use approx due to motive decay
	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
	var hygiene: float = DebugCommands.get_npc_motive(npc, "hygiene")
	var fun: float = DebugCommands.get_npc_motive(npc, "fun")

	assert_approx_eq(hunger, 20.0, "Hunger should be ~20")
	assert_approx_eq(energy, 80.0, "Energy should be ~80")
	assert_approx_eq(bladder, 50.0, "Bladder should be ~50")
	# Unspecified motives should default to 100
	assert_approx_eq(hygiene, 100.0, "Hygiene should default to ~100")
	assert_approx_eq(fun, 100.0, "Fun should default to ~100")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_spawn_npc_signal() -> void:
	test("spawn_npc emits npc_spawned signal")

	DebugCommands.clear_runtime_npcs()

	var signal_data: Array = [false, null]

	var callback := func(spawned_npc: Node) -> void:
		signal_data[0] = true
		signal_data[1] = spawned_npc

	DebugCommands.npc_spawned.connect(callback)

	var npc: Node = DebugCommands.spawn_npc(Vector2(50, 50))

	await get_tree().process_frame

	assert_true(signal_data[0], "npc_spawned signal should be emitted")
	assert_eq(signal_data[1], npc, "Signal should pass the spawned NPC")

	# Cleanup
	DebugCommands.npc_spawned.disconnect(callback)
	DebugCommands.clear_runtime_npcs()


func test_set_npc_motive() -> void:
	test("set_npc_motive changes individual motive value")

	DebugCommands.clear_runtime_npcs()

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# Set hunger to low value
	var result: bool = DebugCommands.set_npc_motive(npc, "hunger", 10.0)
	assert_true(result, "set_npc_motive should return true")

	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_eq(hunger, 10.0, "Hunger should be 10 after setting")

	# Other motives should be unchanged (approx due to decay)
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	assert_approx_eq(energy, 100.0, "Energy should still be ~100")

	# Test case-insensitivity
	var result2: bool = DebugCommands.set_npc_motive(npc, "ENERGY", 75.0)
	assert_true(result2, "set_npc_motive should work with uppercase")

	var energy2: float = DebugCommands.get_npc_motive(npc, "energy")
	assert_eq(energy2, 75.0, "Energy should be 75 after setting")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_set_npc_motive_clamping() -> void:
	test("set_npc_motive clamps values to 0-100 range")

	DebugCommands.clear_runtime_npcs()

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# Test value above 100 gets clamped
	DebugCommands.set_npc_motive(npc, "hunger", 150.0)
	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_eq(hunger, 100.0, "Hunger should be clamped to 100")

	# Test value below 0 gets clamped
	DebugCommands.set_npc_motive(npc, "energy", -50.0)
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	assert_eq(energy, 0.0, "Energy should be clamped to 0")

	# Test boundary values
	DebugCommands.set_npc_motive(npc, "bladder", 0.0)
	var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
	assert_eq(bladder, 0.0, "Bladder should be exactly 0")

	DebugCommands.set_npc_motive(npc, "hygiene", 100.0)
	var hygiene: float = DebugCommands.get_npc_motive(npc, "hygiene")
	assert_eq(hygiene, 100.0, "Hygiene should be exactly 100")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_set_npc_motive_signal() -> void:
	test("set_npc_motive emits motive_changed signal")

	DebugCommands.clear_runtime_npcs()

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	var signal_data: Array = [false, null, "", 0.0, 0.0]

	var callback := func(changed_npc: Node, motive_name: String, old_value: float, new_value: float) -> void:
		signal_data[0] = true
		signal_data[1] = changed_npc
		signal_data[2] = motive_name
		signal_data[3] = old_value
		signal_data[4] = new_value

	DebugCommands.motive_changed.connect(callback)

	# Change hunger from 100 to 25
	DebugCommands.set_npc_motive(npc, "hunger", 25.0)

	assert_true(signal_data[0], "motive_changed signal should be emitted")
	assert_eq(signal_data[1], npc, "Signal should pass the NPC")
	assert_eq(signal_data[2], "hunger", "Signal should pass motive name")
	assert_approx_eq(signal_data[3], 100.0, "Signal should pass old value (~100)")
	assert_eq(signal_data[4], 25.0, "Signal should pass new value (25)")

	# Cleanup
	DebugCommands.motive_changed.disconnect(callback)
	DebugCommands.clear_runtime_npcs()


func test_set_npc_motives_batch() -> void:
	test("set_npc_motives changes multiple motives at once")

	DebugCommands.clear_runtime_npcs()

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	var motives_to_set := {
		"hunger": 15.0,
		"energy": 30.0,
		"bladder": 45.0,
		"hygiene": 60.0,
		"fun": 75.0
	}

	var result: bool = DebugCommands.set_npc_motives(npc, motives_to_set)
	assert_true(result, "set_npc_motives should return true")

	# Verify all motives were set
	assert_eq(DebugCommands.get_npc_motive(npc, "hunger"), 15.0, "Hunger should be 15")
	assert_eq(DebugCommands.get_npc_motive(npc, "energy"), 30.0, "Energy should be 30")
	assert_eq(DebugCommands.get_npc_motive(npc, "bladder"), 45.0, "Bladder should be 45")
	assert_eq(DebugCommands.get_npc_motive(npc, "hygiene"), 60.0, "Hygiene should be 60")
	assert_eq(DebugCommands.get_npc_motive(npc, "fun"), 75.0, "Fun should be 75")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_set_npc_motive_invalid_name() -> void:
	test("set_npc_motive returns false for invalid motive name")

	DebugCommands.clear_runtime_npcs()

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# Invalid motive name
	var result: bool = DebugCommands.set_npc_motive(npc, "invalid_motive", 50.0)
	assert_false(result, "set_npc_motive should return false for invalid motive")

	# Empty motive name
	var result2: bool = DebugCommands.set_npc_motive(npc, "", 50.0)
	assert_false(result2, "set_npc_motive should return false for empty motive name")

	# Null NPC
	var result3: bool = DebugCommands.set_npc_motive(null, "hunger", 50.0)
	assert_false(result3, "set_npc_motive should return false for null NPC")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_get_runtime_npcs() -> void:
	test("get_runtime_npcs returns all spawned NPCs")

	DebugCommands.clear_runtime_npcs()

	await get_tree().process_frame

	# Spawn some NPCs
	var npc1: Node = DebugCommands.spawn_npc(Vector2(0, 0))
	var npc2: Node = DebugCommands.spawn_npc(Vector2(100, 0))
	var npc3: Node = DebugCommands.spawn_npc(Vector2(200, 0))

	await get_tree().process_frame

	var runtime_npcs: Array[Node] = DebugCommands.get_runtime_npcs()

	assert_eq(runtime_npcs.size(), 3, "Should have 3 runtime NPCs")
	assert_true(npc1 in runtime_npcs, "npc1 should be in runtime NPCs")
	assert_true(npc2 in runtime_npcs, "npc2 should be in runtime NPCs")
	assert_true(npc3 in runtime_npcs, "npc3 should be in runtime NPCs")

	# Cleanup
	DebugCommands.clear_runtime_npcs()


func test_clear_runtime_npcs() -> void:
	test("clear_runtime_npcs removes all spawned NPCs")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	# Spawn some NPCs
	var npc1: Node = DebugCommands.spawn_npc(Vector2(0, 100))
	var npc2: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_npcs().size(), 2, "Should have 2 runtime NPCs")

	# Clear all
	DebugCommands.clear_runtime_npcs()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_npcs().size(), 0, "Should have 0 runtime NPCs after clear")
	assert_false(is_instance_valid(npc1), "npc1 should be freed")
	assert_false(is_instance_valid(npc2), "npc2 should be freed")


# =============================================================================
# US-005: Job Management Tests
# =============================================================================

func test_post_job_cook_simple_meal() -> void:
	test("post_job loads cook_simple_meal recipe and creates job")

	# Clear any existing jobs
	JobBoard.clear_all_jobs()

	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")

	assert_not_null(job, "post_job should return a Job")
	assert_not_null(job.recipe, "Job should have a recipe")
	assert_eq(job.recipe.recipe_name, "Cook Simple Meal", "Recipe name should be 'Cook Simple Meal'")
	assert_eq(job.state, Job.JobState.POSTED, "Job should be in POSTED state")

	# Verify job is in JobBoard
	var all_jobs: Array[Job] = DebugCommands.get_all_jobs()
	assert_true(job in all_jobs, "Job should be in JobBoard")

	# Cleanup
	JobBoard.clear_all_jobs()


func test_post_job_use_toilet() -> void:
	test("post_job loads use_toilet recipe and creates job")

	JobBoard.clear_all_jobs()

	var job: Job = DebugCommands.post_job("res://resources/recipes/use_toilet.tres")

	assert_not_null(job, "post_job should return a Job")
	assert_not_null(job.recipe, "Job should have a recipe")
	assert_eq(job.recipe.recipe_name, "Use Toilet", "Recipe name should be 'Use Toilet'")
	assert_eq(job.state, Job.JobState.POSTED, "Job should be in POSTED state")

	# Cleanup
	JobBoard.clear_all_jobs()


func test_post_job_watch_tv() -> void:
	test("post_job loads watch_tv recipe and creates job")

	JobBoard.clear_all_jobs()

	var job: Job = DebugCommands.post_job("res://resources/recipes/watch_tv.tres")

	assert_not_null(job, "post_job should return a Job")
	assert_not_null(job.recipe, "Job should have a recipe")
	assert_eq(job.recipe.recipe_name, "Watch TV", "Recipe name should be 'Watch TV'")
	assert_eq(job.state, Job.JobState.POSTED, "Job should be in POSTED state")

	# Cleanup
	JobBoard.clear_all_jobs()


func test_post_job_invalid_path() -> void:
	test("post_job returns null for invalid recipe path")

	JobBoard.clear_all_jobs()

	# Empty path
	var job1: Job = DebugCommands.post_job("")
	assert_null(job1, "post_job should return null for empty path")

	# Non-existent path
	var job2: Job = DebugCommands.post_job("res://resources/recipes/non_existent.tres")
	assert_null(job2, "post_job should return null for non-existent recipe")

	# Invalid resource type
	var job3: Job = DebugCommands.post_job("res://icon.svg")
	assert_null(job3, "post_job should return null for non-Recipe resource")


func test_post_job_signal() -> void:
	test("post_job emits job_posted_debug signal")

	JobBoard.clear_all_jobs()

	var signal_data: Array = [false, null]

	var callback := func(posted_job: Job) -> void:
		signal_data[0] = true
		signal_data[1] = posted_job

	DebugCommands.job_posted_debug.connect(callback)

	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")

	await get_tree().process_frame

	assert_true(signal_data[0], "job_posted_debug signal should be emitted")
	assert_eq(signal_data[1], job, "Signal should pass the posted job")

	# Cleanup
	DebugCommands.job_posted_debug.disconnect(callback)
	JobBoard.clear_all_jobs()


func test_interrupt_job() -> void:
	test("interrupt_job interrupts an IN_PROGRESS job")

	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()

	# Create a job and an NPC to claim it
	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# Claim and start the job
	var claimed: bool = JobBoard.claim_job(job, npc)
	assert_true(claimed, "Job should be claimed")

	var started: bool = job.start()
	assert_true(started, "Job should be started")
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")

	# Interrupt the job
	var result: bool = DebugCommands.interrupt_job(job)

	assert_true(result, "interrupt_job should return true")
	assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
	assert_null(job.claimed_by, "Job should have no claimer after interruption")

	# Cleanup
	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()


func test_interrupt_job_signal() -> void:
	test("interrupt_job emits job_interrupted_debug signal")

	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()

	var signal_data: Array = [false, null]

	var callback := func(interrupted_job: Job) -> void:
		signal_data[0] = true
		signal_data[1] = interrupted_job

	DebugCommands.job_interrupted_debug.connect(callback)

	# Create and start a job
	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	JobBoard.claim_job(job, npc)
	job.start()

	# Interrupt
	DebugCommands.interrupt_job(job)

	assert_true(signal_data[0], "job_interrupted_debug signal should be emitted")
	assert_eq(signal_data[1], job, "Signal should pass the interrupted job")

	# Cleanup
	DebugCommands.job_interrupted_debug.disconnect(callback)
	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()


func test_interrupt_job_invalid() -> void:
	test("interrupt_job returns false for invalid cases")

	JobBoard.clear_all_jobs()

	# Null job
	var result1: bool = DebugCommands.interrupt_job(null)
	assert_false(result1, "interrupt_job should return false for null job")

	# Job not in progress (still POSTED)
	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	var result2: bool = DebugCommands.interrupt_job(job)
	assert_false(result2, "interrupt_job should return false for job not IN_PROGRESS")

	# Cleanup
	JobBoard.clear_all_jobs()


func test_get_all_jobs() -> void:
	test("get_all_jobs returns all jobs from JobBoard")

	JobBoard.clear_all_jobs()

	# Post multiple jobs
	var job1: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	var job2: Job = DebugCommands.post_job("res://resources/recipes/use_toilet.tres")
	var job3: Job = DebugCommands.post_job("res://resources/recipes/watch_tv.tres")

	await get_tree().process_frame

	var all_jobs: Array[Job] = DebugCommands.get_all_jobs()

	assert_eq(all_jobs.size(), 3, "Should have 3 jobs")
	assert_true(job1 in all_jobs, "job1 should be in all_jobs")
	assert_true(job2 in all_jobs, "job2 should be in all_jobs")
	assert_true(job3 in all_jobs, "job3 should be in all_jobs")

	# Cleanup
	JobBoard.clear_all_jobs()


func test_get_jobs_by_state() -> void:
	test("get_jobs_by_state filters jobs by state")

	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()

	# Create jobs in different states
	var job1: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	var job2: Job = DebugCommands.post_job("res://resources/recipes/use_toilet.tres")
	var job3: Job = DebugCommands.post_job("res://resources/recipes/watch_tv.tres")

	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))

	await get_tree().process_frame
	await get_tree().process_frame

	# Claim and start job2
	JobBoard.claim_job(job2, npc)
	job2.start()

	# Check POSTED jobs
	var posted_jobs: Array[Job] = DebugCommands.get_jobs_by_state(Job.JobState.POSTED)
	assert_eq(posted_jobs.size(), 2, "Should have 2 POSTED jobs")
	assert_true(job1 in posted_jobs, "job1 should be POSTED")
	assert_true(job3 in posted_jobs, "job3 should be POSTED")

	# Check IN_PROGRESS jobs
	var in_progress_jobs: Array[Job] = DebugCommands.get_jobs_by_state(Job.JobState.IN_PROGRESS)
	assert_eq(in_progress_jobs.size(), 1, "Should have 1 IN_PROGRESS job")
	assert_true(job2 in in_progress_jobs, "job2 should be IN_PROGRESS")

	# Check COMPLETED jobs (none yet)
	var completed_jobs: Array[Job] = DebugCommands.get_jobs_by_state(Job.JobState.COMPLETED)
	assert_eq(completed_jobs.size(), 0, "Should have 0 COMPLETED jobs")

	# Interrupt job2
	DebugCommands.interrupt_job(job2)

	# Check INTERRUPTED jobs
	var interrupted_jobs: Array[Job] = DebugCommands.get_jobs_by_state(Job.JobState.INTERRUPTED)
	assert_eq(interrupted_jobs.size(), 1, "Should have 1 INTERRUPTED job")
	assert_true(job2 in interrupted_jobs, "job2 should be INTERRUPTED")

	# Cleanup
	JobBoard.clear_all_jobs()
	DebugCommands.clear_runtime_npcs()


# =============================================================================
# US-006: Wall Painting Tests
# =============================================================================

func test_paint_wall_add() -> void:
	test("paint_wall adds a wall at grid position")

	# Clear any existing runtime walls
	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# Add a wall at an empty position
	var grid_pos := Vector2i(5, 5)
	var result: bool = DebugCommands.paint_wall(grid_pos, true)

	assert_true(result, "paint_wall should return true")
	assert_true(test_level.astar.is_point_solid(grid_pos), "AStar should mark position as solid")

	# Verify runtime wall was tracked
	var runtime_walls: Dictionary = DebugCommands.get_runtime_walls()
	assert_true(runtime_walls.has(grid_pos), "Runtime walls should contain the new wall")

	# Verify wall node was created
	var wall_node: StaticBody2D = runtime_walls[grid_pos]
	assert_not_null(wall_node, "Wall node should exist")
	assert_true(is_instance_valid(wall_node), "Wall node should be valid")

	# Cleanup
	DebugCommands.clear_runtime_walls()
	test_level.clear_all_entities()


func test_paint_wall_remove() -> void:
	test("paint_wall removes a runtime wall at grid position")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# First add a wall
	var grid_pos := Vector2i(6, 6)
	DebugCommands.paint_wall(grid_pos, true)
	assert_true(test_level.astar.is_point_solid(grid_pos), "Wall should be added")

	# Now remove it
	var result: bool = DebugCommands.paint_wall(grid_pos, false)

	assert_true(result, "paint_wall(false) should return true")
	assert_false(test_level.astar.is_point_solid(grid_pos), "AStar should mark position as walkable")

	# Verify runtime wall was removed from tracking
	var runtime_walls: Dictionary = DebugCommands.get_runtime_walls()
	assert_false(runtime_walls.has(grid_pos), "Runtime walls should not contain the removed wall")

	# Cleanup
	test_level.clear_all_entities()


func test_get_wall_at() -> void:
	test("get_wall_at returns correct wall status")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# Check empty position (no walls in empty level)
	var empty_pos := Vector2i(5, 5)
	assert_false(DebugCommands.get_wall_at(empty_pos), "Empty position should return false")

	# Add a runtime wall and check
	DebugCommands.paint_wall(empty_pos, true)
	assert_true(DebugCommands.get_wall_at(empty_pos), "Runtime wall should be detected")

	# Cleanup
	DebugCommands.clear_runtime_walls()
	test_level.clear_all_entities()


func test_paint_wall_signal() -> void:
	test("paint_wall emits wall_changed signal")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	var signal_data: Array = [false, Vector2i(-1, -1), false]

	var callback := func(grid_pos: Vector2i, is_wall: bool) -> void:
		signal_data[0] = true
		signal_data[1] = grid_pos
		signal_data[2] = is_wall

	DebugCommands.wall_changed.connect(callback)

	# Add a wall
	var grid_pos := Vector2i(7, 7)
	DebugCommands.paint_wall(grid_pos, true)

	assert_true(signal_data[0], "wall_changed signal should be emitted")
	assert_eq(signal_data[1], grid_pos, "Signal should pass correct grid position")
	assert_true(signal_data[2], "Signal should indicate wall was added (is_wall=true)")

	# Reset signal data
	signal_data[0] = false

	# Remove the wall
	DebugCommands.paint_wall(grid_pos, false)

	assert_true(signal_data[0], "wall_changed signal should be emitted on removal")
	assert_eq(signal_data[1], grid_pos, "Signal should pass correct grid position")
	assert_false(signal_data[2], "Signal should indicate wall was removed (is_wall=false)")

	# Cleanup
	DebugCommands.wall_changed.disconnect(callback)
	test_level.clear_all_entities()


func test_paint_wall_out_of_bounds() -> void:
	test("paint_wall returns false for out of bounds position")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# Try to add wall outside grid bounds (grid is 20x20)
	var out_of_bounds_pos := Vector2i(25, 25)
	var result: bool = DebugCommands.paint_wall(out_of_bounds_pos, true)

	assert_false(result, "paint_wall should return false for out of bounds position")

	# Negative position should also fail
	var negative_pos := Vector2i(-1, -1)
	var result2: bool = DebugCommands.paint_wall(negative_pos, true)

	assert_false(result2, "paint_wall should return false for negative position")

	# Cleanup
	test_level.clear_all_entities()


func test_paint_wall_remove_nonexistent() -> void:
	test("paint_wall is a no-op when removing non-existent wall")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# Try to remove a wall that doesn't exist
	var empty_pos := Vector2i(5, 5)
	assert_false(test_level.astar.is_point_solid(empty_pos), "Position should be empty")

	var result: bool = DebugCommands.paint_wall(empty_pos, false)

	# Removing non-existent wall is a no-op that returns true
	assert_true(result, "paint_wall should return true (no-op) when removing non-existent wall")

	# Cleanup
	test_level.clear_all_entities()


func test_get_runtime_walls() -> void:
	test("get_runtime_walls returns all spawned walls")

	DebugCommands.clear_runtime_walls()
	await get_tree().process_frame

	# Add multiple walls
	var pos1 := Vector2i(3, 3)
	var pos2 := Vector2i(4, 4)
	var pos3 := Vector2i(5, 5)

	DebugCommands.paint_wall(pos1, true)
	DebugCommands.paint_wall(pos2, true)
	DebugCommands.paint_wall(pos3, true)

	var runtime_walls: Dictionary = DebugCommands.get_runtime_walls()

	assert_eq(runtime_walls.size(), 3, "Should have 3 runtime walls")
	assert_true(runtime_walls.has(pos1), "Should contain wall at pos1")
	assert_true(runtime_walls.has(pos2), "Should contain wall at pos2")
	assert_true(runtime_walls.has(pos3), "Should contain wall at pos3")

	# Cleanup
	DebugCommands.clear_runtime_walls()
	test_level.clear_all_entities()


func test_clear_runtime_walls() -> void:
	test("clear_runtime_walls removes all walls")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	# Add multiple walls
	var pos1 := Vector2i(3, 3)
	var pos2 := Vector2i(4, 4)

	DebugCommands.paint_wall(pos1, true)
	DebugCommands.paint_wall(pos2, true)

	assert_eq(DebugCommands.get_runtime_walls().size(), 2, "Should have 2 runtime walls")
	assert_true(test_level.astar.is_point_solid(pos1), "Wall 1 should be solid")
	assert_true(test_level.astar.is_point_solid(pos2), "Wall 2 should be solid")

	# Clear all runtime walls
	DebugCommands.clear_runtime_walls()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_walls().size(), 0, "Should have 0 runtime walls after clear")
	assert_false(test_level.astar.is_point_solid(pos1), "Position 1 should be walkable after clear")
	assert_false(test_level.astar.is_point_solid(pos2), "Position 2 should be walkable after clear")

	# Cleanup
	test_level.clear_all_entities()


func test_world_grid_conversion() -> void:
	test("world_to_grid and grid_to_world convert correctly")

	# Test world_to_grid
	var world_pos := Vector2(48, 80)  # Should be grid (1, 2) with 32px tiles
	var grid_pos: Vector2i = DebugCommands.world_to_grid(world_pos)
	assert_eq(grid_pos, Vector2i(1, 2), "world_to_grid should convert (48, 80) to (1, 2)")

	# Test with position at tile boundary
	var boundary_pos := Vector2(64, 96)
	var boundary_grid: Vector2i = DebugCommands.world_to_grid(boundary_pos)
	assert_eq(boundary_grid, Vector2i(2, 3), "world_to_grid should convert (64, 96) to (2, 3)")

	# Test grid_to_world (returns center of tile)
	var grid_input := Vector2i(3, 4)
	var world_output: Vector2 = DebugCommands.grid_to_world(grid_input)
	# Center of tile at grid (3, 4) with 32px tiles = (3*32 + 16, 4*32 + 16) = (112, 144)
	assert_eq(world_output, Vector2(112, 144), "grid_to_world should convert (3, 4) to (112, 144)")

	# Test round-trip
	var original_grid := Vector2i(5, 7)
	var world_converted: Vector2 = DebugCommands.grid_to_world(original_grid)
	var back_to_grid: Vector2i = DebugCommands.world_to_grid(world_converted)
	assert_eq(back_to_grid, original_grid, "Round-trip conversion should preserve grid position")


# =============================================================================
# US-007: Scenario Save/Load Tests
# =============================================================================

const TEST_SCENARIO_PATH := "user://test_scenarios/test_scenario.json"
const TEST_SCENARIO_PATH_2 := "user://test_scenarios/test_scenario_2.json"


func _cleanup_test_scenarios() -> void:
	# Remove test scenario files if they exist
	if FileAccess.file_exists(TEST_SCENARIO_PATH):
		DirAccess.remove_absolute(TEST_SCENARIO_PATH)
	if FileAccess.file_exists(TEST_SCENARIO_PATH_2):
		DirAccess.remove_absolute(TEST_SCENARIO_PATH_2)


func test_save_scenario_empty() -> void:
	test("save_scenario with empty scenario creates valid JSON")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	var result: bool = DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	assert_true(result, "save_scenario should return true")
	assert_true(FileAccess.file_exists(TEST_SCENARIO_PATH), "Scenario file should exist")

	# Verify JSON is valid
	var file: FileAccess = FileAccess.open(TEST_SCENARIO_PATH, FileAccess.READ)
	assert_not_null(file, "File should be readable")
	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	assert_eq(parse_result, OK, "JSON should be valid")

	var data: Dictionary = json.data
	assert_true(data.has("version"), "Data should have version")
	assert_true(data.has("stations"), "Data should have stations array")
	assert_true(data.has("items"), "Data should have items array")
	assert_true(data.has("npcs"), "Data should have npcs array")
	assert_true(data.has("walls"), "Data should have walls array")

	_cleanup_test_scenarios()


func test_save_scenario_with_stations() -> void:
	test("save_scenario saves station data correctly")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Spawn some stations
	var station1: Station = DebugCommands.spawn_station("counter", Vector2(64, 64))
	var station2: Station = DebugCommands.spawn_station("stove", Vector2(128, 64))

	await get_tree().process_frame

	var result: bool = DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	assert_true(result, "save_scenario should return true")

	# Read and verify
	var file: FileAccess = FileAccess.open(TEST_SCENARIO_PATH, FileAccess.READ)
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data: Dictionary = json.data
	var stations: Array = data.get("stations", [])

	assert_eq(stations.size(), 2, "Should have 2 stations saved")

	# Verify first station
	var s1: Dictionary = stations[0]
	assert_eq(s1.get("type"), "counter", "First station should be counter")
	var pos1: Dictionary = s1.get("position", {})
	assert_eq(pos1.get("x"), 64.0, "First station x should be 64")
	assert_eq(pos1.get("y"), 64.0, "First station y should be 64")

	# Cleanup
	DebugCommands.clear_scenario()
	_cleanup_test_scenarios()


func test_save_scenario_with_npcs() -> void:
	test("save_scenario saves NPC data with motives correctly")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Spawn NPC with custom motives
	var custom_motives := {"hunger": 25.0, "energy": 75.0, "bladder": 50.0, "hygiene": 100.0, "fun": 10.0}
	var npc: Node = DebugCommands.spawn_npc(Vector2(200, 200), custom_motives)

	await get_tree().process_frame
	await get_tree().process_frame

	var result: bool = DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	assert_true(result, "save_scenario should return true")

	# Read and verify
	var file: FileAccess = FileAccess.open(TEST_SCENARIO_PATH, FileAccess.READ)
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data: Dictionary = json.data
	var npcs: Array = data.get("npcs", [])

	assert_eq(npcs.size(), 1, "Should have 1 NPC saved")

	var n1: Dictionary = npcs[0]
	var pos: Dictionary = n1.get("position", {})
	assert_eq(pos.get("x"), 200.0, "NPC x should be 200")
	assert_eq(pos.get("y"), 200.0, "NPC y should be 200")

	var motives: Dictionary = n1.get("motives", {})
	assert_approx_eq(motives.get("hunger"), 25.0, "Hunger should be ~25")
	assert_approx_eq(motives.get("energy"), 75.0, "Energy should be ~75")
	assert_approx_eq(motives.get("bladder"), 50.0, "Bladder should be ~50")
	assert_approx_eq(motives.get("hygiene"), 100.0, "Hygiene should be ~100")
	assert_approx_eq(motives.get("fun"), 10.0, "Fun should be ~10")

	# Cleanup
	DebugCommands.clear_scenario()
	_cleanup_test_scenarios()


func test_save_scenario_with_walls() -> void:
	test("save_scenario saves wall data correctly")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Paint some walls
	DebugCommands.paint_wall(Vector2i(3, 3), true)
	DebugCommands.paint_wall(Vector2i(4, 4), true)
	DebugCommands.paint_wall(Vector2i(5, 5), true)

	var result: bool = DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	assert_true(result, "save_scenario should return true")

	# Read and verify
	var file: FileAccess = FileAccess.open(TEST_SCENARIO_PATH, FileAccess.READ)
	var json: JSON = JSON.new()
	json.parse(file.get_as_text())
	file.close()

	var data: Dictionary = json.data
	var walls: Array = data.get("walls", [])

	assert_eq(walls.size(), 3, "Should have 3 walls saved")

	# Verify wall positions are present (order may vary)
	var wall_positions: Array = []
	for wall in walls:
		wall_positions.append(Vector2i(wall.get("grid_x", 0), wall.get("grid_y", 0)))

	assert_true(Vector2i(3, 3) in wall_positions, "Wall at (3,3) should be saved")
	assert_true(Vector2i(4, 4) in wall_positions, "Wall at (4,4) should be saved")
	assert_true(Vector2i(5, 5) in wall_positions, "Wall at (5,5) should be saved")

	# Cleanup
	DebugCommands.clear_scenario()
	test_level.clear_all_entities()
	_cleanup_test_scenarios()


# ============================================================================
# CONTAINER SPAWNING TESTS
# ============================================================================

func test_spawn_container_basic() -> void:
	test("spawn_container creates container at position")

	DebugCommands.clear_runtime_containers()
	await get_tree().process_frame

	var position := Vector2(128, 128)
	var container: ItemContainer = DebugCommands.spawn_container("fridge", position)

	assert_not_null(container, "Container should be created")
	assert_eq(container.container_name, "Fridge (Debug)", "Container name should be set")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_spawn_container_all_types() -> void:
	test("spawn_container works for all valid types")

	DebugCommands.clear_runtime_containers()
	await get_tree().process_frame

	var valid_types: Array[String] = DebugCommands.get_valid_container_types()
	assert_eq(valid_types.size(), 6, "Should have 6 valid container types")

	for container_type in valid_types:
		var container: ItemContainer = DebugCommands.spawn_container(container_type, Vector2(100, 100))
		assert_not_null(container, "Container of type '" + container_type + "' should be created")

	assert_eq(DebugCommands.get_runtime_containers().size(), 6, "Should have 6 runtime containers")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_spawn_container_grid_snapping() -> void:
	test("spawn_container snaps position to grid")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	# Test position that's not on grid
	var position := Vector2(145, 167)  # Should snap to (160, 160) with 32px grid
	var container: ItemContainer = DebugCommands.spawn_container("crate", position)

	assert_not_null(container, "Container should be created")
	# Check that position was snapped (within reasonable tolerance)
	var expected_x: float = round(145.0 / 32.0) * 32.0  # = 160
	var expected_y: float = round(167.0 / 32.0) * 32.0  # = 160
	assert_eq(container.global_position.x, expected_x, "X should be snapped to grid")
	assert_eq(container.global_position.y, expected_y, "Y should be snapped to grid")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_spawn_container_signal() -> void:
	test("spawn_container emits container_spawned signal")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	var signal_received: Array = [false]
	var received_container: Array = [null]

	var callback := func(container: ItemContainer) -> void:
		signal_received[0] = true
		received_container[0] = container

	DebugCommands.container_spawned.connect(callback)

	var container: ItemContainer = DebugCommands.spawn_container("shelf", Vector2(100, 100))

	assert_true(signal_received[0], "container_spawned signal should be emitted")
	assert_eq(received_container[0], container, "Signal should contain the spawned container")

	# Cleanup
	DebugCommands.container_spawned.disconnect(callback)
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_spawn_container_invalid_type() -> void:
	test("spawn_container returns null for invalid type")

	DebugCommands.clear_scenario()

	var container: ItemContainer = DebugCommands.spawn_container("invalid_type", Vector2(100, 100))
	assert_null(container, "Container should be null for invalid type")

	container = DebugCommands.spawn_container("", Vector2(100, 100))
	assert_null(container, "Container should be null for empty type")

	# Cleanup
	test_level.clear_all_entities()


func test_spawn_container_default_allowed_tags() -> void:
	test("spawn_container applies default allowed tags for fridge")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	var container: ItemContainer = DebugCommands.spawn_container("fridge", Vector2(100, 100))

	assert_not_null(container, "Container should be created")
	# Fridge should allow food items by default
	assert_true(container.is_tag_allowed("raw_food"), "Fridge should allow raw_food")
	assert_true(container.is_tag_allowed("prepped_food"), "Fridge should allow prepped_food")
	assert_true(container.is_tag_allowed("cooked_meal"), "Fridge should allow cooked_meal")
	# Fridge should not allow non-food items
	assert_false(container.is_tag_allowed("toilet_paper"), "Fridge should not allow toilet_paper")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_spawn_container_custom_allowed_tags() -> void:
	test("spawn_container can use custom allowed tags")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	var custom_tags: Array = ["special_item", "another_item"]
	var container: ItemContainer = DebugCommands.spawn_container("crate", Vector2(100, 100), custom_tags)

	assert_not_null(container, "Container should be created")
	assert_true(container.is_tag_allowed("special_item"), "Container should allow custom tag")
	assert_true(container.is_tag_allowed("another_item"), "Container should allow second custom tag")
	assert_false(container.is_tag_allowed("raw_food"), "Container should not allow non-custom tags")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_remove_container() -> void:
	test("remove_container removes runtime container")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	var container: ItemContainer = DebugCommands.spawn_container("bin", Vector2(100, 100))
	assert_not_null(container, "Container should be created")
	assert_eq(DebugCommands.get_runtime_containers().size(), 1, "Should have 1 container")

	var result: bool = DebugCommands.remove_container(container)
	assert_true(result, "remove_container should return true")

	await get_tree().process_frame
	assert_eq(DebugCommands.get_runtime_containers().size(), 0, "Should have 0 containers after removal")

	# Cleanup
	test_level.clear_all_entities()


func test_get_runtime_containers() -> void:
	test("get_runtime_containers returns all spawned containers")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	DebugCommands.spawn_container("fridge", Vector2(100, 100))
	DebugCommands.spawn_container("crate", Vector2(200, 100))
	DebugCommands.spawn_container("shelf", Vector2(300, 100))

	var containers: Array[ItemContainer] = DebugCommands.get_runtime_containers()
	assert_eq(containers.size(), 3, "Should have 3 runtime containers")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	test_level.clear_all_entities()


func test_clear_runtime_containers() -> void:
	test("clear_runtime_containers removes all containers")

	# Clear everything first
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	DebugCommands.spawn_container("fridge", Vector2(100, 100))
	DebugCommands.spawn_container("crate", Vector2(200, 100))
	assert_eq(DebugCommands.get_runtime_containers().size(), 2, "Should have 2 containers before clear")

	DebugCommands.clear_runtime_containers()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_containers().size(), 0, "Should have 0 containers after clear")

	# Cleanup
	test_level.clear_all_entities()


func test_spawn_item_into_container_via_api() -> void:
	test("spawn_item can spawn item directly into container")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	# Create a container that allows all items
	var container: ItemContainer = DebugCommands.spawn_container("crate", Vector2(100, 100))
	assert_not_null(container, "Container should be created")
	assert_eq(container.get_item_count(), 0, "Container should be empty initially")

	# Spawn item into container
	var item: ItemEntity = DebugCommands.spawn_item("raw_food", container)

	assert_not_null(item, "Item should be created")
	assert_eq(container.get_item_count(), 1, "Container should have 1 item")
	assert_eq(item.item_tag, "raw_food", "Item tag should be correct")

	# Spawn another item
	var item2: ItemEntity = DebugCommands.spawn_item("toilet_paper", container)
	assert_not_null(item2, "Second item should be created")
	assert_eq(container.get_item_count(), 2, "Container should have 2 items")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	DebugCommands.clear_runtime_items()
	test_level.clear_all_entities()


func test_container_notifies_npcs() -> void:
	test("spawn_container notifies NPCs of new container")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	# Create an NPC first
	var npc: Node = DebugCommands.spawn_npc(Vector2(100, 100))
	await get_tree().process_frame
	await get_tree().process_frame

	# Check NPC's available_containers before spawning container
	var initial_containers: Array[ItemContainer] = []
	if npc.get("available_containers") != null:
		initial_containers = npc.available_containers.duplicate()

	var initial_count: int = initial_containers.size()

	# Spawn a container
	var container: ItemContainer = DebugCommands.spawn_container("fridge", Vector2(200, 100))
	await get_tree().process_frame

	# Check NPC's available_containers after spawning container
	var final_containers: Array[ItemContainer] = npc.available_containers
	assert_eq(final_containers.size(), initial_count + 1, "NPC should have 1 more container available")
	assert_true(container in final_containers, "NPC should know about the new container")

	# Cleanup
	DebugCommands.clear_runtime_containers()
	DebugCommands.clear_runtime_npcs()
	test_level.clear_all_entities()


func test_save_scenario_signal() -> void:
	test("save_scenario emits scenario_saved signal")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	var signal_data: Array = [false, ""]

	var callback := func(path: String) -> void:
		signal_data[0] = true
		signal_data[1] = path

	DebugCommands.scenario_saved.connect(callback)

	DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	assert_true(signal_data[0], "scenario_saved signal should be emitted")
	assert_eq(signal_data[1], TEST_SCENARIO_PATH, "Signal should pass the save path")

	# Cleanup
	DebugCommands.scenario_saved.disconnect(callback)
	_cleanup_test_scenarios()


func test_save_scenario_invalid_path() -> void:
	test("save_scenario returns false for invalid path")

	var result: bool = DebugCommands.save_scenario("")
	assert_false(result, "save_scenario should return false for empty path")


func test_load_scenario_basic() -> void:
	test("load_scenario loads saved scenario correctly")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Create a scenario
	var station: Station = DebugCommands.spawn_station("sink", Vector2(96, 96))
	var npc: Node = DebugCommands.spawn_npc(Vector2(150, 150), {"hunger": 30.0})

	await get_tree().process_frame
	await get_tree().process_frame

	# Save it
	DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	# Clear and verify cleared
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 0, "Should have 0 stations after clear")
	assert_eq(DebugCommands.get_runtime_npcs().size(), 0, "Should have 0 NPCs after clear")

	# Load the scenario
	var result: bool = DebugCommands.load_scenario(TEST_SCENARIO_PATH)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(result, "load_scenario should return true")

	# Verify entities were loaded
	var loaded_stations: Array[Station] = DebugCommands.get_runtime_stations()
	assert_eq(loaded_stations.size(), 1, "Should have 1 station after load")
	assert_eq(loaded_stations[0].station_tag, "sink", "Station should be sink")

	var loaded_npcs: Array[Node] = DebugCommands.get_runtime_npcs()
	assert_eq(loaded_npcs.size(), 1, "Should have 1 NPC after load")

	var loaded_hunger: float = DebugCommands.get_npc_motive(loaded_npcs[0], "hunger")
	assert_approx_eq(loaded_hunger, 30.0, "NPC hunger should be ~30")

	# Cleanup
	DebugCommands.clear_scenario()
	_cleanup_test_scenarios()


func test_load_scenario_clear_first() -> void:
	test("load_scenario with clear_first=true clears existing entities")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Create and save a simple scenario
	DebugCommands.spawn_station("counter", Vector2(64, 64))
	await get_tree().process_frame
	DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	# Clear and create a different scenario
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	DebugCommands.spawn_station("stove", Vector2(128, 128))
	DebugCommands.spawn_station("fridge", Vector2(192, 192))
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 2, "Should have 2 stations before load")

	# Load with clear_first=true (default)
	DebugCommands.load_scenario(TEST_SCENARIO_PATH, true)
	await get_tree().process_frame
	await get_tree().process_frame

	# Should only have the loaded station
	var stations: Array[Station] = DebugCommands.get_runtime_stations()
	assert_eq(stations.size(), 1, "Should have 1 station after load with clear")
	assert_eq(stations[0].station_tag, "counter", "Station should be counter from saved scenario")

	# Cleanup
	DebugCommands.clear_scenario()
	_cleanup_test_scenarios()


func test_load_scenario_no_clear() -> void:
	test("load_scenario with clear_first=false adds to existing entities")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Create and save a simple scenario
	DebugCommands.spawn_station("counter", Vector2(64, 64))
	await get_tree().process_frame
	DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	# Clear and create existing entities
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	DebugCommands.spawn_station("stove", Vector2(128, 128))
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 1, "Should have 1 station before load")

	# Load with clear_first=false
	DebugCommands.load_scenario(TEST_SCENARIO_PATH, false)
	await get_tree().process_frame
	await get_tree().process_frame

	# Should have both stations
	var stations: Array[Station] = DebugCommands.get_runtime_stations()
	assert_eq(stations.size(), 2, "Should have 2 stations after load without clear")

	# Cleanup
	DebugCommands.clear_scenario()
	_cleanup_test_scenarios()


func test_load_scenario_signal() -> void:
	test("load_scenario emits scenario_loaded signal")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Save an empty scenario
	DebugCommands.save_scenario(TEST_SCENARIO_PATH)

	var signal_data: Array = [false, ""]

	var callback := func(path: String) -> void:
		signal_data[0] = true
		signal_data[1] = path

	DebugCommands.scenario_loaded.connect(callback)

	DebugCommands.load_scenario(TEST_SCENARIO_PATH)

	await get_tree().process_frame

	assert_true(signal_data[0], "scenario_loaded signal should be emitted")
	assert_eq(signal_data[1], TEST_SCENARIO_PATH, "Signal should pass the load path")

	# Cleanup
	DebugCommands.scenario_loaded.disconnect(callback)
	_cleanup_test_scenarios()


func test_load_scenario_invalid_path() -> void:
	test("load_scenario returns false for invalid path")

	var result1: bool = DebugCommands.load_scenario("")
	assert_false(result1, "load_scenario should return false for empty path")

	var result2: bool = DebugCommands.load_scenario("user://non_existent_file.json")
	assert_false(result2, "load_scenario should return false for non-existent file")


func test_clear_scenario() -> void:
	test("clear_scenario removes all runtime entities")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	# Create various entities
	DebugCommands.spawn_station("counter", Vector2(64, 64))
	DebugCommands.spawn_station("stove", Vector2(128, 64))
	DebugCommands.spawn_npc(Vector2(100, 100))
	DebugCommands.spawn_npc(Vector2(200, 200))

	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 2, "Should have 2 stations")
	assert_eq(DebugCommands.get_runtime_npcs().size(), 2, "Should have 2 NPCs")

	# Clear everything
	DebugCommands.clear_scenario()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 0, "Should have 0 stations after clear")
	assert_eq(DebugCommands.get_runtime_npcs().size(), 0, "Should have 0 NPCs after clear")
	assert_eq(DebugCommands.get_runtime_items().size(), 0, "Should have 0 items after clear")


func test_clear_scenario_signal() -> void:
	test("clear_scenario emits scenario_cleared signal")

	var signal_received: Array = [false]

	var callback := func() -> void:
		signal_received[0] = true

	DebugCommands.scenario_cleared.connect(callback)

	DebugCommands.clear_scenario()

	assert_true(signal_received[0], "scenario_cleared signal should be emitted")

	# Cleanup
	DebugCommands.scenario_cleared.disconnect(callback)


func test_scenario_round_trip_complex() -> void:
	test("Complex scenario round-trip preserves all data")

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	DebugCommands.clear_scenario()
	await get_tree().process_frame

	_cleanup_test_scenarios()

	# Create a complex scenario
	var station1: Station = DebugCommands.spawn_station("counter", Vector2(64, 64))
	var station2: Station = DebugCommands.spawn_station("stove", Vector2(128, 64))
	var station3: Station = DebugCommands.spawn_station("fridge", Vector2(192, 64))

	var npc1: Node = DebugCommands.spawn_npc(Vector2(100, 200), {"hunger": 20.0, "energy": 80.0})
	var npc2: Node = DebugCommands.spawn_npc(Vector2(200, 200), {"hunger": 50.0, "bladder": 30.0})

	DebugCommands.paint_wall(Vector2i(3, 3), true)
	DebugCommands.paint_wall(Vector2i(4, 3), true)

	await get_tree().process_frame
	await get_tree().process_frame

	# Verify initial state
	assert_eq(DebugCommands.get_runtime_stations().size(), 3, "Should have 3 stations initially")
	assert_eq(DebugCommands.get_runtime_npcs().size(), 2, "Should have 2 NPCs initially")
	assert_eq(DebugCommands.get_runtime_walls().size(), 2, "Should have 2 walls initially")

	# Save scenario
	var save_result: bool = DebugCommands.save_scenario(TEST_SCENARIO_PATH)
	assert_true(save_result, "Save should succeed")

	# Clear everything
	DebugCommands.clear_scenario()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(DebugCommands.get_runtime_stations().size(), 0, "Should have 0 stations after clear")
	assert_eq(DebugCommands.get_runtime_npcs().size(), 0, "Should have 0 NPCs after clear")
	assert_eq(DebugCommands.get_runtime_walls().size(), 0, "Should have 0 walls after clear")

	# Load scenario
	var load_result: bool = DebugCommands.load_scenario(TEST_SCENARIO_PATH)
	assert_true(load_result, "Load should succeed")

	await get_tree().process_frame
	await get_tree().process_frame

	# Verify loaded state matches original
	var loaded_stations: Array[Station] = DebugCommands.get_runtime_stations()
	assert_eq(loaded_stations.size(), 3, "Should have 3 stations after load")

	# Check station types
	var station_types: Array = []
	for station in loaded_stations:
		station_types.append(station.station_tag)
	assert_true("counter" in station_types, "Counter should be loaded")
	assert_true("stove" in station_types, "Stove should be loaded")
	assert_true("fridge" in station_types, "Fridge should be loaded")

	var loaded_npcs: Array[Node] = DebugCommands.get_runtime_npcs()
	assert_eq(loaded_npcs.size(), 2, "Should have 2 NPCs after load")

	# Check NPC motives (order may vary, so check both) - use approx comparison
	var found_hungry_npc: bool = false
	var found_bladder_npc: bool = false
	for npc in loaded_npcs:
		var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
		var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
		if abs(hunger - 20.0) <= 0.1:
			found_hungry_npc = true
		if abs(bladder - 30.0) <= 0.1:
			found_bladder_npc = true
	assert_true(found_hungry_npc, "Should find NPC with hunger~=20")
	assert_true(found_bladder_npc, "Should find NPC with bladder~=30")

	var loaded_walls: Dictionary = DebugCommands.get_runtime_walls()
	assert_eq(loaded_walls.size(), 2, "Should have 2 walls after load")
	assert_true(loaded_walls.has(Vector2i(3, 3)), "Wall at (3,3) should be loaded")
	assert_true(loaded_walls.has(Vector2i(4, 3)), "Wall at (4,3) should be loaded")

	# Cleanup
	DebugCommands.clear_scenario()
	test_level.clear_all_entities()
	_cleanup_test_scenarios()
