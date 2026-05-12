extends Node

## MythAge — 7 mythological ages layered on top of technical civilization stages.
## HeelKawnians discover and name these ages through lived experience.
## Ages are irreversible — once discovered, the world remembers.
## Technical stages (Primitive → Post-Scarcity) drive AI logic.
## Myth ages drive narrative identity and player-facing experience.

signal age_discovered(age_index: int, age_name: String, age_description: String)

enum Age {
	AWAKENING,     # Score 0-10: First fire, first shelter
	SETTLEMENT,    # Score 10-25: First farms, first walls
	CRAFT,         # Score 25-40: Specialization, workshops, trade
	IRON,          # Score 40-55: Metal, roads, institutions
	KNOWLEDGE,     # Score 55-70: Libraries, scholarship, enchantment
	AMBITION,      # Score 70-85: Nations, war, great works
	MYTH,          # Score 85+: Legends walk, enchantments reshape reality
}

const AGE_NAMES: Dictionary = {
	Age.AWAKENING: "Age of Awakening",
	Age.SETTLEMENT: "Age of Settlement",
	Age.CRAFT: "Age of Craft",
	Age.IRON: "Age of Iron",
	Age.KNOWLEDGE: "Age of Knowledge",
	Age.AMBITION: "Age of Ambition",
	Age.MYTH: "Age of Myth",
}

const AGE_DESCRIPTIONS: Dictionary = {
	Age.AWAKENING: "The world was new and we were small.",
	Age.SETTLEMENT: "We found our place and made it home.",
	Age.CRAFT: "Our hands learned what our minds imagined.",
	Age.IRON: "We bent the earth to our will.",
	Age.KNOWLEDGE: "We wrote our names on the world.",
	Age.AMBITION: "We reached for what was beyond our grasp.",
	Age.MYTH: "We became the stories we told.",
}

const AGE_THRESHOLDS: Dictionary = {
	Age.AWAKENING: 0,
	Age.SETTLEMENT: 10,
	Age.CRAFT: 25,
	Age.IRON: 40,
	Age.KNOWLEDGE: 55,
	Age.AMBITION: 70,
	Age.MYTH: 85,
}

## Minimum number of active settlements required for each age
const AGE_MIN_SETTLEMENTS: Dictionary = {
	Age.AWAKENING: 0,
	Age.SETTLEMENT: 1,
	Age.CRAFT: 1,
	Age.IRON: 2,
	Age.KNOWLEDGE: 2,
	Age.AMBITION: 3,
	Age.MYTH: 3,
}

## Current highest discovered age
var current_age: int = -1  # -1 = no age discovered yet
## All discovered ages (irreversible)
var discovered_ages: Dictionary = {}
## Custom names set by dominant settlement culture
var custom_age_names: Dictionary = {}
## When each age was discovered (tick)
var age_discovery_ticks: Dictionary = {}

## Check interval in ticks (not every tick)
const CHECK_INTERVAL: int = 50
var _check_accum: int = 0


func _ready() -> void:
	# Initialize with no ages discovered
	current_age = -1
	discovered_ages = {}
	custom_age_names = {}
	age_discovery_ticks = {}


func _process(_delta: float) -> void:
	if GameManager == null:
		return
	_check_accum += 1
	if _check_accum < CHECK_INTERVAL:
		return
	_check_accum = 0
	_check_age_progression()


func _check_age_progression() -> void:
	if CivilizationStage == null:
		return
	var score: int = CivilizationStage.get_world_score()
	var active_settlements: int = _count_active_settlements()

	# Check each age in order
	for age_idx in range(7):
		if discovered_ages.has(age_idx):
			continue  # Already discovered
		var threshold: int = int(AGE_THRESHOLDS.get(age_idx, 999))
		var min_settlements: int = int(AGE_MIN_SETTLEMENTS.get(age_idx, 0))
		if score >= threshold and active_settlements >= min_settlements:
			_discover_age(age_idx)


func _count_active_settlements() -> int:
	if SettlementMemory == null:
		return 0
	var count: int = 0
	var settlements: Array = SettlementMemory.get_formal_settlements()
	for st in settlements:
		if st is Dictionary:
			var state: String = str((st as Dictionary).get("state", ""))
			if state == "active" or state == "reviving" or state == "recovering":
				var pop: int = int((st as Dictionary).get("population", 0))
				if pop >= 2:
					count += 1
	return count


func _discover_age(age_idx: int) -> void:
	discovered_ages[age_idx] = true
	age_discovery_ticks[age_idx] = GameManager.tick_count if GameManager != null else 0
	current_age = age_idx

	var age_name: String = get_age_name(age_idx)
	var age_desc: String = str(AGE_DESCRIPTIONS.get(age_idx, ""))

	# Record world event
	if WorldMemory != null:
		WorldMemory.record_event({
			"type": "age_discovered",
			"age_index": age_idx,
			"age_name": age_name,
			"age_description": age_desc,
			"tick": GameManager.tick_count if GameManager != null else 0,
		})

	# Signal
	age_discovered.emit(age_idx, age_name, age_desc)

	# Print to console for debugging
	print("[MythAge] The HeelKawnians have entered the %s" % age_name)


## Get the display name for an age (custom or default)
func get_age_name(age_idx: int) -> String:
	if custom_age_names.has(age_idx):
		return str(custom_age_names[age_idx])
	return str(AGE_NAMES.get(age_idx, "Unknown Age"))


## Get the current age display name (or "—" if none discovered)
func get_current_age_name() -> String:
	if current_age < 0:
		return "—"
	return get_age_name(current_age)


## Get the current age description (or empty if none)
func get_current_age_description() -> String:
	if current_age < 0:
		return ""
	return str(AGE_DESCRIPTIONS.get(current_age, ""))


## Get the age index for a given civilization score
func age_for_score(score: int) -> int:
	var result: int = -1
	for age_idx in range(7):
		var threshold: int = int(AGE_THRESHOLDS.get(age_idx, 999))
		if score >= threshold:
			result = age_idx
	return result


## Set a custom name for an age (called by settlement culture)
func set_custom_age_name(age_idx: int, custom_name: String) -> void:
	custom_age_names[age_idx] = custom_name


## Get the next undiscovered age (or -1 if all discovered)
func next_undiscovered_age() -> int:
	for age_idx in range(7):
		if not discovered_ages.has(age_idx):
			return age_idx
	return -1


## Get the score threshold for the next undiscovered age
func next_age_threshold() -> int:
	var next: int = next_undiscovered_age()
	if next < 0:
		return -1
	return int(AGE_THRESHOLDS.get(next, 999))


## Serialize for save
func to_save_dict() -> Dictionary:
	return {
		"current_age": current_age,
		"discovered_ages": discovered_ages.duplicate(true),
		"custom_age_names": custom_age_names.duplicate(true),
		"age_discovery_ticks": age_discovery_ticks.duplicate(true),
	}


## Deserialize from save
func from_save_dict(d: Dictionary) -> void:
	current_age = int(d.get("current_age", -1))
	discovered_ages = {}
	if d.has("discovered_ages") and d["discovered_ages"] is Dictionary:
		for k in d["discovered_ages"]:
			discovered_ages[int(k)] = true
	custom_age_names = {}
	if d.has("custom_age_names") and d["custom_age_names"] is Dictionary:
		for k in d["custom_age_names"]:
			custom_age_names[int(k)] = str(d["custom_age_names"][k])
	age_discovery_ticks = {}
	if d.has("age_discovery_ticks") and d["age_discovery_ticks"] is Dictionary:
		for k in d["age_discovery_ticks"]:
			age_discovery_ticks[int(k)] = int(d["age_discovery_ticks"][k])
