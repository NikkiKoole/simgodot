# PRD: Unified Job Completion Pipeline

## Introduction

The codebase currently has two competing job completion implementations that cause inconsistent behavior:

1. **`npc.gd::_finish_job()`** - The active runtime path that applies motive effects directly and consumes items, but never spawns output items
2. **`job_board.gd::complete_job()`** - A complete implementation with output spawning that is never called by NPCs

This creates a critical bug: recipes with defined outputs (like `cook_simple_meal.tres` producing `cooked_meal`) never actually produce those items. The NPC just gets the motive satisfaction directly.

This refactor unifies the completion pipeline around **Design B: Production Chain Model**, where tasks produce world outputs and separate consumption tasks satisfy motives. This enables emergent gameplay like multiple NPCs benefiting from one production chain, meaningful storage, and scarcity mechanics.

## Goals

- Establish a single authoritative job completion pipeline via `JobBoard.complete_job()`
- Remove duplicated motive/item handling logic from `npc.gd::_finish_job()`
- Ensure recipe outputs are actually spawned into the world
- Implement "drop at station" policy for outputs (tool handling deferred)
- Remove motive effects from production recipes (cooking doesn't satisfy hunger)
- Create a working consumption recipe (`eat_snack.tres`) as proof of the new model
- Update existing tests to reflect the unified pipeline

## User Stories

### US-001: Refactor NPC to delegate job completion to JobBoard
**Description:** As a developer, I want `_finish_job()` to delegate all completion logic to `JobBoard.complete_job()` so that there is one authoritative completion pipeline.

**Acceptance Criteria:**
- [ ] `npc.gd::_finish_job()` calls `JobBoard.complete_job(current_job, self, target_station)`
- [ ] `_finish_job()` no longer applies motive effects directly
- [ ] `_finish_job()` no longer handles item consumption (queue_free)
- [ ] `_finish_job()` only cleans up local NPC state (held_items, target_station, current_job, state)
- [ ] NPC can access JobBoard via `get_node("/root/Main/JobBoard")` or stored reference

### US-002: Ensure JobBoard.complete_job() handles station output spawning
**Description:** As a developer, I want `complete_job()` to reliably spawn recipe outputs at the station so that production recipes create real items in the world.

**Acceptance Criteria:**
- [ ] `_spawn_outputs()` places items in station output slots when available
- [ ] If no output slots available, items are placed on the ground near the station
- [ ] Each output item is properly instantiated with correct `item_tag` and state
- [ ] Output items are added to the scene tree correctly

### US-003: Remove tools requirement from watch_tv recipe (DEFERRED: Tool handling)
**Description:** As a developer, I want to remove the remote tool requirement from watch_tv since tool handling is deferred to future work.

**Acceptance Criteria:**
- [ ] `resources/recipes/watch_tv.tres` has `tools = []`
- [ ] Recipe still has all steps defined
- [ ] Recipe still has motive_effects for fun

**Note:** Tool handling (where tools come from, where they go, sharing between NPCs) is a bigger subject that deserves its own PRD. For now, we remove tool requirements so recipes work without them.

### US-004: Remove motive effects from production recipes
**Description:** As a content author, I want production recipes to NOT satisfy motives directly so that only consumption actions fulfill needs.

**Acceptance Criteria:**
- [ ] `cook_simple_meal.tres` has empty `motive_effects = {}`
- [ ] Cooking a meal no longer satisfies hunger
- [ ] The `cooked_meal` output is spawned at the cooking station

### US-005: Create eat_snack consumption recipe
**Description:** As a developer, I want a working consumption recipe that demonstrates the new model where eating (not cooking) satisfies hunger.

**Acceptance Criteria:**
- [ ] New recipe file `resources/recipes/eat_snack.tres` exists
- [ ] Recipe consumes 1x `cooked_meal` (or similar food item)
- [ ] Recipe has no station requirement (can eat anywhere)
- [ ] Recipe has `motive_effects = {"hunger": 50.0}` (or appropriate value)
- [ ] Recipe has no outputs (food is consumed)
- [ ] NPCs can execute this recipe and have hunger satisfied

### US-006: Update tests for unified pipeline
**Description:** As a developer, I want tests to verify the unified completion pipeline works correctly.

**Acceptance Criteria:**
- [ ] Existing `test_jobboard.gd` tests pass with new implementation
- [ ] Tests verify that outputs are spawned when recipe has outputs
- [ ] Tests verify that motive effects are applied via `complete_job()`
- [ ] Tests verify tools are dropped at station
- [ ] Integration test: NPC completes cooking job, `cooked_meal` appears at station

### US-007: Clean up held_items after completion
**Description:** As a developer, I want the NPC's held_items to be properly cleared after job completion without orphaning items.

**Acceptance Criteria:**
- [ ] NPC's `held_items` array is cleared after `complete_job()` returns
- [ ] Items are not queue_free'd by NPC (JobBoard handles this)
- [ ] No orphaned item references remain in NPC state
- [ ] Station reservation is properly released

## Functional Requirements

- FR-1: `npc.gd::_finish_job()` must delegate to `JobBoard.complete_job(job, agent, station)` for all completion logic
- FR-2: `JobBoard.complete_job()` must spawn all recipe outputs at the station's output slots
- FR-3: `JobBoard.complete_job()` must apply motive effects to the agent
- FR-4: `JobBoard.complete_job()` must consume recipe inputs (queue_free consumed items)
- FR-5: `JobBoard.complete_job()` must drop tools at/near the station (not consume them)
- FR-6: `npc.gd::_finish_job()` must only handle local state cleanup: clear held_items, release station, set state to IDLE
- FR-7: Production recipes (cooking, crafting) must have empty `motive_effects`
- FR-8: Consumption recipes (eating, drinking) must consume items and provide motive effects
- FR-9: The `eat_snack` recipe must work without a station requirement

## Non-Goals

- No changes to job discovery, claiming, or hauling phases
- No tool handling implementation (deferred to future PRD)
- No changes to the step execution system (`_apply_step_transforms`, work timers, etc.)
- No new station types or container mechanics
- No automatic job chaining (cook -> eat) - NPCs decide what to do via existing motive system
- No partial motive satisfaction for production (e.g., "smelling food")

## Technical Considerations

### JobBoard Access Pattern
The NPC needs to access the JobBoard singleton. Options:
1. `get_node("/root/Main/JobBoard")` - simple but path-dependent
2. Store a reference on NPC initialization
3. Make JobBoard an autoload

Recommendation: Use stored reference set during NPC initialization, falling back to node path lookup. This balances testability with simplicity.

### Item Handoff from NPC to JobBoard
Currently, `_finish_job()` has direct access to `held_items`. After refactoring:
- NPC passes `self` to `complete_job()`
- JobBoard accesses items via `agent.held_items` (already done in existing `_handle_item_consumption`)
- JobBoard handles consumption/dropping
- NPC clears its `held_items` array after `complete_job()` returns

### Station Output Slot Handling
The existing `_spawn_outputs()` in JobBoard handles this:
- Places items in station output slots if available
- Falls back to ground placement near station
- Sets correct item state based on tag (e.g., "cooked" state)

### Existing Recipe Step Transforms
Note: Step transforms (e.g., `raw_meat` -> `cooked_meat`) happen during work steps via `_apply_step_transforms()`. This is separate from final output spawning and should not be affected by this refactor.

## Success Metrics

- Cooking a meal produces a `cooked_meal` item at the station
- Eating a meal consumes the item and satisfies hunger
- No motive satisfaction occurs from cooking alone
- All existing job completion tests pass
- No duplicate code for motive effects or item consumption between NPC and JobBoard

## Open Questions

1. **Job scope and ownership model:** Should Jobs/Recipes have `scope` and `kind` properties?
   - **Scope:** `PUBLIC` (any NPC can claim) vs `PRIVATE` (owner-only claim)
   - **Kind:** `PRODUCTION` vs `CONSUMPTION` (or similar taxonomy)
   
   This would elegantly solve consumption job discovery: when an NPC produces a `cooked_meal`, they could auto-post a PRIVATE consumption job that only they can claim. Alternatively, consumption jobs could be PUBLIC so any hungry NPC can grab available food.
   
   This also enables scenarios like:
   - Private crafting projects (NPC builds something for themselves)
   - Shared household chores (PUBLIC cleaning jobs)
   - Personal meals vs communal cooking
   
   **Recommendation:** Consider this as a follow-up PRD if the basic pipeline works well. The current implementation can work without it (NPCs will compete for food items via existing job claiming), but scope/kind would add intentionality.

2. **Tool handling** - Deferred to future PRD. This includes: where tools come from, where they go after use, sharing between NPCs, tool requirements for recipes. For now, tool requirements removed from recipes.
