extends CanvasLayer
## Debug UI - Visual interface for debug and testing tools.
## This UI is always visible and provides access to entity inspection and spawn tools.
## The UI panels are positioned to avoid blocking the main game viewport.

# References to UI sections for child scripts to access
@onready var inspector_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/InspectorSection
@onready var tools_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/ToolsSection
@onready var bottom_bar: PanelContainer = $BottomBar
@onready var job_status_label: Label = $BottomBar/MarginContainer/HBoxContainer/JobStatusLabel


func _ready() -> void:
    # Connect to DebugCommands signals for future inspector updates
    if DebugCommands:
        DebugCommands.entity_selected.connect(_on_entity_selected)
        DebugCommands.entity_deselected.connect(_on_entity_deselected)

    # Connect to JobBoard for status updates
    if JobBoard:
        JobBoard.job_posted.connect(_on_job_changed)
        JobBoard.job_claimed.connect(_on_job_changed)
        JobBoard.job_completed.connect(_on_job_changed)
        JobBoard.job_released.connect(_on_job_changed)
        JobBoard.job_failed.connect(_on_job_changed)

    _update_job_status()


func _on_entity_selected(_entity: Node) -> void:
    # Future: Update inspector panel based on entity type
    pass


func _on_entity_deselected() -> void:
    # Future: Clear inspector panel
    pass


func _on_job_changed(_job) -> void:
    _update_job_status()


func _update_job_status() -> void:
    if not JobBoard:
        return

    var all_jobs: Array = DebugCommands.get_all_jobs() if DebugCommands else []

    var posted := 0
    var claimed := 0
    var in_progress := 0
    var completed := 0
    var interrupted := 0
    var failed := 0

    for job in all_jobs:
        match job.state:
            Job.JobState.POSTED:
                posted += 1
            Job.JobState.CLAIMED:
                claimed += 1
            Job.JobState.IN_PROGRESS:
                in_progress += 1
            Job.JobState.COMPLETED:
                completed += 1
            Job.JobState.INTERRUPTED:
                interrupted += 1
            Job.JobState.FAILED:
                failed += 1

    job_status_label.text = "Jobs: %d Posted | %d Claimed | %d In Progress | %d Completed" % [
        posted, claimed, in_progress, completed
    ]
