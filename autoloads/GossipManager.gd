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

# OPTIMIZATION: Resolve PawnSpawner lazily
func _get_pawn_spawner() -> PawnSpawner:
	var _main: Node = get_tree().get_root().get_node_or_null("Main")
	if _main == null:
		return null
	return _main.get_node_or_null("WorldViewport/PawnSpawner") as PawnSpawner

## Global gossip registry (for debugging/queries)
var _global_gossip: Array[Dictionary] = []
var _next_gossip_id: int = 1

## Reputation cache: pawn_id -> {reputation: float, tick: int}
var _reputation_cache: Dictionary = {}
var _cache_dirty: bool = false

## Cross-settlement gossip: track diaspora migrants until they arrive
## pawn_id -> {origin_settlement_id: int, target_region: int, exile_tick: int}
var _pending_migrants: Dictionary = {}


func _ready() -> void:
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
	
	# Subscribe to diaspora exile events for cross-settlement gossip propagation
	if EventBus != null:
		EventBus.subscribe("diaspora_exile", self, "_on_diaspora_exile")


func _on_world_tick(tick_number: int) -> void:
	# OPTIMIZATION: Decay only every 100 ticks (was every 100, keeping this)
	if tick_number % 100 == 0:
		_tick_gossip_decay()
		_reputation_cache.clear()
	
	# MEMORIAL SYSTEM: Gossip spreads faster at commemoration gatherings
	if tick_number % 1000 == 0:  # Check every 1000 ticks for gatherings
		_process_memorial_gossip_spread(tick_number)
	
	# CROSS-SETTLEMENT GOSSIP: Check if diaspora migrants have arrived
	if tick_number % 50 == 0 and not _pending_migrants.is_empty():
		_check_arrived_migrants(tick_number)


## Get or create GossipPropagation for a pawn
func _get_gossip_for_pawn(pawn_id: int) -> GossipPropagation:
	if not _pawn_gossip.has(pawn_id):
		# Check if pawn still exists - resolve spawner lazily
		var pawn_exists: bool = false
		var pawn_spawner: PawnSpawner = _get_pawn_spawner()
		if pawn_spawner != null and pawn_spawner.has_method("find_pawn_by_id"):
			var pawn: Node = pawn_spawner.call("find_pawn_by_id", pawn_id)
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
	var sp: PawnSpawner = _get_pawn_spawner()
	if sp == null:
		return result
	
	if sp.has_method("find_pawns"):
		var pawns: Array = sp.call("find_pawns")
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


## Get recent gossip about a specific pawn (by subject_pawn_id).
## Returns up to `max_count` gossip dictionaries, newest first.
func get_gossip_about(pawn_id: int, max_count: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in _global_gossip:
		if g.get("subject_pawn_id") == pawn_id:
			result.append(g)
			if result.size() >= max_count:
				break
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


# ==================== MEMORIAL SYSTEM INTEGRATION ====================

## Gossip spreads faster at commemoration gatherings (memorial sites)
func _process_memorial_gossip_spread(tick: int) -> void:
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms == null:
		return
	
	if not ms.has_method("get_memorials"):
		return
	
	var memorials: Array[Dictionary] = ms.call("get_memorials")
	for memorial in memorials:
		# Check if any gathering is happening at this memorial
		# (Simplified: assume gatherings happen when 3+ pawns at memorial tile)
		var memorial_tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
		
		var ps: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
		if ps == null:
			continue
		
		# Count pawns at memorial
		var pawns_at_memorial: Array[int] = []
		for pawn in ps.pawns:
			if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
				continue
			
			if pawn.data.tile_pos == memorial_tile:
				pawns_at_memorial.append(int(pawn.data.id))
		
		# If 3+ pawns at memorial, gossip spreads faster
		if pawns_at_memorial.size() >= 3:
			_spread_gossip_at_memorial(pawns_at_memorial, memorial, tick)


## Spread gossip among pawns at memorial gathering
func _spread_gossip_at_memorial(pawn_ids: Array[int], memorial: Dictionary, tick: int) -> void:
	# Determine memorial settlement
	var memorial_tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
	var memorial_rk: int = WorldMemory._region_key(memorial_tile.x, memorial_tile.y)
	var memorial_settlement_id: int = SettlementMemory.get_center_region_for_region(memorial_rk)
	
	# Build settlement lookup for attendees
	var pawn_settlements: Dictionary = {}
	for pid in pawn_ids:
		var pawn: Node = _find_pawn_by_id(pid)
		pawn_settlements[pid] = _get_pawn_settlement_id(pawn)
	
	for i in range(pawn_ids.size()):
		for j in range(i + 1, pawn_ids.size()):
			var pawn_a: int = pawn_ids[i]
			var pawn_b: int = pawn_ids[j]
			
			# Check if either pawn is a visitor from another settlement
			var has_visitor: bool = false
			if memorial_settlement_id >= 0:
				var a_settlement: int = pawn_settlements.get(pawn_a, -1)
				var b_settlement: int = pawn_settlements.get(pawn_b, -1)
				if a_settlement >= 0 and a_settlement != memorial_settlement_id:
					has_visitor = true
				if b_settlement >= 0 and b_settlement != memorial_settlement_id:
					has_visitor = true
			
			# Apply 2x multiplier when visitors from other settlements are present
			var share_chance: float = GOSSIP_SHARE_CHANCE_BASE
			if has_visitor:
				share_chance *= 2.0
			
			# Share gossip between these pawns
			if WorldRNG != null and WorldRNG.chance_for(StringName("gossip_memorial:%d:%d:%d" % [pawn_a, pawn_b, tick]), share_chance, 1.0):
				_share_gossip_between(pawn_a, pawn_b, tick)


## Share gossip between two pawns
func _share_gossip_between(pawn_a: int, pawn_b: int, tick: int) -> void:
	var gossip_a = _get_gossip_for_pawn(pawn_a)
	var gossip_b = _get_gossip_for_pawn(pawn_b)

	if gossip_a == null or gossip_b == null:
		return

	# Guard: ensure get_stored_gossip exists (API compatibility)
	if not gossip_a.has_method("get_stored_gossip") or not gossip_b.has_method("get_stored_gossip"):
		return

	# Share a piece of gossip from A to B
	var a_gossip: Array[Dictionary] = gossip_a.get_stored_gossip()
	if a_gossip.size() > 0:
		var idx: int = abs(WorldRNG.index_for(StringName("gossip_share_a:%d:%d" % [pawn_a, pawn_b]), a_gossip.size())) if WorldRNG != null else 0
		var chosen: Dictionary = a_gossip[idx]
		gossip_b.receive_gossip(
			chosen.get("content", ""),
			pawn_a,
			chosen.get("original_source", pawn_a),
			chosen.get("accuracy", 0.8),
			1.0,  # trust_strength
			chosen.get("hot", false),
			chosen.get("importance", 0.5),
			chosen.get("type", "general")
		)

	# Share from B to A
	var b_gossip: Array[Dictionary] = gossip_b.get_stored_gossip()
	if b_gossip.size() > 0:
		var idx: int = abs(WorldRNG.index_for(StringName("gossip_share_b:%d:%d" % [pawn_a, pawn_b]), b_gossip.size())) if WorldRNG != null else 0
		var chosen: Dictionary = b_gossip[idx]
		gossip_a.receive_gossip(
			chosen.get("content", ""),
			pawn_b,
			chosen.get("original_source", pawn_b),
			chosen.get("accuracy", 0.8),
			1.0,  # trust_strength
			chosen.get("hot", false),
			chosen.get("importance", 0.5),
			chosen.get("type", "general")
		)


## Debug: clear all gossip (for testing)
func clear() -> void:
	_pawn_gossip.clear()
	_global_gossip.clear()
	_reputation_cache.clear()
	_next_gossip_id = 1
	_cache_dirty = true
	_pending_migrants.clear()


# ==================== CROSS-SETTLEMENT GOSSIP PROPAGATION ====================

## EventBus callback: diaspora exile started — track migrating pawns
func _on_diaspora_exile(payload: Dictionary) -> void:
	var exile_ids: Array = payload.get("exile_pawn_ids", [])
	var origin_settlement: int = payload.get("parent_settlement", -1)
	var to_region: int = payload.get("to_region", -1)
	var tick: int = payload.get("tick", GameManager.tick_count)
	
	for pawn_id in exile_ids:
		_pending_migrants[int(pawn_id)] = {
			"origin_settlement_id": origin_settlement,
			"target_region": to_region,
			"exile_tick": tick,
		}


## Check if tracked migrants have arrived at their destination settlement
func _check_arrived_migrants(tick: int) -> void:
	var to_remove: Array[int] = []
	
	for pawn_id in _pending_migrants.keys():
		var migrant_info: Dictionary = _pending_migrants[pawn_id]
		var origin_id: int = migrant_info["origin_settlement_id"]
		
		var pawn: Node = _find_pawn_by_id(pawn_id)
		if pawn == null or pawn.data == null:
			to_remove.append(pawn_id)
			continue
		
		var tile: Vector2i = pawn.data.tile_pos
		var rk: int = WorldMemory._region_key(tile.x, tile.y)
		
		# Arrived if they reached the target region or are in a different settlement
		var arrived: bool = false
		var dest_settlement_id: int = -1
		
		if rk == migrant_info["target_region"]:
			arrived = true
			dest_settlement_id = migrant_info["target_region"]
		else:
			var current_settlement_id: int = SettlementMemory.get_center_region_for_region(rk)
			if current_settlement_id >= 0 and current_settlement_id != origin_id:
				arrived = true
				dest_settlement_id = current_settlement_id
		
		if not arrived:
			continue
		
		# Propagate gossip from migrant to destination settlement
		var gossip_count: int = _propagate_migrant_gossip(pawn_id, origin_id, dest_settlement_id, tick)
		
		# Record cross-settlement gossip spread event
		_record_cross_settlement_gossip_spread(origin_id, dest_settlement_id, pawn_id, gossip_count, tick)
		
		to_remove.append(pawn_id)
	
	for pid in to_remove:
		_pending_migrants.erase(pid)


## Propagate a migrant's gossip to pawns in the destination settlement
func _propagate_migrant_gossip(pawn_id: int, source_settlement_id: int, dest_settlement_id: int, tick: int) -> int:
	var migrant_gossip: GossipPropagation = _get_gossip_for_pawn(pawn_id)
	if migrant_gossip == null:
		return 0
	
	var gossip_items: Array[Dictionary] = migrant_gossip.get_stored_gossip()
	if gossip_items.is_empty():
		return 0
	
	# Find pawns in destination settlement
	var dest_pawns: Array[int] = _get_pawns_in_settlement(dest_settlement_id)
	if dest_pawns.is_empty():
		return 0
	
	var total_shared: int = 0
	
	for dest_pawn_id in dest_pawns:
		if dest_pawn_id == pawn_id:
			continue
		
		var dest_gossip: GossipPropagation = _get_gossip_for_pawn(dest_pawn_id)
		if dest_gossip == null:
			continue
		
		for g in gossip_items:
			# Apply cross-settlement accuracy decay (+1 extra hop for crossing settlement boundary)
			var base_accuracy: float = g.get("accuracy", 0.8)
			var accuracy_after_hop: float = maxf(0.1, base_accuracy - ACCURACY_DECAY_PER_HOP * 2.0)
			
			dest_gossip.receive_gossip(
				g.get("content", ""),
				pawn_id,
				g.get("original_source", pawn_id),
				accuracy_after_hop,
				0.5,  # neutral trust for outsider
				g.get("hot", false),
				g.get("importance", 0.5),
				g.get("type", "general")
			)
			total_shared += 1
		
		_cache_dirty = true
	
	return total_shared


## Get all living pawn IDs currently in a settlement (by region membership)
func _get_pawns_in_settlement(settlement_id: int) -> Array[int]:
	var result: Array[int] = []
	var sp: PawnSpawner = _get_pawn_spawner()
	if sp == null:
		return result
	
	var pawns: Array = sp.call("find_pawns")
	for p in pawns:
		if p == null or p.data == null:
			continue
		
		var tile: Vector2i = p.data.tile_pos
		var rk: int = WorldMemory._region_key(tile.x, tile.y)
		var pawn_settlement: int = SettlementMemory.get_center_region_for_region(rk)
		
		if pawn_settlement == settlement_id:
			result.append(int(p.data.id))
	
	return result


## Find a pawn node by ID
func _find_pawn_by_id(pawn_id: int) -> Node:
	var sp: PawnSpawner = _get_pawn_spawner()
	if sp == null or not sp.has_method("find_pawn_by_id"):
		return null
	return sp.call("find_pawn_by_id", pawn_id)


## Get the settlement ID a pawn currently belongs to (by tile region)
func _get_pawn_settlement_id(pawn: Node) -> int:
	if pawn == null or pawn.data == null:
		return -1
	var tile: Vector2i = pawn.data.tile_pos
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	return SettlementMemory.get_center_region_for_region(rk)


## Record cross-settlement gossip spread to WorldMemory
func _record_cross_settlement_gossip_spread(
	source_settlement_id: int,
	dest_settlement_id: int,
	pawn_id: int,
	gossip_count: int,
	tick: int
) -> void:
	var WorldMem: Node = get_node_or_null("/root/WorldMemory")
	if WorldMem == null:
		return
	
	WorldMem.record_event({
		"type": "gossip_spread",
		"source_settlement_id": source_settlement_id,
		"dest_settlement_id": dest_settlement_id,
		"pawn_id": pawn_id,
		"gossip_count": gossip_count,
		"tick": tick,
	})
