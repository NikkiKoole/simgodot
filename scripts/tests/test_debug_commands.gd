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
