extends "res://scripts/tests/test_runner.gd"
## Tests for Cook Simple Meal Recipe (US-015)
## Verifies full cooking sequence execution from raw_food to cooked_meal

# Preload scenes and resources
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var cook_simple_meal_recipe: Recipe
var test_area: Node2D

func _ready() -> void:
	_test_name = "Cook Simple Meal Recipe"
	test_area = $TestArea
	# Load the recipe resource
	cook_simple_meal_recipe = load("res://resources/recipes/cook_simple_meal.tres")
	super._ready()

func run_tests() -> void:
	_log_header()
	test_recipe_loads_correctly()
	test_recipe_has_correct_inputs()
	test_recipe_has_correct_steps()
	test_recipe_has_correct_outputs()
	test_cook_simple_meal_no_motive_effects()
	test_step_transforms()
	test_full_cooking_sequence_setup()
	test_prep_step_transforms_raw_to_prepped()
	test_cook_step_transforms_prepped_to_cooked()
	test_agent_can_execute_full_sequence()
	test_cooking_does_not_satisfy_hunger()
	_log_summary()

func test_recipe_loads_correctly() -> void:
	test("Recipe loads from .tres file")

	assert_not_null(cook_simple_meal_recipe, "Recipe should load")
	assert_eq(cook_simple_meal_recipe.recipe_name, "Cook Simple Meal", "Recipe name should match")

func test_recipe_has_correct_inputs() -> void:
	test("Recipe has correct inputs (1x raw_food, consumed)")

	var inputs := cook_simple_meal_recipe.get_inputs()
	assert_eq(inputs.size(), 1, "Should have 1 input")

	if inputs.size() > 0:
		var input := inputs[0]
		assert_eq(input.item_tag, "raw_food", "Input should be raw_food")
		assert_eq(input.quantity, 1, "Quantity should be 1")
		assert_true(input.consumed, "Input should be consumed")

func test_recipe_has_correct_steps() -> void:
	test("Recipe has correct steps (prep at counter, cook at stove)")

	assert_eq(cook_simple_meal_recipe.get_step_count(), 2, "Should have 2 steps")

	var step1 := cook_simple_meal_recipe.get_step(0)
	assert_not_null(step1, "Step 1 should exist")
	assert_eq(step1.station_tag, "counter", "Step 1 should be at counter")
	assert_eq(step1.action, "prep", "Step 1 action should be prep")
	assert_eq(step1.duration, 3.0, "Step 1 duration should be 3s")

	var step2 := cook_simple_meal_recipe.get_step(1)
	assert_not_null(step2, "Step 2 should exist")
	assert_eq(step2.station_tag, "stove", "Step 2 should be at stove")
	assert_eq(step2.action, "cook", "Step 2 action should be cook")
	assert_eq(step2.duration, 5.0, "Step 2 duration should be 5s")

func test_recipe_has_correct_outputs() -> void:
	test("Recipe has correct outputs (1x cooked_meal)")

	var outputs := cook_simple_meal_recipe.get_outputs()
	assert_eq(outputs.size(), 1, "Should have 1 output")

	if outputs.size() > 0:
		var output := outputs[0]
		assert_eq(output.item_tag, "cooked_meal", "Output should be cooked_meal")
		assert_eq(output.quantity, 1, "Quantity should be 1")

func test_cook_simple_meal_no_motive_effects() -> void:
	test("Recipe has no motive effects (US-003: cooking doesn't satisfy hunger)")

	assert_true(cook_simple_meal_recipe.motive_effects.is_empty(), "motive_effects should be empty")
	assert_false(cook_simple_meal_recipe.affects_motive("hunger"), "Should NOT affect hunger")

func test_step_transforms() -> void:
	test("Steps have correct input transforms")

	var step1 := cook_simple_meal_recipe.get_step(0)
	assert_true(step1.transforms_item("raw_food"), "Step 1 should transform raw_food")
	assert_eq(step1.get_transformed_tag("raw_food"), "prepped_food", "raw_food -> prepped_food")

	var step2 := cook_simple_meal_recipe.get_step(1)
	assert_true(step2.transforms_item("prepped_food"), "Step 2 should transform prepped_food")
	assert_eq(step2.get_transformed_tag("prepped_food"), "cooked_meal", "prepped_food -> cooked_meal")

func test_full_cooking_sequence_setup() -> void:
	test("Full cooking sequence can be set up")

	# Create NPC
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create container with raw_food
	var container: ItemContainer = ContainerScene.instantiate()
	container.position = Vector2(50, 0)
	test_area.add_child(container)

	var raw_food: ItemEntity = ItemEntityScene.instantiate()
	raw_food.item_tag = "raw_food"
	raw_food.set_state(ItemEntity.ItemState.RAW)
	test_area.add_child(raw_food)
	container.add_item(raw_food)

	# Create stations
	var counter: Station = StationScene.instantiate()
	counter.station_tag = "counter"
	counter.position = Vector2(100, 0)
	test_area.add_child(counter)

	var stove: Station = StationScene.instantiate()
	stove.station_tag = "stove"
	stove.position = Vector2(150, 0)
	test_area.add_child(stove)

	# Add markers to stations
	var counter_input := Marker2D.new()
	counter_input.name = "InputSlot0"
	counter.add_child(counter_input)
	counter._auto_discover_markers()

	var stove_input := Marker2D.new()
	stove_input.name = "InputSlot0"
	stove.add_child(stove_input)

	var stove_output := Marker2D.new()
	stove_output.name = "OutputSlot0"
	stove.add_child(stove_output)
	stove._auto_discover_markers()

	# Set up NPC with containers and stations
	var containers: Array[ItemContainer] = [container]
	var stations: Array[Station] = [counter, stove]
	npc.set_available_containers(containers)
	npc.set_available_stations(stations)

	# Create and post job
	var job := Job.new(cook_simple_meal_recipe, 5)

	assert_not_null(job, "Job should be created")
	assert_eq(job.recipe.recipe_name, "Cook Simple Meal", "Job should use cook recipe")

	# Cleanup
	container.queue_free()
	counter.queue_free()
	stove.queue_free()
	npc.queue_free()

func test_prep_step_transforms_raw_to_prepped() -> void:
	test("Prep step transforms raw_food to prepped_food")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create station with input slot
	var counter: Station = StationScene.instantiate()
	counter.station_tag = "counter"
	test_area.add_child(counter)

	var slot_marker := Marker2D.new()
	slot_marker.name = "InputSlot0"
	counter.add_child(slot_marker)
	counter._auto_discover_markers()

	npc.target_station = counter

	# Create raw_food item and place in station
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	item.set_state(ItemEntity.ItemState.RAW)
	test_area.add_child(item)
	counter.place_input_item(item, 0)

	# Get prep step and apply transform
	var prep_step := cook_simple_meal_recipe.get_step(0)
	npc._apply_step_transforms(prep_step)

	assert_eq(item.item_tag, "prepped_food", "Item tag should change to prepped_food")
	assert_eq(item.state, ItemEntity.ItemState.PREPPED, "Item state should be PREPPED")

	counter.queue_free()
	npc.queue_free()

func test_cook_step_transforms_prepped_to_cooked() -> void:
	test("Cook step transforms prepped_food to cooked_meal")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create station with input slot
	var stove: Station = StationScene.instantiate()
	stove.station_tag = "stove"
	test_area.add_child(stove)

	var slot_marker := Marker2D.new()
	slot_marker.name = "InputSlot0"
	stove.add_child(slot_marker)
	stove._auto_discover_markers()

	npc.target_station = stove

	# Create prepped_food item and place in station
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "prepped_food"
	item.set_state(ItemEntity.ItemState.PREPPED)
	test_area.add_child(item)
	stove.place_input_item(item, 0)

	# Get cook step and apply transform
	var cook_step := cook_simple_meal_recipe.get_step(1)
	npc._apply_step_transforms(cook_step)

	assert_eq(item.item_tag, "cooked_meal", "Item tag should change to cooked_meal")
	assert_eq(item.state, ItemEntity.ItemState.COOKED, "Item state should be COOKED")

	stove.queue_free()
	npc.queue_free()

func test_agent_can_execute_full_sequence() -> void:
	test("Agent can execute full cooking sequence")

	# Create NPC
	var npc = NPCScene.instantiate()
	npc.position = Vector2(0, 0)
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create container with raw_food
	var container: ItemContainer = ContainerScene.instantiate()
	container.position = Vector2(50, 0)
	test_area.add_child(container)

	var raw_food: ItemEntity = ItemEntityScene.instantiate()
	raw_food.item_tag = "raw_food"
	raw_food.set_state(ItemEntity.ItemState.RAW)
	test_area.add_child(raw_food)
	container.add_item(raw_food)

	# Create stations with proper markers
	var counter: Station = StationScene.instantiate()
	counter.station_tag = "counter"
	counter.position = Vector2(100, 0)
	test_area.add_child(counter)

	var counter_input := Marker2D.new()
	counter_input.name = "InputSlot0"
	counter.add_child(counter_input)
	var counter_footprint := Marker2D.new()
	counter_footprint.name = "AgentFootprint"
	counter_footprint.position = Vector2(0, 20)
	counter.add_child(counter_footprint)
	counter._auto_discover_markers()

	var stove: Station = StationScene.instantiate()
	stove.station_tag = "stove"
	stove.position = Vector2(150, 0)
	test_area.add_child(stove)

	var stove_input := Marker2D.new()
	stove_input.name = "InputSlot0"
	stove.add_child(stove_input)
	var stove_output := Marker2D.new()
	stove_output.name = "OutputSlot0"
	stove.add_child(stove_output)
	var stove_footprint := Marker2D.new()
	stove_footprint.name = "AgentFootprint"
	stove_footprint.position = Vector2(0, 20)
	stove.add_child(stove_footprint)
	stove._auto_discover_markers()

	# Set up NPC
	var containers: Array[ItemContainer] = [container]
	var stations: Array[Station] = [counter, stove]
	npc.set_available_containers(containers)
	npc.set_available_stations(stations)

	# Create job
	var job := Job.new(cook_simple_meal_recipe, 5)

	# Manually simulate the cooking sequence stages
	# 1. Claim job
	job.claim(npc)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be claimed")

	# 2. Gather raw_food
	container.remove_item(raw_food)
	raw_food.set_location(ItemEntity.ItemLocation.IN_HAND)
	npc.held_items.append(raw_food)
	job.add_gathered_item(raw_food)

	assert_eq(npc.held_items.size(), 1, "NPC should hold 1 item")
	assert_eq(raw_food.location, ItemEntity.ItemLocation.IN_HAND, "Item should be IN_HAND")

	# 3. Start job
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be in progress")

	# 4. Simulate step 1 (prep at counter)
	# Place item in counter
	npc.held_items.erase(raw_food)
	counter.place_input_item(raw_food, 0)
	npc.target_station = counter

	# Apply prep transform
	var prep_step := cook_simple_meal_recipe.get_step(0)
	npc._apply_step_transforms(prep_step)

	assert_eq(raw_food.item_tag, "prepped_food", "After prep: item should be prepped_food")
	assert_eq(raw_food.state, ItemEntity.ItemState.PREPPED, "After prep: state should be PREPPED")

	# Advance to next step
	job.advance_step()
	assert_eq(job.current_step_index, 1, "Should be at step 1 (cook)")

	# 5. Simulate step 2 (cook at stove)
	# Move item from counter to stove
	var prepped_food := counter.get_input_item(0)
	counter.remove_input_item(0)
	npc.held_items.append(prepped_food)
	stove.place_input_item(prepped_food, 0)
	npc.held_items.erase(prepped_food)
	npc.target_station = stove

	# Apply cook transform
	var cook_step := cook_simple_meal_recipe.get_step(1)
	npc._apply_step_transforms(cook_step)

	assert_eq(prepped_food.item_tag, "cooked_meal", "After cook: item should be cooked_meal")
	assert_eq(prepped_food.state, ItemEntity.ItemState.COOKED, "After cook: state should be COOKED")

	# 6. Complete job
	job.advance_step()
	assert_eq(job.current_step_index, 2, "Should be past last step")

	job.complete()
	assert_eq(job.state, Job.JobState.COMPLETED, "Job should be completed")

	# Cleanup
	container.queue_free()
	counter.queue_free()
	stove.queue_free()
	npc.queue_free()

func test_cooking_does_not_satisfy_hunger() -> void:
	test("Cooking does not satisfy hunger (US-003)")

	# Create NPC and record initial hunger
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	var initial_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)

	# Simulate completing the cooking job by applying recipe motive_effects
	# (This is what JobBoard.complete_job does)
	for motive_name in cook_simple_meal_recipe.motive_effects:
		var effect: float = cook_simple_meal_recipe.motive_effects[motive_name]
		if motive_name == "hunger":
			npc.motives.fulfill(Motive.MotiveType.HUNGER, effect)

	var final_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)

	# Since motive_effects is empty, hunger should be unchanged
	assert_eq(final_hunger, initial_hunger, "Hunger should be unchanged after cooking (motive_effects is empty)")

	npc.queue_free()
