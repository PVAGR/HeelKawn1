# 🚀 HeelKawnian Evolution - Implementation Plan

**Created:** May 14, 2026  
**Priority:** CRITICAL - Core to HeelKawn vision  
**Timeline:** 2 weeks for Phase 5A foundation

> This is an implementation proposal, not proof that the systems below exist. Use `HEELKAWN_PROJECT_COMPASS.md` and `BUILD_INVENTORY.md` to decide current truth before coding.

---

## 📋 PHASE 5A: FOUNDATION (This Session - May 7, 2026)

### Task 1: Civilization Stage Tracking ✅ INITIAL LIVE

**File:** `autoloads/CivilizationStage.gd` (NEW)

**Purpose:** Calculate and track civilization development stage (0-10)

**Implementation:**
```gdscript
extends Node

# Civilization stages
const STAGE_PRIMITIVE = 0
const STAGE_NEOLITHIC = 1
const STAGE_BRONZE_AGE = 2
const STAGE_IRON_AGE = 3
const STAGE_MEDIEVAL = 4
const STAGE_RENAISSANCE = 5
const STAGE_INDUSTRIAL = 6
const STAGE_MODERN = 7
const STAGE_INFORMATION = 8
const STAGE_SPACE_AGE = 9
const STAGE_POST_SCARCITY = 10

# Stage names for display
const STAGE_NAMES = {
    0: "Primitive",
    1: "Neolithic",
    2: "Bronze Age",
    3: "Iron Age",
    4: "Medieval",
    5: "Renaissance",
    6: "Industrial",
    7: "Modern",
    8: "Information",
    9: "Space Age",
    10: "Post-Scarcity"
}

func get_civilization_stage(settlement_id: int) -> int:
    var score: int = calculate_civilization_score(settlement_id)
    return score_to_stage(score)

func calculate_civilization_score(settlement_id: int) -> int:
    var score: int = 0
    
    # Technology score (0-30 points)
    if TechnologySystem != null:
        var techs = TechnologySystem.get_researched_technologies(settlement_id)
        score += mini(30, techs.size() * 2)
    
    # Knowledge score (0-20 points)
    if KnowledgeSystem != null:
        var knowledge_types = KnowledgeSystem.get_known_types(settlement_id)
        score += mini(20, knowledge_types.size())
    
    # Infrastructure score (0-20 points)
    if SettlementMemory != null:
        var buildings = SettlementMemory.get_buildings(settlement_id)
        score += mini(20, buildings.size() / 5)
    
    # Complexity score (0-20 points)
    score += mini(20, get_profession_diversity(settlement_id) * 3)
    
    # Quality of life score (0-10 points)
    score += mini(10, int(get_average_lifespan(settlement_id) / 10))
    
    return score

func score_to_stage(score: int) -> int:
    if score < 20: return STAGE_PRIMITIVE
    if score < 40: return STAGE_NEOLITHIC
    if score < 60: return STAGE_BRONZE_AGE
    if score < 80: return STAGE_IRON_AGE
    if score < 100: return STAGE_MEDIEVAL
    if score < 120: return STAGE_RENAISSANCE
    if score < 140: return STAGE_INDUSTRIAL
    if score < 160: return STAGE_MODERN
    if score < 180: return STAGE_INFORMATION
    if score < 200: return STAGE_SPACE_AGE
    return STAGE_POST_SCARCITY

func get_stage_name(stage: int) -> String:
    return STAGE_NAMES.get(stage, "Unknown")

func get_profession_diversity(settlement_id: int) -> int:
    # Count unique professions in settlement
    return 0  # TODO: Implement

func get_average_lifespan(settlement_id: int) -> int:
    # Calculate from death events in WorldMemory
    return 0  # TODO: Implement
```

**Integration:**
- Registered as autoload in `project.godot`.
- Displayed in `ColonyHUD` identity line as an era label.
- Added to F10 as `03B · Civilization Stage`.
- Current implementation is intentionally derived/read-only. It does not advance eras by itself.

---

### Task 1B: HeelKawnian Development Profiles + Matrix Job Bias ✅ INITIAL LIVE

**Files:** `scripts/core/HeelKawnianIdentity.gd` (class_name Resource, not an autoload), `autoloads/HeelKawnianManager.gd`, `scripts/pawn/Pawn.gd`, `scripts/ui/CreatorDebugMenu.gd`

**Purpose:** Give every sprite a deterministic, inspectable development profile and use that profile as a real job-choice influence layer.

**Implemented:**
- Stable soul identity creation from live pawn data.
- Identity resources now remember profile history and evolve simple traits from meaningful events.
- Per-pawn profiles derive development score, phase, drive, next need, era context, skill summary, knowledge summary, social signal, preservation pressure, innovation pressure, and trauma pressure.
- Matrix job biases derive from drive, needs, skill, profession, era context, and identity traits.
- `Pawn.gd` consumes those Matrix biases during ordinary `JobManager` claiming without overriding job legality.
- Strong Matrix-influenced job choices log back through `heelkawnian_development` events for auditability.
- F10 `49 · HeelKawnians` prints aggregate drive/phase counts, sample individual profiles, top Matrix job pulls, and rationale.

**Current boundary:**
- This is an initial job-bias bridge, not full agency.
- It now includes an initial deterministic social intent bridge (`social_seek`, `teach_seek`, `grudge_confront`) consumed by pawn idle autonomy.
- It does not yet provide full household planning, coordinated settlement ambition planning, dedicated research target steering, or broad movement strategy control.
- The next frontier is deeper Matrix AI steering across social, knowledge, household, and settlement layers.

---

### Task 2: Knowledge Combination System ⏳ PENDING

**File:** `autoloads/KnowledgeSystem.gd` (MODIFY)

**Add to KnowledgeSystem:**
```gdscript
# Innovation system
signal innovation_discovered(pawn_id: int, knowledge_a: int, knowledge_b: int, result: Dictionary)

# Knowledge combination recipes
# Format: {k1, k2} -> {result_knowledge, success_chance_base}
var knowledge_combinations: Dictionary = {
    # {Hunting, Crafting} -> Better Bows
    "{1,7}": {"result": 19, "name": "Archery", "chance": 0.05},
    # {Farming, Crafting} -> Irrigation
    "{2,5}": {"result": 20, "name": "Irrigation", "chance": 0.05},
    # {Fire, Clay} -> Pottery
    "{4,5}": {"result": 21, "name": "Pottery", "chance": 0.05},
    # {Mining, Fire} -> Smelting
    "{3,4}": {"result": 22, "name": "Metalworking", "chance": 0.03},
    # {Leadership, Diplomacy} -> Law
    "{6,8}": {"result": 23, "name": "Legal System", "chance": 0.04},
    # {Crafting, Leadership} -> Guilds
    "{5,6}": {"result": 24, "name": "Guild System", "chance": 0.04},
}

func try_innovate(pawn_id: int, knowledge_a: int, knowledge_b: int) -> bool:
    var pawn = get_pawn(pawn_id)
    if pawn == null:
        return false
    
    var rng = WorldRNG.for_pawn(pawn_id, GameManager.tick_count)
    
    # Get combination recipe
    var key = "{%d,%d}" % [mini(knowledge_a, knowledge_b), maxi(knowledge_a, knowledge_b)]
    if not knowledge_combinations.has(key):
        return false  # No combination exists
    
    var recipe: Dictionary = knowledge_combinations[key]
    
    # Calculate success chance
    var success_chance: float = recipe.chance
    success_chance += get_knowledge_level(pawn_id, knowledge_a) * 0.02
    success_chance += get_knowledge_level(pawn_id, knowledge_b) * 0.02
    success_chance += pawn.intelligence * 0.01
    success_chance += get_tool_bonus(pawn_id) * 0.03
    success_chance += get_institution_bonus(pawn_id) * 0.05
    
    # Check for success
    if rng.float() < success_chance:
        # Success! Teach new knowledge
        var new_knowledge: int = recipe.result
        teach_knowledge(pawn_id, new_knowledge)
        
        # Record innovation event
        _record_innovation(pawn_id, knowledge_a, knowledge_b, new_knowledge)
        
        # Emit signal
        innovation_discovered.emit(pawn_id, knowledge_a, knowledge_b, {
            "knowledge_id": new_knowledge,
            "name": recipe.name
        })
        
        return true
    
    return false

func get_knowledge_level(pawn_id: int, knowledge_type: int) -> int:
    # Return 0-10 based on how long pawn has known this knowledge
    return 0  # TODO: Implement

func get_tool_bonus(pawn_id: int) -> float:
    # Return 0-2 based on tool quality
    return 0.0  # TODO: Implement

func get_institution_bonus(pawn_id: int) -> float:
    # Return 0-1 based on guild/university membership
    return 0.0  # TODO: Implement

func _record_innovation(pawn_id: int, k1: int, k2: int, result: int) -> void:
    if WorldMemory != null:
        WorldMemory.record_event({
            "type": "innovation",
            "pawn_id": pawn_id,
            "knowledge_a": k1,
            "knowledge_b": k2,
            "result": result,
            "tick": GameManager.tick_count
        })
```

---

### Task 3: Book Crafting ⏳ PENDING

**File:** `autoloads/CraftingSystem.gd` (MODIFY)

**Add recipes:**
```gdscript
# Paper recipe
{
    "name": "Paper",
    "ingredients": {"plant_fiber": 10},
    "craft_time": 60,
    "result": {"item": "paper", "count": 5},
    "knowledge_required": 5,  # Writing knowledge
    "unlock_tech": "papermaking"
}

# Ink recipe
{
    "name": "Ink",
    "ingredients": {"berry": 5, "soot": 2, "water": 1},
    "craft_time": 30,
    "result": {"item": "ink", "count": 1},
    "knowledge_required": 5,
    "unlock_tech": null
}

# Leather recipe
{
    "name": "Leather",
    "ingredients": {"animal_hide": 1, "tannin": 5},
    "craft_time": 120,
    "result": {"item": "leather", "count": 1},
    "knowledge_required": 5,
    "unlock_tech": "leatherworking"
}

# Book recipe
{
    "name": "Book",
    "ingredients": {"paper": 20, "leather": 1, "ink": 1},
    "craft_time": 300,
    "result": {"item": "book", "count": 1},
    "knowledge_required": 5,
    "unlock_tech": "writing",
    "special": "Can store up to 10 knowledge types"
}
```

**File:** `scenes/ui/CraftingMenu.gd` (MODIFY)

- Add book UI (shows stored knowledge when crafted)
- Inscription interface (select which knowledge to store)

---

### Task 4: Quality of Life Tracking ⏳ PENDING

**File:** `autoloads/WorldMemory.gd` (MODIFY)

**Add:**
```gdscript
# Lifespan tracking
var pawn_births: Dictionary = {}  # pawn_id -> birth_tick
var pawn_deaths: Dictionary = {}  # pawn_id -> {death_tick, age, cause}

func record_birth(pawn_id: int, tick: int) -> void:
    pawn_births[pawn_id] = tick

func record_death(pawn_id: int, tick: int, cause: String) -> void:
    if pawn_births.has(pawn_id):
        var age: int = tick - pawn_births[pawn_id]
        pawn_deaths[pawn_id] = {
            "death_tick": tick,
            "age": age,
            "cause": cause
        }

func get_average_lifespan(settlement_id: int) -> int:
    var total_age: int = 0
    var count: int = 0
    
    for pawn_id in pawn_deaths:
        var death_data: Dictionary = pawn_deaths[pawn_id]
        # Filter by settlement (TODO: track pawn settlement)
        total_age += death_data.age
        count += 1
    
    if count == 0:
        return 0
    
    return total_age / count

func get_literacy_rate(settlement_id: int) -> float:
    # Count pawns who know reading/writing knowledge
    var total: int = 0
    var literate: int = 0
    
    if KnowledgeSystem != null:
        # TODO: Get all pawns in settlement
        # For each pawn, check if they know reading knowledge (type 5?)
        pass
    
    if total == 0:
        return 0.0
    
    return float(literate) / float(total)
```

---

## 📊 INTEGRATION POINTS

### ColonyHUD.gd
```gdscript
# Add civilization stage label
var civ_stage_label: Label = $CivStageLabel

func _update_settlement_info() -> void:
    if CivilizationStage != null:
        var stage: int = CivilizationStage.get_civilization_stage(current_settlement_id)
        var stage_name: String = CivilizationStage.get_stage_name(stage)
        civ_stage_label.text = "Era: %s" % stage_name
```

### F10 Debug Menu (#3 - Colony Sim)
```gdscript
func _report_colony_sim() -> void:
    print("--- CIVILIZATION PROGRESS ---")
    for settlement in SettlementMemory.settlements:
        var stage: int = CivilizationStage.get_civilization_stage(settlement.id)
        print("  %s: %s (Stage %d)" % [settlement.name, CivilizationStage.get_stage_name(stage), stage])
        print("    Avg Lifespan: %d years" % WorldMemory.get_average_lifespan(settlement.id))
        print("    Literacy: %.1f%%" % (WorldMemory.get_literacy_rate(settlement.id) * 100))
```

---

## ✅ COMPLETION CRITERIA

**Phase 5A Complete When:**

1. ✅ CivilizationStage.gd exists and calculates stages correctly
2. ✅ Initial HeelKawnian development profiles visible in F10 #49
3. ⏳ HeelKawnian profiles bias real pawn behavior
4. ⏳ Knowledge combination system allows innovation
5. ⏳ Books craftable and store knowledge
6. ⏳ Lifespan/literacy tracked and displayed
7. ✅ Initial systems visible in debug menu
8. ✅ No compilation errors
9. ✅ Game runs without crashes

---

## 🎯 NEXT SESSION PREVIEW

**Phase 5B: Institutions**

1. Apprenticeship System (masters teach apprentices)
2. Guild Buildings (knowledge sharing networks)
3. University Building (collective research)
4. Research Collaboration (team projects)

**Timeline:** 2-4 weeks

---

*Implementation Plan v1.0 — "One step at a time, from primitive to post-scarcity."*
