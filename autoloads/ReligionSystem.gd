extends Node
## ReligionSystem — Emergent religion from world events.
##
## HeelKawnians create gods from what they experience:
## - Famine → Harvest God (prayed to for food)
## - Plague → Healing God (prayed to for health)
## - War → War God (prayed to for strength)
## - Flood → Water God (prayed to for mercy)
## - Discovery → Knowledge God (prayed to for wisdom)
##
## Gods emerge when multiple pawns experience the same kind of event.
## A god needs at least 3 believers to form.
## Shrines are built to honor gods. Prayers are recorded in WorldMemory.
## Religion affects mood (prayer = hope), decisions (devout avoid what god forbids),
## and culture (settlements adopt patron gods).
##
## No chosen ones. No prophecy. Gods are created by the people, for the people.
## If everyone who believes in a god dies, the god fades into myth.

enum GodDomain {
	HARVEST,     # Food, farming, fertility
	HEALING,     # Health, medicine, recovery
	WAR,         # Combat, strength, courage
	WATER,       # Rain, rivers, mercy from floods
	KNOWLEDGE,   # Wisdom, learning, innovation
	DEATH,       # Funerals, afterlife, remembrance
	PROTECTION,  # Shelter, safety, walls
	NATURE,      # Forest, wildlife, foraging
}

const DOMAIN_NAMES: Dictionary = {
	GodDomain.HARVEST: "Harvest",
	GodDomain.HEALING: "Healing",
	GodDomain.WAR: "War",
	GodDomain.WATER: "Water",
	GodDomain.KNOWLEDGE: "Knowledge",
	GodDomain.DEATH: "Death",
	GodDomain.PROTECTION: "Protection",
	GodDomain.NATURE: "Nature",
}

# God names generated from domain + cultural style
const GOD_NAME_PREFIXES: Dictionary = {
	GodDomain.HARVEST: ["Aldith", "Berran", "Ceres", "Dagon", "Eostre"],
	GodDomain.HEALING: ["Aescul", "Brighid", "Eir", "Hygeia", "Lazar"],
	GodDomain.WAR: ["Ares", "Belli", "Camulus", "Durga", "Mars"],
	GodDomain.WATER: ["Aegir", "Njord", "Sedna", "Tethys", "Varuna"],
	GodDomain.KNOWLEDGE: ["Athena", "Bragi", "Enki", "Hermes", "Saraswati"],
	GodDomain.DEATH: ["Anubis", "Erebos", "Hela", "Morrigan", "Yama"],
	GodDomain.PROTECTION: ["Aegis", "Bastet", "Fortuna", "Hestia", "Tyr"],
	GodDomain.NATURE: ["Artemis", "Cernunnos", "Dryad", "Silvanus", "Verdandi"],
}

const MIN_BELIEVERS_TO_FORM: int = 3
const RELIGION_CHECK_INTERVAL: int = 2000
const PRAYER_MOOD_BOOST: float = 15.0
const PRAYER_DURATION: int = 200

# Active gods: god_id -> {domain, name, believers, settlement_id, tick_formed, shrines}
var _gods: Dictionary = {}
var _next_god_id: int = 1

# Pawn beliefs: pawn_id -> {god_id, devotion (0-100)}
var _beliefs: Dictionary = {}

# Pending belief events: when a pawn experiences a significant event,
# they may start believing in the relevant domain's god
var _belief_events: Dictionary = {}  # pawn_id -> array of domains

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


## When a pawn experiences a significant event, they may form a belief.
func on_significant_event(pawn_id: int, event_type: String, severity: float = 1.0) -> void:
	var domain: int = _domain_for_event(event_type)
	if domain < 0:
		return
	if not _belief_events.has(pawn_id):
		_belief_events[pawn_id] = []
	_belief_events[pawn_id].append({"domain": domain, "severity": severity, "tick": GameManager.tick_count if GameManager != null else 0})
	# If 3+ events of the same domain, the pawn becomes a believer
	var domain_count: int = 0
	for evt in _belief_events[pawn_id]:
		if int(evt.get("domain", -1)) == domain:
			domain_count += 1
	if domain_count >= 3:
		_become_believer(pawn_id, domain)


func _domain_for_event(event_type: String) -> int:
	match event_type:
		"famine", "starvation", "hunger_emergency", "food_event":
			return GodDomain.HARVEST
		"plague", "disease", "infection", "injury":
			return GodDomain.HEALING
		"combat", "war", "battle", "death_combat":
			return GodDomain.WAR
		"flood", "drought", "water_event":
			return GodDomain.WATER
		"discovery", "innovation", "teaching":
			return GodDomain.KNOWLEDGE
		"death", "funeral", "burial":
			return GodDomain.DEATH
		"shelter_built", "wall_built", "settlement_founded":
			return GodDomain.PROTECTION
		"forage", "hunt", "wildlife":
			return GodDomain.NATURE
		_:
			return -1


func _become_believer(pawn_id: int, domain: int) -> void:
	# Find or create a god for this domain
	var god_id: int = _find_or_create_god(domain, pawn_id)
	if god_id < 0:
		return
	# Add to beliefs
	if not _beliefs.has(pawn_id):
		_beliefs[pawn_id] = {}
	if not _beliefs[pawn_id].has(god_id):
		_beliefs[pawn_id][god_id] = 20.0  # Starting devotion
	# Add to god's believers
	if _gods.has(god_id):
		var god: Dictionary = _gods[god_id]
		if not god.get("believers", []).has(pawn_id):
			god["believers"].append(pawn_id)
			god["follower_count"] = int(god.get("follower_count", 0)) + 1
	# Record belief event
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": pawn_id,
		"belief_formed": true,
		"god": _gods.get(god_id, {}).get("name", "unknown"),
		"domain": DOMAIN_NAMES.get(domain, "unknown"),
	})


func _find_or_create_god(domain: int, first_believer_id: int) -> int:
	# Check if a god of this domain already exists in the believer's settlement
	var settlement_id: int = -1
	if SettlementMemory != null:
		settlement_id = SettlementMemory.get_settlement_id_for_pawn(first_believer_id)
	# Find existing god of this domain in this settlement
	for gid in _gods:
		var god: Dictionary = _gods[gid]
		if int(god.get("domain", -1)) == domain:
			if settlement_id < 0 or int(god.get("settlement_id", -1)) == settlement_id:
				return int(gid)
	# Create new god
	var god_id: int = _next_god_id
	_next_god_id += 1
	var prefixes: Array = GOD_NAME_PREFIXES.get(domain, ["Unknown"])
	var name: String = prefixes[WorldRNG.rangei(0, prefixes.size() - 1, god_id, &"god_name")]
	_gods[god_id] = {
		"domain": domain,
		"name": name,
		"believers": [first_believer_id],
		"follower_count": 1,
		"settlement_id": settlement_id,
		"tick_formed": GameManager.tick_count if GameManager != null else 0,
		"shrines": 0,
		"prayers_answered": 0,
	}
	# Record god formation
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"god_formed": true,
		"god_name": name,
		"domain": DOMAIN_NAMES.get(domain, "unknown"),
		"settlement_id": settlement_id,
	})
	return god_id


## Process religion on tick.
func _on_game_tick(tick: int) -> void:
	if tick % RELIGION_CHECK_INTERVAL != 0:
		return
	# Check if any pending belief events should form gods
	_check_belief_formation(tick)
	# Prune dead believers
	_prune_dead_believers()
	# Fade gods with no believers
	_fade_dead_gods()


func _check_belief_formation(tick: int) -> void:
	# Check each domain: if enough pawns have belief events for it, form a god
	var domain_believers: Dictionary = {}
	for pawn_id in _belief_events:
		for evt in _belief_events[pawn_id]:
			var domain: int = int(evt.get("domain", -1))
			if domain < 0:
				continue
			if not domain_believers.has(domain):
				domain_believers[domain] = []
			domain_believers[domain].append(pawn_id)
	# For each domain with enough potential believers, form a god
	for domain in domain_believers:
		var pawns: Array = domain_believers[domain]
		if pawns.size() >= MIN_BELIEVERS_TO_FORM:
			# Use the first believer as the founder
			_find_or_create_god(domain, int(pawns[0]))
			# Convert all believers
			for pid in pawns:
				_become_believer(int(pid), domain)


func _prune_dead_believers() -> void:
	var all_pawns: Array = PawnAccess.find_alive_pawns()
	var alive_ids: Dictionary = {}
	for pawn in all_pawns:
		if pawn != null and is_instance_valid(pawn) and pawn.data != null:
			alive_ids[int(pawn.data.id)] = true
	# Remove dead believers from gods
	for god_id in _gods:
		var god: Dictionary = _gods[god_id]
		var believers: Array = god.get("believers", [])
		var to_remove: Array = []
		for pid in believers:
			if not alive_ids.has(pid):
				to_remove.append(pid)
		for pid in to_remove:
			believers.erase(pid)
			god["follower_count"] = int(god.get("follower_count", 0)) - 1
	# Remove dead pawns from beliefs
	for pawn_id in _beliefs.keys():
		if not alive_ids.has(int(pawn_id)):
			_beliefs.erase(pawn_id)


func _fade_dead_gods() -> void:
	var to_remove: Array = []
	for god_id in _gods:
		var god: Dictionary = _gods[god_id]
		if int(god.get("follower_count", 0)) <= 0:
			to_remove.append(god_id)
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.LIFE_EVENT,
				"tick": GameManager.tick_count if GameManager != null else 0,
				"god_faded": true,
				"god_name": god.get("name", "unknown"),
				"domain": DOMAIN_NAMES.get(int(god.get("domain", -1)), "unknown"),
			})
	for gid in to_remove:
		_gods.erase(gid)


## Get the god a pawn believes in most strongly.
func get_primary_god(pawn_id: int) -> Dictionary:
	if not _beliefs.has(pawn_id):
		return {}
	var beliefs: Dictionary = _beliefs[pawn_id]
	var best_god: int = -1
	var best_devotion: float = 0.0
	for god_id in beliefs:
		if float(beliefs[god_id]) > best_devotion:
			best_devotion = float(beliefs[god_id])
			best_god = int(god_id)
	if best_god < 0 or not _gods.has(best_god):
		return {}
	return _gods[best_god]


## Get all beliefs for a pawn.
func get_beliefs(pawn_id: int) -> Dictionary:
	return _beliefs.get(pawn_id, {})


## Get all active gods.
func get_all_gods() -> Dictionary:
	return _gods


## Record a prayer (called when pawn visits shrine).
func record_prayer(pawn_id: int, god_id: int) -> void:
	if not _beliefs.has(pawn_id) or not _beliefs[pawn_id].has(god_id):
		return
	# Increase devotion
	_beliefs[pawn_id][god_id] = minf(100.0, float(_beliefs[pawn_id][god_id]) + 5.0)
	# Mood boost from prayer
	var pawn: HeelKawnian = _find_pawn_by_id(pawn_id)
	if pawn != null and is_instance_valid(pawn) and pawn.data != null:
		pawn.data.add_mood_event(MoodEvent.Type.HOPE, PRAYER_MOOD_BOOST, PRAYER_DURATION)
	# Record prayer
	if _gods.has(god_id):
		_gods[god_id]["prayers_answered"] = int(_gods[god_id].get("prayers_answered", 0)) + 1


func _find_pawn_by_id(pawn_id: int) -> HeelKawnian:
	var all_pawns: Array = PawnAccess.find_alive_pawns()
	for pawn in all_pawns:
		if pawn != null and is_instance_valid(pawn) and pawn.data != null and int(pawn.data.id) == pawn_id:
			return pawn
	return null


## Get religion summary for UI.
func get_religion_summary() -> Dictionary:
	var result: Dictionary = {}
	for god_id in _gods:
		var god: Dictionary = _gods[god_id]
		result[god.get("name", "unknown")] = {
			"domain": DOMAIN_NAMES.get(int(god.get("domain", -1)), "unknown"),
			"followers": int(god.get("follower_count", 0)),
			"shrines": int(god.get("shrines", 0)),
			"prayers_answered": int(god.get("prayers_answered", 0)),
		}
	return result
