# SimGodot Agent Guidelines

## Project Overview
This is a Godot 4.5 simulation game inspired by The Sims, featuring NPCs with motive systems and interactable objects.

## Code Conventions

### GDScript Style
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

## Validation

Run Godot validation with:
```bash
"/Users/nikkikoole/Downloads/Godot 3.app/Contents/MacOS/Godot" --headless --quit
```

Note: Despite the name "Godot 3.app", this is actually Godot 4.5.1.

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
