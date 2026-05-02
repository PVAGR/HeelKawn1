# FACTIONS

**Emergent Identities in HeelKawn**  
*Last Updated: 2026-05-02*

Factions in HeelKawn are **not pre-scripted groups** — they are emergent identities that arise from deterministic history, cultural memory, and settlement patterns. This document tracks canonical faction seeds and their evolution rules.

> **Design Principle:** Factions are read-only interpretations of facts. They emerge from WorldMemory events, WorldMeaning labels, and CulturalMemory patterns. No hardcoded allegiances.

---

## Faction System Architecture

### Emergence Pipeline
```
WorldMemory (facts) 
  → CulturalMemory (patterns) 
  → SettlementPlanner (culture types) 
  → FactionRegistry (identity clusters)
```

### Identity Drivers
1. **Scar Profile:** History of death/destruction in region
2. **Conflict Recurrence:** Frequency of war/battle events
3. **Recovery Pattern:** Peace duration and revival success
4. **Resource Pressure:** Food/wood/stone scarcity history
5. **Knowledge Retention:** Teaching event density
6. **Kinship Density:** Family network strength

---

## Faction Entry Template

```markdown
Name:
Origin region:
Identity driver:
Behavioral pattern:
Architecture markers:
Current trajectory:
Region archetype link:
Supporting deterministic profile:
  - Scar profile:
  - Conflict profile:
  - Recovery profile:
  - Knowledge profile:
  - Kinship profile:
```

---

## Canonical Faction Seeds

### Open Hearth Clusters

**Status:** Active cultural type (SettlementPlanner.CULTURE_OPEN)

- **Origin region:** Low-scar recovery zones (e.g., Region 1: The Quiet Valley)
- **Identity driver:** Trust in stable resource patterns
- **Behavioral pattern:** Expansion and rebuilding, outward-facing trade
- **Architecture markers:** Broader shared spaces, accessible paths, minimal fortifications
- **Current trajectory:** Likely to revive abandoned-but-quiet settlements
- **Region archetype link:** `The Quiet Ring`
- **Peace Requirement:** 18000 ticks (lowest among cultures)
- **Supporting deterministic profile:**
  - Scar profile: Low-to-moderate (0-1)
  - Conflict profile: Low recurrence (<2 events per 10000 ticks)
  - Recovery profile: Strong peace-gated revival potential
  - Knowledge profile: High teaching event density
  - Kinship profile: Extended family networks, multiple households

### Stoneward Enclaves

**Status:** Active cultural type (SettlementPlanner.CULTURE_DEFENSIVE)

- **Origin region:** Frequently bloodied regions (e.g., Region 2: The Bloodied Fields)
- **Identity driver:** Memory of repeated loss
- **Behavioral pattern:** Defense-first development, suspicion of outsiders
- **Architecture markers:** Perimeter-heavy builds, constrained entries, guard towers
- **Current trajectory:** High persistence, low outward integration
- **Region archetype link:** `Red Scar Basin`
- **Peace Requirement:** 42000 ticks (highest among cultures)
- **Supporting deterministic profile:**
  - Scar profile: Moderate-to-high (2-3)
  - Conflict profile: Repeated clustering (>5 events per 10000 ticks)
  - Recovery profile: Limited unless conflict pressure drops for sustained periods
  - Knowledge profile: Martial knowledge prioritized (combat skills)
  - Kinship profile: Tight nuclear families, strong loyalty bonds

### Cautious Steadings

**Status:** Active cultural type (SettlementPlanner.CULTURE_CAUTIOUS)

- **Origin region:** Stable frontier zones (e.g., Region 3: The Teacher's Hold)
- **Identity driver:** Balanced risk assessment, pragmatic adaptation
- **Behavioral pattern:** Measured growth, selective trade partnerships
- **Architecture markers:** Functional layouts, modular expansion, stockpile integration
- **Current trajectory:** Gradual expansion, knowledge preservation focus
- **Region archetype link:** `The Middle Grounds`
- **Peace Requirement:** 30000 ticks (baseline standard)
- **Supporting deterministic profile:**
  - Scar profile: Low (0-1)
  - Conflict profile: Occasional (1-2 events per 10000 ticks)
  - Recovery profile: Steady, sustainable revival
  - Knowledge profile: Balanced skill distribution
  - Kinship profile: Multi-generational households, apprenticeship traditions

---

## Historical Faction Formations

### The First Collapse Survivors (Tick 15000-25000)

**Formation Event:** First starvation cascade in Region 0

- **Origin:** Scattered survivors from The First Scar
- **Fate:** Dispersed into Quiet Valley and Teacher's Hold
- **Legacy:** Established caution around resource hoarding
- **Cultural Impact:** Contributed to CRITICAL_LOCAL_FOOD_PRESSURE threshold (0.9)

### The Bloodied Fields Coalition (Tick 40000-60000)

**Formation Event:** Repeated war_battle_spawned events in Region 2

- **Origin:** Multiple settlements forced into defensive alliance
- **Fate:** Fragmented after 30000-tick peace period
- **Legacy:** Established DEFENSIVE culture archetype
- **Cultural Impact:** PEACE_TICKS_PER_BRANCH[DEFENSIVE] = 42000

### The Knowledge Keepers (Tick 70000+)

**Formation Event:** Teaching event clustering in Region 3

- **Origin:** Teachers and apprentices preserving skills
- **Fate:** Ongoing — active knowledge transmission network
- **Legacy:** Prevented technology loss in cluster
- **Cultural Impact:** OPEN culture bonus (+15 to revival score)

---

## Faction Registry System

### Runtime Tracking

The `FactionRegistry.gd` autoload tracks emergent factions:

```gdscript
# Faction data structure
{
    "faction_id": int,
    "name": String,
    "origin_region": int,
    "culture_type": int,  # CULTURE_OPEN/CAUTIOUS/DEFENSIVE
    "member_settlements": Array[int],  # Region keys
    "formation_tick": int,
    "identity_markers": Dictionary,
    "trajectory": String  # "expanding", "stable", "declining"
}
```

### Faction Detection Rules

1. **Minimum Cluster Size:** 3+ settlements with same culture type
2. **Shared History:** ≥5 common WorldMemory events
3. **Geographic Proximity:** Within 10 regions of each other
4. **Cultural Cohesion:** Same architecture signatures (PERIM_R, DOOR2_MIN_SPAN)

---

## Faction Evolution Mechanics

### Growth Conditions
- Successful revival of abandoned settlements
- High birth rate in member settlements
- Knowledge retention across generations
- Trade network expansion

### Decline Conditions
- Scar level ≥3 in core regions
- Extended conflict (>5000 ticks without peace)
- Knowledge loss (teacher deaths without apprentices)
- Resource exhaustion (food pressure >0.9 for 10000+ ticks)

### Transformation Triggers
- **Open → Defensive:** After 3+ conflict events in 10000 ticks
- **Defensive → Open:** After 50000 ticks of sustained peace
- **Cautious → Open:** After successful revival of 2+ settlements
- **Any → Collapsed:** Scar level ≥3 in all core regions

---

## Player Interaction with Factions

### Spectator Mode
- Observe faction boundaries via map overlay
- Track faction trajectories over time
- View faction history in chronicle log

### Incarnation Mode
- Born into faction member settlements
- Subject to faction behavioral patterns
- Can influence faction through actions (teaching, building, defending)
- Cannot override faction identity directly

### Forbidden Interactions
- No faction creation by player fiat
- No forced faction mergers
- No heroic faction leadership overrides
- No morality-based faction alignment

---

## Future Faction Development

### Phase 4 (Current)
- [x] Culture type system (OPEN/CAUTIOUS/DEFENSIVE)
- [x] Architecture signature tracking
- [x] Peace requirement differentiation
- [ ] FactionRegistry population from settlement clusters
- [ ] Faction name generation from history

### Phase 5 (Planned)
- [ ] Inter-faction trade networks
- [ ] Diplomatic relations (emergent, not scripted)
- [ ] War declaration from memory patterns
- [ ] Faction-specific cultural events

### Long-Term (Phase 6+)
- [ ] Religious schisms from MythMemory
- [ ] Ideological conflicts from KnowledgeSystem
- [ ] Succession crises from BloodlineSystem
- [ ] Cross-generational faction identity shifts

---

## Testing & Validation

### Faction Detection Tests
1. Create 3+ settlements with same culture type within 10 regions
2. Verify FactionRegistry detects cluster after 2000 ticks
3. Verify faction name derives from historical events
4. Verify faction trajectory updates with settlement changes

### Faction Evolution Tests
1. Induce conflict in OPEN faction region
2. Verify culture shift to DEFENSIVE after 3+ events
3. Verify peace requirement increases to 42000 ticks
4. Verify architecture signatures update accordingly

---

## References

- `autoloads/FactionRegistry.gd` — Runtime faction tracking
- `autoloads/SettlementPlanner.gd` — Culture type assignment
- `autoloads/CulturalMemory.gd` — Tradition inheritance
- `docs/WORLD_BIBLE/REVIVAL_CONSTRAINTS.md` — Revival gates by culture
- `docs/lore/MAP_OF_PROMETHEUS.md` — Regional context

