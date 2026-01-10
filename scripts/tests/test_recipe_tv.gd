extends "res://scripts/tests/test_runner.gd"
## Tests for Watch TV Recipe (US-017)
## Verifies full TV watching sequence execution with fun motive effect

# Preload scenes and resources
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var watch_tv_recipe: Recipe
var test_area: Node2D

func _ready() -> void:
	_test_name = "Watch TV Recipe"
	test_area = $TestArea
	# Load the recipe resource
	watch_tv_recipe = load("res://resources/recipes/watch_tv.tres")
	super._ready()

func run_tests() -> void:
	_log_header()
	test_recipe_loads_correctly()
	test_recipe_has_no_inputs()
	test_watch_tv_no_tools()
	test_watch_tv_has_steps()
	test_recipe_has_no_outputs()
	test_watch_tv_has_fun_motive()
	test_step_details()
	test_full_tv_sequence_setup()
	test_turn_on_step_at_tv()
	test_watch_step_at_couch()
	test_turn_off_step_at_tv()
	test_agent_can_execute_full_sequence()
	test_watch_tv_can_start_without_tools()
	_log_summary()

func test_recipe_loads_correctly() -> void:
	test("Recipe loads from .tres file")

	assert_not_null(watch_tv_recipe, "Recipe should load")
	assert_eq(watch_tv_recipe.recipe_name, "Watch TV", "Recipe name should match")

func test_recipe_has_no_inputs() -> void:
	test("Recipe has no inputs")

	var inputs := watch_tv_recipe.get_inputs()
	assert_eq(inputs.size(), 0, "Should have 0 inputs")
	assert_false(watch_tv_recipe.has_inputs(), "has_inputs() should return false")

func test_watch_tv_no_tools() -> void:
	test("Recipe has no tools (US-004)")

	assert_false(watch_tv_recipe.has_tools(), "Should not have tools")
	assert_true(watch_tv_recipe.tools.is_empty(), "tools array should be empty")

func test_watch_tv_has_steps() -> void:
	test("Recipe has steps (US-004)")

	assert_eq(watch_tv_recipe.get_step_count(), 3, "Should have 3 steps")

	var step1 := watch_tv_recipe.get_step(0)
	assert_not_null(step1, "Step 1 should exist")
	assert_eq(step1.station_tag, "tv", "Step 1 should be at tv")
	assert_eq(step1.action, "turn_on", "Step 1 action should be turn_on")
	assert_eq(step1.duration, 1.0, "Step 1 duration should be 1s")

	var step2 := watch_tv_recipe.get_step(1)
	assert_not_null(step2, "Step 2 should exist")
	assert_eq(step2.station_tag, "couch", "Step 2 should be at couch")
	assert_eq(step2.action, "watch", "Step 2 action should be watch")
	assert_eq(step2.duration, 10.0, "Step 2 duration should be 10s")

	var step3 := watch_tv_recipe.get_step(2)
	assert_not_null(step3, "Step 3 should exist")
	assert_eq(step3.station_tag, "tv", "Step 3 should be at tv")
	assert_eq(step3.action, "turn_off", "Step 3 action should be turn_off")
	assert_eq(step3.duration, 1.0, "Step 3 duration should be 1s")

func test_recipe_has_no_outputs() -> void:
	test("Recipe has no outputs")

	var outputs := watch_tv_recipe.get_outputs()
	assert_eq(outputs.size(), 0, "Should have no outputs")
	assert_false(watch_tv_recipe.has_outputs(), "has_outputs() should return false")

func test_watch_tv_has_fun_motive() -> void:
	test("Recipe has fun motive effect (US-004)")

	assert_true(watch_tv_recipe.motive_effects.has("fun"), "Should have fun motive effect")
	assert_eq(watch_tv_recipe.get_motive_effect("fun"), 40.0, "Fun effect should be 40")

func test_step_details() -> void:
	test("Steps have correct details")

	var step1 := watch_tv_recipe.get_step(0)
	assert_eq(step1.animation, "using_remote", "Step 1 animation should be using_remote")
	assert_true(step1.input_transform.is_empty(), "Step 1 should have no transforms")

	var step2 := watch_tv_recipe.get_step(1)
	assert_eq(step2.animation, "sitting", "Step 2 animation should be sitting")
	assert_true(step2.input_transform.is_empty(), "Step 2 should have no transforms")

	var step3 := watch_tv_recipe.get_step(2)
	assert_eq(step3.animation, "using_remote", "Step 3 animation should be using_remote")
	assert_true(step3.input_transform.is_empty(), "Step 3 should have no transforms")

func test_full_tv_sequence_setup() -> void:
	test("Full TV sequence can be set up (no tools required)")

	# Create NPC
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create stations
	var tv: Station = StationScene.instantiate()
	tv.station_tag = "tv"
	tv.position = Vector2(100, 0)
	test_area.add_child(tv)

	var couch: Station = StationScene.instantiate()
	couch.station_tag = "couch"
	couch.position = Vector2(150, 0)
	test_area.add_child(couch)

	# Add markers to stations
	var tv_footprint := Marker2D.new()
	tv_footprint.name = "AgentFootprint"
	tv.add_child(tv_footprint)
	tv._auto_discover_markers()

	var couch_footprint := Marker2D.new()
	couch_footprint.name = "AgentFootprint"
	couch.add_child(couch_footprint)
	couch._auto_discover_markers()

	# Set up NPC with stations (no containers needed - no tools)
	var stations: Array[Station] = [tv, couch]
	npc.set_available_stations(stations)

	# Create and post job
	var job := Job.new(watch_tv_recipe, 5)

	assert_not_null(job, "Job should be created")
	assert_eq(job.recipe.recipe_name, "Watch TV", "Job should use watch TV recipe")

	# Cleanup
	tv.queue_free()
	couch.queue_free()
	npc.queue_free()

func test_watch_tv_can_start_without_tools() -> void:
	test("can_start_job succeeds without tool items (US-004)")

	# Create NPC
	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create stations
	var tv: Station = StationScene.instantiate()
	tv.station_tag = "tv"
	test_area.add_child(tv)

	var tv_footprint := Marker2D.new()
	tv_footprint.name = "AgentFootprint"
	tv.add_child(tv_footprint)
	tv._auto_discover_markers()

	var couch: Station = StationScene.instantiate()
	couch.station_tag = "couch"
	test_area.add_child(couch)

	var couch_footprint := Marker2D.new()
	couch_footprint.name = "AgentFootprint"
	couch.add_child(couch_footprint)
	couch._auto_discover_markers()

	# Set up NPC with stations only (no containers, no tools)
	var stations: Array[Station] = [tv, couch]
	npc.set_available_stations(stations)

	# Verify recipe has no tools requirement
	assert_false(watch_tv_recipe.has_tools(), "Recipe should not require tools")

	# Create job and verify NPC can start it without any tools
	var job := Job.new(watch_tv_recipe, 5)

	# The job should be startable - NPC doesn't need to gather any tools
	assert_not_null(job, "Job should be created")
	assert_false(watch_tv_recipe.has_tools(), "Recipe should have no tools")
	assert_false(watch_tv_recipe.has_inputs(), "Recipe should have no inputs")

	# Claim and start job
	job.claim(npc)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be claimed")

	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should start without needing tools")

	# Cleanup
	tv.queue_free()
	couch.queue_free()
	npc.queue_free()

func test_turn_on_step_at_tv() -> void:
	test("Turn on step works at TV station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create TV station
	var tv: Station = StationScene.instantiate()
	tv.station_tag = "tv"
	test_area.add_child(tv)

	var footprint := Marker2D.new()
	footprint.name = "AgentFootprint"
	tv.add_child(footprint)
	tv._auto_discover_markers()

	npc.target_station = tv

	# Get turn_on step
	var turn_on_step := watch_tv_recipe.get_step(0)
	assert_eq(turn_on_step.station_tag, "tv", "Turn on step should be at tv")
	assert_eq(turn_on_step.action, "turn_on", "Action should be turn_on")
	assert_eq(turn_on_step.duration, 1.0, "Duration should be 1s")
	assert_true(turn_on_step.input_transform.is_empty(), "No transforms expected")

	tv.queue_free()
	npc.queue_free()

func test_watch_step_at_couch() -> void:
	test("Watch step works at couch station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create couch station
	var couch: Station = StationScene.instantiate()
	couch.station_tag = "couch"
	test_area.add_child(couch)

	var footprint := Marker2D.new()
	footprint.name = "AgentFootprint"
	couch.add_child(footprint)
	couch._auto_discover_markers()

	npc.target_station = couch

	# Get watch step
	var watch_step := watch_tv_recipe.get_step(1)
	assert_eq(watch_step.station_tag, "couch", "Watch step should be at couch")
	assert_eq(watch_step.action, "watch", "Action should be watch")
	assert_eq(watch_step.duration, 10.0, "Duration should be 10s")
	assert_true(watch_step.input_transform.is_empty(), "No transforms expected")

	couch.queue_free()
	npc.queue_free()

func test_turn_off_step_at_tv() -> void:
	test("Turn off step works at TV station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create TV station
	var tv: Station = StationScene.instantiate()
	tv.station_tag = "tv"
	test_area.add_child(tv)

	var footprint := Marker2D.new()
	footprint.name = "AgentFootprint"
	tv.add_child(footprint)
	tv._auto_discover_markers()

	npc.target_station = tv

	# Get turn_off step
	var turn_off_step := watch_tv_recipe.get_step(2)
	assert_eq(turn_off_step.station_tag, "tv", "Turn off step should be at tv")
	assert_eq(turn_off_step.action, "turn_off", "Action should be turn_off")
	assert_eq(turn_off_step.duration, 1.0, "Duration should be 1s")
	assert_true(turn_off_step.input_transform.is_empty(), "No transforms expected")

	tv.queue_free()
	npc.queue_free()

func test_agent_can_execute_full_sequence() -> void:
	test("Agent can execute full TV watching sequence (no tools needed)")

	# Create NPC
	var npc = NPCScene.instantiate()
	npc.position = Vector2(0, 0)
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create stations with proper markers
	var tv: Station = StationScene.instantiate()
	tv.station_tag = "tv"
	tv.position = Vector2(100, 0)
	test_area.add_child(tv)

	var tv_footprint := Marker2D.new()
	tv_footprint.name = "AgentFootprint"
	tv_footprint.position = Vector2(0, 20)
	tv.add_child(tv_footprint)
	tv._auto_discover_markers()

	var couch: Station = StationScene.instantiate()
	couch.station_tag = "couch"
	couch.position = Vector2(150, 0)
	test_area.add_child(couch)

	var couch_footprint := Marker2D.new()
	couch_footprint.name = "AgentFootprint"
	couch_footprint.position = Vector2(0, 20)
	couch.add_child(couch_footprint)
	couch._auto_discover_markers()

	# Set up NPC with stations (no tools required)
	var stations: Array[Station] = [tv, couch]
	npc.set_available_stations(stations)

	# Create job
	var job := Job.new(watch_tv_recipe, 5)

	# Manually simulate the TV watching sequence stages
	# 1. Claim job
	job.claim(npc)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be claimed")

	# 2. No tools to gather - NPC should have no held items
	assert_eq(npc.held_items.size(), 0, "NPC should hold 0 items (no tools)")

	# 3. Start job
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be in progress")

	# 4. Simulate step 1 (turn_on at tv)
	npc.target_station = tv

	var turn_on_step := watch_tv_recipe.get_step(0)
	assert_eq(turn_on_step.action, "turn_on", "Step 1 should be turn_on")
	assert_true(turn_on_step.input_transform.is_empty(), "Turn on step has no transforms")

	# Advance to next step
	job.advance_step()
	assert_eq(job.current_step_index, 1, "Should be at step 1 (watch)")

	# 5. Simulate step 2 (watch at couch)
	npc.target_station = couch

	var watch_step := watch_tv_recipe.get_step(1)
	assert_eq(watch_step.action, "watch", "Step 2 should be watch")
	assert_eq(watch_step.duration, 10.0, "Watch step should be 10s")
	assert_true(watch_step.input_transform.is_empty(), "Watch step has no transforms")

	# Advance to next step
	job.advance_step()
	assert_eq(job.current_step_index, 2, "Should be at step 2 (turn_off)")

	# 6. Simulate step 3 (turn_off at tv)
	npc.target_station = tv

	var turn_off_step := watch_tv_recipe.get_step(2)
	assert_eq(turn_off_step.action, "turn_off", "Step 3 should be turn_off")
	assert_true(turn_off_step.input_transform.is_empty(), "Turn off step has no transforms")

	# Advance past last step
	job.advance_step()
	assert_eq(job.current_step_index, 3, "Should be past last step")

	# 7. Complete job with motive effects
	# Get initial fun value
	var initial_fun: float = npc.motives.get_value(Motive.MotiveType.FUN)

	# Apply motive effects manually (simulating _finish_job)
	for motive_name in watch_tv_recipe.motive_effects:
		var effect: float = watch_tv_recipe.motive_effects[motive_name]
		if motive_name == "fun":
			npc.motives.fulfill(Motive.MotiveType.FUN, effect)

	var final_fun: float = npc.motives.get_value(Motive.MotiveType.FUN)
	assert_true(final_fun > initial_fun, "Fun should increase after watching TV")

	job.complete()
	assert_eq(job.state, Job.JobState.COMPLETED, "Job should be completed")

	# Cleanup
	tv.queue_free()
	couch.queue_free()
	npc.queue_free()
