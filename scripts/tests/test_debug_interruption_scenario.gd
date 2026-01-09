extends "res://scripts/tests/test_runner.gd"
## END-TO-END TEST: Job interruption scenario (US-021)
##
## This is a HIGH-LEVEL integration test that verifies job interruption and
## resumption using the DebugCommands API - the same API the Debug UI uses.
##
## What it tests:
## - Spawning entities via DebugCommands (stations, containers, items, NPCs)
## - Posting jobs and letting NPC autonomously start cooking
## - Interrupting the job via DebugCommands.interrupt_job()
## - Verifying items remain at the station after interruption
## - Spawning a second NPC who claims and completes the interrupted job
## - Uses real Level with pathfinding, real recipe (cook_simple_meal.tres)
##
## For low-level unit tests of interruption mechanics,
## see test_interruption.gd instead.

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
	_test_name = "Debug Interruption Scenario"
	_setup_test_level()
	super._ready()


func _setup_test_level() -> void:
	# Create a simple level with just an open room
	test_level = Node2D.new()
	test_level.set_script(LevelScript)
	test_level.world_map = SIMPLE_ROOM_MAP
	test_level.auto_spawn_npcs = false
	add_child(test_level)


func run_tests() -> void:
	_log_header()
	await test_interruption_and_resume_scenario()
	_log_summary()


## Test the full interruption scenario using DebugCommands API
func test_interruption_and_resume_scenario() -> void:
	test("Full interruption scenario: NPC1 starts cooking, gets interrupted, NPC2 resumes and completes")

	# Clear any existing state
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# SETUP PHASE - Spawn entities using DebugCommands API
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

	# 5. Spawn first NPC with full motives (will set hunger low after job claim)
	var npc1: Node = DebugCommands.spawn_npc(Vector2(128, 256), {
		"hunger": 100.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc1, "NPC1 should spawn")
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# VERIFY SETUP
	# ==========================================================================

	print("    Entity positions:")
	print("      NPC1:    pos=(%.0f, %.0f)" % [npc1.global_position.x, npc1.global_position.y])
	print("      Fridge:  pos=(%.0f, %.0f)" % [fridge.global_position.x, fridge.global_position.y])
	print("      Counter: pos=(%.0f, %.0f)" % [counter.global_position.x, counter.global_position.y])
	print("      Stove:   pos=(%.0f, %.0f)" % [stove.global_position.x, stove.global_position.y])

	# Verify fridge has raw_food
	var fridge_data: Dictionary = DebugCommands.get_inspection_data(fridge)
	assert_eq(fridge_data.used, 1, "Fridge should have 1 item")

	# ==========================================================================
	# PHASE 1: Post job and have NPC1 start cooking
	# ==========================================================================

	# Post a cooking job via DebugCommands API
	var job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	assert_not_null(job, "Job should be posted via DebugCommands")

	# Build typed arrays for job claiming
	var typed_containers: Array[ItemContainer] = [fridge]
	var typed_stations: Array[Station] = [counter, stove]

	# Ensure NPC1 has access to containers and stations
	npc1.set_available_containers(typed_containers)
	npc1.set_available_stations(typed_stations)

	# Claim the job for NPC1 via JobBoard
	var claimed: bool = JobBoard.claim_job(job, npc1, typed_containers)
	assert_true(claimed, "NPC1 should claim the job")

	# Set hunger low after job is claimed to avoid race condition
	DebugCommands.set_npc_motive(npc1, "hunger", 10.0)

	# Start hauling for the job
	var hauling_started: bool = npc1.start_hauling_for_job(job)
	assert_true(hauling_started, "NPC1 should start hauling")

	# Verify NPC1 has the job
	assert_not_null(npc1.current_job, "NPC1 should have a job")

	# ==========================================================================
	# PHASE 2: Wait for NPC1 to place item at station, then interrupt
	# We want to interrupt AFTER NPC1 has placed the item at a station
	# (so items remain at station after interrupt, per acceptance criteria)
	# ==========================================================================

	# Wait until item is placed at the counter station (prep work started)
	var max_wait_frames := 600  # 10 seconds
	var frame_count := 0
	var ready_to_interrupt := false

	while not ready_to_interrupt and frame_count < max_wait_frames:
		await get_tree().physics_frame
		frame_count += 1

		# Check if item is at counter (prep started) - this is the key condition
		var item_at_counter: bool = counter.get_input_item(0) != null

		# Ready to interrupt once item is placed at counter
		if item_at_counter:
			ready_to_interrupt = true

		# Debug output every 2 seconds
		if frame_count % 120 == 0:
			var current_fridge_data: Dictionary = DebugCommands.get_inspection_data(fridge)
			var fridge_empty: bool = current_fridge_data.used == 0
			var state_name: String = npc1.State.keys()[npc1.current_state] if npc1.current_state < npc1.State.size() else "UNKNOWN"
			print("    Frame %d: NPC1 state=%s, fridge_empty=%s, item_at_counter=%s, job_step=%d" % [
				frame_count,
				state_name,
				fridge_empty,
				item_at_counter,
				job.current_step_index
			])

	assert_true(ready_to_interrupt, "NPC1 should have placed item at counter (waited %d frames)" % frame_count)
	print("    NPC1 placed item at counter after %d frames, ready to interrupt" % frame_count)

	# Record the current step index before interruption
	var step_before_interrupt: int = job.current_step_index
	print("    Job step before interrupt: %d" % step_before_interrupt)

	# Check what items are where before interrupt
	var item_at_counter_before: ItemEntity = counter.get_input_item(0)
	var item_at_stove_before: ItemEntity = stove.get_input_item(0)
	var npc1_held_items_before: int = npc1.held_items.size()

	print("    Before interrupt: counter has item=%s, stove has item=%s, NPC1 holding=%d items" % [
		item_at_counter_before != null,
		item_at_stove_before != null,
		npc1_held_items_before
	])

	# ==========================================================================
	# PHASE 3: Interrupt the job via DebugCommands
	# ==========================================================================

	var interrupted: bool = DebugCommands.interrupt_job(job)
	assert_true(interrupted, "Job should be interrupted successfully")
	assert_eq(job.state, Job.JobState.INTERRUPTED, "Job state should be INTERRUPTED")

	# Wait a frame for interrupt to process
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# PHASE 4: Verify items remain at station after interruption
	# ==========================================================================

	# Check where items ended up after interrupt
	var item_at_counter_after: ItemEntity = counter.get_input_item(0)
	var item_at_stove_after: ItemEntity = stove.get_input_item(0)

	# Items should either be at a station or on the ground (if NPC was holding them)
	# They should NOT disappear
	print("    After interrupt: counter has item=%s, stove has item=%s" % [
		item_at_counter_after != null,
		item_at_stove_after != null
	])

	# If item was at counter before, it should still be there
	if item_at_counter_before != null:
		assert_not_null(item_at_counter_after, "Item should remain at counter after interrupt")
		print("    Item remained at counter: tag=%s" % item_at_counter_after.item_tag)

	# Job step index should be preserved
	assert_eq(job.current_step_index, step_before_interrupt, "Job step index should be preserved after interrupt")

	# NPC1 should no longer have the job
	# Note: NPC may still have current_job reference briefly, but job.claimed_by should be null
	assert_null(job.claimed_by, "Job should have no claimant after interrupt")

	# ==========================================================================
	# PHASE 5: Spawn second NPC and have them resume the job
	# ==========================================================================

	print("    Spawning NPC2 to resume the interrupted job...")

	var npc2: Node = DebugCommands.spawn_npc(Vector2(160, 320), {
		"hunger": 100.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc2, "NPC2 should spawn")
	await get_tree().process_frame
	await get_tree().process_frame

	print("      NPC2:    pos=(%.0f, %.0f)" % [npc2.global_position.x, npc2.global_position.y])

	# Give NPC2 access to the same containers and stations
	npc2.set_available_containers(typed_containers)
	npc2.set_available_stations(typed_stations)

	# NPC2 claims the interrupted job
	var claimed2: bool = JobBoard.claim_job(job, npc2)
	assert_true(claimed2, "NPC2 should claim the interrupted job")
	assert_eq(job.claimed_by, npc2, "Job should be claimed by NPC2")

	# Set hunger low for NPC2
	DebugCommands.set_npc_motive(npc2, "hunger", 10.0)
	var npc2_initial_hunger: float = DebugCommands.get_npc_motive(npc2, "hunger")

	# Start the job for NPC2
	# If there's an item at a station, NPC2 should continue from there
	# Otherwise NPC2 needs to gather remaining items
	var hauling_started2: bool = npc2.start_hauling_for_job(job)
	assert_true(hauling_started2, "NPC2 should start working on job")

	print("    NPC2 claimed job at step %d, starting work..." % job.current_step_index)

	# ==========================================================================
	# PHASE 6: Wait for NPC2 to complete the job
	# ==========================================================================

	var job_completed := {"value": false}
	job.job_completed.connect(func(): job_completed["value"] = true)

	var max_frames := 1200  # 20 seconds
	frame_count = 0

	while not job_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

		# Debug output every 2 seconds
		if frame_count % 120 == 0:
			var state_name: String = npc2.State.keys()[npc2.current_state] if npc2.current_state < npc2.State.size() else "UNKNOWN"
			var job_state: String = Job.JobState.keys()[job.state]
			print("    Frame %d: NPC2 state=%s, job_state=%s, job_step=%d" % [
				frame_count,
				state_name,
				job_state,
				job.current_step_index
			])

	# ==========================================================================
	# VERIFICATION PHASE
	# ==========================================================================

	# Verify job completed
	assert_true(job_completed["value"], "Job should complete within timeout (took %d frames)" % frame_count)
	assert_eq(job.state, Job.JobState.COMPLETED, "Job state should be COMPLETED")

	# Verify NPC2's hunger increased (recipe gives +50 hunger)
	var npc2_final_hunger: float = DebugCommands.get_npc_motive(npc2, "hunger")
	assert_true(npc2_final_hunger > npc2_initial_hunger, "NPC2 hunger should increase after eating (was %.1f, now %.1f)" % [npc2_initial_hunger, npc2_final_hunger])

	print("    Interruption scenario completed successfully!")
	print("    NPC1 was interrupted, NPC2 resumed and completed the job in %d frames" % frame_count)
	print("    NPC2 hunger went from %.1f to %.1f" % [npc2_initial_hunger, npc2_final_hunger])

	# ==========================================================================
	# CLEANUP
	# ==========================================================================

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
