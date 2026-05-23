# State Verification 2026-05-22 — Phase 5

## What Changed

1. **MythMemory** — already removed from autoload (done in prior session); completed migration:
   - 3 `static func` converted to instance methods: `register_rebirth_success`, `get_region_myth_state`, `get_conflict_intensity`
   - Removed `_get_instance()` (dead code after static→instance conversion)
   - Removed `class_name MythMemory` — no external code references it by class name

2. **MemoryManager** — added forwarding methods:
   - `register_myth_rebirth_success(center_rk)` → delegates to MythMemory
   - `get_myth_conflict_intensity(region_key)` → delegates to MythMemory

3. **Call sites updated** (8 references across 6 files):
   - `MythMemory.register_rebirth_success()` → `MemoryManager.register_myth_rebirth_success()`
   - `MythMemory.get_region_myth_state()` → `MemoryManager.get_region_myth_state()`
   - `MythMemory.get_conflict_intensity()` → `MemoryManager.get_myth_conflict_intensity()`

## What Was Verified

- All `MythMemory.` code references replaced with `MemoryManager.` equivalents
- No `class_name MythMemory` reference used externally (removed)
- MythMemory no longer uses `Engine.get_main_loop()/SceneTree` for self-lookup

## What Remains Unverified

- No Godot binary — runtime smoke tests blocked
- Cannot verify lazy-loading or forwarding works at runtime
