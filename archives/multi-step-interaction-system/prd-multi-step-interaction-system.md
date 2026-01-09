# PRD: Multi-Step Interaction System

## Introduction

Evolve the current simple "Object -> Need" interaction system into a complex, multi-step behavior system. Currently, agents find a single object (bed, fridge, toilet) that advertises one motive, reserve it, interact for a duration, and fulfill the need. The new system will support sequences of steps involving multiple objects, physical item handling, hauling logistics, and interruptible/resumable tasks.

**Example interactions this enables:**
- Cook Meal: Take food from fridge -> find counter -> prep food -> put in pot -> place on stove -> wait -> eat
- Use Toilet: Sit on toilet -> use toilet paper -> flush -> wash hands at sink
- Watch TV: Walk to TV -> turn on -> walk to couch -> sit -> zap channels -> watch -> turn off

## Goals

- Create a single, generalized interaction system that handles all object interactions
- Support multi-step sequences with different objects at each step
- Implement physical item tracking (items exist in world, can be dropped/picked up)
- Support containers (bins/chests) that hold multiple items
- Enable partial progress - interrupted tasks leave items in place, resumable by any agent
- Implement full logistics: stockpiles, hauling jobs, reservations
- Hybrid architecture: agents have needs that generate jobs, agents claim and execute jobs
- Data-driven: new interactions defined via configuration, not code

## User Stories

### US-001: Define Interaction Recipes as Data
**Description:** As a developer, I want to define interaction sequences in data files so that I can add new interactions without writing code.

**Acceptance Criteria:**
- [ ] Create a `Recipe` resource type that defines an interaction sequence
- [ ] Recipe contains: name, required inputs (items/tools), steps, outputs, motive effects
- [ ] Recipes are loadable from `.tres` or JSON files
- [ ] At least 3 example recipes created (cooking, toilet, TV watching)

### US-002: Physical Item Entities
**Description:** As a developer, I need items to exist as physical entities in the world so that logistics and interruption work correctly.

**Acceptance Criteria:**
- [ ] Create `ItemEntity` class with properties: item_id, item_tag, state, reserved_by, location
- [ ] Items can be: in a stockpile/container, in agent hand, in a station slot, or on the ground
- [ ] Items persist when dropped (agent interrupted mid-task)
- [ ] Items can change state (Raw -> Prepped -> Cooked)

### US-003: Container System (Bins/Chests/Stockpiles)
**Description:** As a player, I want containers that hold multiple items so that my base has organized storage.

**Acceptance Criteria:**
- [ ] Create `Container` class that can hold multiple `ItemEntity` references
- [ ] Containers have capacity limits
- [ ] Containers can filter by item tags (e.g., "food only" fridge)
- [ ] Agents can query "find item with tag X in any container"

### US-004: Smart Station Component
**Description:** As a developer, I need objects like stoves, toilets, and TVs to be "smart stations" with slots and interaction points.

**Acceptance Criteria:**
- [ ] Create `Station` class with: station_tag, input_slots, output_slots, agent_footprint
- [ ] Stations can hold items in their slots
- [ ] Stations track reservation state (which agent is using it)
- [ ] Stations expose the position where an agent should stand

### US-005: Job Posting System (Hybrid Architecture)
**Description:** As a developer, I need a global job system where agent needs generate jobs and agents claim them.

**Acceptance Criteria:**
- [ ] Create `Job` class with: recipe_ref, priority, claimed_by, state, progress
- [ ] Agents with needs above threshold generate jobs for recipes that fulfill those needs
- [ ] Jobs are posted to a global `JobBoard` that agents can query
- [ ] Agents claim jobs, preventing others from taking them
- [ ] Unclaimed jobs can be claimed by any capable agent

### US-006: Requirement Checking Phase
**Description:** As an agent, before starting a job I need to verify all requirements are available so I don't get stuck.

**Acceptance Criteria:**
- [ ] Job system checks: required items exist in accessible containers
- [ ] Job system checks: required stations are available (not reserved)
- [ ] Job system checks: required tools are available
- [ ] If requirements not met, job remains posted but agent looks for other jobs

### US-007: Hauling/Gathering Phase
**Description:** As an agent, I need to gather all required items before starting the main interaction.

**Acceptance Criteria:**
- [ ] Agent generates sub-tasks: MoveTo(container) -> PickUp(item) for each required input
- [ ] Items are reserved when agent commits to hauling them
- [ ] Agent carries items to the station before starting work
- [ ] Multiple hauling trips supported if agent can only carry limited items

### US-008: Work Execution Phase
**Description:** As an agent, I execute the recipe steps at the station, transforming inputs into outputs.

**Acceptance Criteria:**
- [ ] Agent moves through recipe steps sequentially
- [ ] Each step has: target station tag, animation, duration
- [ ] Items transform according to step definition (Raw -> Prepped)
- [ ] Progress is tracked per-step and overall

### US-009: Interruption and Resumption
**Description:** As an agent, if I'm interrupted mid-task, the items remain in place and another agent can resume.

**Acceptance Criteria:**
- [ ] When interrupted: agent drops held items at current location
- [ ] Job state updates to "interrupted" with current step saved
- [ ] Items at stations remain in their slots
- [ ] Another agent can claim the interrupted job and resume from current step
- [ ] Reservations are released when agent is interrupted

### US-010: Cleanup/Consumption Phase
**Description:** As an agent, after completing work I consume outputs or store them appropriately.

**Acceptance Criteria:**
- [ ] Output items are spawned at station output slot
- [ ] If recipe has motive effects, agent consumes output and gains motive
- [ ] Used tools remain (possibly in "dirty" state creating new jobs)
- [ ] Byproducts (e.g., dirty dishes) spawn and need cleanup jobs

### US-011: Example Recipe - Cooking
**Description:** As a player, I want agents to cook meals with realistic multi-step logistics.

**Acceptance Criteria:**
- [ ] Recipe defined: get food from fridge -> prep at counter -> cook on stove -> eat at table
- [ ] Food item transforms through states: Raw -> Prepped -> Cooked -> (consumed)
- [ ] Pot/pan as reusable tool that becomes dirty after use
- [ ] Hunger motive fulfilled at end

### US-012: Example Recipe - Toilet Use
**Description:** As a player, I want agents to use toilet with realistic steps.

**Acceptance Criteria:**
- [ ] Recipe defined: sit on toilet -> use toilet paper -> flush -> wash hands at sink
- [ ] Toilet paper consumed (1 unit per use)
- [ ] Toilet becomes "dirty" state over time (generates cleaning job)
- [ ] Bladder motive fulfilled

### US-013: Example Recipe - Watch TV
**Description:** As a player, I want agents to watch TV with channel surfing behavior.

**Acceptance Criteria:**
- [ ] Recipe defined: turn on TV -> walk to couch -> sit -> watch (with zapping sub-animation)
- [ ] TV station and Couch station linked in recipe
- [ ] Entertainment motive fulfilled over time while watching
- [ ] TV can be turned off by another agent wanting different channel (stretch goal)

## Functional Requirements

- FR-1: The system must support defining interaction recipes as data (Resource or JSON)
- FR-2: Recipes must specify: inputs (items/tools), sequence of steps, outputs, motive effects
- FR-3: Each step must define: target station tag, action type, duration, animation, item transformations
- FR-4: Items must exist as physical nodes in the scene tree with position, state, and reservation
- FR-5: Containers must support multiple items with capacity limits and tag filters
- FR-6: Stations must have slots for items and a defined agent interaction point
- FR-7: A global JobBoard must track all available, claimed, and completed jobs
- FR-8: Agents must be able to query the JobBoard for jobs matching their needs
- FR-9: Before starting a job, all requirements (items, stations, tools) must be validated
- FR-10: Agents must haul required items to the work station before executing steps
- FR-11: Items must be reserved when an agent commits to using them
- FR-12: Job progress must persist across interruptions
- FR-13: Interrupted jobs must be resumable by any capable agent
- FR-14: Output items must spawn at station output slots upon step completion
- FR-15: Motive changes must apply only upon successful recipe completion
- FR-16: Used tools must persist and potentially change state (clean -> dirty)

## Non-Goals (Out of Scope)

- Agent skills/labor specialization (all agents can do all jobs for now)
- Electricity or resource consumption as prerequisites
- Job priorities beyond need-based urgency
- Pathfinding improvements (assume existing pathfinding works)
- UI for viewing job queue or agent task status
- Multiplayer synchronization
- Save/load of in-progress jobs (can be added later)

## Design Considerations

### Recipe Data Structure
```gdscript
class_name Recipe extends Resource

@export var recipe_name: String
@export var inputs: Array[RecipeInput]  # {item_tag, quantity, consumed}
@export var tools: Array[String]  # tool tags required but not consumed
@export var steps: Array[RecipeStep]  # sequence of steps
@export var outputs: Array[RecipeOutput]  # {item_tag, quantity}
@export var motive_effects: Dictionary  # {"hunger": 50, "bladder": -10}
```

### RecipeStep Data Structure
```gdscript
class_name RecipeStep extends Resource

@export var station_tag: String  # e.g., "stove", "counter", "toilet"
@export var action: String  # e.g., "cook", "prep", "sit"
@export var duration: float  # seconds
@export var animation: String  # animation to play
@export var input_transform: Dictionary  # {"raw_meat": "cooked_meat"}
```

### Job States
- `POSTED`: Job available, no agent claimed it
- `CLAIMED`: Agent has claimed, gathering requirements
- `IN_PROGRESS`: Agent is executing steps
- `INTERRUPTED`: Agent was interrupted, job can be resumed
- `COMPLETED`: Job finished successfully
- `FAILED`: Job cannot be completed (missing requirements permanently)

### Item Locations
- `IN_CONTAINER`: Item is in a bin/chest/stockpile
- `IN_HAND`: Agent is carrying the item
- `IN_SLOT`: Item is in a station slot (stove, counter)
- `ON_GROUND`: Item was dropped (interruption or explicit)

## Technical Considerations

- Godot 4.x with GDScript
- Use Godot's Resource system for recipes (`.tres` files) for editor integration
- Items should be nodes in the scene tree for physics/visibility
- Consider using signals for job state changes and item pickups
- Agent state machine will need new states: HAULING, WORKING, INTERRUPTED
- Existing need/motive system will trigger job creation

## Success Metrics

- All existing interactions (bed, fridge, toilet, shower, TV) reimplemented using new system
- Adding a new 5-step interaction requires only creating a Recipe resource, no code
- Interrupting an agent mid-cook leaves food on stove, another agent can resume
- Agents visibly haul items from containers to stations before working
- System handles 50+ concurrent jobs without performance issues

## Open Questions

1. Should agents have carry capacity (1 item vs multiple)?
2. How do we handle "optional" steps (e.g., wash hands after toilet is optional)?
3. Should tools be explicitly picked up, or automatically available if nearby?
4. How do we prioritize between multiple jobs satisfying the same need?
5. Should containers auto-generate "restock" jobs when empty?
6. How do we handle recipes requiring multiple agents (stretch goal)?
