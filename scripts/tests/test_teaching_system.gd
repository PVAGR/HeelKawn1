extends Node

## Headless test for TeachingSystem knowledge transmission.
## Run: godot --headless --path . --script scripts/tests/test_teaching_system.gd

var _passed: int = 0
var _failed: int = 0
var _ts: Node = null

func _ready() -> void:
	print("[test_teaching_system] Starting...")
	var TeachingSystem = load("res://autoloads/TeachingSystem.gd")
	_ts = TeachingSystem.new()
	get_tree().root.add_child(_ts)

	_setup_mock_autoloads()
	_ts.clear()

	_test_effectiveness_basic()
	_test_duration_scaling()
	_test_lesson_lifecycle()
	_test_lesson_failure_events()
	_test_invalid_inputs()
	_test_cancel_lesson()
	_test_save_load_roundtrip()
	_test_clear()
	_test_stats()
	_test_find_teachers_for_student()

	print("\n[test_teaching_system] ====================")
	print("[test_teaching_system] PASSED: %d" % _passed)
	print("[test_teaching_system] FAILED: %d" % _failed)
	print("[test_teaching_system] ====================")
	if _failed > 0:
		print("[test_teaching_system] TESTS FAILED")
	else:
		print("[test_teaching_system] ALL TESTS PASSED")
	_ts.free()
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % message)
	else:
		_failed += 1
		print("[FAIL] %s" % message)


func _setup_mock_autoloads() -> void:
	var ks = Node.new()
	ks._mock_has = {}
	ks._mock_carriers = {}
	ks.has_knowledge = func(_pid, _cat): return ks._mock_has.get(_cat, false)
	ks.get_carrier_count = func(_cat): return ks._mock_carriers.get(_cat, 1)
	ks.add_knowledge_carrier = func(_pid, _cat, _src): ks._mock_carriers[_cat] = ks._mock_carriers.get(_cat, 0) + 1
	ks.get_pawn_knowledge = func(_pid): return []
	ks.has_method = func(n): return n in ["has_knowledge", "get_carrier_count", "add_knowledge_carrier", "get_pawn_knowledge"]
	get_tree().root.add_child(ks)
	_ts._knowledge_system = ks

	var sd = Node.new()
	sd.get_friendship = func(_a, _b): return 0.0
	sd.add_interaction = func(_a, _b, _t, _w): pass
	sd.has_method = func(n): return n in ["get_friendship", "add_interaction"]
	get_tree().root.add_child(sd)
	_ts._social_dynamics = sd

	var eb = Node.new()
	eb.subs = {}
	eb.emitted = []
	eb.subscribe = func(evt, obj, cb): eb.subs[evt] = {"obj": obj, "cb": cb}
	eb.emit = func(evt, args): eb.emitted.append({"evt": evt, "args": args})
	eb.has_method = func(n): return n in ["subscribe", "emit"]
	get_tree().root.add_child(eb)
	_ts._event_bus = eb

	var wm = Node.new()
	wm.events = []
	wm.record_event = func(d): wm.events.append(d)
	wm.has_method = func(n): return n in ["record_event"]
	get_tree().root.add_child(wm)
	_ts._world_memory = wm

	var sm = Node.new()
	sm.get = func(k, d): return sm._data.get(k, d)
	sm._data = {"settlements": []}
	get_tree().root.add_child(sm)
	_ts._settlement_memory = sm

	var gm = Node.new()
	gm.tick_count = 10000
	gm.verbose_logs = false
	gm.connect = func(sig, obj, method, _flags = 0): gm._signal_conns = gm._signal_conns if "signal_conns" in gm else {}; gm._signal_conns[sig] = {"obj": obj, "method": method}
	gm._signal_conns = {}
	gm.has_signal = func(_n): return true
	gm.has_method = func(n): return n in ["connect", "has_signal"]
	get_tree().root.add_child(gm)
	_ts._game_manager = gm

	var ps = Node.new()
	ps._pawn_nodes = {1: null, 2: null, 3: null, 10: null, 20: null, 30: null, 40: null}
	ps.has_method = func(n): return n in ["_get_pawn_node"]
	get_tree().root.add_child(ps)
	_ts._pawn_spawner = ps

	var wrng = Node.new()
	wrng.stream_seed = 42
	wrng.range_for = func(_key, lo, hi, _salt = 0): return (lo + hi) / 2.0
	wrng.chance_for = func(_key, _prob, _salt = 0): return true
	wrng.rng_for = func(_key): var r = RandomNumberGenerator.new(); r.seed = 42; return r
	wrng.has_method = func(n): return n in ["range_for", "chance_for", "rng_for", "unit_for"]
	wrng.unit_for = func(_key, _salt = 0): return 0.5
	get_tree().root.add_child(wrng)
	_ts._world_rng = wrng

	_ts._pawn_get_settlement = func(pid):
		var map = {1: 5, 2: 5, 3: 5, 10: 5, 20: 5, 30: 5, 40: 5}
		return map.get(pid, -1)


func _test_effectiveness_basic() -> void:
	print("\n--- Effectiveness Basic ---")
	var e1 = _ts._calculate_effectiveness(5, 3, false, 0.0)
	_assert(e1 > 0, "skilled teacher gives positive effectiveness (%.4f)" % e1)

	var e2 = _ts._calculate_effectiveness(1, 10, false, 0.0)
	_assert(e2 < 0.5, "low-skill teacher gives low effectiveness (%.4f)" % e2)

	var e_no = _ts._calculate_effectiveness(5, 3, false, 0.0)
	var e_li = _ts._calculate_effectiveness(5, 3, true, 0.0)
	_assert(e_li > e_no, "library bonus boosts effectiveness (%.4f vs %.4f)" % [e_li, e_no])

	var e_nf = _ts._calculate_effectiveness(5, 3, false, 0.0)
	var e_fr = _ts._calculate_effectiveness(5, 3, false, 0.25)
	_assert(e_fr > e_nf, "friendship multiplier boosts effectiveness (%.4f vs %.4f)" % [e_fr, e_nf])

	var e_a = _ts._calculate_effectiveness(5, 3, false, 0.0)
	var e_b = _ts._calculate_effectiveness(5, 3, false, 0.0)
	_assert(abs(e_a - e_b) < 0.001, "deterministic for same inputs (%.6f vs %.6f)" % [e_a, e_b])


func _test_duration_scaling() -> void:
	print("\n--- Duration Scaling ---")
	var fast = _ts._calculate_duration(3, 10, 0.5)
	var slow = _ts._calculate_duration(3, 1, 0.5)
	_assert(slow > fast, "low-skill teacher takes longer (%.0f vs %.0f)" % [slow, fast])

	var easy = _ts._calculate_duration(1, 5, 0.5)
	var hard = _ts._calculate_duration(21, 5, 0.5)
	_assert(hard > easy, "harder categories take longer (%.0f vs %.0f)" % [hard, easy])

	var d1 = _ts._calculate_duration(3, 5, 0.5)
	var d2 = _ts._calculate_duration(3, 5, 0.5)
	_assert(d1 == d2, "deterministic duration (%.0f)" % d1)


func _test_lesson_lifecycle() -> void:
	print("\n--- Lesson Lifecycle ---")
	_ts.clear()

	var ks = _ts._knowledge_system
	ks._mock_has = {}
	for i in range(30):
		ks._mock_has[i] = true
		ks._mock_carriers[i] = 2

	_ts._game_manager.tick_count = 5000

	var lid = _ts.start_lesson(1, 2, 3)
	_assert(lid > 0, "start_lesson returns valid id (%d)" % lid)

	var lesson = _ts._active_lessons.get(lid, {})
	_assert(not lesson.is_empty(), "lesson in active_lessons")
	_assert(lesson.teacher_id == 1, "teacher_id=%d" % lesson.teacher_id)
	_assert(lesson.student_id == 2, "student_id=%d" % lesson.student_id)
	_assert(lesson.category == 3, "category=%d" % lesson.category)
	_assert(lesson.tick_started == 5000, "tick_started=%d" % lesson.tick_started)
	_assert(not lesson.completed, "not yet completed")

	_assert(_ts._lessons_history.has(lid), "lesson in history")

	lid = _ts.start_lesson(1, 3, 1)
	_assert(lid > 0, "teacher can teach second student")

	lid = _ts.start_lesson(1, 4, 1)
	_assert(lid > 0, "teacher can teach third student (max 3)")

	lid = _ts.start_lesson(1, 5, 1)
	_assert(lid == -1, "teacher at max capacity (%d)" % lid)


func _test_lesson_failure_events() -> void:
	print("\n--- Lesson Failure Events ---")
	_ts.clear()
	var ks = _ts._knowledge_system
	ks._mock_has = {}
	for i in range(30):
		ks._mock_has[i] = true
		ks._mock_carriers[i] = 2

	_ts._game_manager.tick_count = 10000

	var eb = _ts._event_bus
	eb.emitted = []

	var lid = _ts.start_lesson(10, 20, 3)
	_assert(lid > 0, "started lesson for failure test")

	var events_before = eb.emitted.size()
	_ts._on_pawn_died({"pawn_id": 10})
	var lesson_gone = not _ts._active_lessons.has(lid) or _ts._active_lessons.get(lid, {}).get("completed", false)
	_assert(lesson_gone, "teacher death clears lesson")

	eb.emitted = []
	_ts.clear()
	lid = _ts.start_lesson(30, 40, 2)
	_assert(lid > 0, "started lesson for student death test")

	_ts._on_pawn_died({"pawn_id": 40})
	lesson_gone = not _ts._active_lessons.has(lid) or _ts._active_lessons.get(lid, {}).get("completed", false)
	_assert(lesson_gone, "student death clears lesson")


func _test_invalid_inputs() -> void:
	print("\n--- Invalid Inputs ---")
	_ts.clear()
	var ks = _ts._knowledge_system
	ks._mock_has = {}
	for i in range(30):
		ks._mock_has[i] = true
		ks._mock_carriers[i] = 2

	var lid

	lid = _ts.start_lesson(0, 1, 2)
	_assert(lid == -1, "teacher_id=0 returns -1")

	lid = _ts.start_lesson(1, 0, 2)
	_assert(lid == -1, "student_id=0 returns -1")

	lid = _ts.start_lesson(1, 2, -1)
	_assert(lid == -1, "category=-1 returns -1")

	lid = _ts.start_lesson(1, 1, 2)
	_assert(lid == -1, "self-teaching returns -1")


func _test_cancel_lesson() -> void:
	print("\n--- Cancel Lesson ---")
	_ts.clear()
	var ks = _ts._knowledge_system
	ks._mock_has = {}
	for i in range(30):
		ks._mock_has[i] = true
		ks._mock_carriers[i] = 2
	_ts._game_manager.tick_count = 15000

	var lid = _ts.start_lesson(2, 3, 1)
	_assert(lid > 0, "lesson started for cancel test")

	var cancelled = _ts.cancel_lesson(lid)
	_assert(cancelled, "cancel_lesson returns true")
	_assert(not _ts._active_lessons.has(lid), "lesson removed from active after cancel")

	cancelled = _ts.cancel_lesson(99999)
	_assert(not cancelled, "cancel unknown lesson returns false")

	cancelled = _ts.cancel_lesson(-1)
	_assert(not cancelled, "cancel invalid id returns false")


func _test_save_load_roundtrip() -> void:
	print("\n--- Save/Load Roundtrip ---")
	_ts.clear()

	var save = _ts.get_save_state()
	_assert(save is Dictionary, "get_save_state returns Dictionary")
	_assert(save.has("_next_lesson_id"), "save has _next_lesson_id")
	_assert(save.has("_teacher_xp"), "save has _teacher_xp")
	_assert(save.has("_lessions_history"), "save has _lessions_history")
	_assert(save.has("_completed_lesson_count"), "save has completed count")
	_assert(save.has("_failed_lesson_count"), "save has failed count")
	_assert(save.has("_total_effectiveness_sum"), "save has effectiveness sum")

	_ts._completed_lesson_count = 42
	_ts._failed_lesson_count = 7
	_ts._total_effectiveness_sum = 156.0
	var save2 = _ts.get_save_state()

	_ts.clear()
	_ts.load_state(save2)
	_assert(_ts._completed_lesson_count == 42, "restored completed count (%d)" % _ts._completed_lesson_count)
	_assert(_ts._failed_lesson_count == 7, "restored failed count (%d)" % _ts._failed_lesson_count)
	_assert(abs(_ts._total_effectiveness_sum - 156.0) < 0.001, "restored effectiveness sum (%.2f)" % _ts._total_effectiveness_sum)

	_ts.clear()
	_ts.load_state({"garbage": true})
	_assert(true, "loading garbage does not crash")


func _test_clear() -> void:
	print("\n--- Clear ---")
	_ts._next_lesson_id = 500
	_ts._active_lessons = {1: {"test": true}}
	_ts._teacher_xp = {1: 100.0}
	_ts._completed_lesson_count = 10
	_ts._failed_lesson_count = 3
	_ts._total_effectiveness_sum = 50.0
	_ts.clear()

	_assert(_ts._active_lessons.is_empty(), "active_lessons empty after clear")
	_assert(_ts._next_lesson_id == 1, "next_lesson_id reset to 1 (%d)" % _ts._next_lesson_id)
	_assert(_ts._teacher_xp.is_empty(), "teacher_xp empty after clear")
	_assert(_ts._completed_lesson_count == 0, "completed count reset (%d)" % _ts._completed_lesson_count)
	_assert(_ts._failed_lesson_count == 0, "failed count reset (%d)" % _ts._failed_lesson_count)


func _test_stats() -> void:
	print("\n--- Stats ---")
	_ts._teacher_xp = {1: 120.0, 2: 80.0}
	_ts._completed_lesson_count = 15
	_ts._failed_lesson_count = 3
	_ts._total_effectiveness_sum = 45.0

	var stats = _ts.get_stats()
	_assert(stats is Dictionary, "get_stats returns Dictionary")
	_assert(stats.has("completed_lessons"), "stats has completed_lessons")
	_assert(stats.has("failed_lessons"), "stats has failed_lessons")
	_assert(stats.has("total_lessons"), "stats has total_lessons")
	_assert(stats.get("completed_lessons") >= 0, "completed_lessons >= 0")
	_assert(stats.get("failed_lessons") >= 0, "failed_lessons >= 0")

	var report = _ts.get_teacher_report(1)
	_assert(report is Dictionary, "get_teacher_report returns Dictionary")
	_assert(report.get("teacher_id") == 1, "teacher report has correct id (%d)" % report.get("teacher_id"))

	report = _ts.get_teacher_report(999)
	_assert(report.get("teacher_id") == 999, "unknown teacher returns report (%d)" % report.get("teacher_id"))

	report = _ts.get_student_report(1)
	_assert(report is Dictionary, "get_student_report returns Dictionary")


func _test_find_teachers_for_student() -> void:
	print("\n--- Matchmaking ---")
	_ts.clear()
	var ks = _ts._knowledge_system
	ks._mock_has = {}
	ks._mock_carriers = {}
	for i in range(30):
		ks._mock_has[i] = true
		ks._mock_carriers[i] = 2

	var teachers = _ts.find_teachers_for_student(2, 3)
	_assert(teachers is Array, "find_teachers returns Array")

	if teachers.size() > 0:
		_assert(teachers[0] is Dictionary, "first result is Dictionary")
		_assert(teachers[0].has("teacher_id"), "result has teacher_id")
		_assert(teachers[0].has("estimated_effectiveness"), "result has estimated_effectiveness")

	var students = _ts.find_students_for_teacher(1, 3)
	_assert(students is Array, "find_students returns Array")
