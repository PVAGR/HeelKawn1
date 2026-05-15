# TickManager Implementation Summary

## Overview
Implemented a deterministic TickManager system to fix rubber-banding issues in HeelKawn.

## Files Created
1. `autoloads/TickManager.gd` - Central tick manager with:
   - Fixed-step accumulation loop
   - Speed multipliers (0.5x, 1x, 4x, 16x, 64x)
   - Pause/Resume without losing state
   - Calls `_on_world_tick()` on all "tickable" nodes
   - Supports RefCounted tickables via `register_refcounted_tickable()`

2. `scripts/ui/SpeedControlUI.gd` - UI for speed control
3. `scenes/ui/SpeedControlUI.tscn` - Scene file for the UI

## Files Modified
1. `autoloads/WorldMemory.gd` - Already had tickable group and _on_world_tick()
2. `autoloads/JobManager.gd` - Already had tickable group and _on_world_tick()
3. `scripts/pawn/Pawn.gd` - Already had tickable group and _on_world_tick(), connects to TickManager
4. `scripts/ai/SettlementAI.gd` - Added _on_world_tick() method
5. `autoloads/AIAgentManager.gd` - Added _on_world_tick() to SettlementAIShim class
6. `autoloads/GameManager.gd` - Defers to TickManager for tick processing

## How to Use
1. Add SpeedControlUI to your main scene
2. Configure button connections (already set up in the .tscn file)
3. TickManager is automatically registered as an autoload (see project.godot)

## Speed Controls
- Pause: Pauses the game
- 0.5x: Half speed
- 1x: Normal speed (1 tick per second)
- 4x: Fast speed
- 16x: Very fast
- 64x: Ultra fast

## Technical Details
- Ticks are emitted at fixed intervals: `BASE_TICK_INTERVAL / speed_multiplier`
- At 1x: 1 tick per second
- At 64x: 64 ticks per second (base_interval / 64)
- All "tickable" nodes are called in deterministic order (sorted by node path)
- RefCounted objects can register via `TickManager.register_refcounted_tickable()`
