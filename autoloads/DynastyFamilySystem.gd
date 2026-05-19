extends Node
## DynastyFamilySystem — Bannerlord/CK-style family, marriage, children, and dynasty tracking.
##
## Builds on KinshipSystem to add:
## - Surnames and dynasty names
## - Marriage negotiations and ceremonies
## - Child generation with inherited traits
## - Family reputation and prestige
## - Lineage tracking (family trees)
## - Inheritance of property, titles, knowledge
## - Family feuds and alliances
##
## Design principles:
## - Families emerge from marriages and births
## - Dynasties form when families achieve prominence
## - Traits are inherited with variation (not clones)
## - Family reputation affects social standing
## - Lineage persists across generations

# ============================================================
# CONSTANTS
# ============================================================

## How often to check for marriage opportunities (ticks)
const MARRIAGE_CHECK_INTERVAL: int = 3000

## How often to process births (ticks)
const BIRTH_CHECK_INTERVAL: int = 5000

## How often to update dynasty status (ticks)
const DYNASTY_UPDATE_INTERVAL: int = 10000

## Minimum age for marriage (in sim ticks, ~18 years)
const MARRIAGE_MIN_AGE: int = 8640

## Maximum age for first marriage (in sim ticks, ~40 years)
const MARRIAGE_MAX_FIRST_AGE: int = 19200

## Pregnancy duration (in sim ticks, ~9 months)
const PREGNANCY_DURATION: int = 4320

## Base chance of conception per birth check
const CONCEPTION_BASE_CHANCE: float = 0.15

## Minimum population pressure for marriage incentives
const MARRIAGE_POP_PRESSURE: float = 0.3

## Dynasty formation threshold (family prestige)
const DYNASTY_PRESTIGE_THRESHOLD: float = 50.0

## Surname generation word lists
const SURNAME_PREFIXES: PackedStringArray = [
	"Stone", "Iron", "Wood", "River", "Hill", "Field", "Ash", "Oak",
	"Briar", "Thorn", "Wolf", "Bear", "Hawk", "Fox", "Deer", "Elk",
	"Storm", "Wind", "Rain", "Snow", "Frost", "Dawn", "Dusk", "Night",
	"Gold", "Silver", "Copper", "Bronze", "Flint", "Clay",
]

const SURNAME_SUFFIXES: PackedStringArray = [
	"son", "daughter", "born", "weaver", "keeper", "ward", "heart",
	"hand", "foot", "eye", "head", "blood", "bone", "skin", "hair",
	"shield", "blade", "bow", "arrow", "hammer", "axe", "spear",
	"fall", "brook", "ford", "bridge", "gate", "wall", "tower",
	"wood", "field", "stone", "hill", "dale", "vale", "mere",
]

const DYNASTY_NAMES: PackedStringArray = [
	"the Great", "the Wise", "the Bold", "the Just", "the Brave",
	"the Old", "the Young", "the Red", "the Black", "the White",
	"of the North", "of the South", "of the East", "of the West",
	"of the River", "of the Mountain", "of the Forest", "of the Plains",
]

# ============================================================
# FAMILY/DYNASTY DATA
# ============================================================

## families: family_id -> Dictionary
## {
##   "id": int,
##   "surname": String,
##   "members": Array[int],  # pawn_ids
##   "founder_id": int,
##   "formed_tick": int,
##   "prestige": float,
##   "reputation": float,  # -100 to 100
##   "wealth": float,
##   "property": Array,  # owned buildings, land
##   "allied_families": Array[int],
##   "feuding_families": Array[int],
##   "dynasty_id": int,  # -1 if not part of a dynasty
## }
var families: Dictionary = {}
var _next_family_id: int = 1

## dynasties: dynasty_id -> Dictionary
## {
##   "id": int,
##   "name": String,
##   "families": Array[int],  # family_ids
##   "founder_family_id": int,
##   "formed_tick": int,
##   "prestige": float,
##   "power": float,  # combined military/economic strength
##   "culture": String,
##   "motto": String,
##   "color": String,  # hex color for dynasty banner
## }
var dynasties: Dictionary = {}
var _next_dynasty_id: int = 1

## marriages: marriage_id -> Dictionary
## {
##   "id": int,
##   "spouse_a": int,  # pawn_id
##   "spouse_b": int,  # pawn_id
##   "tick_married": int,
##   "is_arranged": bool,
##   "family_alliance": bool,
##   "children": Array[int],  # pawn_ids
##   "status": String,  # "active", "widowed", "divorced"
## }
var marriages: Dictionary = {}
var _next_marriage_id: int = 1

## pregnancies: pawn_id -> Dictionary
## {
##   "mother_id": int,
##   "father_id": int,
##   "conceived_tick": int,
##   "due_tick": int,
## }
var pregnancies: Dictionary = {}

## Lineage cache: pawn_id -> {"father_id": int, "mother_id": int, "generation": int}
var _lineage_cache: Dictionary = {}

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Check for marriages
	if tick % MARRIAGE_CHECK_INTERVAL == 0:
		_process_marriages(tick)
	# Process births
	if tick % BIRTH_CHECK_INTERVAL == 0:
		_process_births(tick)
	# Update dynasty status
	if tick % DYNASTY_UPDATE_INTERVAL == 0:
		_update_dynasties(tick)


# ============================================================
# MARRIAGE SYSTEM
# ============================================================

func _process_marriages(tick: int) -> void:
	"""Find eligible pawns and arrange marriages."""
	if PawnAccess == null:
		return
	var eligible: Array[Dictionary] = _find_eligible_partners(tick)
	if eligible.size() < 2:
		return
	# Try to match partners
	var matched: Dictionary = {}
	for i in range(eligible.size()):
		if matched.has(i):
			continue
		var pa: Dictionary = eligible[i]
		for j in range(i + 1, eligible.size()):
			if matched.has(j):
				continue
			var pb: Dictionary = eligible[j]
			if _are_compatible_partners(pa, pb, tick):
				_arrange_marriage(pa, pb, tick)
				matched[i] = true
				matched[j] = true
				break


func _find_eligible_partners(tick: int) -> Array[Dictionary]:
	"""Find pawns eligible for marriage."""
	var eligible: Array[Dictionary] = []
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.data == null:
			continue
		var age: int = int(p.data.get("age_ticks", 0))
		if age < MARRIAGE_MIN_AGE:
			continue
		# Check if already married
		if KinshipSystem != null and KinshipSystem.has_method("get_spouses"):
			var spouses: Array = KinshipSystem.get_spouses(int(p.data.id))
			if not spouses.is_empty():
				continue
		# Check if currently pregnant
		if pregnancies.has(int(p.data.id)):
			continue
		eligible.append({
			"pawn": p,
			"id": int(p.data.id),
			"age": age,
			"family_id": _get_family_for_pawn(int(p.data.id)),
			"prestige": float(p.data.get("prestige", 0.0)),
		})
	return eligible


func _are_compatible_partners(pa: Dictionary, pb: Dictionary, tick: int) -> bool:
	"""Check if two pawns are compatible for marriage."""
	# Not too old for first marriage
	if pa["age"] > MARRIAGE_MAX_FIRST_AGE and pb["age"] > MARRIAGE_MAX_FIRST_AGE:
		return false
	# Not from same family (avoid close kin)
	if pa["family_id"] >= 0 and pa["family_id"] == pb["family_id"]:
		# Check if actually related
		if KinshipSystem != null and KinshipSystem.has_method("are_related"):
			if KinshipSystem.are_related(pa["id"], pb["id"]):
				return false
	# Compatible prestige levels (within 30 points)
	if abs(pa["prestige"] - pb["prestige"]) > 30.0:
		return false
	return true


func _arrange_marriage(pa: Dictionary, pb: Dictionary, tick: int) -> void:
	"""Arrange a marriage between two pawns."""
	var mid: int = _next_marriage_id
	_next_marriage_id += 1
	var is_arranged: bool = true  # Default to arranged; love matches are rarer
	var family_alliance: bool = pa["family_id"] >= 0 and pb["family_id"] >= 0 and pa["family_id"] != pb["family_id"]
	marriages[mid] = {
		"id": mid,
		"spouse_a": pa["id"],
		"spouse_b": pb["id"],
		"tick_married": tick,
		"is_arranged": is_arranged,
		"family_alliance": family_alliance,
		"children": [],
		"status": "active",
	}
	# Register in KinshipSystem
	if KinshipSystem != null and KinshipSystem.has_method("marry"):
		KinshipSystem.marry(pa["id"], pb["id"])
	# If family alliance, boost family relations
	if family_alliance:
		var fa: Dictionary = families.get(pa["family_id"], {})
		var fb: Dictionary = families.get(pb["family_id"], {})
		if not fa.is_empty() and not fb.is_empty():
			if not pb["family_id"] in fa.get("allied_families", []):
				fa["allied_families"].append(pb["family_id"])
			if not pa["family_id"] in fb.get("allied_families", []):
				fb["allied_families"].append(pa["family_id"])
	# Boost prestige for both families
	if pa["family_id"] >= 0:
		var fa: Dictionary = families.get(pa["family_id"], {})
		if not fa.is_empty():
			fa["prestige"] = float(fa.get("prestige", 0.0)) + 5.0
	if pb["family_id"] >= 0:
		var fb: Dictionary = families.get(pb["family_id"], {})
		if not fb.is_empty():
			fb["prestige"] = float(fb.get("prestige", 0.0)) + 5.0
	# Log marriage
	var name_a: String = str(pa.get("name", "Unknown"))
	var name_b: String = str(pb.get("name", "Unknown"))
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "%s and %s were joined in marriage." % [name_a, name_b],
			PackedStringArray(["marriage", name_a, name_b]))


# ============================================================
# BIRTH SYSTEM
# ============================================================

func _process_births(tick: int) -> void:
	"""Process active pregnancies and generate children."""
	var to_remove: Array[int] = []
	for mother_id in pregnancies.keys():
		var preg: Dictionary = pregnancies[mother_id]
		if tick >= int(preg.get("due_tick", 0)):
			# Birth!
			_process_birth(mother_id, preg, tick)
			to_remove.append(mother_id)
	# Also check for new conceptions from married couples
	_try_conceptions(tick)
	# Remove completed pregnancies
	for mid in to_remove:
		pregnancies.erase(mid)


func _try_conceptions(tick: int) -> void:
	"""Try to conceive children for married couples."""
	for mid in marriages.keys():
		var m: Dictionary = marriages[mid]
		if str(m.get("status", "")) != "active":
			continue
		var spouse_a: int = int(m.get("spouse_a", -1))
		var spouse_b: int = int(m.get("spouse_b", -1))
		if spouse_a < 0 or spouse_b < 0:
			continue
		# Check if either is already pregnant
		if pregnancies.has(spouse_a) or pregnancies.has(spouse_b):
			continue
		# Conception chance
		if WorldRNG != null and WorldRNG.has_method("chance_for"):
			if WorldRNG.chance_for(StringName("conception_%d" % mid), CONCEPTION_BASE_CHANCE, tick + mid):
				# Determine mother (random for now; could be biology-based)
				var mother_id: int = spouse_a if WorldRNG.range_for(StringName("mother_%d" % mid), 0.0, 1.0, tick + mid + 1) < 0.5 else spouse_b
				var father_id: int = spouse_b if mother_id == spouse_a else spouse_a
				pregnancies[mother_id] = {
					"mother_id": mother_id,
					"father_id": father_id,
					"conceived_tick": tick,
					"due_tick": tick + PREGNANCY_DURATION,
				}


func _process_birth(mother_id: int, preg: Dictionary, tick: int) -> void:
	"""Process a birth, creating a new pawn."""
	var father_id: int = int(preg.get("father_id", -1))
	var mother_pawn: Node = _get_pawn_by_id(mother_id)
	if mother_pawn == null or mother_pawn.data == null:
		return
	# Determine child's traits (inherited from parents)
	var father_pawn: Node = _get_pawn_by_id(father_id)
	var child_traits: Dictionary = _inherit_traits(mother_pawn, father_pawn)
	# Determine child's surname
	var surname: String = _get_child_surname(mother_pawn, father_pawn)
	# Generate child name
	var child_name: String = _generate_child_name(surname)
	# In a full implementation, this would spawn a new pawn entity.
	# For now, we record the birth in KinshipSystem and family records.
	if KinshipSystem != null and KinshipSystem.has_method("record_birth"):
		KinshipSystem.record_birth(mother_id, father_id, child_name, tick)
	# Update marriage record
	for mid in marriages.keys():
		var m: Dictionary = marriages[mid]
		if int(m.get("spouse_a", -1)) == mother_id or int(m.get("spouse_b", -1)) == mother_id:
			if "children" in m:
				m["children"].append(mother_id)  # Placeholder; real child ID would be from spawn
			break
	# Update family prestige
	var fam_id: int = _get_family_for_pawn(mother_id)
	if fam_id >= 0:
		var fam: Dictionary = families.get(fam_id, {})
		if not fam.is_empty():
			fam["prestige"] = float(fam.get("prestige", 0.0)) + 3.0
	# Log birth
	if ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "%s gave birth to %s." % [str(mother_pawn.data.get("name", "Unknown")), child_name],
			PackedStringArray(["birth", child_name, surname]))


# ============================================================
# TRAIT INHERITANCE
# ============================================================

func _inherit_traits(mother: Node, father: Node) -> Dictionary:
	"""Generate child traits inherited from parents with variation."""
	var child_traits: Dictionary = {}
	var mother_data: Node = mother.data if mother != null else null
	var father_data: Node = father.data if father != null else null
	if mother_data == null and father_data == null:
		return child_traits
	# Inherit physical traits (use base 50.0 since HeelKawnianData uses skill/affinity system)
	var physical_traits: Array[String] = ["strength", "agility", "endurance", "intelligence", "charisma"]
	for trait in physical_traits:
		var avg: float = 50.0
		var variation: float = avg * 0.1
		if WorldRNG != null:
			variation = WorldRNG.range_for(StringName("trait_%s" % trait), -variation, variation, GameManager.tick_count)
		child_traits[trait] = clampf(avg + variation, 0.0, 100.0)
	# Inherit personality traits (use Big Five from HeelKawnianData)
	var personality_traits: Array[String] = ["bravery", "curiosity", "loyalty", "ambition", "empathy"]
	var stat_keys: Array[String] = ["neuroticism", "openness", "agreeableness", "conscientiousness", "extraversion"]
	for i in personality_traits.size():
		var trait: String = personality_traits[i]
		var stat_key: String = stat_keys[i]
		var m_val: float = 50.0
		var f_val: float = 50.0
		if mother_data != null:
			var mv = mother_data.get(stat_key)
			if mv != null:
				m_val = float(mv) * 100.0
		if father_data != null:
			var fv = father_data.get(stat_key)
			if fv != null:
				f_val = float(fv) * 100.0
		var avg: float = (m_val + f_val) / 2.0
		var variation: float = avg * 0.15
		if WorldRNG != null:
			variation = WorldRNG.range_for(StringName("personality_%s" % trait), -variation, variation, GameManager.tick_count + 100)
		child_traits[trait] = clampf(avg + variation, 0.0, 100.0)
	return child_traits


# ============================================================
# FAMILY MANAGEMENT
# ============================================================

func _get_family_for_pawn(pawn_id: int) -> int:
	"""Get the family ID for a pawn."""
	for fid in families.keys():
		var fam: Dictionary = families[fid]
		if pawn_id in fam.get("members", []):
			return fid
	return -1


func create_family_for_pawn(pawn_id: int, surname: String, tick: int) -> int:
	"""Create a new family for a pawn."""
	var fid: int = _next_family_id
	_next_family_id += 1
	families[fid] = {
		"id": fid,
		"surname": surname,
		"members": [pawn_id],
		"founder_id": pawn_id,
		"formed_tick": tick,
		"prestige": 10.0,
		"reputation": 0.0,
		"wealth": 0.0,
		"property": [],
		"allied_families": [],
		"feuding_families": [],
		"dynasty_id": -1,
	}
	return fid


func add_pawn_to_family(pawn_id: int, family_id: int) -> void:
	"""Add a pawn to an existing family."""
	var fam: Dictionary = families.get(family_id, {})
	if fam.is_empty():
		return
	if not pawn_id in fam.get("members", []):
		fam["members"].append(pawn_id)


# ============================================================
# DYNASTY FORMATION
# ============================================================

func _update_dynasties(tick: int) -> void:
	"""Check for families that should form or join dynasties."""
	for fid in families.keys():
		var fam: Dictionary = families[fid]
		if int(fam.get("dynasty_id", -1)) >= 0:
			continue  # Already in a dynasty
		if float(fam.get("prestige", 0.0)) >= DYNASTY_PRESTIGE_THRESHOLD:
			# Check if should join existing dynasty or form new one
			var allied_dynasties: Dictionary = {}
			for afid in fam.get("allied_families", []):
				var allied_fam: Dictionary = families.get(afid, {})
				var adid: int = int(allied_fam.get("dynasty_id", -1))
				if adid >= 0:
					allied_dynasties[adid] = int(allied_dynasties.get(adid, 0)) + 1
			if not allied_dynasties.is_empty():
				# Join the most common allied dynasty
				var best_did: int = -1
				var best_count: int = 0
				for did in allied_dynasties.keys():
					if int(allied_dynasties[did]) > best_count:
						best_count = int(allied_dynasties[did])
						best_did = did
				if best_did >= 0:
					_join_dynasty(fid, best_did, tick)
			else:
				# Form a new dynasty
				_form_dynasty(fid, tick)


func _form_dynasty(family_id: int, tick: int) -> void:
	"""Form a new dynasty from a prominent family."""
	var did: int = _next_dynasty_id
	_next_dynasty_id += 1
	var fam: Dictionary = families.get(family_id, {})
	var surname: String = str(fam.get("surname", "Unknown"))
	var dynasty_name: String = "House " + surname
	var motto: String = _generate_motto()
	var color: String = _generate_dynasty_color(did)
	dynasties[did] = {
		"id": did,
		"name": dynasty_name,
		"families": [family_id],
		"founder_family_id": family_id,
		"formed_tick": tick,
		"prestige": float(fam.get("prestige", 0.0)),
		"power": float(fam.get("wealth", 0.0)) + float(fam.get("prestige", 0.0)),
		"culture": str(fam.get("culture", "unknown")),
		"motto": motto,
		"color": color,
	}
	fam["dynasty_id"] = did
	# Log dynasty formation
	if ChronicleNarrativeSystem != null:
		ChronicleNarrativeSystem._add_narrative(tick, "immediate", "dynasty",
			ChronicleNarrativeSystem._narrate_dynasty_formed({
				"name": dynasty_name,
				"founder": str(fam.get("surname", "Unknown family")),
				"settlement": "",
			}, ChronicleNarrativeSystem._tick_to_year(tick), ChronicleNarrativeSystem._tick_to_season_name(tick)),
			["dynasty_formed", dynasty_name])
	elif ChronicleLog != null:
		ChronicleLog.append_entry(tick, "world", "The dynasty of %s was established. Motto: \"%s\"" % [dynasty_name, motto],
			PackedStringArray(["dynasty", dynasty_name]))


func _join_dynasty(family_id: int, dynasty_id: int, tick: int) -> void:
	"""Join a family to an existing dynasty."""
	var dynasty: Dictionary = dynasties.get(dynasty_id, {})
	var fam: Dictionary = families.get(family_id, {})
	if dynasty.is_empty() or fam.is_empty():
		return
	if not family_id in dynasty.get("families", []):
		dynasty["families"].append(family_id)
	fam["dynasty_id"] = dynasty_id
	# Update dynasty prestige and power
	dynasty["prestige"] = float(dynasty.get("prestige", 0.0)) + float(fam.get("prestige", 0.0)) * 0.5
	dynasty["power"] = float(dynasty.get("power", 0.0)) + float(fam.get("wealth", 0.0)) + float(fam.get("prestige", 0.0))


# ============================================================
# NAME GENERATION
# ============================================================

func _generate_child_name(surname: String) -> String:
	"""Generate a name for a newborn child."""
	var first_names: PackedStringArray = [
		"Kael", "Torvin", "Elara", "Mira", "Bram", "Sera", "Dren", "Lia",
		"Gareth", "Nora", "Finn", "Asha", "Rook", "Iris", "Cade", "Wren",
		"Holt", "Ivy", "Jace", "Lyn", "Orin", "Pia", "Quinn", "Rhea",
		"Silas", "Tess", "Ulric", "Vera", "Wade", "Yara", "Zane", "Ava",
	]
	var idx: int = 0
	if GameManager != null:
		idx = GameManager.tick_count % first_names.size()
	var first: String = first_names[idx]
	return first + " " + surname


func _get_child_surname(mother: Node, father: Node) -> String:
	"""Determine child's surname (typically father's, but can vary)."""
	var father_surname: String = ""
	var mother_surname: String = ""
	if father != null and father.data != null:
		father_surname = str(father.data.get("surname", ""))
	if mother != null and mother.data != null:
		mother_surname = str(mother.data.get("surname", ""))
	if father_surname != "":
		return father_surname
	if mother_surname != "":
		return mother_surname
	# Generate new surname
	return _generate_surname()


func _generate_surname() -> String:
	"""Generate a new surname."""
	var prefix_idx: int = 0
	var suffix_idx: int = 0
	if GameManager != null:
		prefix_idx = GameManager.tick_count % SURNAME_PREFIXES.size()
		suffix_idx = (GameManager.tick_count / SURNAME_PREFIXES.size()) % SURNAME_SUFFIXES.size()
	return SURNAME_PREFIXES[prefix_idx] + SURNAME_SUFFIXES[suffix_idx]


func _generate_motto() -> String:
	"""Generate a dynasty motto."""
	var mottos: PackedStringArray = [
		"Strength in Unity", "Through Fire and Stone", "Ever Forward",
		"Blood and Honor", "The Land Remembers", "Roots Run Deep",
		"By Sword and Shield", "Winter Tests the Strong", "We Endure",
		"From Ashes We Rise", "The River Flows On", "Iron Will",
	]
	var idx: int = 0
	if GameManager != null:
		idx = GameManager.tick_count % mottos.size()
	return mottos[idx]


func _generate_dynasty_color(dynasty_id: int) -> String:
	"""Generate a deterministic color for a dynasty."""
	var colors: PackedStringArray = [
		"#c0392b", "#2980b9", "#27ae60", "#8e44ad", "#d35400",
		"#16a085", "#2c3e50", "#f39c12", "#1abc9c", "#e74c3c",
	]
	return colors[dynasty_id % colors.size()]


# ============================================================
# HELPERS
# ============================================================

func _get_pawn_by_id(pawn_id: int) -> Node:
	"""Get a pawn node by ID."""
	if PawnAccess == null:
		return null
	var pawns: Array = PawnAccess.find_alive_pawns()
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			if int(p.data.id) == pawn_id:
				return p
	return null


# ============================================================
# PUBLIC API
# ============================================================

func get_family_for_pawn(pawn_id: int) -> Dictionary:
	var fid: int = _get_family_for_pawn(pawn_id)
	if fid < 0:
		return {}
	return families.get(fid, {})


func get_dynasty_for_pawn(pawn_id: int) -> Dictionary:
	var fid: int = _get_family_for_pawn(pawn_id)
	if fid < 0:
		return {}
	var fam: Dictionary = families.get(fid, {})
	var did: int = int(fam.get("dynasty_id", -1))
	if did < 0:
		return {}
	return dynasties.get(did, {})


func get_all_families() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fid in families.keys():
		result.append(families[fid])
	return result


func get_all_dynasties() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for did in dynasties.keys():
		result.append(dynasties[did])
	return result


func get_marriages_for_pawn(pawn_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mid in marriages.keys():
		var m: Dictionary = marriages[mid]
		if int(m.get("spouse_a", -1)) == pawn_id or int(m.get("spouse_b", -1)) == pawn_id:
			result.append(m)
	return result


func get_children_of_marriage(marriage_id: int) -> Array[int]:
	var m: Dictionary = marriages.get(marriage_id, {})
	return m.get("children", [])


func get_family_count() -> int:
	return families.size()


func get_dynasty_count() -> int:
	return dynasties.size()


func get_marriage_count() -> int:
	return marriages.size()
