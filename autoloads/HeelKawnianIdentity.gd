extends Resource
class_name HeelKawnianIdentity

var id: String = ""
var origin_seed: int = 0
var traits: Dictionary = {}
var memory: Array = []
var phase: String = "emerging"
var age: int = 0
var last_profile: Dictionary = {}
var development_history: Array[Dictionary] = []
var cultural_heritage: String = "wanderer"

func _init(_id: String = "", _origin_seed: int = 0) -> void:
    id = _id
    origin_seed = _origin_seed
    traits = {}
    memory = []
    phase = "emerging"
    age = 0
    last_profile = {}
    development_history = []

func evolve(event: Dictionary) -> void:
    var event_type: String = str(event.get("type", event.get("event_type", "unknown")))
    age += 1
    memory.append(event.duplicate(true))
    if memory.size() > 64:
        memory.pop_front()

    match event_type:
        "knowledge_acquisition", "knowledge_discovery", "knowledge_rediscovery", "teaching_success":
            _add_trait("curiosity", 0.04)
            _add_trait("knowledge_drive", 0.05)
        "knowledge_inscribed", "knowledge_sealed":
            _add_trait("preservation_drive", 0.06)
        "structure_built", "building_constructed", "cooperative_build", "job_completed":
            _add_trait("labor_pride", 0.03)
        "pawn_death", "starvation_event", "disaster", "fire_started":
            _add_trait("caution", 0.05)
        "teaching_event", "skill_taught":
            _add_trait("mentor_drive", 0.04)
        "social_meeting", "social_bond_milestone":
            _add_trait("social_memory", 0.03)
        "matrix_decision":
            var payload: Dictionary = event.get("payload", {})
            match str(payload.get("drive", "")):
                "learn", "innovate":
                    _add_trait("curiosity", 0.01)
                    _add_trait("knowledge_drive", 0.01)
                "preserve":
                    _add_trait("preservation_drive", 0.015)
                "practice", "serve_settlement":
                    _add_trait("labor_pride", 0.01)
                "recover", "survive":
                    _add_trait("caution", 0.01)
                "teach":
                    _add_trait("mentor_drive", 0.015)
                "bond":
                    _add_trait("social_memory", 0.01)


func absorb_profile(profile: Dictionary) -> void:
    last_profile = profile.duplicate(true)
    phase = str(profile.get("development_phase", phase))
    var tick: int = int(profile.get("tick", 0))
    development_history.append({
        "tick": tick,
        "phase": phase,
        "drive": str(profile.get("development_drive", "")),
        "era": str(profile.get("era", "")),
        "score": int(profile.get("development_score", 0)),
    })
    if development_history.size() > 32:
        development_history.pop_front()


func _add_trait(key: String, amount: float) -> void:
    traits[key] = clampf(float(traits.get(key, 0.0)) + amount, 0.0, 1.0)


## Phase 4: deterministic cultural heritage from settlement history.
## Derived purely from SettlementPersistence weight + WorldMemory event types. No RNG.
func inherit_culture(settlement_id: int) -> void:
    if not SettlementPersistence:
        return

    var weight = SettlementPersistence.calculate_historical_weight(settlement_id)

    if weight > 0.5:
        var events = WorldMemory.get_recent_events_for_settlement(settlement_id, 50, false) if WorldMemory else []
        var battles = 0
        var knowledge = 0

        for ev in events:
            var typ = ev.get("type", "")
            # Catch common HeelKawn deterministic event types
            if typ == "battle_won" or typ == "enemy_defeated" or typ == "enemy_death":
                battles += 1
            elif typ == "teaching" or typ == "technology_researched" or typ == "lesson_completed":
                knowledge += 1

        if battles > knowledge:
            cultural_heritage = "veteran"
        elif knowledge > 0:
            cultural_heritage = "scholar"
        else:
            cultural_heritage = "survivor"
    else:
        cultural_heritage = "wanderer"
