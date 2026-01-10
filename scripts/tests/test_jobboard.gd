extends "res://scripts/tests/test_runner.gd"
## Tests for JobBoard singleton (US-007)

# Preload the JobBoard script for creating test instances
const JobBoardScript = preload("res://scripts/job_board.gd")

var test_area: Node2D

func _ready() -> void:
	_test_name = "JobBoard"
	test_area = $TestArea
	super._ready()

func run_tests() -> void:
	_log_header()

	test_job_board_creation()
	test_post_job()
	test_get_available_jobs()
	test_get_jobs_for_motive()
	test_claim_job()
	test_release_job()
	test_signals()
	test_job_by_id()
	test_jobs_by_state()
	test_jobs_for_agent()
	test_job_cleanup()
	test_priority_jobs()
	test_helper_methods()
	test_can_start_job_valid()
	test_can_start_job_missing_items()
	test_can_start_job_missing_tools()
	test_can_start_job_missing_stations()
	test_can_start_job_reserved_items()
	test_can_start_job_reserved_stations()
	test_can_start_job_multiple_requirements()
	await test_can_start_finds_ground_items()
	await test_can_start_finds_station_output()
	await test_can_start_combines_sources()
	await test_can_start_excludes_reserved_from_all_sources()
	await test_can_start_partial_sources()
	test_can_start_container_items_unchanged()
	test_interrupt_job()
	test_interrupt_job_signal()
	test_interrupt_job_preserves_step_index()
	test_interrupted_job_claimable()
	test_interrupted_job_reservations_released()
	test_resume_interrupted_job()
	test_complete_job_basic()
	test_complete_job_motive_effects()
	test_complete_job_spawns_outputs()
	test_spawn_outputs_fallback_to_ground()
	test_spawn_outputs_sets_prepped_state()
	test_complete_job_consumes_inputs()
	test_complete_job_preserves_tools()
	test_complete_job_with_transforms()
	test_complete_job_invalid_states()

	_log_summary()

func _create_job_board() -> Node:
	var board = JobBoardScript.new()
	test_area.add_child(board)
	return board

func _cleanup_job_board(board: Node) -> void:
	board.clear_all_jobs()
	board.queue_free()

func _create_test_recipe(recipe_name: String = "Test Recipe", motive: String = "", motive_value: float = 0.0) -> Recipe:
	var recipe := Recipe.new()
	recipe.recipe_name = recipe_name
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)
	if not motive.is_empty():
		recipe.set_motive_effect(motive, motive_value)
	return recipe

func test_job_board_creation() -> void:
	test("JobBoard creation")
	var board = _create_job_board()
	assert_not_null(board, "JobBoard should be created")
	assert_eq(board.get_job_count(), 0, "New JobBoard should have no jobs")
	assert_false(board.has_available_jobs(), "New JobBoard should have no available jobs")
	_cleanup_job_board(board)

func test_post_job() -> void:
	test("Post job")
	var board = _create_job_board()
	var recipe := _create_test_recipe("Cooking")
	var job: Job = board.post_job(recipe, 5)
	assert_not_null(job, "Posted job should exist")
	assert_eq(job.recipe, recipe, "Job should have the recipe")
	assert_eq(job.priority, 5, "Job should have the priority")
	assert_eq(job.state, Job.JobState.POSTED, "Job should be in POSTED state")
	assert_eq(board.get_job_count(), 1, "Board should have 1 job")
	var job2: Job = board.post_job(recipe, 3)
	assert_eq(board.get_job_count(), 2, "Board should have 2 jobs")
	assert_neq(job.job_id, job2.job_id, "Jobs should have unique IDs")
	_cleanup_job_board(board)

func test_get_available_jobs() -> void:
	test("Get available jobs")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)
	var job1: Job = board.post_job(recipe, 1)
	var job2: Job = board.post_job(recipe, 2)
	var job3: Job = board.post_job(recipe, 3)
	var available: Array[Job] = board.get_available_jobs()
	assert_array_size(available, 3, "All 3 jobs should be available")
	board.claim_job(job2, agent)
	available = board.get_available_jobs()
	assert_array_size(available, 2, "2 jobs should be available after claim")
	assert_array_not_contains(available, job2, "Claimed job should not be available")
	job2.start()
	available = board.get_available_jobs()
	assert_array_size(available, 2, "Still 2 jobs available")
	job2.complete()
	available = board.get_available_jobs()
	assert_array_size(available, 2, "Still 2 jobs available (completed not claimable)")
	assert_not_null(job1, "job1 exists")
	assert_not_null(job3, "job3 exists")
	agent.queue_free()
	_cleanup_job_board(board)

func test_get_jobs_for_motive() -> void:
	test("Get jobs for motive")
	var board = _create_job_board()
	var hunger_recipe := _create_test_recipe("Eat", "hunger", 50.0)
	var bladder_recipe := _create_test_recipe("Toilet", "bladder", 80.0)
	var fun_recipe := _create_test_recipe("Play", "fun", 30.0)
	var no_motive_recipe := _create_test_recipe("Work")
	board.post_job(hunger_recipe, 1)
	board.post_job(hunger_recipe, 2)
	board.post_job(bladder_recipe, 1)
	board.post_job(fun_recipe, 1)
	board.post_job(no_motive_recipe, 1)
	var hunger_jobs: Array[Job] = board.get_jobs_for_motive("hunger")
	assert_array_size(hunger_jobs, 2, "Should have 2 hunger jobs")
	var bladder_jobs: Array[Job] = board.get_jobs_for_motive("bladder")
	assert_array_size(bladder_jobs, 1, "Should have 1 bladder job")
	var fun_jobs: Array[Job] = board.get_jobs_for_motive("fun")
	assert_array_size(fun_jobs, 1, "Should have 1 fun job")
	var energy_jobs: Array[Job] = board.get_jobs_for_motive("energy")
	assert_array_size(energy_jobs, 0, "Should have 0 energy jobs")
	_cleanup_job_board(board)

func test_claim_job() -> void:
	test("Claim job")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent1 := Node.new()
	var agent2 := Node.new()
	test_area.add_child(agent1)
	test_area.add_child(agent2)
	var job: Job = board.post_job(recipe, 1)
	var claimed: bool = board.claim_job(job, agent1)
	assert_true(claimed, "Claim should succeed")
	assert_eq(job.claimed_by, agent1, "Job should be claimed by agent1")
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED")
	var claimed2: bool = board.claim_job(job, agent2)
	assert_false(claimed2, "Agent2 claim should fail")
	assert_eq(job.claimed_by, agent1, "Job should still be claimed by agent1")
	var claimed_null_job: bool = board.claim_job(null, agent1)
	assert_false(claimed_null_job, "Claiming null job should fail")
	var claimed_null_agent: bool = board.claim_job(job, null)
	assert_false(claimed_null_agent, "Claiming with null agent should fail")
	var external_job := Job.new(recipe, 1)
	var claimed_external: bool = board.claim_job(external_job, agent1)
	assert_false(claimed_external, "Claiming job not in board should fail")
	agent1.queue_free()
	agent2.queue_free()
	_cleanup_job_board(board)

func test_release_job() -> void:
	test("Release job")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)
	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED")
	board.release_job(job)
	assert_eq(job.state, Job.JobState.POSTED, "Job should return to POSTED")
	assert_null(job.claimed_by, "Job should be unclaimed")
	var available: Array[Job] = board.get_available_jobs()
	assert_array_contains(available, job, "Released job should be available")
	var agent2 := Node.new()
	test_area.add_child(agent2)
	var claimed: bool = board.claim_job(job, agent2)
	assert_true(claimed, "Another agent should be able to claim released job")
	agent.queue_free()
	agent2.queue_free()
	_cleanup_job_board(board)

func test_signals() -> void:
	test("JobBoard signals")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)
	# Use dictionary to track signals (passed by reference to lambdas)
	var signals_received := {"posted": false, "claimed": false, "released": false, "completed": false}
	board.job_posted.connect(func(_j): signals_received["posted"] = true)
	board.job_claimed.connect(func(_j, _a): signals_received["claimed"] = true)
	board.job_released.connect(func(_j): signals_received["released"] = true)
	board.job_completed.connect(func(_j): signals_received["completed"] = true)
	var job: Job = board.post_job(recipe, 1)
	assert_true(signals_received["posted"], "job_posted signal should be emitted")
	board.claim_job(job, agent)
	assert_true(signals_received["claimed"], "job_claimed signal should be emitted")
	board.release_job(job)
	assert_true(signals_received["released"], "job_released signal should be emitted")
	board.claim_job(job, agent)
	job.start()
	job.complete()
	await get_tree().process_frame
	assert_true(signals_received["completed"], "job_completed signal should be emitted")
	agent.queue_free()
	_cleanup_job_board(board)

func test_job_by_id() -> void:
	test("Get job by ID")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var job1: Job = board.post_job(recipe, 1)
	var job2: Job = board.post_job(recipe, 2)
	var found: Job = board.get_job_by_id(job1.job_id)
	assert_eq(found, job1, "Should find job1 by ID")
	var found2: Job = board.get_job_by_id(job2.job_id)
	assert_eq(found2, job2, "Should find job2 by ID")
	var not_found: Job = board.get_job_by_id("invalid_id")
	assert_null(not_found, "Should return null for invalid ID")
	_cleanup_job_board(board)

func test_jobs_by_state() -> void:
	test("Get jobs by state")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)
	var job1: Job = board.post_job(recipe, 1)
	var job2: Job = board.post_job(recipe, 2)
	var job3: Job = board.post_job(recipe, 3)
	var job4: Job = board.post_job(recipe, 4)
	board.claim_job(job2, agent)
	board.claim_job(job3, agent)
	job3.release()
	board.claim_job(job3, agent)
	job3.start()
	board.claim_job(job4, agent)
	job4.release()
	board.claim_job(job4, agent)
	job4.start()
	job4.complete()
	var posted: Array[Job] = board.get_jobs_by_state(Job.JobState.POSTED)
	assert_array_size(posted, 1, "Should have 1 POSTED job")
	var claimed: Array[Job] = board.get_jobs_by_state(Job.JobState.CLAIMED)
	assert_array_size(claimed, 1, "Should have 1 CLAIMED job")
	var in_progress: Array[Job] = board.get_jobs_by_state(Job.JobState.IN_PROGRESS)
	assert_array_size(in_progress, 1, "Should have 1 IN_PROGRESS job")
	var completed: Array[Job] = board.get_jobs_by_state(Job.JobState.COMPLETED)
	assert_array_size(completed, 1, "Should have 1 COMPLETED job")
	var active: Array[Job] = board.get_active_jobs()
	assert_array_size(active, 2, "Should have 2 active jobs (CLAIMED + IN_PROGRESS)")
	assert_not_null(job1, "job1 exists")
	agent.queue_free()
	_cleanup_job_board(board)

func test_jobs_for_agent() -> void:
	test("Get jobs for agent")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent1 := Node.new()
	var agent2 := Node.new()
	test_area.add_child(agent1)
	test_area.add_child(agent2)
	var job1: Job = board.post_job(recipe, 1)
	var job2: Job = board.post_job(recipe, 2)
	var job3: Job = board.post_job(recipe, 3)
	board.claim_job(job1, agent1)
	job1.release()
	board.claim_job(job1, agent1)
	board.claim_job(job2, agent1)
	job2.release()
	board.claim_job(job2, agent1)
	board.claim_job(job3, agent2)
	var agent1_jobs: Array[Job] = board.get_jobs_for_agent(agent1)
	assert_array_size(agent1_jobs, 2, "Agent1 should have 2 jobs")
	var agent2_jobs: Array[Job] = board.get_jobs_for_agent(agent2)
	assert_array_size(agent2_jobs, 1, "Agent2 should have 1 job")
	var no_agent_jobs: Array[Job] = board.get_jobs_for_agent(Node.new())
	assert_array_size(no_agent_jobs, 0, "Unknown agent should have 0 jobs")
	agent1.queue_free()
	agent2.queue_free()
	_cleanup_job_board(board)

func test_job_cleanup() -> void:
	test("Job cleanup")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)
	var job1: Job = board.post_job(recipe, 1)
	var job2: Job = board.post_job(recipe, 2)
	var job3: Job = board.post_job(recipe, 3)
	var job4: Job = board.post_job(recipe, 4)
	board.claim_job(job2, agent)
	job2.start()
	job2.complete()
	board.claim_job(job3, agent)
	job3.release()
	board.claim_job(job3, agent)
	job3.start()
	job3.fail("Test failure")
	board.claim_job(job4, agent)
	job4.release()
	board.claim_job(job4, agent)
	assert_eq(board.get_job_count(), 4, "Should have 4 jobs before cleanup")
	var removed: int = board.cleanup_finished_jobs()
	assert_eq(removed, 2, "Should remove 2 finished jobs")
	assert_eq(board.get_job_count(), 2, "Should have 2 jobs after cleanup")
	assert_true(board.jobs.has(job1), "POSTED job should remain")
	assert_true(board.jobs.has(job4), "CLAIMED job should remain")
	assert_false(board.jobs.has(job2), "COMPLETED job should be removed")
	assert_false(board.jobs.has(job3), "FAILED job should be removed")
	var removed_single: bool = board.remove_job(job1)
	assert_true(removed_single, "Should successfully remove job")
	assert_eq(board.get_job_count(), 1, "Should have 1 job after removal")
	var removed_invalid: bool = board.remove_job(job1)
	assert_false(removed_invalid, "Should fail to remove already-removed job")
	board.clear_all_jobs()
	assert_eq(board.get_job_count(), 0, "Should have 0 jobs after clear")
	agent.queue_free()
	_cleanup_job_board(board)

func test_priority_jobs() -> void:
	test("Priority job selection")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)
	var hunger_recipe := _create_test_recipe("Eat", "hunger", 50.0)
	var fun_recipe := _create_test_recipe("Play", "fun", 30.0)
	var low_hunger: Job = board.post_job(hunger_recipe, 1)
	var high_hunger: Job = board.post_job(hunger_recipe, 10)
	var medium_fun: Job = board.post_job(fun_recipe, 5)
	var highest: Job = board.get_highest_priority_job()
	assert_eq(highest, high_hunger, "Should return highest priority job")
	var highest_hunger: Job = board.get_highest_priority_job_for_motive("hunger")
	assert_eq(highest_hunger, high_hunger, "Should return highest priority hunger job")
	var highest_fun: Job = board.get_highest_priority_job_for_motive("fun")
	assert_eq(highest_fun, medium_fun, "Should return only fun job")
	var highest_energy: Job = board.get_highest_priority_job_for_motive("energy")
	assert_null(highest_energy, "Should return null for no matching motive")
	board.claim_job(high_hunger, agent)
	highest = board.get_highest_priority_job()
	assert_eq(highest, medium_fun, "Should return next highest after claim")
	assert_not_null(low_hunger, "low_hunger exists")
	agent.queue_free()
	_cleanup_job_board(board)

func test_helper_methods() -> void:
	test("Helper methods")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)
	var hunger_recipe := _create_test_recipe("Eat", "hunger", 50.0)
	var plain_recipe := _create_test_recipe("Work")
	assert_false(board.has_available_jobs(), "Empty board has no available jobs")
	board.post_job(plain_recipe, 1)
	assert_true(board.has_available_jobs(), "Board with job has available jobs")
	assert_false(board.has_available_jobs_for_motive("hunger"), "No hunger jobs yet")
	board.post_job(hunger_recipe, 1)
	assert_true(board.has_available_jobs_for_motive("hunger"), "Now has hunger jobs")
	assert_eq(board.get_job_count_by_state(Job.JobState.POSTED), 2, "Should have 2 POSTED")
	assert_eq(board.get_job_count_by_state(Job.JobState.CLAIMED), 0, "Should have 0 CLAIMED")
	var available_hunger: Array[Job] = board.get_available_jobs_for_motive("hunger")
	assert_array_size(available_hunger, 1, "Should have 1 available hunger job")
	agent.queue_free()
	_cleanup_job_board(board)


# ============================================================================
# can_start_job() tests
# ============================================================================

func _create_container(container_name: String = "TestContainer") -> ItemContainer:
	var container := ItemContainer.new()
	container.container_name = container_name
	container.capacity = 10
	test_area.add_child(container)
	return container

func _create_item(tag: String) -> ItemEntity:
	var item := ItemEntity.new()
	item.item_tag = tag
	return item

func _create_station(tag: String) -> Station:
	var station := Station.new()
	station.station_tag = tag
	test_area.add_child(station)
	return station

func _create_recipe_with_inputs(recipe_name: String, inputs: Array[Dictionary], tools: Array[String], station_tags: Array[String]) -> Recipe:
	var recipe := Recipe.new()
	recipe.recipe_name = recipe_name

	for input in inputs:
		recipe.add_input(input.get("tag", ""), input.get("quantity", 1), input.get("consumed", true))

	for tool_tag in tools:
		recipe.add_tool(tool_tag)

	for station_tag in station_tags:
		var step := RecipeStep.new()
		step.station_tag = station_tag
		step.action = "work"
		step.duration = 2.0
		recipe.add_step(step)

	return recipe

func test_can_start_job_valid() -> void:
	test("can_start_job with valid requirements")
	var board = _create_job_board()

	# Create recipe requiring 1 raw_food and a counter station
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		[],
		["counter"]
	)

	# Create container with the required item
	var container := _create_container()
	var item := _create_item("raw_food")
	container.add_item(item)

	# Create the required station
	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_true(result.can_start, "Job should be startable with all requirements met")
	assert_eq(result.reason, "", "Reason should be empty when can start")
	assert_array_size(result.missing_items, 0, "No missing items")
	assert_array_size(result.missing_tools, 0, "No missing tools")
	assert_array_size(result.missing_stations, 0, "No missing stations")

	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_missing_items() -> void:
	test("can_start_job with missing items")
	var board = _create_job_board()

	# Create recipe requiring 2 raw_food
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 2}],
		[],
		["counter"]
	)

	# Create container with only 1 item (need 2)
	var container := _create_container()
	var item := _create_item("raw_food")
	container.add_item(item)

	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_false(result.can_start, "Job should NOT be startable with insufficient items")
	assert_array_size(result.missing_items, 1, "Should have 1 missing item entry")
	assert_eq(result.missing_items[0].item_tag, "raw_food", "Missing item should be raw_food")
	assert_eq(result.missing_items[0].quantity_needed, 2, "Should need 2")
	assert_eq(result.missing_items[0].quantity_found, 1, "Should have found 1")
	assert_true(result.reason.contains("Missing items"), "Reason should mention missing items")

	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_missing_tools() -> void:
	test("can_start_job with missing tools")
	var board = _create_job_board()

	# Create recipe requiring a knife tool
	var recipe := _create_recipe_with_inputs("Cutting",
		[],
		["knife"],
		["counter"]
	)

	# Create empty container (no knife)
	var container := _create_container()
	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_false(result.can_start, "Job should NOT be startable without required tool")
	assert_array_size(result.missing_tools, 1, "Should have 1 missing tool")
	assert_eq(result.missing_tools[0], "knife", "Missing tool should be knife")
	assert_true(result.reason.contains("Missing tools"), "Reason should mention missing tools")

	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_missing_stations() -> void:
	test("can_start_job with missing stations")
	var board = _create_job_board()

	# Create recipe requiring a stove station
	var recipe := _create_recipe_with_inputs("Cooking",
		[],
		[],
		["stove"]
	)

	var container := _create_container()
	# Create wrong station type
	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_false(result.can_start, "Job should NOT be startable without required station")
	assert_array_size(result.missing_stations, 1, "Should have 1 missing station")
	assert_eq(result.missing_stations[0], "stove", "Missing station should be stove")
	assert_true(result.reason.contains("Unavailable stations"), "Reason should mention unavailable stations")

	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_reserved_items() -> void:
	test("can_start_job with reserved items")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)

	# Create recipe requiring 1 raw_food
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		[],
		["counter"]
	)

	# Create container with reserved item
	var container := _create_container()
	var item := _create_item("raw_food")
	container.add_item(item)
	item.reserve_item(agent)  # Reserve the item

	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_false(result.can_start, "Job should NOT be startable with reserved items")
	assert_array_size(result.missing_items, 1, "Should show item as missing (reserved)")
	assert_eq(result.missing_items[0].quantity_found, 0, "Should find 0 available items")

	agent.queue_free()
	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_reserved_stations() -> void:
	test("can_start_job with reserved stations")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)

	# Create recipe requiring counter station
	var recipe := _create_recipe_with_inputs("Working",
		[],
		[],
		["counter"]
	)

	var container := _create_container()
	var station := _create_station("counter")
	station.reserve(agent)  # Reserve the station

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [station])

	assert_false(result.can_start, "Job should NOT be startable with reserved station")
	assert_array_size(result.missing_stations, 1, "Should show station as unavailable")
	assert_eq(result.missing_stations[0], "counter", "Missing station should be counter")

	agent.queue_free()
	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_can_start_job_multiple_requirements() -> void:
	test("can_start_job with multiple requirements")
	var board = _create_job_board()

	# Create complex recipe with multiple requirements
	var recipe := _create_recipe_with_inputs("Complex Cooking",
		[{"tag": "raw_food", "quantity": 2}, {"tag": "seasoning", "quantity": 1}],
		["knife", "pan"],
		["counter", "stove"]
	)

	# Create container with all items and tools
	var container := _create_container()
	container.add_item(_create_item("raw_food"))
	container.add_item(_create_item("raw_food"))
	container.add_item(_create_item("seasoning"))
	container.add_item(_create_item("knife"))
	container.add_item(_create_item("pan"))

	# Create both stations
	var counter := _create_station("counter")
	var stove := _create_station("stove")

	var job: Job = board.post_job(recipe, 1)
	var result = board.can_start_job(job, [container], [counter, stove])

	assert_true(result.can_start, "Job should be startable with all complex requirements met")
	assert_eq(result.reason, "", "Reason should be empty")

	# Now test with missing some requirements
	var container2 := _create_container()
	container2.add_item(_create_item("raw_food"))  # Only 1, need 2
	# Missing seasoning, knife, pan

	var result2 = board.can_start_job(job, [container2], [counter])  # Missing stove

	assert_false(result2.can_start, "Job should NOT be startable with missing requirements")
	assert_array_size(result2.missing_items, 2, "Should have 2 missing item types")
	assert_array_size(result2.missing_tools, 2, "Should have 2 missing tools")
	assert_array_size(result2.missing_stations, 1, "Should have 1 missing station")
	assert_true(result2.reason.contains("Missing items"), "Reason should mention items")
	assert_true(result2.reason.contains("Missing tools"), "Reason should mention tools")
	assert_true(result2.reason.contains("Unavailable stations"), "Reason should mention stations")

	counter.queue_free()
	stove.queue_free()
	container.queue_free()
	container2.queue_free()
	_cleanup_job_board(board)


# ============================================================================
# can_start_job() tests for ground and station output items (US-003)
# ============================================================================

## Helper to create a mock level with ground item support
func _create_mock_level() -> Node2D:
	var level := MockLevel.new()
	test_area.add_child(level)
	return level


## Mock level class with ground items support
class MockLevel extends Node2D:
	var all_items: Array[ItemEntity] = []

	func add_ground_item(item: ItemEntity) -> void:
		item.location = ItemEntity.ItemLocation.ON_GROUND
		all_items.append(item)
		add_child(item)

	func get_ground_items_by_tag(tag: String) -> Array[ItemEntity]:
		var result: Array[ItemEntity] = []
		for item in all_items:
			if not is_instance_valid(item):
				continue
			if item.location != ItemEntity.ItemLocation.ON_GROUND:
				continue
			if item.item_tag != tag:
				continue
			if item.is_reserved():
				continue
			result.append(item)
		return result


func test_can_start_finds_ground_items() -> void:
	test("can_start_job finds ground items (US-003)")
	var board = _create_job_board()

	# Create recipe requiring 1 raw_food
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		[],
		["counter"]
	)

	# Create empty container
	var container := _create_container()

	# Create station
	var station := _create_station("counter")

	# Create mock level with ground item
	var level := _create_mock_level()
	var ground_item := _create_item("raw_food")
	level.add_ground_item(ground_item)

	var job: Job = board.post_job(recipe, 1)

	# Without level, should fail (no items in container)
	var result_no_level = board.can_start_job(job, [container], [station])
	assert_false(result_no_level.can_start, "Should fail without level (no container items)")

	# With level, should find ground item
	var result_with_level = board.can_start_job(job, [container], [station], level)
	assert_true(result_with_level.can_start, "Should succeed when item on ground")
	assert_array_size(result_with_level.missing_items, 0, "No missing items")

	level.queue_free()
	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


func test_can_start_finds_station_output() -> void:
	test("can_start_job finds station output items (US-003)")
	var board = _create_job_board()

	# Create recipe requiring 1 cooked_meal
	var recipe := _create_recipe_with_inputs("Eating",
		[{"tag": "cooked_meal", "quantity": 1}],
		[],
		["counter"]
	)

	# Create empty container
	var container := _create_container()

	# Create station with output item
	var stove := _create_station_with_slots("stove", 1)
	var output_item := _create_item("cooked_meal")
	stove.place_output_item(output_item, 0)

	# Create required counter station
	var counter := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# Should find item in station output slot
	var result = board.can_start_job(job, [container], [stove, counter])
	assert_true(result.can_start, "Should succeed when item in station output slot")
	assert_array_size(result.missing_items, 0, "No missing items")

	stove.queue_free()
	counter.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


func test_can_start_combines_sources() -> void:
	test("can_start_job combines items from all sources (US-003)")
	var board = _create_job_board()

	# Create recipe requiring 3 raw_food
	var recipe := _create_recipe_with_inputs("Big Cooking",
		[{"tag": "raw_food", "quantity": 3}],
		[],
		["counter"]
	)

	# Put 1 item in container
	var container := _create_container()
	container.add_item(_create_item("raw_food"))

	# Put 1 item in station output
	var stove := _create_station_with_slots("stove", 1)
	var output_item := _create_item("raw_food")
	stove.place_output_item(output_item, 0)

	# Put 1 item on ground
	var level := _create_mock_level()
	var ground_item := _create_item("raw_food")
	level.add_ground_item(ground_item)

	# Create required counter
	var counter := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# Should combine items from all three sources (1+1+1=3)
	var result = board.can_start_job(job, [container], [stove, counter], level)
	assert_true(result.can_start, "Should succeed when combining items from all sources")
	assert_array_size(result.missing_items, 0, "No missing items")

	# Test with only 2 sources (should fail, need 3)
	var result_partial = board.can_start_job(job, [container], [stove, counter])  # No level
	assert_false(result_partial.can_start, "Should fail with only 2 items from 2 sources")
	assert_array_size(result_partial.missing_items, 1, "Should have 1 missing item entry")
	assert_eq(result_partial.missing_items[0].quantity_found, 2, "Should find 2 items")
	assert_eq(result_partial.missing_items[0].quantity_needed, 3, "Should need 3 items")

	level.queue_free()
	stove.queue_free()
	counter.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


func test_can_start_excludes_reserved_from_all_sources() -> void:
	test("can_start_job excludes reserved items from all sources (US-003)")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)

	# Create recipe requiring 1 raw_food
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		[],
		["counter"]
	)

	# Create container with reserved item
	var container := _create_container()
	var container_item := _create_item("raw_food")
	container.add_item(container_item)
	container_item.reserve_item(agent)

	# Create station with reserved output item
	var stove := _create_station_with_slots("stove", 1)
	var output_item := _create_item("raw_food")
	stove.place_output_item(output_item, 0)
	output_item.reserve_item(agent)

	# Create ground item that is reserved
	var level := _create_mock_level()
	var ground_item := _create_item("raw_food")
	level.add_ground_item(ground_item)
	ground_item.reserve_item(agent)

	var counter := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# All items are reserved, should fail
	var result = board.can_start_job(job, [container], [stove, counter], level)
	assert_false(result.can_start, "Should fail when all items are reserved")
	assert_array_size(result.missing_items, 1, "Should have 1 missing item entry")
	assert_eq(result.missing_items[0].quantity_found, 0, "Should find 0 available items")

	# Release one item, should succeed
	ground_item.release_item()
	var result_after_release = board.can_start_job(job, [container], [stove, counter], level)
	assert_true(result_after_release.can_start, "Should succeed after releasing one item")

	agent.queue_free()
	level.queue_free()
	stove.queue_free()
	counter.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


func test_can_start_partial_sources() -> void:
	test("can_start_job handles partial items across sources (US-003)")
	var board = _create_job_board()

	# Create recipe requiring 2 raw_food and 1 knife tool
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 2}],
		["knife"],
		["counter"]
	)

	# Put 1 raw_food in container
	var container := _create_container()
	container.add_item(_create_item("raw_food"))

	# Put 1 raw_food on ground
	var level := _create_mock_level()
	var ground_food := _create_item("raw_food")
	level.add_ground_item(ground_food)

	# Put knife in station output
	var stove := _create_station_with_slots("stove", 1)
	var knife := _create_item("knife")
	stove.place_output_item(knife, 0)

	var counter := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# Should find 2 raw_food (1 container + 1 ground) and knife in station output
	var result = board.can_start_job(job, [container], [stove, counter], level)
	assert_true(result.can_start, "Should succeed with items split across sources")
	assert_array_size(result.missing_items, 0, "No missing items")
	assert_array_size(result.missing_tools, 0, "No missing tools")

	level.queue_free()
	stove.queue_free()
	counter.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


func test_can_start_container_items_unchanged() -> void:
	test("can_start_job container behavior unchanged (US-003 backward compat)")
	var board = _create_job_board()

	# Create recipe requiring items - same as original test
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		[],
		["counter"]
	)

	# Create container with the required item
	var container := _create_container()
	var item := _create_item("raw_food")
	container.add_item(item)

	# Create the required station
	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# Should work exactly as before (no level parameter)
	var result = board.can_start_job(job, [container], [station])
	assert_true(result.can_start, "Job should be startable with container items (backward compat)")
	assert_eq(result.reason, "", "Reason should be empty when can start")
	assert_array_size(result.missing_items, 0, "No missing items")

	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)


# ============================================================================
# interrupt_job() tests (US-012)
# ============================================================================

func test_interrupt_job() -> void:
	test("Interrupt job")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)

	var job: Job = board.post_job(recipe, 1)

	# Cannot interrupt POSTED job
	var interrupted: bool = board.interrupt_job(job)
	assert_false(interrupted, "Cannot interrupt POSTED job")
	assert_eq(job.state, Job.JobState.POSTED, "Job should still be POSTED")

	# Claim and start the job
	board.claim_job(job, agent)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED")

	# Cannot interrupt CLAIMED job
	interrupted = board.interrupt_job(job)
	assert_false(interrupted, "Cannot interrupt CLAIMED job")
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should still be CLAIMED")

	# Start the job
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")

	# Now interrupt should work
	interrupted = board.interrupt_job(job)
	assert_true(interrupted, "Should interrupt IN_PROGRESS job")
	assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")

	# Cannot interrupt already interrupted job
	interrupted = board.interrupt_job(job)
	assert_false(interrupted, "Cannot interrupt already INTERRUPTED job")

	agent.queue_free()
	_cleanup_job_board(board)

func test_interrupt_job_signal() -> void:
	test("Interrupt job signal")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent := Node.new()
	test_area.add_child(agent)

	var signals_received := {"interrupted": false, "interrupted_job": null}
	board.job_interrupted.connect(func(j):
		signals_received["interrupted"] = true
		signals_received["interrupted_job"] = j
	)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	board.interrupt_job(job)

	assert_true(signals_received["interrupted"], "job_interrupted signal should be emitted")
	assert_eq(signals_received["interrupted_job"], job, "Signal should pass the correct job")

	agent.queue_free()
	_cleanup_job_board(board)

func test_interrupt_job_preserves_step_index() -> void:
	test("Interrupt job preserves step index")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)

	# Create recipe with multiple steps
	var recipe := Recipe.new()
	recipe.recipe_name = "Multi-step"
	var step1 := RecipeStep.new()
	step1.station_tag = "counter"
	step1.action = "prep"
	step1.duration = 2.0
	recipe.add_step(step1)
	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 5.0
	recipe.add_step(step2)
	var step3 := RecipeStep.new()
	step3.station_tag = "counter"
	step3.action = "plate"
	step3.duration = 1.0
	recipe.add_step(step3)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	# Advance to step 2 (index 1)
	job.advance_step()
	assert_eq(job.current_step_index, 1, "Should be at step 1")

	# Interrupt
	board.interrupt_job(job)
	assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
	assert_eq(job.current_step_index, 1, "Step index should be preserved after interrupt")

	agent.queue_free()
	_cleanup_job_board(board)

func test_interrupted_job_claimable() -> void:
	test("Interrupted job is claimable")
	var board = _create_job_board()
	var recipe := _create_test_recipe()
	var agent1 := Node.new()
	var agent2 := Node.new()
	test_area.add_child(agent1)
	test_area.add_child(agent2)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent1)
	job.start()
	board.interrupt_job(job)

	# Job should be claimable
	assert_true(job.is_claimable(), "Interrupted job should be claimable")

	# Job should appear in available jobs
	var available: Array[Job] = board.get_available_jobs()
	assert_array_contains(available, job, "Interrupted job should be in available jobs")

	# Another agent should be able to claim it
	var claimed: bool = board.claim_job(job, agent2)
	assert_true(claimed, "Agent2 should be able to claim interrupted job")
	assert_eq(job.claimed_by, agent2, "Job should be claimed by agent2")
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED after re-claim")

	agent1.queue_free()
	agent2.queue_free()
	_cleanup_job_board(board)

func test_interrupted_job_reservations_released() -> void:
	test("Interrupted job releases reservations")
	var board = _create_job_board()
	var agent := Node.new()
	test_area.add_child(agent)

	# Create recipe with items
	var recipe := _create_recipe_with_inputs("Cooking",
		[{"tag": "raw_food", "quantity": 1}],
		["knife"],
		["counter"]
	)

	# Create container with items
	var container := _create_container()
	var food := _create_item("raw_food")
	var knife := _create_item("knife")
	container.add_item(food)
	container.add_item(knife)

	# Create station
	var station := _create_station("counter")

	var job: Job = board.post_job(recipe, 1)

	# Claim job with containers (reserves items)
	board.claim_job(job, agent, [container])

	# Items should be reserved
	assert_true(food.is_reserved(), "Food should be reserved after claim")
	assert_true(knife.is_reserved(), "Knife should be reserved after claim")

	# Start and interrupt
	job.start()
	station.reserve(agent)
	job.target_station = station

	board.interrupt_job(job)

	# All reservations should be released
	assert_false(food.is_reserved(), "Food should be unreserved after interrupt")
	assert_false(knife.is_reserved(), "Knife should be unreserved after interrupt")
	assert_null(job.claimed_by, "Job should have no claimed_by after interrupt")

	agent.queue_free()
	station.queue_free()
	container.queue_free()
	_cleanup_job_board(board)

func test_resume_interrupted_job() -> void:
	test("Resume interrupted job from step index")
	var board = _create_job_board()
	var agent1 := Node.new()
	var agent2 := Node.new()
	test_area.add_child(agent1)
	test_area.add_child(agent2)

	# Create recipe with multiple steps
	var recipe := Recipe.new()
	recipe.recipe_name = "Multi-step"
	var step1 := RecipeStep.new()
	step1.station_tag = "counter"
	step1.action = "prep"
	step1.duration = 2.0
	recipe.add_step(step1)
	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 5.0
	recipe.add_step(step2)

	var job: Job = board.post_job(recipe, 1)

	# Agent1 claims, starts, advances, then gets interrupted
	board.claim_job(job, agent1)
	job.start()
	job.advance_step()  # Move to step 1 (cook)
	assert_eq(job.current_step_index, 1, "Should be at step 1")

	board.interrupt_job(job)
	assert_eq(job.current_step_index, 1, "Step index preserved after interrupt")

	# Agent2 claims the interrupted job
	var claimed: bool = board.claim_job(job, agent2)
	assert_true(claimed, "Agent2 should claim interrupted job")
	assert_eq(job.claimed_by, agent2, "Job should be claimed by agent2")
	assert_eq(job.current_step_index, 1, "Step index should still be 1 after re-claim")

	# Agent2 starts and continues from step 1
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")
	assert_eq(job.current_step_index, 1, "Should resume from step 1")

	var current_step := job.get_current_step()
	assert_not_null(current_step, "Should have current step")
	assert_eq(current_step.station_tag, "stove", "Current step should be at stove")
	assert_eq(current_step.action, "cook", "Current action should be cook")

	agent1.queue_free()
	agent2.queue_free()
	_cleanup_job_board(board)


# ============================================================================
# complete_job() tests (US-013)
# ============================================================================

## Helper to create a mock agent with motives
## Uses a custom script to add motives property
func _create_mock_agent() -> Node2D:
	var agent := MockAgent.new()
	agent.motives = Motive.new("TestAgent")
	test_area.add_child(agent)
	return agent


## Mock agent class with motives property
class MockAgent extends Node2D:
	var motives: Motive = null

## Helper to create a recipe with outputs
func _create_recipe_with_outputs(recipe_name: String, outputs: Array[Dictionary], motive_effects: Dictionary = {}) -> Recipe:
	var recipe := Recipe.new()
	recipe.recipe_name = recipe_name

	for output in outputs:
		recipe.add_output(output.get("tag", ""), output.get("quantity", 1))

	for motive_name in motive_effects:
		recipe.set_motive_effect(motive_name, motive_effects[motive_name])

	# Add a simple step
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 1.0
	recipe.add_step(step)

	return recipe

## Helper to create a station with output slots
func _create_station_with_slots(tag: String, num_output_slots: int = 1) -> Station:
	var station := Station.new()
	station.station_tag = tag
	test_area.add_child(station)

	# Add output slot markers
	for i in range(num_output_slots):
		var marker := Marker2D.new()
		marker.name = "OutputSlot%d" % i
		marker.position = Vector2(i * 16, 0)
		station.add_child(marker)

	# Trigger auto-discovery
	station._auto_discover_markers()

	return station


func test_complete_job_basic() -> void:
	test("complete_job basic functionality")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	var recipe := _create_test_recipe("Test Job")
	var job: Job = board.post_job(recipe, 1)

	# Cannot complete POSTED job
	var completed: bool = board.complete_job(job, agent)
	assert_false(completed, "Cannot complete POSTED job")

	# Claim and start the job
	board.claim_job(job, agent)

	# Cannot complete CLAIMED job
	completed = board.complete_job(job, agent)
	assert_false(completed, "Cannot complete CLAIMED job")

	# Start the job
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")

	# Now complete should work
	completed = board.complete_job(job, agent)
	assert_true(completed, "Should complete IN_PROGRESS job")
	assert_eq(job.state, Job.JobState.COMPLETED, "Job should be COMPLETED")

	agent.queue_free()
	_cleanup_job_board(board)


func test_complete_job_motive_effects() -> void:
	test("complete_job applies motive effects")
	var board = _create_job_board()
	var agent := _create_mock_agent()
	var motives: Motive = agent.get("motives")

	# Set initial motive values
	motives.values[Motive.MotiveType.HUNGER] = 0.0
	motives.values[Motive.MotiveType.FUN] = -20.0

	# Create recipe with motive effects
	var recipe := _create_recipe_with_outputs("Satisfying Meal",
		[],
		{"hunger": 50.0, "fun": 30.0}
	)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	# Complete the job
	var completed: bool = board.complete_job(job, agent)
	assert_true(completed, "Job should complete")

	# Check motive effects were applied
	assert_eq(motives.get_value(Motive.MotiveType.HUNGER), 50.0, "Hunger should increase by 50")
	assert_eq(motives.get_value(Motive.MotiveType.FUN), 10.0, "Fun should increase by 30 (from -20 to 10)")

	agent.queue_free()
	_cleanup_job_board(board)


func test_complete_job_spawns_outputs() -> void:
	test("complete_job spawns output items at station")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe with outputs
	var recipe := _create_recipe_with_outputs("Cooking",
		[{"tag": "cooked_meal", "quantity": 1}, {"tag": "leftover", "quantity": 2}],
		{}
	)

	# Create station with 3 output slots
	var station := _create_station_with_slots("counter", 3)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	# Complete with station
	var completed: bool = board.complete_job(job, agent, station)
	assert_true(completed, "Job should complete")

	# Check outputs were spawned
	var output_items := station.get_all_output_items()
	assert_array_size(output_items, 3, "Should have 3 output items (1 cooked_meal + 2 leftover)")

	# Verify item tags
	var cooked_count := 0
	var leftover_count := 0
	for item in output_items:
		if item.item_tag == "cooked_meal":
			cooked_count += 1
			assert_eq(item.state, ItemEntity.ItemState.COOKED, "Cooked meal should have COOKED state")
		elif item.item_tag == "leftover":
			leftover_count += 1

	assert_eq(cooked_count, 1, "Should have 1 cooked_meal")
	assert_eq(leftover_count, 2, "Should have 2 leftovers")

	# Cleanup output items
	for item in output_items:
		item.queue_free()

	agent.queue_free()
	station.queue_free()
	_cleanup_job_board(board)


func test_spawn_outputs_fallback_to_ground() -> void:
	test("spawn_outputs falls back to ground when no output slots")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe with outputs
	var recipe := _create_recipe_with_outputs("Cooking",
		[{"tag": "cooked_meal", "quantity": 2}],
		{}
	)

	# Create station with only 1 output slot (but we need 2 items)
	var station := _create_station_with_slots("counter", 1)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	# Complete with station
	var completed: bool = board.complete_job(job, agent, station)
	assert_true(completed, "Job should complete")

	# First item should be in output slot
	var output_items := station.get_all_output_items()
	assert_array_size(output_items, 1, "Should have 1 item in output slot")

	# Second item should be a child of station (on ground)
	var ground_items: Array[ItemEntity] = []
	for child in station.get_children():
		if child is ItemEntity and not output_items.has(child):
			ground_items.append(child)

	assert_array_size(ground_items, 1, "Should have 1 item on ground")
	assert_eq(ground_items[0].location, ItemEntity.ItemLocation.ON_GROUND, "Ground item should have ON_GROUND location")
	assert_eq(ground_items[0].global_position, station.global_position, "Ground item should be at station position")

	# Cleanup
	for item in output_items:
		item.queue_free()
	for item in ground_items:
		item.queue_free()

	agent.queue_free()
	station.queue_free()
	_cleanup_job_board(board)


func test_spawn_outputs_sets_prepped_state() -> void:
	test("spawn_outputs sets PREPPED state for prepped items")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe with prepped output
	var recipe := _create_recipe_with_outputs("Prepping",
		[{"tag": "prepped_vegetables", "quantity": 1}],
		{}
	)

	# Create station with output slot
	var station := _create_station_with_slots("counter", 1)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()

	# Complete with station
	var completed: bool = board.complete_job(job, agent, station)
	assert_true(completed, "Job should complete")

	# Check output has PREPPED state
	var output_items := station.get_all_output_items()
	assert_array_size(output_items, 1, "Should have 1 output item")
	assert_eq(output_items[0].item_tag, "prepped_vegetables", "Item should have correct tag")
	assert_eq(output_items[0].state, ItemEntity.ItemState.PREPPED, "Item should have PREPPED state")

	# Cleanup
	for item in output_items:
		item.queue_free()

	agent.queue_free()
	station.queue_free()
	_cleanup_job_board(board)


func test_complete_job_consumes_inputs() -> void:
	test("complete_job consumes input items")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe with consumed inputs
	var recipe := Recipe.new()
	recipe.recipe_name = "Consume Test"
	recipe.add_input("raw_food", 2, true)  # 2x raw_food, consumed
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "cook"
	step.duration = 1.0
	recipe.add_step(step)

	# Create items
	var food1 := _create_item("raw_food")
	var food2 := _create_item("raw_food")
	test_area.add_child(food1)
	test_area.add_child(food2)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)

	# Add items to gathered
	job.add_gathered_item(food1)
	job.add_gathered_item(food2)

	job.start()

	# Complete the job
	var completed: bool = board.complete_job(job, agent)
	assert_true(completed, "Job should complete")

	# Wait a frame for queue_free to process
	await get_tree().process_frame

	# Check items were consumed (freed)
	assert_false(is_instance_valid(food1), "food1 should be freed (consumed)")
	assert_false(is_instance_valid(food2), "food2 should be freed (consumed)")

	agent.queue_free()
	_cleanup_job_board(board)


func test_complete_job_preserves_tools() -> void:
	test("complete_job preserves tools (not consumed)")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe with tool
	var recipe := Recipe.new()
	recipe.recipe_name = "Tool Test"
	recipe.add_input("raw_food", 1, true)  # consumed
	recipe.add_tool("knife")  # not consumed
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "cut"
	step.duration = 1.0
	recipe.add_step(step)

	# Create items
	var food := _create_item("raw_food")
	var knife := _create_item("knife")
	test_area.add_child(food)
	test_area.add_child(knife)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)

	# Add items to gathered
	job.add_gathered_item(food)
	job.add_gathered_item(knife)

	# Reserve items
	food.reserve_item(agent)
	knife.reserve_item(agent)

	job.start()

	# Complete the job
	var completed: bool = board.complete_job(job, agent)
	assert_true(completed, "Job should complete")

	# Wait a frame for queue_free to process
	await get_tree().process_frame

	# Check food was consumed but knife preserved
	assert_false(is_instance_valid(food), "food should be freed (consumed)")
	assert_true(is_instance_valid(knife), "knife should still exist (tool)")
	assert_false(knife.is_reserved(), "knife reservation should be released")

	knife.queue_free()
	agent.queue_free()
	_cleanup_job_board(board)


func test_complete_job_with_transforms() -> void:
	test("complete_job handles transformed items correctly")
	var board = _create_job_board()
	var agent := _create_mock_agent()

	# Create recipe where raw_food transforms to cooked_food
	var recipe := Recipe.new()
	recipe.recipe_name = "Transform Test"
	recipe.add_input("raw_food", 1, true)  # consumed
	var step := RecipeStep.new()
	step.station_tag = "stove"
	step.action = "cook"
	step.duration = 5.0
	step.input_transform = {"raw_food": "cooked_food"}
	recipe.add_step(step)

	# Create item and simulate transformation
	var food := _create_item("raw_food")
	test_area.add_child(food)

	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.add_gathered_item(food)
	job.start()

	# Simulate step transform (as agent would do during work)
	food.item_tag = "cooked_food"
	food.state = ItemEntity.ItemState.COOKED

	# Complete the job
	var completed: bool = board.complete_job(job, agent)
	assert_true(completed, "Job should complete")

	# Wait a frame for queue_free to process
	await get_tree().process_frame

	# Transformed item should be consumed (original tag was raw_food which is consumed)
	assert_false(is_instance_valid(food), "Transformed food should be consumed")

	agent.queue_free()
	_cleanup_job_board(board)


func test_complete_job_invalid_states() -> void:
	test("complete_job handles invalid inputs")
	var board = _create_job_board()
	var agent := _create_mock_agent()
	var recipe := _create_test_recipe()

	# Null job
	var completed: bool = board.complete_job(null, agent)
	assert_false(completed, "Cannot complete null job")

	# Null agent
	var job: Job = board.post_job(recipe, 1)
	board.claim_job(job, agent)
	job.start()
	completed = board.complete_job(job, null)
	assert_false(completed, "Cannot complete with null agent")

	# Job not in board
	var external_job := Job.new(recipe, 1)
	external_job.claim(agent)
	external_job.start()
	completed = board.complete_job(external_job, agent)
	assert_false(completed, "Cannot complete job not in board")

	# Cleanup
	agent.queue_free()
	_cleanup_job_board(board)
