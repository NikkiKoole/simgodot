extends VBoxContainer
## Spawn Tools Panel - UI for spawning items, stations, and NPCs
## Provides dropdowns for selecting what to spawn, then click in the game world to place.
## All spawns go through the DebugCommands API.

# Spawn mode enum
enum SpawnMode { NONE, ITEM, STATION, NPC }

# Current spawn mode and selection
var current_mode: SpawnMode = SpawnMode.NONE
var selected_item_tag: String = ""
var selected_station_type: String = ""

# Preview node for showing what will be spawned
var preview_node: Node2D = null
var preview_visible: bool = false

# Available item tags for spawning
const ITEM_TAGS: Array[String] = [
	"raw_food", "prepped_food", "cooked_meal", "toilet_paper", "remote",
	"plate", "dirty_plate", "soap", "towel", "book"
]

# Reference to debug_ui for coordinate conversion
var debug_ui: CanvasLayer = null

# UI elements
@onready var item_dropdown: OptionButton = $ItemSpawnSection/ItemDropdown
@onready var item_spawn_btn: Button = $ItemSpawnSection/SpawnItemButton
@onready var station_dropdown: OptionButton = $StationSpawnSection/StationDropdown
@onready var station_spawn_btn: Button = $StationSpawnSection/SpawnStationButton
@onready var npc_spawn_btn: Button = $NPCSpawnSection/SpawnNPCButton
@onready var cancel_btn: Button = $CancelButton
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	# Find the DebugUI parent
	debug_ui = _find_debug_ui()

	# Populate item dropdown
	_populate_item_dropdown()

	# Populate station dropdown
	_populate_station_dropdown()

	# Connect button signals
	item_spawn_btn.pressed.connect(_on_spawn_item_pressed)
	station_spawn_btn.pressed.connect(_on_spawn_station_pressed)
	npc_spawn_btn.pressed.connect(_on_spawn_npc_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)

	# Connect dropdown signals
	item_dropdown.item_selected.connect(_on_item_selected)
	station_dropdown.item_selected.connect(_on_station_selected)

	# Initially hide cancel button and status
	cancel_btn.visible = false
	status_label.text = ""

	# Select first items in dropdowns
	if item_dropdown.item_count > 0:
		item_dropdown.select(0)
		_on_item_selected(0)
	if station_dropdown.item_count > 0:
		station_dropdown.select(0)
		_on_station_selected(0)


func _find_debug_ui() -> CanvasLayer:
	var parent: Node = get_parent()
	while parent != null:
		if parent is CanvasLayer:
			return parent
		parent = parent.get_parent()
	return null


func _populate_item_dropdown() -> void:
	item_dropdown.clear()
	for tag in ITEM_TAGS:
		var display_name: String = tag.replace("_", " ").capitalize()
		item_dropdown.add_item(display_name)


func _populate_station_dropdown() -> void:
	station_dropdown.clear()
	var station_types: Array[String] = DebugCommands.get_valid_station_types()
	for station_type in station_types:
		var display_name: String = station_type.capitalize()
		station_dropdown.add_item(display_name)


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < ITEM_TAGS.size():
		selected_item_tag = ITEM_TAGS[index]


func _on_station_selected(index: int) -> void:
	var station_types: Array[String] = DebugCommands.get_valid_station_types()
	if index >= 0 and index < station_types.size():
		selected_station_type = station_types[index]


func _on_spawn_item_pressed() -> void:
	if selected_item_tag.is_empty():
		status_label.text = "Select an item first"
		return

	current_mode = SpawnMode.ITEM
	cancel_btn.visible = true
	status_label.text = "Click in world to spawn: " + selected_item_tag.replace("_", " ")
	_create_preview()


func _on_spawn_station_pressed() -> void:
	if selected_station_type.is_empty():
		status_label.text = "Select a station type first"
		return

	current_mode = SpawnMode.STATION
	cancel_btn.visible = true
	status_label.text = "Click in world to spawn: " + selected_station_type.capitalize()
	_create_preview()


func _on_spawn_npc_pressed() -> void:
	current_mode = SpawnMode.NPC
	cancel_btn.visible = true
	status_label.text = "Click in world to spawn NPC"
	_create_preview()


func _on_cancel_pressed() -> void:
	_cancel_spawn_mode()


func _cancel_spawn_mode() -> void:
	current_mode = SpawnMode.NONE
	cancel_btn.visible = false
	status_label.text = ""
	_remove_preview()


func _process(_delta: float) -> void:
	if current_mode != SpawnMode.NONE and preview_node != null:
		_update_preview_position()


func _input(event: InputEvent) -> void:
	if current_mode == SpawnMode.NONE:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if click is over UI - if so, ignore
			if _is_click_over_ui(event.position):
				return

			# Handle the spawn
			var world_pos: Vector2 = _screen_to_world(event.position)
			_do_spawn(world_pos)

			# Accept the event to prevent other handlers
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click cancels spawn mode
			_cancel_spawn_mode()
			get_viewport().set_input_as_handled()


func _is_click_over_ui(screen_pos: Vector2) -> bool:
	if debug_ui == null:
		return false

	var side_panel: Node = debug_ui.get_node_or_null("SidePanel")
	var job_panel: Node = debug_ui.get_node_or_null("JobPanel")

	if side_panel != null and side_panel is Control:
		if side_panel.get_global_rect().has_point(screen_pos):
			return true

	if job_panel != null and job_panel is Control:
		if job_panel.get_global_rect().has_point(screen_pos):
			return true

	return false


func _screen_to_world(screen_position: Vector2) -> Vector2:
	# Find the camera for coordinate conversion
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_position

	var canvas_transform: Transform2D = viewport.get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_position


func _do_spawn(world_position: Vector2) -> void:
	match current_mode:
		SpawnMode.ITEM:
			var item: ItemEntity = DebugCommands.spawn_item(selected_item_tag, world_position)
			if item != null:
				status_label.text = "Spawned: " + selected_item_tag.replace("_", " ")
			else:
				status_label.text = "Failed to spawn item"

		SpawnMode.STATION:
			var station: Station = DebugCommands.spawn_station(selected_station_type, world_position)
			if station != null:
				status_label.text = "Spawned: " + selected_station_type.capitalize()
			else:
				status_label.text = "Failed to spawn station"

		SpawnMode.NPC:
			var npc: Node = DebugCommands.spawn_npc(world_position)
			if npc != null:
				status_label.text = "Spawned: NPC"
			else:
				status_label.text = "Failed to spawn NPC"

	# Exit spawn mode after spawning
	current_mode = SpawnMode.NONE
	cancel_btn.visible = false
	_remove_preview()


func _create_preview() -> void:
	_remove_preview()

	# Create a simple preview node
	preview_node = Node2D.new()
	preview_node.name = "SpawnPreview"
	preview_node.z_index = 100

	# Add visual based on spawn type
	var visual: ColorRect = ColorRect.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	match current_mode:
		SpawnMode.ITEM:
			visual.size = Vector2(16, 16)
			visual.position = Vector2(-8, -8)
			visual.color = Color(0.2, 0.8, 0.2, 0.6)  # Green, semi-transparent
		SpawnMode.STATION:
			visual.size = Vector2(32, 32)
			visual.position = Vector2(-16, -16)
			# Use station color if available
			if DebugCommands.STATION_COLORS.has(selected_station_type):
				visual.color = DebugCommands.STATION_COLORS[selected_station_type]
				visual.color.a = 0.6  # Make semi-transparent
			else:
				visual.color = Color(0.3, 0.5, 0.6, 0.6)
		SpawnMode.NPC:
			visual.size = Vector2(24, 24)
			visual.position = Vector2(-12, -12)
			visual.color = Color(0.2, 0.4, 0.8, 0.6)  # Blue, semi-transparent

	preview_node.add_child(visual)

	# Add to the game world (find level or use current scene)
	var level: Node = _get_level_node()
	if level != null:
		level.add_child(preview_node)
	else:
		var root: Node = get_tree().current_scene
		if root != null:
			root.add_child(preview_node)


func _remove_preview() -> void:
	if preview_node != null and is_instance_valid(preview_node):
		preview_node.queue_free()
	preview_node = null


func _update_preview_position() -> void:
	if preview_node == null or not is_instance_valid(preview_node):
		return

	var mouse_screen_pos: Vector2 = get_viewport().get_mouse_position()

	# Check if over UI - hide preview
	if _is_click_over_ui(mouse_screen_pos):
		preview_node.visible = false
		return

	preview_node.visible = true
	var world_pos: Vector2 = _screen_to_world(mouse_screen_pos)

	# Snap station preview to grid
	if current_mode == SpawnMode.STATION:
		world_pos = DebugCommands.snap_to_grid(world_pos)

	preview_node.global_position = world_pos


func _get_level_node() -> Node:
	var levels: Array[Node] = get_tree().get_nodes_in_group("level")
	if levels.size() > 0:
		return levels[0]
	return get_tree().current_scene
