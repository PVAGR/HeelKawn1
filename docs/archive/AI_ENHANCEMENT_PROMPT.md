# HeelKawn AI Enhancement Prompt

## Vision: The Truman Show — Living NPCs

### Core Philosophy
NPCs in HeelKawn are NOT game entities executing scripts. They are **digital citizens** with:
- Personal histories nobody else knows
- Goals they're actively pursuing
- Social lives with gossip and reputation
- Careers they're advancing in
- Dramatic stories unfolding naturally

---

## System 1: Long-Term Memory System

### Implementation
Each NPC stores memories indexed by:

```
enum MemoryType {
    PERSONAL = 0,      # "I found the perfect berry patch"
    SOCIAL = 1,        # "Mira said she'll help me build"
    EVENT = 2,         # "That wolf attack last spring"
    GOAL = 3,          # "I want to become the best cook"
    REGRET = 4,        # "I should've stayed home that day"
}
```

### Memory Properties
- **Importance** (0.0-1.0): More important = longer retention
- **Decay Rate**: Lower importance = faster forgetting
- **Revival Trigger**: Certain events cause old memories to resurface
- **Narrative Value**: Memories drive NPC storytelling

### Example Memory Data
```gdscript
{
    "type": MemoryType.SOCIAL,
    "summary": "taught_farming_to_rikard",
    "importance": 0.8,
    "tick_created": 15000,
    "last_recalled": 18500,
    " Emotional_sting": "pride",
    "people_involved": [pawn_id_rikard],
    "location": Vector2i(45, 23)
}
```

---

## System 2: Goal & Aspiration Engine

### Hierarchy of Goals

```
enum GoalScope {
    IMMEDIATE = 0,    # "Finish harvesting this wheat"
    TODAY = 1,         # "Get enough food for winter"
    THIS_YEAR = 2,     # "Build a proper house"
    LIFELONG = 3,      # "Become the settlement's healer"
}
```

### Goal Properties
- **Stakes**: What matters if goal fails
- **Obstacles**: Current blockers
- **Hope Level**: Probability NPC believes it achievable
- **External Dependencies**: Needs others' help

### Daily Goal Selection
NPC chooses 1-2 main goals each "morning" based on:
1. Lifelong aspirations (weighted by hope_level)
2. Today's survival needs
3. Social promises made
4. Random dramatic opportunity

---

## System 3: Gossip & Cultural Transmission

### Gossip Properties
```gdscript
{
    "content": "rikard_found_deep_water_source",
    "source_pawn_id": 7,    # Who told me
    "original_source": 12, # Who discovered it
    "accuracy": 0.85,       # 1.0 = verified truth
    "tick_first_heard": 15200,
    "spread_count": 3,    # How many times I've shared
    "reliability_score": 0.7  # Based on source reputation
}
```

### Gossip Propagation Rules
- NPCs share when **socially bonded** (relationship > 0.3)
- Accuracy degrades each hop (base_decay = 0.1)
- Hot gossip spreads 3x faster
- Secrets have **minimum_trust** threshold

### Cultural Memory
Shared beliefs/knowledge that spread:
- "The old grave in the north is haunted"
- "Mira knows the best hunting grounds"
- "We should build a wall before winter"

---

## System 4: Career & XP Progression

### Career Categories
```gdscript
enum CareerTrack {
    NONE = -1,
    FORAGER = 0,
    HUNTER = 1,
    BUILDER = 2,
    HEALER = 3,
    FIGHTER = 4,
    CRAFTSMAN = 5,
    SAGE = 6,      # Knowledge keeper
    LEADER = 7,   # Settlement authority
}
```

### XP & Advancement
```gdscript
{
    "career_track": CareerTrack.BUILDER,
    "xp_total": 450,
    "xp_level": 7,    # level = floor(sqrt(xp / 100))
    "title": "apprentice_builder",
    "master_id": 5,   # Who taught me
    "known_by": [pawn_ids who know my skill],
    "proud_moments": [
        {"event": "first_bed", "tick": 15200},
        {"event": "wall_section", "tick": 18000}
    ]
}
```

### Level Titles (Example: Builder)
- **Novice** (XP 0-99): "apprentice_builder"
- **Journeyman** (XP 100-299): "builder"
- **Master** (XP 300-599): "master_builder"
- **Grand Master** (XP 600+): "architect"

---

## System 5: Dramatic Event Generator

### Event Categories
```gdscript
enum DramaticEvent {
    DISCOVERY = 0,     # Found something important
    CONFLICT = 1,     # Argument/escalation
    ACCOMPLISHMENT = 2, # Achieved goal
    LOSS = 3,         # Death/relationship break
    REDEMPTION = 4,    # Made amends
    REUNION = 5,      # Found lost person
    BETRAYAL = 6,     # Trust broken
    SACRIFICE = 7,    # Helped at cost
}
```

### Story Engine
NPCs generate mini-narratives:

1. **Setup**: Goal established
2. **Complication**: Obstacle appears
3. **Rising Action**: Attempts to overcome
4. **Climax**: Major moment
5. **Resolution**: Success/failure
6. **Coda**: Memory formed

### Story Seed Examples
- *"The newcomer needs shelter before night. Help them?"*
- *"My former friend betrayed me years ago. Confront or forgive?"*
- *"I discovered a rare herb. Sell knowledge or keep secret?"*

---

## Integration Points

### Pawn.gd Enhancements
Add to `_ready()`:
```gdscript
# Initialize Phase 4 systems
_long_term_memory = LongTermMemory.new(data.id)
_goal_engine = GoalEngine.new(self)
_gossip_network = GossipPropagation.new(self)
_career_system = CareerXP.new(self)
_dramatic_engine = DramaticEventGenerator.new(self)
```

### Game Manager Integration
- `_tick_hour()` triggers `goal_engine.pick_daily_goals()`
- `_tick_week()` triggers `dramatic_engine.attempt_story_beat()`
- When NPC meets another: `gossip_network.share_information()`

---

## Success Metrics (Visual)

### If NPCs Feel Alive, You See:
- ✅ NPCs in conversation clusters (social priority)
- ✅ NPCs mentioning past events ("Remember when...")
- ✅ NPCs with visible career items (tools, clothing)
- ✅ "Dramatic" events in world chat
- ✅ Player can observe but not fully predict NPC behavior
- ✅ NPCs responding to each other, not just world state

### Anti-Patterns to Avoid:
- ❌ All NPCs doing same behavior
- ❌ NPCs only react to player
- ❌ Predictable day-night cycles without variation
- ❌ No relationship changes over time
- ❌ No visible character growth

---

## Godot 4 Implementation Notes

### Performance Targets
- Max 50 NPCs with full Phase 4
- Tick budget per NPC: < 2ms
- Memory per NPC: ~5KB

### Key Classes to Implement
1. `LongTermMemory.gd` - Memory storage & retrieval
2. `GoalEngine.gd` - Goal management
3. `GossipPropagation.gd` - Information spread
4. `CareerXP.gd` - Skill tracking
5. `DramaticEventGenerator.gd` - Story generation