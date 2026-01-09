extends VBoxContainer
## Post Job Tool - UI for manually posting jobs via recipes
## Provides a dropdown of available recipes and a Post button.
## All job posting goes through the DebugCommands API.

# Available recipes with their display names and paths
const RECIPES: Array[Dictionary] = [
	{"name": "Cook Simple Meal", "path": "res://resources/recipes/cook_simple_meal.tres"},
	{"name": "Use Toilet", "path": "res://resources/recipes/use_toilet.tres"},
	{"name": "Watch TV", "path": "res://resources/recipes/watch_tv.tres"}
]

# UI elements
@onready var recipe_dropdown: OptionButton = $RecipeDropdown
@onready var post_button: Button = $PostButton
@onready var status_label: Label = $StatusLabel

# Currently selected recipe path
var selected_recipe_path: String = ""


func _ready() -> void:
	# Populate recipe dropdown
	_populate_recipe_dropdown()

	# Connect button signal
	post_button.pressed.connect(_on_post_pressed)

	# Connect dropdown signal
	recipe_dropdown.item_selected.connect(_on_recipe_selected)

	# Select first recipe by default
	if recipe_dropdown.item_count > 0:
		recipe_dropdown.select(0)
		_on_recipe_selected(0)

	# Clear status initially
	status_label.text = ""


func _populate_recipe_dropdown() -> void:
	recipe_dropdown.clear()
	for recipe_data in RECIPES:
		recipe_dropdown.add_item(recipe_data["name"])


func _on_recipe_selected(index: int) -> void:
	if index >= 0 and index < RECIPES.size():
		selected_recipe_path = RECIPES[index]["path"]


func _on_post_pressed() -> void:
	if selected_recipe_path.is_empty():
		status_label.text = "Select a recipe first"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return

	# Post the job via DebugCommands
	var job: Job = DebugCommands.post_job(selected_recipe_path)

	if job != null:
		var recipe_name: String = job.recipe.recipe_name if job.recipe else "Unknown"
		status_label.text = "Posted: " + recipe_name
		status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		status_label.text = "Failed to post job"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
