extends VBoxContainer
## Container Inspector Panel - Shows detailed ItemContainer information when one is selected.
## Displays: container name, tags, item list, capacity

# Reference to the currently inspected container
var current_container: ItemContainer = null

# UI elements
@onready var name_label: Label = $NameLabel
@onready var tags_label: Label = $TagsLabel
@onready var capacity_label: Label = $CapacityLabel
@onready var items_container: VBoxContainer = $ItemsContainer


func _ready() -> void:
	# Hide initially until a container is selected
	visible = false


func _process(_delta: float) -> void:
	# Update display if we have a container selected
	if current_container != null and is_instance_valid(current_container):
		_update_display()


## Set the container to inspect
func set_container(container: ItemContainer) -> void:
	current_container = container

	if container == null:
		visible = false
		return

	visible = true
	_update_display()


## Clear the inspector
func clear() -> void:
	current_container = null
	visible = false


## Update the display with current container data
func _update_display() -> void:
	if current_container == null or not is_instance_valid(current_container):
		return

	# Get inspection data from DebugCommands
	var data: Dictionary = DebugCommands.get_inspection_data(current_container)

	# Update name
	var container_name: String = data.get("name", "")
	if container_name.is_empty():
		container_name = current_container.name
	name_label.text = container_name

	# Update tags (allowed tags)
	var tags: Array = data.get("tags", [])
	if tags.is_empty():
		tags_label.text = "Allowed Tags: All"
	else:
		tags_label.text = "Allowed Tags: " + ", ".join(tags)

	# Update capacity
	var capacity: int = data.get("capacity", 0)
	var used: int = data.get("used", 0)
	capacity_label.text = "Capacity: " + str(used) + "/" + str(capacity)

	# Update items list
	_update_items_display(data.get("items", []))


## Update the items list display
func _update_items_display(items_list: Array) -> void:
	# Clear existing children
	for child in items_container.get_children():
		child.queue_free()

	# Add title
	var title_label := Label.new()
	title_label.text = "Items:"
	items_container.add_child(title_label)

	if items_list.is_empty():
		var empty_label := Label.new()
		empty_label.text = "  (empty)"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		items_container.add_child(empty_label)
		return

	# Add item entries
	for i in range(items_list.size()):
		var item_tag: String = items_list[i]
		var item_row := HBoxContainer.new()

		var index_label := Label.new()
		index_label.text = "  [" + str(i) + "] "
		index_label.custom_minimum_size.x = 40
		item_row.add_child(index_label)

		var content_label := Label.new()
		content_label.text = item_tag
		item_row.add_child(content_label)

		items_container.add_child(item_row)
