extends PanelContainer
## Job Panel - Expandable job list panel for the debug UI.
## Shows job counts in the status bar and expands to show full job list.

## References to UI elements
@onready var status_bar: HBoxContainer = $VBoxContainer/StatusBar
@onready var job_list_container: VBoxContainer = $VBoxContainer/JobListContainer
@onready var job_list: VBoxContainer = $VBoxContainer/JobListContainer/ScrollContainer/JobList

## Status labels for job counts
@onready var posted_label: Label = $VBoxContainer/StatusBar/PostedLabel
@onready var claimed_label: Label = $VBoxContainer/StatusBar/ClaimedLabel
@onready var in_progress_label: Label = $VBoxContainer/StatusBar/InProgressLabel
@onready var interrupted_label: Label = $VBoxContainer/StatusBar/InterruptedLabel
@onready var completed_label: Label = $VBoxContainer/StatusBar/CompletedLabel
@onready var failed_label: Label = $VBoxContainer/StatusBar/FailedLabel
@onready var expand_button: Button = $VBoxContainer/StatusBar/ExpandButton

## Track expanded state
var is_expanded := false

## Height of status bar only (collapsed)
const COLLAPSED_HEIGHT := 40
## Height when expanded (showing job list)
const EXPANDED_HEIGHT := 250


func _ready() -> void:
	# Start collapsed
	_set_expanded(false)

	# Connect to JobBoard signals for real-time updates
	if JobBoard:
		JobBoard.job_posted.connect(_on_job_changed)
		JobBoard.job_claimed.connect(_on_job_changed_with_agent)
		JobBoard.job_completed.connect(_on_job_changed)
		JobBoard.job_released.connect(_on_job_changed)
		JobBoard.job_failed.connect(_on_job_failed)
		JobBoard.job_interrupted.connect(_on_job_changed)

	# Connect expand button
	expand_button.pressed.connect(_on_expand_pressed)

	# Initial update
	_update_job_counts()
	_update_job_list()


func _on_job_changed(_job: Job) -> void:
	_update_job_counts()
	_update_job_list()


func _on_job_changed_with_agent(_job: Job, _agent: Node) -> void:
	_update_job_counts()
	_update_job_list()


func _on_job_failed(_job: Job, _reason: String) -> void:
	_update_job_counts()
	_update_job_list()


func _on_expand_pressed() -> void:
	_set_expanded(!is_expanded)


func _set_expanded(expanded: bool) -> void:
	is_expanded = expanded
	job_list_container.visible = expanded
	expand_button.text = "▼" if expanded else "▲"

	# Update custom minimum size
	custom_minimum_size.y = EXPANDED_HEIGHT if expanded else COLLAPSED_HEIGHT


func _update_job_counts() -> void:
	if not JobBoard:
		return

	var all_jobs: Array = DebugCommands.get_all_jobs() if DebugCommands else []

	var counts := {
		Job.JobState.POSTED: 0,
		Job.JobState.CLAIMED: 0,
		Job.JobState.IN_PROGRESS: 0,
		Job.JobState.INTERRUPTED: 0,
		Job.JobState.COMPLETED: 0,
		Job.JobState.FAILED: 0
	}

	for job in all_jobs:
		if counts.has(job.state):
			counts[job.state] += 1

	posted_label.text = "Posted: %d" % counts[Job.JobState.POSTED]
	claimed_label.text = "Claimed: %d" % counts[Job.JobState.CLAIMED]
	in_progress_label.text = "In Progress: %d" % counts[Job.JobState.IN_PROGRESS]
	interrupted_label.text = "Interrupted: %d" % counts[Job.JobState.INTERRUPTED]
	completed_label.text = "Completed: %d" % counts[Job.JobState.COMPLETED]
	failed_label.text = "Failed: %d" % counts[Job.JobState.FAILED]


func _update_job_list() -> void:
	if not is_instance_valid(job_list):
		return

	# Clear existing job rows
	for child in job_list.get_children():
		child.queue_free()

	if not JobBoard:
		return

	var all_jobs: Array = DebugCommands.get_all_jobs() if DebugCommands else []

	if all_jobs.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No jobs"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		job_list.add_child(empty_label)
		return

	# Add row for each job
	for job in all_jobs:
		var row := _create_job_row(job)
		job_list.add_child(row)


func _create_job_row(job: Job) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Recipe name
	var recipe_name := Label.new()
	recipe_name.text = job.recipe.recipe_name if job.recipe else "Unknown"
	recipe_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_name.custom_minimum_size.x = 100
	row.add_child(recipe_name)

	# State label with color coding
	var state_label := Label.new()
	state_label.text = Job.get_state_name(job.state)
	state_label.custom_minimum_size.x = 80
	state_label.add_theme_color_override("font_color", _get_state_color(job.state))
	row.add_child(state_label)

	# Assigned NPC
	var npc_button := Button.new()
	if job.claimed_by != null and is_instance_valid(job.claimed_by):
		npc_button.text = job.claimed_by.name
		npc_button.pressed.connect(_on_npc_button_pressed.bind(job.claimed_by))
		npc_button.tooltip_text = "Click to select this NPC"
	else:
		npc_button.text = "-"
		npc_button.disabled = true
	npc_button.custom_minimum_size.x = 60
	row.add_child(npc_button)

	# Current step
	var step_label := Label.new()
	step_label.text = "Step %d/%d" % [job.current_step_index + 1, job.get_total_steps()]
	step_label.custom_minimum_size.x = 60
	row.add_child(step_label)

	# Interrupt button (only for IN_PROGRESS jobs)
	var interrupt_button := Button.new()
	interrupt_button.text = "Interrupt"
	interrupt_button.custom_minimum_size.x = 70
	if job.state == Job.JobState.IN_PROGRESS:
		interrupt_button.pressed.connect(_on_interrupt_pressed.bind(job))
	else:
		interrupt_button.disabled = true
	row.add_child(interrupt_button)

	return row


func _get_state_color(state: Job.JobState) -> Color:
	match state:
		Job.JobState.POSTED:
			return Color(0.7, 0.7, 1.0)  # Light blue
		Job.JobState.CLAIMED:
			return Color(1.0, 1.0, 0.7)  # Light yellow
		Job.JobState.IN_PROGRESS:
			return Color(0.7, 1.0, 0.7)  # Light green
		Job.JobState.INTERRUPTED:
			return Color(1.0, 0.8, 0.5)  # Orange
		Job.JobState.COMPLETED:
			return Color(0.5, 1.0, 0.5)  # Green
		Job.JobState.FAILED:
			return Color(1.0, 0.5, 0.5)  # Red
		_:
			return Color(1.0, 1.0, 1.0)  # White


func _on_npc_button_pressed(npc: Node) -> void:
	if npc != null and is_instance_valid(npc) and DebugCommands:
		DebugCommands.select_entity(npc)


func _on_interrupt_pressed(job: Job) -> void:
	if job != null and DebugCommands:
		DebugCommands.interrupt_job(job)
		_update_job_counts()
		_update_job_list()
