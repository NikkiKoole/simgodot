extends "res://scripts/tests/test_runner.gd"
## Tests for NPC WORKING state (US-011)

# Preload scenes
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var test_area: Node2D

func _ready() -> void:
	_test_name = "Agent Working"
	test_area = $TestArea
	super._ready()

func run_tests() -> void:
	_log_header()
	test_npc_has_working_state()
	test_npc_has_working_variables()
	test_set_available_stations()
	test_find_station_for_step()
	test_start_step_work()
	test_work_timer_countdown()
	test_apply_step_transforms()
	test_step_advancement()
	test_job_completion()
	test_motive_effects_applied()
	test_cancel_working()
	test_is_working()
	test_tools_preserved_on_completion()
	_log_summary()

func test_npc_has_working_state() -> void:
	test("NPC has WORKING state")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	# WORKING should be state 5 (after IDLE=0, WALKING=1, WAITING=2, USING_OBJECT=3, HAULING=4)
	assert_eq(npc.State.WORKING, 5, "WORKING should be state 5")
	assert_true(npc.State.has("WORKING"), "State enum should have WORKING")

	npc.queue_free()

func test_npc_has_working_variables() -> void:
	test("NPC has working state variables")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	assert_not_null(npc.available_stations, "NPC should have available_stations array")
	assert_eq(npc.available_stations.size(), 0, "available_stations should be empty initially")
	assert_null(npc.target_station, "target_station should be null initially")
	assert_eq(npc.work_timer, 0.0, "work_timer should be 0 initially")
	assert_eq(npc.current_animation, "", "current_animation should be empty initially")

	npc.queue_free()

func test_set_available_stations() -> void:
	test("set_available_stations populates array")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	var station1: Station = StationScene.instantiate()
	var station2: Station = StationScene.instantiate()
	station1.station_tag = "counter"
	station2.station_tag = "stove"
	test_area.add_child(station1)
	test_area.add_child(station2)

	var stations: Array[Station] = [station1, station2]
	npc.set_available_stations(stations)

	assert_eq(npc.available_stations.size(), 2, "Should have 2 available stations")

	station1.queue_free()
	station2.queue_free()
	npc.queue_free()

func test_find_station_for_step() -> void:
	test("_find_station_for_step finds matching station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	var station1: Station = StationScene.instantiate()
	var station2: Station = StationScene.instantiate()
	station1.station_tag = "counter"
	station2.station_tag = "stove"
	test_area.add_child(station1)
	test_area.add_child(station2)

	var stations: Array[Station] = [station1, station2]
	npc.set_available_stations(stations)

	# Create a step requiring counter
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "prep"
	step.duration = 2.0

	var found: Station = npc._find_station_for_step(step)
	assert_not_null(found, "Should find a station")
	assert_eq(found.station_tag, "counter", "Should find counter station")

	# Create a step requiring stove
	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 3.0

	var found2: Station = npc._find_station_for_step(step2)
	assert_not_null(found2, "Should find stove station")
	assert_eq(found2.station_tag, "stove", "Should find stove station")

	# Create a step requiring non-existent station
	var step3 := RecipeStep.new()
	step3.station_tag = "oven"
	step3.action = "bake"
	step3.duration = 5.0

	var found3: Station = npc._find_station_for_step(step3)
	assert_null(found3, "Should not find oven station")

	station1.queue_free()
	station2.queue_free()
	npc.queue_free()

func test_start_step_work() -> void:
	test("_start_step_work sets timer and animation")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create station
	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)
	npc.target_station = station

	# Create recipe with step
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Recipe"

	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "prep"
	step.duration = 3.5
	step.animation = "prep_anim"
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	npc.current_job = job

	# Call _start_step_work
	npc._start_step_work()

	assert_eq(npc.work_timer, 3.5, "work_timer should be set to step duration")
	assert_eq(npc.current_animation, "prep_anim", "current_animation should be set")

	station.queue_free()
	npc.queue_free()

func test_work_timer_countdown() -> void:
	test("Work timer counts down during _do_work")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true
	npc.current_path = PackedVector2Array()  # Empty path means at station
	npc.path_index = 0

	# Create station
	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)
	npc.target_station = station

	# Create recipe with step
	var recipe := Recipe.new()
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.duration = 5.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job
	npc.work_timer = 5.0

	# Simulate _do_work with 1 second delta
	npc._do_work(1.0, 1.0)
	assert_eq(npc.work_timer, 4.0, "Timer should decrease by delta")

	npc._do_work(2.0, 2.0)
	assert_eq(npc.work_timer, 2.0, "Timer should continue decreasing")

	station.queue_free()
	npc.queue_free()

func test_apply_step_transforms() -> void:
	test("_apply_step_transforms changes item tags")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create station with input slot
	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)

	# Add a marker for input slot
	var slot_marker := Marker2D.new()
	slot_marker.name = "InputSlot0"
	station.add_child(slot_marker)
	station._auto_discover_markers()

	npc.target_station = station

	# Create item and place in station
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	item.set_state(ItemEntity.ItemState.RAW)
	test_area.add_child(item)
	station.place_input_item(item, 0)

	# Create step with transform
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "prep"
	step.duration = 2.0
	step.input_transform = {"raw_food": "prepped_food"}

	# Apply transforms
	npc._apply_step_transforms(step)

	assert_eq(item.item_tag, "prepped_food", "Item tag should be transformed")
	assert_eq(item.state, ItemEntity.ItemState.PREPPED, "Item state should be PREPPED")

	station.queue_free()
	npc.queue_free()

func test_step_advancement() -> void:
	test("Steps advance after completion")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create recipe with 2 steps
	var recipe := Recipe.new()
	recipe.recipe_name = "Two Step Recipe"

	var step1 := RecipeStep.new()
	step1.station_tag = "counter"
	step1.action = "prep"
	step1.duration = 1.0
	recipe.add_step(step1)

	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 2.0
	recipe.add_step(step2)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job

	assert_eq(job.current_step_index, 0, "Should start at step 0")

	# Advance step
	var has_more := job.advance_step()
	assert_true(has_more, "Should have more steps")
	assert_eq(job.current_step_index, 1, "Should be at step 1")

	# Advance again
	has_more = job.advance_step()
	assert_false(has_more, "Should have no more steps")
	assert_eq(job.current_step_index, 2, "Index should be past last step")

	npc.queue_free()

func test_job_completion() -> void:
	test("_finish_job completes job and resets state")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create simple recipe
	var recipe := Recipe.new()
	recipe.recipe_name = "Simple Recipe"
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.duration = 1.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job
	npc.current_state = npc.State.WORKING

	# Track job completion
	var completed := {"value": false}
	job.job_completed.connect(func(): completed["value"] = true)

	# Call _finish_job
	npc._finish_job()

	assert_true(completed["value"], "Job should emit completed signal")
	assert_eq(job.state, Job.JobState.COMPLETED, "Job state should be COMPLETED")
	assert_null(npc.current_job, "current_job should be null")
	assert_eq(npc.current_state, npc.State.IDLE, "State should be IDLE")

	npc.queue_free()

func test_motive_effects_applied() -> void:
	test("Motive effects applied on job completion")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Get initial hunger value
	var initial_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)

	# Create recipe with motive effect
	var recipe := Recipe.new()
	recipe.recipe_name = "Hunger Recipe"
	recipe.motive_effects = {"hunger": 50.0}
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.duration = 1.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job

	# Complete the job
	npc._finish_job()

	var final_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)
	assert_true(final_hunger > initial_hunger, "Hunger should increase after job completion")

	npc.queue_free()

func test_cancel_working() -> void:
	test("_cancel_working releases resources")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create station
	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	test_area.add_child(station)
	station.reserve(npc)
	npc.target_station = station

	# Create job
	var recipe := Recipe.new()
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.duration = 1.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job
	npc.current_state = npc.State.WORKING
	npc.work_timer = 5.0

	# Cancel working
	npc._cancel_working("Test cancellation")

	assert_null(npc.target_station, "target_station should be null")
	assert_true(station.is_available(), "Station should be released")
	assert_eq(job.state, Job.JobState.FAILED, "Job should be FAILED")
	assert_null(npc.current_job, "current_job should be null")
	assert_eq(npc.current_state, npc.State.IDLE, "State should be IDLE")
	assert_eq(npc.work_timer, 0.0, "work_timer should be reset")

	station.queue_free()
	npc.queue_free()

func test_is_working() -> void:
	test("is_working() returns correct state")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)

	assert_false(npc.is_working(), "Should not be working initially")

	npc.current_state = npc.State.WORKING
	assert_true(npc.is_working(), "Should be working when in WORKING state")

	npc.current_state = npc.State.IDLE
	assert_false(npc.is_working(), "Should not be working when IDLE")

	npc.queue_free()

func test_tools_preserved_on_completion() -> void:
	test("Tools are preserved on job completion, non-tools consumed")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create a food item (should be consumed)
	var food_item: ItemEntity = ItemEntityScene.instantiate()
	food_item.item_tag = "cooked_food"
	test_area.add_child(food_item)

	# Create a tool item (should be preserved)
	var tool_item: ItemEntity = ItemEntityScene.instantiate()
	tool_item.item_tag = "knife"
	test_area.add_child(tool_item)

	# Give items to NPC
	npc.held_items.append(food_item)
	npc.held_items.append(tool_item)
	food_item.reparent(npc)
	tool_item.reparent(npc)

	# Create recipe with knife as tool
	var recipe := Recipe.new()
	recipe.recipe_name = "Cooking Recipe"
	recipe.add_input("raw_food", 1, true)  # consumed
	recipe.add_tool("knife")  # preserved
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.duration = 1.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job
	npc.current_state = npc.State.WORKING

	# Complete the job
	npc._finish_job()

	# Food item should be consumed (queued for deletion)
	# Note: queue_free() doesn't immediately free, so we check is_queued_for_deletion()
	assert_true(food_item.is_queued_for_deletion(), "Food item should be queued for deletion")

	# Tool should still exist and be on the ground
	assert_true(is_instance_valid(tool_item), "Tool item should still exist")
	assert_eq(tool_item.location, ItemEntity.ItemLocation.ON_GROUND, "Tool should be ON_GROUND")
	assert_false(npc.held_items.has(tool_item), "Tool should not be in held_items")

	tool_item.queue_free()
	npc.queue_free()
