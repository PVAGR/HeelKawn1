# TickManager Implementation - COMPLETED

## Overview
Successfully implemented a deterministic TickManager system to fix rubber-banding issues in HeelKawn. The new system ensures all simulation logic runs on fixed-time ticks instead of frame-dependent updates.

## Files Created

### 1. `autoloads/TickManager.gd`
Central tick manager with:
- Fixed-step accumulation loop (`_accumulated_time += delta`)
- Emits `tick_processed(tick_number)` signal when enough time accumulates
- Supports speed multipliers: [0.5, 1.0, 4.0, 16.0, 64.0]x
- Pause/Resume without losing accumulated time state
- Tracks `current_tick` (int) starting from 0
- Calls `_on_world_tick()` on all "tickable" nodes in deterministic order (sorted by node path)
- Supports RefCounted tickables via `register_refcounted_tickable()`

### 2. `scripts/ui/SpeedControlUI.gd`
Speed control UI with buttons for Pause, 0.5x, 1x, 4x, 16x, 64x.
Connects to `TickManager.set_speed_index()` for speed changes.

### 3. `scenes/ui/SpeedControlUI.tscn`
Scene file for the SpeedControlUI with HBoxContainer and Button nodes.

## Files Modified

### 1. `autoloads/WorldMemory.gd`
- Already had `add_to_group("tickable")` in `_ready()` (line 44)
- Already had `_on_world_tick()` method (line 49)

### 2. `autoloads/JobManager.gd`
- Already had `add_to_group("tickable")` in `_ready()` (lines 11, 47)
- Already had `_on_world_tick()` method (line 15)

### 3. `scripts/pawn/Pawn.gd`
- Already had `add_to_group("tickable")` in `_ready()` (lines 752, 754)
- Already had `_on_world_tick()` method (line 1326)
- Updated to connect to `TickManager.tick_processed` signal (with fallback to GameManager)

### 4. `scripts/ai/SettlementAI.gd`
- Added `_on_world_tick(tick_number)` method (line 1103)
- Note: SettlementAI is RefCounted, so it uses `TickManager.register_refcounted_tickable()`

### 5. `autoloads/AIAgentManager.gd`
- Already had `add_to_group("tickable")` in `_ready()` (line 67)
- Added `_on_world_tick()` method to `SettlementAIShim` class (line 18)
- Updated `_ready()` to rely on "tickable" group instead of signal connection (avoids double-processing)

### 6. `autoloads/GameManager.gd`
- Updated `_process()` to defer to TickManager for tick processing (lines 326-375)
- If TickManager is active, GameManager._process() returns early

## Project Configuration
- `project.godot` already has TickManager registered as autoload (line 24)
- TickManager is loaded BEFORE GameManager (ensures proper initialization order)

## How It Works

1. **TickManager._process(delta)** accumulates real time
2. When `accumulated_time >= target_interval`, a tick is processed:
   - `current_tick` increments
   - All nodes in "tickable" group have `_on_world_tick(tick)` called (in deterministic path order)
   - All RefCounted tickables have `_on_world_tick(tick)` called
   - `tick_processed` signal is emitted
3. **Speed control**: `target_interval = BASE_TICK_INTERVAL / speed_multiplier`
   - At 1x: 1 tick per second
   - At 64x: 64 ticks per second (every ~15.6ms)
4. **Pause**: Sets `_is_paused = true`, which skips tick processing in `_process()`

## Usage

### Adding a New System to the Tick System
```gdscript
# For Node-based systems:
func _ready() -> void:
    add_to_group("tickable")

func _on_world_tick(tick_number: int) -> void:
    # Your tick logic here
    pass

# For RefCounted systems:
func _ready() -> void:
    var tick_mgr = get_node_or_null("/root/TickManager")
    if tick_mgr != null:
        tick_mgr.register_refcounted_tickable(self)

func _on_world_tick(tick_number: int) -> void:
    # Your tick logic here
    pass
```

### Using SpeedControlUI
1. Instance the `res://scenes/ui/SpeedControlUI.tscn` in your main scene
2. The UI will automatically connect to TickManager
3. Use the buttons to control game speed

## Benefits
- Deterministic tick processing (same seed = same tick order)
- No rubber-banding (fixed-time steps)
- Pause without losing state
- Variable speed (0.5x to 64x)
- Clean separation of visual interpolation (_process) and game logic (_on_world_tick)
