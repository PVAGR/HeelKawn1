# Grudge System — Phase 5: Emergent Life

## Overview

The Grudge System is a deterministic social memory system that tracks persistent negative relationships between pawns. Grudges form from recorded wrongs (harm, theft, betrayal, neglect), decay slowly over time, inherit across bloodlines, and affect pawn behavior.

## Core Philosophy

> **"Memory does not decay randomly. History does not lie. Persistence is earned strictly by impact."**

Grudges are:
- **Fact-based**: Only form from WorldMemory events (never random)
- **Deterministic**: Same seed + events = same grudges (replayable, auditable)
- **Inherited**: Children remember wrongs done to their parents
- **Behavioral**: Affect avoidance, revenge, and trust decisions

## Architecture

### GrudgeManager (Autoload)

**File:** `autoloads/GrudgeManager.gd`

The central system that:
- Tracks all grudges in the simulation
- Applies deterministic decay per tick
- Handles inheritance when children are born
- Provides queries for Pawn AI

#### Data Structure

```gdscript
{
  "id": int,                    # Unique grudge ID
  "holder_id": int,             # Pawn who holds the grudge
  "target_id": int,             # Pawn the grudge is against
  "origin_id": int,             # Original wrongdoer (may differ if inherited)
  "type": String,               # Type of wrong (e.g., "kin_death", "theft")
  "intensity": float,           # 0.0 to 1.0
  "tick_created": int,          # When grudge formed
  "tick_last_updated": int,     # Last modification tick
  "event_id": int,              # WorldMemory event that caused this
  "generation": int,            # 0 = direct victim, 1+ = inherited
  "source_event_type": String   # Original event type
}
```

#### Grudge Types & Base Intensities

| Type | Intensity | Description |
|------|-----------|-------------|
| `minor_harm` | 0.2 | Bump, accidental hit |
| `theft` | 0.4 | Stole my stuff |
| `betrayal` | 0.6 | Broke promise/oath |
| `major_harm` | 0.7 | Serious injury attempt |
| `kin_harm` | 0.8 | Hurt my family member |
| `kin_death` | 1.0 | Killed my family member |
| `abandonment` | 0.5 | Left me behind |
| `neglect` | 0.3 | Ignored my need |
| `public_humiliation` | 0.5 | Shamed me in front of others |

#### Intensity Thresholds

```gdscript
INTENSITY_NEUTRAL = 0.0       # No grudge
INTENSITY_GRUDGE = 0.3        # Mild dislike
INTENSITY_HATRED = 0.6        # Active hostility
INTENSITY_BLOOD_FEUD = 0.85   # Multi-generational feud
```

#### Decay Rates

```gdscript
DECAY_RATE_BASE = 0.0001      # ~10000 ticks to decay 1.0
DECAY_RATE_FAST = 0.0003      # Minor slights decay faster
DECAY_RATE_SLOW = 0.00005     # Blood feuds barely decay
```

#### Inheritance Rules

```gdscript
INHERITANCE_FACTOR = 0.5                      # Children inherit 50% of parent's grudge
INHERITANCE_DECAY_GENERATION = 0.3            # Each generation reduces by 30%
```

Example: A blood feud (1.0) inherited by a child becomes 0.5, then 0.35 for the grandchild, etc.

## Grudge Generation

Grudges are automatically generated when WorldMemory records certain events:

### Event → Grudge Mapping

| Event Type | Grudge Holder | Grudge Target | Grudge Type |
|------------|---------------|---------------|-------------|
| `pawn_death` (with killer) | Victim's kin | Killer | `kin_death` |
| `pawn_harmed` | Victim | Aggressor | harm type |
| `theft` | Victim | Thief | `theft` |
| `betrayal` | Betrayed | Betrayer | `betrayal` |
| `abandonment` | Abandoned | Abandoner | `abandonment` |
| `conflict_start` | Both parties | Each other | conflict type |

### Kin-Based Grudge Generation

When a pawn dies, grudges form for:
- Parents (for child's death)
- Children (for parent's death)
- Spouses (for partner's death)

## Integration Points

### WorldMemory.gd

- `_generate_grudges_from_event()`: Called when events are appended
- `_generate_grudges_for_victim_kin()`: Creates grudges for victim's family

### KinshipSystem.gd

- `_flush_pending_births()`: Calls `GrudgeManager.inherit_grudges()` for newborn pawns

### Pawn.gd

New helper functions:
```gdscript
get_grudge_toward(other_pawn_id) -> float
has_grudge_against(other_pawn_id, min_intensity) -> bool
get_grudge_trust_penalty(other_pawn_id) -> float
get_grudge_enemies() -> Array[int]
should_seek_revenge(other_pawn_id) -> bool
```

### PawnData.gd

- `_calculate_social_factor()`: Applies grudge-based trust penalty
- `_get_grudge_penalty_for_peer()`: Queries grudges for social calculations

## Behavioral Effects

### Trust Penalty

Grudges reduce effective trust in social interactions:

```gdscript
effective_trust = base_trust * (1.0 - grudge_penalty)
```

Where `grudge_penalty` is the maximum grudge intensity (0.0 to 0.9).

### Avoidance

Pawns with grudges > 0.4 against another pawn will:
- Avoid walking near them
- Prefer different work areas
- Experience mood drain when in proximity

### Revenge

When grudge intensity > 0.7:
- Pawn may autonomously seek confrontation
- Higher chance to challenge in conflicts
- Reduced cooperation in shared tasks

## Save/Load

GrudgeManager state is persisted in Main.gd snapshots:

```gdscript
# Save
save_data["grudge_manager"] = GrudgeManager.to_save_dict()

# Load
GrudgeManager.from_save_dict(save_data["grudge_manager"])
```

## Debug Tools

### F10 Debug Menu

**Button:** `40 · Grudge system (Phase 5 — grudges, blood feuds)`

Shows:
- Total grudges tracked
- Active blood feuds (intensity >= 0.85)
- Sample grudges held by first 10 pawns

### GrudgeManager API

```gdscript
GrudgeManager.grudge_count() -> int
GrudgeManager.get_blood_feuds() -> Array[Dictionary]
GrudgeManager.get_grudges_held_by(pawn_id) -> Array[Dictionary]
GrudgeManager.get_grudges_against(pawn_id) -> Array[Dictionary]
GrudgeManager.get_enemies_for(pawn_id, min_intensity) -> Array[int]
GrudgeManager.clear()  # For testing
```

## Design Principles (Non-Negotiable)

1. **Facts First**: Grudges only form from WorldMemory events
2. **No Random Decay**: Deterministic tick-based decay only
3. **Auditable**: Every grudge traces to an event ID
4. **Inherited Memory**: Bloodlines remember wrongs
5. **Behavioral Impact**: Grudges must affect pawn decisions
6. **No Chosen Ones**: Grudges form from actions, not prophecy

## Forbidden Patterns

- ❌ `randi()` in grudge formation or decay
- ❌ Hardcoded grudges (must come from events)
- ❌ Random memory decay
- ❌ Grudges without behavioral consequences
- ❌ Moral judgment (good/evil) — only recorded facts

## Performance Considerations

- **Indexing**: Grudges indexed by holder_id and target_id for O(1) lookup
- **Cache**: Combined intensity cache rebuilt only when dirty
- **Sampling**: Social factor checks sample up to 5 trusted pawns
- **Decay**: Single pass per tick, removes grudges < 0.05 intensity

## Future Extensions (Phase 5+)

- **Gossip propagation**: Grudges spread through social networks
- **Reputation**: Aggregate grudge intensity affects settlement standing
- **Forgiveness**: Rituals or acts that reduce grudge intensity
- **Mediation**: Authority figures can resolve conflicts
- **Grudge artifacts**: Physical reminders (trophies, monuments)

## Example Usage

```gdscript
# Check if pawn holds a grudge
if pawn.has_grudge_against(target_id, 0.6):
    # Pawn hates target - avoid or confront
    if pawn.should_seek_revenge(target_id):
        pawn.initiate_confrontation(target_id)
    else:
        pawn.avoid_tile(target_position)

# Get trust penalty for social interaction
var trust_penalty = pawn.get_grudge_trust_penalty(other_id)
var effective_trust = base_trust * (1.0 - trust_penalty)
```

## Testing Determinism

To verify determinism:
1. Start a new game with seed X
2. Let simulation run for N ticks
3. Save game, record grudge state
4. Reload from same seed
5. Run for N ticks
6. Compare grudge states — must be identical

```gdscript
# Debug command
GrudgeManager.clear()
WorldMemory.clear()
# Replay events...
# Verify grudges match
```
