# Gossip & Reputation System — Phase 5: Emergent Life

## Overview

The Gossip & Reputation System enables social information to spread between pawns during proximity, creating emergent reputation and social norms. Grudges generate gossip that propagates through the settlement, affecting how pawns trust and interact with each other.

## Core Philosophy

> **"News travels fast. Reputation is what others say when you're not in the room."**

Gossip is:
- **Fact-rooted**: Originates from WorldMemory events (via grudges)
- **Social**: Spreads through proximity-based sharing
- **Decaying**: Accuracy fades per hop, old gossip forgotten
- **Behavioral**: Reputation affects trust, cooperation, aggression

## Architecture

### GossipManager (Autoload)

**File:** `autoloads/GossipManager.gd`

Central registry that:
- Tracks all gossip in the simulation
- Manages gossip sharing during social proximity
- Calculates reputation scores from aggregated gossip
- Provides queries for Pawn AI

### GossipPropagation (Per-Pawn)

**File:** `scripts/social/GossipPropagation.gd`

Per-pawn gossip memory that:
- Stores received gossip items
- Determines what gossip to share
- Calculates reputation for specific targets
- Handles gossip decay over time

## Data Structures

### Gossip Item

```gdscript
{
  "id": int,                    # Unique gossip ID
  "subject_pawn_id": int,       # Who the gossip is about
  "content": String,            # What is being said
  "origin_pawn_id": int,        # Who originally said it
  "type": String,               # Type (grudge type, discovery, etc.)
  "importance": float,          # 0.0 to 1.0
  "accuracy": float,            # 0.1 to 1.0 (decays per hop)
  "spread_count": int,          # How many times shared
  "tick_created": int,          # When gossip originated
  "sentiment": float            # -1.0 to 1.0
}
```

### Gossip Types (Grudge Mapping)

| Grudge Type | Gossip Content Template |
|-------------|------------------------|
| `minor_harm` | "heard {target} wronged {holder}" |
| `theft` | "heard {target} stole from {holder}" |
| `betrayal` | "heard {target} betrayed {holder}" |
| `major_harm` | "heard {target} attacked {holder}" |
| `kin_harm` | "heard {target} hurt {holder}'s family" |
| `kin_death` | "heard {target} caused death of {holder}'s kin" |
| `abandonment` | "heard {target} abandoned {holder}" |
| `neglect` | "heard {target} neglected {holder}" |

### Importance Levels

| Level | Value | Spread Chance |
|-------|-------|---------------|
| Trivial | 0.2 | Low |
| Notable | 0.5 | Medium |
| Serious | 0.7 | High |
| Seismic | 0.9 | Very High |

## Gossip Propagation

### Sharing Rules

Gossip spreads when:
1. Two pawns are in social proximity (co-presence for 50+ ticks)
2. Trust strength >= 0.3 (MIN_TRUST_THRESHOLD)
3. Gossip hasn't exceeded MAX_SPREAD_HOPS (4)
4. Deterministic chance roll succeeds

### Spread Chance Calculation

```gdscript
spread_chance = BASE_CHANCE (0.3)
if gossip.hot: spread_chance *= HOT_GOSSIP_MULTIPLIER (3.0)
spread_chance *= gossip.importance
spread_chance *= age_factor (1.0 - age/5000)
```

### Accuracy Decay

Each hop reduces accuracy by 0.1:

```
Original: 1.0 (verified truth)
Hop 1: 0.9
Hop 2: 0.8
Hop 3: 0.7
Hop 4: 0.6 (max hops reached, stops spreading)
```

## Reputation System

### Calculation

Reputation is calculated from all gossip about a pawn:

```gdscript
reputation = sum(sentiment * weight) / sum(weight)

where weight = accuracy * recency * importance
```

### Reputation Scale

| Score | Label | Behavioral Effect |
|-------|-------|-------------------|
| >= 0.6 | Exemplary | +30% trust bonus |
| >= 0.3 | Good | +15% trust bonus |
| >= -0.1 | Neutral | No modifier |
| >= -0.3 | Questionable | -15% trust penalty |
| < -0.3 | Notorious | -30% trust penalty |

### Behavioral Effects

Reputation affects:
- **Trust calculations**: Good reputation = more trusted in social interactions
- **Cooperation**: Pawns more likely to help those with good reputation
- **Aggression**: Bad reputation pawns face more challenges
- **Social bonding**: Mood bonus when sharing gossip with trusted pawns

## Integration Points

### GrudgeManager → GossipManager

When a grudge forms, gossip is automatically generated:

```gdscript
# In GrudgeManager._generate_gossip_from_grudge()
GossipMgr.record_gossip(
    target_id,       # Subject (being talked about)
    content,         # "X holds grudge against Y for Z"
    holder_id,       # Origin (who started it)
    grudge_type,
    importance,      # Based on grudge intensity
    sentiment,       # Negative for grudges
    tick
)
```

### Pawn.gd → GossipManager

Social proximity triggers gossip sharing:

```gdscript
# In Pawn._track_co_presence_light()
if cur % 50 == 0:  # Every 50 ticks of co-presence
    _share_gossip_with(other_pawn)

# In Pawn._share_gossip_with()
GossipManager.share_gossip_between(
    int(data.id),
    other_id,
    trust_strength  # From social rapport
)
```

### PawnData.gd → Reputation

Social factor calculations include reputation:

```gdscript
# In PawnData._calculate_social_factor()
var reputation_modifier: float = _get_reputation_trust_modifier()

if action_type in ["socialize", "talk", "help"]:
    factor += trust_norm * 0.2 * (1.0 - grudge_penalty) * (1.0 + reputation_modifier)
```

## Save/Load

GossipManager state is persisted in Main.gd snapshots:

```gdscript
# Save
save_data["gossip_manager"] = GossipManager.to_save_dict()

# Load
GossipManager.from_save_dict(save_data["gossip_manager"])
```

## Debug Tools

### F10 Debug Menu

**Button:** `41 · Gossip & Reputation (Phase 5 — social propagation)`

Shows:
- Total gossip items tracked
- Active gossip (still spreading, < max hops)
- Notorious pawns with reputation scores
- Sample reputations for first 10 pawns

### GossipManager API

```gdscript
GossipManager.gossip_count() -> int
GossipManager.get_active_gossip() -> Array[Dictionary]
GossipManager.get_notorious_report() -> Array[Dictionary]
GossipManager.get_reputation_for(pawn_id) -> float
GossipManager.get_reputation_label(pawn_id) -> String
GossipManager.share_gossip_between(pawn_a, pawn_b, trust) -> int
GossipManager.clear()  # For testing
```

## Design Principles (Non-Negotiable)

1. **Facts First**: Gossip originates from recorded events (grudges)
2. **Deterministic**: Same seed + proximity = same gossip spread
3. **Decays**: Old gossip forgotten, accuracy fades per hop
4. **Behavioral**: Reputation must affect pawn decisions
5. **No Hivemind**: Gossip only spreads through actual proximity
6. **Auditable**: Gossip traces to origin pawn and event

## Forbidden Patterns

- ❌ `randi()` in gossip spread decisions (use WorldRNG)
- ❌ Instant gossip传播 (must require proximity)
- ❌ Perfect accuracy after hops (must decay)
- ❌ Reputation without behavioral consequences
- ❌ Gossip from nowhere (must originate from events)

## Performance Considerations

- **Per-pawn storage**: GossipPropagation instances only for active pawns
- **Sampling**: Reputation checks sample up to 5 trusted pawns
- **Decay batching**: Gossip decay runs every 100 ticks, not every tick
- **Cache**: Reputation cached for 100 ticks
- **Cleanup**: Gossip removed for pawns that no longer exist

## Example Usage

```gdscript
# Check pawn's reputation before cooperating
var rep: float = GossipManager.get_reputation_for(other_pawn_id)
if rep < -0.3:
    # This pawn is notorious - be cautious
    action_priority *= 0.7

# Share gossip during social interaction
var shared: int = GossipManager.share_gossip_between(
    pawn_a_id, pawn_b_id, trust_strength
)
if shared > 0:
    # Social bonding occurred
    pawn_a.data.mood += shared * 0.05
```

## Emergent Behaviors

### Reputation Cascades

A single grudge can cascade into settlement-wide reputation damage:

1. Pawn A wrongs Pawn B → B holds grudge
2. Grudge generates gossip: "A wronged B"
3. B shares with C, D during proximity
4. C shares with E, F
5. Now E, F know about A's wrong despite never witnessing it
6. A's reputation drops settlement-wide

### Social Clusters

Pawns who spend time together share gossip, creating clusters with similar beliefs:

- Workers in same zone share local gossip
- Family members share more (higher trust threshold)
- Isolated pawns have outdated/incomplete information

### Notorious Outcasts

Pawns with very bad reputation may find:
- No one wants to cooperate with them
- More challenge attempts (low trust = more aggression)
- Gossip about them spreads faster (hot gossip multiplier)

## Future Extensions (Phase 5+)

- **Positive gossip**: Achievements, teaching, help also generate gossip
- **Gossip rituals**: Formal gathering spots (firesides, markets) boost sharing
- **Reputation recovery**: Actions that improve bad reputation
- **Lies/misinformation**: Intentional false gossip (betrayal type)
- **Settlement reputation**: Aggregate reputation affects trade, diplomacy
