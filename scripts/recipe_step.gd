class_name RecipeStep
extends Resource

## Defines a single step within a recipe interaction sequence
## Each step occurs at a specific station with an action and duration

## The type of station required for this step (e.g., "counter", "stove", "toilet")
@export var station_tag: String = ""

## The action to perform at the station (e.g., "prep", "cook", "sit")
@export var action: String = ""

## How long this step takes in seconds
@export var duration: float = 1.0

## Animation to play during this step (empty = no specific animation)
@export var animation: String = ""

## Item state transformations applied when this step completes
## Dictionary mapping input item tags to output states/tags
## e.g., {"raw_meat": "cooked_meat"} or {"raw_food": "prepped_food"}
@export var input_transform: Dictionary = {}


## Check if this step requires a specific station type
func requires_station() -> bool:
	return not station_tag.is_empty()


## Get the transformed item tag for a given input
## Returns the original tag if no transform is defined
func get_transformed_tag(original_tag: String) -> String:
	if input_transform.has(original_tag):
		return input_transform[original_tag]
	return original_tag


## Check if this step transforms a specific item
func transforms_item(item_tag: String) -> bool:
	return input_transform.has(item_tag)


## Get all input item tags that this step transforms
func get_transform_inputs() -> Array[String]:
	var inputs: Array[String] = []
	for key in input_transform.keys():
		inputs.append(key)
	return inputs


## Get all output item tags that this step produces
func get_transform_outputs() -> Array[String]:
	var outputs: Array[String] = []
	for value in input_transform.values():
		outputs.append(value)
	return outputs


## Debug print step information
func debug_print() -> void:
	print("=== RecipeStep ===")
	print("  Station: ", station_tag if not station_tag.is_empty() else "(none)")
	print("  Action: ", action)
	print("  Duration: ", duration, "s")
	print("  Animation: ", animation if not animation.is_empty() else "(none)")
	if not input_transform.is_empty():
		print("  Transforms:")
		for input_tag in input_transform:
			print("    ", input_tag, " -> ", input_transform[input_tag])
