# 🏛️ AI Architectural Decions

**Record of significant architectural decisions made by AI assistants.** These constrain future work and explain why systems are built certain ways.

---

## Decision Log Index

| ID | Title | Date | Status | Impact |
|----|-------|------|--------|--------|
| DEC-001 | Deterministic Kernel | Phase 0 | ✅ Locked | Foundational |
| DEC-002 | WorldMemory Append-Only | Phase 2 | ✅ Locked | Core Architecture |
| DEC-003 | Pawn-Activated Events | Phase 4 | ✅ Locked | Simulation Design |
| DEC-004 | UI Polling Interval | Phase 6 | ✅ Active | Performance |
| DEC-005 | Consciousness Tab Location | May 6 | ✅ Active | UI Architecture |

---

## DEC-001: Deterministic Kernel

**Date:** Phase 0 (Original Design)  
**Status:** ✅ Locked (Non-Negotiable)  
**Impact:** Foundational - All systems must comply

### Decision
HeelKawn uses a **deterministic kernel** - same causes produce same effects. No random memory decay, no frame-dependent logic, no non-seeded RNG.

### Alternatives Considered
- Roguelike randomness (rejected - breaks replayability)
- Frame-time dependent simulation (rejected - not reproducible)

### Rationale
- Enables replayability and auditability
- History emerges from cause/effect, not scripts
- Core to HeelKawn's "persistent myth engine" vision

### Implications
- All RNG must use seeded WorldRNG
- No `randi()`, `randf()`, `rand_range()` without seed
- State changes derive from tick count, not delta time
- UI cannot override world truth

**Enforced by:** AI agents (reject non-deterministic code)

---

## DEC-002: WorldMemory Append-Only Fact Log

**Date:** Phase 2  
**Status:** ✅ Locked  
**Impact:** Core Architecture

### Decision
WorldMemory records **what happened**, never intentions. Append-only, never modified after write.

### Alternatives Considered
- Mutable state (rejected - loses history)
- Intent-based recording (rejected - world records actions, not plans)

### Rationale
- Historical continuity requires immutable facts
- Meaning is derived, never authored
- Enables deterministic replay

### Implications
- All meaningful events recorded to WorldMemory
- Events have type, timestamp, participants, location
- Meaning layer (WorldMeaning) derives interpretations
- UI displays derived meaning, never overrides facts

---

## DEC-003: Pawn-Activated Events

**Date:** Phase 4  
**Status:** ✅ Locked  
**Impact:** Simulation Design

### Decision
Events trigger from **pawn actions**, not global timers. The world lives through its inhabitants.

### Alternatives Considered
- Global timer events (rejected - feels scripted)
- Hybrid approach (rejected - adds complexity)

### Rationale
- Emergence over scripting
- Pawns feel alive when they cause events
- Consistent with deterministic kernel

### Implications
- No "every X seconds" event generators
- Events flow from pawn decisions/actions
- AI systems respond to pawn activity

---

## DEC-004: UI Polling Interval (0.35s)

**Date:** Phase 6  
**Status:** ✅ Active  
**Impact:** Performance

### Decision
PawnInfoPanel polls every **0.35 seconds**, not per-frame or per-tick.

### Alternatives Considered
- Per-frame update (rejected - performance cost)
- Per-tick update (rejected - too frequent at high speeds)
- Event-driven only (rejected - misses state changes)

### Rationale
- Balance between responsiveness and performance
- Works at all game speeds (1x, 26x, 100x)
- State-driven (only updates if signature changes)

### Implications
- UI feels live without frame cost
- Works with adaptive throttling systems
- Signature diff prevents unnecessary repaints

**Code:**
```gdscript
const UI_POLL_INTERVAL_SEC: float = 0.35
func _process(delta: float) -> void:
    _poll_accum_sec += delta
    if _poll_accum_sec < UI_POLL_INTERVAL_SEC:
        return
    _poll_accum_sec = 0.0
    # Update if signature changed
```

---

## DEC-005: Consciousness Tab in PawnInfoPanel

**Date:** May 6, 2026  
**Status:** ✅ Active  
**Impact:** UI Architecture

### Decision
Pawn Consciousness UI implemented as a **tab in existing PawnInfoPanel**, not a separate panel.

### Alternatives Considered
1. **Separate ConsciousnessPanel** (rejected)
   - Pros: Dedicated space, more room
   - Cons: More UI clutter, another panel to manage

2. **Tab in PawnInfoPanel** (✅ Chosen)
   - Pros: Organized with other pawn data, consistent UX
   - Cons: Tab can get crowded

3. **Popup on demand** (rejected)
   - Pros: Clean default view
   - Cons: Harder to discover, extra clicks

### Rationale
- PawnInfoPanel already the place for pawn data
- Tab organization scales well (already has 5 tabs)
- Consistent with existing UX patterns
- No new scene files needed

### Implications
- Consciousness data updates on same 0.35s poll
- Shares styling/theme with other tabs
- Tab count increases (6 tabs in debug, 4 in release)
- Must fit within existing panel dimensions

---

## 📝 How to Record Decisions

### Template:

```markdown
## DEC-XXX: [Decision Title]

**Date:** [Date]  
**Status:** ✅ Active / ✅ Locked / ⚠️ Deprecated / ❌ Reversed  
**Impact:** Foundational / Core Architecture / Simulation Design / Performance / UI Architecture

### Decision
[What was decided]

### Alternatives Considered
- [Alternative 1] (rejected/accepted)
- [Alternative 2] (rejected/accepted)

### Rationale
[Why this decision was made]

### Implications
[What this constrains or enables]

### Code Examples
[If applicable]

### Related Decisions
- DEC-XXX (title)
```

---

*Last Updated: May 6, 2026*
