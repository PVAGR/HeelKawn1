# MAP OF PROMETHEUS

**Canonical Geography of the HeelKawn World**  
*Last Updated: 2026-05-02*

---

## Purpose

Prometheus is the playable world continent in HeelKawn — a land shaped by ancient cataclysms, forgotten wars, and the slow accumulation of human meaning. This document describes the canonical regions, their historical significance, and their role in the deterministic simulation.

> **Design Principle:** Geography is memory. Every valley, ruin, and road exists because of prior events. Nothing is random decoration.

---

## World Structure

### Coordinate System
- **World Grid:** 512×512 regions (expandable)
- **Region Size:** 32×32 tiles
- **Tile Size:** 16×16 pixels
- **Total Playable Area:** ~16,384 tiles per axis

### Biome Distribution
Biomes are deterministically seeded from world seed + region coordinates:

| Biome ID | Name | Characteristics | Settlement Potential |
|----------|------|-----------------|---------------------|
| 0 | Plains | Flat, fertile, moderate rainfall | High |
| 1 | Forest | Dense trees, wildlife, hidden resources | Medium |
| 2 | Hills | Elevated, mineral-rich, defensible | Medium |
| 3 | Mountains | Extreme elevation, rare ores, isolated | Low |
| 4 | Desert | Arid, scarce water, extreme temperatures | Very Low |
| 5 | Tundra | Frozen, seasonal growth, hardy fauna | Low |
| 6 | Swamp | Wet, disease-prone, unique resources | Low |
| 7 | Coast | Trade access, fishing, vulnerable | High |

---

## Canonical Regions

### Region 0: The First Scar
- **Coordinates:** (128, 128)
- **Biome:** Plains (degraded)
- **Historical Significance:** Location of the first recorded settlement collapse in simulation testing
- **Current State:** Permanently abandoned (scar level 3)
- **Meaning Label:** "grave"
- **Notable Events:** 
  - Tick 15000: First starvation cascade
  - Tick 18000: Complete depopulation
  - Tick 25000: Scar level locked at 3

### Region 1: The Quiet Valley
- **Coordinates:** (140, 135)
- **Biome:** Plains/Forest mix
- **Historical Significance:** Longest continuously inhabited region in test sessions
- **Current State:** Active
- **Meaning Label:** "quiet"
- **Cultural Type:** CAUTIOUS
- **Notable Features:**
  - Stable food production
  - Low conflict history
  - Strong kinship networks

### Region 2: The Bloodied Fields
- **Coordinates:** (150, 140)
- **Biome:** Plains
- **Historical Significance:** Site of repeated conflict events
- **Current State:** Abandoned → Revivable (cycle)
- **Meaning Label:** "bloodied"
- **Conflict History:**
  - Multiple war_battle_spawned events
  - High pawn_death density
  - Peace gates prevent revival until 30000+ ticks

### Region 3: The Teacher's Hold
- **Coordinates:** (125, 130)
- **Biome:** Hills
- **Historical Significance:** Knowledge preservation site
- **Current State:** Active
- **Meaning Label:** "quiet"
- **Cultural Type:** OPEN
- **Notable Features:**
  - High teaching event density
  - Technology research hub
  - Cultural memory strong

### Region 4: The Famine Zone
- **Coordinates:** (160, 145)
- **Biome:** Plains (exhausted)
- **Historical Significance:** Ecological collapse case study
- **Current State:** Recovering
- **Meaning Label:** "scarred"
- **Recovery Status:**
  - Resource pressure decreasing
  - Slow repopulation
  - Requires 10000+ tick recovery period

---

## Named Region Patterns

### The Quiet Ring
- **Type:** Recovering settlement belt
- **Biome traits:** Stable food and moderate travel safety
- **Settlement tendency:** Open and adaptive
- **Memory profile:** Low scar density, occasional ruins
- **Current status:** Viable for revival behavior tuning

### Red Scar Basin
- **Type:** Heavily impacted conflict corridor
- **Biome traits:** Unstable population pressure zones
- **Settlement tendency:** Defensive and inward
- **Memory profile:** Repeated death markers and abandonment
- **Current status:** Bloodied-to-grave transition risk

---

## Settlement Clusters

### Cluster Alpha (Regions 0-10)
- **Center:** Region 1 (The Quiet Valley)
- **Culture:** Mixed CAUTIOUS/OPEN
- **Status:** Active civilization core
- **Population Density:** High
- **Trade Networks:** Established

### Cluster Beta (Regions 50-70)
- **Center:** Region 55
- **Culture:** DEFENSIVE
- **Status:** Isolated, conflict-prone
- **Population Density:** Medium
- **Trade Networks:** Limited

### Cluster Gamma (Regions 200-220)
- **Center:** Region 210
- **Culture:** OPEN
- **Status:** Frontier expansion
- **Population Density:** Low
- **Trade Networks:** Developing

---

## Historical Layers

### Layer 1: Pre-History (Tick 0-10000)
- Initial settlement wave
- Resource discovery phase
- First collapses

### Layer 2: The Expansion (Tick 10000-50000)
- Civilization clustering
- Trade network formation
- Cultural divergence begins

### Layer 3: The Conflicts (Tick 50000-100000)
- War system activation
- Settlement destruction cycles
- Scar accumulation

### Layer 4: The Recovery (Tick 100000+)
- Revival processes
- Cultural memory inheritance
- Long-term persistence patterns

---

## Points of Interest

### Ruins
- **Function:** Persistent reminders of past settlements
- **Spawn Condition:** Building destruction + scar level ≥ 1
- **Effect:** Regional meaning shift toward "scarred" or "bloodied"

### Roads
- **Function:** Trade and movement corridors
- **Persistence:** Survive settlement collapse
- **Effect:** Increase tile scores for rebirth spawning

### Boundary Stones
- **Function:** Cultural territory markers
- **Spawn Condition:** Settlement intent GROW + sustained activity
- **Effect:** Define settlement cluster boundaries

### Mass Graves
- **Function:** Extreme death event markers
- **Spawn Condition:** Enemy_death clusters (≥5 in 1000 ticks)
- **Effect:** Permanent "grave" meaning label, blocks revival

---

## Map Reading Rules

- Regions are read through facts first, meaning second
- Persistent scars should be explained by recorded history, not by authorial drama
- Revival is possible only where the canonical peace and scar gates allow it

---

## Deterministic Generation Rules

1. **No Random Placement:** All features derive from seed + tick
2. **Cause → Effect:** Ruins exist only where buildings were destroyed
3. **Memory Persistence:** Scars never decrease, only accumulate
4. **Cultural Emergence:** Culture types emerge from survival pressure, not assignment
5. **Auditable History:** Every feature traceable to WorldMemory events

---

## Future Expansion

### Unexplored Territories
- **Northern Wastes** (Y < 50): Extreme tundra, untested
- **Eastern Seas** (X > 400): Coastal biomes, trade potential
- **Southern Deserts** (Y > 400): Resource scarcity challenges
- **Western Mountains** (X < 50): Isolation, mineral wealth

### Planned Additions
- Naval systems for coastal regions
- Mountain pass mechanics
- River systems (not yet implemented)
- Seasonal migration routes

---

## Usage Notes

- This map evolves with each simulation run
- Canonical regions serve as reference points for testing
- Player actions can create new points of interest
- All geography serves the simulation — no decorative features

---

## Primary Canon Anchors

- `docs/WORLD_BIBLE/REGIONS.md`
- `docs/WORLD_BIBLE/TIMELINE.md`
- `docs/WORLD_BIBLE/FACTIONS.md`
- `docs/lore/UNIVERSE_CONSTITUTION.md`

---

**See Also:**
- `docs/WORLD_BIBLE/REGIONS.md` — Region system documentation
- `autoloads/WorldPersistence.gd` — Scar tracking implementation
- `autoloads/SettlementMemory.gd` — Settlement cluster logic
- `REVIVAL_CONSTRAINTS.md` — Revival gate conditions
