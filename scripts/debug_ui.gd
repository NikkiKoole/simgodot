extends CanvasLayer
## Debug UI - Visual interface for debug and testing tools.
## This UI is always visible and provides access to entity inspection and spawn tools.
## The UI panels are positioned to avoid blocking the main game viewport.

# References to UI sections for child scripts to access
@onready var inspector_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/InspectorSection
@onready var tools_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/ToolsSection
@onready var bottom_bar: PanelContainer = $BottomBar
@onready var job_status_label: Label = $BottomBar/MarginContainer/HBoxContainer/JobStatusLabel

# Selection highlight - we handle it directly in DebugUI instead of a separate node
var selected_entity: Node2D = null
var original_modulate: Color = Color.WHITE
var pulse_time: float = 0.0
const PULSE_SPEED := 4.0
const HIGHLIGHT_TINT := Color(1.0, 1.0, 0.5, 1.0)  # Yellowish tint

# Click detection collision mask (layer 8 for clickable areas, layer 2 for NPCs)
# Collision layers are bit masks: layer N = 2^(N-1), so layer 8 = 128, layer 2 = 2
const CLICK_COLLISION_MASK := 128 + 2  # Layer 8 (ClickArea) + Layer 2 (NPC body)

# Reference to the camera for coordinate conversion
var camera: Camera2D = null


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

	# Find camera for coordinate conversion
	_find_camera()


func _find_camera() -> void:
	# Try to find the camera in the scene
	var cameras := get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		camera = cameras[0]
		return

	# Fallback: search for Camera2D nodes
	var root := get_tree().current_scene
	if root:
		camera = _find_camera_recursive(root)


func _find_camera_recursive(node: Node) -> Camera2D:
	if node is Camera2D:
		return node
	for child in node.get_children():
		var result := _find_camera_recursive(child)
		if result != null:
			return result
	return null


func _process(delta: float) -> void:
	# Handle selection highlight pulsing
	if selected_entity != null and is_instance_valid(selected_entity):
		pulse_time += delta * PULSE_SPEED
		var pulse := lerpf(0.7, 1.0, (sin(pulse_time) + 1.0) / 2.0)
		selected_entity.modulate = HIGHLIGHT_TINT * pulse


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if click is over UI panels - if so, don't handle
			var mouse_pos: Vector2 = event.position
			# Side panel is on right (x > viewport_width - 280)
			# Bottom bar is at bottom (y > viewport_height - 40) but not under side panel
			var viewport_size := get_viewport().get_visible_rect().size
			var side_panel_x := viewport_size.x - 280
			var bottom_bar_y := viewport_size.y - 40

			# Skip if clicking on side panel
			if mouse_pos.x > side_panel_x:
				return
			# Skip if clicking on bottom bar (but not under where side panel would be)
			if mouse_pos.y > bottom_bar_y and mouse_pos.x < side_panel_x:
				return

			_handle_click(event.global_position)


func _handle_click(screen_position: Vector2) -> void:
	# Convert screen position to world position
	var world_position := _screen_to_world(screen_position)

	print("[DebugUI] Click at screen: ", screen_position, " -> world: ", world_position)

	# Find entity at this position using physics query
	var entity := _find_entity_at_position(world_position)

	if entity != null:
		print("[DebugUI] Selected entity: ", entity.name)
		DebugCommands.select_entity(entity)
	else:
		print("[DebugUI] No entity found, deselecting")
		# Clicked empty space - deselect
		DebugCommands.deselect_entity()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	# If we have a camera, use it for proper coordinate conversion
	if camera != null and is_instance_valid(camera):
		# Get the viewport
		var viewport := get_viewport()
		if viewport:
			# Use the camera's transform to convert screen to world coordinates
			var canvas_transform := viewport.get_canvas_transform()
			return canvas_transform.affine_inverse() * screen_position

	# Fallback: assume no camera offset
	return screen_position


func _find_entity_at_position(world_position: Vector2) -> Node:
	# Get the physics space
	var viewport := get_viewport()
	if viewport == null:
		return null

	var world := viewport.get_world_2d()
	if world == null:
		return null

	var space_state := world.direct_space_state
	if space_state == null:
		return null

	# Create a point query at the world position
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = CLICK_COLLISION_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true

	# Query for all objects at this point
	var results := space_state.intersect_point(query, 10)

	if results.is_empty():
		return null

	# Find the best entity from results
	# Priority: Items > NPCs > Stations > Containers
	var best_entity: Node = null
	var best_priority := -1

	for result in results:
		var collider: Node = result.collider
		var entity := _get_selectable_entity(collider)

		if entity != null:
			var priority := _get_entity_priority(entity)
			if priority > best_priority:
				best_priority = priority
				best_entity = entity

	return best_entity


func _get_selectable_entity(collider: Node) -> Node:
	# If the collider is an Area2D named "ClickArea", get its parent
	if collider is Area2D and collider.name == "ClickArea":
		return collider.get_parent()

	# If the collider is a CharacterBody2D (NPC), return it directly
	if collider is CharacterBody2D:
		# Check if it's an NPC (has motives property)
		if collider.get("motives") != null:
			return collider

	# If the collider itself is a selectable entity type
	if _is_selectable_entity(collider):
		return collider

	return null


func _is_selectable_entity(node: Node) -> bool:
	# Check for NPC (has motives)
	if node.get("motives") != null:
		return true

	# Check for Station (has get_all_input_items method)
	if node.has_method("get_all_input_items"):
		return true

	# Check for ItemEntity (has item_tag property)
	if node.get("item_tag") != null:
		return true

	# Check for Container (has items array and add_item method)
	if node.get("items") != null and node.has_method("add_item"):
		return true

	return false


func _get_entity_priority(entity: Node) -> int:
	# Higher priority entities are selected first when overlapping
	# Items are smallest, so they get highest priority
	if entity.get("item_tag") != null:
		return 4  # ItemEntity

	if entity.get("motives") != null:
		return 3  # NPC

	if entity.has_method("get_all_input_items"):
		return 2  # Station

	if entity.get("items") != null and entity.has_method("add_item"):
		return 1  # Container

	return 0


func _on_entity_selected(entity: Node) -> void:
	# Restore previous entity's modulate
	if selected_entity != null and is_instance_valid(selected_entity):
		selected_entity.modulate = original_modulate

	# Store new selected entity and its original modulate
	if entity is Node2D:
		selected_entity = entity
		original_modulate = entity.modulate
		pulse_time = 0.0
		print("[DebugUI] Highlight activated for: ", entity.name)
	else:
		selected_entity = null

	# Update inspector panel based on entity type
	_update_inspector_placeholder(entity)


func _on_entity_deselected() -> void:
	# Restore previous entity's modulate
	if selected_entity != null and is_instance_valid(selected_entity):
		selected_entity.modulate = original_modulate
		print("[DebugUI] Highlight deactivated for: ", selected_entity.name)

	selected_entity = null

	# Clear inspector panel
	_clear_inspector_placeholder()


func _update_inspector_placeholder(entity: Node) -> void:
	var placeholder := inspector_section.get_node_or_null("PlaceholderLabel")
	if placeholder is Label:
		var data := DebugCommands.get_inspection_data(entity)
		var entity_type: String = data.get("type", "unknown")
		placeholder.text = "Selected: " + entity_type.capitalize()


func _clear_inspector_placeholder() -> void:
	var placeholder := inspector_section.get_node_or_null("PlaceholderLabel")
	if placeholder is Label:
		placeholder.text = "Select an entity to inspect"


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
