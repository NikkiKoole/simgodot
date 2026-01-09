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

## Explicit item state changes for transformed items
## Dictionary mapping output item tags to ItemEntity.ItemState values
## e.g., {"cooked_meal": 2} where 2 = ItemState.COOKED
## If not specified, state is inferred from tag patterns (prepped, cooked, etc.)
@export var output_states: Dictionary = {}


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


## Get the explicit output state for a transformed item, or -1 if not specified
## Falls back to inferring state from tag patterns if not explicitly set
func get_output_state(output_tag: String) -> int:
	if output_states.has(output_tag):
		return output_states[output_tag]
	# Fallback: infer from tag patterns
	return _infer_state_from_tag(output_tag)


## Infer ItemState from tag name patterns
## Returns -1 if no pattern matches (caller should preserve existing state)
func _infer_state_from_tag(tag: String) -> int:
	var lower_tag := tag.to_lower()
	if lower_tag.contains("cooked") or lower_tag.ends_with("_cooked"):
		return 2  # ItemState.COOKED
	elif lower_tag.contains("prepped") or lower_tag.ends_with("_prepped") or lower_tag.contains("prep_"):
		return 1  # ItemState.PREPPED
	elif lower_tag.contains("dirty") or lower_tag.ends_with("_dirty"):
		return 3  # ItemState.DIRTY
	elif lower_tag.contains("broken") or lower_tag.ends_with("_broken"):
		return 4  # ItemState.BROKEN
	elif lower_tag.contains("raw") or lower_tag.ends_with("_raw"):
		return 0  # ItemState.RAW
	return -1  # No pattern matched


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
