# 🏛️ Memorial & Commemoration System

**Design Proposal — May 6, 2026**  
**Author:** Qwen Code  
**Track:** TRACK 3 (World Richness) + TRACK 4 (System Polish)

---

## What

Pawns commemorate significant events through memorials, gatherings, and oral tradition. History becomes **physical** (monuments), **social** (gatherings), and **cultural** (stories passed down).

---

## Why It Fits HeelKawn

**Core Philosophy Alignment:**
- ✅ **Memory persists** — Pawns remember everything; commemorations make memory collective
- ✅ **History emerges** — Memorials built where events actually happened (not scripted locations)
- ✅ **Knowledge carried** — Oral tradition transmits knowledge through generations
- ✅ **Pawn-activated** — Commemorations triggered by pawn memories, not global timers
- ✅ **Deterministic** — Same events = same commemorations

**Makes HeelKawn Feel Alive:**
- World has WEIGHT — places matter because of what happened there
- Time has RHYTHM — annual gatherings create cultural calendar
- Death has MEANING — fallen pawns remembered, not forgotten
- Culture has DEPTH — rituals emerge from actual history

---

## How It Works

### 1. Memorial Types (Auto-Generated)

**Memorials spawn at event locations after significant WorldMemory events:**

| Event Type | Memorial Type | Trigger |
|------------|--------------|---------|
| Pawn death (violent) | Grave marker, memorial stone | Death recorded to WorldMemory |
| Battle site | Monument, weapon rack | 3+ deaths at same tile within 500 ticks |
| Great achievement | Statue, plaque | ProgressionSystem tier increase |
| Settlement founding | Founding stone | SettlementMemory creation |
| Disaster site | Ruin marker, taboo zone | Fire/flood/death event |
| Knowledge loss | Empty monument, "here died the last [skill] master" | Last carrier dies |

**Memorial data structure:**
```gdscript
{
  "memorial_id": int,
  "tile": Vector2i,
  "memorial_type": String,
  "event_id": int,  # Links to WorldMemory event
  "created_tick": int,
  "associated_pawns": Array[int],  # Pawns being remembered
  "visitors": Array[int],  # Pawns who visited (for gossip spread)
  "decay_level": float  # 0-100 (memorials can erode without maintenance)
}
```

---

### 2. Commemoration Gatherings

**Annual gatherings triggered on event anniversaries:**

**When:**
- Every 10,000 ticks (≈ 1 in-game year) after significant event
- Pawns within range (10 tiles) of memorial automatically attend
- Traveling pawns may make pilgrimages to distant memorials

**What Happens:**
1. **Storytelling** — Elders share event story with youth (knowledge transmission)
2. **Mood bonus** — "Honored" moodlet (+15 mood, 600 tick duration)
3. **Gossip spread** — Event details spread among attendees (GossipManager integration)
4. **Bonding** — Rapport increased between attendees (social ties strengthen)
5. **Teaching** — If event involved skill use, knowledge may be transmitted

**Gathering data:**
```gdscript
{
  "gathering_id": int,
  "memorial_id": int,
  "anniversary_tick": int,
  "attendees": Array[int],
  "stories_told": Array[String],  # Event descriptions
  "knowledge_transmitted": Array[String],  # Skills taught
  "rapport_built": Dictionary  # {pawn_id: rapport_gain}
}
```

---

### 3. Oral Tradition System

**Knowledge transmitted through stories at gatherings:**

**How:**
- Elders (age > 40) have "Storyteller" role automatically
- Youth (age < 20) listen and learn
- Stories include: event details + associated knowledge

**Example:**
```
Event: "Great Fire of Ashwell" (tick 4521)
Knowledge transmitted:
  - Fire safety techniques
  - Which buildings burned (settlement layout history)
  - Who died (grudge formation if arson suspected)
  - How settlement rebuilt (cultural memory)
```

**Knowledge degradation (optional, realistic):**
- Each retelling has 5% chance of slight mutation
- Over generations, facts become legends
- WorldMemory preserves "true" version; oral tradition may diverge

---

### 4. Pilgrimage System

**Pawns travel to distant memorials:**

**Triggers:**
- Pawn has grudge with deceased → visits grave (closure)
- Pawn shares profession with deceased → pays respects
- Pawn is family member → annual pilgrimage
- Pawn heard gossip about site → curiosity visit

**Behavior:**
- Pawn temporarily leaves settlement
- Travels to memorial tile
- Stands in silence (10-30 ticks)
- Returns with moodlet ("Found Peace" +10 mood or "Haunted" -5 mood)

---

## Emergent Possibilities

**Unpredictable outcomes from simple rules:**

1. **Sacred Geography** — Map becomes dotted with meaningful sites
2. **Cultural Calendars** — Settlements have unique gathering schedules based on their history
3. **Memorial Clusters** — Battle sites become monument complexes
4. **Taboo Zones** — Disaster sites avoided, become wild places
5. **Pilgrimage Routes** — Paths worn between frequently visited memorials
6. **Historical Districts** — Old settlement areas with dense memorial concentration
7. **Knowledge Preservation** — Oral tradition keeps skills alive even when carriers rare
8. **Grudge Perpetuation** — Memorials remind families of feuds, grudges persist longer
9. **Tourism** — Pawns visit famous memorials in other settlements (cultural exchange)
10. **Player Discovery** — Player stumbles on ancient memorial, reads chronicle entry

---

## Implementation Plan

### Phase 1: Core System (2-3 hours)

**Files to Create:**
- `autoloads/MemorialSystem.gd` — Memorial spawning, tracking, decay
- `scripts/events/CommemorationGathering.gd` — Gathering logic
- `scripts/pawn/PilgrimageAI.gd` — Pilgrimage behavior

**Files to Modify:**
- `autoloads/WorldMemory.gd` — Trigger memorial creation on events
- `scripts/pawn/Pawn.gd` — Add pilgrimage state, gathering attendance
- `scripts/ui/ChronicleLedger.gd` — Display memorial/gathering events

### Phase 2: Integration (1-2 hours)

**Integrate with:**
- `PawnConsciousness.gd` — Memories trigger memorial interest
- `GrudgeManager.gd` — Memorial for grudge-related deaths
- `GossipManager.gd` — Gossip spreads at gatherings
- `KnowledgeSystem.gd` — Oral tradition transmits knowledge
- `SettlementMemory.gd` — Settlement tracks its memorials

### Phase 3: Polish (1 hour)

**Visual:**
- Memorial sprites (grave markers, monuments, statues)
- Gathering visual indicator (pawns in circle)
- Pilgrimage path rendering

**UI:**
- Click memorial → read inscription
- F10 debug: "Memorials" report (list all memorials, visitor counts)
- Chronicle entries for gatherings

---

## Code Sketches

### Memorial Creation (WorldMemory integration)

```gdscript
# In WorldMemory.gd, after recording death event
func _on_significant_event(event: Dictionary) -> void:
    if event.type == "pawn_death" and event.get("violent", false):
        MemorialSystem.create_memorial({
            "tile": event.tile,
            "type": "grave_marker",
            "event_id": event.id,
            "associated_pawns": [event.pawn_id]
        })
    
    if event.type == "battle":
        MemorialSystem.create_memorial({
            "tile": event.tile,
            "type": "battle_monument",
            "event_id": event.id,
            "associated_pawns": event.participants
        })
```

### Gathering Trigger (annual anniversary)

```gdscript
# In MemorialSystem.gd
func _process_commemorations(tick: int) -> void:
    for memorial in memorials:
        var ticks_since_event := tick - memorial.event_tick
        if ticks_since_event > 0 and ticks_since_event % 10000 == 0:
            _trigger_commemoration_gathering(memorial)

func _trigger_commemoration_gathering(memorial: Dictionary) -> void:
    var attendees := _find_nearby_pawns(memorial.tile, 10.0)
    if attendees.size() == 0:
        return  # Nobody to attend
    
    var gathering := {
        "memorial_id": memorial.id,
        "tick": GameManager.tick_count,
        "attendees": attendees,
        "stories_told": _get_event_stories(memorial.event_id),
        "knowledge_transmitted": _get_associated_knowledge(memorial)
    }
    
    _apply_gathering_effects(gathering)
```

### Pilgrimage AI (Pawn behavior)

```gdscript
# In Pawn.gd
func _check_pilgrimage_desire() -> bool:
    # Check if any memorials call to this pawn
    for memorial in MemorialSystem.get_memorials():
        if _should_pilgrimage(memorial):
            _start_pilgrimage(memorial)
            return true
    return false

func _should_pilgrimage(memorial: Dictionary) -> bool:
    # Family member
    if memorial.associated_pawns.has_any_of(my.family_ids):
        return true
    
    # Shared profession with deceased
    if memorial.deceased_profession == my.profession:
        return true
    
    # Grudge closure
    if GrudgeManager.has_grudge_with_any(memorial.associated_pawns):
        return true
    
    return false
```

---

## Acceptance Criteria

**System is complete when:**

- [ ] Memorials auto-create at event locations
- [ ] Commemoration gatherings trigger annually
- [ ] Pawns attend gatherings when nearby
- [ ] Pilgrimage AI works (pawns travel to memorials)
- [ ] Oral tradition transmits knowledge at gatherings
- [ ] Memorials visible on map (clickable)
- [ ] Chronicle entries for memorials/gatherings
- [ ] F10 debug report shows memorial data
- [ ] Integrates with grudge/gossip/consciousness systems

---

## Collaboration Asks

**TRACK 4 AI (System Polish):**
- Integrate memorials with GrudgeManager (memorials for feud deaths)
- Integrate with GossipManager (gossip spreads at gatherings)
- Integrate with PawnConsciousness (memories trigger pilgrimage desire)

**TRACK 1 AI (UI):**
- Memorial click UI (read inscription)
- F10 debug panel for memorials
- Chronicle ledger entries for gatherings

**TRACK 5 AI (Building):**
- Memorial building types (grave marker, monument, statue)
- Resource requirements for memorial construction

---

## Open Questions — **ANSWERED BY HUMAN (May 6, 2026)**

1. **Should player be able to build memorials manually?** 
   - ✅ **YES** — Both manual (player-built) AND automatic (NPC/HeelKawnian-built)
   - Player can place memorials for their pawns
   - NPCs/HeelKawnians autonomously build memorials for their dead (family, friends, grudge-enemies)

2. **Should memorials decay over time?**
   - ❌ **NO** — Memorials are PERMANENT, do not decay
   - **BUT:** Should be minimal visual footprint — "just a blip" (small grave marker)
   - Click to read full inscription (who, what, why, when)

3. **How to handle mass death events?**
   - ✅ **Mass memorial** — One monument listing all names + event description
   - Example: "Here 12 fell in the Great Battle of Ashwell, Year 45"
   - Lists all associated pawn names (clickable to read individual stories)

4. **Should knowledge degradation be optional?**
   - ✅ **YES** — Oral tradition mutates stories over generations (5% decay rate)
   - Makes the system feel more realistic — legends diverge from facts
   - WorldMemory preserves "true" version; oral tradition may differ

**Human decision needed for these.**

---

*Proposal created: May 6, 2026*  
*Status: Awaiting feedback, ready to implement*
