extends Node
## TeachingSystem — knowledge and skill transmission between pawns.
## Teachers (skilled pawns) transfer knowledge to students through
## structured lessons. Tracks active lesson progress, effectiveness,
## prerequisites, duration scaling, completion effects, and integrates
## with KnowledgeSystem, SocialDynamics, EventBus, and WorldMemory.
##
## All randomness uses deterministic WorldRNG.stream_seed only.

const TEACHING_INTERVAL: int = 1500
const MAX_LESSONS_PER_TEACHER: int = 3
const MAX_LESSONS_PER_STUDENT: int = 2
const STALE_LESSON_TIMEOUT: int = 30000
const BASE_LESSON_DURATION: int = 6000
const FRIENDSHIP_GAIN_ON_COMPLETE: float = 0.05
const FRIENDSHIP_MULTIPLIER_MAX: float = 0.25
const LIBRARY_BONUS_MULTIPLIER: float = 1.15
const TEACHING_XP_PER_EFFECTIVENESS: float = 8.0
const MOVE_AWAY_GRACE_TICKS: int = 5000

const CATEGORY_DIFFICULTY: Dictionary = {
	0: 0.5, 1: 0.6, 2: 0.7, 3: 0.5, 4: 0.8,
	5: 0.6, 6: 0.7, 7: 0.9, 8: 1.0, 9: 0.4,
	10: 0.8, 11: 0.6, 12: 0.7, 13: 0.8, 14: 1.2,
	15: 0.9, 16: 0.8, 17: 1.1, 18: 1.4, 19: 1.0,
	20: 1.3, 21: 1.5, 22: 1.2, 23: 1.5, 24: 1.3,
	25: 1.4, 26: 0.9, 27: 0.6, 28: 1.2,
}

const PREREQUISITES: Dictionary = {
	18: [16], 19: [13], 20: [6], 21: [4], 22: [3],
	23: [2], 24: [7], 25: [15], 26: [1], 28: [2],
}

const CATEGORY_NAMES: Dictionary = {
	0: "Fire Keeping", 1: "Food Storage", 2: "Tool Making",
	3: "Season Reading", 4: "Sickness Avoidance", 5: "Navigation",
	6: "Shelter Building", 7: "Memory Preservation", 8: "Ruin Interpretation",
	9: "Hospitality", 10: "Winter Survival", 11: "Teaching",
	12: "Hunting", 13: "Farming", 14: "Combat",
	15: "Diplomacy", 16: "Crafting", 17: "Leadership",
	18: "Metallurgy", 19: "Animal Husbandry", 20: "Architecture",
	21: "Medicine", 22: "Astronomy", 23: "Engineering",
	24: "Writing", 25: "Philosophy", 26: "Agriculture",
	27: "Fire", 28: "Weapon Crafting",
}

var _active_lessons: Dictionary = {}
var _next_lesson_id: int = 1
var _last_teaching_tick: int = -999999
var _teacher_xp: Dictionary = {}
var _lessons_history: Array[Dictionary] = []
var _completed_lesson_count: int = 0
var _failed_lesson_count: int = 0
var _total_effectiveness_sum: float = 0.0
var _stale_check_tick: int = -999999
var _move_away_lessons: Dictionary = {}
var _lesson_participants_cache: Dictionary = {}

signal lesson_started(teacher: int, student: int, category: int, lesson_id: int)
signal lesson_completed(teacher: int, student: int, category: int, effectiveness: float, lesson_id: int)
signal lesson_failed(teacher: int, student: int, category: int, reason: String, lesson_id: int)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("subscribe"):
		eb.subscribe("pawn_died", self, "_on_pawn_died")
		eb.subscribe("pawn_moved", self, "_on_pawn_moved")

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("unsubscribe"):
		eb.unsubscribe("pawn_died", self, "_on_pawn_died")
		eb.unsubscribe("pawn_moved", self, "_on_pawn_moved")

func _on_game_tick(tick: int) -> void:
	if tick - _last_teaching_tick < TEACHING_INTERVAL:
		return
	_last_teaching_tick = tick
	_process_lessons(tick)
	if tick - _stale_check_tick >= STALE_LESSON_TIMEOUT:
		_stale_check_tick = tick
		_cleanup_stale_lessons(tick)
	_cleanup_expired_move_away_lessons(tick)

func _process_lessons(tick: int) -> void:
	var to_complete: Array[int] = []
	var to_fail: Array[int] = []
	var processed: int = 0
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if lesson.is_empty():
			to_fail.append(lid)
			continue
		var teacher_id: int = int(lesson.get("teacher_id", -1))
		var student_id: int = int(lesson.get("student_id", -1))
		if teacher_id < 0 or student_id < 0:
			to_fail.append(lid)
			continue
		if not _is_pawn_alive(teacher_id):
			to_fail.append(lid)
			continue
		if not _is_pawn_alive(student_id):
			to_fail.append(lid)
			continue
		var category: int = int(lesson.get("category", 0))
		var effectiveness: float = _calculate_effectiveness(teacher_id, student_id, category, tick)
		var duration: float = float(lesson.get("duration", BASE_LESSON_DURATION))
		var progress_increment: float = _calculate_progress_increment(effectiveness, duration)
		if progress_increment <= 0.0:
			progress_increment = 0.005
		var progress: float = float(lesson.get("progress", 0.0)) + progress_increment
		lesson["progress"] = progress
		lesson["effectiveness"] = effectiveness
		lesson["last_update_tick"] = tick
		_active_lessons[lid] = lesson
		processed += 1
		if progress >= 1.0:
			to_complete.append(lid)
	for lid in to_complete:
		_complete_lesson(lid, tick)
	for lid in to_fail:
		var reason: String = "participant_unavailable"
		var lesson: Dictionary = _active_lessons.get(lid, {})
		var t: int = int(lesson.get("teacher_id", -1))
		var s: int = int(lesson.get("student_id", -1))
		var c: int = int(lesson.get("category", 0))
		if t >= 0 and not _is_pawn_alive(t):
			reason = "teacher_died"
		elif s >= 0 and not _is_pawn_alive(s):
			reason = "student_died"
		_fail_lesson(lid, reason, tick)
	if GameManager != null and GameManager.verbose_logs() and processed > 0:
		print("[TeachingSystem] Tick %d: processed %d lessons, %d complete, %d failed" % [tick, processed, to_complete.size(), to_fail.size()])

func cancel_lesson(lesson_id: int, tick: int, give_partial_credit: bool = false) -> bool:
	if not _active_lessons.has(lesson_id):
		return false
	var lesson: Dictionary = _active_lessons[lesson_id]
	var progress: float = float(lesson.get("progress", 0.0))
	if give_partial_credit and progress > 0.3:
		var teacher_id: int = int(lesson.get("teacher_id", -1))
		var student_id: int = int(lesson.get("student_id", -1))
		var category: int = int(lesson.get("category", 0))
		var partial_eff: float = float(lesson.get("effectiveness", 0.3)) * progress * 0.5
		if partial_eff > 0.1:
			var ks := get_node_or_null("/root/KnowledgeSystem")
			if ks != null and ks.has_method("add_knowledge_carrier"):
				if not ks.has_knowledge(student_id, category):
					ks.add_knowledge_carrier(student_id, category)
			var partial_xp: float = partial_eff * TEACHING_XP_PER_EFFECTIVENESS * 0.5
			_teacher_xp[teacher_id] = _teacher_xp.get(teacher_id, 0.0) + partial_xp
			_completed_lesson_count += 1
			_total_effectiveness_sum += partial_eff
			lesson_completed.emit(teacher_id, student_id, category, partial_eff, lesson_id)
	var reason: String = "cancelled"
	if give_partial_credit:
		reason = "cancelled_with_partial_credit"
	_fail_lesson(lesson_id, reason, tick)
	return true

func _calculate_progress_increment(effectiveness: float, duration: float) -> float:
	if duration <= 0.0:
		return 0.1
	var increment: float = effectiveness * (float(TEACHING_INTERVAL) / duration)
	return clampf(increment, 0.001, 1.0)

func is_valid_category(category: int) -> bool:
	return category >= 0 and category <= 28

func _category_name(category: int) -> String:
	return CATEGORY_NAMES.get(category, "Category #%d" % category)

func start_lesson(teacher_id: int, student_id: int, category: int, tick: int) -> int:
	if teacher_id < 0 or student_id < 0:
		return -1
	if teacher_id == student_id:
		return -1
	if not is_valid_category(category):
		return -1
	if not _is_pawn_alive(teacher_id) or not _is_pawn_alive(student_id):
		return -1
	var same_settlement: bool = _same_settlement(teacher_id, student_id)
	if not same_settlement:
		return -1
	for lid in _active_lessons.keys():
		var existing: Dictionary = _active_lessons[lid]
		if int(existing.get("teacher_id", -1)) == teacher_id and int(existing.get("student_id", -1)) == student_id and int(existing.get("category", -1)) == category:
			return -1
	var teacher_active: int = 0
	var student_active: int = 0
	for lid in _active_lessons.keys():
		var ex: Dictionary = _active_lessons[lid]
		if int(ex.get("teacher_id", -1)) == teacher_id:
			teacher_active += 1
		if int(ex.get("student_id", -1)) == student_id:
			student_active += 1
	if teacher_active >= MAX_LESSONS_PER_TEACHER:
		return -2
	if student_active >= MAX_LESSONS_PER_STUDENT:
		return -3
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("has_knowledge"):
		if ks.has_knowledge(student_id, category):
			return -4
		if not ks.has_knowledge(teacher_id, category):
			return -5
	if not _has_prerequisites(category, teacher_id):
		return -6
	if not _has_prerequisites(category, student_id):
		return -7
	var duration: int = _calculate_duration(teacher_id, student_id, category)
	var lid: int = _next_lesson_id
	_next_lesson_id += 1
	_active_lessons[lid] = {
		"lesson_id": lid,
		"teacher_id": teacher_id,
		"student_id": student_id,
		"category": category,
		"tick_started": tick,
		"duration": duration,
		"effectiveness": 0.0,
		"progress": 0.0,
		"completed": false,
		"last_update_tick": tick,
		"teacher_settlement": _get_pawn_settlement_id(teacher_id),
		"student_settlement": _get_pawn_settlement_id(student_id),
	}
	lesson_started.emit(teacher_id, student_id, category, lid)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "lesson_started",
			"k": wm.Kind.TEACHING_EVENT,
			"teacher_id": teacher_id,
			"student_id": student_id,
			"category": category,
			"category_name": _category_name(category),
			"lesson_id": lid,
			"duration": duration,
		})
	return lid

func _has_prerequisites(category: int, pawn_id: int) -> bool:
	if not PREREQUISITES.has(category):
		return true
	var required: Array = PREREQUISITES[category]
	if required.is_empty():
		return true
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("has_knowledge"):
		return true
	var missing: Array[int] = []
	for prereq in required:
		var pcat: int = int(prereq)
		if not ks.has_knowledge(pawn_id, pcat):
			missing.append(pcat)
	return missing.is_empty()

func _calculate_duration(teacher_id: int, student_id: int, category: int) -> int:
	var difficulty: float = CATEGORY_DIFFICULTY.get(category, 1.0)
	var teacher_skill: float = _get_teacher_skill(teacher_id, category)
	var teacher_speed_factor: float = clampf(1.0 - teacher_skill * 0.08, 0.4, 1.0)
	var duration: float = float(BASE_LESSON_DURATION) * difficulty * teacher_speed_factor
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("get_carrier_count"):
		var carriers: int = ks.get_carrier_count(category)
		if carriers > 1:
			duration *= clampf(1.0 - float(carriers) * 0.02, 0.7, 1.0)
	return maxi(int(duration), 600)

func _calculate_effectiveness(teacher_id: int, student_id: int, category: int, tick: int) -> float:
	var teacher_skill: float = _get_teacher_skill(teacher_id, category)
	var student_skill: float = _get_student_skill(student_id, category)
	var base: float = teacher_skill / maxf(student_skill, 1.0)
	base = clampf(base, 0.1, 3.0)
	var teacher_settlement: int = _get_pawn_settlement_id(teacher_id)
	if _settlement_has_library(teacher_settlement):
		base *= LIBRARY_BONUS_MULTIPLIER
	else:
		var student_settlement: int = _get_pawn_settlement_id(student_id)
		if _settlement_has_library(student_settlement):
			base *= LIBRARY_BONUS_MULTIPLIER
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd != null and sd.has_method("get_friendship"):
		var friendship: float = sd.get_friendship(teacher_id, student_id)
		if friendship > 0.0:
			var rel_mult: float = 1.0 + minf(friendship, 1.0) * FRIENDSHIP_MULTIPLIER_MAX
			base *= rel_mult
	if base <= 0.0:
		base = 0.05
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("get_carrier_count"):
		var global_carriers: int = ks.get_carrier_count(category)
		if global_carriers > 0:
			base *= 1.0 + minf(float(global_carriers) * 0.015, 0.3)
	var rng_seed: int = teacher_id * 1009 + student_id * 131 + category * 37 + tick
	var stream: StringName = StringName("teaching_effectiveness_jitter:%d" % rng_seed)
	var jitter: float = WorldRNG.range_for(stream, 0.95, 1.05, rng_seed)
	base *= jitter
	var teacher_concurrent: int = 0
	for lid2 in _active_lessons.keys():
		if int(_active_lessons[lid2].get("teacher_id", -1)) == teacher_id:
			teacher_concurrent += 1
	if teacher_concurrent > 1:
		var fatigue: float = 1.0 - (float(teacher_concurrent - 1) * 0.1)
		base *= clampf(fatigue, 0.7, 1.0)
	var student_concurrent: int = 0
	for lid2 in _active_lessons.keys():
		if int(_active_lessons[lid2].get("student_id", -1)) == student_id:
			student_concurrent += 1
	if student_concurrent > 1:
		var split_attention: float = 1.0 - (float(student_concurrent - 1) * 0.08)
		base *= clampf(split_attention, 0.75, 1.0)
	return clampf(base, 0.05, 4.0)

func _get_teacher_skill(teacher_id: int, category: int) -> float:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("has_knowledge"):
		return 1.0
	if not ks.has_knowledge(teacher_id, category):
		return 0.1
	var total_known: int = 0
	if ks.has_method("get_pawn_knowledge"):
		var known: Array = ks.get_pawn_knowledge(teacher_id)
		total_known = known.size()
	var skill: float = 1.0 + float(total_known) * 0.15
	var teaching_xp: float = _teacher_xp.get(teacher_id, 0.0)
	skill += teaching_xp * 0.002
	return clampf(skill, 0.1, 10.0)

func _get_student_skill(student_id: int, category: int) -> float:
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("get_pawn_knowledge"):
		return 1.0
	var known: Array = ks.get_pawn_knowledge(student_id)
	if known.size() == 0:
		return 1.0
	if known.has(category):
		return 0.5
	var related_count: int = 0
	for kt in known:
		var prereqs: Array = PREREQUISITES.get(category, [])
		if int(kt) in prereqs:
			related_count += 1
	var skill: float = 1.0 + float(known.size()) * 0.1 + float(related_count) * 0.3
	return clampf(skill, 0.5, 8.0)

func _complete_lesson(lid: int, tick: int) -> void:
	var lesson: Dictionary = _active_lessons.get(lid, {})
	if lesson.is_empty():
		return
	var teacher_id: int = int(lesson.get("teacher_id", -1))
	var student_id: int = int(lesson.get("student_id", -1))
	var category: int = int(lesson.get("category", 0))
	var effectiveness: float = float(lesson.get("effectiveness", 0.5))
	if effectiveness <= 0.0:
		effectiveness = 0.3
	lesson["completed"] = true
	lesson["progress"] = 1.0
	_active_lessons[lid] = lesson
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("add_knowledge_carrier"):
		if not ks.has_knowledge(student_id, category):
			ks.add_knowledge_carrier(student_id, category)
		var related_bonus_categories: Array[int] = []
		for kt in range(29):
			var prereqs: Array = PREREQUISITES.get(kt, [])
			if category in prereqs:
				if not ks.has_knowledge(student_id, kt):
					related_bonus_categories.append(kt)
		if not related_bonus_categories.is_empty() and effectiveness >= 0.8:
			var stream: StringName = StringName("teaching_completion_related_bonus:%d" % lid)
			if WorldRNG.chance_for(stream, 0.15 * effectiveness, tick + student_id):
				var bonus_cat: int = related_bonus_categories[tick % related_bonus_categories.size()]
				ks.add_knowledge_carrier(student_id, bonus_cat)
	var sd := get_node_or_null("/root/SocialDynamics")
	if sd != null and sd.has_method("add_interaction"):
		var friendship_gain: float = FRIENDSHIP_GAIN_ON_COMPLETE * effectiveness
		sd.add_interaction(teacher_id, student_id, "friendship", friendship_gain, tick, "lesson_completed")
	var xp_gain: float = effectiveness * TEACHING_XP_PER_EFFECTIVENESS
	_teacher_xp[teacher_id] = _teacher_xp.get(teacher_id, 0.0) + xp_gain
	_completed_lesson_count += 1
	_total_effectiveness_sum += effectiveness
	var history_entry: Dictionary = {
		"lesson_id": lid, "teacher_id": teacher_id, "student_id": student_id,
		"category": category, "effectiveness": effectiveness, "tick": tick,
	}
	_lessons_history.append(history_entry)
	if _lessons_history.size() > 500:
		_lessons_history.pop_front()
	lesson_completed.emit(teacher_id, student_id, category, effectiveness, lid)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "lesson_completed",
			"k": wm.Kind.TEACHING_EVENT,
			"teacher_id": teacher_id,
			"student_id": student_id,
			"category": category,
			"category_name": _category_name(category),
			"effectiveness": effectiveness,
			"lesson_id": lid,
			"teacher_xp_gained": xp_gain,
		})
	_active_lessons.erase(lid)

func _fail_lesson(lid: int, reason: String, tick: int) -> void:
	var lesson: Dictionary = _active_lessons.get(lid, {})
	if lesson.is_empty():
		return
	var teacher_id: int = int(lesson.get("teacher_id", -1))
	var student_id: int = int(lesson.get("student_id", -1))
	var category: int = int(lesson.get("category", 0))
	_failed_lesson_count += 1
	_active_lessons.erase(lid)
	lesson_failed.emit(teacher_id, student_id, category, reason, lid)
	var wm := get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "lesson_failed",
			"k": wm.Kind.TEACHING_EVENT,
			"teacher_id": teacher_id,
			"student_id": student_id,
			"category": category,
			"category_name": _category_name(category),
			"reason": reason,
			"lesson_id": lid,
		})

func _on_pawn_died(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", -1))
	if pawn_id < 0:
		return
	var lid_to_fail: Array[int] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("teacher_id", -1)) == pawn_id or int(lesson.get("student_id", -1)) == pawn_id:
			lid_to_fail.append(lid)
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	for lid in lid_to_fail:
		var lesson: Dictionary = _active_lessons.get(lid, {})
		var who: String = "teacher" if int(lesson.get("teacher_id", -1)) == pawn_id else "student"
		_fail_lesson(lid, "%s_died" % who, tick)

func _on_pawn_moved(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", -1))
	if pawn_id < 0:
		return
	var new_settlement: int = int(payload.get("new_settlement_id", -1))
	var old_settlement: int = int(payload.get("old_settlement_id", -1))
	if new_settlement < 0 or old_settlement < 0 or old_settlement == new_settlement:
		return
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	var affected_count: int = 0
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		var tid: int = int(lesson.get("teacher_id", -1))
		var sid: int = int(lesson.get("student_id", -1))
		if tid != pawn_id and sid != pawn_id:
			continue
		var other_id: int = sid if tid == pawn_id else tid
		var other_settlement: int = _get_pawn_settlement_id(other_id)
		if other_settlement < 0:
			_fail_lesson(lid, "other_participant_invalid", tick)
			affected_count += 1
		elif other_settlement != new_settlement:
			_move_away_lessons[lid] = {
				"lesson_id": lid, "tick_started": tick,
				"grace_until": tick + MOVE_AWAY_GRACE_TICKS,
				"mover_id": pawn_id,
				"other_id": other_id,
			}
			affected_count += 1
			var wm := get_node_or_null("/root/WorldMemory")
			if wm != null and wm.has_method("record_event"):
				wm.record_event({
					"type": "lesson_separated_by_move",
					"k": wm.Kind.TEACHING_EVENT,
					"lesson_id": lid,
					"mover_id": pawn_id,
					"other_id": other_id,
					"old_settlement": old_settlement,
					"new_settlement": new_settlement,
					"grace_until": tick + MOVE_AWAY_GRACE_TICKS,
				})
	if GameManager != null and GameManager.verbose_logs() and affected_count > 0:
		print("[TeachingSystem] Pawn %d moved settlement %d->%d, affected %d lessons, will expire after grace period" % [pawn_id, old_settlement, new_settlement, affected_count])

func _cleanup_expired_move_away_lessons(tick: int) -> void:
	if _move_away_lessons.is_empty():
		return
	var to_fail: Array[int] = []
	for lid in _move_away_lessons.keys():
		var info: Dictionary = _move_away_lessons[lid]
		if tick >= int(info.get("grace_until", tick)):
			if _active_lessons.has(lid):
				var lesson: Dictionary = _active_lessons[lid]
				var tid: int = int(lesson.get("teacher_id", -1))
				var sid: int = int(lesson.get("student_id", -1))
				if not _same_settlement(tid, sid):
					to_fail.append(lid)
			_move_away_lessons.erase(lid)
	for lid in to_fail:
		_fail_lesson(lid, "participant_left_settlement", tick)

func _cleanup_stale_lessons(tick: int) -> void:
	if _active_lessons.is_empty():
		return
	var to_remove: Array[int] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		var last_update: int = int(lesson.get("last_update_tick", 0))
		if tick - last_update > STALE_LESSON_TIMEOUT:
			to_remove.append(lid)
	for lid in to_remove:
		_fail_lesson(lid, "stale_timeout", tick)

func _cancel_lessons_for_pawn(pawn_id: int, reason: String, tick: int) -> int:
	var count: int = 0
	var to_fail: Array[int] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("teacher_id", -1)) == pawn_id or int(lesson.get("student_id", -1)) == pawn_id:
			to_fail.append(lid)
	for lid in to_fail:
		_fail_lesson(lid, reason, tick)
		count += 1
	return count

func find_teachers_for_student(student_id: int, category: int, settlement_id: int = -1) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if settlement_id < 0:
		settlement_id = _get_pawn_settlement_id(student_id)
	if settlement_id < 0:
		return candidates
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("has_knowledge"):
		return candidates
	var pawn_ids: Array[int] = _get_pawns_in_settlement(settlement_id)
	for pid in pawn_ids:
		if pid == student_id:
			continue
		if not ks.has_knowledge(pid, category):
			continue
		if not _is_pawn_alive(pid):
			continue
		if not _has_prerequisites(category, pid):
			continue
		var active_count: int = 0
		for lid in _active_lessons.keys():
			if int(_active_lessons[lid].get("teacher_id", -1)) == pid:
				active_count += 1
		if active_count >= MAX_LESSONS_PER_TEACHER:
			continue
		var effectiveness: float = _calculate_effectiveness(pid, student_id, category, GameManager.tick_count if GameManager != null else 0)
		var friendship: float = 0.0
		var sd := get_node_or_null("/root/SocialDynamics")
		if sd != null and sd.has_method("get_friendship"):
			friendship = sd.get_friendship(pid, student_id)
		candidates.append({
			"teacher_id": pid,
			"category": category,
			"estimated_effectiveness": effectiveness,
			"friendship": friendship,
			"active_lessons": active_count,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("estimated_effectiveness", 0.0)) > float(b.get("estimated_effectiveness", 0.0))
	)
	return candidates

func find_students_for_teacher(teacher_id: int, category: int, settlement_id: int = -1) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if settlement_id < 0:
		settlement_id = _get_pawn_settlement_id(teacher_id)
	if settlement_id < 0:
		return candidates
	var ks := get_node_or_null("/root/KnowledgeSystem")
	if ks == null or not ks.has_method("has_knowledge"):
		return candidates
	if not ks.has_knowledge(teacher_id, category):
		return candidates
	var pawn_ids: Array[int] = _get_pawns_in_settlement(settlement_id)
	for pid in pawn_ids:
		if pid == teacher_id:
			continue
		if ks.has_knowledge(pid, category):
			continue
		if not _is_pawn_alive(pid):
			continue
		if not _has_prerequisites(category, pid):
			continue
		var active_count: int = 0
		for lid in _active_lessons.keys():
			if int(_active_lessons[lid].get("student_id", -1)) == pid:
				active_count += 1
		if active_count >= MAX_LESSONS_PER_STUDENT:
			continue
		var effectiveness: float = _calculate_effectiveness(teacher_id, pid, category, GameManager.tick_count if GameManager != null else 0)
		var friendship: float = 0.0
		var sd := get_node_or_null("/root/SocialDynamics")
		if sd != null and sd.has_method("get_friendship"):
			friendship = sd.get_friendship(teacher_id, pid)
		candidates.append({
			"student_id": pid,
			"category": category,
			"estimated_effectiveness": effectiveness,
			"friendship": friendship,
			"active_lessons": active_count,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("estimated_effectiveness", 0.0)) > float(b.get("estimated_effectiveness", 0.0))
	)
	return candidates

func _settlement_has_library(settlement_id: int) -> bool:
	if settlement_id < 0:
		return false
	var sm := get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return false
	var settlements: Array = sm.get("settlements")
	if not (settlements is Array):
		return false
	for st_any in settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) != settlement_id:
			continue
		if st.has("buildings"):
			var buildings: Array = st["buildings"]
			if not (buildings is Array):
				buildings = []
			for b in buildings:
				if b is Dictionary:
					var bt: String = str(b.get("type", ""))
					if bt.to_lower() in ["library", "school", "archive"]:
						return true
		var regions_v: Variant = st.get("regions", null)
		if not (regions_v is PackedInt32Array):
			continue
		var regions: PackedInt32Array = regions_v as PackedInt32Array
		var library_buildings: Array = _find_buildings_of_type_in_regions(regions, ["library", "school", "archive"])
		if not library_buildings.is_empty():
			return true
	return false

func _find_buildings_of_type_in_regions(regions: PackedInt32Array, types: Array[String]) -> Array:
	var result: Array = []
	var world_node := get_tree().get_root().get_node_or_null("Main/WorldViewport/World")
	if world_node == null:
		return result
	for child in world_node.get_children():
		if child.has_method("get") and child.has_method("has_method"):
			var type_v: Variant = child.get("type")
			if type_v is String:
				var t: String = type_v as String
				if t.to_lower() in types:
					var tile_v: Variant = child.get("tile_pos")
					if tile_v is Vector2i:
						var tile: Vector2i = tile_v as Vector2i
						var rk: int = WorldMemory._region_key(tile.x, tile.y)
						if rk in regions:
							result.append(child)
	return result

func _get_pawn_settlement_id(pawn_id: int) -> int:
	if pawn_id < 0:
		return -1
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null or not ps.has_method("_get_pawn_node"):
		return -1
	var pawn = ps.call("_get_pawn_node", pawn_id)
	if pawn == null or not is_instance_valid(pawn):
		return -1
	var data = pawn.get("data")
	if data == null:
		return -1
	return int(data.settlement_id)

func _get_pawns_in_settlement(settlement_id: int) -> Array[int]:
	var result: Array[int] = []
	if settlement_id < 0:
		return result
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null or not ps.has_method("pawns"):
		return result
	var pawns: Array = ps.pawns
	for p in pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if int(p.data.settlement_id) == settlement_id:
			result.append(int(p.data.id))
	return result

func _same_settlement(a_id: int, b_id: int) -> bool:
	var a_sett: int = _get_pawn_settlement_id(a_id)
	var b_sett: int = _get_pawn_settlement_id(b_id)
	return a_sett >= 0 and a_sett == b_sett

func _is_pawn_alive(pawn_id: int) -> bool:
	if pawn_id < 0:
		return false
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null or not ps.has_method("_get_pawn_node"):
		return false
	var pawn = ps.call("_get_pawn_node", pawn_id)
	return pawn != null and is_instance_valid(pawn)

func get_teacher_report(teacher_id: int) -> Dictionary:
	var active: Array[Dictionary] = []
	var total_effectiveness: float = 0.0
	var lesson_count: int = 0
	var categories_taught: Dictionary = {}
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("teacher_id", -1)) == teacher_id:
			active.append(lesson.duplicate())
	for entry in _lessons_history:
		if int(entry.get("teacher_id", -1)) == teacher_id:
			total_effectiveness += float(entry.get("effectiveness", 0.0))
			lesson_count += 1
			var cat: int = int(entry.get("category", -1))
			categories_taught[cat] = categories_taught.get(cat, 0) + 1
	var avg_eff: float = 0.0
	if lesson_count > 0:
		avg_eff = total_effectiveness / float(lesson_count)
	return {
		"teacher_id": teacher_id,
		"active_lessons": active,
		"active_count": active.size(),
		"completed_lessons": lesson_count,
		"total_effectiveness": total_effectiveness,
		"average_effectiveness": snappedf(avg_eff, 0.01),
		"categories_taught": categories_taught,
		"teacher_xp": _teacher_xp.get(teacher_id, 0.0),
	}

func get_student_report(student_id: int) -> Dictionary:
	var active: Array[Dictionary] = []
	var completed: Array[Dictionary] = []
	var total_effectiveness: float = 0.0
	var lesson_count: int = 0
	var categories_learned: Dictionary = {}
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("student_id", -1)) == student_id:
			active.append(lesson.duplicate())
	for entry in _lessons_history:
		if int(entry.get("student_id", -1)) == student_id:
			completed.append(entry.duplicate())
			total_effectiveness += float(entry.get("effectiveness", 0.0))
			lesson_count += 1
			var cat: int = int(entry.get("category", -1))
			categories_learned[cat] = categories_learned.get(cat, 0) + 1
	var avg_eff: float = 0.0
	if lesson_count > 0:
		avg_eff = total_effectiveness / float(lesson_count)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var total_knowledge: int = 0
	if ks != null and ks.has_method("get_pawn_knowledge"):
		total_knowledge = ks.get_pawn_knowledge(student_id).size()
	return {
		"student_id": student_id,
		"active_lessons": active,
		"active_count": active.size(),
		"completed_lessons": lesson_count,
		"total_effectiveness": total_effectiveness,
		"average_effectiveness": snappedf(avg_eff, 0.01),
		"categories_learned": categories_learned,
		"total_knowledge": total_knowledge,
	}

func get_settlement_teaching_status(settlement_id: int) -> Dictionary:
	var teachers: Array[int] = []
	var students: Array[int] = []
	var active_in_settlement: Array[Dictionary] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		var tid: int = int(lesson.get("teacher_id", -1))
		var sid: int = int(lesson.get("student_id", -1))
		var t_sett: int = int(lesson.get("teacher_settlement", -1))
		var s_sett: int = int(lesson.get("student_settlement", -1))
		if t_sett == settlement_id or s_sett == settlement_id:
			active_in_settlement.append(lesson.duplicate())
		if t_sett == settlement_id and not (tid in teachers):
			teachers.append(tid)
		if s_sett == settlement_id and not (sid in students):
			students.append(sid)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	var total_categories: int = 0
	var covered_categories: int = 0
	if ks != null and ks.has_method("get_pawn_knowledge"):
		for tid in teachers:
			var known: Array = ks.get_pawn_knowledge(tid)
			total_categories = maxi(total_categories, known.size())
			if not known.is_empty():
				covered_categories += 1
	var settlement_teachers: Array[int] = _get_pawns_in_settlement(settlement_id)
	var potential_teachers: int = 0
	for pid in settlement_teachers:
		if ks != null and ks.has_method("get_pawn_knowledge"):
			if ks.get_pawn_knowledge(pid).size() >= 2:
				potential_teachers += 1
	return {
		"settlement_id": settlement_id,
		"active_teachers": teachers.size(),
		"active_students": students.size(),
		"active_lessons_here": active_in_settlement,
		"active_lesson_count_here": active_in_settlement.size(),
		"unique_teachers": teachers,
		"unique_students": students,
		"potential_teachers": potential_teachers,
		"has_library": _settlement_has_library(settlement_id),
	}

func get_all_teachers_in_settlement(settlement_id: int, category: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if settlement_id < 0:
		return result
	var pawn_ids: Array[int] = _get_pawns_in_settlement(settlement_id)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	for pid in pawn_ids:
		if not _is_pawn_alive(pid):
			continue
		if ks == null or not ks.has_method("has_knowledge"):
			continue
		if category >= 0 and not ks.has_knowledge(pid, category):
			continue
		if category < 0 and ks.get_pawn_knowledge(pid).is_empty():
			continue
		var active: int = 0
		for lid in _active_lessons.keys():
			if int(_active_lessons[lid].get("teacher_id", -1)) == pid:
				active += 1
		result.append({
			"pawn_id": pid,
			"active_lessons": active,
			"has_capacity": active < MAX_LESSONS_PER_TEACHER,
			"knowledge_count": ks.get_pawn_knowledge(pid).size() if ks.has_method("get_pawn_knowledge") else 0,
			"teacher_xp": _teacher_xp.get(pid, 0.0),
		})
	return result

func get_all_students_in_settlement(settlement_id: int, category: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if settlement_id < 0:
		return result
	var pawn_ids: Array[int] = _get_pawns_in_settlement(settlement_id)
	var ks := get_node_or_null("/root/KnowledgeSystem")
	for pid in pawn_ids:
		if not _is_pawn_alive(pid):
			continue
		if ks != null and ks.has_method("has_knowledge") and category >= 0:
			if ks.has_knowledge(pid, category):
				continue
		var active: int = 0
		for lid in _active_lessons.keys():
			if int(_active_lessons[lid].get("student_id", -1)) == pid:
				active += 1
		result.append({
			"pawn_id": pid,
			"active_lessons": active,
			"has_capacity": active < MAX_LESSONS_PER_STUDENT,
			"knowledge_count": ks.get_pawn_knowledge(pid).size() if ks != null and ks.has_method("get_pawn_knowledge") else 0,
		})
	return result

func get_least_loaded_teacher(settlement_id: int, category: int) -> int:
	var teachers: Array[Dictionary] = get_all_teachers_in_settlement(settlement_id, category)
	if teachers.is_empty():
		return -1
	var best_id: int = -1
	var best_load: int = 999
	for t in teachers:
		var load: int = int(t.get("active_lessons", 0))
		if load < best_load and bool(t.get("has_capacity", false)):
			best_load = load
			best_id = int(t.get("pawn_id", -1))
	return best_id

func get_most_teachable_student(settlement_id: int, category: int) -> int:
	var students: Array[Dictionary] = get_all_students_in_settlement(settlement_id, category)
	if students.is_empty():
		return -1
	var best_id: int = -1
	var lowest_load: int = 999
	var highest_eff: float = -1.0
	for s in students:
		var load: int = int(s.get("active_lessons", 0))
		if not bool(s.get("has_capacity", false)):
			continue
		var ks := get_node_or_null("/root/KnowledgeSystem")
		var prereq_ok: bool = true
		if ks != null and ks.has_method("has_knowledge"):
			var prereqs: Array = PREREQUISITES.get(category, [])
			for prereq in prereqs:
				if not ks.has_knowledge(int(s.get("pawn_id", -1)), prereq):
					prereq_ok = false
					break
		if not prereq_ok:
			continue
		if load < lowest_load:
			lowest_load = load
			highest_eff = 0.0
			best_id = int(s.get("pawn_id", -1))
		elif load == lowest_load and int(s.get("knowledge_count", 0)) < int(highest_eff * 10.0):
			best_id = int(s.get("pawn_id", -1))
	return best_id

func get_teacher_xp(teacher_id: int) -> float:
	return _teacher_xp.get(teacher_id, 0.0)

func get_lesson(lesson_id: int) -> Dictionary:
	if _active_lessons.has(lesson_id):
		return _active_lessons[lesson_id].duplicate()
	for entry in _lessons_history:
		if int(entry.get("lesson_id", -1)) == lesson_id:
			return entry.duplicate()
	return {}

func get_active_lessons_for_teacher(teacher_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("teacher_id", -1)) == teacher_id:
			out.append(lesson.duplicate())
	return out

func get_active_lessons_for_student(student_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lid in _active_lessons.keys():
		var lesson: Dictionary = _active_lessons[lid]
		if int(lesson.get("student_id", -1)) == student_id:
			out.append(lesson.duplicate())
	return out

func get_active_lessons() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lid in _active_lessons.keys():
		out.append(_active_lessons[lid].duplicate())
	return out

func get_active_lesson_count() -> int:
	return _active_lessons.size()

func get_lesson_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _lessons_history:
		out.append(entry.duplicate())
	return out

func get_stats() -> Dictionary:
	var avg_eff: float = 0.0
	if _completed_lesson_count > 0:
		avg_eff = _total_effectiveness_sum / float(_completed_lesson_count)
	var teachers_with_xp: int = 0
	var total_xp: float = 0.0
	for tid in _teacher_xp:
		var xp: float = _teacher_xp[tid]
		if xp > 0.0:
			teachers_with_xp += 1
			total_xp += xp
	return {
		"active_lessons": _active_lessons.size(),
		"completed_lessons": _completed_lesson_count,
		"failed_lessons": _failed_lesson_count,
		"total_lessons_attempted": _completed_lesson_count + _failed_lesson_count,
		"average_effectiveness": snappedf(avg_eff, 0.01),
		"total_effectiveness_sum": snappedf(_total_effectiveness_sum, 0.01),
		"teachers_with_xp": teachers_with_xp,
		"total_teacher_xp": snappedf(total_xp, 0.1),
		"history_size": _lessons_history.size(),
		"pending_move_away_expirations": _move_away_lessons.size(),
		"last_teaching_tick": _last_teaching_tick,
	}

func get_save_state() -> Dictionary:
	return {
		"active_lessons": _active_lessons.duplicate(true),
		"next_lesson_id": _next_lesson_id,
		"last_teaching_tick": _last_teaching_tick,
		"teacher_xp": _teacher_xp.duplicate(true),
		"lessons_history": _lessons_history.duplicate(true),
		"completed_lesson_count": _completed_lesson_count,
		"failed_lesson_count": _failed_lesson_count,
		"total_effectiveness_sum": _total_effectiveness_sum,
		"stale_check_tick": _stale_check_tick,
		"move_away_lessons": _move_away_lessons.duplicate(true),
	}

func load_state(state: Dictionary) -> void:
	clear()
	if state.has("active_lessons"):
		_active_lessons = state["active_lessons"].duplicate(true)
	if state.has("next_lesson_id"):
		_next_lesson_id = int(state["next_lesson_id"])
	if state.has("last_teaching_tick"):
		_last_teaching_tick = int(state["last_teaching_tick"])
	if state.has("teacher_xp"):
		_teacher_xp = state["teacher_xp"].duplicate(true)
	if state.has("lessons_history"):
		_lessons_history = state["lessons_history"].duplicate(true)
	if state.has("completed_lesson_count"):
		_completed_lesson_count = int(state["completed_lesson_count"])
	if state.has("failed_lesson_count"):
		_failed_lesson_count = int(state["failed_lesson_count"])
	if state.has("total_effectiveness_sum"):
		_total_effectiveness_sum = float(state["total_effectiveness_sum"])
	if state.has("stale_check_tick"):
		_stale_check_tick = int(state["stale_check_tick"])
	if state.has("move_away_lessons"):
		_move_away_lessons = state["move_away_lessons"].duplicate(true)

func clear() -> void:
	_active_lessons.clear()
	_next_lesson_id = 1
	_last_teaching_tick = -999999
	_teacher_xp.clear()
	_lessons_history.clear()
	_completed_lesson_count = 0
	_failed_lesson_count = 0
	_total_effectiveness_sum = 0.0
	_stale_check_tick = -999999
	_move_away_lessons.clear()
	_lesson_participants_cache.clear()
