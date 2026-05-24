class_name GossipPropagation
extends RefCounted

## Phase 5: Gossip & Social Information Propagation
## NPCs share information naturally, creating emergent stories and reputation
## Extended to include grudge-based gossip and reputation calculation

const MIN_TRUST_THRESHOLD: float = 0.3
const MAX_SPREAD_HOPS: int = 4
const ACCURACY_DECAY_PER_HOP: float = 0.1
const HOT_GOSSIP_MULTIPLIER: float = 3.0

## Gossip importance levels (affects spread chance)
const IMPORTANCE_TRIVIAL: float = 0.2
const IMPORTANCE_NOTABLE: float = 0.5
const IMPORTANCE_SERIOUS: float = 0.7
const IMPORTANCE_SEISMIC: float = 0.9

## Gossip types that map to grudge types
const GOSSIP_GRUDGE_MAPPING: Dictionary = {
	"minor_harm": "heard %s wronged %s",
	"theft": "heard %s stole from %s",
	"betrayal": "heard %s betrayed %s",
	"major_harm": "heard %s attacked %s",
	"kin_harm": "heard %s hurt %s's family",
	"kin_death": "heard %s caused death of %s's kin",
	"abandonment": "heard %s abandoned %s",
	"neglect": "heard %s neglected %s",
}

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
	spicy: bool = false,
	importance: float = IMPORTANCE_NOTABLE,
	gossip_type: String = "general"
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
		"importance": importance,
		"type": gossip_type,
	}

	_received_gossip.append(entry)
	return true


## Generate gossip from a grudge (called when pawn learns of a grudge)
func generate_grudge_gossip(grudge_holder_id: int, grudge_target_id: int, grudge_type: String, intensity: float) -> void:
	if not GOSSIP_GRUDGE_MAPPING.has(grudge_type):
		return
	
	var template: String = GOSSIP_GRUDGE_MAPPING[grudge_type]
	var content: String = template % [str(grudge_target_id), str(grudge_holder_id)]
	var importance: float = _grudge_intensity_to_importance(intensity)
	var is_hot: bool = intensity >= 0.6
	
	# Receive as if we heard it from the grudge holder (original source)
	receive_gossip(
		content,
		grudge_holder_id,  # Source we heard it from
		grudge_holder_id,  # Original source
		1.0,  # Direct knowledge = high accuracy
		0.8,  # High trust in own knowledge
		is_hot,
		importance,
		grudge_type
	)


## Convert grudge intensity to gossip importance
func _grudge_intensity_to_importance(intensity: float) -> float:
	if intensity >= 0.85:
		return IMPORTANCE_SEISMIC
	elif intensity >= 0.6:
		return IMPORTANCE_SERIOUS
	elif intensity >= 0.3:
		return IMPORTANCE_NOTABLE
	return IMPORTANCE_TRIVIAL


## Get gossip to share with another NPC
func get_gossip_to_share(target_pawn_id: int, relationship_strength: float) -> Array[Dictionary]:
	if relationship_strength < MIN_TRUST_THRESHOLD:
		return []

	var to_share: Array[Dictionary] = []
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
		
		# Important gossip spreads more
		spread_chance *= g.importance

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
	var filtered: Array[Dictionary] = []
	for g in _received_gossip:
		var age: int = tick_now - g.tick_first_heard
		if age < 10000:
			filtered.append(g)
	_received_gossip = filtered

	# Limit total gossip entries
	if _received_gossip.size() > 32:
		var trimmed: Array[Dictionary] = []
		for i in range(_received_gossip.size() - 32, _received_gossip.size()):
			trimmed.append(_received_gossip[i])
		_received_gossip = trimmed


## Record that I shared gossip
func mark_shared(gossip_id: int) -> void:
	for g in _received_gossip:
		if g.id == gossip_id:
			g.spread_count += 1
			break


## Get gossip for conversation
func get_conversation_topics(min_importance: float = 0.4) -> Array[String]:
	var topics: Array[String] = []
	for g in _received_gossip:
		if g.reliability_score >= min_importance:
			topics.append(str(g.content))

	# Use deterministic ordering instead of shuffle
	topics.sort_custom(func(a: String, b: String) -> bool:
		return a < b
	)
	var count: int = mini(3, topics.size())
	var result: Array[String] = []
	for i in range(count):
		result.append(topics[i])
	return result


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
		spicy,
		importance,
		"discovery"
	)


## Get gossip about a specific target pawn (for reputation calculation)
func get_gossip_about(target_pawn_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in _received_gossip:
		if g.original_source == target_pawn_id or g.content.find(str(target_pawn_id)) >= 0:
			result.append(g)
	return result


## Calculate reputation score for a target pawn (-1.0 to 1.0)
## Positive = good reputation, negative = bad reputation
func calculate_reputation_for(target_pawn_id: int) -> float:
	var gossip_about: Array[Dictionary] = get_gossip_about(target_pawn_id)
	if gossip_about.is_empty():
		return 0.0  # No news = neutral reputation
	
	var total: float = 0.0
	var weight_sum: float = 0.0
	
	for g in gossip_about:
		# Weight by accuracy and recency
		var accuracy_weight: float = g.accuracy
		var age: int = _current_tick() - g.tick_first_heard
		var recency_weight: float = clampf(1.0 - (float(age) / 10000.0), 0.2, 1.0)
		var importance_weight: float = g.importance
		
		var weight: float = accuracy_weight * recency_weight * importance_weight
		weight_sum += weight
		
		# Determine if gossip is positive or negative
		var sentiment: float = _get_gossip_sentiment(g)
		total += sentiment * weight
	
	if weight_sum <= 0.0:
		return 0.0
	
	return clampf(total / weight_sum, -1.0, 1.0)


## Get sentiment of gossip (-1.0 negative, 1.0 positive, 0 neutral)
func _get_gossip_sentiment(g: Dictionary) -> float:
	var gossip_type: String = g.get("type", "general")
	
	# Grudge types are negative
	if gossip_type in GOSSIP_GRUDGE_MAPPING.keys():
		return -1.0
	
	# Discovery/achievement types are positive
	if gossip_type in ["discovery", "achievement", "teaching", "help"]:
		return 0.7
	
	# Default neutral
	return 0.0


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


## Return all stored gossip entries (used by GossipManager memorial sharing).
func get_stored_gossip() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in _received_gossip:
		if g is Dictionary:
			result.append(g as Dictionary)
	return result