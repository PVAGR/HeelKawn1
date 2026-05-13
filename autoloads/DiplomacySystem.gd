extends Node
## DiplomacySystem — Agent-based diplomacy between settlements.
## Leaders meet, negotiate, and form treaties. All deterministic.
## Treaties: trade agreements, non-aggression pacts, alliances, vassalage.
## Diplomatic relations are tracked per settlement pair.
## Broken treaties cause reputation loss, grudges, and potential war.

enum TreatyType {
	TRADE,           # mutual trade access + bonus
	NON_AGGRESSION,  # no military action
	ALLIANCE,        # mutual defense + shared knowledge
	VASSALAGE,       # one settlement subordinates to another
	PEACE,           # end active conflict
}

const TREATY_NAMES: Dictionary = {
	TreatyType.TRADE: "Trade Agreement",
	TreatyType.NON_AGGRESSION: "Non-Aggression Pact",
	TreatyType.ALLIANCE: "Alliance",
	TreatyType.VASSALAGE: "Vassalage",
	TreatyType.PEACE: "Peace Treaty",
}

const TREATY_DURATION: Dictionary = {
	TreatyType.TRADE: 5000,
	TreatyType.NON_AGGRESSION: 10000,
	TreatyType.ALLIANCE: 15000,
	TreatyType.VASSALAGE: 20000,
	TreatyType.PEACE: 3000,
}

var treaties: Dictionary = {}
var relations: Dictionary = {}
var _next_treaty_id: int = 1

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func get_relation(settlement_a: int, settlement_b: int) -> int:
	var key: String = _pair_key(settlement_a, settlement_b)
	return relations.get(key, 0)

func modify_relation(settlement_a: int, settlement_b: int, delta: int) -> void {
	var key: String = _pair_key(settlement_a, settlement_b)
	relations[key] = clampi(relations.get(key, 0) + delta, -100, 100)
}

func propose_treaty(type: int, proposer: int, acceptor: int, terms: Dictionary = {}) -> int {
	var tid: int = _next_treaty_id
	_next_treaty_id += 1
	treaties[tid] = {
		"id": tid,
		"type": type,
		"name": TREATY_NAMES.get(type, "Treaty"),
		"proposer": proposer,
		"acceptor": acceptor,
		"tick_proposed": GameManager.tick_count if GameManager != null else 0,
		"duration": TREATY_DURATION.get(type, 5000),
		"is_active": false,
		"terms": terms,
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"treaty_proposed": true,
		"treaty_type": type,
		"proposer": proposer,
		"acceptor": acceptor,
	})
	return tid
}

func accept_treaty(treaty_id: int) -> bool {
	if not treaties.has(treaty_id):
		return false
	var t: Dictionary = treaties[treaty_id]
	t["is_active"] = true
	t["tick_accepted"] = GameManager.tick_count if GameManager != null else 0
	var proposer: int = int(t.get("proposer", -1))
	var acceptor: int = int(t.get("acceptor", -1))
	modify_relation(proposer, acceptor, 15)
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"treaty_accepted": true,
		"treaty_type": t.get("type"),
		"treaty_name": t.get("name"),
		"proposer": proposer,
		"acceptor": acceptor,
	})
	return true
}

func break_treaty(treaty_id: int, breaker: int) -> void {
	if not treaties.has(treaty_id):
		return
	var t: Dictionary = treaties[treaty_id]
	var other: int = int(t.get("acceptor", -1)) if breaker == int(t.get("proposer", -1)) else int(t.get("proposer", -1))
	modify_relation(breaker, other, -30)
	treaties.erase(treaty_id)
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"treaty_broken": true,
		"breacher": breaker,
	})
}

func get_active_treaties_for_settlement(settlement_id: int) -> Array {
	var result: Array = []
	for tid in treaties:
		var t: Dictionary = treaties[tid]
		if not bool(t.get("is_active", false)):
			continue
		if int(t.get("proposer", -1)) == settlement_id or int(t.get("acceptor", -1)) == settlement_id:
			result.append(t)
	return result
}

func _pair_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]

func _on_game_tick(tick: int) -> void:
	if tick % 1000 != 0:
		return
	_expire_treaties(tick)

func _expire_treaties(tick: int) -> void:
	var expired: Array = []
	for tid in treaties:
		var t: Dictionary = treaties[tid]
		if not bool(t.get("is_active", false)):
			continue
		var accepted: int = int(t.get("tick_accepted", 0))
		var duration: int = int(t.get("duration", 5000))
		if accepted > 0 and tick - accepted > duration:
			expired.append(tid)
	for tid in expired:
		treaties.erase(tid)
