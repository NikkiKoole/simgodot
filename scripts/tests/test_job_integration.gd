extends "res://scripts/tests/test_runner.gd"
## Integration tests for the full job system flow
## These tests run through actual physics frames to verify real gameplay behavior

const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

const TILE_SIZE := 32

var test_area: Node2D
var mock_astar: AStarGrid2D

func _ready() -> void:
	_test_name = "Job Integration"
	test_area = $TestArea
	_setup_astar()
	super._ready()

func _setup_astar() -> void:
	mock_astar = AStarGrid2D.new()
	mock_astar.region = Rect2i(0, 0, 20, 20)  # 20x20 grid
	mock_astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	mock_astar.offset = Vector2(TILE_SIZE / 2, TILE_SIZE / 2)
	mock_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	mock_astar.update()

func run_tests() -> void:
	_log_header()
	# These are async tests - they need to await
	await test_work_timer_counts_down_over_frames()
	await test_full_job_flow_with_pathfinding()
	await test_work_timer_not_instant_when_at_station()
	_log_summary()

## Test that work timer actually counts down over multiple physics frames
func test_work_timer_counts_down_over_frames() -> void:
	test("Work timer counts down over actual physics frames")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.global_position = Vector2(100, 100)
	npc.is_initialized = true
	npc.set_astar(mock_astar)

	# Create walkable positions
	var walkable: Array[Vector2] = []
	for x in range(20):
		for y in range(20):
			walkable.append(Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2))
	npc.set_walkable_positions(walkable)
	npc.set_wander_positions(walkable)

	# Create station at same position as NPC (so path is empty)
	var station: Station = StationScene.instantiate()
	station.station_tag = "counter"
	station.global_position = Vector2(100, 100)
	test_area.add_child(station)

	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Create recipe with 1 second work time
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Recipe"
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 1.0  # 1 second
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	job.start()
	npc.current_job = job
	npc.target_station = station
	station.reserve(npc)

	# Manually trigger the work flow as it would happen in game
	npc.current_state = npc.State.WORKING
	npc.current_path = PackedVector2Array()  # Empty path - already at station
	npc.path_index = 0
	npc._on_arrived_at_station()

	# Verify timer was set
	var initial_timer: float = npc.work_timer
	assert_true(initial_timer > 0.0, "Work timer should be set after _on_arrived_at_station")
	assert_eq(initial_timer, 1.0, "Work timer should be 1.0 seconds")

	# Wait for some physics frames
	var frames_to_wait := 30  # ~0.5 seconds at 60fps
	for i in range(frames_to_wait):
		await get_tree().physics_frame

	# Timer should have decreased but not finished
	var timer_after_wait: float = npc.work_timer
	assert_true(timer_after_wait < initial_timer, "Timer should decrease over frames")
	assert_true(timer_after_wait > 0.0, "Timer should not be finished yet")

	# Calculate expected decrease (30 frames at ~16.67ms each = ~0.5 seconds)
	var expected_decrease: float = frames_to_wait * (1.0 / 60.0)
	var actual_decrease: float = initial_timer - timer_after_wait
	# Allow some tolerance for frame timing
	assert_true(abs(actual_decrease - expected_decrease) < 0.1,
		"Timer decrease should be approximately %0.2f seconds, got %0.2f" % [expected_decrease, actual_decrease])

	station.queue_free()
	npc.queue_free()

## Test that NPC doesn't instantly complete work when already at station
func test_work_timer_not_instant_when_at_station() -> void:
	test("Work timer is not instant when NPC is already at station")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.global_position = Vector2(150, 150)
	npc.is_initialized = true
	npc.set_astar(mock_astar)

	var walkable: Array[Vector2] = []
	for x in range(20):
		for y in range(20):
			walkable.append(Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2))
	npc.set_walkable_positions(walkable)
	npc.set_wander_positions(walkable)

	# Create station at same position as NPC
	var station: Station = StationScene.instantiate()
	station.station_tag = "stove"
	station.global_position = Vector2(150, 150)
	test_area.add_child(station)

	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Create recipe with 2 second work time
	var recipe := Recipe.new()
	recipe.recipe_name = "Slow Recipe"
	var step := RecipeStep.new()
	step.station_tag = "stove"
	step.action = "cook"
	step.duration = 2.0
	recipe.add_step(step)

	var job := Job.new(recipe, 1)
	job.claim(npc)
	npc.current_job = job

	# Track if job completes
	var job_completed := {"value": false}
	job.job_completed.connect(func(): job_completed["value"] = true)

	# Start the work flow through _start_next_work_step (like real gameplay)
	job.start()
	npc._start_next_work_step()

	# Wait for NPC to arrive at station and start working
	# The path might not be empty even at same position due to grid snapping
	var max_wait := 120  # 2 seconds max
	var frames_waited := 0
	while npc.work_timer == 0.0 and frames_waited < max_wait:
		await get_tree().physics_frame
		frames_waited += 1

	# Now work_timer should be set
	var timer_when_started: float = npc.work_timer
	assert_true(timer_when_started > 0.0, "Work timer should be set after arriving at station")

	# Wait a few more frames - job should NOT complete instantly
	for i in range(10):
		await get_tree().physics_frame

	assert_false(job_completed["value"], "Job should NOT complete instantly")
	assert_true(npc.work_timer > 0.0, "Work timer should still be counting down")
	assert_true(npc.work_timer < timer_when_started, "Work timer should have decreased")
	assert_eq(npc.current_state, npc.State.WORKING, "NPC should still be in WORKING state")

	station.queue_free()
	npc.queue_free()

## Test the full job flow: hauling items then working at stations
func test_full_job_flow_with_pathfinding() -> void:
	test("Full job flow: haul items and work at multiple stations")

	var npc = NPCScene.instantiate()
	test_area.add_child(npc)
	npc.global_position = Vector2(64, 64)
	npc.is_initialized = true
	npc.set_astar(mock_astar)

	var walkable: Array[Vector2] = []
	for x in range(20):
		for y in range(20):
			walkable.append(Vector2(x * TILE_SIZE + TILE_SIZE/2, y * TILE_SIZE + TILE_SIZE/2))
	npc.set_walkable_positions(walkable)
	npc.set_wander_positions(walkable)

	# Create container with item
	var container: ItemContainer = ContainerScene.instantiate()
	container.container_name = "Test Fridge"
	container.global_position = Vector2(128, 64)
	test_area.add_child(container)

	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	test_area.add_child(item)
	container.add_item(item)

	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Create two stations
	var counter: Station = StationScene.instantiate()
	counter.station_tag = "counter"
	counter.global_position = Vector2(192, 64)
	test_area.add_child(counter)

	# Add input slot marker to counter
	var counter_slot := Marker2D.new()
	counter_slot.name = "InputSlot0"
	counter.add_child(counter_slot)
	counter._auto_discover_markers()

	var stove: Station = StationScene.instantiate()
	stove.station_tag = "stove"
	stove.global_position = Vector2(256, 64)
	test_area.add_child(stove)

	# Add input slot marker to stove
	var stove_slot := Marker2D.new()
	stove_slot.name = "InputSlot0"
	stove.add_child(stove_slot)
	stove._auto_discover_markers()

	var stations: Array[Station] = [counter, stove]
	npc.set_available_stations(stations)

	# Create a 2-step recipe
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Meal"
	recipe.add_input("raw_food", 1, true)
	recipe.motive_effects = {"hunger": 30.0}

	var step1 := RecipeStep.new()
	step1.station_tag = "counter"
	step1.action = "prep"
	step1.duration = 0.5  # Short for testing
	step1.input_transform = {"raw_food": "prepped_food"}
	recipe.add_step(step1)

	var step2 := RecipeStep.new()
	step2.station_tag = "stove"
	step2.action = "cook"
	step2.duration = 0.5  # Short for testing
	step2.input_transform = {"prepped_food": "cooked_food"}
	recipe.add_step(step2)

	var job := Job.new(recipe, 1)

	# Track job completion
	var job_completed := {"value": false}
	job.job_completed.connect(func(): job_completed["value"] = true)

	# Claim and start hauling
	job.claim(npc)
	npc.start_hauling_for_job(job)

	# Let the simulation run for up to 10 seconds (600 frames)
	var max_frames := 600
	var frame_count := 0

	while not job_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	# Verify job completed
	assert_true(job_completed["value"], "Job should complete within timeout")
	assert_eq(job.state, Job.JobState.COMPLETED, "Job state should be COMPLETED")

	# Verify it took more than just a few frames (i.e., timers were respected)
	# At 60fps, 1 second of work = 60 frames minimum
	# We have 0.5s prep + 0.5s cook = 1s minimum, plus walking time
	assert_true(frame_count > 30, "Job should take more than 30 frames (timers should work)")

	print("    Job completed in %d frames (~%.2f seconds)" % [frame_count, frame_count / 60.0])

	container.queue_free()
	counter.queue_free()
	stove.queue_free()
	npc.queue_free()
