extends Node

## BodyRiskManager — manages pawn injuries, infection, recovery, and body risk.
##
## Injury types:
## - cut: from mining, chopping, combat; can infect
## - burn: from fire pit work, cooking accidents
## - blunt: from falls, combat, collapsing walls
## - broken_bone: severe impact; immobilizes pawn
## - frostbite: prolonged cold exposure without fire/shelter
## - infection: secondary complication from untreated cuts
##
## Recovery:
## - Cuts heal over time; infection risk if no healer nearby
## - Broken bones immobilize pawn until healed
## - Burns reduce work efficiency during recovery
## - Frostbite causes permanent mobility reduction if severe

enum InjuryType { CUT, BURN, BLUNT, BROKEN_BONE, FROSTBITE, INFECTION }

const INFECTION_CHANCE_PER_TICK: float = 0.0001  # Base chance per tick for untreated cuts
const HEALER_INFECTION_REDUCTION: float = 0.7    # Healers reduce infection chance by 70%

const RECOVERY_RATES: Dictionary = {
	InjuryType.CUT:          0.05,   # severity points per tick
	InjuryType.BURN:         0.03,   # burns heal slower
	InjuryType.BLUNT:        0.04,
	InjuryType.BROKEN_BONE:  0.01,   # very slow recovery
	InjuryType.FROSTBITE:    0.02,
	InjuryType.INFECTION:    0.02,   # infection needs treatment
}

## Throttle injury event recording — don't spam WorldMemory with identical events.
## Key: pawn_id, Value: last injury tick
var _last_injury_event_tick: Dictionary = {}
const INJURY_EVENT_THROTTLE_TICKS: int = 60  # Only record one injury per pawn per 60 ticks

const MOBILITY_PENALTIES: Dictionary = {
	InjuryType.CUT:          0.0,   # minor cut doesn't slow you
	InjuryType.BURN:         0.15,  # burns reduce mobility
	InjuryType.BLUNT:        0.1,
	InjuryType.BROKEN_BONE:  0.8,   # can barely move
	InjuryType.FROSTBITE:    0.3,
	InjuryType.INFECTION:    0.25,  # fever weakens
}

const WORK_EFFICIENCY_PENALTIES: Dictionary = {
	InjuryType.CUT:          0.05,
	InjuryType.BURN:         0.25,
	InjuryType.BLUNT:        0.15,
	InjuryType.BROKEN_BONE:  0.9,   # can't work effectively
	InjuryType.FROSTBITE:    0.2,
	InjuryType.INFECTION:    0.35,
}


func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(_tick: int) -> void:
	# Process injury recovery and infection for all pawns
	if GameManager.tick_count % 10 == 0:
		_tick_pawn_injuries()


## Apply an injury to a pawn.
func apply_injury(pawn: Node, injury_type: int, severity: float, source: String = "unknown") -> void:
	var pd = pawn.get_pawn_data()
	if pd == null:
		return
	
	var type_name: String = _injury_name(injury_type)
	
	# Stack with existing injury of same type
	var existing: float = float(pd.injuries.get(type_name, 0.0))
	var new_severity: float = minf(existing + severity, 100.0)
	pd.injuries[type_name] = new_severity
	
	# Cut injuries can become infected
	if injury_type == InjuryType.CUT and new_severity > 30.0:
		# Check if there's a healer nearby
		var has_healer: bool = _has_healer_nearby(pawn)
		var infection_salt: int = _infection_roll_salt(pd, type_name, new_severity, source)
		if not has_healer and WorldRNG.chance_for(&"body_risk:cut_infection", INFECTION_CHANCE_PER_TICK * 10, infection_salt):
			apply_injury(pawn, InjuryType.INFECTION, 20.0, "untreated_cut")
	
	# Update pain based on total injury severity
	_recalculate_pain(pd)
	
	# Throttle injury event recording — don't spam WorldMemory
	var pawn_id: int = int(pd.id)
	var tick_now: int = GameManager.tick_count
	var last_tick: int = _last_injury_event_tick.get(pawn_id, -INJURY_EVENT_THROTTLE_TICKS)
	if tick_now - last_tick >= INJURY_EVENT_THROTTLE_TICKS:
		_last_injury_event_tick[pawn_id] = tick_now
		WorldMemory.record_event({
			"type": "injury",
			"pawn_id": pawn_id,
			"pawn_name": pd.display_name,
			"injury_type": type_name,
			"severity": int(new_severity),
			"source": source,
			"tick": tick_now,
			"tile": {"x": pd.tile_pos.x, "y": pd.tile_pos.y},
		})
	
	if GameManager.verbose_logs():
		print("[BodyRisk] %s suffered %s (severity=%.0f, source=%s)" % [
			pd.display_name, type_name, new_severity, source
		])


## Tick all pawn injuries: recover, check for complications.
func _tick_pawn_injuries() -> void:
	var pawns: Array[HeelKawnian] = PawnSpawner.find_pawns()
	for p in pawns:
		_tick_pawn_injury_recovery(p)


## Process recovery for a single pawn's injuries.
func _tick_pawn_injury_recovery(pawn: Node) -> void:
	var pd = pawn.get_pawn_data()
	if pd == null or pd.injuries.is_empty():
		return
	
	var has_healer: bool = _has_healer_nearby(pawn)
	var recovered_any: bool = false
	
	for injury_name in pd.injuries:
		var severity: float = float(pd.injuries[injury_name])
		if severity <= 0.0:
			continue
		
		# Determine injury type from name
		var injury_type: int = _injury_type_from_name(injury_name)
		var recovery_rate: float = RECOVERY_RATES.get(injury_type, 0.02)
		
		# Healers speed up recovery
		if has_healer:
			recovery_rate *= 2.0
		
		# Rest boosts recovery
		if pd.rest > 70.0:
			recovery_rate *= 1.3
		elif pd.rest < 30.0:
			recovery_rate *= 0.5
		
		var new_severity: float = maxf(0.0, severity - recovery_rate)
		pd.injuries[injury_name] = new_severity
		
		if new_severity <= 0.0:
			pd.injuries.erase(injury_name)
			if GameManager.verbose_logs():
				print("[BodyRisk] %s recovered from %s" % [pd.display_name, injury_name])
			recovered_any = true
	
	if recovered_any or not pd.injuries.is_empty():
		_recalculate_pain(pd)


## Recalculate pawn's pain level based on current injuries.
func _recalculate_pain(pd: HeelKawnianData) -> void:
	var total_pain: float = 0.0
	for injury_name in pd.injuries:
		var severity: float = float(pd.injuries[injury_name])
		total_pain += severity * 0.4  # Scale: 100 severity = 40 pain
	
	pd.pain = minf(total_pain, 100.0)


## Check if there's a healer pawn nearby.
## Currently no healer profession exists, so this always returns false.
## Preserving the structure for when a healer profession is added.
func _has_healer_nearby(pawn: Node, radius: int = 12) -> bool:
	# No healer profession exists yet — skip the O(n²) scan entirely.
	# TODO: Re-enable when HeelKawnianData.Profession.HEALER is added.
	return false

## Calculate total mobility penalty from all injuries (0.0 = no penalty, 1.0 = immobilized).
func get_mobility_penalty(pd: HeelKawnianData) -> float:
	if pd.injuries.is_empty():
		return 0.0
	
	var total_penalty: float = 0.0
	for injury_name in pd.injuries:
		var severity: float = float(pd.injuries[injury_name])
		var injury_type: int = _injury_type_from_name(injury_name)
		var base_penalty: float = MOBILITY_PENALTIES.get(injury_type, 0.0)
		total_penalty += base_penalty * (severity / 100.0)
	
	return minf(total_penalty, 0.95)  # Cap at 95% (never fully immobilized except broken bone)


## Calculate work efficiency penalty from injuries.
func get_work_efficiency_penalty(pd: HeelKawnianData) -> float:
	if pd.injuries.is_empty():
		return 0.0
	
	var total_penalty: float = 0.0
	for injury_name in pd.injuries:
		var severity: float = float(pd.injuries[injury_name])
		var injury_type: int = _injury_type_from_name(injury_name)
		var base_penalty: float = WORK_EFFICIENCY_PENALTIES.get(injury_type, 0.0)
		total_penalty += base_penalty * (severity / 100.0)
	
	return minf(total_penalty, 0.9)


## Check if pawn is immobilized (broken bone with high severity).
func is_immobilized(pd: HeelKawnianData) -> bool:
	var broken_severity: float = float(pd.injuries.get("broken_bone", 0.0))
	return broken_severity > 60.0


## Helper: injury type enum -> name string.
static func _injury_name(type: int) -> String:
	match type:
		InjuryType.CUT:          return "cut"
		InjuryType.BURN:         return "burn"
		InjuryType.BLUNT:        return "blunt"
		InjuryType.BROKEN_BONE:  return "broken_bone"
		InjuryType.FROSTBITE:    return "frostbite"
		InjuryType.INFECTION:    return "infection"
	return "unknown"


## Helper: name string -> injury type enum.
static func _injury_type_from_name(name: String) -> int:
	match name:
		"cut":          return InjuryType.CUT
		"burn":         return InjuryType.BURN
		"blunt":        return InjuryType.BLUNT
		"broken_bone":  return InjuryType.BROKEN_BONE
		"frostbite":    return InjuryType.FROSTBITE
		"infection":    return InjuryType.INFECTION
	return InjuryType.CUT


static func _infection_roll_salt(pd: HeelKawnianData, injury_name: String, severity: float, source: String) -> int:
	var tick: int = GameManager.tick_count if GameManager != null else 0
	return int(pd.id) * 1000003 + tick * 9176 + int(severity * 10.0) + hash(injury_name) + hash(source)
