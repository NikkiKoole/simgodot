# SimGodot Agent Guidelines

## Project Overview
This is a Godot 4.5 simulation game inspired by The Sims, featuring NPCs with motive systems and interactable objects.

## Code Conventions

### GDScript Style
- **IMPORTANT: Use spaces for indentation, NOT tabs** (tabs cause edit matching issues)
- Use `class_name` at the top of scripts for global class registration
- Use type hints throughout (e.g., `var name: String = ""`)
- Use `@export` for inspector-visible properties
- Enums defined within classes using `enum EnumName { VALUE1, VALUE2 }`
- Signals declared with typed parameters (e.g., `signal value_changed(new_value: float)`)

### Scene Structure
- Scenes use `.tscn` format with `[gd_scene]` header
- Visual elements use `ColorRect` named "Sprite2D" for simple colored rectangles
- Scene files need `uid://` for unique identification
- Scripts attached via `ExtResource` in scene files

### Directory Structure
- `scripts/` - GDScript files
- `scenes/` - Scene files (.tscn)
- `scenes/objects/` - Interactable objects and items
- `scripts/ralph/` - Ralph agent PRD and progress tracking

## Level System (`scripts/level.gd`)

### ASCII Map Characters
The world is defined via an ASCII map in `WORLD_MAP` constant:

| Char | Object | Scene |
|------|--------|-------|
| `#` | Wall | (built-in) |
| ` ` | Floor (walkable) | (built-in) |
| `P` | Player start | player.tscn |
| `B` | Bed | bed.tscn |
| `F` | Fridge | fridge.tscn |
| `T` | Toilet | toilet.tscn |
| `S` | Shower | shower.tscn |
| `V` | TV | tv.tscn |
| `C` | Computer | computer.tscn |
| `K` | Bookshelf | bookshelf.tscn |
| `O` | Container | container.tscn |
| `i` | Item | item_entity.tscn |
| `W` | Station | station.tscn |

### Adding New Objects to ASCII Map
1. Add scene preload: `var my_scene: PackedScene = preload("res://scenes/objects/my_object.tscn")`
2. Add character to comment documentation
3. Add match case in `_parse_and_build_world()`
4. Create spawn function if needed (for non-InteractableObject types)

### Future Considerations
- Consider supporting station type variants (e.g., `1`=counter, `2`=stove, `3`=sink)
- Consider supporting item type variants for different item_tags
- Consider a data-driven approach for complex level setups

## Validation

Run Godot validation with:
```bash
"/Users/nikkikoole/Downloads/Godot 3.app/Contents/MacOS/Godot" --headless --import --quit
```

Note: Despite the name "Godot 3.app", this is actually Godot 4.5.1.

**Important**: Use `--import` flag to catch script errors (like reserved class names). Without it, Godot just runs the project briefly without full validation.

## Key Systems

### Motive System (`scripts/motive.gd`)
- Motives range from -100 to +100
- Negative values = urgent need, positive = satisfied
- Active motives: HUNGER, ENERGY, BLADDER, HYGIENE, FUN

### Interactable Objects (`scripts/interactable_object.gd`)
- Objects "advertise" what motives they fulfill
- Reservation system: `reserve()`, `cancel_reservation()`, `is_available_for()`
- Usage tracking: `start_use()`, `stop_use()`

### Item System (`scripts/item_entity.gd`)
- Physical items with ItemState (RAW, PREPPED, COOKED, DIRTY, BROKEN)
- Location tracking with ItemLocation (IN_CONTAINER, IN_HAND, IN_SLOT, ON_GROUND)
- Reservation system for agent claiming

### Container System (`scripts/container.gd`)
- Class name is `ItemContainer` (not `Container` - that's a reserved Godot class)
- Stores multiple ItemEntity references with capacity limits
- Tag filtering via `allowed_tags` array (empty = allow all)
- Key methods: `add_item()`, `remove_item()`, `find_item_by_tag()`
- `get_available_items()` returns only unreserved items
- Items are reparented to container when added

### Resource System
- Resources extend `Resource` class (not Node2D) for pure data classes
- Resources are saved as `.tres` files in `resources/` directory
- Recipe resources go in `resources/recipes/`
- Use `class_name` at top of script for global registration
- `.tres` files use `[gd_resource]` header with `script_class` attribute for typed resources
- Resources are ideal for data definitions like RecipeStep, Recipe, etc.

### Naming Conventions
- Avoid using Godot reserved class names (Container, Node, Control, etc.)
- Prefix custom classes to avoid conflicts (e.g., `ItemContainer` instead of `Container`)

## Testing System

### Test Directory Structure
- `scripts/tests/` - Test scripts extending TestRunner
- `scenes/tests/` - Test scenes that run automatically on load

### Running Tests
Run individual test scenes:
```bash
"/Users/nikkikoole/Downloads/Godot 3.app/Contents/MacOS/Godot" --headless --path . res://scenes/tests/test_items.tscn --quit-after 3000
```

### Creating New Tests
1. Create a script in `scripts/tests/` extending `TestRunner`
2. Set `_test_name` in `_ready()`
3. Override `run_tests()` to call your test methods
4. Create a scene in `scenes/tests/` with a `TestArea` Node2D child
5. Attach your test script to the scene root

### TestRunner API
- `test(name)` - Start a named test
- `assert_true(condition, message)` - Assert condition is true
- `assert_false(condition, message)` - Assert condition is false
- `assert_eq(actual, expected, message)` - Assert equality
- `assert_neq(actual, not_expected, message)` - Assert inequality
- `assert_null(value, message)` - Assert value is null
- `assert_not_null(value, message)` - Assert value is not null
- `assert_array_size(arr, size, message)` - Assert array length
- `assert_array_contains(arr, item, message)` - Assert array contains item

### Test Scene Structure
Test scenes should have:
- Root node with test script attached
- `TestArea` (Node2D) at position (200, 150) for spawning test objects
- `Camera2D` centered on the test area
- Optional visual background (floor/walls)

### Tips
- Use `await get_tree().process_frame` when testing `_ready()` behavior
- Instantiate from preloaded scenes: `const Scene = preload("res://...")`
- Clean up with `queue_free()` after each test
- Test global positions account for parent transforms
