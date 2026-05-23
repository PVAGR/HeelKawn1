# State Verification 2026-05-22 — Phase 6

## What Changed

### SacredMemory → MemoryManager (lazy-loaded child)
- 4 static→instance methods: `site_count()`, `list_sites_sorted(max_n)`, `is_tile_sacred(tile_pos)`, `get_sacred_type_at(x, y)`
- All 4 used `Engine.get_singleton("SacredMemory")` which was always null (broken) — now instance methods work
- 6 call sites updated: ReligionLens (5 refs), FragmentationManager (1 ref), Main.gd (1 ref)
- Removed `class_name SacredMemory`

### FactionRegistry → FactionManager (lazy-loaded child)
- 2 static→instance methods: `sync_from_settlements()`, `append_focus_house_lines(out, center_region)`
- Both used `Engine.get_singleton("FactionRegistry")` which was always null — now instance methods work
- 2 call sites updated: ReligionLens (1 ref), ObservationAPI (1 ref)
- `_relation_pair_key` preserved as `static func` (pure utility, no singleton dependency)
- Removed `class_name FactionRegistry`

## What Was Verified
- No `SacredMemory.` or `FactionRegistry.` code references remain
- No `class_name SacredMemory` or `class_name FactionRegistry` references used externally
- Callers now route through `MemoryManager.get_sacred_memory()` and `FactionManager.get_faction_registry()`

## What Else Was Found (not fixed — structural bugs)
- `MemoryManager.record_sacred_site()` calls `_sacred_memory.record_sacred_site()` — method does NOT exist on SacredMemory
- `FactionManager.register_faction()` calls `_faction_registry.register_faction()` — method does NOT exist
- `FactionManager.get_faction(faction_id: int)` calls `_faction_registry.get_faction(faction_id)` — method does NOT exist
- `FactionManager.get_synced_house_count()` calls `_faction_registry.get_house_count()` — actual method is `get_synced_house_count`
- These are dormant stubs (no external callers discovered)

## What Remains Unverified
- No Godot binary — runtime smoke tests blocked
- Instance method delegation from MemoryManager/FactionManager to child nodes untested at runtime
