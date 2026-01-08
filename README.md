# SimGodot

A top-down 2D life simulation inspired by The Sims, built in Godot 4.5.

## Overview

SimGodot simulates autonomous NPCs driven by a motive system. NPCs navigate an apartment environment, interact with objects, and manage their needs. The game features a player-controlled character and up to 64 AI-controlled NPCs.

## Features

### Motive System

NPCs have 5 needs that decay over time:

| Motive | Decay Time | Fulfilled By |
|--------|------------|--------------|
| Hunger | ~4 hours | Fridge |
| Energy | ~16 hours | Bed |
| Bladder | ~6 hours | Toilet |
| Hygiene | ~12 hours | Shower |
| Fun | ~6.6 hours | TV, Computer, Bookshelf |

When a motive becomes critical (below -50), NPCs autonomously seek objects to fulfill that need.

### NPC AI

- **Pathfinding** - A* grid-based pathfinding with diagonal movement
- **Path Smoothing** - Line-of-sight optimization removes unnecessary waypoints
- **Steering** - Avoidance behavior around other NPCs
- **Stuck Detection** - Dynamic collision shrinking helps NPCs escape tight spaces
- **Object Reservation** - NPCs claim objects while pathfinding to prevent conflicts

### Game Clock

- 9 speed levels: 1x, 2x, 4x, 8x, 16x, 32x, 64x, 128x, 256x
- At 1x speed: 1 real second = 1 game minute
- Full 24-hour day = 24 real minutes at 1x

### Interactable Objects

- Bed (Energy)
- Fridge (Hunger)
- Toilet (Bladder)
- Shower (Hygiene)
- TV (Fun)
- Computer (Fun)
- Bookshelf (Fun)

## Controls

| Key | Action |
|-----|--------|
| W/A/S/D | Move player |
| E / Space | Interact with nearby object |
| + / - | Speed up / Slow down game |
| P | Pause / Unpause |
| ESC | Quit |

## Project Structure

```
simgodot/
├── scripts/
│   ├── level.gd              # World generation, NPC spawning
│   ├── npc.gd                # NPC AI, pathfinding, motive management
│   ├── player.gd             # Player controller
│   ├── motive.gd             # Motive system
│   ├── interactable_object.gd # Object interaction base class
│   ├── game_clock.gd         # Time system and speed control
│   ├── motive_bars.gd        # Motive visualization UI
│   ├── camera.gd             # Camera following
│   └── clock_ui.gd           # Clock display UI
│
├── scenes/
│   ├── main.tscn             # Main scene
│   ├── player.tscn           # Player
│   ├── npc.tscn              # NPC template
│   └── objects/              # Interactable objects
│       ├── bed.tscn
│       ├── fridge.tscn
│       ├── toilet.tscn
│       ├── shower.tscn
│       ├── tv.tscn
│       ├── computer.tscn
│       └── bookshelf.tscn
│
└── project.godot             # Godot project config
```

## Requirements

- Godot 4.5+

## Running

Open the project in Godot and press F5 to run.
