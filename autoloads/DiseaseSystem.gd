extends Node
## DiseaseSystem — Full disease system. Very DF.
##
## Diseases:
## - Plague: spreads through proximity, kills if untreated
## - Infection: from untreated wounds (BodyPartWounds handles this)
## - Food poisoning: from eating contaminated/rotten food
## - Waterborne: from drinking contaminated water
## - Cold/flu: seasonal, mild, spreads in close quarters
## - Wound infection: from untreated body-part wounds
##
## Each disease has:
## - severity (0-100)
## - contagion chance per tick
## - damage per tick
## - duration (ticks until natural recovery or death)
## - treatment (herbs, rest, healer attention)
##
## Quarantine: pawns with disease can be isolated by the settlement.
## Healers treat diseases. Knowledge affects treatment quality.

enum DiseaseType {
	PLAGUE,
	INFECTION,
	FOOD_POISONING,
	WATERBORNE,
	COLD,
	WOUND_INFECTION,
}

const DISEASE_NAMES: Dictionary = {
	DiseaseType.PLAGUE: "plague",
	DiseaseType.INFECTION: "infection",
	DiseaseType.FOOD_POISONING: "food poisoning",
	DiseaseType.WATERBORNE: "waterborne illness",
	DiseaseType.COLD: "cold",
	DiseaseType.WOUND_INFECTION: "wound infection",
}

# Disease parameters: [damage_per_tick, contagion_chance, base_duration, severity_per_tick]
const DISEASE_PARAMS: Dictionary = {
	DiseaseType.PLAGUE: {"damage": 0.15, "contagion": 0.008, "duration": 3000, "severity_rate": 0.05},
	DiseaseType.INFECTION: {"damage": 0.05, "contagion": 0.002, "duration": 1500, "severity_rate": 0.03},
	DiseaseType.FOOD_POISONING: {"damage": 0.08, "contagion": 0.0, "duration": 500, "severity_rate": 0.1},
	DiseaseType.WATERBORNE: {"damage": 0.1, "contagion": 0.003, "duration": 1000, "severity_rate": 0.04},
	DiseaseType.COLD: {"damage": 0.02, "contagion": 0.01, "duration": 800, "severity_rate": 0.02},
	DiseaseType.WOUND_INFECTION: {"damage": 0.06, "contagion": 0.001, "duration": 2000, "severity_rate": 0.03},
}

# Contagion radius (tiles)
const CONTAGION_RADIUS: int = 3

# Treatment effectiveness
const HERB_TREATMENT_REDUCTION: float = 0.5  # 50% severity reduction
const HEALER_TREATMENT_REDUCTION: float = 0.8  # 80% severity reduction
const REST_RECOVERY_BONUS: float = 2.0  # Resting pawns recover 2x faster
const DISEASE_SYSTEM_START_TICK: int = 300  # Avoid first-day disease pressure; let the colony stabilize.

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


## Add a disease to a pawn. Called by DisasterSystem, CataclysmSystem, etc.
func add_disease(pawn_data: RefCounted, disease_type: int, initial_severity: float = 20.0, source: String = "unknown") -> void:
	if pawn_data == null:
		return
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	var allow_early: bool = source.begins_with("cataclysm") or source.begins_with("debug")
	if tick_now < DISEASE_SYSTEM_START_TICK and not allow_early:
		return
	# Initialize disease tracking
	if not pawn_data.get("diseases"):
		pawn_data.set("diseases", {})
	var diseases: Dictionary = pawn_data.diseases
	var disease_key: String = str(disease_type)
	# If already has this disease, increase severity
	if diseases.has(disease_key):
		var existing: Dictionary = diseases[disease_key]
		existing["severity"] = minf(100.0, float(existing.get("severity", 0.0)) + initial_severity * 0.5)
		return
	# New disease
	var params: Dictionary = DISEASE_PARAMS.get(disease_type, {})
	diseases[disease_key] = {
		"type": disease_type,
		"severity": initial_severity,
		"tick_started": tick_now,
		"tick_duration": int(params.get("duration", 1000)),
		"is_treated": false,
		"source": source,
	}
	# Pain from disease
	if pawn_data.get("pain") != null:
		pawn_data.pain = minf(100.0, float(pawn_data.pain) + initial_severity * 0.3)
	# Record disease event
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.INJURY,
		"tick": tick_now,
		"pawn_id": int(pawn_data.id),
		"pawn_name": str(pawn_data.display_name),
		"disease": DISEASE_NAMES.get(disease_type, "unknown"),
		"severity": initial_severity,
		"source": source,
	})


## Remove a disease from a pawn (cured or died).
func remove_disease(pawn_data: RefCounted, disease_type: int) -> void:
	if pawn_data == null:
		return
	var _dis_val = pawn_data.get("diseases")
	var diseases: Dictionary = {} if _dis_val == null else _dis_val
	diseases.erase(str(disease_type))


## Check if a pawn has a specific disease.
func has_disease(pawn_data: RefCounted, disease_type: int) -> bool:
	if pawn_data == null:
		return false
	var _dis2_val = pawn_data.get("diseases")
	var diseases: Dictionary = {} if _dis2_val == null else _dis2_val
	return diseases.has(str(disease_type))


## Get all diseases for a pawn.
func get_diseases(pawn_data: RefCounted) -> Dictionary:
	if pawn_data == null:
		return {}
	var _dis3_val = pawn_data.get("diseases")
	return {} if _dis3_val == null else _dis3_val


## Get total disease severity (affects work speed, movement).
func get_total_disease_severity(pawn_data: RefCounted) -> float:
	if pawn_data == null:
		return 0.0
	var _dis4_val = pawn_data.get("diseases")
	var diseases: Dictionary = {} if _dis4_val == null else _dis4_val
	var total: float = 0.0
	for key in diseases:
		total += float(diseases[key].get("severity", 0.0))
	return minf(100.0, total)


## Get work speed penalty from diseases.
func get_disease_work_penalty(pawn_data: RefCounted) -> float:
	var severity: float = get_total_disease_severity(pawn_data)
	return clampf(severity / 100.0 * 0.5, 0.0, 0.5)  # Up to 50% work penalty


## Get movement penalty from diseases.
func get_disease_move_penalty(pawn_data: RefCounted) -> float:
	var severity: float = get_total_disease_severity(pawn_data)
	return clampf(severity / 100.0 * 0.3, 0.0, 0.3)  # Up to 30% move penalty


## Treat a disease (healer applies herbs/medicine).
func treat_disease(pawn_data: RefCounted, disease_type: int, healer_skill: float = 0.5) -> bool:
	if pawn_data == null:
		return false
	var _dis5_val = pawn_data.get("diseases")
	var diseases: Dictionary = {} if _dis5_val == null else _dis5_val
	var disease_key: String = str(disease_type)
	if not diseases.has(disease_key):
		return false
	var disease: Dictionary = diseases[disease_key]
	disease["is_treated"] = true
	# Reduce severity based on healer skill
	var reduction: float = lerpf(HERB_TREATMENT_REDUCTION, HEALER_TREATMENT_REDUCTION, healer_skill)
	disease["severity"] = maxf(0.0, float(disease.get("severity", 0.0)) * (1.0 - reduction))
	return true


## Process diseases for all pawns every tick.
func _on_game_tick(tick: int) -> void:
	if tick < DISEASE_SYSTEM_START_TICK:
		return
	if tick % 20 != 0:  # Process every 20 ticks
		return
	var pawns: Array = PawnAccess.find_alive_pawns()
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		_process_pawn_diseases(pawn, tick)
	# Spread contagious diseases
	if tick % 100 == 0:
		_spread_diseases(pawns, tick)


func _process_pawn_diseases(pawn: HeelKawnian, tick: int) -> void:
	var data: RefCounted = pawn.data
	var _dis6_val = data.get("diseases")
	var diseases: Dictionary = {} if _dis6_val == null else _dis6_val
	if diseases.is_empty():
		return
	var diseases_to_remove: Array = []
	for disease_key in diseases:
		var disease: Dictionary = diseases[disease_key]
		var disease_type: int = int(disease.get("type", 0))
		var params: Dictionary = DISEASE_PARAMS.get(disease_type, {})
		var severity: float = float(disease.get("severity", 0.0))
		var is_treated: bool = bool(disease.get("is_treated", false))
		var tick_started: int = int(disease.get("tick_started", 0))
		var duration: int = int(disease.get("tick_duration", 1000))
		# Damage from disease
		var damage: float = float(params.get("damage", 0.05)) * 20.0  # Multiply by interval
		if is_treated:
			damage *= 0.3  # Treated diseases do 70% less damage
		data.health = maxf(0.0, float(data.health) - damage)
		# Severity progression
		var severity_rate: float = float(params.get("severity_rate", 0.03)) * 20.0
		if is_treated:
			severity_rate = -0.1 * 20.0  # Treated diseases recover
		elif data.rest > 70.0:
			severity_rate *= -0.5  # Resting helps recover
		severity = clampf(severity + severity_rate, 0.0, 100.0)
		disease["severity"] = severity
		# Check if disease is cured
		if severity <= 0.0:
			diseases_to_remove.append(disease_key)
			WorldMemory.record_event({
				"kind": WorldMemory.Kind.LIFE_EVENT,
				"tick": tick,
				"pawn_id": int(data.id),
				"pawn_name": str(data.display_name),
				"disease_cured": DISEASE_NAMES.get(disease_type, "unknown"),
			})
			continue
		# Check if disease has run its course
		if tick - tick_started > duration:
			diseases_to_remove.append(disease_key)
			continue
		# Death from disease
		if data.health <= 0.0:
			data.set("cause_of_death", "disease: " + DISEASE_NAMES.get(disease_type, "unknown"))
			return
	# Remove cured/expired diseases
	for key in diseases_to_remove:
		diseases.erase(key)


func _spread_diseases(pawns: Array, tick: int) -> void:
	# For each infected pawn, check nearby pawns for contagion
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var dis_val: Variant = pawn.data.get("diseases")
		var diseases: Dictionary = {} if dis_val == null else dis_val
		if diseases.is_empty():
			continue
		for disease_key in diseases:
			var disease: Dictionary = diseases[disease_key]
			if bool(disease.get("is_treated", false)):
				continue  # Treated diseases don't spread
			var disease_type: int = int(disease.get("type", 0))
			var params: Dictionary = DISEASE_PARAMS.get(disease_type, {})
			var contagion_chance: float = float(params.get("contagion", 0.0))
			if contagion_chance <= 0.0:
				continue  # Not contagious
			# Check nearby pawns
			for other in pawns:
				if other == pawn or other == null or not is_instance_valid(other) or other.data == null:
					continue
				var dist: float = pawn.data.tile_pos.distance_to(other.data.tile_pos)
				if dist > CONTAGION_RADIUS:
					continue
				# Roll for contagion
				if WorldRNG.chance_for("disease_spread", contagion_chance, tick + int(pawn.data.id) + int(other.data.id)):
					add_disease(other.data, disease_type, 10.0, "contagion_from_" + str(int(pawn.data.id)))
					break  # Only spread once per pawn per tick


## Get a summary of diseases for UI display.
func get_disease_summary(pawn_data: RefCounted) -> Dictionary:
	if pawn_data == null:
		return {}
	var result: Dictionary = {}
	var _dis7_val = pawn_data.get("diseases")
	var diseases: Dictionary = {} if _dis7_val == null else _dis7_val
	for disease_key in diseases:
		var disease: Dictionary = diseases[disease_key]
		var disease_type: int = int(disease.get("type", 0))
		result[DISEASE_NAMES.get(disease_type, "unknown")] = {
			"severity": float(disease.get("severity", 0.0)),
			"treated": bool(disease.get("is_treated", false)),
			"contagious": float(DISEASE_PARAMS.get(disease_type, {}).get("contagion", 0.0)) > 0.0,
		}
	return result
