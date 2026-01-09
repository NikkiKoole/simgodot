extends VBoxContainer
## Scenario Tool - UI for saving and loading test scenarios
## Provides save/load buttons with file dialogs, quick-save slots, and clear functionality.
## All operations go through the DebugCommands API.

# Default scenario save directory
const SCENARIO_DIR := "user://scenarios/"

# Quick save slot paths
const QUICK_SAVE_SLOTS: Array[String] = [
	"user://scenarios/quicksave_1.json",
	"user://scenarios/quicksave_2.json",
	"user://scenarios/quicksave_3.json"
]

# UI element references
@onready var save_button: Button = $ButtonsContainer/SaveButton
@onready var load_button: Button = $ButtonsContainer/LoadButton
@onready var clear_button: Button = $ClearButton
@onready var quick_save_container: HBoxContainer = $QuickSaveContainer
@onready var quick_load_container: HBoxContainer = $QuickLoadContainer
@onready var status_label: Label = $StatusLabel

# File dialog (created on demand)
var file_dialog: FileDialog = null
var is_save_dialog: bool = false


func _ready() -> void:
	# Connect button signals
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)
	clear_button.pressed.connect(_on_clear_pressed)

	# Set up quick save buttons
	_setup_quick_save_buttons()

	# Set up quick load buttons
	_setup_quick_load_buttons()

	# Clear status initially
	status_label.text = ""


func _setup_quick_save_buttons() -> void:
	for i in range(3):
		var button: Button = quick_save_container.get_node("Save" + str(i + 1))
		if button != null:
			button.pressed.connect(_on_quick_save_pressed.bind(i))


func _setup_quick_load_buttons() -> void:
	for i in range(3):
		var button: Button = quick_load_container.get_node("Load" + str(i + 1))
		if button != null:
			button.pressed.connect(_on_quick_load_pressed.bind(i))


func _on_save_pressed() -> void:
	_show_file_dialog(true)


func _on_load_pressed() -> void:
	_show_file_dialog(false)


func _on_clear_pressed() -> void:
	DebugCommands.clear_scenario()
	_show_status("Cleared all runtime entities", true)


func _on_quick_save_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= QUICK_SAVE_SLOTS.size():
		return

	var path: String = QUICK_SAVE_SLOTS[slot_index]
	var success: bool = DebugCommands.save_scenario(path)

	if success:
		_show_status("Saved to Slot " + str(slot_index + 1), true)
	else:
		_show_status("Failed to save to Slot " + str(slot_index + 1), false)


func _on_quick_load_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= QUICK_SAVE_SLOTS.size():
		return

	var path: String = QUICK_SAVE_SLOTS[slot_index]

	# Check if file exists
	if not FileAccess.file_exists(path):
		_show_status("Slot " + str(slot_index + 1) + " is empty", false)
		return

	var success: bool = DebugCommands.load_scenario(path, true)

	if success:
		_show_status("Loaded from Slot " + str(slot_index + 1), true)
	else:
		_show_status("Failed to load from Slot " + str(slot_index + 1), false)


func _show_file_dialog(is_save: bool) -> void:
	is_save_dialog = is_save

	# Create file dialog if needed
	if file_dialog == null:
		file_dialog = FileDialog.new()
		file_dialog.access = FileDialog.ACCESS_USERDATA
		file_dialog.add_filter("*.json", "Scenario Files")
		file_dialog.file_selected.connect(_on_file_selected)
		file_dialog.canceled.connect(_on_dialog_canceled)
		add_child(file_dialog)

	# Configure for save or load
	if is_save:
		file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		file_dialog.title = "Save Scenario"
		file_dialog.current_file = "scenario.json"
	else:
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.title = "Load Scenario"
		file_dialog.current_file = ""

	# Set current directory
	file_dialog.current_dir = SCENARIO_DIR

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(SCENARIO_DIR)

	# Show the dialog
	file_dialog.popup_centered(Vector2i(600, 400))


func _on_file_selected(path: String) -> void:
	if is_save_dialog:
		# Ensure .json extension
		if not path.ends_with(".json"):
			path += ".json"

		var success: bool = DebugCommands.save_scenario(path)
		if success:
			_show_status("Saved: " + path.get_file(), true)
		else:
			_show_status("Failed to save scenario", false)
	else:
		var success: bool = DebugCommands.load_scenario(path, true)
		if success:
			_show_status("Loaded: " + path.get_file(), true)
		else:
			_show_status("Failed to load scenario", false)


func _on_dialog_canceled() -> void:
	# Do nothing on cancel
	pass


func _show_status(message: String, is_success: bool) -> void:
	status_label.text = message
	if is_success:
		status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
