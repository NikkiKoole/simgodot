extends TestRunner

## Tests for ItemEntity and ItemContainer (US-001 and US-002)

# Preload scenes
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")

var test_area: Node2D


func _ready() -> void:
	_test_name = "ItemEntity & ItemContainer"
	test_area = $TestArea
	super._ready()


func run_tests() -> void:
	_log_header()

	test_item_entity_creation()
	test_item_entity_states()
	test_item_entity_reservation()
	test_container_add_remove()
	test_container_capacity()
	test_container_tag_filtering()
	test_container_available_items()
	test_container_find_by_tag()
	test_job_claim_reserves_items()
	test_job_release_unreserves_items()
	test_job_complete_unreserves_items()
	test_job_fail_unreserves_items()
	test_job_interrupt_unreserves_items()

	_log_summary()


func test_item_entity_creation() -> void:
	test("ItemEntity creation")

	var item: ItemEntity = ItemEntityScene.instantiate()
	test_area.add_child(item)

	item.item_tag = "raw_food"
	item.state = ItemEntity.ItemState.RAW
	item.location = ItemEntity.ItemLocation.ON_GROUND

	assert_eq(item.item_tag, "raw_food", "Item tag should be set")
	assert_eq(item.state, ItemEntity.ItemState.RAW, "Initial state should be RAW")
	assert_eq(item.location, ItemEntity.ItemLocation.ON_GROUND, "Initial location should be ON_GROUND")
	assert_not_null(item.item_id, "Item should have an ID")

	item.queue_free()


func test_item_entity_states() -> void:
	test("ItemEntity state transitions")

	var item: ItemEntity = ItemEntityScene.instantiate()
	test_area.add_child(item)

	# Test state changes
	item.set_state(ItemEntity.ItemState.RAW)
	assert_eq(item.state, ItemEntity.ItemState.RAW, "State should be RAW")

	item.set_state(ItemEntity.ItemState.PREPPED)
	assert_eq(item.state, ItemEntity.ItemState.PREPPED, "State should transition to PREPPED")

	item.set_state(ItemEntity.ItemState.COOKED)
	assert_eq(item.state, ItemEntity.ItemState.COOKED, "State should transition to COOKED")

	# Test location changes
	item.set_location(ItemEntity.ItemLocation.IN_HAND)
	assert_eq(item.location, ItemEntity.ItemLocation.IN_HAND, "Location should be IN_HAND")

	item.set_location(ItemEntity.ItemLocation.IN_SLOT)
	assert_eq(item.location, ItemEntity.ItemLocation.IN_SLOT, "Location should be IN_SLOT")

	item.queue_free()


func test_item_entity_reservation() -> void:
	test("ItemEntity reservation system")

	var item: ItemEntity = ItemEntityScene.instantiate()
	test_area.add_child(item)

	var fake_agent1 = Node.new()
	var fake_agent2 = Node.new()
	test_area.add_child(fake_agent1)
	test_area.add_child(fake_agent2)

	# Initially not reserved
	assert_false(item.is_reserved(), "Item should not be reserved initially")

	# Reserve by agent1
	var reserved = item.reserve_item(fake_agent1)
	assert_true(reserved, "Reservation should succeed")
	assert_true(item.is_reserved(), "Item should be reserved")
	assert_true(item.is_reserved_by(fake_agent1), "Item should be reserved by agent1")

	# Agent2 cannot reserve
	var reserved2 = item.reserve_item(fake_agent2)
	assert_false(reserved2, "Second reservation should fail")

	# Same agent can re-reserve
	var reserved_again = item.reserve_item(fake_agent1)
	assert_true(reserved_again, "Same agent re-reservation should succeed")

	# Release
	item.release_item()
	assert_false(item.is_reserved(), "Item should be released")

	# Now agent2 can reserve
	var reserved3 = item.reserve_item(fake_agent2)
	assert_true(reserved3, "Agent2 should now be able to reserve")

	item.queue_free()
	fake_agent1.queue_free()
	fake_agent2.queue_free()


func test_container_add_remove() -> void:
	test("ItemContainer add/remove items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 5

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "food"
	item2.item_tag = "tool"
	test_area.add_child(item1)
	test_area.add_child(item2)

	# Add items
	var added1 = container.add_item(item1)
	assert_true(added1, "First item should be added")
	assert_eq(container.get_item_count(), 1, "Container should have 1 item")

	var added2 = container.add_item(item2)
	assert_true(added2, "Second item should be added")
	assert_eq(container.get_item_count(), 2, "Container should have 2 items")

	# Cannot add same item twice
	var added_dup = container.add_item(item1)
	assert_false(added_dup, "Duplicate add should fail")
	assert_eq(container.get_item_count(), 2, "Container should still have 2 items")

	# Remove item
	var removed = container.remove_item(item1)
	assert_true(removed, "Remove should succeed")
	assert_eq(container.get_item_count(), 1, "Container should have 1 item after remove")

	# Cannot remove item not in container
	var removed_again = container.remove_item(item1)
	assert_false(removed_again, "Remove non-existent should fail")

	container.queue_free()


func test_container_capacity() -> void:
	test("ItemContainer capacity limits")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 3

	var items: Array[ItemEntity] = []
	for i in 4:
		var item: ItemEntity = ItemEntityScene.instantiate()
		item.item_tag = "item_%d" % i
		test_area.add_child(item)
		items.append(item)

	# Add up to capacity
	assert_true(container.add_item(items[0]), "Item 0 should be added")
	assert_true(container.add_item(items[1]), "Item 1 should be added")
	assert_true(container.add_item(items[2]), "Item 2 should be added")

	assert_true(container.has_space() == false, "Container should be full")

	# Fourth item should fail
	assert_false(container.add_item(items[3]), "Item 3 should fail - at capacity")
	assert_eq(container.get_item_count(), 3, "Container should have exactly 3 items")

	# Remove one, now can add
	container.remove_item(items[0])
	assert_true(container.has_space(), "Container should have space after remove")
	assert_true(container.add_item(items[3]), "Item 3 should now be addable")

	container.queue_free()
	for item in items:
		if is_instance_valid(item) and item.get_parent() != container:
			item.queue_free()


func test_container_tag_filtering() -> void:
	test("ItemContainer tag filtering")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10
	container.allowed_tags = ["food", "drink"] as Array[String]

	var food_item: ItemEntity = ItemEntityScene.instantiate()
	var tool_item: ItemEntity = ItemEntityScene.instantiate()
	food_item.item_tag = "food"
	tool_item.item_tag = "tool"
	test_area.add_child(food_item)
	test_area.add_child(tool_item)

	# Food should be allowed
	assert_true(container.is_tag_allowed("food"), "Food tag should be allowed")
	assert_true(container.add_item(food_item), "Food item should be added")

	# Tool should be rejected
	assert_false(container.is_tag_allowed("tool"), "Tool tag should not be allowed")
	assert_false(container.add_item(tool_item), "Tool item should be rejected")

	assert_eq(container.get_item_count(), 1, "Only food item should be in container")

	container.queue_free()
	tool_item.queue_free()


func test_container_available_items() -> void:
	test("ItemContainer available items (respects reservation)")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 5

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	var item3: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "food"
	item2.item_tag = "food"
	item3.item_tag = "tool"

	container.add_item(item1)
	container.add_item(item2)
	container.add_item(item3)

	var fake_agent = Node.new()
	test_area.add_child(fake_agent)

	# All items available initially
	var available = container.get_available_items()
	assert_array_size(available, 3, "All 3 items should be available")

	# Reserve one item
	item1.reserve_item(fake_agent)

	available = container.get_available_items()
	assert_array_size(available, 2, "Only 2 items should be available after reservation")
	assert_array_not_contains(available, item1, "Reserved item should not be in available list")

	# Check available by tag
	var available_food = container.get_available_items_by_tag("food")
	assert_array_size(available_food, 1, "Only 1 food should be available")

	assert_true(container.has_available_item("food"), "Should have available food")
	assert_eq(container.get_available_count("food"), 1, "Should have 1 available food")

	container.queue_free()
	fake_agent.queue_free()


func test_container_find_by_tag() -> void:
	test("ItemContainer find by tag")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	var item3: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "food"
	item2.item_tag = "food"
	item3.item_tag = "tool"

	container.add_item(item1)
	container.add_item(item2)
	container.add_item(item3)

	# Find single
	var found = container.find_item_by_tag("food")
	assert_not_null(found, "Should find a food item")
	assert_eq(found.item_tag, "food", "Found item should have food tag")

	# Find all
	var all_food = container.find_all_items_by_tag("food")
	assert_array_size(all_food, 2, "Should find 2 food items")

	# Find non-existent
	var not_found = container.find_item_by_tag("nonexistent")
	assert_null(not_found, "Should not find nonexistent tag")

	container.queue_free()

# ============================================================================
# Job reservation tests (US-009)
# ============================================================================

func test_job_claim_reserves_items() -> void:
	test("Job claim reserves required items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	# Add required items
	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	var tool_item: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "raw_food"
	item2.item_tag = "raw_food"
	tool_item.item_tag = "knife"
	container.add_item(item1)
	container.add_item(item2)
	container.add_item(tool_item)

	# Create recipe requiring 2 raw_food and 1 knife tool
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Cooking"
	recipe.add_input("raw_food", 2, true)
	recipe.add_tool("knife")
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	# Create job and agent
	var job := Job.new(recipe, 1)
	var agent := Node.new()
	test_area.add_child(agent)

	# Items should not be reserved initially
	assert_false(item1.is_reserved(), "Item1 should not be reserved initially")
	assert_false(item2.is_reserved(), "Item2 should not be reserved initially")
	assert_false(tool_item.is_reserved(), "Tool should not be reserved initially")
	assert_eq(container.get_available_count("raw_food"), 2, "Should have 2 available raw_food")

	# Claim job with containers
	var claimed := job.claim(agent)
	assert_true(claimed, "Job should be claimed")

	# Manually call reservation (simulating what JobBoard does)
	var job_board_script = preload("res://scripts/job_board.gd")
	var board = job_board_script.new()
	test_area.add_child(board)

	# Post and claim through board
	var posted_job := board.post_job(recipe, 1)
	board.claim_job(posted_job, agent, [container])

	# Verify items are now reserved
	assert_true(item1.is_reserved(), "Item1 should be reserved after claim")
	assert_true(item2.is_reserved(), "Item2 should be reserved after claim")
	assert_true(tool_item.is_reserved(), "Tool should be reserved after claim")
	assert_eq(container.get_available_count("raw_food"), 0, "Should have 0 available raw_food after reservation")

	# Verify items are tracked in job
	assert_eq(posted_job.gathered_items.size(), 3, "Job should have 3 gathered items")

	board.queue_free()
	container.queue_free()
	agent.queue_free()

func test_job_release_unreserves_items() -> void:
	test("Job release unreserves items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	var recipe := Recipe.new()
	recipe.recipe_name = "Test"
	recipe.add_input("raw_food", 1, true)
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var agent := Node.new()
	test_area.add_child(agent)

	var job_board_script = preload("res://scripts/job_board.gd")
	var board = job_board_script.new()
	test_area.add_child(board)

	var job := board.post_job(recipe, 1)
	board.claim_job(job, agent, [container])

	# Item should be reserved
	assert_true(item.is_reserved(), "Item should be reserved after claim")
	assert_eq(container.get_available_count("raw_food"), 0, "No available items after claim")

	# Release the job
	board.release_job(job)

	# Item should be unreserved
	assert_false(item.is_reserved(), "Item should be unreserved after release")
	assert_eq(container.get_available_count("raw_food"), 1, "Item available again after release")

	board.queue_free()
	container.queue_free()
	agent.queue_free()

func test_job_complete_unreserves_items() -> void:
	test("Job completion unreserves items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	var recipe := Recipe.new()
	recipe.recipe_name = "Test"
	recipe.add_input("raw_food", 1, true)
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var agent := Node.new()
	test_area.add_child(agent)

	var job_board_script = preload("res://scripts/job_board.gd")
	var board = job_board_script.new()
	test_area.add_child(board)

	var job := board.post_job(recipe, 1)
	board.claim_job(job, agent, [container])

	assert_true(item.is_reserved(), "Item should be reserved after claim")

	# Start and complete the job
	job.start()
	job.complete()

	# Item should be unreserved after completion
	assert_false(item.is_reserved(), "Item should be unreserved after completion")
	assert_eq(container.get_available_count("raw_food"), 1, "Item available again after completion")

	board.queue_free()
	container.queue_free()
	agent.queue_free()

func test_job_fail_unreserves_items() -> void:
	test("Job failure unreserves items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	var recipe := Recipe.new()
	recipe.recipe_name = "Test"
	recipe.add_input("raw_food", 1, true)
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var agent := Node.new()
	test_area.add_child(agent)

	var job_board_script = preload("res://scripts/job_board.gd")
	var board = job_board_script.new()
	test_area.add_child(board)

	var job := board.post_job(recipe, 1)
	board.claim_job(job, agent, [container])

	assert_true(item.is_reserved(), "Item should be reserved after claim")

	# Start and fail the job
	job.start()
	job.fail("Test failure")

	# Item should be unreserved after failure
	assert_false(item.is_reserved(), "Item should be unreserved after failure")
	assert_eq(container.get_available_count("raw_food"), 1, "Item available again after failure")

	board.queue_free()
	container.queue_free()
	agent.queue_free()

func test_job_interrupt_unreserves_items() -> void:
	test("Job interruption unreserves items")

	var container: ItemContainer = ContainerScene.instantiate()
	test_area.add_child(container)
	container.capacity = 10

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	var recipe := Recipe.new()
	recipe.recipe_name = "Test"
	recipe.add_input("raw_food", 1, true)
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)

	var agent := Node.new()
	test_area.add_child(agent)

	var job_board_script = preload("res://scripts/job_board.gd")
	var board = job_board_script.new()
	test_area.add_child(board)

	var job := board.post_job(recipe, 1)
	board.claim_job(job, agent, [container])

	assert_true(item.is_reserved(), "Item should be reserved after claim")

	# Start and interrupt the job
	job.start()
	job.interrupt()

	# Item should be unreserved after interruption
	assert_false(item.is_reserved(), "Item should be unreserved after interruption")
	assert_eq(container.get_available_count("raw_food"), 1, "Item available again after interruption")
	assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be in INTERRUPTED state")

	board.queue_free()
	container.queue_free()
	agent.queue_free()
