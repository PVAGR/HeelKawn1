class_name GossipPropagation
extends RefCounted

## Phase 4: Gossip & Social Information Propagation
## NPCs share information naturally, creating emergent stories

const MIN_TRUST_THRESHOLD: float = 0.3
const MAX_SPREAD_HOPS: int = 4
const ACCURACY_DECAY_PER_HOP: float = 0.1
const HOT_GOSSIP_MULTIPLIER: float = 3.0

var _pawn_id: int = -1
var _received_gossip: Array[Dictionary] = []
var _shared_gossip_ids: Array = []  # Prevent infinite loops


func _init(pawn_id: int) -> void:
	_pawn_id = pawn_id


## Receive new gossip from another NPC
func receive_gossip(
	content: String,
	source_pawn_id: int,
	original_source: int,
	accuracy: float,
	source_trust: float,
	spicy: bool = false
) -> bool:
	# Check if already known
	for g in _received_gossip:
		if g.content == content and g.original_source == original_source:
			return false  # Already known
	
	var gossip_id: int = _received_gossip.size()
	
	var entry: Dictionary = {
		"id": gossip_id,
		"content": content,
		"source_pawn_id": source_pawn_id,
		"original_source": original_source,
		"accuracy": accuracy,
		"tick_first_heard": _current_tick(),
		"spread_count": 0,
		"reliability_score": source_trust,
		"hot": spicy,
		"believed": true,
	}
	
	_received_gossip.append(entry)
	return true


## Get gossip to share with another NPC
func get_gossip_to_share(target_pawn_id: int, relationship_strength: float) -> Array[Dictionary]:
	if relationship_strength < MIN_TRUST_THRESHOLD:
		return []
	
	var to_share: Array = []
	var tick_now: int = _current_tick()
	
	for g in _received_gossip:
		if g.spread_count >= MAX_SPREAD_HOPS:
			continue
		if g.original_source == _pawn_id:
			continue  # Don't share own gossip
		
		# Hot gossip spreads faster
		var spread_chance: float = 0.3
		if g.hot:
			spread_chance *= HOT_GOSSIP_MULTIPLIER
		
		# Age factor - fresh gossip is more shareable
		var age: int = tick_now - g.tick_first_heard
		var age_factor: float = clampf(1.0 - (float(age) / 5000.0), 0.1, 1.0)
		
		if WorldRNG.chance_for(StringName("gossip:%d:%d" % [_pawn_id, target_pawn_id]), spread_chance * age_factor, 1.0):
			to_share.append(g)
	
	return to_share


## Get information accuracy after propagation
func get_information_accuracy(original_source: int) -> float:
	for g in _received_gossip:
		if g.original_source == original_source:
			var hops: int = g.spread_count
			return maxf(0.1, g.accuracy - (float(hops) * ACCURACY_DECAY_PER_HOP))
	return 0.0


## Tick-based gossip cleanup
func tick_decay() -> void:
	var tick_now: int = _current_tick()
	
	# Remove old, stale gossip
	_received_gossip = _received_gossip.filter(func(g): 
		var age: int = tick_now - g.tick_first_heard
		return age < 10000  # Keep gossip for ~10000 ticks
	)
	
	# Limit total gossip entries
	if _received_gossip.size() > 32:
		_received_gossip = _received_gossip.slice(_received_gossip.size() - 32)


## Record that I shared gossip
func mark_shared(gossip_id: int) -> void:
	for g in _received_gossip:
		if g.id == gossip_id:
			g.spread_count += 1
			break


## Get gossip for conversation
func get_conversation_topics(min_importance: float = 0.4) -> Array[String]:
	var topics: Array = []
	for g in _received_gossip:
		if g.reliability_score >= min_importance:
			topics.append(g.content)
	
	topics.shuffle()
	return topics.slice(0, mini(3, topics.size()))


## Create new gossip about discovery
func spread_discovery(
	discovery_content: String,
	source_pawn_id: int,
	importance: float = 0.7,
	spicy: bool = false
) -> void:
	receive_gossip(
		discovery_content,
		source_pawn_id,
		source_pawn_id,
		1.0,  # Verified truth from discoverer
		1.0,  # Trust in self
		spicy
	)


func _current_tick() -> int:
	return GameManager.tick_count if GameManager != null else 0


func get_state() -> Dictionary:
	return {
		"pawn_id": _pawn_id,
		"received_gossip": _received_gossip,
		"shared_gossip_ids": _shared_gossip_ids,
	}


func load_state(state: Dictionary) -> void:
	_received_gossip = state.get("received_gossip", [])
	_shared_gossip_ids = state.get("shared_gossip_ids", [])


func gossip_count() -> int:
	return _received_gossip.size()