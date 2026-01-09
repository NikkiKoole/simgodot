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
func claim_job(job: Job, agent: Node) -> bool:
	if job == null or agent == null:
		return false

	if not jobs.has(job):
		return false

	var claimed := job.claim(agent)
	if claimed:
		job_claimed.emit(job, agent)
	return claimed

## Release a job, returning it to POSTED state
func release_job(job: Job) -> void:
	if job == null:
		return

	if not jobs.has(job):
		return

	job.release()
	job_released.emit(job)

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
