extends Node
## MemorialSystem — Physical memory of significant events
##
## Creates memorials at sites of:
## - Pawn deaths (grave markers)
## - Battles (monuments)
## - Great achievements (statues)
## - Settlement founding (founding stones)
## - Disasters (ruin markers)
##
## Pawns visit memorials (pilgrimages), gather for commemorations,
## and transmit knowledge through oral tradition.

const MEMORIAL_TYPES: Dictionary = {
	"grave_marker": {"sprite": "res://sprites/memorials/grave.png", "build_time": 0, "size": "small"},
	"battle_monument": {"sprite": "res://sprites/memorials/monument.png", "build_time": 0, "size": "large"},
	"founding_stone": {"sprite": "res://sprites/memorials/founding_stone.png", "build_time": 0, "size": "medium"},
	"ruin_marker": {"sprite": "res://sprites/memorials/ruin.png", "build_time": 0, "size": "small"},
	"memorial_plaque": {"sprite": "res://sprites/memorials/plaque.png", "build_time": 0, "size": "small"},
	"mass_grave": {"sprite": "res://sprites/memorials/mass_grave.png", "build_time": 0, "size": "medium"},
}

const COMMEMORATION_INTERVAL: int = 10000  # Ticks between commemorations (~1 year)
const GATHERING_RADIUS: float = 10.0  # Tiles around memorial
const ORAL_TRADITION_KNOWLEDGE_DECAY: float = 0.05  # 5% mutation per retelling
const MEMORIAL_DECAY_ENABLED: bool = false  # Human directive: memorials are PERMANENT

# Memorial data structure
## {
##   "memorial_id": int,
##   "tile": Vector2i,
##   "memorial_type": String,
##   "event_id": int,
##   "created_tick": int,
##   "associated_pawns": Array[int],
##   "visitors": Array[int],
##   "decay_level": float
## }
var memorials: Array[Dictionary] = []
var _next_memorial_id: int = 1

# Gathering history
var gatherings: Array[Dictionary] = []

# References
@onready var _world_memory: Node = null
@onready var _pawn_spawner: Node = null
@onready var _gossip_manager: Node = null
@onready var _knowledge_system: Node = null


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_gossip_manager = get_node_or_null("/root/GossipManager")
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	
	# Note: WorldMemory.gd calls MemorialSystem directly via ms.call() methods
	# No signal connection needed


func _on_game_tick(tick: int) -> void:
	# Check for commemorations every tick
	if tick % COMMEMORATION_INTERVAL == 0:
		_process_commemorations(tick)
	
	# Decay memorials slowly (optional)
	if tick % 1000 == 0:
		_decay_memorials(tick)


# ==================== MEMORIAL CREATION ====================

## Create a memorial at the specified tile
func create_memorial(data: Dictionary) -> int:
	var memorial: Dictionary = {
		"memorial_id": _next_memorial_id,
		"tile": data.get("tile", Vector2i.ZERO),
		"memorial_type": data.get("type", "grave_marker"),
		"event_id": data.get("event_id", -1),
		"created_tick": GameManager.tick_count,
		"associated_pawns": data.get("associated_pawns", []),
		"visitors": [],
		"decay_level": 0.0,
		"built_by": data.get("built_by", "auto"),  # "auto", "player", or "npc"
		"custom_inscription": data.get("inscription", "")
	}
	
	memorials.append(memorial)
	_next_memorial_id += 1
	
	# Record to WorldMemory
	_record_memorial_creation(memorial)
	
	return memorial.memorial_id


## Player manually places a memorial (human directive: both manual and auto)
func player_place_memorial(tile: Vector2i, memorial_type: String, associated_pawns: Array[int] = [], inscription: String = "") -> int:
	return create_memorial({
		"tile": tile,
		"type": memorial_type,
		"associated_pawns": associated_pawns,
		"built_by": "player",
		"inscription": inscription
	})


## NPC/HeelKawnian autonomously builds memorial for their dead
func npc_build_memorial(pawn_builder: Node, deceased_pawn_data: RefCounted, tile: Vector2i) -> void:
	var memorial_type: String = "grave_marker"

	# Check relationship to determine memorial type
	if pawn_builder.data != null and deceased_pawn_data != null:
		# Family member builds memorial
		if _are_related(int(pawn_builder.data.id), int(deceased_pawn_data.id)):
			memorial_type = "memorial_plaque"  # More personal
		# Grudge enemy might build mocking memorial
		elif _gossip_manager != null and _gossip_manager.has_grudge(int(pawn_builder.data.id), int(deceased_pawn_data.id)):
			memorial_type = "ruin_marker"  # Minimal, dismissive

	create_memorial({
		"tile": tile,
		"type": memorial_type,
		"associated_pawns": [int(deceased_pawn_data.id)],
		"built_by": "npc",
		"event_id": _get_event_id_for_death(int(deceased_pawn_data.id))
	})


## Create mass memorial for multiple deaths (battle, disaster, etc.)
func create_mass_memorial(tile: Vector2i, deceased_pawns: Array[RefCounted], event_name: String, event_description: String) -> int:
	var pawn_ids: Array[int] = []
	for pawn_data in deceased_pawns:
		if pawn_data != null:
			pawn_ids.append(int(pawn_data.id))

	var inscription: String = "%s\n\n%s" % [event_name, event_description]
	inscription += "\n\nHere fell:\n"
	for pawn_data in deceased_pawns:
		if pawn_data != null:
			inscription += "• %s\n" % pawn_data.display_name

	return create_memorial({
		"tile": tile,
		"type": "mass_grave",
		"associated_pawns": pawn_ids,
		"built_by": "auto",
		"inscription": inscription
	})


## Create memorial for pawn death
func create_death_memorial(pawn_data: RefCounted, death_tile: Vector2i, violent: bool = false) -> void:
	var memorial_type: String = "grave_marker"
	if violent:
		memorial_type = "memorial_plaque"

	create_memorial({
		"tile": death_tile,
		"type": memorial_type,
		"associated_pawns": [int(pawn_data.id)],
		"event_id": _get_event_id_for_death(int(pawn_data.id))
	})


## Create memorial for battle (multiple deaths at same location)
func create_battle_memorial(battle_tile: Vector2i, participants: Array[int]) -> void:
	# Check if memorial already exists at this tile
	for memorial in memorials:
		if memorial.tile == battle_tile and memorial.memorial_type == "battle_monument":
			return  # Already exists
	
	create_memorial({
		"tile": battle_tile,
		"type": "battle_monument",
		"associated_pawns": participants,
		"event_id": _get_event_id_for_battle(battle_tile)
	})


# ==================== COMMEMORATION GATHERINGS ====================

func _process_commemorations(tick: int) -> void:
	for memorial in memorials:
		var ticks_since_creation: int = tick - memorial.created_tick
		if ticks_since_creation > 0 and ticks_since_creation % COMMEMORATION_INTERVAL == 0:
			_trigger_commemoration_gathering(memorial)


func _trigger_commemoration_gathering(memorial: Dictionary) -> void:
	if _pawn_spawner == null:
		return
	
	# Find pawns within gathering radius
	var attendees: Array[int] = []
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		var distance: float = pawn.position.distance_to(Vector2(memorial.tile))
		if distance <= GATHERING_RADIUS:
			attendees.append(int(pawn.data.id))
	
	if attendees.size() == 0:
		return  # Nobody to attend
	
	# Create gathering record
	var gathering: Dictionary = {
		"gathering_id": _next_gathering_id(),
		"memorial_id": memorial.memorial_id,
		"tick": GameManager.tick_count,
		"attendees": attendees,
		"stories_told": _get_event_stories(memorial.event_id),
		"knowledge_transmitted": _get_associated_knowledge(memorial)
	}
	
	gatherings.append(gathering)
	
	# Apply gathering effects
	_apply_gathering_effects(gathering)
	
	# Record to WorldMemory
	_record_gathering(gathering)


func _apply_gathering_effects(gathering: Dictionary) -> void:
	# Mood bonus for attendees
	for pawn_id in gathering.attendees:
		var pawn = _get_pawn_by_id(pawn_id)
		if pawn != null and pawn.data != null:
			# "Honored" moodlet
			if pawn.data.has("mood"):
				pawn.data.mood = minf(100.0, pawn.data.mood + 15.0)

	# Note: Gossip spread is handled by GossipManager._process_memorial_gossip_spread()
	# when 3+ pawns gather at memorial

	# Knowledge transmission
	if _knowledge_system != null and gathering.knowledge_transmitted.size() > 0:
		_transmit_knowledge_at_gathering(gathering)


# ==================== ORAL TRADITION ====================

func _get_associated_knowledge(memorial: Dictionary) -> Array[String]:
	var knowledge: Array[String] = []
	
	# Get knowledge from associated pawns' memories
	for pawn_id in memorial.associated_pawns:
		var pawn = _get_pawn_by_id(pawn_id)
		if pawn != null and pawn.data != null:
			# Add skills this pawn had
			if pawn.data.has("skills"):
				for skill_idx in range(pawn.data.skills.size()):
					if pawn.data.skills[skill_idx] > 50:  # Skilled
						knowledge.append(_knowledge_system.get_knowledge_type_name(skill_idx))
	
	return knowledge


func _transmit_knowledge_at_gathering(gathering: Dictionary) -> void:
	# Find elders (age > 40) and youth (age < 20)
	var elders: Array[int] = []
	var youth: Array[int] = []
	
	for pawn_id in gathering.attendees:
		var pawn = _get_pawn_by_id(pawn_id)
		if pawn != null and pawn.data != null:
			var age: float = pawn.data.get("age", 0.0)
			if age > 40.0:
				elders.append(pawn_id)
			elif age < 20.0:
				youth.append(pawn_id)
	
	# Elders teach youth
	for elder_id in elders:
		for youth_id in youth:
			for knowledge_type in gathering.knowledge_transmitted:
				_knowledge_system.teach_knowledge(youth_id, elder_id, knowledge_type)


# ==================== PILGRIMAGE SYSTEM ====================

## Check if pawn should go on pilgrimage
func check_pilgrimage_desire(pawn: Node) -> bool:
	if pawn.data == null:
		return false
	
	for memorial in memorials:
		if _should_pilgrimage(pawn, memorial):
			_start_pilgrimage(pawn, memorial)
			return true
	
	return false


func _should_pilgrimage(pawn: Node, memorial: Dictionary) -> bool:
	var pawn_id: int = int(pawn.data.id)
	
	# Family member
	for associated_id in memorial.associated_pawns:
		if _are_related(pawn_id, associated_id):
			return true
	
	# Shared profession with deceased
	# (simplified - would need death record profession data)
	
	# Grudge closure
	if _gossip_manager != null:
		for associated_id in memorial.associated_pawns:
			if _gossip_manager.has_grudge(pawn_id, associated_id):
				return true
	
	return false


func _start_pilgrimage(pawn: Node, memorial: Dictionary) -> void:
	# Set pawn state to pilgrim
	if pawn.has_method("set_state"):
		pawn.call("set_state", "pilgrimage")
	
	# Pawn will pathfind to memorial tile
	# (integrate with pawn's pathfinding system)
	if pawn.has_method("move_to"):
		pawn.call("move_to", memorial.tile)


# ==================== HELPERS ====================

func _get_pawn_by_id(pawn_id: int) -> Node:
	if _pawn_spawner == null:
		return null
	
	for pawn in _pawn_spawner.pawns:
		if pawn != null and pawn.data != null and int(pawn.data.id) == pawn_id:
			return pawn
	return null


func _are_related(pawn_a_id: int, pawn_b_id: int) -> bool:
	# Check kinship system
	var kinship = get_node_or_null("/root/KinshipSystem")
	if kinship != null and kinship.has_method("are_related"):
		return kinship.call("are_related", pawn_a_id, pawn_b_id)
	return false


func _get_event_stories(event_id: int) -> Array[String]:
	if _world_memory == null:
		return []
	
	# Get event from WorldMemory
	var events = _world_memory.get_events()
	for event in events:
		if event.get("id") == event_id:
			return [_format_event_story(event)]
	
	return []


func _format_event_story(event: Dictionary) -> String:
	var story: String = ""
	var event_type: String = event.get("type", "unknown")
	
	match event_type:
		"pawn_death":
			story = "Here fell %s, a %s who lived %.1f years" % [
				event.get("name", "unknown"),
				event.get("profession", "wanderer"),
				float(event.get("age", 0)) / 360.0
			]
		"battle":
			story = "Here %d fought and %d fell" % [
				int(event.get("participants", 0)),
				int(event.get("casualties", 0))
			]
		"settlement_founded":
			story = "Here %s was founded in year %d" % [
				event.get("settlement_name", "this place"),
				int(event.get("tick", 0)) / 3600
			]
	
	return story


func _record_memorial_creation(memorial: Dictionary) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "memorial_created",
		"memorial_id": memorial.memorial_id,
		"memorial_type": memorial.memorial_type,
		"tile": memorial.tile,
		"tick": GameManager.tick_count
	})


func _record_gathering(gathering: Dictionary) -> void:
	if _world_memory == null:
		return
	
	_world_memory.record_event({
		"type": "commemoration_gathering",
		"gathering_id": gathering.gathering_id,
		"memorial_id": gathering.memorial_id,
		"attendees": gathering.attendees.size(),
		"tick": GameManager.tick_count
	})


func _next_gathering_id() -> int:
	return gatherings.size() + 1


func _get_event_id_for_death(pawn_id: int) -> int:
	# Find most recent death event for this pawn
	if _world_memory == null:
		return -1
	
	var events = _world_memory.get_events()
	for i in range(events.size() - 1, -1, -1):
		var event = events[i]
		if event.get("type") == "pawn_death" and event.get("pawn_id") == pawn_id:
			return event.get("id", -1)
	
	return -1


func _get_event_id_for_battle(tile: Vector2i) -> int:
	# Find most recent battle event at this tile
	if _world_memory == null:
		return -1
	
	var events = _world_memory.get_events()
	for i in range(events.size() - 1, -1, -1):
		var event = events[i]
		var event_tile: Vector2i = event.get("tile", Vector2i.ZERO)
		if event.get("type") == "battle" and event_tile == tile:
			return event.get("id", -1)

	return -1


func _decay_memorials(tick: int) -> void:
	# Human directive: memorials are PERMANENT, do not decay
	if not MEMORIAL_DECAY_ENABLED:
		return
	
	# Optional: memorials decay over time without maintenance
	for memorial in memorials:
		memorial.decay_level += 0.01  # 1% decay per 1000 ticks
		if memorial.decay_level >= 100.0:
			# Memorial destroyed, remove it
			memorials.erase(memorial)
			break


# ==================== DEBUG ====================

func get_memorials() -> Array[Dictionary]:
	return memorials


func get_gatherings() -> Array[Dictionary]:
	return gatherings


func get_memorial_at_tile(tile: Vector2i) -> Dictionary:
	for memorial in memorials:
		if memorial.tile == tile:
			return memorial
	return {}


## Get a memorial that this pawn should pilgrimage to
func get_memorial_for_pilgrimage(pawn_id: int) -> Dictionary:
	# Check for family memorials first
	for memorial in memorials:
		for associated_id in memorial.associated_pawns:
			if _are_related(pawn_id, associated_id):
				return memorial  # Family memorial
	
	# Check for grudge-related memorials
	if _gossip_manager != null:
		for memorial in memorials:
			for associated_id in memorial.associated_pawns:
				if _gossip_manager.has_grudge(pawn_id, associated_id):
					return memorial  # Grudge enemy memorial (closure)
	
	# Check for same profession memorials
	var pawn = _get_pawn_by_id(pawn_id)
	if pawn != null and pawn.data != null:
		var pawn_profession = pawn.data.current_profession
		for memorial in memorials:
			for associated_id in memorial.associated_pawns:
				var deceased_pawn = _get_pawn_by_id(associated_id)
				if deceased_pawn != null and deceased_pawn.data != null:
					if deceased_pawn.data.current_profession == pawn_profession:
						return memorial  # Same profession memorial
	
	# No memorial found
	return {}
