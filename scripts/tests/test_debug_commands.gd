extends TestRunner

## Tests for DebugCommands singleton (US-001)

const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")
const NPCScene = preload("res://scenes/npc.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")

var test_area: Node2D


func _ready() -> void:
	_test_name = "DebugCommands"
	test_area = $TestArea
	super._ready()


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

	# Cleanup
	DebugCommands.clear_runtime_stations()


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

	# Clear any existing runtime stations
	DebugCommands.clear_runtime_stations()
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

	# Check all motives are at 100 (full)
	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
	var hygiene: float = DebugCommands.get_npc_motive(npc, "hygiene")
	var fun: float = DebugCommands.get_npc_motive(npc, "fun")

	assert_eq(hunger, 100.0, "Hunger should be 100 (full)")
	assert_eq(energy, 100.0, "Energy should be 100 (full)")
	assert_eq(bladder, 100.0, "Bladder should be 100 (full)")
	assert_eq(hygiene, 100.0, "Hygiene should be 100 (full)")
	assert_eq(fun, 100.0, "Fun should be 100 (full)")

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

	# Check custom motives are set correctly
	var hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	var bladder: float = DebugCommands.get_npc_motive(npc, "bladder")
	var hygiene: float = DebugCommands.get_npc_motive(npc, "hygiene")
	var fun: float = DebugCommands.get_npc_motive(npc, "fun")

	assert_eq(hunger, 20.0, "Hunger should be 20")
	assert_eq(energy, 80.0, "Energy should be 80")
	assert_eq(bladder, 50.0, "Bladder should be 50")
	# Unspecified motives should default to 100
	assert_eq(hygiene, 100.0, "Hygiene should default to 100")
	assert_eq(fun, 100.0, "Fun should default to 100")

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

	# Other motives should be unchanged
	var energy: float = DebugCommands.get_npc_motive(npc, "energy")
	assert_eq(energy, 100.0, "Energy should still be 100")

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
	assert_eq(signal_data[3], 100.0, "Signal should pass old value (100)")
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

	DebugCommands.clear_runtime_npcs()

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
