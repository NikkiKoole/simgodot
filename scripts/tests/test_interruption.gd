extends "res://scripts/tests/test_runner.gd"
## Tests for Job Interruption with Cooking Recipe (US-018)
## Verifies interruption works correctly: items preserved, job resumable, second agent can complete

# Preload scenes and resources
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var cook_simple_meal_recipe: Recipe
var test_area: Node2D

func _ready() -> void:
    _test_name = "Job Interruption with Cooking"
    test_area = $TestArea
    # Load the recipe resource
    cook_simple_meal_recipe = load("res://resources/recipes/cook_simple_meal.tres")
    super._ready()

func run_tests() -> void:
    _log_header()
    test_interrupt_after_prep_items_at_station()
    test_interrupt_while_holding_items_drops_on_ground()
    test_job_shows_interrupted_in_jobboard()
    test_interrupted_job_preserves_step_index()
    test_second_agent_can_claim_interrupted_job()
    test_second_agent_resumes_from_interrupted_step()
    test_second_agent_completes_cooking_from_interrupted_step()
    test_full_interruption_and_resume_sequence()
    # Edge case tests from code review
    test_multiple_interruptions_and_resumes()
    test_interrupt_before_any_work_done()
    test_job_interrupted_signal_emission()
    test_cannot_interrupt_posted_job()
    test_cannot_interrupt_claimed_job()
    test_cannot_interrupt_completed_job()
    test_cannot_interrupt_failed_job()
    _log_summary()


## Helper: Create a fully set up station with input/output slots and agent footprint
func _create_station(tag: String, pos: Vector2) -> Station:
    var station: Station = StationScene.instantiate()
    station.station_tag = tag
    station.position = pos
    test_area.add_child(station)

    var input_slot := Marker2D.new()
    input_slot.name = "InputSlot0"
    station.add_child(input_slot)

    var output_slot := Marker2D.new()
    output_slot.name = "OutputSlot0"
    station.add_child(output_slot)

    var footprint := Marker2D.new()
    footprint.name = "AgentFootprint"
    footprint.position = Vector2(0, 20)
    station.add_child(footprint)

    station._auto_discover_markers()
    return station


## Helper: Create an NPC with available containers and stations set up
func _create_npc(containers: Array[ItemContainer], stations: Array[Station]) -> Node:
    var npc = NPCScene.instantiate()
    npc.position = Vector2(0, 0)
    test_area.add_child(npc)
    npc.is_initialized = true
    npc.set_available_containers(containers)
    npc.set_available_stations(stations)
    return npc


## Helper: Create a container with an item
func _create_container_with_item(item_tag: String, item_state: int, pos: Vector2) -> Dictionary:
    var container: ItemContainer = ContainerScene.instantiate()
    container.position = pos
    test_area.add_child(container)

    var item: ItemEntity = ItemEntityScene.instantiate()
    item.item_tag = item_tag
    item.set_state(item_state)
    test_area.add_child(item)
    container.add_item(item)

    return {"container": container, "item": item}


## Test 1: Interrupt agent mid-cooking (after prep) - items stay at station slot
func test_interrupt_after_prep_items_at_station() -> void:
    test("Interrupt after prep - prepped food stays in station slot")

    # Create stations
    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    # Create container with raw_food
    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]
    var npc := _create_npc(containers, stations)

    # Create and claim job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    # Simulate: agent has gathered the item and placed it in counter for prep
    container.remove_item(raw_food)
    raw_food.set_location(ItemEntity.ItemLocation.IN_HAND)
    npc.held_items.append(raw_food)
    job.add_gathered_item(raw_food)

    # Agent arrives at counter, places item in slot
    npc.held_items.erase(raw_food)
    counter.place_input_item(raw_food, 0)
    npc.target_station = counter

    # Apply prep transform (step 0)
    var prep_step := cook_simple_meal_recipe.get_step(0)
    npc._apply_step_transforms(prep_step)

    # Advance to step 1 (cook at stove)
    job.advance_step()
    assert_eq(job.current_step_index, 1, "Should be at step 1 (cook)")

    # Verify item is now prepped_food
    assert_eq(raw_food.item_tag, "prepped_food", "Item should be transformed to prepped_food")

    # Item is still in the counter slot
    var item_in_slot := counter.get_input_item(0)
    assert_not_null(item_in_slot, "Item should still be in counter slot")
    assert_eq(item_in_slot.item_tag, "prepped_food", "Item in slot should be prepped_food")

    # Now interrupt the job via JobBoard
    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_true(interrupted, "Job should be interrupted successfully")

    # Verify item is still in the station slot (not dropped)
    var item_after_interrupt := counter.get_input_item(0)
    assert_not_null(item_after_interrupt, "Item should still be in counter slot after interrupt")
    assert_eq(item_after_interrupt.item_tag, "prepped_food", "Item should still be prepped_food")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 2: Interrupt while holding items - items drop on ground
func test_interrupt_while_holding_items_drops_on_ground() -> void:
    test("Interrupt while holding items - items dropped ON_GROUND")

    # Create stations
    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    # Create container with raw_food
    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]
    var npc := _create_npc(containers, stations)

    # Create and claim job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    # Simulate: agent has gathered the item but is still carrying it (hasn't placed in station yet)
    container.remove_item(raw_food)
    raw_food.set_location(ItemEntity.ItemLocation.IN_HAND)
    npc.held_items.append(raw_food)
    job.add_gathered_item(raw_food)

    # Reparent item to NPC (as would happen when carrying)
    raw_food.get_parent().remove_child(raw_food)
    npc.add_child(raw_food)

    # Verify agent is holding item
    assert_eq(npc.held_items.size(), 1, "NPC should hold 1 item")
    assert_eq(raw_food.location, ItemEntity.ItemLocation.IN_HAND, "Item should be IN_HAND")

    # Assign current_job so interrupt_current_job works
    npc.current_job = job

    # Interrupt via NPC method (which handles dropping items)
    var interrupted: bool = npc.interrupt_current_job()
    assert_true(interrupted, "NPC should interrupt current job successfully")

    # Verify item was dropped on ground
    assert_eq(raw_food.location, ItemEntity.ItemLocation.ON_GROUND, "Item should be ON_GROUND after interrupt")
    assert_eq(npc.held_items.size(), 0, "NPC should not hold any items after interrupt")

    # Item should no longer be child of NPC
    assert_neq(raw_food.get_parent(), npc, "Item should not be child of NPC after drop")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()
    if is_instance_valid(raw_food):
        raw_food.queue_free()


## Test 3: Job shows as INTERRUPTED in JobBoard
func test_job_shows_interrupted_in_jobboard() -> void:
    test("Interrupted job shows INTERRUPTED state in JobBoard")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]
    var npc := _create_npc(containers, stations)

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS before interrupt")

    # Interrupt job
    JobBoard.interrupt_job(job)

    # Verify state is INTERRUPTED
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED after interrupt")

    # Verify job is in JobBoard's list
    var interrupted_jobs := JobBoard.get_jobs_by_state(Job.JobState.INTERRUPTED)
    assert_eq(interrupted_jobs.size(), 1, "Should have 1 interrupted job")
    assert_eq(interrupted_jobs[0], job, "Interrupted job should be our job")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 4: Interrupted job preserves step index
func test_interrupted_job_preserves_step_index() -> void:
    test("Interrupted job preserves current_step_index")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]
    var npc := _create_npc(containers, stations)

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    # Advance to step 1 (as if prep was completed)
    job.advance_step()
    assert_eq(job.current_step_index, 1, "Job should be at step 1")

    # Interrupt job
    JobBoard.interrupt_job(job)

    # Verify step index is preserved
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
    assert_eq(job.current_step_index, 1, "Step index should still be 1 after interrupt")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 5: Second agent can claim interrupted job
func test_second_agent_can_claim_interrupted_job() -> void:
    test("Second agent can claim interrupted job")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    # Create first NPC
    var npc1 := _create_npc(containers, stations)

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc1, containers)
    job.start()
    job.advance_step()

    # Interrupt job
    JobBoard.interrupt_job(job)

    # Verify job is claimable
    assert_true(job.is_claimable(), "Interrupted job should be claimable")

    # Create second NPC
    var npc2 := _create_npc(containers, stations)

    # Second agent claims the interrupted job
    var claimed: bool = JobBoard.claim_job(job, npc2)
    assert_true(claimed, "Second agent should be able to claim interrupted job")
    assert_eq(job.claimed_by, npc2, "Job should be claimed by second agent")
    assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED after second agent claims")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc1.queue_free()
    npc2.queue_free()


## Test 9: Multiple interruptions - Agent A -> interrupt -> Agent B -> interrupt -> Agent C completes
func test_multiple_interruptions_and_resumes() -> void:
    test("Job can be interrupted and resumed multiple times")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    # Agent A starts, gets interrupted at step 0 (before completing prep)
    var npc_a := _create_npc(containers, stations)
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc_a, containers)
    job.start()

    assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")
    assert_eq(job.current_step_index, 0, "Should be at step 0")

    # Interrupt Agent A
    var interrupted_a: bool = JobBoard.interrupt_job(job)
    assert_true(interrupted_a, "First interrupt should succeed")
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
    assert_eq(job.current_step_index, 0, "Step index should still be 0")

    # Agent B claims, does prep, gets interrupted at step 1
    var npc_b := _create_npc(containers, stations)
    JobBoard.claim_job(job, npc_b)
    job.start()

    # Agent B completes prep step
    container.remove_item(raw_food)
    counter.place_input_item(raw_food, 0)
    npc_b.target_station = counter
    npc_b._apply_step_transforms(cook_simple_meal_recipe.get_step(0))
    job.advance_step()

    assert_eq(job.current_step_index, 1, "Should be at step 1")
    assert_eq(raw_food.item_tag, "prepped_food", "Item should be prepped_food")

    # Interrupt Agent B
    var interrupted_b: bool = JobBoard.interrupt_job(job)
    assert_true(interrupted_b, "Second interrupt should succeed")
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED again")
    assert_eq(job.current_step_index, 1, "Step index should be preserved at 1")

    # Agent C claims, resumes from step 1, completes
    var npc_c := _create_npc(containers, stations)
    JobBoard.claim_job(job, npc_c)
    job.start()

    assert_eq(job.current_step_index, 1, "Should resume at step 1")

    # Agent C completes cook step
    var prepped_food := counter.get_input_item(0)
    counter.remove_input_item(0)
    stove.place_input_item(prepped_food, 0)
    npc_c.target_station = stove
    npc_c._apply_step_transforms(cook_simple_meal_recipe.get_step(1))
    job.advance_step()

    assert_eq(prepped_food.item_tag, "cooked_meal", "Item should be cooked_meal")
    assert_true(job.is_all_steps_complete(), "All steps should be complete")

    job.complete()
    assert_eq(job.state, Job.JobState.COMPLETED, "Job should be COMPLETED")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc_a.queue_free()
    npc_b.queue_free()
    npc_c.queue_free()


## Test 10: Interrupt before any work done (at step 0, no items gathered)
func test_interrupt_before_any_work_done() -> void:
    test("Interrupt immediately after job.start() before any work")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc := _create_npc(containers, stations)

    # Create, claim, and start job but do NO work
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")
    assert_eq(job.current_step_index, 0, "Should be at step 0")
    assert_eq(job.gathered_items.size(), 1, "Should have reserved 1 item")

    # Interrupt immediately - no work done yet
    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_true(interrupted, "Should be able to interrupt")
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
    assert_eq(job.current_step_index, 0, "Step index should still be 0")

    # Item should still be in container (reservation released)
    assert_false(raw_food.is_reserved(), "Item reservation should be released")

    # Job should be claimable
    assert_true(job.is_claimable(), "Interrupted job should be claimable")

    # Second agent can claim and complete from step 0
    var npc2 := _create_npc(containers, stations)
    var claimed: bool = JobBoard.claim_job(job, npc2, containers)
    assert_true(claimed, "Second agent should claim")
    assert_eq(job.current_step_index, 0, "Should start from step 0")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()
    npc2.queue_free()


## Test 11: Verify job_interrupted signal is emitted
func test_job_interrupted_signal_emission() -> void:
    test("job_interrupted signal is emitted on interrupt")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc := _create_npc(containers, stations)

    # Track signal emission using Dictionary (lambdas capture by value)
    var state := {"signal_received": false, "signal_job": null}
    JobBoard.job_interrupted.connect(func(j: Job):
        state["signal_received"] = true
        state["signal_job"] = j
    )

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()

    assert_false(state["signal_received"], "Signal should not be received yet")

    # Interrupt job
    JobBoard.interrupt_job(job)

    # Verify signal was emitted
    assert_true(state["signal_received"], "job_interrupted signal should be received")
    assert_eq(state["signal_job"], job, "Signal should pass the interrupted job")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 12: Cannot interrupt POSTED job
func test_cannot_interrupt_posted_job() -> void:
    test("Cannot interrupt job in POSTED state")

    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    assert_eq(job.state, Job.JobState.POSTED, "Job should be POSTED")

    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_false(interrupted, "Should not be able to interrupt POSTED job")
    assert_eq(job.state, Job.JobState.POSTED, "Job should still be POSTED")

    # Cleanup
    JobBoard.clear_all_jobs()


## Test 13: Cannot interrupt CLAIMED job (not yet started)
func test_cannot_interrupt_claimed_job() -> void:
    test("Cannot interrupt job in CLAIMED state")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc := _create_npc(containers, stations)

    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)

    assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED")

    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_false(interrupted, "Should not be able to interrupt CLAIMED job")
    assert_eq(job.state, Job.JobState.CLAIMED, "Job should still be CLAIMED")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 14: Cannot interrupt COMPLETED job
func test_cannot_interrupt_completed_job() -> void:
    test("Cannot interrupt job in COMPLETED state")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc := _create_npc(containers, stations)

    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()
    job.complete()

    assert_eq(job.state, Job.JobState.COMPLETED, "Job should be COMPLETED")

    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_false(interrupted, "Should not be able to interrupt COMPLETED job")
    assert_eq(job.state, Job.JobState.COMPLETED, "Job should still be COMPLETED")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 15: Cannot interrupt FAILED job
func test_cannot_interrupt_failed_job() -> void:
    test("Cannot interrupt job in FAILED state")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc := _create_npc(containers, stations)

    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc, containers)
    job.start()
    job.fail("Test failure")

    assert_eq(job.state, Job.JobState.FAILED, "Job should be FAILED")

    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_false(interrupted, "Should not be able to interrupt FAILED job")
    assert_eq(job.state, Job.JobState.FAILED, "Job should still be FAILED")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc.queue_free()


## Test 6: Second agent resumes from interrupted step (not from beginning)
func test_second_agent_resumes_from_interrupted_step() -> void:
    test("Second agent resumes from interrupted step index")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc1 := _create_npc(containers, stations)

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc1, containers)
    job.start()

    # First agent completes prep step, item transformed and in counter
    container.remove_item(raw_food)
    counter.place_input_item(raw_food, 0)
    var prep_step := cook_simple_meal_recipe.get_step(0)
    npc1.target_station = counter
    npc1._apply_step_transforms(prep_step)

    # Advance to step 1
    job.advance_step()
    assert_eq(job.current_step_index, 1, "Should be at step 1 before interrupt")

    # Interrupt
    JobBoard.interrupt_job(job)

    # Second agent claims job
    var npc2 := _create_npc(containers, stations)
    JobBoard.claim_job(job, npc2)

    # Verify step index is still 1 (not reset to 0)
    assert_eq(job.current_step_index, 1, "Step index should remain 1 after claim by second agent")

    # Second agent's get_current_step should return the cook step (step 1)
    var current_step := job.get_current_step()
    assert_not_null(current_step, "Current step should exist")
    assert_eq(current_step.station_tag, "stove", "Current step should be at stove (cook step)")
    assert_eq(current_step.action, "cook", "Current step action should be cook")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc1.queue_free()
    npc2.queue_free()


## Test 7: Second agent completes cooking from interrupted step
func test_second_agent_completes_cooking_from_interrupted_step() -> void:
    test("Second agent completes cooking from interrupted step")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    var npc1 := _create_npc(containers, stations)

    # Create and start job
    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    JobBoard.claim_job(job, npc1, containers)
    job.start()

    # First agent completes prep step
    container.remove_item(raw_food)
    counter.place_input_item(raw_food, 0)
    npc1.target_station = counter
    npc1._apply_step_transforms(cook_simple_meal_recipe.get_step(0))
    job.advance_step()

    # Item is now prepped_food in counter
    assert_eq(raw_food.item_tag, "prepped_food", "Item should be prepped_food")

    # Interrupt after prep
    JobBoard.interrupt_job(job)

    # Second agent claims and starts job
    var npc2 := _create_npc(containers, stations)
    JobBoard.claim_job(job, npc2)
    job.start()

    # Second agent picks up prepped_food from counter and moves to stove
    var prepped_food := counter.get_input_item(0)
    counter.remove_input_item(0)
    stove.place_input_item(prepped_food, 0)
    npc2.target_station = stove

    # Second agent executes cook step (step 1)
    var cook_step := cook_simple_meal_recipe.get_step(1)
    npc2._apply_step_transforms(cook_step)

    # Verify food is now cooked
    assert_eq(prepped_food.item_tag, "cooked_meal", "Item should be transformed to cooked_meal")
    assert_eq(prepped_food.state, ItemEntity.ItemState.COOKED, "Item state should be COOKED")

    # Advance step and complete job
    job.advance_step()
    assert_true(job.is_all_steps_complete(), "All steps should be complete")

    # Get initial hunger for second agent
    var initial_hunger: float = npc2.motives.get_value(Motive.MotiveType.HUNGER)

    # Apply motive effects
    for motive_name in cook_simple_meal_recipe.motive_effects:
        var effect: float = cook_simple_meal_recipe.motive_effects[motive_name]
        if motive_name == "hunger":
            npc2.motives.fulfill(Motive.MotiveType.HUNGER, effect)

    var final_hunger: float = npc2.motives.get_value(Motive.MotiveType.HUNGER)
    assert_true(final_hunger > initial_hunger, "Hunger should increase for second agent")

    job.complete()
    assert_eq(job.state, Job.JobState.COMPLETED, "Job should be COMPLETED")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc1.queue_free()
    npc2.queue_free()


## Test 8: Full interruption and resume sequence (comprehensive test)
func test_full_interruption_and_resume_sequence() -> void:
    test("Full interruption and resume sequence")

    var counter := _create_station("counter", Vector2(100, 0))
    var stove := _create_station("stove", Vector2(150, 0))

    var container_data := _create_container_with_item("raw_food", ItemEntity.ItemState.RAW, Vector2(50, 0))
    var container: ItemContainer = container_data["container"]
    var raw_food: ItemEntity = container_data["item"]

    var containers: Array[ItemContainer] = [container]
    var stations: Array[Station] = [counter, stove]

    # === PHASE 1: First agent starts cooking ===
    var npc1 := _create_npc(containers, stations)

    var job := JobBoard.post_job(cook_simple_meal_recipe, 5)
    assert_eq(job.state, Job.JobState.POSTED, "Job should be POSTED initially")

    JobBoard.claim_job(job, npc1, containers)
    assert_eq(job.state, Job.JobState.CLAIMED, "Job should be CLAIMED")

    job.start()
    assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS")
    assert_eq(job.current_step_index, 0, "Should start at step 0")

    # Agent gathers item and does prep
    container.remove_item(raw_food)
    raw_food.set_location(ItemEntity.ItemLocation.IN_HAND)
    npc1.held_items.append(raw_food)
    job.add_gathered_item(raw_food)

    # Place in counter and apply prep transform
    npc1.held_items.erase(raw_food)
    counter.place_input_item(raw_food, 0)
    npc1.target_station = counter
    npc1._apply_step_transforms(cook_simple_meal_recipe.get_step(0))

    assert_eq(raw_food.item_tag, "prepped_food", "Item should be prepped_food after step 0")
    job.advance_step()
    assert_eq(job.current_step_index, 1, "Should be at step 1")

    # === PHASE 2: Interrupt mid-cooking ===
    var interrupted: bool = JobBoard.interrupt_job(job)
    assert_true(interrupted, "Job should be interruptible")
    assert_eq(job.state, Job.JobState.INTERRUPTED, "Job should be INTERRUPTED")
    assert_eq(job.current_step_index, 1, "Step index preserved at 1")
    assert_null(job.claimed_by, "Job should have no claimant after interrupt")

    # Item should still be in counter slot
    var item_in_counter := counter.get_input_item(0)
    assert_not_null(item_in_counter, "Prepped food should remain in counter slot")
    assert_eq(item_in_counter.item_tag, "prepped_food", "Should still be prepped_food")

    # Job should appear in available jobs
    var available := JobBoard.get_available_jobs()
    assert_true(available.has(job), "Interrupted job should be in available jobs")

    # === PHASE 3: Second agent resumes and completes ===
    var npc2 := _create_npc(containers, stations)

    var claimed: bool = JobBoard.claim_job(job, npc2)
    assert_true(claimed, "Second agent should claim interrupted job")
    assert_eq(job.claimed_by, npc2, "Job claimed by second agent")

    job.start()
    assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be IN_PROGRESS again")
    assert_eq(job.current_step_index, 1, "Should still be at step 1 (cook)")

    # Second agent picks up prepped food and moves to stove
    var prepped_food := counter.get_input_item(0)
    counter.remove_input_item(0)
    stove.place_input_item(prepped_food, 0)
    npc2.target_station = stove
    job.add_gathered_item(prepped_food)

    # Execute cook step
    npc2._apply_step_transforms(cook_simple_meal_recipe.get_step(1))
    assert_eq(prepped_food.item_tag, "cooked_meal", "Item should be cooked_meal")
    assert_eq(prepped_food.state, ItemEntity.ItemState.COOKED, "State should be COOKED")

    job.advance_step()
    assert_eq(job.current_step_index, 2, "Should be at step 2 (past last step)")
    assert_true(job.is_all_steps_complete(), "All steps complete")

    # Apply motive effects
    var initial_hunger: float = npc2.motives.get_value(Motive.MotiveType.HUNGER)
    npc2.motives.fulfill(Motive.MotiveType.HUNGER, 50.0)
    var final_hunger: float = npc2.motives.get_value(Motive.MotiveType.HUNGER)
    assert_true(final_hunger > initial_hunger, "Hunger fulfilled for second agent")

    job.complete()
    assert_eq(job.state, Job.JobState.COMPLETED, "Job should be COMPLETED")

    # Verify job no longer in available jobs
    available = JobBoard.get_available_jobs()
    assert_false(available.has(job), "Completed job should not be in available jobs")

    # Cleanup
    JobBoard.clear_all_jobs()
    container.queue_free()
    counter.queue_free()
    stove.queue_free()
    npc1.queue_free()
    npc2.queue_free()
