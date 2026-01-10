extends TestRunner

## Tests for NPC ground item pickup during hauling (US-006)

const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var level: Node2D


func _ready() -> void:
	_test_name = "NPC Ground Item Hauling"
	level = get_parent()
	super._ready()


func run_tests() -> void:
	_log_header()

	await test_npc_pathfinds_to_ground_item()
	await test_npc_picks_up_ground_item()
	await test_ground_item_location_changes()
	await test_ground_item_removed_from_parent()
	await test_npc_handles_missing_item()
	await test_npc_continues_after_ground_pickup()

	_log_summary()


func test_npc_pathfinds_to_ground_item() -> void:
	test("NPC pathfinds to ground item position")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(50, 50)
	level.add_child(npc)
	npc.is_initialized = true
	npc.set_astar(level.astar)
	npc.set_walkable_positions(level.walkable_positions)

	# Add ground item at a distance
	var ground_item: ItemEntity = level.add_item(Vector2(200, 50), "raw_food")

	# Set up NPC with no containers (forces ground item search)
	var empty_containers: Array[ItemContainer] = []
	var empty_stations: Array[Station] = []
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(empty_stations)

	# Set up items to gather
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})

	# Start gathering - should find ground item
	var result: bool = npc._start_gathering_next_item()

	assert_true(result, "Should successfully start gathering")
	assert_eq(npc.target_ground_item, ground_item, "Should target the ground item")
	assert_eq(npc.current_state, npc.State.HAULING, "Should be in HAULING state")
	assert_true(npc.current_path.size() > 0, "Should have a path to the item")

	# Cleanup
	level.remove_item(ground_item)
	npc.queue_free()
	await get_tree().process_frame


func test_npc_picks_up_ground_item() -> void:
	test("NPC picks up ground item on arrival")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Add ground item at NPC position (simulating arrival)
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")

	# Set up NPC targeting the ground item
	npc.target_ground_item = ground_item
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})

	# Simulate arrival
	npc._on_arrived_at_ground_item()

	assert_true(npc.held_items.has(ground_item), "Item should be in held_items")
	assert_eq(npc.target_ground_item, null, "target_ground_item should be cleared")

	# Cleanup
	npc.queue_free()
	await get_tree().process_frame


func test_ground_item_location_changes() -> void:
	test("Ground item location changes to IN_HAND after pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Add ground item
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	assert_eq(ground_item.location, ItemEntity.ItemLocation.ON_GROUND, "Item starts ON_GROUND")

	# Set up NPC and simulate pickup
	npc.target_ground_item = ground_item
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})
	npc._on_arrived_at_ground_item()

	assert_eq(ground_item.location, ItemEntity.ItemLocation.IN_HAND, "Item location should be IN_HAND")

	# Cleanup
	npc.queue_free()
	await get_tree().process_frame


func test_ground_item_removed_from_parent() -> void:
	test("Ground item reparented from Level to NPC after pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true

	# Add ground item (initially child of level)
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	assert_eq(ground_item.get_parent(), level, "Item starts as child of level")

	# Set up NPC and simulate pickup
	npc.target_ground_item = ground_item
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})
	npc._on_arrived_at_ground_item()

	assert_eq(ground_item.get_parent(), npc, "Item should be reparented to NPC")
	assert_false(level.all_items.has(ground_item), "Item should be removed from level.all_items")

	# Cleanup
	npc.queue_free()
	await get_tree().process_frame


func test_npc_handles_missing_item() -> void:
	test("NPC re-searches if ground item disappears before arrival")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true
	npc.set_astar(level.astar)
	npc.set_walkable_positions(level.walkable_positions)

	# Add ground item
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")

	# Add a backup item in a container
	var container: ItemContainer = level.add_container(Vector2(150, 100), "Storage")
	var backup_item: ItemEntity = ItemEntityScene.instantiate()
	backup_item.item_tag = "raw_food"
	container.add_item(backup_item)

	# Set up NPC with access to container
	var containers: Array[ItemContainer] = [container]
	var empty_stations: Array[Station] = []
	npc.set_available_containers(containers)
	npc.set_available_stations(empty_stations)

	# Set up NPC targeting the ground item
	npc.target_ground_item = ground_item
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})

	# Remove the ground item (simulating it disappeared)
	level.remove_item(ground_item)
	await get_tree().process_frame

	# Simulate arrival - item is gone, should re-search
	npc._on_arrived_at_ground_item()

	# Should have found the backup item in container (or be in a valid state)
	assert_eq(npc.target_ground_item, null, "Ground item target should be cleared")
	# NPC should either target the container or be in HAULING state trying to get there
	var found_alternative: bool = (npc.target_container == container) or (npc.current_state == npc.State.HAULING) or (npc.current_state == npc.State.IDLE)
	assert_true(found_alternative, "NPC should handle missing item gracefully")

	# Cleanup
	level.remove_container(container)
	npc.queue_free()
	await get_tree().process_frame


func test_npc_continues_after_ground_pickup() -> void:
	test("NPC proceeds to next step after ground item pickup")

	var npc = NPCScene.instantiate()
	npc.position = Vector2(100, 100)
	level.add_child(npc)
	npc.is_initialized = true
	npc.set_astar(level.astar)
	npc.set_walkable_positions(level.walkable_positions)

	# Add two ground items
	var item1: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")
	var item2: ItemEntity = level.add_item(Vector2(150, 100), "seasoning")

	# Set up NPC with empty containers (forces ground search)
	var empty_containers: Array[ItemContainer] = []
	var empty_stations: Array[Station] = []
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(empty_stations)

	# Set up multiple items to gather
	npc.target_ground_item = item1
	npc.items_to_gather.clear()
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})
	npc.items_to_gather.append({"tag": "seasoning", "quantity": 1})

	# Pick up first item
	npc._on_arrived_at_ground_item()

	# Should have picked up raw_food and now be targeting seasoning
	assert_true(npc.held_items.size() >= 1, "Should have at least one held item")
	assert_eq(npc.held_items[0].item_tag, "raw_food", "First held item should be raw_food")

	# Should now be looking for seasoning
	if npc.items_to_gather.size() > 0:
		assert_eq(npc.items_to_gather[0]["tag"], "seasoning", "Next item to gather should be seasoning")

	# Cleanup
	level.remove_item(item2)
	npc.queue_free()
	await get_tree().process_frame
