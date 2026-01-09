extends "res://scripts/tests/test_runner.gd"

## Tests for Job class (US-006)

# Preload scenes
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var test_area: Node2D

func _ready() -> void:
	_test_name = "Job"
	test_area = $TestArea
	super._ready()

func run_tests() -> void:
	_log_header()
	test_job_creation()
	test_job_state_enum()
	test_job_claim_release()
	test_job_state_transitions()
	test_job_step_tracking()
	test_job_gathered_items()
	test_job_target_station()
	test_job_interruption()
	test_job_helper_methods()
	_log_summary()

func _create_test_recipe() -> Recipe:
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Recipe"

	# Add a couple of steps
	var step1 := RecipeStep.new()
	step1.station_tag = "counter"
	step1.action = "prep"
	step1.duration = 3.0
	recipe.add_step(step1)

	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 5.0
	recipe.add_step(step2)

	return recipe

func test_job_creation() -> void:
	test("Job creation")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 5)

	assert_not_null(job.job_id, "Job should have an ID")
	assert_true(job.job_id.begins_with("job_"), "Job ID should start with 'job_'")
	assert_eq(job.recipe, recipe, "Job should reference the recipe")
	assert_eq(job.priority, 5, "Job priority should be set")
	assert_eq(job.state, Job.JobState.POSTED, "Initial state should be POSTED")
	assert_null(job.claimed_by, "Job should not be claimed initially")
	assert_eq(job.current_step_index, 0, "Initial step index should be 0")
	assert_array_size(job.gathered_items, 0, "Gathered items should be empty initially")
	assert_null(job.target_station, "Target station should be null initially")

func test_job_state_enum() -> void:
	test("JobState enum values")

	# Verify all states exist
	assert_eq(Job.JobState.POSTED, 0, "POSTED should be 0")
	assert_eq(Job.JobState.CLAIMED, 1, "CLAIMED should be 1")
	assert_eq(Job.JobState.IN_PROGRESS, 2, "IN_PROGRESS should be 2")
	assert_eq(Job.JobState.INTERRUPTED, 3, "INTERRUPTED should be 3")
	assert_eq(Job.JobState.COMPLETED, 4, "COMPLETED should be 4")
	assert_eq(Job.JobState.FAILED, 5, "FAILED should be 5")

	# Test state name helper
	assert_eq(Job.get_state_name(Job.JobState.POSTED), "Posted", "State name for POSTED")
	assert_eq(Job.get_state_name(Job.JobState.CLAIMED), "Claimed", "State name for CLAIMED")
	assert_eq(Job.get_state_name(Job.JobState.IN_PROGRESS), "In Progress", "State name for IN_PROGRESS")
	assert_eq(Job.get_state_name(Job.JobState.INTERRUPTED), "Interrupted", "State name for INTERRUPTED")
	assert_eq(Job.get_state_name(Job.JobState.COMPLETED), "Completed", "State name for COMPLETED")
	assert_eq(Job.get_state_name(Job.JobState.FAILED), "Failed", "State name for FAILED")

func test_job_claim_release() -> void:
	test("Job claim and release")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)

	var agent1 := Node.new()
	var agent2 := Node.new()
	test_area.add_child(agent1)
	test_area.add_child(agent2)

	# Initially claimable
	assert_true(job.is_claimable(), "Job should be claimable when POSTED")

	# Claim by agent1
	var claimed := job.claim(agent1)
	assert_true(claimed, "Claim should succeed")
	assert_eq(job.claimed_by, agent1, "Job should be claimed by agent1")
	assert_eq(job.state, Job.JobState.CLAIMED, "State should be CLAIMED")
	assert_false(job.is_claimable(), "Job should not be claimable when CLAIMED")

	# Agent2 cannot claim
	var claimed2 := job.claim(agent2)
	assert_false(claimed2, "Agent2 claim should fail")
	assert_eq(job.claimed_by, agent1, "Job should still be claimed by agent1")

	# Same agent can re-claim
	var claimed_again := job.claim(agent1)
	assert_true(claimed_again, "Same agent re-claim should succeed")

	# Release
	job.release()
	assert_null(job.claimed_by, "Job should be unclaimed after release")
	assert_eq(job.state, Job.JobState.POSTED, "State should return to POSTED")
	assert_true(job.is_claimable(), "Job should be claimable after release")

	# Now agent2 can claim
	var claimed3 := job.claim(agent2)
	assert_true(claimed3, "Agent2 should be able to claim after release")

	agent1.queue_free()
	agent2.queue_free()

func test_job_state_transitions() -> void:
	test("Job state transitions")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)
	var agent := Node.new()
	test_area.add_child(agent)

	# POSTED -> CLAIMED
	assert_eq(job.state, Job.JobState.POSTED, "Initial state should be POSTED")
	job.claim(agent)
	assert_eq(job.state, Job.JobState.CLAIMED, "State should be CLAIMED after claim")

	# Cannot start from POSTED
	var job2 := Job.new(recipe, 1)
	var started_without_claim := job2.start()
	assert_false(started_without_claim, "Cannot start without claiming first")

	# CLAIMED -> IN_PROGRESS
	var started := job.start()
	assert_true(started, "Start should succeed from CLAIMED")
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "State should be IN_PROGRESS")
	assert_true(job.is_active(), "Job should be active")

	# IN_PROGRESS -> COMPLETED
	job.complete()
	assert_eq(job.state, Job.JobState.COMPLETED, "State should be COMPLETED")
	assert_true(job.is_finished(), "Job should be finished")

	# Test FAILED path
	var job3 := Job.new(recipe, 1)
	job3.claim(agent)
	job3.start()
	job3.fail("Test failure")
	assert_eq(job3.state, Job.JobState.FAILED, "State should be FAILED")
	assert_true(job3.is_finished(), "Failed job should be finished")

	agent.queue_free()

func test_job_step_tracking() -> void:
	test("Job step tracking")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)

	# Check initial step state
	assert_eq(job.current_step_index, 0, "Initial step index should be 0")
	assert_eq(job.get_total_steps(), 2, "Should have 2 steps")
	assert_eq(job.get_remaining_steps(), 2, "Should have 2 remaining steps")
	assert_false(job.is_all_steps_complete(), "Steps should not be complete initially")

	# Get current step
	var step := job.get_current_step()
	assert_not_null(step, "Current step should exist")
	assert_eq(step.station_tag, "counter", "First step should be at counter")

	# Advance step
	var has_more := job.advance_step()
	assert_true(has_more, "Should have more steps after advancing")
	assert_eq(job.current_step_index, 1, "Step index should be 1")
	assert_eq(job.get_remaining_steps(), 1, "Should have 1 remaining step")

	step = job.get_current_step()
	assert_eq(step.station_tag, "stove", "Second step should be at stove")

	# Advance past end
	has_more = job.advance_step()
	assert_false(has_more, "Should have no more steps")
	assert_eq(job.current_step_index, 2, "Step index should be 2")
	assert_true(job.is_all_steps_complete(), "All steps should be complete")
	assert_null(job.get_current_step(), "Current step should be null after all steps")

	# Test progress
	assert_eq(job.get_progress(), 1.0, "Progress should be 100% when complete")

func test_job_gathered_items() -> void:
	test("Job gathered items tracking")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)

	var item1: ItemEntity = ItemEntityScene.instantiate()
	var item2: ItemEntity = ItemEntityScene.instantiate()
	item1.item_tag = "raw_food"
	item2.item_tag = "tool"
	test_area.add_child(item1)
	test_area.add_child(item2)

	# Add items
	assert_array_size(job.gathered_items, 0, "Initially no gathered items")

	job.add_gathered_item(item1)
	assert_array_size(job.gathered_items, 1, "Should have 1 gathered item")
	assert_array_contains(job.gathered_items, item1, "Should contain item1")

	job.add_gathered_item(item2)
	assert_array_size(job.gathered_items, 2, "Should have 2 gathered items")

	# Cannot add same item twice
	job.add_gathered_item(item1)
	assert_array_size(job.gathered_items, 2, "Duplicate add should not increase count")

	# Remove item
	var removed := job.remove_gathered_item(item1)
	assert_true(removed, "Remove should succeed")
	assert_array_size(job.gathered_items, 1, "Should have 1 item after remove")
	assert_array_not_contains(job.gathered_items, item1, "Should not contain removed item")

	# Remove non-existent
	var removed_again := job.remove_gathered_item(item1)
	assert_false(removed_again, "Remove non-existent should fail")

	# Clear all
	job.add_gathered_item(item1)
	job.clear_gathered_items()
	assert_array_size(job.gathered_items, 0, "Should have no items after clear")

	item1.queue_free()
	item2.queue_free()

func test_job_target_station() -> void:
	test("Job target station reference")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)

	var station: Station = StationScene.instantiate()
	station.station_tag = "stove"
	test_area.add_child(station)

	# Initially no target station
	assert_null(job.target_station, "Target station should be null initially")

	# Set target station
	job.target_station = station
	assert_eq(job.target_station, station, "Target station should be set")
	assert_eq(job.target_station.station_tag, "stove", "Station tag should match")

	station.queue_free()

func test_job_interruption() -> void:
	test("Job interruption")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)
	var agent := Node.new()
	test_area.add_child(agent)

	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	test_area.add_child(item)

	# Setup job in progress
	job.claim(agent)
	job.start()
	job.target_station = station
	station.reserve(agent)
	job.add_gathered_item(item)
	item.reserve_item(agent)
	job.advance_step()  # Move to step 1

	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be in progress")
	assert_eq(job.current_step_index, 1, "Should be on step 1")
	assert_true(item.is_reserved(), "Item should be reserved")

	# Interrupt
	job.interrupt()

	assert_eq(job.state, Job.JobState.INTERRUPTED, "State should be INTERRUPTED")
	assert_null(job.claimed_by, "Claimed_by should be null after interrupt")
	assert_eq(job.current_step_index, 1, "Step index should be preserved")
	assert_true(job.is_claimable(), "Interrupted job should be claimable")
	assert_false(item.is_reserved(), "Items should be released on interrupt")
	assert_true(station.is_available(), "Station should be released on interrupt")

	# Can be reclaimed from INTERRUPTED
	var agent2 := Node.new()
	test_area.add_child(agent2)
	var reclaimed := job.claim(agent2)
	assert_true(reclaimed, "Interrupted job should be reclaimable")
	assert_eq(job.state, Job.JobState.CLAIMED, "State should be CLAIMED after reclaim")

	agent.queue_free()
	agent2.queue_free()
	station.queue_free()
	item.queue_free()

func test_job_helper_methods() -> void:
	test("Job helper methods")

	var recipe := _create_test_recipe()
	var job := Job.new(recipe, 1)
	var agent := Node.new()
	test_area.add_child(agent)

	# is_claimable
	assert_true(job.is_claimable(), "POSTED job should be claimable")
	job.claim(agent)
	assert_false(job.is_claimable(), "CLAIMED job should not be claimable")

	# is_active
	assert_true(job.is_active(), "CLAIMED job should be active")
	job.start()
	assert_true(job.is_active(), "IN_PROGRESS job should be active")

	# is_finished
	assert_false(job.is_finished(), "IN_PROGRESS job should not be finished")
	job.complete()
	assert_true(job.is_finished(), "COMPLETED job should be finished")

	# Test progress calculation
	var job2 := Job.new(recipe, 1)
	assert_eq(job2.get_progress(), 0.0, "Progress should be 0% at start")
	job2.advance_step()
	assert_eq(job2.get_progress(), 0.5, "Progress should be 50% after 1 of 2 steps")

	# Test with no recipe
	var job3 := Job.new(null, 1)
	assert_eq(job3.get_total_steps(), 0, "No recipe should have 0 steps")
	assert_null(job3.get_current_step(), "No recipe should return null step")
	assert_eq(job3.get_progress(), 1.0, "No recipe should show 100% progress")

	agent.queue_free()
