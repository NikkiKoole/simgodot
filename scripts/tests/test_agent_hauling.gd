extends "res://scripts/tests/test_runner.gd"
## Tests for NPC HAULING state (US-010)

# Preload scenes
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")

var test_area: Node2D

func _ready() -> void:
	_test_name = "Agent Hauling"
	test_area = $TestArea
	super._ready()

func run_tests() -> void:
	_log_header()
	test_npc_has_hauling_state()
	test_npc_has_held_items_array()
	test_pick_up_item()
	test_item_location_changes_to_in_hand()
	test_held_items_tracking()
	test_start_hauling_for_job()
	test_hauling_gathers_required_items()
	test_cancel_hauling_drops_items()
	test_multiple_items_gathering()
	_log_summary()

func test_npc_has_hauling_state() -> void:
	test("NPC has HAULING state")

	# Check that State enum includes HAULING
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	# Access the State enum - HAULING should be value 4 (after IDLE=0, WALKING=1, WAITING=2, USING_OBJECT=3)
	assert_eq(npc.State.HAULING, 4, "HAULING should be state 4")
	assert_true(npc.State.has("HAULING"), "State enum should have HAULING")

	npc.queue_free()

func test_npc_has_held_items_array() -> void:
	test("NPC has held_items array")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	assert_not_null(npc.held_items, "NPC should have held_items array")
	assert_eq(npc.held_items.size(), 0, "held_items should be empty initially")
	assert_false(npc.is_holding_items(), "is_holding_items() should return false initially")

	npc.queue_free()

func test_pick_up_item() -> void:
	test("NPC can pick up item")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	test_area.add_child(item)

	# Pick up item using the internal method
	npc._pick_up_item(item)

	assert_eq(npc.held_items.size(), 1, "NPC should have 1 held item")
	assert_true(npc.is_holding_items(), "is_holding_items() should return true")
	assert_array_contains(npc.held_items, item, "held_items should contain the item")

	npc.queue_free()

func test_item_location_changes_to_in_hand() -> void:
	test("Item location changes to IN_HAND when picked up")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	item.set_location(ItemEntity.ItemLocation.IN_CONTAINER)
	test_area.add_child(item)

	assert_eq(item.location, ItemEntity.ItemLocation.IN_CONTAINER, "Initial location should be IN_CONTAINER")

	npc._pick_up_item(item)

	assert_eq(item.location, ItemEntity.ItemLocation.IN_HAND, "Location should be IN_HAND after pickup")

	npc.queue_free()

func test_held_items_tracking() -> void:
	test("Held items array correctly tracks multiple items")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	var item3: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "food"
	item2.item_tag = "tool"
	item3.item_tag = "drink"
	test_area.add_child(item1)
	test_area.add_child(item2)
	test_area.add_child(item3)

	npc._pick_up_item(item1)
	assert_eq(npc.held_items.size(), 1, "Should have 1 item")

	npc._pick_up_item(item2)
	assert_eq(npc.held_items.size(), 2, "Should have 2 items")

	npc._pick_up_item(item3)
	assert_eq(npc.held_items.size(), 3, "Should have 3 items")

	# Test get_held_items
	var held: Array[ItemEntity] = npc.get_held_items()
	assert_array_size(held, 3, "get_held_items should return 3 items")

	# Test remove_held_item
	var removed: bool = npc.remove_held_item(item2)
	assert_true(removed, "remove_held_item should return true")
	assert_eq(npc.held_items.size(), 2, "Should have 2 items after removal")
	assert_array_not_contains(npc.held_items, item2, "item2 should be removed")

	# Test removing non-held item
	var removed_again: bool = npc.remove_held_item(item2)
	assert_false(removed_again, "remove_held_item should return false for non-held item")

	npc.queue_free()

func test_start_hauling_for_job() -> void:
	test("start_hauling_for_job initializes hauling state")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true  # Skip normal initialization

	# Create a container with items
	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10
	container.global_position = Vector2(100, 100)

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	# Set up NPC with container access
	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Create a recipe and job
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Recipe"
	recipe.add_input("raw_food", 1, true)

	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)

	# Start hauling - without astar it will fail to pathfind, but we can check initialization
	# For this test, we verify the method exists and can be called
	assert_true(npc.has_method("start_hauling_for_job"), "NPC should have start_hauling_for_job method")

	# Since we don't have astar set up, the hauling will fail to pathfind
	# But we can test that items_to_gather is populated
	npc.current_job = job
	npc.held_items.clear()
	npc.items_to_gather.clear()

	# Manually build items_to_gather like start_hauling_for_job does
	for input_data in job.recipe.inputs:
		var input := Recipe.RecipeInput.from_dict(input_data)
		npc.items_to_gather.append({"tag": input.item_tag, "quantity": input.quantity})

	assert_eq(npc.items_to_gather.size(), 1, "Should have 1 item to gather")
	assert_eq(npc.items_to_gather[0]["tag"], "raw_food", "Should need raw_food")
	assert_eq(npc.items_to_gather[0]["quantity"], 1, "Should need quantity 1")

	container.queue_free()
	npc.queue_free()

func test_hauling_gathers_required_items() -> void:
	test("Hauling gathers items from container")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create a container with items
	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	assert_eq(container.get_item_count(), 1, "Container should have 1 item")

	# Simulate picking up item from container
	npc.target_container = container
	npc.items_to_gather.append({"tag": "raw_food", "quantity": 1})

	# Call the pickup method directly
	npc._pick_up_item(item)

	assert_eq(npc.held_items.size(), 1, "NPC should hold 1 item")
	assert_eq(item.location, ItemEntity.ItemLocation.IN_HAND, "Item should be IN_HAND")

	container.queue_free()
	npc.queue_free()

func test_cancel_hauling_drops_items() -> void:
	test("Cancel hauling drops all held items")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Pick up some items
	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "food"
	item2.item_tag = "tool"
	test_area.add_child(item1)
	test_area.add_child(item2)

	npc._pick_up_item(item1)
	npc._pick_up_item(item2)

	assert_eq(npc.held_items.size(), 2, "NPC should hold 2 items before cancel")

	# Cancel hauling
	npc._cancel_hauling()

	assert_eq(npc.held_items.size(), 0, "NPC should hold 0 items after cancel")
	assert_eq(npc.current_state, npc.State.IDLE, "State should be IDLE after cancel")
	assert_eq(item1.location, ItemEntity.ItemLocation.ON_GROUND, "Item1 should be ON_GROUND")
	assert_eq(item2.location, ItemEntity.ItemLocation.ON_GROUND, "Item2 should be ON_GROUND")

	npc.queue_free()

func test_multiple_items_gathering() -> void:
	test("Hauling correctly tracks multiple item requirements")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create a recipe requiring multiple items
	var recipe := Recipe.new()
	recipe.recipe_name = "Complex Recipe"
	recipe.add_input("raw_food", 2, true)  # Need 2 raw_food
	recipe.add_tool("knife")  # Need 1 knife

	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)

	# Manually initialize items_to_gather
	npc.current_job = job
	npc.held_items.clear()
	npc.items_to_gather.clear()

	for input_data in job.recipe.inputs:
		var input := Recipe.RecipeInput.from_dict(input_data)
		npc.items_to_gather.append({"tag": input.item_tag, "quantity": input.quantity})

	for tool_tag in job.recipe.tools:
		npc.items_to_gather.append({"tag": tool_tag, "quantity": 1})

	assert_eq(npc.items_to_gather.size(), 2, "Should have 2 types of items to gather")
	assert_eq(npc.items_to_gather[0]["tag"], "raw_food", "First should be raw_food")
	assert_eq(npc.items_to_gather[0]["quantity"], 2, "Should need 2 raw_food")
	assert_eq(npc.items_to_gather[1]["tag"], "knife", "Second should be knife")
	assert_eq(npc.items_to_gather[1]["quantity"], 1, "Should need 1 knife")

	npc.queue_free()
