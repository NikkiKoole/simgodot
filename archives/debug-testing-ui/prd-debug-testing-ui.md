# Debug & Testing UI System PRD

## Overview

A development-focused UI system that allows manual inspection and manipulation of the game world to test the multi-step interaction system. The UI provides visibility into NPC behavior, job states, item locations, and world configuration without requiring code changes.

## Goals

1. **Inspect** - See what's happening: NPC states, job progress, item locations, station contents
2. **Manipulate** - Trigger behaviors: spawn items, adjust motives, post jobs, interrupt jobs
3. **Configure** - Edit world layout: place stations, paint walls, set up test scenarios
4. **Observe** - Watch the systems work: NPC hauling items, cooking when hungry, job completion

## Non-Goals

- Player-facing UI (this is dev-only)
- Performance optimization (clarity over efficiency)
- Multiple selection / batch operations (not needed yet)
- Undo system (not needed yet)

---

## Architecture

### UI Layout

```
+--------------------------------------------------+
|  [Game World View]                    | Side     |
|                                       | Panel    |
|   (click entities to select)          |----------|
|                                       | Inspector|
|                                       | - NPC    |
|                                       | - Station|
|                                       | - Item   |
|                                       |----------|
|                                       | Tools    |
|                                       | - Spawn  |
|                                       | - Paint  |
|                                       | - Jobs   |
+--------------------------------------------------+
|  [Bottom Bar: JobBoard Status / Quick Actions]   |
+--------------------------------------------------+
```

### Core Principles

1. **Always Visible** - No toggle needed during dev phase
2. **Click to Select** - Left-click any entity to inspect it
3. **Context Actions** - Right-click for entity-specific actions
4. **Side Panel Tools** - Persistent tool palette for world manipulation
5. **Non-Modal** - Never blocks game simulation

---

## User Stories

### Phase 1: Inspection (Read-Only)

#### US-001: Select and Inspect NPC
**As a** developer  
**I want to** click on an NPC to see their current state  
**So that** I can understand what they're doing and why

**Acceptance Criteria:**
- Left-clicking an NPC highlights them with a selection indicator
- Side panel shows NPC inspector with:
  - Name/ID
  - Current state (IDLE, WALKING, WORKING, HAULING, etc.)
  - Current job (if any) with recipe name and step index
  - Held item (if any)
  - Motive bars (hunger, bladder, fun, energy, hygiene)
  - Current target position/object
- Selection persists until another entity is selected or clicked elsewhere

#### US-002: Select and Inspect Station
**As a** developer  
**I want to** click on a station to see its contents and state  
**So that** I can verify items are being placed correctly

**Acceptance Criteria:**
- Left-clicking a station highlights it
- Side panel shows station inspector with:
  - Station name and tags
  - Slot contents (list of items in each slot)
  - Current user (NPC using this station, if any)
  - Available capacity
- Visual overlay on station showing slot positions

#### US-003: Select and Inspect Item
**As a** developer  
**I want to** click on an item to see its properties  
**So that** I can track items through the system

**Acceptance Criteria:**
- Left-clicking an item (on ground, in container, held) highlights it
- Side panel shows item inspector with:
  - Item tag/type
  - Current location (ON_GROUND, IN_CONTAINER, AT_STATION, HELD_BY_NPC)
  - Container/station/NPC reference if applicable
  - Item state (if any)

#### US-004: View JobBoard Status
**As a** developer  
**I want to** see all jobs and their states at a glance  
**So that** I can monitor job flow through the system

**Acceptance Criteria:**
- Bottom bar shows JobBoard summary:
  - Count of jobs by state (POSTED, CLAIMED, IN_PROGRESS, INTERRUPTED, COMPLETED, FAILED)
- Clicking the bar expands to show job list
- Each job shows: recipe name, state, assigned NPC, current step
- Can click a job to select the assigned NPC

#### US-005: Inspect Container Contents
**As a** developer  
**I want to** click on a container (fridge, cabinet) to see what's inside  
**So that** I can verify item storage

**Acceptance Criteria:**
- Left-clicking a container highlights it
- Side panel shows container inspector with:
  - Container name and tags
  - List of contained items with their tags
  - Capacity used / total

---

### Phase 2: Manipulation (Write Actions)

#### US-006: Spawn Items
**As a** developer  
**I want to** spawn items into the world  
**So that** I can set up test scenarios

**Acceptance Criteria:**
- Tool panel has "Spawn Item" section
- Dropdown/list of available item tags:
  - raw_food
  - toilet_paper
  - remote
  - cooked_meal
  - prepped_food
- Click location in world to spawn selected item ON_GROUND
- Or click container/station to spawn item inside it
- Visual feedback on spawn

#### US-007: Adjust NPC Motives
**As a** developer  
**I want to** manually adjust NPC motive values  
**So that** I can trigger specific behaviors (hunger -> cooking)

**Acceptance Criteria:**
- When NPC is selected, inspector shows editable motive sliders
- Can drag slider to set motive value (0-100)
- Changes apply immediately
- Quick buttons: "Make Hungry" (hunger=10), "Make Full" (hunger=100), etc.

#### US-008: Force NPC State
**As a** developer  
**I want to** force an NPC into a specific state  
**So that** I can test state transitions

**Acceptance Criteria:**
- When NPC is selected, context menu (right-click) offers:
  - "Go Idle" - cancel current activity
  - "Drop Item" - if holding something
  - "Interrupt Job" - if working on a job
- Actions execute immediately with visual feedback

#### US-009: Post Jobs Manually
**As a** developer  
**I want to** manually post jobs to the JobBoard  
**So that** I can test job claiming and execution

**Acceptance Criteria:**
- Tool panel has "Post Job" section
- Dropdown of available recipes:
  - Cook Simple Meal
  - Use Toilet
  - Watch TV
- "Post" button adds job with POSTED state
- Confirmation shown in bottom bar

#### US-010: Interrupt and Resume Jobs
**As a** developer  
**I want to** manually interrupt or resume jobs  
**So that** I can test the interruption system

**Acceptance Criteria:**
- When job is selected (via JobBoard panel):
  - "Interrupt" button (if IN_PROGRESS)
  - Job state updates to INTERRUPTED
  - NPC releases the job
- Any NPC can then claim the interrupted job

---

### Phase 3: World Configuration

#### US-011: Place Stations at Runtime
**As a** developer  
**I want to** place stations in the world without editing the ASCII map  
**So that** I can quickly set up test layouts

**Acceptance Criteria:**
- Tool panel has "Place Station" section
- List of station types:
  - Counter (tag: counter)
  - Stove (tag: stove)
  - Sink (tag: sink)
  - Toilet (existing scene)
  - TV (existing scene)
  - Couch (tag: couch, seating)
  - Fridge (container, tag: fridge)
  - Generic Station (custom tags)
- Click to place at location
- Stations snap to grid
- Can right-click placed station to remove

#### US-012: Paint Walls at Runtime
**As a** developer  
**I want to** paint/erase walls in the world  
**So that** I can modify pathfinding layouts quickly

**Acceptance Criteria:**
- Tool panel has "Wall Paint" mode
- Click to toggle wall at grid position
- Or drag to paint/erase multiple walls
- Navigation mesh updates automatically
- ASCII map file is NOT modified (runtime only)

#### US-013: Configure Station Tags
**As a** developer  
**I want to** edit a station's tags after placement  
**So that** I can make it work with different recipes

**Acceptance Criteria:**
- When station is selected, inspector shows editable tags
- Can add/remove tags
- Common tag suggestions shown (counter, stove, sink, seating, etc.)

#### US-014: Spawn NPC
**As a** developer  
**I want to** spawn additional NPCs  
**So that** I can test multi-agent scenarios

**Acceptance Criteria:**
- Tool panel has "Spawn NPC" button
- Click location to spawn NPC at that position
- NPC starts in IDLE state with default motives
- Can customize initial motive values before spawn

---

### Phase 4: Observation Aids

#### US-015: Visualize NPC Paths
**As a** developer  
**I want to** see the path an NPC is following  
**So that** I can debug navigation issues

**Acceptance Criteria:**
- When NPC is selected, their current path is drawn as a line
- Path points shown as dots
- Current target shown as highlighted point
- Path updates in real-time as NPC moves

#### US-016: Visualize Item Flow
**As a** developer  
**I want to** see items being transported  
**So that** I can verify hauling behavior

**Acceptance Criteria:**
- Items being carried by NPCs have a visual indicator
- Optional: trail showing where item has been
- Item tag shown as floating label

#### US-017: Job Progress Timeline
**As a** developer  
**I want to** see a timeline of job events  
**So that** I can understand job flow

**Acceptance Criteria:**
- Optional panel showing recent job events:
  - "[NPC] claimed [Job]"
  - "[NPC] started step 2 of [Recipe]"
  - "[Job] was interrupted"
  - "[NPC] completed [Job]"
- Events timestamped
- Can click event to select related NPC/Job

#### US-018: Station Slot Visualization
**As a** developer  
**I want to** see station slot positions and contents visually  
**So that** I can verify item placement

**Acceptance Criteria:**
- When station is selected, slots shown as overlay
- Empty slots shown as dotted outlines
- Occupied slots show item icon/label
- Slot indices labeled

---

## Technical Requirements

### Required Stations (Gap Analysis)

The following stations are required by existing recipes but don't have dedicated scenes:

| Station Tag | Required By | Solution |
|-------------|-------------|----------|
| counter | cook_simple_meal (prep step) | Create station.tscn instance with tag "counter" |
| stove | cook_simple_meal (cook step) | Create station.tscn instance with tag "stove" |
| sink | use_toilet (wash_hands step) | Create station.tscn instance with tag "sink" |
| couch | watch_tv (implied seating) | Create station.tscn instance with tags "couch", "seating" |

Existing dedicated scenes: toilet.tscn, tv.tscn, fridge.tscn

### Required Items (Gap Analysis)

| Item Tag | Purpose | Spawn Location |
|----------|---------|----------------|
| raw_food | Input for cooking | Fridge container, or spawn on ground |
| toilet_paper | Input for toilet use | Cabinet container, or spawn in bathroom |
| remote | Tool for TV | Near couch, or spawn on ground |
| prepped_food | Intermediate cooking state | Created by prep step |
| cooked_meal | Output of cooking | Created by cook step |

### Implementation Notes

1. **Selection System**: Use Godot's `_input_event` or raycast from camera to detect clicks on entities with collision shapes.

2. **Inspector Panel**: CanvasLayer with Control nodes, updates when selection changes.

3. **Entity Highlighting**: Shader or modulate color change on selected entity.

4. **Runtime Station Placement**: Instantiate station.tscn, configure tags, add to scene tree.

5. **Wall Painting**: Modify TileMap or collision shape array, regenerate navmesh.

6. **Job Event Log**: Subscribe to JobBoard signals, maintain rolling buffer of events.

---

## UI Component Hierarchy

```
DebugUI (CanvasLayer)
├── SidePanel (PanelContainer)
│   ├── InspectorSection (VBoxContainer)
│   │   ├── NPCInspector (Control) [shown when NPC selected]
│   │   ├── StationInspector (Control) [shown when station selected]
│   │   ├── ItemInspector (Control) [shown when item selected]
│   │   └── ContainerInspector (Control) [shown when container selected]
│   └── ToolsSection (VBoxContainer)
│       ├── SpawnItemTool (Control)
│       ├── PlaceStationTool (Control)
│       ├── WallPaintTool (Control)
│       ├── PostJobTool (Control)
│       └── SpawnNPCTool (Control)
├── BottomBar (PanelContainer)
│   ├── JobBoardSummary (HBoxContainer)
│   └── JobListExpanded (ScrollContainer) [toggled]
├── SelectionHighlight (Node2D) [follows selected entity]
└── PathVisualization (Node2D) [draws NPC paths]
```

---

## Phased Implementation

### Phase 1: Inspection Foundation
- US-001 through US-005
- Core selection system
- Inspector panels for NPC, Station, Item, Container
- JobBoard status display

### Phase 2: Basic Manipulation
- US-006 through US-010
- Item spawning
- Motive adjustment
- Job posting and interruption

### Phase 3: World Editing
- US-011 through US-014
- Station placement
- Wall painting
- NPC spawning

### Phase 4: Visualization
- US-015 through US-018
- Path visualization
- Item flow tracking
- Event timeline

---

## Success Metrics

1. Can set up a cooking scenario in < 1 minute:
   - Place counter and stove
   - Spawn raw_food in fridge
   - Set NPC hunger to low
   - Watch NPC autonomously cook

2. Can test interruption flow:
   - Post cooking job
   - Watch NPC claim and start
   - Interrupt mid-cooking
   - Watch second NPC resume

3. Can debug navigation issues:
   - See NPC path visualized
   - Identify stuck points
   - Paint/unpaint walls to fix

---

## Persistence: Test Scenario Files

Runtime station placements and world configurations should be saveable to test scenario files. This enables:

1. **Repeatable Test Setups** - Save a configured world state, reload it later
2. **Sharing Scenarios** - Export scenario files for team members or bug reports
3. **Automated Loading** - Load scenarios programmatically for specific tests

### Scenario File Format

```json
{
  "name": "cooking_test_scenario",
  "description": "Counter, stove, fridge with raw_food, hungry NPC",
  "stations": [
    {"type": "counter", "position": [100, 200], "tags": ["counter"]},
    {"type": "stove", "position": [150, 200], "tags": ["stove"]},
    {"type": "fridge", "position": [50, 200], "tags": ["fridge", "container"]}
  ],
  "items": [
    {"tag": "raw_food", "location": "container", "container_index": 0}
  ],
  "npcs": [
    {"position": [200, 300], "motives": {"hunger": 10, "bladder": 80, "fun": 50}}
  ],
  "walls": [
    [0, 0], [1, 0], [2, 0]
  ]
}
```

### Scenario Operations

- **Save Current** - Export current runtime state to JSON file
- **Load Scenario** - Apply scenario file to current world (additive or replace)
- **Quick Save Slots** - 3 quick-save slots for rapid iteration

---

## Testing Strategy

The Debug UI must be built with testability as a core principle. While the visual UI requires mouse interaction, all underlying functionality should be exposed through testable APIs.

### Architecture for Testability

```
┌─────────────────────────────────────────────────────────┐
│                    Debug UI (Visual)                     │
│  - Mouse input handling                                  │
│  - Visual rendering (highlights, overlays)               │
│  - Panel layout and widgets                              │
└─────────────────────────────────────────────────────────┘
                          │ calls
                          ▼
┌─────────────────────────────────────────────────────────┐
│                  DebugCommands (API)                     │
│  - select_entity(entity)                                 │
│  - spawn_item(tag, position_or_container)                │
│  - spawn_station(type, position, tags)                   │
│  - spawn_npc(position, motives)                          │
│  - set_npc_motive(npc, motive, value)                    │
│  - post_job(recipe)                                      │
│  - interrupt_job(job)                                    │
│  - paint_wall(position, add_or_remove)                   │
│  - save_scenario(path)                                   │
│  - load_scenario(path)                                   │
│  - get_inspection_data(entity) -> Dictionary             │
└─────────────────────────────────────────────────────────┘
                          │ uses
                          ▼
┌─────────────────────────────────────────────────────────┐
│              Game Systems (Already Testable)             │
│  - JobBoard, NPC, Station, ItemEntity, etc.              │
└─────────────────────────────────────────────────────────┘
```

### What Can Be Tested Headlessly

| Feature | Testable Headless? | Test Approach |
|---------|-------------------|---------------|
| Item spawning | Yes | Call `DebugCommands.spawn_item()`, verify item exists |
| Station spawning | Yes | Call `DebugCommands.spawn_station()`, verify in scene tree |
| NPC spawning | Yes | Call `DebugCommands.spawn_npc()`, verify NPC exists |
| Motive adjustment | Yes | Call `DebugCommands.set_npc_motive()`, verify value changed |
| Job posting | Yes | Call `DebugCommands.post_job()`, verify in JobBoard |
| Job interruption | Yes | Call `DebugCommands.interrupt_job()`, verify state |
| Wall painting | Yes | Call `DebugCommands.paint_wall()`, verify collision/navmesh |
| Scenario save/load | Yes | Save scenario, load it, verify world state matches |
| Inspection data | Yes | Call `DebugCommands.get_inspection_data()`, verify dictionary |
| Entity selection | Partially | API works, but visual highlight needs visual test |
| Click-to-select | No | Requires mouse input simulation or visual test |
| Visual overlays | No | Requires visual verification |
| Panel rendering | No | Requires visual verification |

### Test Files Structure

```
scripts/tests/
├── test_debug_commands.gd        # Tests for DebugCommands API
├── test_debug_scenarios.gd       # Tests for scenario save/load
└── test_debug_inspection.gd      # Tests for inspection data accuracy

scenes/tests/
├── test_debug_commands.tscn
├── test_debug_scenarios.tscn
└── test_debug_inspection.tscn
```

### Example Test Cases

#### test_debug_commands.gd

```gdscript
# US-006: Spawn Items
func test_spawn_item_on_ground():
    var item = DebugCommands.spawn_item("raw_food", Vector2(100, 100))
    assert(item != null, "Item should be spawned")
    assert(item.item_tag == "raw_food", "Item tag should match")
    assert(item.location_state == ItemEntity.LocationState.ON_GROUND)

func test_spawn_item_in_container():
    var container = _create_test_container()
    var item = DebugCommands.spawn_item("raw_food", container)
    assert(item.location_state == ItemEntity.LocationState.IN_CONTAINER)
    assert(container.get_items().has(item))

# US-007: Adjust NPC Motives
func test_set_npc_motive():
    var npc = _create_test_npc()
    DebugCommands.set_npc_motive(npc, "hunger", 25.0)
    assert(npc.motives.hunger == 25.0, "Motive should be updated")

# US-011: Place Stations
func test_spawn_station():
    var station = DebugCommands.spawn_station("counter", Vector2(200, 200), ["counter"])
    assert(station != null, "Station should be spawned")
    assert(station.tags.has("counter"), "Station should have counter tag")
    assert(station.global_position == Vector2(200, 200))

# US-012: Wall Painting
func test_paint_wall():
    var grid_pos = Vector2i(5, 5)
    DebugCommands.paint_wall(grid_pos, true)  # Add wall
    assert(_is_wall_at(grid_pos), "Wall should exist")
    DebugCommands.paint_wall(grid_pos, false)  # Remove wall
    assert(not _is_wall_at(grid_pos), "Wall should be removed")
```

#### test_debug_scenarios.gd

```gdscript
func test_save_and_load_scenario():
    # Setup world state
    var station = DebugCommands.spawn_station("stove", Vector2(100, 100), ["stove"])
    var item = DebugCommands.spawn_item("raw_food", Vector2(50, 50))
    var npc = DebugCommands.spawn_npc(Vector2(200, 200), {"hunger": 20})
    
    # Save scenario
    var path = "res://test_scenario_temp.json"
    DebugCommands.save_scenario(path)
    
    # Clear world
    station.queue_free()
    item.queue_free()
    npc.queue_free()
    await get_tree().process_frame
    
    # Load scenario
    DebugCommands.load_scenario(path)
    await get_tree().process_frame
    
    # Verify restored state
    var stations = get_tree().get_nodes_in_group("stations")
    assert(stations.size() == 1, "Station should be restored")
    assert(stations[0].tags.has("stove"), "Station tags should match")
    
    # Cleanup
    DirAccess.remove_absolute(path)

func test_scenario_with_items_in_containers():
    var fridge = DebugCommands.spawn_station("fridge", Vector2(100, 100), ["fridge", "container"])
    var item = DebugCommands.spawn_item("raw_food", fridge)
    
    var path = "res://test_scenario_container.json"
    DebugCommands.save_scenario(path)
    
    # Clear and reload
    _clear_world()
    DebugCommands.load_scenario(path)
    await get_tree().process_frame
    
    # Verify item is in container
    var containers = get_tree().get_nodes_in_group("containers")
    assert(containers[0].get_items().size() == 1)
    assert(containers[0].get_items()[0].item_tag == "raw_food")
    
    DirAccess.remove_absolute(path)
```

#### test_debug_inspection.gd

```gdscript
func test_inspect_npc():
    var npc = _create_test_npc()
    npc.motives.hunger = 30.0
    npc.state = NPC.State.IDLE
    
    var data = DebugCommands.get_inspection_data(npc)
    
    assert(data.has("type") and data.type == "npc")
    assert(data.has("state") and data.state == "IDLE")
    assert(data.has("motives"))
    assert(data.motives.hunger == 30.0)

func test_inspect_station():
    var station = DebugCommands.spawn_station("counter", Vector2(100, 100), ["counter"])
    var item = DebugCommands.spawn_item("raw_food", station)
    
    var data = DebugCommands.get_inspection_data(station)
    
    assert(data.type == "station")
    assert(data.tags.has("counter"))
    assert(data.slot_contents.size() > 0)
    assert(data.slot_contents[0].item_tag == "raw_food")

func test_inspect_item():
    var item = DebugCommands.spawn_item("cooked_meal", Vector2(50, 50))
    
    var data = DebugCommands.get_inspection_data(item)
    
    assert(data.type == "item")
    assert(data.item_tag == "cooked_meal")
    assert(data.location_state == "ON_GROUND")
```

### Test Coverage Goals

| User Story | Test Coverage Target |
|------------|---------------------|
| US-001 to US-005 (Inspection) | `get_inspection_data()` returns accurate data for all entity types |
| US-006 (Spawn Items) | All spawn locations tested (ground, container, station) |
| US-007 (Adjust Motives) | All motive types, boundary values (0, 100) |
| US-008 (Force NPC State) | State transitions, edge cases (already idle, no item to drop) |
| US-009 (Post Jobs) | All recipe types, verify JobBoard state |
| US-010 (Interrupt Jobs) | Interrupt from various states, verify state transitions |
| US-011 (Place Stations) | All station types, tag configuration |
| US-012 (Paint Walls) | Add/remove walls, navmesh updates |
| US-013 (Configure Tags) | Add/remove tags on existing stations |
| US-014 (Spawn NPC) | Default motives, custom motives |
| Scenario Save/Load | Round-trip all entity types, complex scenarios |

### Visual Testing (Manual Checklist)

For features that cannot be tested headlessly, maintain a manual test checklist:

- [ ] Click NPC - selection highlight appears
- [ ] Click Station - slots overlay visible
- [ ] Inspector panel updates on selection change
- [ ] Path visualization draws correctly
- [ ] Item flow indicators visible during hauling
- [ ] Job timeline updates in real-time
- [ ] Wall paint preview shows before click
