extends "res://scripts/tests/test_runner.gd"
## Tests for Eat Snack Recipe (US-005)
## Verifies consumption recipe that consumes cooked_meal and satisfies hunger

# Preload scenes and resources
const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const JobBoardScript = preload("res://scripts/job_board.gd")

var eat_snack_recipe: Recipe
var test_area: Node2D

func _ready() -> void:
	_test_name = "Eat Snack Recipe"
	test_area = $TestArea
	# Load the recipe resource
	eat_snack_recipe = load("res://resources/recipes/eat_snack.tres")
	super._ready()

func run_tests() -> void:
	_log_header()
	test_eat_snack_exists()
	test_eat_snack_requires_cooked_meal()
	test_eat_snack_consumes_input()
	test_eat_snack_no_steps()
	test_eat_snack_no_outputs()
	test_eat_snack_satisfies_hunger()
	test_eating_consumes_meal_and_satisfies_hunger()
	_log_summary()

func test_eat_snack_exists() -> void:
	test("Recipe loads from .tres file")

	assert_not_null(eat_snack_recipe, "Recipe should load")
	assert_eq(eat_snack_recipe.recipe_name, "Eat Snack", "Recipe name should match")

func test_eat_snack_requires_cooked_meal() -> void:
	test("Recipe requires cooked_meal input")

	var inputs := eat_snack_recipe.get_inputs()
	assert_eq(inputs.size(), 1, "Should have 1 input")

	if inputs.size() > 0:
		var input := inputs[0]
		assert_eq(input.item_tag, "cooked_meal", "Input should be cooked_meal")
		assert_eq(input.quantity, 1, "Quantity should be 1")

func test_eat_snack_consumes_input() -> void:
	test("Recipe consumes the input")

	var inputs := eat_snack_recipe.get_inputs()
	assert_eq(inputs.size(), 1, "Should have 1 input")

	if inputs.size() > 0:
		var input := inputs[0]
		assert_true(input.consumed, "Input should be consumed")

func test_eat_snack_no_steps() -> void:
	test("Recipe has no steps (instant consumption)")

	assert_eq(eat_snack_recipe.get_step_count(), 0, "Should have 0 steps")
	assert_true(eat_snack_recipe.steps.is_empty(), "Steps array should be empty")

func test_eat_snack_no_outputs() -> void:
	test("Recipe has no outputs")

	var outputs := eat_snack_recipe.get_outputs()
	assert_eq(outputs.size(), 0, "Should have no outputs")
	assert_false(eat_snack_recipe.has_outputs(), "has_outputs() should return false")

func test_eat_snack_satisfies_hunger() -> void:
	test("Recipe satisfies hunger with 50.0 effect")

	assert_true(eat_snack_recipe.affects_motive("hunger"), "Should affect hunger")
	assert_eq(eat_snack_recipe.get_motive_effect("hunger"), 50.0, "Hunger effect should be 50.0")

func test_eating_consumes_meal_and_satisfies_hunger() -> void:
	test("Integration: Eating consumes meal and satisfies hunger")

	# Create NPC
	var npc = NPCScene.instantiate()
	npc.position = Vector2(0, 0)
	test_area.add_child(npc)
	npc.is_initialized = true

	# Create container with cooked_meal
	var container: ItemContainer = ContainerScene.instantiate()
	container.position = Vector2(50, 0)
	test_area.add_child(container)

	var cooked_meal: ItemEntity = ItemEntityScene.instantiate()
	cooked_meal.item_tag = "cooked_meal"
	test_area.add_child(cooked_meal)
	cooked_meal.set_state(ItemEntity.ItemState.COOKED)
	container.add_item(cooked_meal)

	# Set up NPC with container
	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Create job
	var job := Job.new(eat_snack_recipe, 5)

	assert_not_null(job, "Job should be created")
	assert_eq(job.recipe.recipe_name, "Eat Snack", "Job should use eat_snack recipe")

	# Claim job
	job.claim(npc)
	assert_eq(job.state, Job.JobState.CLAIMED, "Job should be claimed")

	# Gather cooked_meal
	container.remove_item(cooked_meal)
	cooked_meal.set_location(ItemEntity.ItemLocation.IN_HAND)
	npc.held_items.append(cooked_meal)
	job.add_gathered_item(cooked_meal)

	assert_eq(npc.held_items.size(), 1, "NPC should hold 1 item")
	assert_eq(cooked_meal.location, ItemEntity.ItemLocation.IN_HAND, "Item should be IN_HAND")

	# Start job (no steps, so it's immediately ready to complete)
	job.start()
	assert_eq(job.state, Job.JobState.IN_PROGRESS, "Job should be in progress")
	assert_eq(job.current_step_index, 0, "Should be at step 0 (no steps to execute)")

	# Get initial hunger value
	var initial_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)

	# Create a JobBoard to handle completion
	var job_board = JobBoardScript.new()
	test_area.add_child(job_board)
	job_board.jobs.append(job)

	# Complete job via JobBoard (this handles motive effects and item consumption)
	var completed: bool = job_board.complete_job(job, npc, null)
	assert_true(completed, "Job should complete successfully")

	# NPC clears held_items after complete_job returns (simulating NPC._finish_job)
	npc.held_items.clear()

	# Verify hunger increased
	var final_hunger: float = npc.motives.get_value(Motive.MotiveType.HUNGER)
	assert_true(final_hunger > initial_hunger, "Hunger should increase after eating")
	var expected_hunger: float = initial_hunger + 50.0
	if expected_hunger > 100.0:
		expected_hunger = 100.0
	assert_eq(final_hunger, expected_hunger, "Hunger should increase by 50 (capped at 100)")

	# Verify held_items cleared (NPC clears after job completion)
	assert_eq(npc.held_items.size(), 0, "Held items should be cleared after job completion")

	# Verify job state
	assert_eq(job.state, Job.JobState.COMPLETED, "Job should be completed")

	# Cleanup
	job_board.free()
	container.queue_free()
	npc.queue_free()
