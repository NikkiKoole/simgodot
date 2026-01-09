class_name Job
extends RefCounted

## Represents a work task that an agent can claim and execute
## Jobs track state, progress through recipe steps, and collected items

## Possible states a job can be in
enum JobState {
	POSTED,      ## Available for agents to claim
	CLAIMED,     ## Reserved by an agent but not yet started
	IN_PROGRESS, ## Agent is actively working on this job
	INTERRUPTED, ## Paused mid-execution, can be resumed
	COMPLETED,   ## Successfully finished
	FAILED       ## Could not be completed
}

## Unique identifier for this job instance
var job_id: String = ""

## The recipe this job executes
var recipe: Recipe = null

## Priority level (higher = more urgent)
var priority: int = 0

## Reference to the agent that has claimed this job (null if unclaimed)
var claimed_by: Node = null

## Current state of the job
var state: JobState = JobState.POSTED

## Index of the current step in the recipe (0-based)
var current_step_index: int = 0

## Items the agent has gathered for this job
var gathered_items: Array[ItemEntity] = []

## Reference to the station where work is being performed
var target_station: Station = null

## Signals for state changes
signal state_changed(new_state: JobState)
signal step_advanced(step_index: int)
signal item_gathered(item: ItemEntity)
signal job_completed()
signal job_failed(reason: String)

## Counter for generating unique IDs (combined with timestamp for scene-reload safety)
static var _next_id: int = 0
static var _session_id: int = 0

func _init(p_recipe: Recipe = null, p_priority: int = 0) -> void:
	recipe = p_recipe
	priority = p_priority
	job_id = _generate_id()

## Generate a unique job ID using timestamp + counter for uniqueness across scene reloads
static func _generate_id() -> String:
	# Initialize session ID once per game session using current time
	if _session_id == 0:
		_session_id = Time.get_ticks_usec()
	_next_id += 1
	return "job_%d_%d" % [_session_id, _next_id]

## Claim this job for an agent
## Returns true if claim successful, false if already claimed by another agent
func claim(agent: Node) -> bool:
	# If already claimed by this agent, allow re-claim
	if claimed_by == agent:
		return true
	# Cannot claim if claimed by another agent
	if claimed_by != null:
		return false
	# Can only claim from POSTED or INTERRUPTED state
	if state != JobState.POSTED and state != JobState.INTERRUPTED:
		return false
	claimed_by = agent
	set_state(JobState.CLAIMED)
	return true

## Release claim on this job, returning it to POSTED state
func release() -> void:
	# Release item reservations
	for item in gathered_items:
		if item != null and is_instance_valid(item):
			item.release_item()
	# Release station reservation if we have one
	if target_station != null and target_station.is_reserved_by(claimed_by):
		target_station.release()
	claimed_by = null
	target_station = null
	set_state(JobState.POSTED)

## Start working on this job
func start() -> bool:
	if state != JobState.CLAIMED:
		return false
	set_state(JobState.IN_PROGRESS)
	return true

## Interrupt this job (pause mid-execution)
func interrupt() -> void:
	if state == JobState.IN_PROGRESS:
		set_state(JobState.INTERRUPTED)
		# Release station reservation if we have one
		if target_station != null and target_station.is_reserved_by(claimed_by):
			target_station.release()
		# Release item reservations
		for item in gathered_items:
			if item != null and is_instance_valid(item):
				item.release_item()
		claimed_by = null

## Complete this job successfully
func complete() -> void:
	# Release item reservations (items may be consumed or remain)
	for item in gathered_items:
		if item != null and is_instance_valid(item):
			item.release_item()
	# Release station reservation if we have one
	if target_station != null and target_station.is_reserved_by(claimed_by):
		target_station.release()
	set_state(JobState.COMPLETED)
	job_completed.emit()

## Mark this job as failed
func fail(reason: String = "") -> void:
	# Release item reservations
	for item in gathered_items:
		if item != null and is_instance_valid(item):
			item.release_item()
	# Release station reservation if we have one
	if target_station != null and target_station.is_reserved_by(claimed_by):
		target_station.release()
	set_state(JobState.FAILED)
	job_failed.emit(reason)

## Set the job state and emit signal
func set_state(new_state: JobState) -> void:
	if state != new_state:
		state = new_state
		state_changed.emit(new_state)

## Advance to the next recipe step
## Returns true if there are more steps, false if recipe is complete
func advance_step() -> bool:
	current_step_index += 1
	step_advanced.emit(current_step_index)
	return current_step_index < get_total_steps()

## Get the current recipe step
func get_current_step() -> RecipeStep:
	if recipe == null:
		return null
	return recipe.get_step(current_step_index)

## Get total number of steps in the recipe
func get_total_steps() -> int:
	if recipe == null:
		return 0
	return recipe.get_step_count()

## Check if all steps have been completed
func is_all_steps_complete() -> bool:
	return current_step_index >= get_total_steps()

## Add a gathered item to the job
func add_gathered_item(item: ItemEntity) -> void:
	if item != null and not gathered_items.has(item):
		gathered_items.append(item)
		item_gathered.emit(item)

## Remove a gathered item from the job
func remove_gathered_item(item: ItemEntity) -> bool:
	var idx := gathered_items.find(item)
	if idx >= 0:
		gathered_items.remove_at(idx)
		return true
	return false

## Clear all gathered items
func clear_gathered_items() -> void:
	gathered_items.clear()

## Check if this job is claimable (POSTED or INTERRUPTED)
func is_claimable() -> bool:
	return state == JobState.POSTED or state == JobState.INTERRUPTED

## Check if this job is active (CLAIMED or IN_PROGRESS)
func is_active() -> bool:
	return state == JobState.CLAIMED or state == JobState.IN_PROGRESS

## Check if this job is finished (COMPLETED or FAILED)
func is_finished() -> bool:
	return state == JobState.COMPLETED or state == JobState.FAILED

## Get remaining steps count
func get_remaining_steps() -> int:
	return max(0, get_total_steps() - current_step_index)

## Get progress as a percentage (0.0 to 1.0)
func get_progress() -> float:
	var total := get_total_steps()
	if total == 0:
		return 1.0
	return float(current_step_index) / float(total)

## Get human-readable state name
static func get_state_name(job_state: JobState) -> String:
	match job_state:
		JobState.POSTED: return "Posted"
		JobState.CLAIMED: return "Claimed"
		JobState.IN_PROGRESS: return "In Progress"
		JobState.INTERRUPTED: return "Interrupted"
		JobState.COMPLETED: return "Completed"
		JobState.FAILED: return "Failed"
		_: return "Unknown"

## Debug print job information
func debug_print() -> void:
	print("=== Job: ", job_id, " ===")
	print("  Recipe: ", recipe.recipe_name if recipe else "None")
	print("  Priority: ", priority)
	print("  State: ", get_state_name(state))
	print("  Claimed by: ", claimed_by if claimed_by else "None")
	print("  Current step: ", current_step_index, "/", get_total_steps())
	print("  Gathered items: ", gathered_items.size())
	print("  Target station: ", target_station.station_tag if target_station else "None")
