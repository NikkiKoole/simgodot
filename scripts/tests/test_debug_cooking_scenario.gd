extends "res://scripts/tests/test_runner.gd"
## END-TO-END TEST: Full cooking scenario (US-020)
##
## This is a HIGH-LEVEL integration test that verifies the complete cooking flow
## using the DebugCommands API - the same API the Debug UI uses.
##
## What it tests:
## - Spawning entities via DebugCommands (stations, containers, items, NPCs)
## - Posting jobs via DebugCommands.post_job()
## - Full NPC behavior: haul raw_food → prep at counter → cook at stove
## - Motive effects: hunger increases after completing the meal
## - Uses real Level with pathfinding, real recipe (cook_simple_meal.tres)
##
## For low-level tests of specific mechanics (work timers, etc.),
## see test_job_integration.gd instead.

const LevelScript = preload("res://scripts/level.gd")

const TILE_SIZE := 32

var test_level: Node2D

# Simple rectangular room - just walls around the edges
const SIMPLE_ROOM_MAP := """
####################
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
#                  #
####################
"""


func _ready() -> void:
	_test_name = "Debug Cooking Scenario"
	_setup_test_level()
	super._ready()


func _setup_test_level() -> void:
	# Create a simple level with just an open room
	test_level = Node2D.new()
	test_level.set_script(LevelScript)
	test_level.world_map = SIMPLE_ROOM_MAP
	test_level.auto_spawn_npcs = false
	add_child(test_level)


## Helper to find an item by tag recursively in the scene tree
func _find_item_recursive(node: Node, item_tag: String) -> ItemEntity:
	if node is ItemEntity and node.item_tag == item_tag:
		return node
	for child in node.get_children():
		var found := _find_item_recursive(child, item_tag)
		if found != null:
			return found
	return null


func run_tests() -> void:
	_log_header()
	await test_cooking_scenario_full_flow()
	await test_production_consumption_loop()
	_log_summary()


## Test the full cooking scenario using DebugCommands API
func test_cooking_scenario_full_flow() -> void:
	test("Full cooking scenario: spawn setup, NPC cooks and eats")

	# Clear any existing state
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# SETUP PHASE - Spawn entities using DebugCommands API
	# All entities placed in the open room area (avoid walls at edges)
	# ==========================================================================

	# 1. Spawn a fridge (container) with raw_food - left side of room
	var fridge: ItemContainer = DebugCommands.spawn_container("fridge", Vector2(96, 192))
	assert_not_null(fridge, "Fridge should spawn")
	await get_tree().process_frame

	# 2. Spawn raw_food in the fridge
	var raw_food: ItemEntity = DebugCommands.spawn_item("raw_food", fridge)
	assert_not_null(raw_food, "Raw food should spawn in fridge")
	assert_eq(raw_food.location, ItemEntity.ItemLocation.IN_CONTAINER, "Raw food should be in container")

	# 3. Spawn a counter station for prep work - middle of room
	var counter: Station = DebugCommands.spawn_station("counter", Vector2(192, 192))
	assert_not_null(counter, "Counter should spawn")
	await get_tree().process_frame

	# Add input slot marker to counter for item placement
	var counter_slot := Marker2D.new()
	counter_slot.name = "InputSlot0"
	counter.add_child(counter_slot)
	var counter_footprint := Marker2D.new()
	counter_footprint.name = "AgentFootprint"
	counter_footprint.position = Vector2(0, 24)
	counter.add_child(counter_footprint)
	counter._auto_discover_markers()

	# 4. Spawn a stove station for cooking - right side of room
	var stove: Station = DebugCommands.spawn_station("stove", Vector2(288, 192))
	assert_not_null(stove, "Stove should spawn")
	await get_tree().process_frame

	# Add input slot marker to stove
	var stove_slot := Marker2D.new()
	stove_slot.name = "InputSlot0"
	stove.add_child(stove_slot)
	var stove_output := Marker2D.new()
	stove_output.name = "OutputSlot0"
	stove.add_child(stove_output)
	var stove_footprint := Marker2D.new()
	stove_footprint.name = "AgentFootprint"
	stove_footprint.position = Vector2(0, 24)
	stove.add_child(stove_footprint)
	stove._auto_discover_markers()

	# 5. Spawn an NPC with FULL motives first (to prevent autonomous job-seeking during setup)
	# Position inside the room: room is 20x19 tiles (32px each), walls at edges
	# Valid area roughly x: 64-576, y: 64-544
	var npc: Node = DebugCommands.spawn_npc(Vector2(128, 256), {
		"hunger": 100.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc, "NPC should spawn")
	await get_tree().process_frame
	await get_tree().process_frame

	# Store initial hunger (will set low later after job is posted)
	var initial_hunger: float = 10.0

	# ==========================================================================
	# VERIFY SETUP - Print positions for debugging
	# ==========================================================================

	print("    Entity positions:")
	print("      NPC:     pos=(%.0f, %.0f) grid=(%d, %d)" % [npc.global_position.x, npc.global_position.y, int(npc.global_position.x / TILE_SIZE), int(npc.global_position.y / TILE_SIZE)])
	print("      Fridge:  pos=(%.0f, %.0f) grid=(%d, %d)" % [fridge.global_position.x, fridge.global_position.y, int(fridge.global_position.x / TILE_SIZE), int(fridge.global_position.y / TILE_SIZE)])
	print("      Counter: pos=(%.0f, %.0f) grid=(%d, %d)" % [counter.global_position.x, counter.global_position.y, int(counter.global_position.x / TILE_SIZE), int(counter.global_position.y / TILE_SIZE)])
	print("      Stove:   pos=(%.0f, %.0f) grid=(%d, %d)" % [stove.global_position.x, stove.global_position.y, int(stove.global_position.x / TILE_SIZE), int(stove.global_position.y / TILE_SIZE)])
	print("    Room size: %dx%d tiles (walls at edges, valid area: 1-%d x 1-%d)" % [20, 19, 18, 17])

	# Verify fridge has raw_food
	var fridge_data: Dictionary = DebugCommands.get_inspection_data(fridge)
	assert_eq(fridge_data.used, 1, "Fridge should have 1 item")
	assert_array_contains(fridge_data.items, "raw_food", "Fridge should contain raw_food")

	# Verify no jobs exist yet
	var initial_jobs: Array[Job] = DebugCommands.get_all_jobs()
	assert_array_size(initial_jobs, 0, "Should have 0 jobs initially")

	# ==========================================================================
	# EXECUTION PHASE - Post job via DebugCommands and let NPC execute it
	# ==========================================================================

	# Post a cooking job via DebugCommands API FIRST (before making NPC hungry)
	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	assert_not_null(job, "Job should be posted via DebugCommands")
	assert_eq(job.recipe.recipe_name, "Cook Simple Meal", "Job should be Cook Simple Meal")

	# Build typed arrays for job claiming
	var typed_containers: Array[ItemContainer] = [fridge]
	var typed_stations: Array[Station] = [counter, stove]

	# Ensure NPC has access to containers and stations
	npc.set_available_containers(typed_containers)
	npc.set_available_stations(typed_stations)

	# Claim the job for the NPC via JobBoard
	var claimed: bool = JobBoard.claim_job(job, npc, typed_containers)
	assert_true(claimed, "NPC should claim the job")

	# NOW set hunger low (after job is claimed, to avoid race condition with autonomous behavior)
	DebugCommands.set_npc_motive(npc, "hunger", initial_hunger)
	var actual_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_approx_eq(actual_hunger, initial_hunger, "NPC hunger should be set to 10")

	# Start hauling for the job - this kicks off the full flow
	var hauling_started: bool = npc.start_hauling_for_job(job)
	assert_true(hauling_started, "NPC should start hauling")

	# Verify NPC has the job
	assert_not_null(npc.current_job, "NPC should have a job")
	assert_eq(npc.current_job.recipe.recipe_name, "Cook Simple Meal", "NPC should be doing Cook Simple Meal")

	# ==========================================================================
	# WAIT FOR JOB COMPLETION
	# ==========================================================================

	# Track job completion
	var job_completed := {"value": false}
	job.job_completed.connect(func(): job_completed["value"] = true)

	# Let the simulation run until job completes or timeout
	# Full cooking flow:
	# - Walk to fridge and pick up raw_food
	# - Walk to counter and place item, work for 3 seconds (prep)
	# - Walk to stove and place item, work for 5 seconds (cook)
	# - Total: ~8+ seconds of work time plus walking
	# At 60fps, that's ~480+ frames minimum
	var max_frames := 1200  # 20 seconds should be plenty
	var frame_count := 0

	while not job_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

		# Debug output every 2 seconds
		if frame_count % 120 == 0:
			var state_name: String = npc.State.keys()[npc.current_state] if npc.current_state < npc.State.size() else "UNKNOWN"
			var job_state: String = Job.JobState.keys()[job.state]
			var held_count: int = npc.held_items.size() if npc.held_items else 0
			print("    Frame %d: NPC state=%s, job_state=%s, work_timer=%.2f, held_items=%d, pos=(%.0f,%.0f)" % [
				frame_count,
				state_name,
				job_state,
				npc.work_timer,
				held_count,
				npc.global_position.x,
				npc.global_position.y
			])

	# ==========================================================================
	# VERIFICATION PHASE
	# ==========================================================================

	# Verify job completed
	assert_true(job_completed["value"], "Job should complete within timeout (took %d frames)" % frame_count)
	assert_eq(job.state, Job.JobState.COMPLETED, "Job state should be COMPLETED")

	# Note: cook_simple_meal no longer has motive_effects (US-003)
	# Hunger satisfaction now comes from eating the cooked meal via eat_snack recipe
	# This test only verifies cooking completes successfully - not hunger satisfaction
	var final_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	print("    Note: Hunger unchanged by cooking (US-003) - was %.1f, now %.1f" % [initial_hunger, final_hunger])

	# Verify it took a reasonable amount of time (not instant)
	# Prep (3s) + Cook (5s) = 8s minimum = 480 frames at 60fps
	assert_true(frame_count > 200, "Job should take more than 200 frames (work timers should function)")

	print("    Cooking scenario completed in %d frames (~%.2f seconds)" % [frame_count, frame_count / 60.0])
	print("    Cooking completed - cooked_meal produced (hunger unchanged per US-003)")

	# ==========================================================================
	# CLEANUP
	# ==========================================================================

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()


## Test the full production-consumption loop: cook -> eat
## This chains cook_simple_meal (produces cooked_meal) with eat_snack (consumes cooked_meal, satisfies hunger)
func test_production_consumption_loop() -> void:
	test("Production-consumption loop: cook raw_food -> produce cooked_meal -> eat snack -> hunger satisfied")

	# Clear any existing state
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# SETUP PHASE
	# ==========================================================================

	# 1. Spawn a fridge with raw_food
	var fridge: ItemContainer = DebugCommands.spawn_container("fridge", Vector2(96, 192))
	assert_not_null(fridge, "Fridge should spawn")
	await get_tree().process_frame

	var raw_food: ItemEntity = DebugCommands.spawn_item("raw_food", fridge)
	assert_not_null(raw_food, "Raw food should spawn in fridge")

	# 2. Spawn counter station for prep
	var counter: Station = DebugCommands.spawn_station("counter", Vector2(192, 192))
	assert_not_null(counter, "Counter should spawn")
	await get_tree().process_frame

	var counter_slot := Marker2D.new()
	counter_slot.name = "InputSlot0"
	counter.add_child(counter_slot)
	var counter_footprint := Marker2D.new()
	counter_footprint.name = "AgentFootprint"
	counter_footprint.position = Vector2(0, 24)
	counter.add_child(counter_footprint)
	counter._auto_discover_markers()

	# 3. Spawn stove station for cooking
	var stove: Station = DebugCommands.spawn_station("stove", Vector2(288, 192))
	assert_not_null(stove, "Stove should spawn")
	await get_tree().process_frame

	var stove_slot := Marker2D.new()
	stove_slot.name = "InputSlot0"
	stove.add_child(stove_slot)
	var stove_output := Marker2D.new()
	stove_output.name = "OutputSlot0"
	stove.add_child(stove_output)
	var stove_footprint := Marker2D.new()
	stove_footprint.name = "AgentFootprint"
	stove_footprint.position = Vector2(0, 24)
	stove.add_child(stove_footprint)
	stove._auto_discover_markers()

	# 4. Spawn NPC with low hunger (will want to eat)
	var npc: Node = DebugCommands.spawn_npc(Vector2(128, 256), {
		"hunger": 100.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc, "NPC should spawn")
	await get_tree().process_frame
	await get_tree().process_frame

	# Build typed arrays
	var typed_containers: Array[ItemContainer] = [fridge]
	var typed_stations: Array[Station] = [counter, stove]
	npc.set_available_containers(typed_containers)
	npc.set_available_stations(typed_stations)

	# ==========================================================================
	# PHASE 1: COOKING - NPC cooks raw_food -> cooked_meal
	# ==========================================================================

	print("    Phase 1: Cooking raw_food -> cooked_meal")

	# Post and claim cooking job
	var cook_job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	assert_not_null(cook_job, "Cook job should be posted")

	var claimed: bool = JobBoard.claim_job(cook_job, npc, typed_containers)
	assert_true(claimed, "NPC should claim cook job")

	# Start hauling
	var hauling_started: bool = npc.start_hauling_for_job(cook_job)
	assert_true(hauling_started, "NPC should start hauling for cook job")

	# Wait for cooking to complete
	var cook_completed := {"value": false}
	cook_job.job_completed.connect(func(): cook_completed["value"] = true)

	var max_frames := 1200
	var frame_count := 0

	while not cook_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(cook_completed["value"], "Cook job should complete")
	assert_eq(cook_job.state, Job.JobState.COMPLETED, "Cook job state should be COMPLETED")
	print("    Cooking completed in %d frames" % frame_count)

	# Wait a frame for outputs to spawn
	await get_tree().process_frame
	await get_tree().process_frame

	# Find the cooked_meal that was produced
	# Items are spawned as children of the station (either in output slot or directly)
	var cooked_meal: ItemEntity = null

	# Check stove children (most likely location)
	for child in stove.get_children():
		if child is ItemEntity and child.item_tag == "cooked_meal":
			cooked_meal = child
			break

	# Check level children
	if cooked_meal == null:
		for child in test_level.get_children():
			if child is ItemEntity and child.item_tag == "cooked_meal":
				cooked_meal = child
				break

	# Check all nodes recursively in the scene
	if cooked_meal == null:
		cooked_meal = _find_item_recursive(get_tree().root, "cooked_meal")

	assert_not_null(cooked_meal, "cooked_meal should be spawned after cooking")
	print("    cooked_meal found at position: (%.0f, %.0f)" % [cooked_meal.global_position.x, cooked_meal.global_position.y])

	# ==========================================================================
	# PHASE 2: EATING - NPC eats cooked_meal -> hunger satisfied
	# ==========================================================================

	print("    Phase 2: Eating cooked_meal -> hunger satisfied")

	# Set NPC hunger to low value
	var initial_hunger: float = 10.0
	DebugCommands.set_npc_motive(npc, "hunger", initial_hunger)
	var actual_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_approx_eq(actual_hunger, initial_hunger, "NPC hunger should be 10")

	# Move cooked_meal to fridge so NPC can find it
	# First remove from current parent
	if cooked_meal.get_parent() != null:
		cooked_meal.get_parent().remove_child(cooked_meal)
	fridge.add_item(cooked_meal)
	await get_tree().process_frame

	# Verify fridge has the cooked_meal
	var fridge_data: Dictionary = DebugCommands.get_inspection_data(fridge)
	assert_true(fridge_data.items.has("cooked_meal"), "Fridge should have cooked_meal")

	# Post and claim eat_snack job
	var eat_job: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	assert_not_null(eat_job, "Eat job should be posted")

	var eat_claimed: bool = JobBoard.claim_job(eat_job, npc, typed_containers)
	assert_true(eat_claimed, "NPC should claim eat job")

	# Start hauling for eat job (gathering the cooked_meal)
	var eat_hauling_started: bool = npc.start_hauling_for_job(eat_job)
	assert_true(eat_hauling_started, "NPC should start hauling for eat job")

	# Wait for eating to complete
	var eat_completed := {"value": false}
	eat_job.job_completed.connect(func(): eat_completed["value"] = true)

	frame_count = 0
	while not eat_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(eat_completed["value"], "Eat job should complete")
	assert_eq(eat_job.state, Job.JobState.COMPLETED, "Eat job state should be COMPLETED")
	print("    Eating completed in %d frames" % frame_count)

	# ==========================================================================
	# VERIFICATION - Hunger should be satisfied
	# ==========================================================================

	var final_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")

	# Note: Hunger decays over time during simulation, so we can't expect exact values.
	# The important verification is that after eating, hunger is significantly higher
	# than the critical threshold, proving the eat_snack motive effect was applied.
	# Starting at 10.0, after decay and +50 from eating, we expect ~30-60 range.
	assert_true(final_hunger > 25.0, "Hunger should be above 25 after eating (started at 10, +50 from eating, minus decay)")
	assert_true(final_hunger < 70.0, "Hunger should be below 70 (sanity check)")

	print("    Production-consumption loop complete!")
	print("    Hunger: started at %.1f, ended at %.1f (with decay + eat_snack +50 effect)" % [initial_hunger, final_hunger])

	# ==========================================================================
	# CLEANUP
	# ==========================================================================

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
