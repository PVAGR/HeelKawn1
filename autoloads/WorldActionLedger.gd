extends Node
## WorldActionLedger - Actions persist FOREVER
##
## EVE Online medieval persistence:
## - Every player action recorded permanently
## - Every HeelKawnian action recorded permanently
## - Actions readable by future players
## - History chronicle system
## - Ruins remain, battles leave scars
## - Generational transfer (kids inherit YOUR world)
##
## This is what makes HeelKawn a PERSISTENT SIMULATION UNIVERSE.
## Your actions MATTER. They are RECORDED. They are REMEMBERED. FOREVER.

# Action ledger entry
## {
##   "action_id": int,
##   "actor_id": int,  # pawn_id (player or HeelKawnian)
##   "actor_type": String,  # "player" or "heelkawnian"
##   "actor_name": String,
##   "action_type": String,  # "gathered", "built", "fought", "traded", etc.
##   "action_description": String,
##   "tile": Vector2i,
##   "tick": int,
##   "year": int,
##   "day": int,
##   "impact": int,  # 1-10 significance
##   "category": String,  # "survival", "construction", "combat", "social", "discovery"
##   "associated_entities": Array[int],  # Other pawns/entities involved
##   "permanent": bool,  # If true, never deleted
##   "read_count": int,  # How many times read by future players
##   "tags": Array[String]  # Searchable tags
## }
var action_ledger: Array[Dictionary] = []
var _next_action_id: int = 1

# Historical chronicles (aggregated from ledger)
## {
##   "chronicle_id": int,
##   "title": String,
##   "author_id": int,  # Who wrote it
##   "tick_written": int,
##   "covers_period": {"start": int, "end": int},
##   "content": String,
##   "region": Vector2i,
##   "era": String,
##   "significance": int  # 1-10
## }
var historical_chronicles: Array[Dictionary] = []
var _next_chronicle_id: int = 1

# World scars (permanent marks from actions)
## {
##   "scar_id": int,
##   "type": String,  # "battle", "disaster", "construction", "mining"
##   "tile": Vector2i,
##   "created_tick": int,
##   "created_by": int,
##   "description": String,
##   "permanent": bool,  # If true, never fades
##   "fade_tick": int  # If not permanent, when it fades
## }
var world_scars: Array[Dictionary] = []
var _next_scar_id: int = 1

# Generational transfers
## {
##   "transfer_id": int,
##   "from_pawn_id": int,  # Parent
##   "to_pawn_id": int,  # Child/heir
##   "tick": int,
##   "items_transferred": Array[Dictionary],
##   "knowledge_transferred": Array[String],
##   "debts_transferred": Array[Dictionary],
##   "legacy_notes": String
## }
var generational_transfers: Array[Dictionary] = []
var _next_transfer_id: int = 1

# Configuration
const MAX_LEDGER_ENTRIES: int = 100000  # Keep last 100k actions
const ACTIONS_PER_CHRONICLE: int = 100  # Create chronicle every 100 actions
const SCAR_FADE_TIME: int = 50000  # Non-permanent scars fade after 50k ticks

# References
@onready var _world_memory: Node = null
@onready var _pawn_spawner: Node = null
@onready var _world: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_world = get_node_or_null("/root/Main/World")


func _on_game_tick(tick: int) -> void:
	# Fade non-permanent scars
	if tick % 1000 == 0:
		_fade_scars(tick)
	
	# Auto-generate chronicles
	if tick % ACTIONS_PER_CHRONICLE == 0:
		_generate_chronicle(tick)


# ==================== ACTION RECORDING ====================

## Record a player action
func record_player_action(player_pawn_id: int, action_type: String, 
 description: String, tile: Vector2i, impact: int = 5, 
 category: String = "general", associated_entities: Array[int] = [],
 tags: Array[String] = []) -> int:
	
	var actor_name: String = _get_pawn_name(player_pawn_id)
	
	return _record_action({
		"actor_id": player_pawn_id,
		"actor_type": "player",
		"actor_name": actor_name,
		"action_type": action_type,
		"action_description": description,
		"tile": tile,
		"tick": GameManager.tick_count,
		"year": GameManager.tick_count / 360,
		"day": (GameManager.tick_count % 360),
		"impact": clampi(impact, 1, 10),
		"category": category,
		"associated_entities": associated_entities,
		"permanent": impact >= 8,  # High impact actions are permanent
		"read_count": 0,
		"tags": tags
	})


## Record a HeelKawnian action
func record_heelkawnian_action(heelkawnian_id: int, action_type: String,
 description: String, tile: Vector2i, impact: int = 3,
 category: String = "general", associated_entities: Array[int] = [],
 tags: Array[String] = []) -> int:
	
	var actor_name: String = _get_pawn_name(heelkawnian_id)
	
	return _record_action({
		"actor_id": heelkawnian_id,
		"actor_type": "heelkawnian",
		"actor_name": actor_name,
		"action_type": action_type,
		"action_description": description,
		"tile": tile,
		"tick": GameManager.tick_count,
		"year": GameManager.tick_count / 360,
		"day": (GameManager.tick_count % 360),
		"impact": clampi(impact, 1, 10),
		"category": category,
		"associated_entities": associated_entities,
		"permanent": impact >= 9,  # Only highest impact HeelKawnian actions permanent
		"read_count": 0,
		"tags": tags
	})


func _record_action(action_data: Dictionary) -> int:
	action_data.action_id = _next_action_id
	action_ledger.append(action_data)
	
	_next_action_id += 1
	
	# Trim ledger if too large
	while action_ledger.size() > MAX_LEDGER_ENTRIES:
		action_ledger.pop_front()
	
	# Record to WorldMemory (for save/load persistence)
	if _world_memory != null:
		_world_memory.record_event({
			"type": "action_recorded",
			"action_id": action_data.action_id,
			"actor_name": action_data.actor_name,
			"action_type": action_data.action_type,
			"permanent": action_data.permanent,
			"tick": action_data.tick
		})
	
	return action_data.action_id


# ==================== WORLD SCARS ====================

## Create a permanent scar on the world
func create_world_scar(type: String, tile: Vector2i, created_by: int,
 description: String, permanent: bool = true) -> int:
	
	var scar: Dictionary = {
		"scar_id": _next_scar_id,
		"type": type,
		"tile": tile,
		"created_tick": GameManager.tick_count,
		"created_by": created_by,
		"description": description,
		"permanent": permanent,
		"fade_tick": -1 if permanent else GameManager.tick_count + SCAR_FADE_TIME
	}
	
	world_scars.append(scar)
	_next_scar_id += 1
	
	# Record scar creation
	if _world_memory != null:
		_world_memory.record_event({
			"type": "world_scar_created",
			"scar_id": scar.scar_id,
			"scar_type": type,
			"tile": {"x": tile.x, "y": tile.y},
			"permanent": permanent,
			"tick": GameManager.tick_count
		})
	
	return scar.scar_id


func _fade_scars(tick: int) -> void:
	for i in range(world_scars.size() - 1, -1, -1):
		var scar: Dictionary = world_scars[i]
		
		if not scar.permanent and scar.fade_tick > 0 and tick >= scar.fade_tick:
			# Scar fades
			world_scars.remove_at(i)
			
			if _world_memory != null:
				_world_memory.record_event({
					"type": "world_scar_faded",
					"scar_id": scar.scar_id,
					"tick": tick
				})


## Get scars at a tile
func get_scars_at(tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for scar in world_scars:
		if scar.tile == tile:
			result.append(scar.duplicate())
	
	return result


## Get scars in radius
func get_scars_in_radius(center: Vector2i, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for scar in world_scars:
		if scar.tile.distance_to(center) <= radius:
			result.append(scar.duplicate())
	
	return result


# ==================== CHRONICLE SYSTEM ====================

func _generate_chronicle(tick: int) -> void:
	# Get recent actions
	var start_idx: int = max(0, action_ledger.size() - ACTIONS_PER_CHRONICLE)
	var recent_actions: Array[Dictionary] = action_ledger.slice(start_idx)
	
	if recent_actions.size() < 10:
		return  # Not enough actions for meaningful chronicle
	
	# Group by category
	var by_category: Dictionary = {}
	for action in recent_actions:
		var cat: String = action.get("category", "general")
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(action)
	
	# Find dominant category
	var dominant_category: String = "general"
	var max_count: int = 0
	for cat in by_category:
		if by_category[cat].size() > max_count:
			max_count = by_category[cat].size()
			dominant_category = cat
	
	# Create chronicle
	var chronicle: Dictionary = {
		"chronicle_id": _next_chronicle_id,
		"title": _generate_chronicle_title(dominant_category, recent_actions),
		"author_id": 0,  # Auto-generated by system
		"tick_written": tick,
		"covers_period": {
			"start": recent_actions[0].tick if recent_actions.size() > 0 else tick,
			"end": tick
		},
		"content": _generate_chronicle_content(recent_actions, dominant_category),
		"region": _get_central_tile(recent_actions),
		"era": _get_era_name(tick),
		"significance": _calculate_chronicle_significance(recent_actions)
	}
	
	historical_chronicles.append(chronicle)
	_next_chronicle_id += 1
	
	# Record chronicle
	if _world_memory != null:
		_world_memory.record_event({
			"type": "chronicle_written",
			"chronicle_id": chronicle.chronicle_id,
			"title": chronicle.title,
			"era": chronicle.era,
			"tick": tick
		})


func _generate_chronicle_title(category: String, actions: Array[Dictionary]) -> String:
	match category:
		"survival":
			return "Age of Survival"
		"construction":
			return "Age of Building"
		"combat":
			return "Age of Conflict"
		"social":
			return "Age of Society"
		"discovery":
			return "Age of Discovery"
		_:
			return "Chronicle of Year " + str(actions[0].year if actions.size() > 0 else 0)


func _generate_chronicle_content(actions: Array[Dictionary], category: String) -> String:
	var content: String = "In the Year %d, " % actions[0].year if actions.size() > 0 else "In ancient times, "
	
	match category:
		"survival":
			content += "the people struggled to survive. "
		"construction":
			content += "great works were built. "
		"combat":
			content += "conflict shaped the land. "
		"social":
			content += "society grew and changed. "
		"discovery":
			content += "new horizons were found. "
		_:
			content += "events unfolded. "
	
	# Add notable actions
	var notable: Array[Dictionary] = actions.filter(func(a): return a.impact >= 7)
	if notable.size() > 0:
		content += "Notable: "
		for action in notable:
			content += "%s %s; " % [action.actor_name, action.action_description]
	
	return content


func _get_central_tile(actions: Array[Dictionary]) -> Vector2i:
	if actions.size() == 0:
		return Vector2i.ZERO
	
	var sum_x: int = 0
	var sum_y: int = 0
	for action in actions:
		sum_x += action.tile.x
		sum_y += action.tile.y
	
	return Vector2i(sum_x / actions.size(), sum_y / actions.size())


func _get_era_name(tick: int) -> String:
	var year: int = tick / 360
	
	if year < 1:
		return "Founding Era"
	elif year < 10:
		return "Early Era"
	elif year < 50:
		return "Growth Era"
	elif year < 100:
		return "Mature Era"
	else:
		return "Legendary Era"


func _calculate_chronicle_significance(actions: Array[Dictionary]) -> int:
	var total_impact: int = 0
	for action in actions:
		total_impact += action.impact
	
	var avg_impact: float = float(total_impact) / float(actions.size()) if actions.size() > 0 else 0
	
	return clampi(int(avg_impact), 1, 10)


# ==================== GENERATIONAL TRANSFER ====================

## Transfer legacy from parent to child
func transfer_generational_legacy(from_pawn_id: int, to_pawn_id: int,
 items: Array[Dictionary] = [], knowledge: Array[String] = [],
 debts: Array[Dictionary] = [], legacy_notes: String = "") -> int:
	
	var transfer: Dictionary = {
		"transfer_id": _next_transfer_id,
		"from_pawn_id": from_pawn_id,
		"to_pawn_id": to_pawn_id,
		"tick": GameManager.tick_count,
		"items_transferred": items,
		"knowledge_transferred": knowledge,
		"debts_transferred": debts,
		"legacy_notes": legacy_notes
	}
	
	generational_transfers.append(transfer)
	_next_transfer_id += 1
	
	# Record transfer
	if _world_memory != null:
		_world_memory.record_event({
			"type": "generational_transfer",
			"transfer_id": transfer.transfer_id,
			"from": from_pawn_id,
			"to": to_pawn_id,
			"items": items.size(),
			"knowledge": knowledge.size(),
			"tick": GameManager.tick_count
		})
	
	return transfer.transfer_id


## Get inherited knowledge for a pawn
func get_inherited_knowledge(pawn_id: int) -> Array[String]:
	var knowledge: Array[String] = []
	
	for transfer in generational_transfers:
		if transfer.to_pawn_id == pawn_id:
			knowledge.append_array(transfer.knowledge_transferred)
	
	return knowledge


## Get inherited items for a pawn
func get_inherited_items(pawn_id: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	
	for transfer in generational_transfers:
		if transfer.to_pawn_id == pawn_id:
			items.append_array(transfer.items_transferred)
	
	return items


# ==================== QUERY SYSTEM ====================

## Get actions by actor
func get_actions_by_actor(actor_id: int, limit: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		if action.actor_id == actor_id:
			result.append(action.duplicate())
	
	if limit > 0:
		return result.slice(0, limit)
	
	return result


## Get actions by category
func get_actions_by_category(category: String, limit: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		if action.category == category:
			result.append(action.duplicate())
	
	if limit > 0:
		return result.slice(0, limit)
	
	return result


## Get actions in time period
func get_actions_in_period(start_tick: int, end_tick: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		if action.tick >= start_tick and action.tick <= end_tick:
			result.append(action.duplicate())
	
	return result


## Get actions in region
func get_actions_in_region(center: Vector2i, radius: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		if action.tile.distance_to(center) <= radius:
			result.append(action.duplicate())
	
	return result


## Get permanent actions only
func get_permanent_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		if action.permanent:
			result.append(action.duplicate())
	
	return result


## Get all chronicles
func get_all_chronicles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for chronicle in historical_chronicles:
		result.append(chronicle.duplicate())
	
	return result


## Get chronicle by era
func get_chronicles_by_era(era: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for chronicle in historical_chronicles:
		if chronicle.era == era:
			result.append(chronicle.duplicate())
	
	return result


## Mark action as read (for tracking)
func mark_action_read(action_id: int) -> void:
	for action in action_ledger:
		if action.action_id == action_id:
			action.read_count += 1
			break


## Get most-read actions (most significant to history)
func get_most_read_actions(limit: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		result.append(action.duplicate())
	
	result.sort_custom(func(a, b): return a.read_count > b.read_count)
	
	return result.slice(0, limit)


# ==================== UTILITY ====================

func _get_pawn_name(pawn_id: int) -> String:
	if _pawn_spawner == null:
		return "Unknown"
	
	# Find pawn by ID
	for pawn in _pawn_spawner.pawns:
		if pawn != null and is_instance_valid(pawn) and pawn.data != null:
			if int(pawn.data.id) == pawn_id:
				return pawn.data.get("display_name", "Unknown")
	
	return "Pawn #%d" % pawn_id


# ==================== PUBLIC API ====================

## Get full ledger (for export/save)
func get_full_ledger() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	for action in action_ledger:
		result.append(action.duplicate())
	
	return result


## Get ledger summary
func get_ledger_summary() -> Dictionary:
	return {
		"total_actions": action_ledger.size(),
		"permanent_actions": action_ledger.filter(func(a): return a.permanent).size(),
		"total_chronicles": historical_chronicles.size(),
		"total_scars": world_scars.size(),
		"permanent_scars": world_scars.filter(func(s): return s.permanent).size(),
		"total_transfers": generational_transfers.size()
	}


## Export ledger to save data
func export_to_save() -> Dictionary:
	return {
		"ledger": action_ledger.duplicate(),
		"chronicles": historical_chronicles.duplicate(),
		"scars": world_scars.duplicate(),
		"transfers": generational_transfers.duplicate(),
		"next_action_id": _next_action_id,
		"next_chronicle_id": _next_chronicle_id,
		"next_scar_id": _next_scar_id,
		"next_transfer_id": _next_transfer_id
	}


## Import ledger from save data
func import_from_save(save_data: Dictionary) -> void:
	if save_data.has("ledger"):
		action_ledger = save_data.ledger.duplicate()
	
	if save_data.has("chronicles"):
		historical_chronicles = save_data.chronicles.duplicate()
	
	if save_data.has("scars"):
		world_scars = save_data.scars.duplicate()
	
	if save_data.has("transfers"):
		generational_transfers = save_data.transfers.duplicate()
	
	if save_data.has("next_action_id"):
		_next_action_id = save_data.next_action_id
	
	if save_data.has("next_chronicle_id"):
		_next_chronicle_id = save_data.next_chronicle_id
	
	if save_data.has("next_scar_id"):
		_next_scar_id = save_data.next_scar_id
	
	if save_data.has("next_transfer_id"):
		_next_transfer_id = save_data.next_transfer_id


## Clear all data (ONLY for world reroll, NOT for normal operation)
func clear() -> void:
	action_ledger.clear()
	historical_chronicles.clear()
	world_scars.clear()
	generational_transfers.clear()
	_next_action_id = 1
	_next_chronicle_id = 1
	_next_scar_id = 1
	_next_transfer_id = 1
