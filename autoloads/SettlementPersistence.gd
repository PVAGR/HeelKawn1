extends Node
## Phase 4 (Identity & Meaning): deterministic historical-weight persistence.
## Weight derives ONLY from WorldMemory facts + tick count — no RNG, no frame delta.
## Historically significant settlements resist permanent abandonment longer.

var _weight_cache: Dictionary = {}
var _ruins_recorded: Dictionary = {}
const CACHE_TTL_TICKS = 600

func calculate_historical_weight(settlement_id: int) -> float:
	var current_tick = GameManager.tick_count if GameManager else 0
	if _weight_cache.has(settlement_id):
		var cache = _weight_cache[settlement_id]
		if current_tick - cache.tick < CACHE_TTL_TICKS:
			return cache.weight

	var weight: float = 0.0
	var settlement = SettlementMemory.get_settlement_at_region(settlement_id) if SettlementMemory else null

	if settlement is Dictionary:
		var founding_tick = settlement.get("founding_tick", -1)
		var age_score: float = 0.0
		if founding_tick > 0:
			var age_ticks = current_tick - founding_tick
			age_score = clamp(age_ticks / 10000.0, 0.0, 0.3)

		var formal_score = 0.2 if settlement.get("is_formal_settlement", false) else 0.0

		var events = WorldMemory.get_recent_events_for_settlement(settlement_id, 50, false) if WorldMemory else []
		var significant_events = 0
		for ev in events:
			var typ = ev.get("type", "")
			if typ == "building_constructed" or typ == "settlement_formalized" or typ == "battle_won":
				significant_events += 1
		var event_score = clamp(significant_events * 0.05, 0.0, 0.3)

		var deaths = settlement.get("total_pawn_deaths", 0)
		var death_score = clamp(deaths / 50.0, 0.0, 0.2)

		weight = clamp(age_score + formal_score + event_score + death_score, 0.0, 1.0)

	_weight_cache[settlement_id] = {"weight": weight, "tick": current_tick}
	return weight

func create_ruin(settlement_id: int) -> void:
	if _ruins_recorded.has(settlement_id):
		return
	_ruins_recorded[settlement_id] = true

	if WorldMemory:
		WorldMemory.record_event({
			"type": "settlement_became_ruin",
			"region": settlement_id,
			"center_region": settlement_id,
			"tick": GameManager.tick_count if GameManager else 0
		})

	if SacredMemory:
		SacredMemory.sync_permanent_ruins_from_settlements()
