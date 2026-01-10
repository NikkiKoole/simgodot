extends TestRunner

## Tests for Station class (US-003)

# Preload scenes
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var test_area: Node2D


func _ready() -> void:
	_test_name = "Station"
	test_area = $TestArea
	super._ready()


func run_tests() -> void:
	_log_header()

	test_station_creation()
	test_station_reservation()
	await test_station_slot_discovery()
	await test_station_input_slots()
	await test_station_output_slots()
	await test_station_slot_operations()
	await test_station_agent_footprint()
	# US-002: get_available_output_items_by_tag tests
	await test_get_output_items_empty()
	await test_get_output_items_finds_matching()
	await test_get_output_items_excludes_input_slots()
	await test_get_output_items_excludes_reserved()
	await test_get_output_items_multiple_stations()

	_log_summary()


func test_station_creation() -> void:
	test("Station creation")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)

	station.station_tag = "stove"
	station.station_name = "Kitchen Stove"

	assert_eq(station.station_tag, "stove", "Station tag should be set")
	assert_eq(station.station_name, "Kitchen Stove", "Station name should be set")
	assert_true(station.is_available(), "Station should be available initially")

	station.queue_free()


## US-002: get_available_output_items_by_tag tests

func test_get_output_items_empty() -> void:
	test("Returns empty when no output items")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var result: Array[ItemEntity] = station.get_available_output_items_by_tag("cooked_food")
	assert_array_size(result, 0, "Should return empty array when no output items")

	station.queue_free()


func test_get_output_items_finds_matching() -> void:
	test("Returns items matching tag in output slots")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "cooked_food"
	test_area.add_child(item)

	station.place_output_item(item, 0)

	var result: Array[ItemEntity] = station.get_available_output_items_by_tag("cooked_food")
	assert_array_size(result, 1, "Should find 1 cooked_food item in output slot")
	assert_array_contains(result, item, "Should contain the placed item")

	# Non-matching tag returns empty
	var non_match: Array[ItemEntity] = station.get_available_output_items_by_tag("raw_food")
	assert_array_size(non_match, 0, "Should return empty for non-matching tag")

	station.queue_free()


func test_get_output_items_excludes_input_slots() -> void:
	test("Does not return items from input slots")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var input_item: ItemEntity = ItemEntityScene.instantiate()
	var output_item: ItemEntity = ItemEntityScene.instantiate()
	input_item.item_tag = "raw_food"
	output_item.item_tag = "raw_food"
	test_area.add_child(input_item)
	test_area.add_child(output_item)

	station.place_input_item(input_item, 0)
	station.place_output_item(output_item, 0)

	var result: Array[ItemEntity] = station.get_available_output_items_by_tag("raw_food")
	assert_array_size(result, 1, "Should only find output item, not input item")
	assert_array_contains(result, output_item, "Should contain output item")
	assert_array_not_contains(result, input_item, "Should not contain input item")

	station.queue_free()


func test_get_output_items_excludes_reserved() -> void:
	test("Does not return reserved items")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "cooked_food"
	test_area.add_child(item)

	station.place_output_item(item, 0)

	# Before reservation, item is found
	var before_reserve: Array[ItemEntity] = station.get_available_output_items_by_tag("cooked_food")
	assert_array_size(before_reserve, 1, "Should find item before reservation")

	# Reserve item
	var fake_agent := Node.new()
	test_area.add_child(fake_agent)
	item.reserve_item(fake_agent)

	# After reservation, item is not found
	var after_reserve: Array[ItemEntity] = station.get_available_output_items_by_tag("cooked_food")
	assert_array_size(after_reserve, 0, "Should not find reserved item")

	# Cleanup
	item.release_item()
	fake_agent.queue_free()
	station.queue_free()


func test_get_output_items_multiple_stations() -> void:
	test("Works correctly across multiple stations")

	var station1: Station = StationScene.instantiate()
	var station2: Station = StationScene.instantiate()
	test_area.add_child(station1)
	test_area.add_child(station2)
	await get_tree().process_frame

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "cooked_food"
	item2.item_tag = "cooked_food"
	test_area.add_child(item1)
	test_area.add_child(item2)

	station1.place_output_item(item1, 0)
	station2.place_output_item(item2, 0)

	# Each station returns only its own items
	var result1: Array[ItemEntity] = station1.get_available_output_items_by_tag("cooked_food")
	assert_array_size(result1, 1, "Station1 should find 1 item")
	assert_array_contains(result1, item1, "Station1 should contain item1")
	assert_array_not_contains(result1, item2, "Station1 should not contain item2")

	var result2: Array[ItemEntity] = station2.get_available_output_items_by_tag("cooked_food")
	assert_array_size(result2, 1, "Station2 should find 1 item")
	assert_array_contains(result2, item2, "Station2 should contain item2")
	assert_array_not_contains(result2, item1, "Station2 should not contain item1")

	station1.queue_free()
	station2.queue_free()


func test_station_reservation() -> void:
	test("Station reservation system")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)

	var fake_agent1 = Node.new()
	var fake_agent2 = Node.new()
	test_area.add_child(fake_agent1)
	test_area.add_child(fake_agent2)

	# Initially available
	assert_true(station.is_available(), "Station should be available initially")

	# Reserve by agent1
	var reserved = station.reserve(fake_agent1)
	assert_true(reserved, "Reservation should succeed")
	assert_false(station.is_available(), "Station should not be available after reservation")
	assert_true(station.is_reserved_by(fake_agent1), "Station should be reserved by agent1")

	# Agent2 cannot reserve
	var reserved2 = station.reserve(fake_agent2)
	assert_false(reserved2, "Second reservation should fail")

	# Same agent can re-reserve
	var reserved_again = station.reserve(fake_agent1)
	assert_true(reserved_again, "Same agent re-reservation should succeed")

	# Release
	station.release()
	assert_true(station.is_available(), "Station should be available after release")

	# Now agent2 can reserve
	var reserved3 = station.reserve(fake_agent2)
	assert_true(reserved3, "Agent2 should now be able to reserve")

	station.queue_free()
	fake_agent1.queue_free()
	fake_agent2.queue_free()


func test_station_slot_discovery() -> void:
	test("Station auto-discovers Marker2D slots")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)

	# Wait a frame for _ready to complete
	await get_tree().process_frame

	# Station scene has InputSlot0, OutputSlot0, and AgentFootprint
	assert_eq(station.get_input_slot_count(), 1, "Should have 1 input slot")
	assert_eq(station.get_output_slot_count(), 1, "Should have 1 output slot")
	assert_not_null(station.agent_footprint, "Agent footprint should be discovered")

	station.queue_free()


func test_station_input_slots() -> void:
	test("Station input slot operations")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "raw_food"
	item2.item_tag = "ingredient"
	test_area.add_child(item1)
	test_area.add_child(item2)

	# Place item in input slot 0
	var placed = station.place_input_item(item1, 0)
	assert_true(placed, "Should place item in input slot 0")
	assert_true(station.has_input_items(), "Station should have input items")

	# Get item from input slot
	var retrieved = station.get_input_item(0)
	assert_eq(retrieved, item1, "Should retrieve same item from slot")
	assert_eq(retrieved.item_tag, "raw_food", "Item tag should match")

	# Item location should be updated
	assert_eq(item1.location, ItemEntity.ItemLocation.IN_SLOT, "Item location should be IN_SLOT")

	# Cannot place another item in same slot
	var placed2 = station.place_input_item(item2, 0)
	assert_false(placed2, "Should not place item in occupied slot")

	# Invalid slot index
	var placed_invalid = station.place_input_item(item2, 99)
	assert_false(placed_invalid, "Should reject invalid slot index")

	# Remove item
	var removed = station.remove_input_item(0)
	assert_eq(removed, item1, "Should return removed item")
	assert_false(station.has_input_items(), "Station should have no input items")

	# Empty slot returns null
	var empty = station.get_input_item(0)
	assert_null(empty, "Empty slot should return null")

	station.queue_free()
	item2.queue_free()


func test_station_output_slots() -> void:
	test("Station output slot operations")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "cooked_food"
	test_area.add_child(item)

	# Place item in output slot 0
	var placed = station.place_output_item(item, 0)
	assert_true(placed, "Should place item in output slot 0")
	assert_true(station.has_output_items(), "Station should have output items")

	# Get item from output slot
	var retrieved = station.get_output_item(0)
	assert_eq(retrieved, item, "Should retrieve same item from output slot")

	# Remove item
	var removed = station.remove_output_item(0)
	assert_eq(removed, item, "Should return removed item")
	assert_false(station.has_output_items(), "Station should have no output items")

	station.queue_free()


func test_station_slot_operations() -> void:
	test("Station slot helper operations")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	await get_tree().process_frame

	# Find empty input slot
	var empty_input = station.find_empty_input_slot()
	assert_eq(empty_input, 0, "First empty input slot should be 0")

	# Find empty output slot
	var empty_output = station.find_empty_output_slot()
	assert_eq(empty_output, 0, "First empty output slot should be 0")

	# Place items
	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "input_item"
	item2.item_tag = "output_item"
	test_area.add_child(item1)
	test_area.add_child(item2)

	station.place_input_item(item1, 0)
	station.place_output_item(item2, 0)

	# Now no empty slots (since we only have 1 of each)
	var no_empty_input = station.find_empty_input_slot()
	assert_eq(no_empty_input, -1, "No empty input slots")

	var no_empty_output = station.find_empty_output_slot()
	assert_eq(no_empty_output, -1, "No empty output slots")

	# Get all items
	var all_inputs = station.get_all_input_items()
	assert_array_size(all_inputs, 1, "Should have 1 input item")

	var all_outputs = station.get_all_output_items()
	assert_array_size(all_outputs, 1, "Should have 1 output item")

	# Clear all
	station.clear_all_slots()
	assert_false(station.has_input_items(), "No input items after clear")
	assert_false(station.has_output_items(), "No output items after clear")

	station.queue_free()


func test_station_agent_footprint() -> void:
	test("Station agent footprint position")

	var station: Station = StationScene.instantiate()
	test_area.add_child(station)
	station.position = Vector2(100, 100)
	await get_tree().process_frame

	# Get agent position (footprint is at y+40 in scene)
	var agent_pos = station.get_agent_position()
	assert_not_null(agent_pos, "Agent position should not be null")

	# Footprint is offset from station position
	# Station scene has AgentFootprint at local position Vector2(0, 40)
	# Global position = test_area(200,150) + station(100,100) + footprint(0,40)
	var expected_x = station.global_position.x  # Footprint X offset is 0
	var expected_y = station.global_position.y + 40.0  # Footprint Y offset is 40
	assert_eq(agent_pos.x, expected_x, "Agent X should match station global X")
	assert_eq(agent_pos.y, expected_y, "Agent Y should be station Y + footprint offset (40)")

	# Slot positions
	var input_slot_pos = station.get_input_slot_position(0)
	assert_not_null(input_slot_pos, "Input slot position should not be null")

	var output_slot_pos = station.get_output_slot_position(0)
	assert_not_null(output_slot_pos, "Output slot position should not be null")

	station.queue_free()
