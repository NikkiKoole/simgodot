# Plan: Configurable ASCII Map for Testable Levels

## Context for Implementation

This plan follows a major refactor where we unified entity tracking in level.gd. The DebugCommands singleton now delegates all entity spawning to level.gd's public API (add_station, add_npc, etc.). 

However, the test file `scripts/tests/test_debug_commands.gd` currently uses a MockLevel class (~180 lines) that duplicates level.gd's entity management. This is fragile and can diverge from real behavior.

**Goal**: Eliminate MockLevel by making level.gd configurable so tests can use the REAL Level class.

---

## Problem

`scripts/level.gd` has a hardcoded `WORLD_MAP` constant and auto-spawns everything in `_ready()`:
- GameClock and ClockUI
- Walls from ASCII map
- Player positioning  
- Containers, Items, Stations from ASCII markers
- NPCs (configurable count)

Tests need levels without all this auto-spawning, so they created MockLevel which duplicates entity management logic.

---

## Solution

Make the ASCII map an input parameter instead of a hardcoded constant. Tests provide their own maps (or empty string for blank levels).

---

## Current Code (level.gd key parts)

```gdscript
# Currently hardcoded
const WORLD_MAP := """
#################
#       #       #
#       #       #
#               #
#       #   O   #
#       #       #
###  ####       #
#       #########
#  P            #
#     i     W   #
###  #####      #
#       #       #
#       #       #
#       #       #
#       #       #
#################
"""

@export var npc_count: int = 1
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
    # Creates game_clock, clock_ui
    # Calls _parse_and_build_world()
    # Calls _setup_astar()
    # Calls _spawn_npcs()
```

---

## Target Code Changes

### 1. Make world_map configurable (level.gd)

```gdscript
# Default map for normal gameplay (move current WORLD_MAP here)
const DEFAULT_WORLD_MAP := """
#################
#       #       #
#       #       #
#               #
#       #   O   #
#       #       #
###  ####       #
#       #########
#  P            #
#     i     W   #
###  #####      #
#       #       #
#       #       #
#       #       #
#       #       #
#################
"""

## The ASCII map to use. Empty string = empty grid (for testing)
@export_multiline var world_map: String = DEFAULT_WORLD_MAP

## Whether to auto-spawn NPCs on ready
@export var auto_spawn_npcs: bool = true

## Number of NPCs to spawn (only if auto_spawn_npcs is true)
@export var npc_count: int = 1

## Grid size for empty levels (when world_map is empty)
@export var empty_grid_width: int = 20
@export var empty_grid_height: int = 20
```

### 2. Make Player optional (level.gd)

```gdscript
# Change from:
@onready var player: CharacterBody2D = $Player

# To:
@onready var player: CharacterBody2D = get_node_or_null("Player")
```

### 3. Update _ready() (level.gd)

```gdscript
func _ready() -> void:
    add_to_group("level")
    
    # Create game clock (always needed for NPC behavior)
    game_clock = GameClock.new()
    add_child(game_clock)

    # Create clock UI (skip in tests if desired - could add export flag)
    var clock_ui := ClockUI.new()
    clock_ui.set_game_clock(game_clock)
    add_child(clock_ui)

    # Create reusable collision shape
    wall_shape = RectangleShape2D.new()
    wall_shape.size = Vector2(TILE_SIZE, TILE_SIZE)

    # Parse map OR create empty grid
    if world_map.strip_edges().is_empty():
        _setup_empty_grid()
    else:
        _parse_and_build_world()
    
    _setup_astar()
    
    # Only spawn NPCs if enabled
    if auto_spawn_npcs and npc_count > 0:
        _spawn_npcs()

    # Give player reference to game clock (if player exists)
    if player != null:
        player.set_game_clock(game_clock)
```

### 4. Add empty grid setup (level.gd)

```gdscript
## Setup an empty grid with no walls - all positions walkable
func _setup_empty_grid() -> void:
    map_width = empty_grid_width
    map_height = empty_grid_height
    
    # Create floor background
    var floor_rect := ColorRect.new()
    floor_rect.color = FLOOR_COLOR
    floor_rect.position = Vector2.ZERO
    floor_rect.size = Vector2(map_width * TILE_SIZE, map_height * TILE_SIZE)
    floor_rect.z_index = -10
    add_child(floor_rect)
    
    # All positions are walkable in empty grid
    for y in range(map_height):
        for x in range(map_width):
            var pos := Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
            walkable_positions.append(pos)
            wander_positions.append(pos)
```

### 5. Update _setup_astar() to handle empty grid (level.gd)

The current `_setup_astar()` parses WORLD_MAP again to mark walls. For empty grids, no walls need marking:

```gdscript
func _setup_astar() -> void:
    astar = AStarGrid2D.new()
    astar.region = Rect2i(0, 0, map_width, map_height)
    astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
    astar.offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
    astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
    astar.update()

    # Only mark walls if we have a map (not empty grid)
    if not world_map.strip_edges().is_empty():
        var lines := world_map.strip_edges().split("\n")
        for y in range(lines.size()):
            var line: String = lines[y]
            for x in range(line.length()):
                if line[x] == "#":
                    astar.set_point_solid(Vector2i(x, y), true)
```

---

## Test Usage Examples

### Empty level for spawn tests

```gdscript
var test_level: Node2D

func setup_empty_level() -> void:
    test_level = preload("res://scenes/level.tscn").instantiate()
    test_level.world_map = ""  # Empty = no walls, no pre-spawned entities
    test_level.auto_spawn_npcs = false
    add_child(test_level)
    await get_tree().process_frame
```

### Level with walls for pathfinding tests

```gdscript
func setup_wall_test() -> void:
    test_level = preload("res://scenes/level.tscn").instantiate()
    test_level.world_map = """
##########
#        #
#   ##   #
#   ##   #
#        #
##########
"""
    test_level.auto_spawn_npcs = false
    add_child(test_level)
    await get_tree().process_frame
```

### Level with stations and containers for job tests

```gdscript
func setup_job_test() -> void:
    test_level = preload("res://scenes/level.tscn").instantiate()
    test_level.world_map = """
##########
#        #
# O    W #
#        #
#   i    #
##########
"""
    test_level.auto_spawn_npcs = false
    add_child(test_level)
    await get_tree().process_frame
    
    # Level now has: 1 container (O), 1 station (W), 1 item (i)
    # All tracked in level.all_containers, level.all_stations, level.all_items
```

---

## Changes to test_debug_commands.gd

### Remove MockLevel class entirely

Delete the entire `class MockLevel extends Node2D:` block (~180 lines, around lines 15-195).

### Remove mock_level variable

```gdscript
# Delete this:
var mock_level: MockLevel

# Delete this function:
func _setup_mock_level() -> void:
    mock_level = MockLevel.new()
    add_child(mock_level)
```

### Add test_level variable and setup

```gdscript
var test_level: Node2D

func _ready() -> void:
    _test_name = "DebugCommands"
    test_area = $TestArea
    _setup_test_level()
    super._ready()

func _setup_test_level() -> void:
    test_level = preload("res://scenes/level.tscn").instantiate()
    test_level.world_map = ""  # Empty level
    test_level.auto_spawn_npcs = false
    add_child(test_level)
```

### Replace mock_level references

Throughout the file, replace:
- `mock_level.astar` → `test_level.astar`
- `mock_level.clear_all_entities()` → `test_level.clear_all_entities()`
- `_setup_wall_test_walls()` → can be removed, walls defined in world_map instead

### For wall tests specifically

Instead of `_setup_wall_test_walls()`, tests that need walls can recreate the level with a wall map:

```gdscript
func test_paint_wall_add() -> void:
    test("paint_wall adds a wall at grid position")
    
    # Reset to empty level (or level with some original walls)
    test_level.queue_free()
    test_level = preload("res://scenes/level.tscn").instantiate()
    test_level.world_map = """
##########
#        #
#        #
##########
"""
    test_level.auto_spawn_npcs = false
    add_child(test_level)
    await get_tree().process_frame
    
    # Now test wall painting...
```

Or simpler - just use empty level and paint walls dynamically, which is what the test is actually testing.

---

## ASCII Map Legend

Keep consistent with existing markers in `_parse_and_build_world()`:

| Char | Meaning |
|------|---------|
| `#` | Wall (solid, not walkable) |
| ` ` | Floor (empty, walkable) |
| `P` | Player spawn position (also walkable) |
| `O` | Container spawn (also walkable) |
| `i` | Item spawn - raw_food by default (also walkable) |
| `W` | Station spawn - counter by default (also walkable) |

---

## Implementation Order

### Step 1: Modify level.gd

1. Add `DEFAULT_WORLD_MAP` constant with current map
2. Change `const WORLD_MAP` to `@export_multiline var world_map: String = DEFAULT_WORLD_MAP`
3. Add `@export var auto_spawn_npcs: bool = true`
4. Change `@onready var player` to use `get_node_or_null("Player")`
5. Add `@export var empty_grid_width: int = 20` and `empty_grid_height`
6. Add `_setup_empty_grid()` function
7. Update `_ready()` to check `world_map.is_empty()` and branch
8. Update `_setup_astar()` to handle empty grid case
9. Add `add_to_group("level")` at start of `_ready()`

### Step 2: Test level.gd changes

Run the game normally - should work exactly as before with default map.

### Step 3: Update test_debug_commands.gd

1. Delete MockLevel class (lines ~15-195)
2. Delete `mock_level` variable and `_setup_mock_level()`
3. Add `test_level` variable
4. Add `_setup_test_level()` that creates real Level with empty world_map
5. Replace all `mock_level` references with `test_level`
6. Remove `_setup_wall_test_walls()` function
7. Update wall tests to either use empty level or reset with wall map

### Step 4: Run all tests

```bash
./run_tests.sh
```

All 13 suites should pass.

---

## Files to Modify

1. **scripts/level.gd** - Add configurability
2. **scripts/tests/test_debug_commands.gd** - Remove MockLevel, use real Level

No other files need changes.

---

## Verification Checklist

- [ ] Game runs normally with default world_map
- [ ] Empty world_map creates blank grid with all positions walkable
- [ ] auto_spawn_npcs=false prevents NPC spawning
- [ ] Player=null doesn't crash (for scenes without Player node)
- [ ] test_debug_commands.gd has no MockLevel class
- [ ] All 13 test suites pass
- [ ] DebugCommands can spawn/remove entities on empty level
- [ ] Wall painting works on empty level

---

## Notes for Implementation

1. **Don't break the game** - The default values should make the game work exactly as before
2. **Level must be in "level" group** - DebugCommands finds it via `get_tree().get_nodes_in_group("level")`
3. **GameClock is required** - NPCs need it for behavior, always create it
4. **Tests should clean up** - Call `test_level.clear_all_entities()` between tests or recreate level
5. **Motive decay in tests** - NPCs' motives decay over time, use approximate comparisons or set motives right before checking

---

## Expected Outcome

- ~180 lines of MockLevel code deleted
- Tests use real Level class with real code paths  
- Test setups are visual and readable (ASCII maps)
- Single source of truth for entity management
- Easier to add new tests - just define an ASCII map
- Bugs in level.gd will be caught by tests (no mock divergence)
