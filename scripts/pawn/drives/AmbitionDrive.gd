## AmbitionDrive.gd — Growth impulses.
##
## Reads HeelKawnianManager (development profile), SettlementMemory
## (settlement needs), IntentMemory, ColonySimServices (crisis pressures),
## and profession/skill data.
## Pushes growth urges: work, build, master, lead, legacy.
##
## Ambition is a drive. A builder wants to build. A scholar wants to teach.
## A warrior wants to guard. These aren't random — they're genuine internal
## pushes that compete with survival and social needs.
extends RefCounted
class_name AmbitionDrive

const BASE_INTERVAL: int = 25

var _last_pulse_tick: int = -999999


func should_pulse(current_tick: int, _game_speed: float = 1.0) -> bool:
	if current_tick - _last_pulse_tick < BASE_INTERVAL:
		return false
	_last_pulse_tick = current_tick
	return true


## Pulse: check ambition state and push urges.
func pulse(data: HeelKawnianData, current_tick: int) -> Array[Urge]:
	var urges: Array[Urge] = []
	if data == null:
		return urges

	var pawn_id: int = int(data.id)

	# ── CRISIS OVERRIDES ──
	# Settlement crises push strong work/build urges.
	var crisis_food: float = 0.0
	var crisis_housing: float = 0.0
	if ColonySimServices != null:
		if ColonySimServices.has_method("get_food_pressure"):
			crisis_food = ColonySimServices.get_food_pressure()
		if ColonySimServices.has_method("get_housing_pressure"):
			crisis_housing = ColonySimServices.get_housing_pressure()

	if crisis_food > 0.7:
		# Food crisis → push food WORK urgently
		var work_urge: Urge = Urge.new(Urge.Type.WORK, 4.0, Urge.Source.AMBITION, current_tick)
		work_urge.context["job_category"] = "food"
		urges.append(work_urge)

	if crisis_housing > 0.8:
		# Housing crisis → push BUILD urgently
		var build_urge: Urge = Urge.new(Urge.Type.BUILD, 4.0, Urge.Source.AMBITION, current_tick)
		build_urge.context["job_category"] = "housing"
		urges.append(build_urge)

	# ── PROFESSION DRIVES ──
	# Each profession has a natural urge toward its work.
	# Only push if needs are reasonably satisfied (not starving/exhausted).
	if data.hunger > 35.0 and data.rest > 30.0:
		match data.current_profession:
			HeelKawnianData.Profession.FARMER:
				var work_urge: Urge = Urge.new(Urge.Type.WORK, 3.0, Urge.Source.AMBITION, current_tick)
				work_urge.context["job_category"] = "food"
				urges.append(work_urge)
			HeelKawnianData.Profession.BUILDER:
				var build_urge: Urge = Urge.new(Urge.Type.BUILD, 3.5, Urge.Source.AMBITION, current_tick)
				urges.append(build_urge)
			HeelKawnianData.Profession.GATHERER:
				var work_urge: Urge = Urge.new(Urge.Type.WORK, 3.0, Urge.Source.AMBITION, current_tick)
				work_urge.context["job_category"] = "gathering"
				urges.append(work_urge)
			HeelKawnianData.Profession.WARRIOR:
				urges.append(Urge.new(Urge.Type.GUARD, 3.0, Urge.Source.AMBITION, current_tick))
			HeelKawnianData.Profession.SCHOLAR:
				urges.append(Urge.new(Urge.Type.TEACH, 3.0, Urge.Source.AMBITION, current_tick))
			HeelKawnianData.Profession.HEALER:
				var work_urge: Urge = Urge.new(Urge.Type.WORK, 3.0, Urge.Source.AMBITION, current_tick)
				work_urge.context["job_category"] = "healing"
				urges.append(work_urge)

	# ── SETTLEMENT INTENT ──
	# Settlements with GROW intent push build urges.
	if SettlementMemory != null and SettlementMemory.has_method("get_settlement_id_for_pawn"):
		var sid: int = SettlementMemory.get_settlement_id_for_pawn(pawn_id)
		if sid >= 0:
			var center: int = SettlementMemory.get_center_region_for_region(sid) if SettlementMemory.has_method("get_center_region_for_region") else -1
			if center >= 0:
				var intent_mem: Node = MemoryManager.get_intent_memory()
				if intent_mem != null:
					var settlement_intent: Dictionary = intent_mem.settlement_intent if intent_mem.has_method("settlement_intent") else {}
					var intent: int = int(settlement_intent.get(center, MemoryManager.get_intent_hold()))
					if intent == MemoryManager.get_intent_grow():
						urges.append(Urge.new(Urge.Type.BUILD, 2.5, Urge.Source.AMBITION, current_tick))

	# ── SKILL MASTERY ──
	# Pawns with high skill but not yet maxed feel the urge to practice.
	var skill_key: String = data.highest_affinity_skill() if data.has_method("highest_affinity_skill") else ""
	if not skill_key.is_empty():
		var skill_level: float = data.get_skill_level(data.Skill.keys().find(skill_key)) if data.has_method("get_skill_level") else 0.0
		if skill_level > 50.0 and skill_level < 90.0:
			urges.append(Urge.new(Urge.Type.MASTER, 2.0, Urge.Source.AMBITION, current_tick))

	# ── LEGACY ──
	# Pawns with low legacy score feel the urge to create something lasting.
	if data.legacy_score < 20.0 and data.hunger > 50.0 and data.rest > 40.0:
		if posmod(current_tick + pawn_id * 17, 4000) < 50:
			urges.append(Urge.new(Urge.Type.LEGACY, 1.5, Urge.Source.AMBITION, current_tick))

	# ── LEADERSHIP ──
	# Pawns with high reputation but no leadership role may seek it.
	if data.reputation_score >= 60.0 and data.leadership_role == 0:
		if posmod(current_tick + pawn_id * 23, 6000) < 50:
			urges.append(Urge.new(Urge.Type.LEAD, 1.5, Urge.Source.AMBITION, current_tick))

	return urges


static func posmod(a: int, b: int) -> int:
	var m: int = a % b
	if m < 0:
		m += b
	return m
