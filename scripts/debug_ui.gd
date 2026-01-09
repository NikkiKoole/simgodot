extends CanvasLayer
## Debug UI - Visual interface for debug and testing tools.
## This UI is always visible and provides access to entity inspection and spawn tools.
## The UI panels are positioned to avoid blocking the main game viewport.

# Preload inspector scenes
const NPCInspectorScene = preload("res://scenes/npc_inspector.tscn")
const StationInspectorScene = preload("res://scenes/station_inspector.tscn")
const ItemInspectorScene = preload("res://scenes/item_inspector.tscn")
const ContainerInspectorScene = preload("res://scenes/container_inspector.tscn")

# References to UI sections for child scripts to access
@onready var inspector_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/InspectorSection
@onready var tools_section: VBoxContainer = $SidePanel/MarginContainer/VBoxContainer/ToolsSection
@onready var job_panel: PanelContainer = $JobPanel

# Inspector panels - instantiated on demand
var npc_inspector: Node = null
var station_inspector: Node = null
var item_inspector: Node = null
var container_inspector: Node = null

# Selection outline - drawn as rectangle around selected entity
var selected_entity: Node2D = null
var selection_outline: Node2D = null
const OUTLINE_COLOR := Color(1.0, 0.8, 0.0, 1.0)  # Yellow/gold
const OUTLINE_WIDTH := 2.0
const OUTLINE_PADDING := 4.0  # Pixels of padding around entity

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


func _process(_delta: float) -> void:
	# Update selection outline position to follow selected entity
	if selection_outline != null and is_instance_valid(selection_outline):
		if selected_entity != null and is_instance_valid(selected_entity):
			selection_outline.global_position = selected_entity.global_position
			selection_outline.queue_redraw()
		else:
			# Entity was freed, remove outline
			_remove_selection_outline()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Check if click is over any UI control - if so, don't handle
			# This properly handles buttons, sliders, and other interactive elements
			var mouse_pos: Vector2 = event.position

			# Check if mouse is over any of our UI panels
			var side_panel := get_node_or_null("SidePanel")
			var job_panel_node := get_node_or_null("JobPanel")

			if side_panel != null and side_panel.get_global_rect().has_point(mouse_pos):
				return
			if job_panel_node != null and job_panel_node.get_global_rect().has_point(mouse_pos):
				return

			# Release focus from any UI control when clicking in game world
			var focused := get_viewport().gui_get_focus_owner()
			if focused != null:
				focused.release_focus()

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
	# Remove previous outline
	_remove_selection_outline()

	# Store new selected entity and create outline
	if entity is Node2D:
		selected_entity = entity
		_create_selection_outline(entity)
		print("[DebugUI] Selection outline for: ", entity.name)
	else:
		selected_entity = null

	# Update inspector panel based on entity type
	_update_inspector_for_entity(entity)


func _on_entity_deselected() -> void:
	_remove_selection_outline()
	print("[DebugUI] Selection cleared")
	selected_entity = null

	# Clear inspector panel
	_clear_all_inspectors()


func _create_selection_outline(entity: Node2D) -> void:
	# Get the entity's size from its collision shape or visual
	var size := _get_entity_size(entity)

	# Create outline node as child of the entity's parent (so it's in world space)
	var parent := entity.get_parent()
	if parent == null:
		return

	# Create a simple Node2D and connect its draw signal
	selection_outline = Node2D.new()
	selection_outline.name = "SelectionOutline"
	selection_outline.z_index = 100  # Draw above everything
	parent.add_child(selection_outline)

	# Store size in metadata for drawing
	selection_outline.set_meta("outline_size", size)

	# Connect draw - we'll call queue_redraw each frame
	selection_outline.draw.connect(_draw_outline)
	selection_outline.global_position = entity.global_position
	selection_outline.queue_redraw()


func _draw_outline() -> void:
	if selection_outline == null or not is_instance_valid(selection_outline):
		return

	var size: Vector2 = selection_outline.get_meta("outline_size", Vector2(32, 32))
	var half_size := size / 2.0 + Vector2(OUTLINE_PADDING, OUTLINE_PADDING)

	# Draw rectangle outline
	var rect := Rect2(-half_size, size + Vector2(OUTLINE_PADDING * 2, OUTLINE_PADDING * 2))
	selection_outline.draw_rect(rect, OUTLINE_COLOR, false, OUTLINE_WIDTH)


func _remove_selection_outline() -> void:
	if selection_outline != null and is_instance_valid(selection_outline):
		selection_outline.queue_free()
	selection_outline = null


func _get_entity_size(entity: Node2D) -> Vector2:
	# Try to get size from ClickArea collision shape
	var click_area := entity.get_node_or_null("ClickArea")
	if click_area != null:
		var collision_shape := click_area.get_node_or_null("CollisionShape2D")
		if collision_shape != null and collision_shape.shape != null:
			var shape: Shape2D = collision_shape.shape
			if shape is CircleShape2D:
				var circle: CircleShape2D = shape
				var diameter: float = circle.radius * 2
				return Vector2(diameter, diameter)
			elif shape is RectangleShape2D:
				var rect: RectangleShape2D = shape
				return rect.size

	# Try to get from body collision (for NPCs)
	var collision := entity.get_node_or_null("CollisionShape2D")
	if collision != null and collision.shape != null:
		var shape: Shape2D = collision.shape
		if shape is CircleShape2D:
			var circle: CircleShape2D = shape
			var diameter: float = circle.radius * 2
			return Vector2(diameter, diameter)
		elif shape is RectangleShape2D:
			var rect: RectangleShape2D = shape
			return rect.size

	# Default size
	return Vector2(32, 32)


## Update inspector panel based on the selected entity type
func _update_inspector_for_entity(entity: Node) -> void:
	# Hide placeholder label
	var placeholder := inspector_section.get_node_or_null("PlaceholderLabel")
	if placeholder is Label:
		placeholder.visible = false

	# Get entity type from inspection data
	var data := DebugCommands.get_inspection_data(entity)
	var entity_type: String = data.get("type", "unknown")

	# Show appropriate inspector based on type
	match entity_type:
		"npc":
			_show_npc_inspector(entity)
		"station":
			_show_station_inspector(entity)
		"item":
			_show_item_inspector(entity)
		"container":
			_show_container_inspector(entity)
		_:
			# For unknown entity types, show placeholder
			_clear_all_inspectors()
			if placeholder is Label:
				placeholder.visible = true
				placeholder.text = "Selected: " + entity_type.capitalize()


## Show the NPC inspector panel for the given NPC
func _show_npc_inspector(npc: Node) -> void:
	# Hide other inspectors
	_hide_all_inspectors()

	# Create NPC inspector if it doesn't exist
	if npc_inspector == null:
		npc_inspector = NPCInspectorScene.instantiate()
		inspector_section.add_child(npc_inspector)

	# Set the NPC to inspect
	npc_inspector.set_npc(npc)
	npc_inspector.visible = true


## Show the Station inspector panel for the given Station
func _show_station_inspector(station: Node) -> void:
	# Hide other inspectors
	_hide_all_inspectors()

	# Create Station inspector if it doesn't exist
	if station_inspector == null:
		station_inspector = StationInspectorScene.instantiate()
		inspector_section.add_child(station_inspector)

	# Set the Station to inspect
	station_inspector.set_station(station)
	station_inspector.visible = true


## Show the Item inspector panel for the given ItemEntity
func _show_item_inspector(item: Node) -> void:
	# Hide other inspectors
	_hide_all_inspectors()

	# Create Item inspector if it doesn't exist
	if item_inspector == null:
		item_inspector = ItemInspectorScene.instantiate()
		inspector_section.add_child(item_inspector)

	# Set the Item to inspect
	item_inspector.set_item(item)
	item_inspector.visible = true


## Show the Container inspector panel for the given ItemContainer
func _show_container_inspector(container: Node) -> void:
	# Hide other inspectors
	_hide_all_inspectors()

	# Create Container inspector if it doesn't exist
	if container_inspector == null:
		container_inspector = ContainerInspectorScene.instantiate()
		inspector_section.add_child(container_inspector)

	# Set the Container to inspect
	container_inspector.set_container(container)
	container_inspector.visible = true


## Hide all inspector panels
func _hide_all_inspectors() -> void:
	if npc_inspector != null:
		npc_inspector.visible = false
	if station_inspector != null:
		station_inspector.visible = false
	if item_inspector != null:
		item_inspector.visible = false
	if container_inspector != null:
		container_inspector.visible = false


## Clear all inspectors and show placeholder
func _clear_all_inspectors() -> void:
	# Hide all inspector panels
	_hide_all_inspectors()

	# Clear inspector data
	if npc_inspector != null:
		npc_inspector.clear()
	if station_inspector != null:
		station_inspector.clear()
	if item_inspector != null:
		item_inspector.clear()
	if container_inspector != null:
		container_inspector.clear()

	# Show placeholder
	var placeholder := inspector_section.get_node_or_null("PlaceholderLabel")
	if placeholder is Label:
		placeholder.visible = true
		placeholder.text = "Select an entity to inspect"
