extends VBoxContainer
## Station Inspector Panel - Shows detailed Station information when one is selected.
## Displays: name, tags, slot contents, current user, capacity
## Also provides tag editing functionality and slot visualization toggle

# Reference to the currently inspected Station
var current_station: Station = null

# UI elements
@onready var name_label: Label = $NameLabel
@onready var tags_label: Label = $TagsLabel
@onready var tags_container: HBoxContainer = $TagsContainer
@onready var tag_input: LineEdit = $TagInputRow/TagInput
@onready var add_tag_button: Button = $TagInputRow/AddTagButton
@onready var suggestions_container: HBoxContainer = $SuggestionsScroll/SuggestionsContainer
@onready var current_user_label: Label = $CurrentUserLabel
@onready var capacity_label: Label = $CapacityLabel
@onready var input_slots_container: VBoxContainer = $InputSlotsContainer
@onready var output_slots_container: VBoxContainer = $OutputSlotsContainer
@onready var slots_toggle_checkbox: CheckBox = $SlotsToggleContainer/SlotsToggleCheckBox

# Slot visualization callback - set by DebugUI
var on_slots_visibility_changed: Callable

# Common tag suggestions
const TAG_SUGGESTIONS: Array[String] = ["counter", "stove", "sink", "seating", "fridge", "toilet", "tv", "cooking", "prep", "storage"]


func _ready() -> void:
	# Set up add tag button
	add_tag_button.pressed.connect(_on_add_tag_pressed)
	tag_input.text_submitted.connect(_on_tag_input_submitted)

	# Create suggestion buttons
	_create_suggestion_buttons()

	# Connect slots toggle checkbox
	if slots_toggle_checkbox != null:
		slots_toggle_checkbox.toggled.connect(_on_slots_toggle_changed)

	# Hide initially until a station is selected
	visible = false


func _process(_delta: float) -> void:
	# Update display if we have a station selected
	if current_station != null and is_instance_valid(current_station):
		_update_display()


## Set the station to inspect
func set_station(station: Station) -> void:
	current_station = station

	if station == null:
		visible = false
		return

	visible = true
	_update_display()


## Clear the inspector
func clear() -> void:
	current_station = null
	visible = false


## Create suggestion buttons for common tags
func _create_suggestion_buttons() -> void:
	for tag in TAG_SUGGESTIONS:
		var btn := Button.new()
		btn.text = tag
		btn.custom_minimum_size.x = 50
		btn.pressed.connect(_on_suggestion_pressed.bind(tag))
		suggestions_container.add_child(btn)


## Update the display with current station data
func _update_display() -> void:
	if current_station == null or not is_instance_valid(current_station):
		return

	# Get inspection data from DebugCommands
	var data: Dictionary = DebugCommands.get_inspection_data(current_station)

	# Update name
	var station_name: String = current_station.station_name if current_station.station_name != "" else current_station.name
	name_label.text = station_name

	# Update tags display
	var tags: Array = data.get("tags", [])
	_update_tags_display(tags)

	# Update current user
	var current_user: String = data.get("current_user", "")
	if current_user.is_empty():
		current_user_label.text = "Status: Available"
	else:
		current_user_label.text = "In Use By: " + current_user

	# Update capacity
	var slot_contents: Dictionary = data.get("slot_contents", {})
	var input_items: Array = slot_contents.get("input_slots", [])
	var output_items: Array = slot_contents.get("output_slots", [])
	var total_slots: int = current_station.get_input_slot_count() + current_station.get_output_slot_count()
	var used_slots: int = input_items.size() + output_items.size()
	capacity_label.text = "Capacity: " + str(used_slots) + "/" + str(total_slots) + " slots"

	# Update input slots display
	_update_slots_display(input_slots_container, "Input Slots", current_station, true)

	# Update output slots display
	_update_slots_display(output_slots_container, "Output Slots", current_station, false)


## Update the tags display with editable tag buttons
func _update_tags_display(tags: Array) -> void:
	# Clear existing tag buttons (except the label)
	for child in tags_container.get_children():
		child.queue_free()

	if tags.is_empty():
		var no_tags := Label.new()
		no_tags.text = "(no tags)"
		no_tags.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		tags_container.add_child(no_tags)
	else:
		for tag in tags:
			var tag_btn := Button.new()
			tag_btn.text = str(tag) + " ×"
			tag_btn.tooltip_text = "Click to remove tag"
			tag_btn.pressed.connect(_on_remove_tag_pressed.bind(str(tag)))
			tags_container.add_child(tag_btn)


## Update slots display
func _update_slots_display(container: VBoxContainer, title: String, station: Station, is_input: bool) -> void:
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	var slot_count: int = station.get_input_slot_count() if is_input else station.get_output_slot_count()

	if slot_count == 0:
		var no_slots := Label.new()
		no_slots.text = title + ": None"
		no_slots.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		container.add_child(no_slots)
		return

	# Add title
	var title_label := Label.new()
	title_label.text = title + ":"
	container.add_child(title_label)

	# Add slot entries
	for i in range(slot_count):
		var item: ItemEntity = station.get_item_in_slot(i, is_input)
		var slot_row := HBoxContainer.new()

		var index_label := Label.new()
		index_label.text = "  [" + str(i) + "] "
		index_label.custom_minimum_size.x = 40
		slot_row.add_child(index_label)

		var content_label := Label.new()
		if item != null and is_instance_valid(item):
			content_label.text = item.item_tag
		else:
			content_label.text = "(empty)"
			content_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		slot_row.add_child(content_label)

		container.add_child(slot_row)


## Handle add tag button pressed
func _on_add_tag_pressed() -> void:
	var new_tag: String = tag_input.text.strip_edges().to_lower()
	if not new_tag.is_empty():
		_add_tag(new_tag)
		tag_input.text = ""


## Handle tag input submitted (Enter key)
func _on_tag_input_submitted(new_text: String) -> void:
	var new_tag: String = new_text.strip_edges().to_lower()
	if not new_tag.is_empty():
		_add_tag(new_tag)
		tag_input.text = ""


## Handle suggestion button pressed
func _on_suggestion_pressed(tag: String) -> void:
	_add_tag(tag)


## Handle remove tag button pressed
func _on_remove_tag_pressed(tag: String) -> void:
	_remove_tag(tag)


## Add a tag to the current station
func _add_tag(tag: String) -> void:
	if current_station == null or not is_instance_valid(current_station):
		return

	# For stations with single tag, replace the existing tag
	current_station.station_tag = tag
	_update_display()


## Remove a tag from the current station
func _remove_tag(tag: String) -> void:
	if current_station == null or not is_instance_valid(current_station):
		return

	# For stations with single tag, clear it
	if current_station.station_tag == tag:
		current_station.station_tag = ""
	_update_display()


## Handle slots visibility toggle
func _on_slots_toggle_changed(is_visible: bool) -> void:
	if on_slots_visibility_changed.is_valid():
		on_slots_visibility_changed.call(is_visible)


## Get current slots visibility state
func is_slots_visible() -> bool:
	if slots_toggle_checkbox != null:
		return slots_toggle_checkbox.button_pressed
	return true


## Set slots visibility state (used when switching stations)
func set_slots_visible(is_visible: bool) -> void:
	if slots_toggle_checkbox != null:
		slots_toggle_checkbox.button_pressed = is_visible
