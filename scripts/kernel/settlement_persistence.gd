extends Node

const _ZoneTags := preload("res://scripts/kernel/world_meaning_safe.gd")
const SettlementIdentity := preload("res://scripts/kernel/settlement_identity.gd")

# Autoload references
@onready var PersistenceSystem = get_node_or_null("/root/PersistenceSystem")
@onready var GameManager = get_node_or_null("/root/GameManager")

signal settlement_state_changed(settlement_id: String, old_state: String, new_state: String)

# === Tuning (Phase 4.1) — change one lever at a time, run to ~5k ticks, read [Persistence] logs ===
# Revivable/stabilizing: also WorldMeaning.STABILIZATION_* and update_carrying_capacity from persistence.
const ABANDON_DECAY_TICKS := 2000
const RUIN_PERMANENT_THRESHOLD := -3
const REVIVAL_IMPACT_MIN := 5
const REVIVAL_WINDOW_PERIOD := 400
const EVALUATE_EVERY_TICKS := 500


func _ready() -> void:
	if not Engine.is_editor_hint():
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	if Engine.is_editor_hint():
		return
	if int(tick) % EVALUATE_EVERY_TICKS != 0:
		return
	evaluate_abandoned_settlements()


func evaluate_abandoned_settlements() -> void:
	var zones: PackedStringArray = SettlementRegistry.get_abandoned_zone_ids()
	for i in range(zones.size()):
		_evaluate_single_zone(str(zones[i]))


func _evaluate_single_zone(zone_id: String) -> void:
	var settlement: Dictionary = SettlementRegistry.get_zone_data(zone_id)
	if settlement.is_empty() or str(settlement.get("state", "")) != "abandoned":
		return

	var current_tick: int = GameManager.tick_count
	var tick_delta: int = current_tick - int(settlement.get("abandoned_at_tick", 0))

	var stats: Dictionary = WorldMemory.get_zone_aggregate(zone_id)
	if stats.is_empty():
		return

	var tags: PackedStringArray = _ZoneTags.zone_tags(zone_id)
	var score: int = _compute_impact_score(stats)

	var old_state: String = str(settlement.get("state", ""))
	var new_state: String = old_state

	if tick_delta >= ABANDON_DECAY_TICKS and score < RUIN_PERMANENT_THRESHOLD:
		new_state = "ruin_permanent"
	elif (
			tick_delta >= ABANDON_DECAY_TICKS
			and score >= REVIVAL_IMPACT_MIN
			and tags.has("stabilizing_biome")
	):
		# Revival window → spawn identity & mark reoccupied
		if tick_delta % REVIVAL_WINDOW_PERIOD == 0 and SettlementRegistry.count_active_neighbors(zone_id, 2) > 0:
			settlement["reoccupied_tick"] = current_tick
			settlement["zone_id"] = zone_id
			var identity: Dictionary = SettlementIdentity.resolve_for(settlement)
			settlement["id"] = str(identity.get("id", zone_id))
			settlement["name"] = str(identity.get("name", "Unnamed"))
			var traits_v: Variant = identity.get("traits", PackedStringArray())
			if traits_v is PackedStringArray:
				var tarr: Array = []
				for t in traits_v as PackedStringArray:
					tarr.append(str(t))
				settlement["traits"] = tarr
			else:
				settlement["traits"] = []
			settlement["lineage_parent"] = str(identity.get("lineage_parent", zone_id))
			settlement["state"] = "active"
			var new_sid: String = str(identity.get("id", zone_id))
			settlement_state_changed.emit(new_sid, old_state, "active")
			SettlementRegistry.commit_zone_state(zone_id, settlement)
			return

	if new_state != old_state:
		settlement["state"] = new_state
		var sid: String = str(settlement.get("id", zone_id))
		settlement_state_changed.emit(sid, old_state, new_state)
		SettlementRegistry.commit_zone_state(zone_id, settlement)

		if new_state == "ruin_permanent":
			var flags: Array = settlement.get("persist_flags", []) as Array
			if not ("ruin" in flags):
				flags.append("ruin")
			settlement["persist_flags"] = flags
			SettlementRegistry.commit_zone_state(zone_id, settlement)
			
			# PersistenceSystem: create persistent ruin entity
			if PersistenceSystem != null:
				var center: Vector2i = SettlementRegistry.get_zone_center(zone_id)
				var entity_id: int = PersistenceSystem.create_persistent_entity(
					PersistenceSystem.EntityType.RUIN,
					center,
					str(settlement.get("name", "Unnamed Ruin")),
					0.7
				)
				# Record visitation (the settlement itself was "visited" by its residents)
				PersistenceSystem.record_visitation(entity_id, -1)


func _compute_impact_score(stats: Dictionary) -> int:
	var pos: int = int(stats.get("builds", 0)) + int(stats.get("monuments", 0)) + int(stats.get("trade_routes", 0))
	var neg: int = int(stats.get("death_clusters", 0)) + int(stats.get("biome_exhaustion", 0))
	return pos - (neg * 2)
