extends Node
## GossipManager.gd — Central gossip propagation and reputation system (Phase 5)
##
## Manages gossip sharing between pawns during social proximity.
## Tracks reputation scores based on aggregated gossip.
##
## DESIGN PRINCIPLES:
## - Facts First: Gossip originates from WorldMemory events (via GrudgeManager)
## - Deterministic: Same seed + interactions = same gossip spread
## - Decays: Old gossip fades from memory
## - Behavioral: Reputation affects trust, cooperation, avoidance

const SCHEMA: int = 1

## Gossip propagation tuning
const GOSSIP_SHARE_CHANCE_BASE: float = 0.3
const GOSSIP_SHARE_CHANCE_HOT: float = 0.7  # "Hot" gossip spreads faster
const MAX_GOSSIP_SPREAD_HOPS: int = 4
const ACCURACY_DECAY_PER_HOP: float = 0.1

## Reputation tuning
const REPUTATION_NEUTRAL: float = 0.0
const REPUTATION_GOOD: float = 0.3
const REPUTATION_EXCELLENT: float = 0.6
const REPUTATION_BAD: float = -0.3
const REPUTATION_NOTORIOUS: float = -0.6

## Social proximity distance for gossip sharing (tiles)
const GOSSIP_PROXIMITY_DISTANCE: float = 5.0

## Gossip data structure:
## {
##   "id": int,
##   "subject_pawn_id": int,    # Who the gossip is about
##   "content": String,          # What is being said
##   "origin_pawn_id": int,      # Who originally said it
##   "type": String,             # Type (grudge type, discovery, etc.)
##   "importance": float,        # 0.0 to 1.0
##   "accuracy": float,          # 0.1 to 1.0 (decays per hop)
##   "spread_count": int,        # How many times shared
##   "tick_created": int,
##   "sentiment": float          # -1.0 to 1.0
## }

## Per-pawn gossip storage: pawn_id -> GossipPropagation instance
var _pawn_gossip: Dictionary = {}

# OPTIMIZATION: Cached PawnSpawner reference
@onready var _pawn_spawner: PawnSpawner = get_node_or_null("/root/PawnSpawner") as PawnSpawner

## Global gossip registry (for debugging/queries)
var _global_gossip: Array[Dictionary] = []
var _next_gossip_id: int = 1

## Reputation cache: pawn_id -> {reputation: float, tick: int}
var _reputation_cache: Dictionary = {}
var _cache_dirty: bool = false


func _ready() -> void:
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()


func _on_world_tick(tick_number: int) -> void:
	# OPTIMIZATION: Decay only every 100 ticks (was every 100, keeping this)
	if tick_number % 100 == 0:
		_tick_gossip_decay()
		_reputation_cache.clear()


## Get or create GossipPropagation for a pawn
func _get_gossip_for_pawn(pawn_id: int) -> GossipPropagation:
	if not _pawn_gossip.has(pawn_id):
		# Check if pawn still exists - use cached spawner
		var pawn_exists: bool = false
		if _pawn_spawner != null and _pawn_spawner.has_method("find_pawn_by_id"):
			var pawn: Node = _pawn_spawner.call("find_pawn_by_id", pawn_id)
			pawn_exists = pawn != null
		
		if pawn_exists:
			_pawn_gossip[pawn_id] = GossipPropagation.new(pawn_id)
		else:
			return null
	
	return _pawn_gossip[pawn_id]


## Record new gossip (called when grudge forms or event happens)
func record_gossip(
	subject_pawn_id: int,
	content: String,
	origin_pawn_id: int,
	gossip_type: String,
	importance: float,
	sentiment: float,
	tick: int
) -> void:
	var gossip: Dictionary = {
		"id": _next_gossip_id,
		"subject_pawn_id": subject_pawn_id,
		"content": content,
		"origin_pawn_id": origin_pawn_id,
		"type": gossip_type,
		"importance": importance,
		"accuracy": 1.0,  # Starts as verified truth
		"spread_count": 0,
		"tick_created": tick,
		"sentiment": sentiment,
	}
	
	_global_gossip.append(gossip)
	_next_gossip_id += 1
	_cache_dirty = true
	
	# Record to WorldMemory for audit trail
	_record_gossip_event(gossip)


## Share gossip between two pawns (called during social proximity)
func share_gossip_between(pawn_a_id: int, pawn_b_id: int, trust_strength: float) -> int:
	var gossip_a: GossipPropagation = _get_gossip_for_pawn(pawn_a_id)
	var gossip_b: GossipPropagation = _get_gossip_for_pawn(pawn_b_id)
	
	if gossip_a == null or gossip_b == null:
		return 0
	
	var shared_count: int = 0
	
	# A shares with B
	var gossip_to_share: Array[Dictionary] = gossip_a.get_gossip_to_share(pawn_b_id, trust_strength)
	for g in gossip_to_share:
		var accuracy_after_hop: float = maxf(0.1, g.accuracy - ACCURACY_DECAY_PER_HOP)
		gossip_b.receive_gossip(
			g.content,
			pawn_a_id,
			g.original_source,
			accuracy_after_hop,
			trust_strength,
			g.hot,
			g.importance,
			g.type
		)
		shared_count += 1
		gossip_a.mark_shared(g.id)
	
	# B shares with A
	gossip_to_share = gossip_b.get_gossip_to_share(pawn_a_id, trust_strength)
	for g in gossip_to_share:
		var accuracy_after_hop: float = maxf(0.1, g.accuracy - ACCURACY_DECAY_PER_HOP)
		gossip_a.receive_gossip(
			g.content,
			pawn_b_id,
			g.original_source,
			accuracy_after_hop,
			trust_strength,
			g.hot,
			g.importance,
			g.type
		)
		shared_count += 1
		gossip_b.mark_shared(g.id)
	
	return shared_count


## Get reputation score for a pawn (-1.0 to 1.0)
func get_reputation_for(pawn_id: int) -> float:
	# Check cache first
	if _reputation_cache.has(pawn_id):
		var cached: Dictionary = _reputation_cache[pawn_id]
		if GameManager.tick_count - cached.tick < 100:  # Cache for 100 ticks
			return cached.reputation
	
	# Calculate from gossip
	var gossip_prop: GossipPropagation = _get_gossip_for_pawn(pawn_id)
	if gossip_prop == null:
		return 0.0
	
	var reputation: float = gossip_prop.calculate_reputation_for(pawn_id)
	_reputation_cache[pawn_id] = {"reputation": reputation, "tick": GameManager.tick_count}
	
	return reputation


## Get reputation label for a pawn (human-readable)
func get_reputation_label(pawn_id: int) -> String:
	var rep: float = get_reputation_for(pawn_id)
	
	if rep >= REPUTATION_EXCELLENT:
		return "Exemplary"
	elif rep >= REPUTATION_GOOD:
		return "Good"
	elif rep >= REPUTATION_NEUTRAL - 0.1:
		return "Neutral"
	elif rep >= REPUTATION_BAD:
		return "Questionable"
	else:
		return "Notorious"


## Get pawns with bad reputation (for AI queries)
func get_notorious_pawns(min_intensity: float = REPUTATION_BAD) -> Array[int]:
	var result: Array[int] = []
	
	# Check all known pawns
	for pawn_id in _pawn_gossip.keys():
		var rep: float = get_reputation_for(pawn_id)
		if rep <= min_intensity:
			result.append(pawn_id)
	
	return result


## Apply gossip decay over time
func _tick_gossip_decay() -> void:
	for pawn_id in _pawn_gossip.keys():
		var gossip_prop: GossipPropagation = _pawn_gossip[pawn_id]
		if gossip_prop != null:
			gossip_prop.tick_decay()
	
	# Clean up gossip for pawns that no longer exist
	var valid_pawn_ids: Array[int] = _get_valid_pawn_ids()
	var to_remove: Array = []
	for pawn_id in _pawn_gossip.keys():
		if not valid_pawn_ids.has(pawn_id):
			to_remove.append(pawn_id)
	
	for pawn_id in to_remove:
		_pawn_gossip.erase(pawn_id)
	
	_cache_dirty = true


## Get list of valid pawn IDs from PawnSpawner
func _get_valid_pawn_ids() -> Array[int]:
	var result: Array[int] = []
	if _pawn_spawner == null:
		return result
	
	if _pawn_spawner.has_method("find_pawns"):
		var pawns: Array = _pawn_spawner.call("find_pawns")
		for p in pawns:
			if p != null and p.data != null:
				result.append(int(p.data.id))
	
	return result


## Record gossip event to WorldMemory
func _record_gossip_event(gossip: Dictionary) -> void:
	var WorldMem: Node = get_node_or_null("/root/WorldMemory")
	if WorldMem == null:
		return
	
	WorldMem.record_event({
		"type": "gossip_spread",
		"subject_pawn_id": gossip.subject_pawn_id,
		"origin_pawn_id": gossip.origin_pawn_id,
		"gossip_type": gossip.type,
		"importance": gossip.importance,
		"sentiment": gossip.sentiment,
		"tick": gossip.tick_created,
	})


## Save/Load support
func to_save_dict() -> Dictionary:
	var pawn_data: Dictionary = {}
	for pawn_id in _pawn_gossip.keys():
		var gossip_prop: GossipPropagation = _pawn_gossip[pawn_id]
		if gossip_prop != null:
			pawn_data[str(pawn_id)] = gossip_prop.get_state()
	
	return {
		"schema": SCHEMA,
		"pawn_gossip": pawn_data,
		"global_gossip": _global_gossip.duplicate(true),
		"next_id": _next_gossip_id,
	}


func from_save_dict(data: Dictionary) -> void:
	if data.get("schema", 0) != SCHEMA:
		push_warning("GossipManager: schema mismatch, migrating...")
	
	_global_gossip = data.get("global_gossip", []).duplicate(true)
	_next_gossip_id = int(data.get("next_id", 1))
	
	var pawn_data: Dictionary = data.get("pawn_gossip", {})
	_pawn_gossip.clear()
	for pawn_id_str in pawn_data.keys():
		var pawn_id: int = int(pawn_id_str)
		var state: Dictionary = pawn_data[pawn_id_str]
		var gossip_prop: GossipPropagation = GossipPropagation.new(pawn_id)
		gossip_prop.load_state(state)
		_pawn_gossip[pawn_id] = gossip_prop
	
	_cache_dirty = true


## Debug: get gossip count
func gossip_count() -> int:
	return _global_gossip.size()


## Debug: get active gossip (spread < MAX hops)
func get_active_gossip() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in _global_gossip:
		if g.spread_count < MAX_GOSSIP_SPREAD_HOPS:
			result.append(g)
	return result


## Debug: get notorious pawns with their reputation
func get_notorious_report() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pawn_id in get_notorious_pawns():
		result.append({
			"pawn_id": pawn_id,
			"reputation": get_reputation_for(pawn_id),
			"label": get_reputation_label(pawn_id),
		})
	return result


## Debug: clear all gossip (for testing)
func clear() -> void:
	_pawn_gossip.clear()
	_global_gossip.clear()
	_reputation_cache.clear()
	_next_gossip_id = 1
	_cache_dirty = true
