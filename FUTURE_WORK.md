# Future Work

A collection of deferred enhancements and nice-to-have features identified during development.

## Code Quality

- [ ] Extract BaseInspector class to reduce duplication across npc_inspector, station_inspector, item_inspector, container_inspector
- [ ] Add comments to private helper methods in complex scripts
- [ ] Minor issues: magic numbers, null check consistency

## Features

- [ ] Multi-tag support for stations (would require changes to Station, RecipeStep matching, save/load)
- [ ] Dirty state tracking for tools/stations
- [ ] Automatic cleanup job generation from dirty items
- [ ] TV channel conflict between agents

## Content

- [ ] Make PostJobTool load recipes dynamically from RecipeRegistry instead of hardcoding
- [ ] Add more example recipes (cleaning, laundry, etc.)
