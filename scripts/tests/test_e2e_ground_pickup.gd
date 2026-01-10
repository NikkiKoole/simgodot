extends "res://scripts/tests/test_runner.gd"
## END-TO-END TEST: Cook-eat loop with autonomous ground/station item pickup (US-010)
##
## This tests the complete production-consumption loop WITHOUT manual item movement.
## Unlike test_production_consumption_loop which manually moves cooked_meal to a fridge,
## this test verifies NPCs can autonomously discover and pick up items from:
## - Station output slots (where recipes spawn items)
## - Ground (fallback when output slots are full)
##
## Key verification:
## - NPC cooks raw_food -> cooked_meal spawns at station output
## - NPC discovers cooked_meal via new item discovery system (US-001 to US-009)
## - NPC picks up cooked_meal from station output (not from a container)
## - NPC eats cooked_meal -> hunger increases

const TILE_SIZE: int = 32

var test_level: Node2D

const SIMPLE_ROOM_MAP: String = """
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
	_test_name = "E2E Ground/Station Pickup"
	_setup_test_level()
	super._ready()


func _setup_test_level() -> void:
	# Use the parent TestLevel from the scene (not a dynamically created one)
	# This ensures NPC._get_level() finds the same level we use for items
	test_level = get_parent()
	test_level.world_map = SIMPLE_ROOM_MAP
	test_level.auto_spawn_npcs = false


func _find_item_recursive(node: Node, item_tag: String) -> ItemEntity:
	if node is ItemEntity and node.item_tag == item_tag:
		return node
	for child in node.get_children():
		var found: ItemEntity = _find_item_recursive(child, item_tag)
		if found != null:
			return found
	return null


func run_tests() -> void:
	_log_header()
	await test_e2e_cook_eat_autonomous()
	await test_e2e_station_output_pickup()
	await test_e2e_ground_spawn_pickup()
	await test_e2e_multiple_npcs_no_conflict()
	_log_summary()


## Test the full cook-eat loop where NPC autonomously picks up cooked_meal from station output
func test_e2e_cook_eat_autonomous() -> void:
	test("E2E: Cook raw_food -> NPC discovers cooked_meal at station -> eats it -> hunger satisfied")

	# Clear state
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame
	await get_tree().process_frame

	# ==========================================================================
	# SETUP
	# ==========================================================================

	# Spawn fridge with raw_food
	var fridge: ItemContainer = DebugCommands.spawn_container("fridge", Vector2(96, 192))
	assert_not_null(fridge, "Fridge should spawn")
	await get_tree().process_frame

	var raw_food: ItemEntity = DebugCommands.spawn_item("raw_food", fridge)
	assert_not_null(raw_food, "Raw food should spawn in fridge")

	# Spawn counter station for prep
	var counter: Station = DebugCommands.spawn_station("counter", Vector2(192, 192))
	assert_not_null(counter, "Counter should spawn")
	await get_tree().process_frame

	var counter_slot: Marker2D = Marker2D.new()
	counter_slot.name = "InputSlot0"
	counter.add_child(counter_slot)
	var counter_footprint: Marker2D = Marker2D.new()
	counter_footprint.name = "AgentFootprint"
	counter_footprint.position = Vector2(0, 24)
	counter.add_child(counter_footprint)
	counter._auto_discover_markers()

	# Spawn stove station for cooking (with output slot for cooked_meal)
	var stove: Station = DebugCommands.spawn_station("stove", Vector2(288, 192))
	assert_not_null(stove, "Stove should spawn")
	await get_tree().process_frame

	var stove_slot: Marker2D = Marker2D.new()
	stove_slot.name = "InputSlot0"
	stove.add_child(stove_slot)
	var stove_output: Marker2D = Marker2D.new()
	stove_output.name = "OutputSlot0"
	stove.add_child(stove_output)
	var stove_footprint: Marker2D = Marker2D.new()
	stove_footprint.name = "AgentFootprint"
	stove_footprint.position = Vector2(0, 24)
	stove.add_child(stove_footprint)
	stove._auto_discover_markers()

	# Spawn NPC with high motives initially
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

	# Set up typed arrays
	var typed_containers: Array[ItemContainer] = [fridge]
	var typed_stations: Array[Station] = [counter, stove]
	npc.set_available_containers(typed_containers)
	npc.set_available_stations(typed_stations)

	# ==========================================================================
	# PHASE 1: COOKING
	# ==========================================================================

	print("    Phase 1: Cooking raw_food -> cooked_meal")

	var cook_job: Job = DebugCommands.post_job("res://resources/recipes/cook_simple_meal.tres")
	assert_not_null(cook_job, "Cook job should be posted")

	var cook_claimed: bool = JobBoard.claim_job(cook_job, npc, typed_containers, typed_stations, test_level)
	assert_true(cook_claimed, "NPC should claim cook job")

	var cook_hauling_started: bool = npc.start_hauling_for_job(cook_job)
	assert_true(cook_hauling_started, "NPC should start hauling for cook job")

	# Wait for cooking to complete
	var cook_completed: Dictionary = {"value": false}
	cook_job.job_completed.connect(func() -> void: cook_completed["value"] = true)

	var max_frames: int = 1200
	var frame_count: int = 0

	while not cook_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(cook_completed["value"], "Cook job should complete (took %d frames)" % frame_count)
	print("    Cooking completed in %d frames" % frame_count)

	# Wait for output to spawn and NPC to finish clearing held items
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify cooked_meal exists in station output or on ground (NOT in container or hand)
	# The spawned output should be in the station output slot
	var cooked_meal: ItemEntity = null

	# Check station output slots first (this is where _spawn_outputs puts items)
	var stove_outputs: Array[ItemEntity] = stove.get_available_output_items_by_tag("cooked_meal")
	if stove_outputs.size() > 0:
		cooked_meal = stove_outputs[0]

	# Check ground items via Level (fallback if output slot was full)
	if cooked_meal == null:
		var ground_items: Array[ItemEntity] = test_level.get_ground_items_by_tag("cooked_meal")
		if ground_items.size() > 0:
			cooked_meal = ground_items[0]

	# If not found in expected places, the feature may not be working
	# Don't use recursive search since that might find held items
	assert_not_null(cooked_meal, "cooked_meal should be spawned in station output or on ground after cooking")

	# Verify item is in the expected location (station output or ground)
	assert_true(
		cooked_meal.location == ItemEntity.ItemLocation.IN_SLOT or cooked_meal.location == ItemEntity.ItemLocation.ON_GROUND,
		"cooked_meal should be IN_SLOT or ON_GROUND"
	)

	# ==========================================================================
	# PHASE 2: EATING (autonomous pickup from station output or ground)
	# ==========================================================================

	print("    Phase 2: NPC discovers and eats cooked_meal autonomously")

	# Set NPC hunger low
	var initial_hunger: float = 10.0
	DebugCommands.set_npc_motive(npc, "hunger", initial_hunger)
	var actual_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_approx_eq(actual_hunger, initial_hunger, "NPC hunger should be 10")

	# Post eat_snack job - NPC should find cooked_meal via item discovery system
	var eat_job: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	assert_not_null(eat_job, "Eat job should be posted")

	# Claim job with stations and level for full item discovery
	var eat_claimed: bool = JobBoard.claim_job(eat_job, npc, typed_containers, typed_stations, test_level)
	assert_true(eat_claimed, "NPC should claim eat job (item found via discovery system)")

	# Connect to job_completed BEFORE starting hauling (eat_snack has no steps, may complete immediately)
	var eat_completed: Dictionary = {"value": false}
	eat_job.job_completed.connect(func() -> void: eat_completed["value"] = true)

	# Start hauling - NPC should pathfind to station output or ground item
	var eat_hauling_started: bool = npc.start_hauling_for_job(eat_job)
	assert_true(eat_hauling_started, "NPC should start hauling for eat job")

	frame_count = 0
	while not eat_completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(eat_completed["value"], "Eat job should complete (took %d frames)" % frame_count)
	print("    Eating completed in %d frames" % frame_count)

	# ==========================================================================
	# VERIFICATION
	# ==========================================================================

	var final_hunger: float = DebugCommands.get_npc_motive(npc, "hunger")
	assert_true(final_hunger > 25.0, "Hunger should be above 25 after eating (was %.1f, now %.1f)" % [initial_hunger, final_hunger])

	print("    E2E cook-eat autonomous loop complete!")
	print("    Hunger: %.1f -> %.1f (eating applied +50, minus decay)" % [initial_hunger, final_hunger])

	# Cleanup
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()


## Test that NPC can pick up items from station output slot
func test_e2e_station_output_pickup() -> void:
	test("E2E: NPC picks up item from station output slot")

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame

	# Spawn a station with item already in output slot
	var station: Station = DebugCommands.spawn_station("counter", Vector2(192, 192))
	assert_not_null(station, "Station should spawn")
	await get_tree().process_frame

	var output_marker: Marker2D = Marker2D.new()
	output_marker.name = "OutputSlot0"
	station.add_child(output_marker)
	var footprint: Marker2D = Marker2D.new()
	footprint.name = "AgentFootprint"
	footprint.position = Vector2(0, 24)
	station.add_child(footprint)
	station._auto_discover_markers()

	# Create item and place in output slot
	var ItemEntityScene: PackedScene = preload("res://scenes/objects/item_entity.tscn")
	var meal: ItemEntity = ItemEntityScene.instantiate()
	meal.item_tag = "cooked_meal"
	station.place_output_item(meal, 0)
	assert_not_null(meal, "Meal should be created")
	assert_eq(meal.location, ItemEntity.ItemLocation.IN_SLOT, "Meal should be IN_SLOT")

	# Spawn NPC
	var npc: Node = DebugCommands.spawn_npc(Vector2(64, 192), {
		"hunger": 10.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc, "NPC should spawn")
	await get_tree().process_frame

	var typed_containers: Array[ItemContainer] = []
	var typed_stations: Array[Station] = [station]
	npc.set_available_containers(typed_containers)
	npc.set_available_stations(typed_stations)

	# Post eat job - should find meal in station output
	var eat_job: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	assert_not_null(eat_job, "Eat job should be posted")

	var claimed: bool = JobBoard.claim_job(eat_job, npc, typed_containers, typed_stations, test_level)
	assert_true(claimed, "NPC should claim eat job with item in station output")

	# Connect signal BEFORE starting hauling
	var completed: Dictionary = {"value": false}
	eat_job.job_completed.connect(func() -> void: completed["value"] = true)

	var hauling_started: bool = npc.start_hauling_for_job(eat_job)
	assert_true(hauling_started, "NPC should start hauling")

	var max_frames: int = 600
	var frame_count: int = 0
	while not completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(completed["value"], "Eat job should complete")

	# Verify station output is now empty
	assert_false(station.has_output_items(), "Station output should be empty after pickup")

	print("    Station output pickup verified in %d frames" % frame_count)

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()


## Test that NPC can pick up items spawned on ground
func test_e2e_ground_spawn_pickup() -> void:
	test("E2E: NPC picks up item spawned on ground")

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame

	# Spawn item on ground via Level
	var meal: ItemEntity = test_level.add_item(Vector2(192, 192), "cooked_meal")
	assert_not_null(meal, "Meal should spawn on ground")
	assert_eq(meal.location, ItemEntity.ItemLocation.ON_GROUND, "Meal should be ON_GROUND")

	# Verify Level tracks it
	var ground_items: Array[ItemEntity] = test_level.get_ground_items_by_tag("cooked_meal")
	assert_eq(ground_items.size(), 1, "Level should track 1 ground item")

	# Spawn NPC
	var npc: Node = DebugCommands.spawn_npc(Vector2(64, 192), {
		"hunger": 10.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc, "NPC should spawn")
	await get_tree().process_frame

	var typed_containers: Array[ItemContainer] = []
	var typed_stations: Array[Station] = []
	npc.set_available_containers(typed_containers)
	npc.set_available_stations(typed_stations)

	# Post eat job - should find meal on ground
	var eat_job: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	assert_not_null(eat_job, "Eat job should be posted")

	var claimed: bool = JobBoard.claim_job(eat_job, npc, typed_containers, typed_stations, test_level)
	assert_true(claimed, "NPC should claim eat job with item on ground")

	# Connect signal BEFORE starting hauling
	var completed: Dictionary = {"value": false}
	eat_job.job_completed.connect(func() -> void: completed["value"] = true)

	var hauling_started: bool = npc.start_hauling_for_job(eat_job)
	assert_true(hauling_started, "NPC should start hauling")

	var max_frames: int = 600
	var frame_count: int = 0
	while not completed["value"] and frame_count < max_frames:
		await get_tree().physics_frame
		frame_count += 1

	assert_true(completed["value"], "Eat job should complete")

	# Verify item removed from ground
	var remaining_items: Array[ItemEntity] = test_level.get_ground_items_by_tag("cooked_meal")
	assert_eq(remaining_items.size(), 0, "Ground item should be picked up")

	print("    Ground item pickup verified in %d frames" % frame_count)

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()


## Test that two NPCs don't claim the same ground item
func test_e2e_multiple_npcs_no_conflict() -> void:
	test("E2E: Two NPCs don't claim the same ground item")

	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
	await get_tree().process_frame

	# Spawn ONE meal on ground
	var meal: ItemEntity = test_level.add_item(Vector2(192, 192), "cooked_meal")
	assert_not_null(meal, "Meal should spawn on ground")

	# Spawn two NPCs
	var npc1: Node = DebugCommands.spawn_npc(Vector2(64, 192), {
		"hunger": 10.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	var npc2: Node = DebugCommands.spawn_npc(Vector2(320, 192), {
		"hunger": 10.0,
		"energy": 100.0,
		"bladder": 100.0,
		"hygiene": 100.0,
		"fun": 100.0
	})
	assert_not_null(npc1, "NPC1 should spawn")
	assert_not_null(npc2, "NPC2 should spawn")
	await get_tree().process_frame

	var typed_containers: Array[ItemContainer] = []
	var typed_stations: Array[Station] = []
	npc1.set_available_containers(typed_containers)
	npc1.set_available_stations(typed_stations)
	npc2.set_available_containers(typed_containers)
	npc2.set_available_stations(typed_stations)

	# Post two eat jobs
	var eat_job1: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	var eat_job2: Job = DebugCommands.post_job("res://resources/recipes/eat_snack.tres")
	assert_not_null(eat_job1, "Eat job 1 should be posted")
	assert_not_null(eat_job2, "Eat job 2 should be posted")

	# First NPC claims - should succeed
	var claimed1: bool = JobBoard.claim_job(eat_job1, npc1, typed_containers, typed_stations, test_level)
	assert_true(claimed1, "NPC1 should claim first eat job")

	# Verify meal is now reserved
	assert_true(meal.is_reserved(), "Meal should be reserved after first claim")
	assert_eq(meal.reserved_by, npc1, "Meal should be reserved by NPC1")

	# Second NPC tries to claim - job.claim() will succeed but no items can be reserved
	# The real protection is that start_hauling_for_job will fail when no items are available
	var claimed2: bool = JobBoard.claim_job(eat_job2, npc2, typed_containers, typed_stations, test_level)
	# Note: claim_job returns true because it claims the JOB, not the items
	# Items are reserved separately and reservation prevents double-pickup

	# Verify item is still reserved by NPC1 (not stolen by NPC2)
	assert_true(meal.is_reserved(), "Meal should still be reserved")
	assert_eq(meal.reserved_by, npc1, "Meal should still be reserved by NPC1 (not NPC2)")

	# The key verification: NPC2 cannot start hauling because it can't find available items
	var hauling2_started: bool = npc2.start_hauling_for_job(eat_job2)
	assert_false(hauling2_started, "NPC2 should NOT be able to start hauling (item reserved by NPC1)")

	print("    Reservation conflict test passed - second NPC cannot haul reserved item")

	# Cleanup
	test_level.remove_item(meal)
	DebugCommands.clear_scenario()
	JobBoard.clear_all_jobs()
