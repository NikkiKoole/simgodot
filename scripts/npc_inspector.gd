extends VBoxContainer
## NPC Inspector Panel - Shows detailed NPC information when one is selected.
## Displays: name/ID, state, current job, held item, motive bars with sliders
## Also provides quick action buttons for motive manipulation

# Reference to the currently inspected NPC
var current_npc: Node = null

# UI elements
@onready var name_label: Label = $NameLabel
@onready var state_label: Label = $StateLabel
@onready var job_label: Label = $JobLabel
@onready var held_item_label: Label = $HeldItemLabel
@onready var motives_container: VBoxContainer = $MotivesContainer
@onready var buttons_container: HBoxContainer = $ButtonsContainer
@onready var path_toggle_checkbox: CheckBox = $PathToggleContainer/PathToggleCheckBox

# Path visualization callback - set by DebugUI
var on_path_visibility_changed: Callable

# Motive slider references (created dynamically)
var motive_sliders: Dictionary = {}  # {motive_name: HSlider}

# Motive names we display (matches DebugCommands.VALID_MOTIVE_NAMES)
const MOTIVE_NAMES: Array[String] = ["hunger", "energy", "bladder", "hygiene", "fun"]

# Colors for motive bar backgrounds based on value
const MOTIVE_COLOR_CRITICAL := Color(0.8, 0.2, 0.2, 0.3)  # Red for low
const MOTIVE_COLOR_WARNING := Color(0.8, 0.6, 0.2, 0.3)   # Orange for medium-low
const MOTIVE_COLOR_GOOD := Color(0.2, 0.7, 0.2, 0.3)      # Green for high


func _ready() -> void:
	# Create motive sliders
	_create_motive_sliders()

	# Create quick action buttons
	_create_quick_buttons()

	# Connect path toggle checkbox
	if path_toggle_checkbox != null:
		path_toggle_checkbox.toggled.connect(_on_path_toggle_changed)

	# Hide initially until an NPC is selected
	visible = false


func _process(_delta: float) -> void:
	# Update display if we have an NPC selected
	if current_npc != null and is_instance_valid(current_npc):
		_update_display()


## Set the NPC to inspect
func set_npc(npc: Node) -> void:
	current_npc = npc

	if npc == null:
		visible = false
		return

	visible = true
	_update_display()
	_update_slider_values()


## Clear the inspector
func clear() -> void:
	current_npc = null
	visible = false


## Create motive slider controls
func _create_motive_sliders() -> void:
	for motive_name in MOTIVE_NAMES:
		var container := HBoxContainer.new()
		container.name = motive_name.capitalize() + "Row"

		# Label for motive name
		var label := Label.new()
		label.text = motive_name.capitalize() + ":"
		label.custom_minimum_size.x = 60
		container.add_child(label)

		# Slider for motive value
		var slider := HSlider.new()
		slider.name = motive_name + "_slider"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.x = 100
		slider.value_changed.connect(_on_motive_slider_changed.bind(motive_name))
		container.add_child(slider)

		# Value label
		var value_label := Label.new()
		value_label.name = motive_name + "_value"
		value_label.text = "50"
		value_label.custom_minimum_size.x = 30
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		container.add_child(value_label)

		motives_container.add_child(container)
		motive_sliders[motive_name] = slider


## Create quick action buttons
func _create_quick_buttons() -> void:
	var make_hungry_btn := Button.new()
	make_hungry_btn.text = "Make Hungry"
	make_hungry_btn.pressed.connect(_on_make_hungry_pressed)
	buttons_container.add_child(make_hungry_btn)

	var make_full_btn := Button.new()
	make_full_btn.text = "Make Full"
	make_full_btn.pressed.connect(_on_make_full_pressed)
	buttons_container.add_child(make_full_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Motives"
	reset_btn.pressed.connect(_on_reset_motives_pressed)
	buttons_container.add_child(reset_btn)


## Update the display with current NPC data
func _update_display() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	# Get inspection data from DebugCommands
	var data: Dictionary = DebugCommands.get_inspection_data(current_npc)

	# Update name/ID
	var npc_id: int = current_npc.npc_id if current_npc.get("npc_id") != null else 0
	name_label.text = "NPC " + str(npc_id)

	# Update state
	var state_name: String = data.get("state", "UNKNOWN")
	state_label.text = "State: " + state_name

	# Update job info
	var job_data: Dictionary = data.get("current_job", {})
	if job_data.is_empty():
		job_label.text = "Job: None"
	else:
		var recipe_name: String = job_data.get("recipe_name", "Unknown")
		var step_index: int = job_data.get("step_index", 0)
		var job_state: String = job_data.get("state", "UNKNOWN")
		job_label.text = "Job: " + recipe_name + " (Step " + str(step_index) + ", " + job_state + ")"

	# Update held item
	var held_item: String = data.get("held_item", "")
	if held_item.is_empty():
		held_item_label.text = "Held Item: Empty"
	else:
		held_item_label.text = "Held Item: " + held_item

	# Update motive value labels (not sliders - those update on user interaction)
	var motives_data: Dictionary = data.get("motives", {})
	for motive_name in MOTIVE_NAMES:
		# Get internal value (-100 to +100) and convert to 0-100 range
		var internal_value: float = motives_data.get(motive_name, 0.0)
		var display_value: float = (internal_value + 100.0) / 2.0

		# Update value label
		var value_label := motives_container.get_node_or_null(motive_name.capitalize() + "Row/" + motive_name + "_value")
		if value_label is Label:
			value_label.text = str(int(display_value))


## Update slider positions to match current motive values
func _update_slider_values() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	var data: Dictionary = DebugCommands.get_inspection_data(current_npc)
	var motives_data: Dictionary = data.get("motives", {})

	for motive_name in MOTIVE_NAMES:
		var slider: HSlider = motive_sliders.get(motive_name)
		if slider != null:
			# Get internal value (-100 to +100) and convert to 0-100 range
			var internal_value: float = motives_data.get(motive_name, 0.0)
			var display_value: float = (internal_value + 100.0) / 2.0

			# Temporarily disconnect signal to avoid feedback loop
			if slider.value_changed.is_connected(_on_motive_slider_changed):
				slider.value_changed.disconnect(_on_motive_slider_changed)

			slider.value = display_value

			# Reconnect signal
			slider.value_changed.connect(_on_motive_slider_changed.bind(motive_name))


## Handle motive slider value changes
func _on_motive_slider_changed(value: float, motive_name: String) -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	# Update motive via DebugCommands
	DebugCommands.set_npc_motive(current_npc, motive_name, value)

	# Update the value label
	var value_label := motives_container.get_node_or_null(motive_name.capitalize() + "Row/" + motive_name + "_value")
	if value_label is Label:
		value_label.text = str(int(value))


## Quick button: Make NPC hungry
func _on_make_hungry_pressed() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	DebugCommands.set_npc_motive(current_npc, "hunger", 10)
	_update_slider_values()


## Quick button: Make NPC full (satisfied hunger)
func _on_make_full_pressed() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	DebugCommands.set_npc_motive(current_npc, "hunger", 100)
	_update_slider_values()


## Quick button: Reset all motives to 100
func _on_reset_motives_pressed() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		return

	var full_motives: Dictionary = {
		"hunger": 100,
		"energy": 100,
		"bladder": 100,
		"hygiene": 100,
		"fun": 100
	}
	DebugCommands.set_npc_motives(current_npc, full_motives)
	_update_slider_values()


## Handle path visibility toggle
func _on_path_toggle_changed(is_visible: bool) -> void:
	if on_path_visibility_changed.is_valid():
		on_path_visibility_changed.call(is_visible)


## Get current path visibility state
func is_path_visible() -> bool:
	if path_toggle_checkbox != null:
		return path_toggle_checkbox.button_pressed
	return true


## Set path visibility state (used when switching NPCs)
func set_path_visible(is_visible: bool) -> void:
	if path_toggle_checkbox != null:
		path_toggle_checkbox.button_pressed = is_visible
