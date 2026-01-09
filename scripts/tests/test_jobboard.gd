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
