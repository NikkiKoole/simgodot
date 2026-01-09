extends "res://scripts/tests/test_runner.gd"
## Tests for Use Toilet Recipe (US-016)
## Verifies full toilet sequence execution with bladder motive effect

# Preload scenes and resources
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var use_toilet_recipe: Recipe
var test_area: Node2D

func _ready() -> void:
	_test_name = "Use Toilet Recipe"
	test_area = $TestArea
	# Load the recipe resource
	use_toilet_recipe = load("res://resources/recipes/use_toilet.tres")
	super._ready()

func run_tests() -> void:
	_log_header()
	test_recipe_loads_correctly()
	test_recipe_has_correct_inputs()
	test_recipe_has_correct_steps()
	test_recipe_has_no_outputs()
	test_recipe_has_correct_motive_effects()
	test_step_details()
	test_full_toilet_sequence_setup()
	test_sit_step_at_toilet()
	test_wash_hands_step_at_sink()
	test_agent_can_execute_full_sequence()
	_log_summary()

func test_recipe_loads_correctly() -> void:
	test("Recipe loads from .tres file")

	assert_not_null(use_toilet_recipe, "Recipe should load")
	assert_eq(use_toilet_recipe.recipe_name, "Use Toilet", "Recipe name should match")

func test_recipe_has_correct_inputs() -> void:
	test("Recipe has correct inputs (1x toilet_paper, consumed)")

	var inputs := use_toilet_recipe.get_inputs()
	assert_eq(inputs.size(), 1, "Should have 1 input")

	if inputs.size() > 0:
		var input := inputs[0]
		assert_eq(input.item_tag, "toilet_paper", "Input should be toilet_paper")
		assert_eq(input.quantity, 1, "Quantity should be 1")
		assert_true(input.consumed, "Input should be consumed")

func test_recipe_has_correct_steps() -> void:
	test("Recipe has correct steps (sit at toilet, wash_hands at sink)")

	assert_eq(use_toilet_recipe.get_step_count(), 2, "Should have 2 steps")

	var step1 := use_toilet_recipe.get_step(0)
	assert_not_null(step1, "Step 1 should exist")
	assert_eq(step1.station_tag, "toilet", "Step 1 should be at toilet")
	assert_eq(step1.action, "sit", "Step 1 action should be sit")
	assert_eq(step1.duration, 5.0, "Step 1 duration should be 5s")

	var step2 := use_toilet_recipe.get_step(1)
	assert_not_null(step2, "Step 2 should exist")
	assert_eq(step2.station_tag, "sink", "Step 2 should be at sink")
	assert_eq(step2.action, "wash_hands", "Step 2 action should be wash_hands")
	assert_eq(step2.duration, 2.0, "Step 2 duration should be 2s")

func test_recipe_has_no_outputs() -> void:
	test("Recipe has no outputs")

	var outputs := use_toilet_recipe.get_outputs()
	assert_eq(outputs.size(), 0, "Should have no outputs")
	assert_false(use_toilet_recipe.has_outputs(), "has_outputs() should return false")

func test_recipe_has_correct_motive_effects() -> void:
	test("Recipe has correct motive effects (bladder: 80)")

	assert_true(use_toilet_recipe.affects_motive("bladder"), "Should affect bladder")
	assert_eq(use_toilet_recipe.get_motive_effect("bladder"), 80.0, "Bladder effect should be 80")

func test_step_details() -> void:
	test("Steps have correct details")

	var step1 := use_toilet_recipe.get_step(0)
	assert_eq(step1.animation, "sitting", "Step 1 animation should be sitting")
	assert_true(step1.input_transform.is_empty(), "Step 1 should have no transforms")

	var step2 := use_toilet_recipe.get_step(1)
	assert_eq(step2.animation, "washing", "Step 2 animation should be washing")
	assert_true(step2.input_transform.is_empty(), "Step 2 should have no transforms")

func test_full_toilet_sequence_setup() -> void:
	test("Full toilet sequence can be set up")

	# Create NPC
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create container with toilet_paper
	var container: ItemContainer = ContainerScene.instantiate()
	container.position = Vector2(50, 0)
	test_area.add_child(container)

	var toilet_paper: ItemEntity = ItemEntityScene.instantiate()
	toilet_paper.item_tag = "toilet_paper"
	test_area.add_child(toilet_paper)
	container.add_item(toilet_paper)

	# Create stations
	var toilet: Station = StationScene.instantiate()
	toilet.station_tag = "toilet"
	toilet.position = Vector2(100, 0)
	test_area.add_child(toilet)

	var sink: Station = StationScene.instantiate()
	sink.station_tag = "sink"
	sink.position = Vector2(150, 0)
	test_area.add_child(sink)

	# Add markers to stations
	var toilet_input := Marker2D.new()
	toilet_input.name = "InputSlot0"
	toilet.add_child(toilet_input)
	var toilet_footprint := Marker2D.new()
	toilet_footprint.name = "AgentFootprint"
	toilet.add_child(toilet_footprint)
	toilet._auto_discover_markers()

	var sink_footprint := Marker2D.new()
	sink_footprint.name = "AgentFootprint"
	sink.add_child(sink_footprint)
	sink._auto_discover_markers()

	# Set up NPC with containers and stations
	var containers: Array[ItemContainer] = [container]
	var stations: Array[Station] = [toilet, sink]
	npc.set_available_containers(containers)
	npc.set_available_stations(stations)

	# Create and post job
	var job := Job.new(use_toilet_recipe, 5)

	assert_not_null(job, "Job should be created")
	assert_eq(job.recipe.recipe_name, "Use Toilet", "Job should use toilet recipe")

	# Cleanup
	container.queue_free()
	toilet.queue_free()
	sink.queue_free()
	npc.queue_free()

func test_sit_step_at_toilet() -> void:
	test("Sit step works at toilet station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create toilet station with input slot
	var toilet: Station = StationScene.instantiate()
	toilet.station_tag = "toilet"
	test_area.add_child(toilet)

	var slot_marker := Marker2D.new()
	slot_marker.name = "InputSlot0"
	toilet.add_child(slot_marker)
	var footprint := Marker2D.new()
	footprint.name = "AgentFootprint"
	toilet.add_child(footprint)
	toilet._auto_discover_markers()

	npc.target_station = toilet

	# Create toilet_paper item and place in station
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "toilet_paper"
	test_area.add_child(item)
	toilet.place_input_item(item, 0)

	# Get sit step - no transforms expected
	var sit_step := use_toilet_recipe.get_step(0)
	assert_eq(sit_step.station_tag, "toilet", "Sit step should be at toilet")
	assert_eq(sit_step.action, "sit", "Action should be sit")
	assert_eq(sit_step.duration, 5.0, "Duration should be 5s")

	# Item should remain unchanged (no transforms)
	assert_eq(item.item_tag, "toilet_paper", "Item tag should remain toilet_paper")

	toilet.queue_free()
	npc.queue_free()

func test_wash_hands_step_at_sink() -> void:
	test("Wash hands step works at sink station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create sink station
	var sink: Station = StationScene.instantiate()
	sink.station_tag = "sink"
	test_area.add_child(sink)

	var footprint := Marker2D.new()
	footprint.name = "AgentFootprint"
	sink.add_child(footprint)
	sink._auto_discover_markers()

	npc.target_station = sink

	# Get wash_hands step - no transforms expected
	var wash_step := use_toilet_recipe.get_step(1)
	assert_eq(wash_step.station_tag, "sink", "Wash step should be at sink")
	assert_eq(wash_step.action, "wash_hands", "Action should be wash_hands")
	assert_eq(wash_step.duration, 2.0, "Duration should be 2s")

	sink.queue_free()
	npc.queue_free()

func test_agent_can_execute_full_sequence() -> void:
	test("Agent can execute full toilet sequence")

	# Create NPC
	var npc = NPCScene.instantiate()
	npc.position = Vector2(0, 0)
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create container with toilet_paper
	var container: ItemContainer = ContainerScene.instantiate()
	container.position = Vector2(50, 0)
	test_area.add_child(container)

	var toilet_paper: ItemEntity = ItemEntityScene.instantiate()
	toilet_paper.item_tag = "toilet_paper"
	test_area.add_child(toilet_paper)
	container.add_item(toilet_paper)

	# Create stations with proper markers
	var toilet: Station = StationScene.instantiate()
	toilet.station_tag = "toilet"
	toilet.position = Vector2(100, 0)
	test_area.add_child(toilet)

	var toilet_input := Marker2D.new()
	toilet_input.name = "InputSlot0"
	toilet.add_child(toilet_input)
	var toilet_footprint := Marker2D.new()
	toilet_footprint.name = "AgentFootprint"
	toilet_footprint.position = Vector2(0, 20)
	toilet.add_child(toilet_footprint)
	toilet._auto_discover_markers()

	var sink: Station = StationScene.instantiate()
	sink.station_tag = "sink"
	sink.position = Vector2(150, 0)
	test_area.add_child(sink)

	var sink_footprint := Marker2D.new()
	sink_footprint.name = "AgentFootprint"
	sink_footprint.position = Vector2(0, 20)
	sink.add_child(sink_footprint)
	sink._auto_discover_markers()

	# Set up NPC
	var containers: Array[ItemContainer] = [container]
	var stations: Array[Station] = [toilet, sink]
	npc.set_available_containers(containers)
	npc.set_available_stations(stations)

	# Create job
	var job := Job.new(use_toilet_recipe, 5)

	# Manually simulate the toilet sequence stages
	# 1. Claim job
	job.claim(npc)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be claimed")

	# 2. Gather toilet_paper
	container.remove_item(toilet_paper)
	toilet_paper.set_location(ItemEntity.ItemLocation.IN_HAND)
	npc.held_items.append(toilet_paper)
	job.add_gathered_item(toilet_paper)

	assert_eq(npc.held_items.size(), 1, "NPC should hold 1 item")
	assert_eq(toilet_paper.location, ItemEntity.ItemLocation.IN_HAND, "Item should be IN_HAND")

	# 3. Start job
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be in progress")

	# 4. Simulate step 1 (sit at toilet)
	# Place item in toilet input slot
	npc.held_items.erase(toilet_paper)
	toilet.place_input_item(toilet_paper, 0)
	npc.target_station = toilet

	# No transforms for sit step
	var sit_step := use_toilet_recipe.get_step(0)
	assert_true(sit_step.input_transform.is_empty(), "Sit step has no transforms")

	# Item remains toilet_paper
	assert_eq(toilet_paper.item_tag, "toilet_paper", "Item should still be toilet_paper")

	# Advance to next step
	job.advance_step()
	assert_eq(job.current_step_index, 1, "Should be at step 1 (wash_hands)")

	# 5. Simulate step 2 (wash_hands at sink)
	# Move to sink (toilet_paper is consumed, stays at toilet for cleanup)
	npc.target_station = sink

	# No transforms for wash step
	var wash_step := use_toilet_recipe.get_step(1)
	assert_true(wash_step.input_transform.is_empty(), "Wash step has no transforms")

	# 6. Complete job
	job.advance_step()
	assert_eq(job.current_step_index, 2, "Should be past last step")

	# Get initial bladder value
	var initial_bladder: float = npc.motives.get_value(Motive.MotiveType.BLADDER)

	# Apply motive effects manually (simulating _finish_job)
	for motive_name in use_toilet_recipe.motive_effects:
		var effect: float = use_toilet_recipe.motive_effects[motive_name]
		if motive_name == "bladder":
			npc.motives.fulfill(Motive.MotiveType.BLADDER, effect)

	var final_bladder: float = npc.motives.get_value(Motive.MotiveType.BLADDER)
	assert_true(final_bladder > initial_bladder, "Bladder should increase after using toilet")

	# Verify consumed item behavior
	var consumed_tags := use_toilet_recipe.get_consumed_input_tags()
	assert_eq(consumed_tags.size(), 1, "Should have 1 consumed input")
	assert_true(consumed_tags.has("toilet_paper"), "toilet_paper should be consumed")

	job.complete()
	assert_eq(job.state, Job.JobState.COMPLETED, "Job should be completed")

	# Cleanup
	container.queue_free()
	toilet.queue_free()
	sink.queue_free()
	npc.queue_free()
