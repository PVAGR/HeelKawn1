extends Node
## NameGenerator - Cultural naming customs
##
## Features:
## - Culturally-appropriate names
## - Family naming traditions
## - Naming based on circumstances
## - Historical naming patterns

# Cultural name pools
var cultural_names: Dictionary = {
	"northern": {
		"male": ["Aldric", "Bjorn", "Cormac", "Dvalin", "Erik", "Fenric", "Garrick", "Halfdan", "Ivar", "Jarl"],
		"female": ["Astrid", "Brynhild", "Ceridwen", "Dagny", "Eira", "Freya", "Gudrun", "Helga", "Ingrid", "Jora"],
		"surname_prefix": ["Ice", "Frost", "Snow", "Winter", "North", "Steel", "Iron", "Stone"],
		"surname_suffix": ["son", "dottir", "born", "heart", "hand", "walker"]
	},
	"southern": {
		"male": ["Marcus", "Lucius", "Titus", "Gaius", "Flavius", "Cassius", "Septimus", "Valerius", "Antonius", "Fabius"],
		"female": ["Livia", "Claudia", "Aurelia", "Sabina", "Julia", "Octavia", "Drusa", "Marcia", "Rufina", "Valeria"],
		"surname_prefix": ["Aur", "Val", "Mar", "Luc", "Fab", "Cor", "Flav", "Sept"],
		"surname_suffix": ["ius", "ius", "anus", "inus", "illus", "acus"]
	},
	"eastern": {
		"male": ["Kenji", "Takeshi", "Hiroshi", "Yuki", "Akira", "Satoshi", "Noboru", "Kazuki", "Ryu", "Daichi"],
		"female": ["Sakura", "Yuki", "Akiko", "Emiko", "Haruki", "Michiko", "Naomi", "Reiko", "Tomoko", "Yoko"],
		"surname_prefix": ["Yama", "Kawa", "Mori", "Hana", "Sato", "Taka", "Naka"],
		"surname_suffix": ["moto", "uchi", "da", "oka", "shima", "no"]
	},
	"western": {
		"male": ["Arthur", "Bedivere", "Caius", "Derek", "Edric", "Felix", "Gareth", "Hector", "Ivor", "Lancelot"],
		"female": ["Guinevere", "Morgana", "Elaine", "Iseult", "Viviane", "Rowena", "Cordelia", "Beatrice", "Rosamund", "Sibyl"],
		"surname_prefix": ["Ash", "Black", "Bright", "Fair", "Good", "High", "Long", "Short"],
		"surname_suffix": ["wood", "field", "brook", "stone", "hall", "ford", "wick"]
	},
	"common": {
		"male": ["John", "James", "Robert", "William", "Thomas", "Richard", "Henry", "Edward", "George", "Charles"],
		"female": ["Mary", "Elizabeth", "Jane", "Anne", "Margaret", "Alice", "Catherine", "Sarah", "Emma", "Rose"],
		"surname_prefix": ["Smith", "Baker", "Miller", "Fisher", "Hunter", "Taylor", "Walker", "Wright"],
		"surname_suffix": ["man", "son", "er", "ford", "ton", "ville"]
	}
}

# Circumstantial name components
var circumstantial_names: Dictionary = {
	"traits": {
		"strong": ["Strong", "Mighty", "Powerful", "Stout"],
		"weak": ["Frail", "Delicate", "Slim"],
		"brave": ["Brave", "Bold", "Fearless", "Valiant"],
		"wise": ["Wise", "Sage", "Cunning", "Shrewd"],
		"kind": ["Kind", "Gentle", "Merciful"],
		"cruel": ["Cruel", "Ruthless", "Merciless"]
	},
	"professions": {
		"builder": ["Builder", "Mason", "Carpenter"],
		"warrior": ["Warrior", "Swordsman", "Shield"],
		"farmer": ["Farmer", "Plow", "Harvest"],
		"scholar": ["Scholar", "Scribe", "Lore"],
		"trader": ["Trader", "Merchant", "Market"],
		"smith": ["Smith", "Forge", "Anvil"],
		"healer": ["Healer", "Herb", "Salve"]
	},
	"events": {
		"battle_survivor": ["Survivor", "Lucky", "Scarred"],
		"first_born": ["First", "Eldest", "Prime"],
		"last_born": ["Last", "Youngest", "Final"],
		"twin": ["Twin", "Double", "Second"]
	}
}

# Name history (to avoid duplicates)
var _name_history: Array[String] = []
const MAX_NAME_HISTORY: int = 500


func _ready() -> void:
	# Seed random number generator
	randomize()


# ==================== NAME GENERATION ====================

## Generate a full name for a pawn
func generate_full_name(pawn_id: int, culture: String = "common", 
 gender: int = 0, circumstances: Dictionary = {}) -> String:
	
	var given_name: String = generate_given_name(culture, gender)
	var surname: String = generate_surname(pawn_id, culture, circumstances)
	
	var full_name: String
	if surname != "":
		full_name = "%s %s" % [given_name, surname]
	else:
		full_name = given_name
	
	# Add to history
	_add_to_history(full_name)
	
	return full_name


## Generate given name (first name)
func generate_given_name(culture: String = "common", gender: int = 0) -> String:
	if not cultural_names.has(culture):
		culture = "common"
	
	var culture_data: Dictionary = cultural_names[culture]
	var name_pool: Array[String]
	
	if gender == 0:  # Male
		name_pool = culture_data.male.duplicate()
	else:  # Female
		name_pool = culture_data.female.duplicate()
	
	if name_pool.size() == 0:
		return "Unknown"
	
	# Deterministic selection based on tick count
	var index: int = randi() % name_pool.size()
	return name_pool[index]


## Generate surname (family name)
func generate_surname(pawn_id: int, culture: String = "common", 
 circumstances: Dictionary = {}) -> String:
	
	if not cultural_names.has(culture):
		culture = "common"
	
	var culture_data: Dictionary = cultural_names[culture]
	
	# Check for family name from bloodline
	var bloodline_name: String = _get_bloodline_name(pawn_id)
	if bloodline_name != "":
		return bloodline_name
	
	# Generate from culture
	var prefix_pool: Array[String] = culture_data.surname_prefix.duplicate()
	var suffix_pool: Array[String] = culture_data.surname_suffix.duplicate()
	
	if prefix_pool.size() == 0 or suffix_pool.size() == 0:
		return ""
	
	var prefix: String = prefix_pool[randi() % prefix_pool.size()]
	var suffix: String = suffix_pool[randi() % suffix_pool.size()]
	
	return prefix + suffix


## Generate nickname based on circumstances
func generate_nickname(pawn_id: int, circumstances: Dictionary = {}) -> String:
	var nicknames: PackedStringArray = []

	# Add trait-based nicknames
	if circumstances.has("traits"):
		var traits_array: Array = circumstances.traits
		var i: int = 0
		while i < traits_array.size():
			var t: String = traits_array[i]
			if circumstantial_names.traits.has(t):
				var pool: Array = circumstantial_names.traits[t]
				nicknames.append(pool[randi() % pool.size()])
			i += 1

	# Add profession-based nickname
	if circumstances.has("profession"):
		var prof: String = circumstances.profession
		if circumstantial_names.professions.has(prof):
			var pool: Array = circumstantial_names.professions[prof]
			nicknames.append(pool[randi() % pool.size()])

	# Add event-based nickname
	if circumstances.has("events"):
		var events_array: Array = circumstances.events
		var j: int = 0
		while j < events_array.size():
			var event: String = events_array[j]
			if circumstantial_names.events.has(event):
				var pool: Array = circumstantial_names.events[event]
				nicknames.append(pool[randi() % pool.size()])
			j += 1

	if nicknames.size() == 0:
		return ""

	# Return first nickname (could combine multiple)
	return "The " + nicknames[0]


# ==================== CULTURAL NAMES ====================

## Get names appropriate for a culture
func get_cultural_names(culture: String, gender: int = 0) -> Array[String]:
	if not cultural_names.has(culture):
		culture = "common"
	
	var culture_data: Dictionary = cultural_names[culture]
	
	if gender == 0:
		return culture_data.male.duplicate()
	else:
		return culture_data.female.duplicate()


## Add new cultural name pool
func add_cultural_names(culture: String, male_names: Array[String], 
 female_names: Array[String], surname_prefix: Array[String], 
 surname_suffix: Array[String]) -> void:
	
	cultural_names[culture] = {
		"male": male_names,
		"female": female_names,
		"surname_prefix": surname_prefix,
		"surname_suffix": surname_suffix
	}


# ==================== FAMILY NAMING ====================

func _get_bloodline_name(pawn_id: int) -> String:
	var bloodline_sys: Node = get_node_or_null("/root/BloodlineSystem")
	if bloodline_sys == null or not bloodline_sys.has_method("get_pawn_bloodline"):
		return ""
	
	var bloodline: Dictionary = bloodline_sys.call("get_pawn_bloodline", pawn_id)
	if bloodline.is_empty():
		return ""
	
	return bloodline.get("name", "")


## Generate child name following family traditions
func generate_child_name(father_id: int, mother_id: int, gender: int = 0) -> String:
	# Get family names
	var father_bloodline: String = _get_bloodline_name(father_id)
	var mother_bloodline: String = _get_bloodline_name(mother_id)
	
	# Get cultures
	var father_culture: String = _get_culture(father_id)
	var mother_culture: String = _get_culture(mother_id)
	
	# Child typically takes father's culture and bloodline
	var culture: String = father_culture if father_culture != "" else "common"
	var given_name: String = generate_given_name(culture, gender)
	
	# Combine with bloodline name
	if father_bloodline != "":
		return "%s of %s" % [given_name, father_bloodline]
	elif mother_bloodline != "":
		return "%s of %s" % [given_name, mother_bloodline]
	else:
		return given_name


func _get_culture(pawn_id: int) -> String:
	# Try to get pawn's culture from pawn data
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner == null or not pawn_spawner.has_method("pawn_data_for_id"):
		return "common"
	
	var data: Node = pawn_spawner.call("pawn_data_for_id", pawn_id)
	if data == null or not data.has_method("get_culture"):
		return "common"
	
	var culture: String = str(data.get("culture", "common"))
	if culture.is_empty(): culture = "common"
	return culture


# ==================== UTILITY ====================

func _add_to_history(name: String) -> void:
	_name_history.append(name)
	
	# Trim history
	while _name_history.size() > MAX_NAME_HISTORY:
		_name_history.pop_front()


## Check if name is already used
func is_name_used(name: String) -> bool:
	return _name_history.has(name)


## Get name history
func get_name_history(limit: int = 10) -> Array[String]:
	var start: int = max(0, _name_history.size() - limit)
	return _name_history.slice(start)


## Clear name history (for world reroll)
func clear_history() -> void:
	_name_history.clear()


# ==================== PUBLIC API ====================

## Generate name for a specific pawn
func generate_name_for_pawn(pawn_id: int, culture: String = "common", 
 gender: int = 0, with_nickname: bool = false) -> String:
	
	var circumstances: Dictionary = {}
	
	# Get pawn circumstances
	var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if pawn_spawner != null and pawn_spawner.has_method("pawn_data_for_id"):
		var data: Node = pawn_spawner.call("pawn_data_for_id", pawn_id)
		if data != null:
			if data.has_method("get_profession"):
				circumstances.profession = data.get("profession") ?? ""
			if data.has_method("get_traits"):
				circumstances.traits = data.get("traits") ?? []
	
	var full_name: String = generate_full_name(pawn_id, culture, gender, circumstances)
	
	if with_nickname:
		var nickname: String = generate_nickname(pawn_id, circumstances)
		if nickname != "":
			full_name = "%s, %s" % [full_name, nickname]
	
	return full_name

## Clear all data (for world reroll)
func clear() -> void:
	clear_history()

## Get statistics
func get_stats() -> Dictionary:
	return {
		"cultures": cultural_names.keys(),
		"names_in_history": _name_history.size()
	}
