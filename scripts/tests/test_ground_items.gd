extends TestRunner

## Tests for Level.get_ground_items_by_tag() (US-001)

const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")

var level: Node2D


func _ready() -> void:
	_test_name = "Level Ground Items Query"
	level = get_parent()
	super._ready()


func run_tests() -> void:
	_log_header()

	test_get_ground_items_empty()
	test_get_ground_items_finds_matching()
	test_get_ground_items_excludes_containers()
	test_get_ground_items_excludes_reserved()
	test_get_ground_items_excludes_held()
	test_get_ground_items_excludes_slots()
	test_get_ground_items_multiple_tags()

	_log_summary()


func test_get_ground_items_empty() -> void:
	test("Returns empty array when no ground items exist")

	# Level starts empty
	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 0, "Should return empty array when no items exist")


func test_get_ground_items_finds_matching() -> void:
	test("Returns items matching tag on ground")

	# Add ground items using Level's API
	var item1: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var item2: ItemEntity = level.add_item(Vector2(200, 100), "raw_food")

	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 2, "Should find 2 raw_food items on ground")
	assert_array_contains(result, item1, "Should contain item1")
	assert_array_contains(result, item2, "Should contain item2")

	# Cleanup
	level.remove_item(item1)
	level.remove_item(item2)


func test_get_ground_items_excludes_containers() -> void:
	test("Does not return items in containers")

	# Add item on ground
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")

	# Add container and item inside it
	var container: ItemContainer = level.add_container(Vector2(200, 100), "Storage")
	var container_item: ItemEntity = ItemEntityScene.instantiate()
	container_item.item_tag = "raw_food"
	container.add_item(container_item)
	# Container items have location IN_CONTAINER and are not in level.all_items

	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 1, "Should only find ground item, not container item")
	assert_array_contains(result, ground_item, "Should contain ground item")

	# Cleanup
	level.remove_item(ground_item)
	level.remove_container(container)


func test_get_ground_items_excludes_reserved() -> void:
	test("Does not return reserved items")

	var item1: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var item2: ItemEntity = level.add_item(Vector2(200, 100), "raw_food")

	# Reserve one item
	var fake_agent := Node.new()
	add_child(fake_agent)
	item1.reserve_item(fake_agent)

	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 1, "Should only find unreserved item")
	assert_array_not_contains(result, item1, "Should not contain reserved item")
	assert_array_contains(result, item2, "Should contain unreserved item")

	# Cleanup
	item1.release_item()
	fake_agent.queue_free()
	level.remove_item(item1)
	level.remove_item(item2)


func test_get_ground_items_excludes_held() -> void:
	test("Does not return items IN_HAND")

	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var held_item: ItemEntity = level.add_item(Vector2(200, 100), "raw_food")

	# Change location to IN_HAND (simulating NPC picking it up)
	held_item.set_location(ItemEntity.ItemLocation.IN_HAND)

	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 1, "Should only find ground item, not held item")
	assert_array_contains(result, ground_item, "Should contain ground item")
	assert_array_not_contains(result, held_item, "Should not contain held item")

	# Cleanup
	level.remove_item(ground_item)
	level.remove_item(held_item)


func test_get_ground_items_excludes_slots() -> void:
	test("Does not return items IN_SLOT")

	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var slot_item: ItemEntity = level.add_item(Vector2(200, 100), "raw_food")

	# Change location to IN_SLOT (simulating item at station)
	slot_item.set_location(ItemEntity.ItemLocation.IN_SLOT)

	var result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(result, 1, "Should only find ground item, not slot item")
	assert_array_contains(result, ground_item, "Should contain ground item")
	assert_array_not_contains(result, slot_item, "Should not contain slot item")

	# Cleanup
	level.remove_item(ground_item)
	level.remove_item(slot_item)


func test_get_ground_items_multiple_tags() -> void:
	test("Only returns items with matching tag")

	var food_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var tool_item: ItemEntity = level.add_item(Vector2(200, 100), "knife")
	var another_food: ItemEntity = level.add_item(Vector2(300, 100), "raw_food")

	var food_result: Array[ItemEntity] = level.get_ground_items_by_tag("raw_food")
	assert_array_size(food_result, 2, "Should find 2 raw_food items")
	assert_array_contains(food_result, food_item, "Should contain food_item")
	assert_array_contains(food_result, another_food, "Should contain another_food")
	assert_array_not_contains(food_result, tool_item, "Should not contain knife")

	var tool_result: Array[ItemEntity] = level.get_ground_items_by_tag("knife")
	assert_array_size(tool_result, 1, "Should find 1 knife item")
	assert_array_contains(tool_result, tool_item, "Should contain tool_item")

	var empty_result: Array[ItemEntity] = level.get_ground_items_by_tag("nonexistent")
	assert_array_size(empty_result, 0, "Should find no items for nonexistent tag")

	# Cleanup
	level.remove_item(food_item)
	level.remove_item(tool_item)
	level.remove_item(another_food)
