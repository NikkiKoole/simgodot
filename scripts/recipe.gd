class_name Recipe
extends Resource

## Defines a complete interaction sequence with inputs, steps, and outputs
## Recipes are data-driven definitions of multi-step tasks agents can perform
##
## =============================================================================
## RECIPE RESOURCE FORMAT
## =============================================================================
##
## Recipes are saved as .tres files in resources/recipes/. They define:
## - What items are needed (inputs)
## - What tools are required (not consumed)
## - What steps to perform at which stations
## - What items are produced (outputs)
## - What motive effects occur on completion
##
## CREATING A NEW RECIPE:
## 1. Create RecipeStep resources for each step (see RecipeStep class)
## 2. Create a Recipe resource referencing those steps
## 3. Save as .tres file in resources/recipes/
##
## EXAMPLE STRUCTURE (cook_simple_meal.tres):
## ```
## [gd_resource type="Resource" script_class="Recipe" load_steps=4 format=3]
## [ext_resource type="Script" path="res://scripts/recipe.gd" id="1"]
## [ext_resource type="Resource" path="res://resources/recipes/step_prep.tres" id="2"]
## [ext_resource type="Resource" path="res://resources/recipes/step_cook.tres" id="3"]
##
## [resource]
## script = ExtResource("1")
## recipe_name = "Cook Simple Meal"
## inputs = [{"item_tag": "raw_food", "quantity": 1, "consumed": true}]
## tools = []
## steps = [ExtResource("2"), ExtResource("3")]
## outputs = [{"item_tag": "cooked_meal", "quantity": 1}]
## motive_effects = {"hunger": 50.0}
## ```
##
## MOTIVE NAMES:
## - "hunger" - Food satisfaction
## - "energy" - Rest/sleep
## - "bladder" - Bathroom needs
## - "hygiene" - Cleanliness
## - "fun" or "entertainment" - Entertainment
## - "social" - Social interaction
## - "comfort" - Physical comfort
## - "room" - Environment quality
##
## =============================================================================

## Inner class for recipe input requirements
class RecipeInput:
    ## The item tag required (e.g., "raw_food", "toilet_paper")
    var item_tag: String = ""
    ## How many of this item are needed
    var quantity: int = 1
    ## Whether this item is consumed during the recipe
    var consumed: bool = true

    func _init(tag: String = "", qty: int = 1, is_consumed: bool = true) -> void:
        item_tag = tag
        quantity = qty
        consumed = is_consumed

    func to_dict() -> Dictionary:
        return {
            "item_tag": item_tag,
            "quantity": quantity,
            "consumed": consumed
        }

    static func from_dict(data: Dictionary) -> RecipeInput:
        return RecipeInput.new(
            data.get("item_tag", ""),
            data.get("quantity", 1),
            data.get("consumed", true)
        )

## Inner class for recipe output products
class RecipeOutput:
    ## The item tag produced (e.g., "cooked_meal")
    var item_tag: String = ""
    ## How many of this item are produced
    var quantity: int = 1

    func _init(tag: String = "", qty: int = 1) -> void:
        item_tag = tag
        quantity = qty

    func to_dict() -> Dictionary:
        return {
            "item_tag": item_tag,
            "quantity": quantity
        }

    static func from_dict(data: Dictionary) -> RecipeOutput:
        return RecipeOutput.new(
            data.get("item_tag", ""),
            data.get("quantity", 1)
        )

## Human-readable name for this recipe
@export var recipe_name: String = ""

## Input items required for this recipe (stored as array of dictionaries for serialization)
## Each dictionary has: item_tag (String), quantity (int), consumed (bool)
@export var inputs: Array[Dictionary] = []

## Tool item tags required (not consumed, but must be available)
@export var tools: Array[String] = []

## Steps to execute in order (array of RecipeStep resources)
@export var steps: Array[RecipeStep] = []

## Output items produced when recipe completes (stored as array of dictionaries)
## Each dictionary has: item_tag (String), quantity (int)
@export var outputs: Array[Dictionary] = []

## Motive effects applied to agent on completion
## Keys are motive names (e.g., "hunger"), values are amounts to add
@export var motive_effects: Dictionary = {}

## Get inputs as RecipeInput objects
func get_inputs() -> Array[RecipeInput]:
    var result: Array[RecipeInput] = []
    for input_dict in inputs:
        result.append(RecipeInput.from_dict(input_dict))
    return result

## Get outputs as RecipeOutput objects
func get_outputs() -> Array[RecipeOutput]:
    var result: Array[RecipeOutput] = []
    for output_dict in outputs:
        result.append(RecipeOutput.from_dict(output_dict))
    return result

## Add an input requirement
func add_input(item_tag: String, quantity: int = 1, consumed: bool = true) -> void:
    var input := RecipeInput.new(item_tag, quantity, consumed)
    inputs.append(input.to_dict())

## Add an output product
func add_output(item_tag: String, quantity: int = 1) -> void:
    var output := RecipeOutput.new(item_tag, quantity)
    outputs.append(output.to_dict())

## Add a tool requirement
func add_tool(tool_tag: String) -> void:
    if not tools.has(tool_tag):
        tools.append(tool_tag)

## Add a step to the recipe
func add_step(step: RecipeStep) -> void:
    steps.append(step)

## Set a motive effect
func set_motive_effect(motive_name: String, amount: float) -> void:
    motive_effects[motive_name] = amount

## Get the total number of steps
func get_step_count() -> int:
    return steps.size()

## Get a specific step by index
func get_step(index: int) -> RecipeStep:
    if index >= 0 and index < steps.size():
        return steps[index]
    return null

## Check if this recipe has any inputs
func has_inputs() -> bool:
    return inputs.size() > 0

## Check if this recipe has any tools
func has_tools() -> bool:
    return tools.size() > 0

## Check if this recipe has any outputs
func has_outputs() -> bool:
    return outputs.size() > 0

## Check if this recipe affects a specific motive
func affects_motive(motive_name: String) -> bool:
    return motive_effects.has(motive_name)

## Get the motive effect amount for a specific motive
func get_motive_effect(motive_name: String) -> float:
    return motive_effects.get(motive_name, 0.0)

## Get all motive names this recipe affects
func get_affected_motives() -> Array[String]:
    var result: Array[String] = []
    for key in motive_effects.keys():
        result.append(key)
    return result

## Get all consumed input tags
func get_consumed_input_tags() -> Array[String]:
    var result: Array[String] = []
    for input_data in get_inputs():
        if input_data.consumed:
            result.append(input_data.item_tag)
    return result

## Get all non-consumed input tags (items that remain after recipe)
func get_preserved_input_tags() -> Array[String]:
    var result: Array[String] = []
    for input_data in get_inputs():
        if not input_data.consumed:
            result.append(input_data.item_tag)
    return result

## Calculate total duration of all steps
func get_total_duration() -> float:
    var total: float = 0.0
    for step in steps:
        total += step.duration
    return total

## Get all unique station tags required by this recipe
func get_required_stations() -> Array[String]:
    var stations: Array[String] = []
    for step in steps:
        if step.requires_station() and not stations.has(step.station_tag):
            stations.append(step.station_tag)
    return stations

## Debug print recipe information
func debug_print() -> void:
    print("=== Recipe: ", recipe_name, " ===")
    print("Inputs:")
    for input_data in get_inputs():
        print("  - ", input_data.quantity, "x ", input_data.item_tag,
              " (", "consumed" if input_data.consumed else "preserved", ")")
    if tools.size() > 0:
        print("Tools: ", tools)
    print("Steps:")
    for i in range(steps.size()):
        var step = steps[i]
        print("  ", i + 1, ". ", step.action, " at ", step.station_tag, " (", step.duration, "s)")
    print("Outputs:")
    for output_data in get_outputs():
        print("  - ", output_data.quantity, "x ", output_data.item_tag)
    if motive_effects.size() > 0:
        print("Motive Effects: ", motive_effects)
    print("Total Duration: ", get_total_duration(), "s")
