extends Node
## CrimeSystem — Theft, assault, murder, and justice.
##
## Crimes emerge from need and opportunity:
## - Theft: hungry/desperate pawn steals from stockpile or another pawn
## - Assault: pawn attacks another over a grudge
## - Murder: assault that kills
##
## Justice system:
## - Witnesses report crimes to settlement
## - Guards investigate and apprehend
## - Trial: governor or elder decides punishment
## - Punishments: fine (stockpile), exile, imprisonment, execution
##
## All crimes recorded in WorldMemory. Grudges form from crimes.
## Reputation is affected by criminal record.

enum CrimeType {
	THEFT,
	ASSAULT,
	MURDER,
	TRESPASS,
	VANDALISM,
}

const CRIME_NAMES: Dictionary = {
	CrimeType.THEFT: "theft",
	CrimeType.ASSAULT: "assault",
	CrimeType.MURDER: "murder",
	CrimeType.TRESPASS: "trespass",
	CrimeType.VANDALISM: "vandalism",
}

const CRIME_SEVERITY: Dictionary = {
	CrimeType.THEFT: 1,
	CrimeType.ASSAULT: 2,
	CrimeType.MURDER: 5,
	CrimeType.TRESPASS: 1,
	CrimeType.VANDALISM: 1,
}

enum PunishmentType {
	FINE,
	EXILE,
	IMPRISONMENT,
	EXECUTION,
}

const PUNISHMENT_NAMES: Dictionary = {
	PunishmentType.FINE: "fine",
	PunishmentType.EXILE: "exile",
	PunishmentType.IMPRISONMENT: "imprisonment",
	PunishmentType.EXECUTION: "execution",
}

# Crime tracking: pawn_id -> array of crime records
var _criminal_records: Dictionary = {}

# Active investigations: settlement_id -> array of unsolved crimes
var _investigations: Dictionary = {}

# Imprisoned pawns: pawn_id -> {settlement_id, tick_imprisoned, duration, crime}
var _imprisoned: Dictionary = {}

# How often crime checks run
const CRIME_CHECK_INTERVAL: int = 500
const JUSTICE_INTERVAL: int = 1000

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


## Record a crime. Called when a pawn commits a crime.
func record_crime(criminal_id: int, crime_type: int, victim_id: int = -1, settlement_id: int = -1, details: Dictionary = {}) -> void:
	var crime: Dictionary = {
		"criminal_id": criminal_id,
		"crime_type": crime_type,
		"crime_name": CRIME_NAMES.get(crime_type, "unknown"),
		"severity": CRIME_SEVERITY.get(crime_type, 1),
		"victim_id": victim_id,
		"settlement_id": settlement_id,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"witnesses": details.get("witnesses", []),
		"location": details.get("location", {}),
		"is_solved": false,
	}
	# Add to criminal record
	if not _criminal_records.has(criminal_id):
		_criminal_records[criminal_id] = []
	_criminal_records[criminal_id].append(crime)
	# Add to investigation queue
	if settlement_id >= 0:
		if not _investigations.has(settlement_id):
			_investigations[settlement_id] = []
		_investigations[settlement_id].append(crime)
	# Record to WorldMemory
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.INJURY,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": criminal_id,
		"crime": CRIME_NAMES.get(crime_type, "unknown"),
		"victim_id": victim_id,
		"settlement_id": settlement_id,
	})
	# Create grudge from victim toward criminal
	if victim_id >= 0:
		SocialManager.record_grudge(victim_id, criminal_id, CRIME_NAMES.get(crime_type, "crime"), CRIME_SEVERITY.get(crime_type, 1))


## Recent crime on record (for community law checks).
func has_recent_crime(pawn_id: int, crime_name: String, max_age_ticks: int = 600) -> bool:
	if pawn_id < 0 or not _criminal_records.has(pawn_id):
		return false
	var now_tick: int = GameManager.tick_count if GameManager != null else 0
	var want: String = crime_name.to_lower()
	for crime_any in _criminal_records[pawn_id]:
		if crime_any is not Dictionary:
			continue
		var crime: Dictionary = crime_any as Dictionary
		if str(crime.get("crime_name", "")).to_lower() != want:
			continue
		var age: int = now_tick - int(crime.get("tick", 0))
		if age >= 0 and age <= max_age_ticks:
			return true
	return false


## Get criminal record for a pawn.
func get_criminal_record(pawn_id: int) -> Array:
	return _criminal_records.get(pawn_id, [])


## Get total crime severity for a pawn (affects reputation).
func get_criminal_severity(pawn_id: int) -> int:
	var records: Array = _criminal_records.get(pawn_id, [])
	var total: int = 0
	for crime in records:
		total += int(crime.get("severity", 1))
	return total


## Is a pawn imprisoned?
func is_imprisoned(pawn_id: int) -> bool:
	return _imprisoned.has(pawn_id)


## Get imprisonment info for a pawn.
func get_imprisonment(pawn_id: int) -> Dictionary:
	return _imprisoned.get(pawn_id, {})


## Imprison a pawn.
func imprison(pawn_id: int, settlement_id: int, duration: int, crime: String = "") -> void:
	_imprisoned[pawn_id] = {
		"settlement_id": settlement_id,
		"tick_imprisoned": GameManager.tick_count if GameManager != null else 0,
		"duration": duration,
		"crime": crime,
	}
	# Record to WorldMemory
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": pawn_id,
		"imprisoned": true,
		"crime": crime,
		"duration": duration,
	})


## Release a pawn from prison.
func release(pawn_id: int) -> void:
	if not _imprisoned.has(pawn_id):
		return
	var info: Dictionary = _imprisoned[pawn_id]
	_imprisoned.erase(pawn_id)
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"pawn_id": pawn_id,
		"released": true,
		"crime": info.get("crime", ""),
	})


## Process crime and justice on tick.
func _on_game_tick(tick: int) -> void:
	# Crime opportunity checks
	if tick % CRIME_CHECK_INTERVAL == 0:
		_check_crime_opportunities(tick)
	# Justice processing
	if tick % JUSTICE_INTERVAL == 0:
		_process_justice(tick)
		_process_imprisonment(tick)


## Check if any pawns are driven to crime by need.
func _check_crime_opportunities(tick: int) -> void:
	var pawns: Array = PawnAccess.find_alive_pawns()
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		if is_imprisoned(int(pawn.data.id)):
			continue
		# Theft: hungry/desperate pawns may steal
		if pawn.data.hunger <= 15.0:  # Very hungry
			if WorldRNG.chance_for(&"crime_theft", 0.05, tick + int(pawn.data.id)):
				_commit_theft(pawn, tick)
				continue
		# Assault: pawns with strong grudges may attack
		var grudge_level: float = SocialManager.get_highest_grudge_level(int(pawn.data.id))
		if grudge_level > 0.7:
				if WorldRNG.chance_for(&"crime_assault", 0.02, tick + int(pawn.data.id)):
					_commit_assault(pawn, tick)
					continue


func _commit_theft(pawn: HeelKawnian, tick: int) -> void:
	# Find nearest stockpile with food
	var sp: Stockpile = StockpileManager.find_food_source(pawn.data.tile_pos)
	if sp == null:
		return
	# Take food from stockpile
	if sp.has_any_food():
		var item_type: int = sp.take_any_food()
		if item_type >= 0:
			pawn.data.carrying = item_type
			pawn.data.carrying_count = 1
			# Find witnesses (pawns within 5 tiles)
			var witnesses: Array = _find_witnesses(pawn, 5)
			var settlement_id: int = SettlementMemory.get_settlement_id_for_pawn(int(pawn.data.id)) if SettlementMemory != null else -1
			record_crime(int(pawn.data.id), CrimeType.THEFT, -1, settlement_id, {
				"witnesses": witnesses,
				"location": {"x": int(pawn.data.tile_pos.x), "y": int(pawn.data.tile_pos.y)},
			})
			# Mood: guilt or defiance
			pawn.data.add_mood_event(MoodEvent.Type.STRESS, 30.0, 200)


func _commit_assault(pawn: HeelKawnian, tick: int) -> void:
	# Find the target of the strongest grudge
	var target_id: int = SocialManager.get_grudge_target(int(pawn.data.id))
	if target_id < 0:
		return
	# Find the target pawn
	var target: HeelKawnian = _find_pawn_by_id(target_id)
	if target == null or not is_instance_valid(target):
		return
	# Must be within 5 tiles
	if pawn.data.tile_pos.distance_to(target.data.tile_pos) > 5:
		return
	# Attack!
	CombatResolver.resolve_attack(pawn, target)
	var witnesses: Array = _find_witnesses(pawn, 8)
	var settlement_id: int = SettlementMemory.get_settlement_id_for_pawn(int(pawn.data.id)) if SettlementMemory != null else -1
	var crime_type: int = CrimeType.MURDER if target.data.health <= 0.0 else CrimeType.ASSAULT
	record_crime(int(pawn.data.id), crime_type, target_id, settlement_id, {
		"witnesses": witnesses,
		"location": {"x": int(pawn.data.tile_pos.x), "y": int(pawn.data.tile_pos.y)},
	})


## Process justice: investigate crimes and punish criminals.
func _process_justice(tick: int) -> void:
	for settlement_id in _investigations:
		var crimes: Array = _investigations[settlement_id]
		var solved: Array = []
		for i in range(crimes.size()):
			var crime: Dictionary = crimes[i]
			if bool(crime.get("is_solved", false)):
				continue
			# If there are witnesses, the crime can be solved
			var witnesses: Array = crime.get("witnesses", [])
			if not witnesses.is_empty():
				crime["is_solved"] = true
				solved.append(i)
				# Determine punishment
				var criminal_id: int = int(crime.get("criminal_id", -1))
				var severity: int = int(crime.get("severity", 1))
				_determine_punishment(criminal_id, severity, settlement_id, tick)
		# Remove solved crimes (reverse order)
		for i in range(solved.size() - 1, -1, -1):
			crimes.remove_at(solved[i])


func _determine_punishment(criminal_id: int, severity: int, settlement_id: int, tick: int) -> void:
	var punishment: int
	var duration: int = 0
	match severity:
		1:  # Minor crime
			punishment = PunishmentType.FINE
		2:  # Moderate crime
			punishment = PunishmentType.IMPRISONMENT
			duration = 2000  # ~40 seconds at 1x
		3, 4:  # Serious crime
			punishment = PunishmentType.IMPRISONMENT
			duration = 5000  # ~100 seconds at 1x
		5, _:  # Murder
			punishment = PunishmentType.EXECUTION
	# Apply punishment
	match punishment:
		PunishmentType.FINE:
			# Fine: take some items from the criminal
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.LIFE_EVENT,
				"tick": tick,
				"pawn_id": criminal_id,
				"punishment": "fined",
				"crime": CRIME_NAMES.get(int(_criminal_records.get(criminal_id, [{}])[-1].get("crime_type", 0)), "unknown"),
			})
		PunishmentType.IMPRISONMENT:
			imprison(criminal_id, settlement_id, duration)
		PunishmentType.EXECUTION:
			# Find the pawn and kill it
			var pawn: HeelKawnian = _find_pawn_by_id(criminal_id)
			if pawn != null and is_instance_valid(pawn):
				pawn.data.health = 0.0
				pawn.data.is_dead = true
				pawn.data.cause_of_death = "execution"
				WorldMemory.record_event({
					"kind": WorldMemory.Kind.LIFE_EVENT,
					"tick": tick,
					"pawn_id": criminal_id,
					"punishment": "executed",
					"crime": CRIME_NAMES.get(int(_criminal_records.get(criminal_id, [{}])[-1].get("crime_type", 0)), "unknown"),
				})
		PunishmentType.EXILE:
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.LIFE_EVENT,
				"tick": tick,
				"pawn_id": criminal_id,
				"punishment": "exiled",
			})


## Process imprisonment: release prisoners who served their time.
func _process_imprisonment(tick: int) -> void:
	var to_release: Array = []
	for pawn_id in _imprisoned:
		var info: Dictionary = _imprisoned[pawn_id]
		var tick_imprisoned: int = int(info.get("tick_imprisoned", 0))
		var duration: int = int(info.get("duration", 0))
		if tick - tick_imprisoned >= duration:
			to_release.append(pawn_id)
	for pawn_id in to_release:
		release(pawn_id)


## Find witnesses (pawns within radius who can see the crime).
func _find_witnesses(pawn: HeelKawnian, radius: int) -> Array:
	var witnesses: Array = []
	var all_pawns: Array = PawnAccess.find_alive_pawns()
	for other in all_pawns:
		if other == pawn or other == null or not is_instance_valid(other) or other.data == null:
			continue
		if pawn.data.tile_pos.distance_to(other.data.tile_pos) <= float(radius):
			# 60% chance of actually noticing the crime
			if WorldRNG.chance_for(&"witness_notice", 0.6, GameManager.tick_count + int(other.data.id)):
				witnesses.append(int(other.data.id))
	return witnesses


func _find_pawn_by_id(pawn_id: int) -> HeelKawnian:
	var all_pawns: Array = PawnAccess.find_alive_pawns()
	for pawn in all_pawns:
		if pawn != null and is_instance_valid(pawn) and pawn.data != null and int(pawn.data.id) == pawn_id:
			return pawn
	return null
