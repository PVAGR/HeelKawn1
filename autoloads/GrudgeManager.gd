extends Node
## GrudgeManager.gd — Deterministic grudge tracking for Phase 5: Emergent Life
## 
## Grudges are persistent negative relationships born from recorded wrongs.
## They decay slowly, inherit across bloodlines, and affect pawn behavior.
##
## DESIGN PRINCIPLES:
## - Facts First: Grudges only form from WorldMemory events (never random)
## - Deterministic: Same seed + events = same grudges (replayable)
## - Inherited: Children remember wrongs done to their parents
## - Behavioral: Grudges affect avoidance, revenge, and trust decisions
##
## GRUDGE SOURCES:
## - Direct harm (combat, injury)
## - Theft (stolen items, raided stockpiles)
## - Betrayal (broken oaths, failed teachings)
## - Neglect (abandoned kin, ignored pleas)
## - Kin death (killed family member)

const SCHEMA: int = 1

## Grudge intensity thresholds
const INTENSITY_NEUTRAL: float = 0.0
const INTENSITY_GRUDGE: float = 0.3
const INTENSITY_HATRED: float = 0.6
const INTENSITY_BLOOD_FEUD: float = 0.85

## Decay tuning (per tick)
const DECAY_RATE_BASE: float = 0.0001  # ~10000 ticks to decay 1.0 intensity
const DECAY_RATE_FAST: float = 0.0003  # Minor slights decay faster
const DECAY_RATE_SLOW: float = 0.00005 # Blood feuds barely decay

## Inheritance tuning
const INHERITANCE_FACTOR: float = 0.5  # Children inherit 50% of parent grudge intensity
const INHERITANCE_DECAY_GENERATION: float = 0.3  # Each generation reduces inherited grudge by 30%

## Behavioral thresholds
const AVOIDANCE_DISTANCE_THRESHOLD: float = 0.4  # Avoid pawns with grudge > this
const REVENGE_THRESHOLD: float = 0.7  # Seek revenge when grudge > this
const TRUST_PENALTY_MAX: float = 0.9  # Max trust penalty from grudges

## Grudge type weights (initial intensity)
const GRUDGE_WEIGHT: Dictionary = {
	"minor_harm": 0.2,       # Bump, accidental hit
	"theft": 0.4,            # Stole my stuff
	"betrayal": 0.6,         # Broke promise/oath
	"major_harm": 0.7,       # Serious injury attempt
	"kin_harm": 0.8,         # Hurt my family member
	"kin_death": 1.0,        # Killed my family member
	"abandonment": 0.5,      # Left me behind
	"neglect": 0.3,          # Ignored my need
	"public_humiliation": 0.5, # Shamed me in front of others
}

## Grudge data structure:
## {
##   "id": int,
##   "holder_id": int,           # HeelKawnian who holds the grudge
##   "target_id": int,           # HeelKawnian the grudge is against
##   "origin_id": int,           # Original wrongdoer (may differ from target if inherited)
##   "type": String,             # Type of wrong
##   "intensity": float,         # 0.0 to 1.0
##   "tick_created": int,
##   "tick_last_updated": int,
##   "event_id": int,            # WorldMemory event that caused this
##   "generation": int,          # 0 = direct victim, 1+ = inherited
##   "source_event_type": String # Original event type (e.g., "pawn_harmed")
## }

var _grudges: Array[Dictionary] = []
var _next_grudge_id: int = 1
var _dirty: bool = false

## Index: holder_id -> [grudge indices]
var _grudges_by_holder: Dictionary = {}
## Index: target_id -> [grudge indices]
var _grudges_by_target: Dictionary = {}
## Index: (holder_id, target_id) -> combined intensity (cached for hot path)
var _combined_intensity_cache: Dictionary = {}
var _cache_dirty: bool = false

## Connected to TickManager
var _tick_connected: bool = false


func _ready() -> void:
	add_to_group("tickable")
	if TickManager != null:
		TickManager.mark_tickable_cache_dirty()
		_tick_connected = true


func _exit_tree() -> void:
	_tick_connected = false


func _on_world_tick(tick_number: int) -> void:
	# OPTIMIZATION: Decay only every 10 ticks to reduce per-tick overhead
	if tick_number % 10 == 0:
		_tick_grudge_decay(tick_number)
	
	# MEMORIAL SYSTEM: Check for grudge closure from memorial visits
	if tick_number % 100 == 0:
		_process_memorial_grudge_closure(tick_number)
		_rebuild_cache_if_needed()


## Record a new grudge from a WorldMemory event
## This is called by WorldMemory when relevant events are recorded
func record_grudge(
	holder_id: int,
	target_id: int,
	grudge_type: String,
	event_id: int,
	event_type: String,
	tick: int
) -> void:
	if holder_id < 0 or target_id < 0 or holder_id == target_id:
		return
	
	var base_intensity: float = GRUDGE_WEIGHT.get(grudge_type, 0.3)
	if base_intensity <= 0.0:
		return
	
	# Check for existing grudge and stack intensity
	var existing_idx: int = _find_grudge_index(holder_id, target_id, grudge_type)
	if existing_idx >= 0:
		var existing: Dictionary = _grudges[existing_idx]
		existing["intensity"] = clampf(existing["intensity"] + base_intensity * 0.3, 0.0, 1.0)
		existing["tick_last_updated"] = tick
		_mark_dirty()
		return
	
	# Create new grudge
	var grudge: Dictionary = {
		"id": _next_grudge_id,
		"holder_id": holder_id,
		"target_id": target_id,
		"origin_id": target_id,
		"type": grudge_type,
		"intensity": base_intensity,
		"tick_created": tick,
		"tick_last_updated": tick,
		"event_id": event_id,
		"generation": 0,
		"source_event_type": event_type,
	}
	
	_grudges.append(grudge)
	_index_grudge(_grudges.size() - 1, holder_id, target_id)
	_next_grudge_id += 1
	_mark_dirty()

	# Record to WorldMemory for audit trail
	_record_grudge_event(holder_id, target_id, grudge_type, base_intensity, tick)
	
	# Phase 5: Generate gossip from this grudge (spreads the news)
	_generate_gossip_from_grudge(holder_id, target_id, grudge_type, base_intensity, tick)


## Inherit grudges from parent to child
## Called when a pawn is born (via KinshipSystem integration)
func inherit_grudges(parent_id: int, child_id: int, tick: int) -> void:
	var parent_grudge_indices: Array = _grudges_by_holder.get(parent_id, [])
	
	for idx in parent_grudge_indices:
		if idx >= _grudges.size():
			continue
		
		var parent_grudge: Dictionary = _grudges[idx]
		var inherited_intensity: float = parent_grudge["intensity"] * INHERITANCE_FACTOR
		inherited_intensity *= pow(1.0 - INHERITANCE_DECAY_GENERATION, parent_grudge["generation"])
		
		if inherited_intensity < INTENSITY_GRUDGE:
			continue  # Too weak to inherit
		
		# Check if child already has this grudge
		var existing_idx: int = _find_grudge_index(child_id, parent_grudge["target_id"], parent_grudge["type"])
		if existing_idx >= 0:
			continue  # Already inherited/recorded
		
		# Create inherited grudge
		var grudge: Dictionary = {
			"id": _next_grudge_id,
			"holder_id": child_id,
			"target_id": parent_grudge["target_id"],
			"origin_id": parent_grudge["origin_id"],
			"type": parent_grudge["type"],
			"intensity": inherited_intensity,
			"tick_created": tick,
			"tick_last_updated": tick,
			"event_id": parent_grudge["event_id"],
			"generation": parent_grudge["generation"] + 1,
			"source_event_type": parent_grudge["source_event_type"],
		}
		
		_grudges.append(grudge)
		_index_grudge(_grudges.size() - 1, child_id, parent_grudge["target_id"])
		_next_grudge_id += 1
		
		# Record inheritance to WorldMemory
		_record_inheritance_event(child_id, parent_id, parent_grudge["target_id"], parent_grudge["type"], inherited_intensity, tick)
	
	_mark_dirty()


## Get combined grudge intensity from holder toward target
## This aggregates all grudges between two pawns for fast AI queries
func get_grudge_intensity(holder_id: int, target_id: int) -> float:
	if _cache_dirty:
		_rebuild_cache_if_needed()
	
	var key: String = "%d_%d" % [holder_id, target_id]
	return _combined_intensity_cache.get(key, 0.0)


## Check if holder has any grudge against target
func has_grudge(holder_id: int, target_id: int, min_intensity: float = INTENSITY_GRUDGE) -> bool:
	return get_grudge_intensity(holder_id, target_id) >= min_intensity


## Get all grudges held by a pawn
func get_grudges_held_by(pawn_id: int) -> Array[Dictionary]:
	var indices: Array = _grudges_by_holder.get(pawn_id, [])
	var result: Array[Dictionary] = []
	for idx in indices:
		if idx < _grudges.size():
			result.append(_grudges[idx])
	return result


## Get all grudges against a pawn
func get_grudges_against(pawn_id: int) -> Array[Dictionary]:
	var indices: Array = _grudges_by_target.get(pawn_id, [])
	var result: Array[Dictionary] = []
	for idx in indices:
		if idx < _grudges.size():
			result.append(_grudges[idx])
	return result


## Get pawns that this pawn should avoid (grudge > threshold)
func get_enemies_for(holder_id: int, min_intensity: float = AVOIDANCE_DISTANCE_THRESHOLD) -> Array[int]:
	var enemies: Array[int] = []
	var indices: Array = _grudges_by_holder.get(holder_id, [])
	
	for idx in indices:
		if idx < _grudges.size():
			var grudge: Dictionary = _grudges[idx]
			if grudge["intensity"] >= min_intensity:
				enemies.append(grudge["target_id"])
	
	return enemies


## Check if pawn should seek revenge against target
func should_seek_revenge(holder_id: int, target_id: int) -> bool:
	return get_grudge_intensity(holder_id, target_id) >= REVENGE_THRESHOLD


## Get trust penalty (0.0 to TRUST_PENALTY_MAX) based on grudges
func get_trust_penalty(holder_id: int, target_id: int) -> float:
	var intensity: float = get_grudge_intensity(holder_id, target_id)
	return intensity * TRUST_PENALTY_MAX


## Apply grudge decay over time
func _tick_grudge_decay(tick: int) -> void:
	var decayed: bool = false
	
	for i in range(_grudges.size() - 1, -1, -1):
		var grudge: Dictionary = _grudges[i]
		
		# Choose decay rate based on intensity
		var decay_rate: float = DECAY_RATE_BASE
		if grudge["intensity"] >= INTENSITY_BLOOD_FEUD:
			decay_rate = DECAY_RATE_SLOW
		elif grudge["intensity"] <= INTENSITY_GRUDGE:
			decay_rate = DECAY_RATE_FAST
		
		grudge["intensity"] = maxf(0.0, grudge["intensity"] - decay_rate)
		grudge["tick_last_updated"] = tick
		decayed = true
		
		# Remove if decayed below threshold
		if grudge["intensity"] < 0.05:
			_remove_grudge_at_index(i)
	
	if decayed:
		_mark_dirty()


## Remove a grudge at index (swap-pop for O(1))
func _remove_grudge_at_index(idx: int) -> void:
	if idx < 0 or idx >= _grudges.size():
		return
	
	var grudge: Dictionary = _grudges[idx]
	_unindex_grudge(idx, grudge["holder_id"], grudge["target_id"])
	
	# Swap with last and pop
	if idx < _grudges.size() - 1:
		_grudges[idx] = _grudges[_grudges.size() - 1]
		# Re-index the swapped grudge
		var swapped: Dictionary = _grudges[idx]
		_reindex_grudge(idx, swapped["holder_id"], swapped["target_id"])
	
	_grudges.pop_back()
	_mark_dirty()


## Find existing grudge index by holder, target, and type
func _find_grudge_index(holder_id: int, target_id: int, grudge_type: String) -> int:
	var indices: Array = _grudges_by_holder.get(holder_id, [])
	for idx in indices:
		if idx < _grudges.size():
			var grudge: Dictionary = _grudges[idx]
			if grudge["target_id"] == target_id and grudge["type"] == grudge_type:
				return idx
	return -1


## Index a grudge for fast lookup
func _index_grudge(idx: int, holder_id: int, target_id: int) -> void:
	if not _grudges_by_holder.has(holder_id):
		_grudges_by_holder[holder_id] = []
	_grudges_by_holder[holder_id].append(idx)
	
	if not _grudges_by_target.has(target_id):
		_grudges_by_target[target_id] = []
	_grudges_by_target[target_id].append(idx)
	
	_cache_dirty = true


## Un-index a grudge before removal
func _unindex_grudge(idx: int, holder_id: int, target_id: int) -> void:
	if _grudges_by_holder.has(holder_id):
		_grudges_by_holder[holder_id].erase(idx)
	
	if _grudges_by_target.has(target_id):
		_grudges_by_target[target_id].erase(idx)
	
	_cache_dirty = true


## Re-index a grudge after swap
func _reindex_grudge(idx: int, holder_id: int, target_id: int) -> void:
	# Remove old indices
	if _grudges_by_holder.has(holder_id):
		_grudges_by_holder[holder_id].erase(idx)
	if _grudges_by_target.has(target_id):
		_grudges_by_target[target_id].erase(idx)
	
	# Add new indices
	_index_grudge(idx, holder_id, target_id)


## Rebuild combined intensity cache
func _rebuild_cache_if_needed() -> void:
	if not _cache_dirty:
		return
	
	_combined_intensity_cache.clear()
	
	for grudge in _grudges:
		var key: String = "%d_%d" % [grudge["holder_id"], grudge["target_id"]]
		var current: float = _combined_intensity_cache.get(key, 0.0)
		_combined_intensity_cache[key] = current + grudge["intensity"]
	
	_cache_dirty = false


## Mark system dirty (needs save)
func _mark_dirty() -> void:
	_dirty = true
	_cache_dirty = true


## Record grudge creation to WorldMemory
func _record_grudge_event(holder_id: int, target_id: int, grudge_type: String, intensity: float, tick: int) -> void:
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "grudge_formed",
			"holder_id": holder_id,
			"target_id": target_id,
			"grudge_type": grudge_type,
			"intensity": intensity,
			"generation": 0,
			"tick": tick,
		})


## Record grudge inheritance to WorldMemory
func _record_inheritance_event(
	child_id: int, parent_id: int, target_id: int, grudge_type: String, intensity: float, tick: int
) -> void:
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "grudge_inherited",
			"child_id": child_id,
			"parent_id": parent_id,
			"target_id": target_id,
			"grudge_type": grudge_type,
			"intensity": intensity,
			"tick": tick,
		})


## Generate gossip from a grudge (Phase 5: Social propagation)
func _generate_gossip_from_grudge(
	holder_id: int, target_id: int, grudge_type: String, intensity: float, tick: int
) -> void:
	var GossipMgr: Node = get_node_or_null("/root/GossipManager")
	if GossipMgr == null or not GossipMgr.has_method("record_gossip"):
		return
	
	# Create gossip content
	var content: String = "%s holds grudge against %s for %s" % [
		str(holder_id), str(target_id), grudge_type
	]
	
	# Determine sentiment (negative for grudges)
	var sentiment: float = -1.0 * intensity
	
	# Importance based on intensity
	var importance: float = intensity
	
	GossipMgr.record_gossip(
		target_id,  # Subject (the one being talked about)
		content,
		holder_id,  # Origin (who started the gossip)
		grudge_type,
		importance,
		sentiment,
		tick
	)


## Save/Load support
func to_save_dict() -> Dictionary:
	return {
		"schema": SCHEMA,
		"grudges": _grudges.duplicate(true),
		"next_id": _next_grudge_id,
	}


func from_save_dict(data: Dictionary) -> void:
	if data.get("schema", 0) != SCHEMA:
		push_warning("GrudgeManager: schema mismatch, migrating...")
	
	_grudges = data.get("grudges", []).duplicate(true)
	_next_grudge_id = int(data.get("next_id", 1))
	
	# Rebuild indices
	_grudges_by_holder.clear()
	_grudges_by_target.clear()
	for i in range(_grudges.size()):
		_index_grudge(i, _grudges[i]["holder_id"], _grudges[i]["target_id"])
	
	_cache_dirty = true
	_dirty = false


## Debug: get grudge count
func grudge_count() -> int:
	return _grudges.size()


## Debug: get active blood feuds
func get_blood_feuds() -> Array[Dictionary]:
	var feuds: Array[Dictionary] = []
	for grudge in _grudges:
		if grudge["intensity"] >= INTENSITY_BLOOD_FEUD:
			feuds.append(grudge)
	return feuds


# ==================== MEMORIAL SYSTEM INTEGRATION ====================

## Process grudge closure from memorial visits
func _process_memorial_grudge_closure(tick: int) -> void:
	var ms: Node = get_node_or_null("/root/MemorialSystem")
	if ms == null:
		return
	
	if not ms.has_method("get_memorials"):
		return
	
	var memorials: Array[Dictionary] = ms.call("get_memorials")
	for memorial in memorials:
		_process_memorial_grudges(memorial, tick)


## Process grudges related to a specific memorial
func _process_memorial_grudges(memorial: Dictionary, tick: int) -> void:
	var associated_pawns: Array = memorial.get("associated_pawns", [])
	if associated_pawns.is_empty():
		return
	
	# Check if any pawns with grudges visited this memorial
	var memorial_tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
	
	# Find pawns near this memorial
	var ps: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null:
		return
	
	for pawn in ps.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		var pawn_id: int = int(pawn.data.id)
		var pawn_tile: Vector2i = pawn.data.tile_pos
		
		# Check if pawn is at memorial tile
		if pawn_tile == memorial_tile:
			# HeelKawnian is visiting memorial — check for grudge closure
			for associated_id in associated_pawns:
				_try_grudge_closure(pawn_id, int(associated_id), memorial, tick)


## Attempt grudge closure when pawn visits memorial of someone they had grudge against
func _try_grudge_closure(pawn_id: int, deceased_id: int, memorial: Dictionary, tick: int) -> void:
	# Check if pawn has grudge against deceased
	var grudges: Array[Dictionary] = get_grudges_held_by(pawn_id)
	
	for grudge in grudges:
		if grudge.get("target_id") == deceased_id:
			# Found grudge against deceased — chance for closure
			var intensity: float = grudge.get("intensity", 0.0)
			var memorial_type: String = memorial.get("memorial_type", "")
			
			# Closure chance based on memorial type and grudge intensity
			var closure_chance: float = 0.0
			
			if memorial_type in ["grave_marker", "memorial_plaque"]:
				closure_chance = 0.3  # 30% chance per visit
			elif memorial_type == "battle_monument":
				closure_chance = 0.2  # 20% for war dead
			elif memorial_type == "mass_grave":
				closure_chance = 0.15  # Harder to closure mass deaths
			
			# Blood feuds rarely closure
			if intensity >= INTENSITY_BLOOD_FEUD:
				closure_chance *= 0.1  # Only 10% of normal chance
			
			# Roll for closure (deterministic based on tick + pawn_id)
			var roll: float = abs(sin(float(tick) * 0.01 + float(pawn_id) * 0.1))
			if roll < closure_chance:
				# Grudge closure!
				_closure_grudge(grudge, tick)


## Close a grudge (reduce intensity significantly)
func _closure_grudge(grudge: Dictionary, tick: int) -> void:
	var grudge_idx: int = _grudges.find(grudge)
	if grudge_idx < 0:
		return
	
	# Reduce intensity by 50% (closure doesn't erase, but heals)
	grudge["intensity"] *= 0.5
	grudge["tick_last_updated"] = tick
	
	# Mark cache dirty for rebuild
	_cache_dirty = true
	
	# Optional: Log closure event
	if GameManager != null and GameManager.verbose_logs():
		print("[GrudgeManager] HeelKawnian %d found closure at memorial — grudge intensity reduced to %.2f" % [
			grudge.get("holder_id", -1), grudge.get("intensity", 0.0)
		])


## Debug: clear all grudges (for testing)
func clear() -> void:
	_grudges.clear()
	_grudges_by_holder.clear()
	_grudges_by_target.clear()
	_combined_intensity_cache.clear()
	_next_grudge_id = 1
	_dirty = true
	_cache_dirty = true
