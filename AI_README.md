# HEELKAWN — AI INSTRUCTIONS & CANON

**Core canon for all AI agents working on HeelKawn.**

---

**Last Updated**: August 18, 2026

---

## QUICK REFERENCE

**Truth hierarchy (when docs conflict):**
1. Source code and Godot runtime checks (highest truth)
2. `AI_README.md` — Kernel philosophy (non-negotiable principles)
3. Older docs and session notes — Historical evidence, not authority

**Repo:** `github.com/PVAGR/HeelKawn1` on `origin/main`

---

## CORE PHILOSOPHY

### The Deterministic Kernel

HeelKawn is a **persistent simulation universe**. The core principle:

> **All world state must derive from tick count + seed + inputs. No hidden RNG. No frame-coupled logic.**

This means:
- Every pawn decision, job completion, resource generation must be reproducible
- Same seed + same inputs = same history
- UI can show approximations, but world truth is deterministic

### Facts First, Meaning Second

The simulation has layers:
1. **Facts** — tile types, resources, pawn positions, job states (deterministic kernel)
2. **Meaning** — region tags, settlement intent, cultural pressure (derived from facts)
3. **Interpretation** — narrative, lore, player understanding (layer on top)

**Rule:** Never hardcode meaning or interpretation into the kernel. Derive it.

---

## HOW AI MEMORY WORKS

Each AI agent manages its own memory. Letta has persistent memory across sessions. Other AI agents (ChatGPT, Claude, Qwen) should paste relevant context from this file when starting work.

---

## KERNEL RULES (NON-NEGOTIABLE)

### 1. No Unseeded RNG

All randomness must use `WorldRNG` with named streams:
```gdscript
var roll: int = WorldRNG.roll("pawn_decision_%d" % pawn_id, 100)
```

**Forbidden:**
- `randi()`, `randf()` in simulation paths
- `Time.get_unix_time_from_system()` for world state
- Any external entropy source

### 2. No Frame/FPS Coupling

World truth must not depend on frame rate:
```gdscript
# WRONG:
if Time.get_delta() > 0.1:  # Frame-coupled!
    do_world_logic()

# CORRECT:
if GameManager.tick_count % 10 == 0:  # Tick-based!
    do_world_logic()
```

### 3. No Fake Systems

Do not expose placeholder behavior as if it were active world logic. If a system is incomplete, mark it clearly or disable it.

### 4. Truth Hierarchy

When docs conflict:
1. Source code (highest truth)
2. Runtime behavior
3. `AI_README.md` (kernel philosophy)
4. Other docs (historical reference)

---

## DEVELOPMENT RULES

### Core Rules
- All state changes must derive from tick count
- Derive meaning through WorldMeaning, never hardcode it
- Preserve anonymity — no heroic exceptionalism

### Performance
- The game must run at 200x speed without lag or freezing
- Performance fixes are always allowed and encouraged
- Do not throttle in ways that cause lag — increase stride, cache lookups, defer expensive computations

---

## PERFORMANCE TARGETS

**1x Speed:** Real-time observation, fully responsive

**100x Speed:** Stress test, no crash cascades, no tick desync

**200x Speed:** Target 25 in-game days (~15,000 ticks) in ~75 seconds. No freezing, no lag spikes.

---

## COMMON PATTERNS

### Throttling by Tick
```gdscript
if posmod(GameManager.tick_count + int(data.id), interval) == 0:
    # Run expensive logic
```

### Speed-Dependent Intervals
```gdscript
func _interval_for_speed() -> int:
    var bucket: int = _speed_bucket()
    return [1, 3, 8, 15, 40, 100][bucket]  # [1x, 6x, 26x, 50x, 100x, 200x]
```

### Cached Lookups
```gdscript
@export var _cached_value: int = -1
@export var _cache_tick: int = -1

func get_cached_value() -> int:
    if _cache_tick != GameManager.tick_count:
        _cached_value = expensive_computation()
        _cache_tick = GameManager.tick_count
    return _cached_value
```

---

## FINAL NOTE

This is a **simulation**, not a game in the traditional sense. The goal is a coherent, deterministic world that evolves over time. Performance matters because we want to simulate years of history in minutes, not hours.

**When in doubt:** Preserve determinism, optimize hot paths, derive meaning from facts.
