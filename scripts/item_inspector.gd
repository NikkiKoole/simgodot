extends VBoxContainer
## Item Inspector Panel - Shows detailed ItemEntity information when one is selected.
## Displays: item tag, location state, container/station/NPC reference

# Reference to the currently inspected item
var current_item: ItemEntity = null

# UI elements
@onready var name_label: Label = $NameLabel
@onready var tag_label: Label = $TagLabel
@onready var state_label: Label = $StateLabel
@onready var location_label: Label = $LocationLabel
@onready var container_label: Label = $ContainerLabel
@onready var reserved_label: Label = $ReservedLabel


func _ready() -> void:
	# Hide initially until an item is selected
	visible = false


func _process(_delta: float) -> void:
	# Update display if we have an item selected
	if current_item != null and is_instance_valid(current_item):
		_update_display()


## Set the item to inspect
func set_item(item: ItemEntity) -> void:
	current_item = item

	if item == null:
		visible = false
		return

	visible = true
	_update_display()


## Clear the inspector
func clear() -> void:
	current_item = null
	visible = false


## Update the display with current item data
func _update_display() -> void:
	if current_item == null or not is_instance_valid(current_item):
		return

	# Get inspection data from DebugCommands
	var data: Dictionary = DebugCommands.get_inspection_data(current_item)

	# Update name/title
	var item_tag: String = data.get("item_tag", "Unknown")
	name_label.text = item_tag.capitalize().replace("_", " ")

	# Update tag
	tag_label.text = "Tag: " + item_tag

	# Update item state (RAW, PREPPED, COOKED, etc.)
	var state_name: String = ItemEntity.get_state_name(current_item.state)
	state_label.text = "State: " + state_name

	# Update location
	var location_state: String = data.get("location_state", "UNKNOWN")
	location_label.text = "Location: " + location_state

	# Update container/holder reference
	var container: String = data.get("container", "")
	if container.is_empty():
		container_label.text = "Holder: None"
	else:
		container_label.text = "Holder: " + container

	# Update reserved status
	if current_item.reserved_by != null and is_instance_valid(current_item.reserved_by):
		var reserver_name: String = current_item.reserved_by.name if current_item.reserved_by.get("name") != null else "Unknown"
		reserved_label.text = "Reserved By: " + reserver_name
	else:
		reserved_label.text = "Reserved: No"
