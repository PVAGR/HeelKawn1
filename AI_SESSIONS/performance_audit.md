# 🔍 HeelKawn Performance Audit

**Date:** May 6, 2026  
**AI:** Qwen Code (TRACK 2 — Performance Optimization)  
**Status:** ⏳ IN PROGRESS

---

## 📊 Current Performance Baseline

### Already Optimized ✅

**Pawn Movement & Visuals:**
- Adaptive visual throttling: `visual_interval = MIN_VISUAL_UPDATE_INTERVAL + int(game_speed * 0.4)`
  - At 1x: Every ~3 frames (67% reduction)
  - At 26x: Every ~13 frames (92% reduction)
  - At 100x: Every ~43 frames (98% reduction)
- Knowledge stone checks: Only when visuals update ✅
- SacredGeography checks: Every frame but lightweight (dictionary lookup) ✅

**Autoload Throttling:**
| Autoload | Update Interval | Status |
|----------|----------------|--------|
| CollapseSystem | 5000 ticks | ✅ Throttled |
| AuthoritySystem | 2000 ticks | ✅ Throttled |
| BodyRiskManager | Injury throttle: 60 ticks | ✅ Throttled |
| MemorialSystem | 100-200 ticks | ✅ Throttled |
| SacredGeography | 100 ticks | ✅ Throttled |

**Memory Management:**
- WorldMemory: 50,000 event cap ✅
- Event significance filtering ✅ (only meaningful events recorded)

---

## 🔍 Profiling Checklist (To Do)

**Need Godot Runtime Access:**
- [ ] Open Godot profiler (F5 → Debugger → Profiler)
- [ ] Run at 1x for 5 minutes → Record FPS
- [ ] Run at 26x for 5 minutes → Record FPS
- [ ] Run at 100x for 5 minutes → Record FPS
- [ ] Check memory growth over 1 hour
- [ ] Profile pathfinding calls per tick
- [ ] Check pawn count vs FPS correlation

**Without Godot Runtime, I Can:**
- [x] Code audit for optimization opportunities
- [x] Check throttling constants across autoloads
- [x] Identify potential bottlenecks from code structure

---

## 🎯 Optimization Opportunities (Code Audit Findings)

### 1. SacredGeography Check (Every Frame)
**Current:**
```gdscript
# In Pawn.gd _process()
if SacredGeography != null and SacredGeography.has_method("check_sacred_tile_effect"):
    SacredGeography.check_sacred_tile_effect(self)
```

**Issue:** Called every frame for every pawn  
**Fix:** Only check when pawn moves to new tile (not every frame)

**Optimized:**
```gdscript
# Track last checked tile
var _last_sacred_check_tile: Vector2i = Vector2i(-9999, -9999)

if data.tile_pos != _last_sacred_check_tile:
    SacredGeography.check_sacred_tile_effect(self)
    _last_sacred_check_tile = data.tile_pos
```

**Savings:** ~90% reduction in SacredGeography calls (only on tile change, not every frame)

---

### 2. WorldMemory Event Filtering (Already Good ✅)
```gdscript
# Already has strict significance filtering
- Core events: Always record (pawn_death, birth, etc.)
- Work events: Only skill level >= 5
- Social events: Only severity >= 3
- Movement events: SKIP (too spammy)
- Resource gathering: Only quantity >= 5
```

**Status:** Already well-optimized. No changes needed.

---

### 3. Pawn Pathfinding Cache (Potential Improvement)
**Current:** Pathfinding called every time pawn claims job  
**Potential:** Cache last path for 10-20 ticks, reuse if target unchanged

**Implementation:**
```gdscript
var _cached_path: Array[Vector2i] = []
var _cached_path_target: Vector2i = Vector2i(-9999, -9999)
var _cached_path_tick: int = -1
const PATH_CACHE_DURATION: int = 20  # Ticks

func _get_cached_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
    if to == _cached_path_target and GameManager.tick_count - _cached_path_tick < PATH_CACHE_DURATION:
        return _cached_path  # Reuse cached path
    
    _cached_path = _world.pathfinder.find_path(from, to, false)
    _cached_path_target = to
    _cached_path_tick = GameManager.tick_count
    return _cached_path
```

**Savings:** Reduces pathfinding calls by ~50% in busy colonies

---

### 4. UI Polling (Already Good ✅)
```gdscript
# PawnInfoPanel.gd
const UI_POLL_INTERVAL_SEC: float = 0.35  # Not per-frame
```

**Status:** Already throttled. No changes needed.

---

### 5. Memorial System (Already Good ✅)
```gdscript
# MemorialSystem.gd
_update_sacred_geography()  # Every 100 ticks ✅
_track_pawn_crossings()     # Every 50 ticks ✅
_pilgrimage_check()         # Every 200 ticks ✅
```

**Status:** All throttled appropriately. No changes needed.

---

## 📋 Recommended Optimizations (Priority Order)

### HIGH PRIORITY (If Godot Profiling Shows Issues)

1. **SacredGeography Tile Check** — Reduce from per-frame to per-tile-change
   - File: `scripts/pawn/Pawn.gd`
   - Time: 15 min
   - Impact: ~90% reduction in SacredGeography calls

2. **Pathfinding Cache** — Cache paths for 20 ticks
   - File: `scripts/pawn/Pawn.gd`
   - Time: 30 min
   - Impact: ~50% reduction in pathfinding calls

### MEDIUM PRIORITY

3. **WorldMemory Event Deduplication** — Prevent duplicate events within N ticks (already has some, may need expansion)

4. **Spatial Partitioning for Social** — Only check social proximity for nearby pawns (already implemented per memory)

---

## 🎯 Next Steps

**Waiting on:**
- Godot runtime access for actual FPS/memory profiling
- Human confirmation: Should I implement the SacredGeography optimization now?

**If yes, I'll:**
1. Add `_last_sacred_check_tile` tracking to Pawn.gd
2. Update SacredGeography check to only trigger on tile change
3. Test for correctness (still applies reverence slowdown)
4. Profile before/after if Godot available

---

*Session in progress: May 6, 2026*
