extends TestRunner

## Tests for NPC._find_item_source() (US-005)

const NPCScene = preload("res://scenes/npc.tscn")
const ItemEntityScene = preload("res://scenes/objects/item_entity.tscn")
const ContainerScene = preload("res://scenes/objects/container.tscn")
const StationScene = preload("res://scenes/objects/station.tscn")

var level: Node2D


func _ready() -> void:
	_test_name = "NPC Find Item Source"
	level = get_parent()
	super._ready()


func run_tests() -> void:
	_log_header()

	test_find_source_container()
	test_find_source_ground()
	test_find_source_station()
	test_find_source_prefers_container()
	test_find_source_reserved_by_self()
	test_find_source_excludes_others_reserved()
	test_find_source_none()

	_log_summary()


func test_find_source_container() -> void:
	test("Returns container when item in container")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# Create container with item
	var container: ItemContainer = level.add_container(Vector2(100, 100), "Storage")
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	# Set up NPC with container access
	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Find item source
	var result: Dictionary = npc._find_item_source("raw_food")

	assert_eq(result["type"], "container", "Type should be 'container'")
	assert_eq(result["source"], container, "Source should be the container")

	# Cleanup
	level.remove_container(container)
	npc.queue_free()


func test_find_source_ground() -> void:
	test("Returns ground item when only on ground")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# Add item on ground (no containers)
	var ground_item: ItemEntity = level.add_item(Vector2(100, 100), "raw_food")

	# NPC has no containers, but should have access to level via _get_level()
	var empty_containers: Array[ItemContainer] = []
	var empty_stations: Array[Station] = []
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(empty_stations)

	# Find item source
	var result: Dictionary = npc._find_item_source("raw_food")

	assert_eq(result["type"], "ground", "Type should be 'ground'")
	assert_eq(result["source"], ground_item, "Source should be the ground item")

	# Cleanup
	level.remove_item(ground_item)
	npc.queue_free()


func test_find_source_station() -> void:
	test("Returns station when item in output slot")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# Create station with item in output slot
	var station: Station = level.add_station(Vector2(100, 100), "stove")
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "cooked_meal"
	station.place_output_item(item, 0)

	# Set up NPC with station access (no containers)
	var empty_containers: Array[ItemContainer] = []
	npc.set_available_containers(empty_containers)
	var stations: Array[Station] = [station]
	npc.set_available_stations(stations)

	# Find item source
	var result: Dictionary = npc._find_item_source("cooked_meal")

	assert_eq(result["type"], "station_output", "Type should be 'station_output'")
	assert_eq(result["source"], station, "Source should be the station")

	# Cleanup
	level.remove_station(station)
	npc.queue_free()


func test_find_source_prefers_container() -> void:
	test("Returns container over ground when both exist")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# Create container with item
	var container: ItemContainer = level.add_container(Vector2(100, 100), "Storage")
	var container_item: ItemEntity = ItemEntityScene.instantiate()
	container_item.item_tag = "raw_food"
	container.add_item(container_item)

	# Also add item on ground
	var ground_item: ItemEntity = level.add_item(Vector2(200, 100), "raw_food")

	# Set up NPC with container access
	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Find item source - should prefer container
	var result: Dictionary = npc._find_item_source("raw_food")

	assert_eq(result["type"], "container", "Type should be 'container' (preferred over ground)")
	assert_eq(result["source"], container, "Source should be the container")

	# Cleanup
	level.remove_container(container)
	level.remove_item(ground_item)
	npc.queue_free()


func test_find_source_reserved_by_self() -> void:
	test("Returns item reserved by this NPC")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# Create container with reserved item
	var container: ItemContainer = level.add_container(Vector2(100, 100), "Storage")
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "raw_food"
	container.add_item(item)

	# Reserve item by this NPC
	item.reserve_item(npc)

	# Create a mock job (needed for reserved-by-self checks)
	var recipe := Recipe.new()
	recipe.recipe_name = "Test Recipe"
	var job := Job.new(recipe, 1)
	npc.current_job = job

	# Set up NPC with container access
	var containers: Array[ItemContainer] = [container]
	npc.set_available_containers(containers)

	# Find item source - should find item reserved by self
	var result: Dictionary = npc._find_item_source("raw_food")

	assert_eq(result["type"], "container", "Type should be 'container'")
	assert_eq(result["source"], container, "Source should be the container with our reserved item")

	# Cleanup
	item.release_item()
	level.remove_container(container)
	npc.queue_free()


func test_find_source_excludes_others_reserved() -> void:
	test("Does not return item reserved by other NPC")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	var other_npc = NPCScene.instantiate()
	level.add_child(other_npc)

	# Create container with item reserved by other NPC
	# Use a unique tag to avoid finding items from previous tests
	var container: ItemContainer = level.add_container(Vector2(100, 100), "Storage")
	var item: ItemEntity = ItemEntityScene.instantiate()
	item.item_tag = "unique_reserved_test_item"
	container.add_item(item)

	# Reserve item by OTHER NPC
	item.reserve_item(other_npc)

	# Set up NPC with container access but no stations
	var containers: Array[ItemContainer] = [container]
	var empty_stations: Array[Station] = []
	npc.set_available_containers(containers)
	npc.set_available_stations(empty_stations)

	# Find item source - should NOT find item reserved by other
	var result: Dictionary = npc._find_item_source("unique_reserved_test_item")

	assert_eq(result["type"], "none", "Type should be 'none' (item reserved by other)")
	assert_eq(result["source"], null, "Source should be null")

	# Cleanup
	item.release_item()
	level.remove_container(container)
	npc.queue_free()
	other_npc.queue_free()


func test_find_source_none() -> void:
	test("Returns type='none' when item not found anywhere")

	var npc = NPCScene.instantiate()
	level.add_child(npc)
	npc.is_initialized = true

	# NPC has no containers and no items exist
	var empty_containers: Array[ItemContainer] = []
	var empty_stations: Array[Station] = []
	npc.set_available_containers(empty_containers)
	npc.set_available_stations(empty_stations)

	# Find item source for nonexistent item
	var result: Dictionary = npc._find_item_source("nonexistent_item")

	assert_eq(result["type"], "none", "Type should be 'none'")
	assert_eq(result["source"], null, "Source should be null")

	# Cleanup
	npc.queue_free()
