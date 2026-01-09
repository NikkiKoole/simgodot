extends Node
## Central singleton for global job management
## Handles posting, querying, claiming, and releasing jobs

## All jobs currently in the system
var jobs: Array[Job] = []

## Signals for job lifecycle events
signal job_posted(job: Job)
signal job_claimed(job: Job, agent: Node)
signal job_completed(job: Job)
signal job_released(job: Job)
signal job_failed(job: Job, reason: String)
signal job_interrupted(job: Job)

func _ready() -> void:
	pass

## Post a new job based on a recipe
## Returns the created Job instance
func post_job(recipe: Recipe, priority: int = 0) -> Job:
	var job := Job.new(recipe, priority)
	jobs.append(job)

	# Connect to job signals for lifecycle tracking
	job.job_completed.connect(_on_job_completed.bind(job))
	job.job_failed.connect(_on_job_failed.bind(job))

	job_posted.emit(job)
	return job

## Get all available (unclaimed) jobs
## Returns jobs in POSTED or INTERRUPTED state
func get_available_jobs() -> Array[Job]:
	var available: Array[Job] = []
	for job in jobs:
		if job.is_claimable():
			available.append(job)
	return available

## Get jobs that affect a specific motive
## Useful for agents seeking to fulfill needs
func get_jobs_for_motive(motive_name: String) -> Array[Job]:
	var matching: Array[Job] = []
	for job in jobs:
		if job.recipe != null and job.recipe.affects_motive(motive_name):
			matching.append(job)
	return matching

## Get available jobs that affect a specific motive
func get_available_jobs_for_motive(motive_name: String) -> Array[Job]:
	var matching: Array[Job] = []
	for job in jobs:
		if job.is_claimable() and job.recipe != null and job.recipe.affects_motive(motive_name):
			matching.append(job)
	return matching

## Claim a job for an agent
## Returns true if claim successful, false otherwise
## If containers are provided, also reserves all required items
func claim_job(job: Job, agent: Node, containers: Array = []) -> bool:
	if job == null or agent == null:
		return false

	if not jobs.has(job):
		return false

	var claimed := job.claim(agent)
	if claimed:
		# Reserve required items from containers
		if containers.size() > 0 and job.recipe != null:
			_reserve_items_for_job(job, agent, containers)
		job_claimed.emit(job, agent)
	return claimed

## Reserve all required items for a job from available containers
func _reserve_items_for_job(job: Job, agent: Node, containers: Array) -> void:
	var recipe: Recipe = job.recipe

	# Reserve input items
	for input_data in recipe.get_inputs():
		var tag: String = input_data.item_tag
		var quantity_needed: int = input_data.quantity
		var quantity_reserved: int = 0

		for container in containers:
			if container is ItemContainer:
				var available_items: Array[ItemEntity] = container.get_available_items_by_tag(tag)
				for item in available_items:
					if quantity_reserved >= quantity_needed:
						break
					if item.reserve_item(agent):
						job.add_gathered_item(item)
						quantity_reserved += 1
				if quantity_reserved >= quantity_needed:
					break

	# Reserve tools
	for tool_tag in recipe.tools:
		for container in containers:
			if container is ItemContainer:
				var available_items: Array[ItemEntity] = container.get_available_items_by_tag(tool_tag)
				if available_items.size() > 0:
					var tool_item: ItemEntity = available_items[0]
					if tool_item.reserve_item(agent):
						job.add_gathered_item(tool_item)
					break

## Release a job, returning it to POSTED state
func release_job(job: Job) -> void:
	if job == null:
		return

	if not jobs.has(job):
		return

	job.release()
	job_released.emit(job)

## Interrupt a job, preserving progress for later resumption
## Returns true if job was interrupted, false if not interruptible
func interrupt_job(job: Job) -> bool:
	if job == null:
		return false

	if not jobs.has(job):
		return false

	# Can only interrupt jobs that are IN_PROGRESS
	if job.state != Job.JobState.IN_PROGRESS:
		return false

	job.interrupt()
	job_interrupted.emit(job)
	return true

## Get a job by its ID
func get_job_by_id(job_id: String) -> Job:
	for job in jobs:
		if job.job_id == job_id:
			return job
	return null

## Get all jobs with a specific state
func get_jobs_by_state(state: Job.JobState) -> Array[Job]:
	var matching: Array[Job] = []
	for job in jobs:
		if job.state == state:
			matching.append(job)
	return matching

## Get all active jobs (CLAIMED or IN_PROGRESS)
func get_active_jobs() -> Array[Job]:
	var active: Array[Job] = []
	for job in jobs:
		if job.is_active():
			active.append(job)
	return active

## Get all completed jobs
func get_completed_jobs() -> Array[Job]:
	return get_jobs_by_state(Job.JobState.COMPLETED)

## Get all failed jobs
func get_failed_jobs() -> Array[Job]:
	return get_jobs_by_state(Job.JobState.FAILED)

## Get jobs claimed by a specific agent
func get_jobs_for_agent(agent: Node) -> Array[Job]:
	var agent_jobs: Array[Job] = []
	for job in jobs:
		if job.claimed_by == agent:
			agent_jobs.append(job)
	return agent_jobs

## Remove a job from the board (typically after completion/failure)
func remove_job(job: Job) -> bool:
	var index := jobs.find(job)
	if index == -1:
		return false

	# Disconnect signals
	if job.job_completed.is_connected(_on_job_completed):
		job.job_completed.disconnect(_on_job_completed)
	if job.job_failed.is_connected(_on_job_failed):
		job.job_failed.disconnect(_on_job_failed)

	jobs.remove_at(index)
	return true

## Remove all completed and failed jobs
func cleanup_finished_jobs() -> int:
	var removed := 0
	var to_remove: Array[Job] = []

	for job in jobs:
		if job.is_finished():
			to_remove.append(job)

	for job in to_remove:
		if remove_job(job):
			removed += 1

	return removed

## Clear all jobs from the board
func clear_all_jobs() -> void:
	for job in jobs:
		if job.job_completed.is_connected(_on_job_completed):
			job.job_completed.disconnect(_on_job_completed)
		if job.job_failed.is_connected(_on_job_failed):
			job.job_failed.disconnect(_on_job_failed)
	jobs.clear()

## Get total number of jobs
func get_job_count() -> int:
	return jobs.size()

## Get count of jobs by state
func get_job_count_by_state(state: Job.JobState) -> int:
	var count := 0
	for job in jobs:
		if job.state == state:
			count += 1
	return count

## Check if any jobs are available
func has_available_jobs() -> bool:
	for job in jobs:
		if job.is_claimable():
			return true
	return false

## Check if any jobs are available for a specific motive
func has_available_jobs_for_motive(motive_name: String) -> bool:
	for job in jobs:
		if job.is_claimable() and job.recipe != null and job.recipe.affects_motive(motive_name):
			return true
	return false

## Get the highest priority available job
func get_highest_priority_job() -> Job:
	var best_job: Job = null
	var best_priority: int = -1

	for job in jobs:
		if job.is_claimable() and job.priority > best_priority:
			best_job = job
			best_priority = job.priority

	return best_job

## Get the highest priority available job for a motive
func get_highest_priority_job_for_motive(motive_name: String) -> Job:
	var best_job: Job = null
	var best_priority: int = -1

	for job in jobs:
		if job.is_claimable() and job.recipe != null and job.recipe.affects_motive(motive_name):
			if job.priority > best_priority:
				best_job = job
				best_priority = job.priority

	return best_job

## Signal handlers
func _on_job_completed(job: Job) -> void:
	job_completed.emit(job)

func _on_job_failed(reason: String, job: Job) -> void:
	job_failed.emit(job, reason)

## Result class for can_start_job validation
class JobRequirementResult:
	var can_start: bool = false
	var reason: String = ""
	var missing_items: Array[Dictionary] = []  # {item_tag, quantity_needed, quantity_found}
	var missing_stations: Array[String] = []
	var missing_tools: Array[String] = []

	func _init(p_can_start: bool = false, p_reason: String = "") -> void:
		can_start = p_can_start
		reason = p_reason


## Check if a job can be started given available containers and stations
## Returns JobRequirementResult with validation details
func can_start_job(job: Job, containers: Array, stations: Array) -> JobRequirementResult:
	if job == null:
		return JobRequirementResult.new(false, "Job is null")

	if job.recipe == null:
		return JobRequirementResult.new(false, "Job has no recipe")

	var result := JobRequirementResult.new(true, "")
	var recipe: Recipe = job.recipe

	# Check required items in containers
	for input_data in recipe.get_inputs():
		var tag: String = input_data.item_tag
		var quantity_needed: int = input_data.quantity
		var quantity_found: int = 0

		# Count available items across all containers
		for container in containers:
			if container is ItemContainer:
				quantity_found += container.get_available_count(tag)

		if quantity_found < quantity_needed:
			result.can_start = false
			result.missing_items.append({
				"item_tag": tag,
				"quantity_needed": quantity_needed,
				"quantity_found": quantity_found
			})

	# Check required tools in containers
	for tool_tag in recipe.tools:
		var tool_found := false

		for container in containers:
			if container is ItemContainer:
				if container.has_available_item(tool_tag):
					tool_found = true
					break

		if not tool_found:
			result.can_start = false
			result.missing_tools.append(tool_tag)

	# Check required stations are available
	var required_stations: Array[String] = recipe.get_required_stations()
	for station_tag in required_stations:
		var station_available := false

		for station in stations:
			if station is Station:
				if station.station_tag == station_tag and station.is_available():
					station_available = true
					break

		if not station_available:
			result.can_start = false
			result.missing_stations.append(station_tag)

	# Build reason string if cannot start
	if not result.can_start:
		var reasons: Array[String] = []

		if result.missing_items.size() > 0:
			var item_strs: Array[String] = []
			for item in result.missing_items:
				item_strs.append("%s (need %d, found %d)" % [
					item.item_tag, item.quantity_needed, item.quantity_found
				])
			reasons.append("Missing items: " + ", ".join(item_strs))

		if result.missing_tools.size() > 0:
			reasons.append("Missing tools: " + ", ".join(result.missing_tools))

		if result.missing_stations.size() > 0:
			reasons.append("Unavailable stations: " + ", ".join(result.missing_stations))

		result.reason = "; ".join(reasons)

	return result


## Debug print all jobs
func debug_print() -> void:
	print("=== JobBoard ===")
	print("Total jobs: ", jobs.size())
	print("Available: ", get_available_jobs().size())
	print("Active: ", get_active_jobs().size())
	print("Completed: ", get_completed_jobs().size())
	print("Failed: ", get_failed_jobs().size())
	print("")
	for job in jobs:
		job.debug_print()
