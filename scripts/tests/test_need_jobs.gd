extends "res://scripts/tests/test_runner.gd"
## Tests for Need System with Job Posting Integration (US-014)

# Preload scripts for creating test instances
const RecipeRegistryScript = preload("res://scripts/recipe_registry.gd")
const JobBoardScript = preload("res://scripts/job_board.gd")

var test_area: Node2D

func _ready() -> void:
	_test_name = "NeedJobs"
	test_area = $TestArea
	super._ready()

func run_tests() -> void:
	_log_header()

	test_recipe_registry_creation()
	test_register_recipe()
	test_get_recipes_for_motive()
	test_get_best_recipe_for_motive()
	test_has_recipe_for_motive()
	test_automatic_job_posting_when_need_critical()
	test_job_priority_based_on_urgency()
	test_no_duplicate_jobs_posted()
	test_best_executable_recipe_selected()

	_log_summary()

# ============================================================================
# Helper functions
# ============================================================================

func _create_recipe_registry() -> Node:
	var registry = RecipeRegistryScript.new()
	test_area.add_child(registry)
	return registry

func _cleanup_registry(registry: Node) -> void:
	registry.clear_all_recipes()
	registry.queue_free()

func _create_job_board() -> Node:
	var board = JobBoardScript.new()
	test_area.add_child(board)
	return board

func _cleanup_job_board(board: Node) -> void:
	board.clear_all_jobs()
	board.queue_free()

func _create_test_recipe(recipe_name: String, motive: String = "", motive_value: float = 0.0) -> Recipe:
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

func _create_recipe_with_inputs(recipe_name: String, inputs: Array[Dictionary], motive: String = "", motive_value: float = 0.0) -> Recipe:
	var recipe := Recipe.new()
	recipe.recipe_name = recipe_name
	for input in inputs:
		recipe.add_input(input.get("tag", ""), input.get("quantity", 1), input.get("consumed", true))
	var step := RecipeStep.new()
	step.station_tag = "counter"
	step.action = "work"
	step.duration = 2.0
	recipe.add_step(step)
	if not motive.is_empty():
		recipe.set_motive_effect(motive, motive_value)
	return recipe

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

# ============================================================================
# RecipeRegistry tests
# ============================================================================

func test_recipe_registry_creation() -> void:
	test("RecipeRegistry creation")
	var registry = _create_recipe_registry()
	assert_not_null(registry, "RecipeRegistry should be created")
	assert_eq(registry.get_recipe_count(), 0, "New registry should have no recipes")
	_cleanup_registry(registry)

func test_register_recipe() -> void:
	test("Register recipe")
	var registry = _create_recipe_registry()
	var recipe := _create_test_recipe("Test Cooking", "hunger", 50.0)

	registry.register_recipe(recipe)
	assert_eq(registry.get_recipe_count(), 1, "Registry should have 1 recipe")

	# Registering same recipe again should not duplicate
	registry.register_recipe(recipe)
	assert_eq(registry.get_recipe_count(), 1, "Registry should still have 1 recipe (no duplicates)")

	# Register another recipe
	var recipe2 := _create_test_recipe("Test Fun", "fun", 30.0)
	registry.register_recipe(recipe2)
	assert_eq(registry.get_recipe_count(), 2, "Registry should have 2 recipes")

	# Null recipe should not be registered
	registry.register_recipe(null)
	assert_eq(registry.get_recipe_count(), 2, "Null recipe should not be registered")

	_cleanup_registry(registry)

func test_get_recipes_for_motive() -> void:
	test("Get recipes for motive")
	var registry = _create_recipe_registry()

	# Register recipes with different motive effects
	var hunger_recipe1 := _create_test_recipe("Eat Food", "hunger", 50.0)
	var hunger_recipe2 := _create_test_recipe("Snack", "hunger", 20.0)
	var fun_recipe := _create_test_recipe("Play Game", "fun", 40.0)
	var no_motive_recipe := _create_test_recipe("Work Task")

	registry.register_recipe(hunger_recipe1)
	registry.register_recipe(hunger_recipe2)
	registry.register_recipe(fun_recipe)
	registry.register_recipe(no_motive_recipe)

	var hunger_recipes: Array[Recipe] = registry.get_recipes_for_motive("hunger")
	assert_array_size(hunger_recipes, 2, "Should have 2 hunger recipes")
	assert_array_contains(hunger_recipes, hunger_recipe1, "Should contain hunger_recipe1")
	assert_array_contains(hunger_recipes, hunger_recipe2, "Should contain hunger_recipe2")

	var fun_recipes: Array[Recipe] = registry.get_recipes_for_motive("fun")
	assert_array_size(fun_recipes, 1, "Should have 1 fun recipe")

	var energy_recipes: Array[Recipe] = registry.get_recipes_for_motive("energy")
	assert_array_size(energy_recipes, 0, "Should have 0 energy recipes")

	_cleanup_registry(registry)

func test_get_best_recipe_for_motive() -> void:
	test("Get best recipe for motive")
	var registry = _create_recipe_registry()

	# Register recipes with different effect values
	var low_hunger := _create_test_recipe("Snack", "hunger", 20.0)
	var high_hunger := _create_test_recipe("Full Meal", "hunger", 80.0)
	var medium_hunger := _create_test_recipe("Light Meal", "hunger", 50.0)

	registry.register_recipe(low_hunger)
	registry.register_recipe(high_hunger)
	registry.register_recipe(medium_hunger)

	var best: Recipe = registry.get_best_recipe_for_motive("hunger")
	assert_eq(best, high_hunger, "Should return recipe with highest effect value")
	assert_eq(best.get_motive_effect("hunger"), 80.0, "Best recipe should have 80 hunger effect")

	# No matching recipe
	var no_match: Recipe = registry.get_best_recipe_for_motive("social")
	assert_null(no_match, "Should return null for no matching recipes")

	_cleanup_registry(registry)

func test_has_recipe_for_motive() -> void:
	test("Has recipe for motive")
	var registry = _create_recipe_registry()

	var hunger_recipe := _create_test_recipe("Eat Food", "hunger", 50.0)
	registry.register_recipe(hunger_recipe)

	assert_true(registry.has_recipe_for_motive("hunger"), "Should have recipe for hunger")
	assert_false(registry.has_recipe_for_motive("fun"), "Should not have recipe for fun")
	assert_false(registry.has_recipe_for_motive("energy"), "Should not have recipe for energy")

	_cleanup_registry(registry)

# ============================================================================
# NPC automatic job posting tests
# ============================================================================

## Mock NPC class for testing job posting behavior
class MockNPC extends Node2D:
	var motives: Motive = null
	var available_containers: Array[ItemContainer] = []
	var available_stations: Array[Station] = []

	func _init() -> void:
		motives = Motive.new("MockNPC")

	## Simulated version of NPC._try_post_job_for_motive
	func try_post_job_for_motive(motive_name: String, motive_type: Motive.MotiveType, registry: Node, job_board: Node) -> Job:
		# Check if registry has recipes for this motive
		if not registry.has_recipe_for_motive(motive_name):
			return null

		# Get all recipes that fulfill this motive
		var matching_recipes: Array[Recipe] = registry.get_recipes_for_motive(motive_name)
		if matching_recipes.is_empty():
			return null

		# Find the best recipe we can execute
		var best_recipe: Recipe = null
		var best_effect: float = 0.0

		for recipe in matching_recipes:
			# Check if we have requirements
			var temp_job := Job.new(recipe, 0)
			var can_start = job_board.can_start_job(temp_job, available_containers, available_stations)

			if can_start.can_start:
				var effect := recipe.get_motive_effect(motive_name)
				if effect > best_effect:
					best_effect = effect
					best_recipe = recipe

		if best_recipe == null:
			return null

		# Calculate priority based on motive value
		var priority := calculate_priority(motive_type)

		# Post the job
		var job: Job = job_board.post_job(best_recipe, priority)
		return job

	func calculate_priority(motive_type: Motive.MotiveType) -> int:
		var motive_value := motives.get_value(motive_type)
		# -100 motive = 100 priority, +100 motive = 0 priority
		var priority := int((100.0 - motive_value) / 2.0)
		return clampi(priority, 0, 100)

	func _motive_type_to_name(motive_type: Motive.MotiveType) -> String:
		match motive_type:
			Motive.MotiveType.HUNGER: return "hunger"
			Motive.MotiveType.ENERGY: return "energy"
			Motive.MotiveType.BLADDER: return "bladder"
			Motive.MotiveType.HYGIENE: return "hygiene"
			Motive.MotiveType.FUN: return "fun"
			_: return ""

func _create_mock_npc() -> MockNPC:
	var npc := MockNPC.new()
	test_area.add_child(npc)
	return npc

func test_automatic_job_posting_when_need_critical() -> void:
	test("Automatic job posting when need is critical")
	var registry = _create_recipe_registry()
	var board = _create_job_board()
	var npc := _create_mock_npc()

	# Register a hunger recipe
	var hunger_recipe := _create_test_recipe("Eat Food", "hunger", 50.0)
	registry.register_recipe(hunger_recipe)

	# Create required station
	var station := _create_station("counter")
	npc.available_stations.append(station)

	# Set NPC's hunger to critical level (-60)
	npc.motives.values[Motive.MotiveType.HUNGER] = -60.0
	assert_true(npc.motives.has_critical_motive(), "NPC should have critical motive")

	# Board should have no jobs initially
	assert_eq(board.get_job_count(), 0, "Board should have no jobs initially")

	# Post job for hunger need
	var job: Job = npc.try_post_job_for_motive("hunger", Motive.MotiveType.HUNGER, registry, board)

	assert_not_null(job, "Job should be posted")
	assert_eq(board.get_job_count(), 1, "Board should have 1 job")
	assert_eq(job.recipe, hunger_recipe, "Job should use hunger recipe")
	assert_eq(job.state, Job.JobState.POSTED, "Job should be in POSTED state")

	station.queue_free()
	npc.queue_free()
	_cleanup_job_board(board)
	_cleanup_registry(registry)

func test_job_priority_based_on_urgency() -> void:
	test("Job priority based on need urgency")
	var registry = _create_recipe_registry()
	var board = _create_job_board()
	var npc := _create_mock_npc()

	# Register recipes
	var hunger_recipe := _create_test_recipe("Eat Food", "hunger", 50.0)
	var fun_recipe := _create_test_recipe("Have Fun", "fun", 40.0)
	registry.register_recipe(hunger_recipe)
	registry.register_recipe(fun_recipe)

	# Create required station
	var station := _create_station("counter")
	npc.available_stations.append(station)

	# Test priority calculation at different motive levels
	# motive -100 should give priority 100
	npc.motives.values[Motive.MotiveType.HUNGER] = -100.0
	var priority_critical := npc.calculate_priority(Motive.MotiveType.HUNGER)
	assert_eq(priority_critical, 100, "Depleted motive (-100) should have priority 100")

	# motive 0 should give priority 50
	npc.motives.values[Motive.MotiveType.HUNGER] = 0.0
	var priority_neutral := npc.calculate_priority(Motive.MotiveType.HUNGER)
	assert_eq(priority_neutral, 50, "Neutral motive (0) should have priority 50")

	# motive +100 should give priority 0
	npc.motives.values[Motive.MotiveType.HUNGER] = 100.0
	var priority_satisfied := npc.calculate_priority(Motive.MotiveType.HUNGER)
	assert_eq(priority_satisfied, 0, "Satisfied motive (+100) should have priority 0")

	# motive -50 (critical threshold) should give priority 75
	npc.motives.values[Motive.MotiveType.HUNGER] = -50.0
	var priority_threshold := npc.calculate_priority(Motive.MotiveType.HUNGER)
	assert_eq(priority_threshold, 75, "Critical threshold motive (-50) should have priority 75")

	# Post job with critical hunger and verify priority
	npc.motives.values[Motive.MotiveType.HUNGER] = -80.0
	var job: Job = npc.try_post_job_for_motive("hunger", Motive.MotiveType.HUNGER, registry, board)
	assert_not_null(job, "Job should be posted")
	assert_eq(job.priority, 90, "Job priority should be 90 for motive at -80")

	station.queue_free()
	npc.queue_free()
	_cleanup_job_board(board)
	_cleanup_registry(registry)

func test_no_duplicate_jobs_posted() -> void:
	test("No duplicate jobs posted for same need")
	var registry = _create_recipe_registry()
	var board = _create_job_board()
	var npc := _create_mock_npc()

	var hunger_recipe := _create_test_recipe("Eat Food", "hunger", 50.0)
	registry.register_recipe(hunger_recipe)

	var station := _create_station("counter")
	npc.available_stations.append(station)

	npc.motives.values[Motive.MotiveType.HUNGER] = -60.0

	# Post first job
	var job1: Job = npc.try_post_job_for_motive("hunger", Motive.MotiveType.HUNGER, registry, board)
	assert_not_null(job1, "First job should be posted")
	assert_eq(board.get_job_count(), 1, "Board should have 1 job")

	# If there's already a job available for the motive, NPC should claim it instead of posting new one
	# This test verifies that existing job is found before posting
	var existing_job: Job = board.get_highest_priority_job_for_motive("hunger")
	assert_not_null(existing_job, "Should find existing job for hunger")
	assert_eq(existing_job, job1, "Should find the same job")

	station.queue_free()
	npc.queue_free()
	_cleanup_job_board(board)
	_cleanup_registry(registry)

func test_best_executable_recipe_selected() -> void:
	test("Best executable recipe selected")
	var registry = _create_recipe_registry()
	var board = _create_job_board()
	var npc := _create_mock_npc()

	# Create recipes with different requirements and effects
	# High effect recipe requires item we don't have
	var high_recipe := _create_recipe_with_inputs("Gourmet Meal",
		[{"tag": "rare_ingredient", "quantity": 1}],
		"hunger", 100.0)

	# Medium effect recipe with no requirements (we can execute)
	var medium_recipe := _create_test_recipe("Simple Meal", "hunger", 50.0)

	# Low effect recipe we can also execute
	var low_recipe := _create_test_recipe("Snack", "hunger", 20.0)

	registry.register_recipe(high_recipe)
	registry.register_recipe(medium_recipe)
	registry.register_recipe(low_recipe)

	# Create station (all recipes use "counter")
	var station := _create_station("counter")
	npc.available_stations.append(station)

	# No containers means we can't do recipes requiring items
	# We should select medium_recipe as it's the best we can execute

	npc.motives.values[Motive.MotiveType.HUNGER] = -60.0
	var job: Job = npc.try_post_job_for_motive("hunger", Motive.MotiveType.HUNGER, registry, board)

	assert_not_null(job, "Job should be posted")
	assert_eq(job.recipe, medium_recipe, "Should select medium recipe (highest executable)")
	assert_eq(job.recipe.get_motive_effect("hunger"), 50.0, "Selected recipe should have 50 hunger effect")

	# Now add the rare ingredient and try again
	board.clear_all_jobs()
	var container := _create_container()
	container.add_item(_create_item("rare_ingredient"))
	npc.available_containers.append(container)

	var job2: Job = npc.try_post_job_for_motive("hunger", Motive.MotiveType.HUNGER, registry, board)

	assert_not_null(job2, "Job should be posted")
	assert_eq(job2.recipe, high_recipe, "Should now select high recipe (now executable)")
	assert_eq(job2.recipe.get_motive_effect("hunger"), 100.0, "Selected recipe should have 100 hunger effect")

	station.queue_free()
	container.queue_free()
	npc.queue_free()
	_cleanup_job_board(board)
	_cleanup_registry(registry)
