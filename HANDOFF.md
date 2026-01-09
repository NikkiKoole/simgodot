# Handoff: NPC Job System Debugging

## Current Status
WIP - NPC job system is mostly working but work steps complete instantly without waiting for the timer.

## What Was Fixed
1. **RecipeRegistry not loading recipes** - Added `load_recipes_from_directory()` call in `_ready()`
2. **NPC couldn't find reserved items** - Items were being reserved during `claim_job` but `_find_container_with_item` skipped reserved items. Added logic to find items reserved by the current NPC.
3. **Type errors in debug_commands.gd** - `Job` extends `RefCounted`, not `Node`. Fixed variable types.
4. **NPC count reduced to 1** - For easier debugging in `level.gd`

## Current Bug
NPC completes work steps instantly without waiting for `work_timer`. The flow is:

```
_start_next_work_step: step 0 action=prep station=counter
_start_step_work: work_timer=3.0 for action=prep
_start_next_work_step: step 1 action=cook station=stove  <-- Should wait 3 seconds!
_start_step_work: work_timer=5.0 for action=cook
_finish_job called  <-- Should wait 5 seconds!
```

## Where to Look
The issue is in `npc.gd`. The flow is:
1. `_start_next_work_step()` calls `_pathfind_to_station()`
2. When path is empty (NPC near station), it immediately calls `_on_arrived_at_station()`
3. `_on_arrived_at_station()` calls `_start_step_work()` which sets `work_timer`
4. **Something is calling `_on_step_complete()` immediately** instead of waiting for `_do_work()` to count down the timer

Added debug logging to trace the issue:
- `_on_arrived_at_station` logs when called
- `_on_step_complete` logs when called
- `_start_step_work` logs the work_timer value

## Key Files Modified
- `scripts/npc.gd` - Main job execution logic, debug logging
- `scripts/recipe_registry.gd` - Auto-loads recipes on startup
- `scripts/debug_commands.gd` - Fixed Job type references
- `scripts/level.gd` - NPC count = 1

## To Test
1. Run the game
2. Spawn a fridge (container) and add raw_food to it
3. Spawn a counter and stove (stations)
4. Wait for NPC to get hungry
5. Watch console logs - should see the flow and where the timer isn't being respected

## Next Steps
1. Run with the new debug logging to see if `_on_step_complete` is being called multiple times or too early
2. Check if something else is advancing steps or finishing the job
3. The timer countdown happens in `_do_work()` which runs in `_physics_process` when state is WORKING
