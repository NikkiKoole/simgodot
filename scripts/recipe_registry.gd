extends Node
## Central singleton for storing and querying available recipes
## NPCs use this to find recipes that can fulfill their needs

## All registered recipes
var recipes: Array[Recipe] = []

## Signal emitted when a recipe is registered
signal recipe_registered(recipe: Recipe)

func _ready() -> void:
	pass

## Register a recipe to be available for job posting
func register_recipe(recipe: Recipe) -> void:
	if recipe == null:
		return
	if not recipes.has(recipe):
		recipes.append(recipe)
		recipe_registered.emit(recipe)

## Register multiple recipes at once
func register_recipes(recipe_list: Array) -> void:
	for recipe in recipe_list:
		if recipe is Recipe:
			register_recipe(recipe)

## Unregister a recipe
func unregister_recipe(recipe: Recipe) -> void:
	var index := recipes.find(recipe)
	if index >= 0:
		recipes.remove_at(index)

## Get all registered recipes
func get_all_recipes() -> Array[Recipe]:
	return recipes

## Get recipes that affect a specific motive
func get_recipes_for_motive(motive_name: String) -> Array[Recipe]:
	var matching: Array[Recipe] = []
	for recipe in recipes:
		if recipe.affects_motive(motive_name):
			matching.append(recipe)
	return matching

## Get the best recipe for a motive (highest effect value)
func get_best_recipe_for_motive(motive_name: String) -> Recipe:
	var best_recipe: Recipe = null
	var best_effect: float = 0.0

	for recipe in recipes:
		if recipe.affects_motive(motive_name):
			var effect := recipe.get_motive_effect(motive_name)
			if effect > best_effect:
				best_effect = effect
				best_recipe = recipe

	return best_recipe

## Check if any recipe exists that fulfills a motive
func has_recipe_for_motive(motive_name: String) -> bool:
	for recipe in recipes:
		if recipe.affects_motive(motive_name):
			return true
	return false

## Get recipe count
func get_recipe_count() -> int:
	return recipes.size()

## Clear all registered recipes
func clear_all_recipes() -> void:
	recipes.clear()

## Load recipes from a directory (loads all .tres files as Recipe resources)
func load_recipes_from_directory(dir_path: String) -> int:
	var loaded := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("RecipeRegistry: Could not open directory: " + dir_path)
		return 0

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := dir_path + "/" + file_name
			var resource := load(full_path)
			if resource is Recipe:
				register_recipe(resource)
				loaded += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	return loaded

## Debug print all registered recipes
func debug_print() -> void:
	print("=== RecipeRegistry ===")
	print("Total recipes: ", recipes.size())
	for recipe in recipes:
		print("  - ", recipe.recipe_name)
		var motives := recipe.get_affected_motives()
		if motives.size() > 0:
			print("    Affects: ", motives)
