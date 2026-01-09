# Code Review Findings - Debug & Testing UI System

**Date:** 2026-01-09
**Branch:** ralph/debug-testing-ui
**Commits Reviewed:** fd05d51..9a8f89b (25 commits, US-001 through US-012)
**Verdict:** Ready to merge (with minor fixes optional)

---

## Strengths

- Clean architecture with DebugCommands singleton as testable API layer
- Consistent inspector pattern across all panels (set_X/clear/_update_display/_process)
- Strong type safety with GDScript annotations throughout
- Comprehensive test coverage (313 assertions for debug_commands, 1038 total)
- Proper scene structure and collision-based click-to-select implementation
- Well-organized code sections with clear comment headers

---

## Important Issues

### 1. Performance: `_process()` Polling in All Inspectors

**Files:** npc_inspector.gd, station_inspector.gd, item_inspector.gd, container_inspector.gd

All four inspectors call `_update_display()` every frame, querying `DebugCommands.get_inspection_data()` 60 times per second even when nothing has changed.

**Fix:** Use timer-based approach:
```gdscript
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1

func _process(delta: float) -> void:
    if current_entity != null and is_instance_valid(current_entity):
        _update_timer += delta
        if _update_timer >= UPDATE_INTERVAL:
            _update_timer = 0.0
            _update_display()
```

### 2. Slider Feedback Loop Prevention is Fragile

**File:** npc_inspector.gd (lines 98-111)

Disconnects/reconnects signals to prevent feedback loops. This is fragile - multiple connections could accumulate.

**Fix:** Use boolean flag:
```gdscript
var _updating_sliders: bool = false

func _update_slider_values() -> void:
    _updating_sliders = true
    # ... update slider values ...
    _updating_sliders = false

func _on_motive_slider_changed(value: float, motive_name: String) -> void:
    if _updating_sliders:
        return
    # ... handle user input ...
```

### 3. Runtime Items Not Tracked on Ground Spawn

**File:** debug_commands.gd (lines 297-310)

Items spawned on ground via `spawn_item()` are NOT added to `runtime_items` array. This means:
- Ground-spawned items won't be saved in scenarios
- Ground-spawned items won't be cleared with `clear_scenario()`

**Fix:** Add `runtime_items.append(item)` in:
- `_spawn_item_on_ground()`
- `_spawn_item_in_container()`
- `_spawn_item_at_station()`

---

## Minor Issues

### 4. Unused Motive Color Constants

**File:** npc_inspector.gd (lines 24-26)

```gdscript
const MOTIVE_COLOR_CRITICAL := Color(0.8, 0.2, 0.2, 0.3)
const MOTIVE_COLOR_WARNING := Color(0.8, 0.6, 0.2, 0.3)
const MOTIVE_COLOR_GOOD := Color(0.2, 0.7, 0.2, 0.3)
```

Defined but never used. Either implement color-coding or remove.

### 5. Debug Print Statements Left in Code

**File:** debug_ui.gd (lines 95, 98, 100, 181, 187)

```gdscript
print("[DebugUI] Click at screen: ...")
print("[DebugUI] Selected entity: ...")
```

Remove or convert to conditional debug logging.

### 6. Magic Numbers in State Matching

**File:** debug_commands.gd

State enum values (0, 1, 2...) should use enum references:
```gdscript
# Instead of: match state: 0: return "IDLE"
# Use: match state: NPC.State.IDLE: return "IDLE"
```

### 7. Inconsistent Signal Naming

**File:** debug_commands.gd

- `job_posted_debug`, `job_interrupted_debug` use `_debug` suffix
- `station_spawned`, `npc_spawned` don't

Choose consistent naming convention.

---

## Recommendations for Future

1. **Extract Common Inspector Base Class** - All four inspectors share the same structure
2. **Add UI Integration Tests** - Current tests only cover DebugCommands API
3. **Add API Documentation** - Doc comments (`##`) for public methods
4. **Consider Signal-Based Updates** - Entities emit signals when state changes, inspectors update reactively

---

## Status

- [ ] Issue #1: Performance polling
- [ ] Issue #2: Slider feedback loop
- [ ] Issue #3: Runtime items tracking (most important)
- [ ] Issue #4: Unused constants
- [ ] Issue #5: Debug prints
- [ ] Issue #6: Magic numbers
- [ ] Issue #7: Signal naming
