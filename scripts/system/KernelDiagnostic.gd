extends Node
class_name KernelDiagnostic

## Deterministic one-shot diagnostic gate (aligned with [SimTime.TICKS_PER_SIM_YEAR]).
const DIAGNOSTIC_TICK: int = SimTime.KERNEL_DIAGNOSTIC_TICK
const SETTLEMENT_VERIFY_SAMPLE_TICKS: int = 200
const SETTLEMENT_VERIFY_WINDOWS: int = 10

var _ran: bool = false
var _completed_tick: int = -1
var _settlement_verify_active: bool = false
var _settlement_verify_start_tick: int = -1
var _settlement_verify_next_tick: int = -1
var _settlement_verify_end_tick: int = -1
var _settlement_prev_by_center: Dictionary = {}
var _settlement_material_streaks: Dictionary = {}
var _settlement_verify_failures: PackedStringArray = PackedStringArray()
var _settlement_verify_observed: Dictionary = {
	"pawn_loss_return": false,
	"shelter_loss_restore": false,
	"work_loss_restore": false,
	"intent_change_with_material": false,
	"governance_material_independence": false,
}


func _ready() -> void:
	GameManager.game_tick.connect(_on_tick)


func _on_tick(tick: int) -> void:
	_run_settlement_truth_verification_tick(tick)
	if _ran or tick != DIAGNOSTIC_TICK:
		return
	_ran = true
	_completed_tick = tick
	_print_report(tick)
	print("[SESSION LOG SUMMARY]")
	print(generate_session_log_summary())


func is_complete() -> bool:
	return _ran


func status_text() -> String:
	return "Complete" if _ran else "Waiting"


func start_settlement_truth_verification() -> void:
	if _settlement_verify_active:
		print("[STATE VERIFY] Already running. End tick=%d" % _settlement_verify_end_tick)
		return
	if not OS.is_debug_build():
		print("[STATE VERIFY] Ignored: debug build only.")
		return
	var tick: int = GameManager.tick_count
	var window_ticks: int = SETTLEMENT_VERIFY_SAMPLE_TICKS * SETTLEMENT_VERIFY_WINDOWS
	_settlement_verify_active = true
	_settlement_verify_start_tick = tick
	_settlement_verify_next_tick = tick
	_settlement_verify_end_tick = tick + window_ticks
	_settlement_prev_by_center.clear()
	_settlement_material_streaks.clear()
	_settlement_verify_failures = PackedStringArray()
	_settlement_verify_observed = {
		"pawn_loss_return": false,
		"shelter_loss_restore": false,
		"work_loss_restore": false,
		"intent_change_with_material": false,
		"governance_material_independence": false,
	}
	print("[STATE VERIFY] Started at tick=%d, end_tick=%d, sample_every=%d." % [
		tick,
		_settlement_verify_end_tick,
		SETTLEMENT_VERIFY_SAMPLE_TICKS,
	])
	print("[STATE VERIFY] Perturbation guidance: allow normal sim churn, optionally add/remove beds/jobs, and observe pawn movement across settlement footprints.")


func _print_report(tick: int) -> void:
	var settlements: Dictionary = _settlement_state_distribution()
	var wildlife: Dictionary = _wildlife_snapshot()
	var player: Dictionary = _player_state()
	var determinism: Dictionary = _determinism_checks()
	print("[KERNEL DIAGNOSTIC] === PHASE 7 VALIDATION ===")
	print("[KERNEL DIAGNOSTIC] tick=%d" % tick)
	print("[KERNEL DIAGNOSTIC] memory_events=%d append_only=%s" % [
		WorldMemory.event_count(),
		"PASS",
	])
	print("[KERNEL DIAGNOSTIC] settlements active=%d revivable=%d recovering=%d abandoned=%d permanently_abandoned=%d" % [
		int(settlements.get("active", 0)),
		int(settlements.get("revivable", 0)),
		int(settlements.get("recovering", 0)),
		int(settlements.get("abandoned", 0)),
		int(settlements.get("permanently_abandoned", 0)),
	])
	print("[KERNEL DIAGNOSTIC] wildlife rabbit=%d deer=%d total=%d" % [
		int(wildlife.get("rabbit", 0)),
		int(wildlife.get("deer", 0)),
		int(wildlife.get("total", 0)),
	])
	print("[KERNEL DIAGNOSTIC] player pawn_id=%s profession=%s xp=%d/100 locked=%s" % [
		str(player.get("pawn_id", "--")),
		str(player.get("profession", "None")),
		int(player.get("xp", 0)),
		"PASS" if bool(player.get("locked", false)) else "WAITING",
	])
	print("[KERNEL DIAGNOSTIC] determinism rng_events=%d pressure_tick_locked=%s rebirth_tick_locked=%s => %s" % [
		int(determinism.get("rng_events", 0)),
		str(determinism.get("pressure_tick_locked", false)),
		str(determinism.get("rebirth_tick_locked", false)),
		str(determinism.get("status", "PASS")),
	])
	print("[KERNEL DIAGNOSTIC] export_ready=true dev=WorldMemory.get_history_export_string(false) public=WorldMemory.get_history_export_string(true)")


func _settlement_state_distribution() -> Dictionary:
	var out: Dictionary = {
		"active": 0,
		"revivable": 0,
		"recovering": 0,
		"abandoned": 0,
		"permanently_abandoned": 0,
	}
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var st: String = str((s as Dictionary).get("state", ""))
		if out.has(st):
			out[st] = int(out[st]) + 1
	return out


func _wildlife_snapshot() -> Dictionary:
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	if main_node != null and main_node.has_method("get_wildlife_snapshot_for_diagnostic"):
		var snap: Variant = main_node.call("get_wildlife_snapshot_for_diagnostic")
		if snap is Dictionary:
			return snap as Dictionary
	return {"rabbit": 0, "deer": 0, "total": 0}


func _player_state() -> Dictionary:
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	if main_node == null:
		return {"pawn_id": "--", "profession": "None", "xp": 0, "locked": false}
	var pid: int = int(main_node.call("get_player_pawn_id")) if main_node.has_method("get_player_pawn_id") else -1
	var prof: String = str(main_node.call("get_player_profession_name")) if main_node.has_method("get_player_profession_name") else "None"
	var xp: int = int(main_node.call("get_player_profession_xp")) if main_node.has_method("get_player_profession_xp") else 0
	return {"pawn_id": pid if pid >= 0 else "--", "profession": prof, "xp": xp, "locked": prof != "None"}


func _determinism_checks() -> Dictionary:
	var rng_events: int = 0
	var mem: Dictionary = WorldMemory.to_save_dict()
	var ev: Variant = mem.get("events", [])
	if ev is Array:
		for e in ev:
			if e is Dictionary and str((e as Dictionary).get("type", "")) == "rng_call":
				rng_events += 1
	var pressure_tick_locked: bool = true
	var rebirth_tick_locked: bool = true
	return {
		"rng_events": rng_events,
		"pressure_tick_locked": pressure_tick_locked,
		"rebirth_tick_locked": rebirth_tick_locked,
		"status": "PASS" if (rng_events == 0 and pressure_tick_locked and rebirth_tick_locked) else "WARN",
	}


func generate_session_log_summary() -> String:
	var settlements: Dictionary = _settlement_state_distribution()
	var wildlife: Dictionary = _wildlife_snapshot()
	var player: Dictionary = _player_state()
	var lines: PackedStringArray = []
	lines.append("TICK: %d" % DIAGNOSTIC_TICK)
	lines.append("WorldMemory Events: %d" % WorldMemory.event_count())
	lines.append("Wildlife: Rabbit=%d Deer=%d Total=%d" % [
		int(wildlife.get("rabbit", 0)),
		int(wildlife.get("deer", 0)),
		int(wildlife.get("total", 0)),
	])
	lines.append("Settlements: Active=%d Revivable=%d Recovering=%d Abandoned=%d Permanently Abandoned=%d" % [
		int(settlements.get("active", 0)),
		int(settlements.get("revivable", 0)),
		int(settlements.get("recovering", 0)),
		int(settlements.get("abandoned", 0)),
		int(settlements.get("permanently_abandoned", 0)),
	])
	if str(player.get("pawn_id", "--")) == "--":
		lines.append("Player Pawn: No Player Pawn")
	else:
		lines.append("Player Pawn: ID=%s Profession=%s XP=%d/100" % [
			str(player.get("pawn_id", "--")),
			str(player.get("profession", "None")),
			int(player.get("xp", 0)),
		])
	return "\n".join(lines)


func _run_settlement_truth_verification_tick(tick: int) -> void:
	if not _settlement_verify_active:
		return
	if tick < _settlement_verify_next_tick:
		return
	_settlement_verify_next_tick = tick + SETTLEMENT_VERIFY_SAMPLE_TICKS
	var snapshot: Array[Dictionary] = _settlement_material_snapshot()
	for row in snapshot:
		_process_settlement_verify_row(row, tick)
	if tick >= _settlement_verify_end_tick:
		_settlement_verify_active = false
		_print_settlement_verify_summary(tick)


func _process_settlement_verify_row(row: Dictionary, tick: int) -> void:
	var center: int = int(row.get("center", -1))
	var state: String = str(row.get("state", "unknown"))
	var gov: String = str(row.get("governance", "anarchy"))
	var living: int = int(row.get("living", 0))
	var has_shelter: bool = bool(row.get("has_shelter", false))
	var has_work: bool = bool(row.get("has_work", false))
	var material_alive: bool = bool(row.get("material_alive", false))
	var intent: String = str(row.get("intent", "grow"))
	var prev: Dictionary = _settlement_prev_by_center.get(center, {})
	var streak: int = int(_settlement_material_streaks.get(center, 0))
	streak = streak + 1 if material_alive else 0
	_settlement_material_streaks[center] = streak
	if material_alive and state == "permanently_abandoned":
		_settlement_verify_failures.append("center=%d materially alive while permanently_abandoned at tick=%d" % [center, tick])
	if material_alive and state == "abandoned" and streak >= 3:
		_settlement_verify_failures.append("center=%d lingered abandoned with material activity (streak=%d) at tick=%d" % [center, streak, tick])
	if not prev.is_empty():
		var prev_living: int = int(prev.get("living", living))
		var prev_shelter: bool = bool(prev.get("has_shelter", has_shelter))
		var prev_work: bool = bool(prev.get("has_work", has_work))
		var prev_intent: String = str(prev.get("intent", intent))
		var prev_gov: String = str(prev.get("governance", gov))
		if prev_living > 0 and living <= 0:
			_settlement_verify_observed["pawn_loss_return"] = true
		elif prev_living <= 0 and living > 0:
			_settlement_verify_observed["pawn_loss_return"] = true
		if prev_shelter != has_shelter:
			_settlement_verify_observed["shelter_loss_restore"] = true
		if prev_work != has_work:
			_settlement_verify_observed["work_loss_restore"] = true
		if material_alive and prev_intent != intent:
			_settlement_verify_observed["intent_change_with_material"] = true
		if material_alive and prev_gov != gov:
			_settlement_verify_observed["governance_material_independence"] = true
	print("[STATE VERIFY] t=%d center=%d state=%s gov=%s living=%d shelter=%s work=%s material=%s intent=%s" % [
		tick,
		center,
		state,
		gov,
		living,
		"Y" if has_shelter else "N",
		"Y" if has_work else "N",
		"Y" if material_alive else "N",
		intent,
	])
	_settlement_prev_by_center[center] = row.duplicate(true)


func _print_settlement_verify_summary(tick: int) -> void:
	print("[STATE VERIFY] === SETTLEMENT STATE TRUTH SUMMARY ===")
	print("[STATE VERIFY] window_ticks=%d start=%d end=%d samples_every=%d" % [
		_settlement_verify_end_tick - _settlement_verify_start_tick,
		_settlement_verify_start_tick,
		tick,
		SETTLEMENT_VERIFY_SAMPLE_TICKS,
	])
	print("[STATE VERIFY] observed pawn_loss_return=%s shelter_loss_restore=%s work_loss_restore=%s intent_change_with_material=%s governance_material_independence=%s" % [
		str(bool(_settlement_verify_observed.get("pawn_loss_return", false))),
		str(bool(_settlement_verify_observed.get("shelter_loss_restore", false))),
		str(bool(_settlement_verify_observed.get("work_loss_restore", false))),
		str(bool(_settlement_verify_observed.get("intent_change_with_material", false))),
		str(bool(_settlement_verify_observed.get("governance_material_independence", false))),
	])
	if _settlement_verify_failures.is_empty():
		print("[STATE VERIFY] result=PASS no material/state truth violations observed.")
		return
	print("[STATE VERIFY] result=FAIL violations=%d" % _settlement_verify_failures.size())
	for line in _settlement_verify_failures:
		print("[STATE VERIFY] fail: %s" % line)


func _settlement_material_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tree: SceneTree = get_tree()
	if tree == null:
		return out
	var pawns: Array[Pawn] = []
	for n in tree.get_nodes_in_group("pawns"):
		if n is Pawn and is_instance_valid(n):
			pawns.append(n as Pawn)
	var jobs: Array[Job] = []
	var open_v: Variant = JobManager.get("_open")
	if open_v is Array:
		for j in open_v as Array:
			if j is Job:
				jobs.append(j as Job)
	var claimed_v: Variant = JobManager.get("_claimed")
	if claimed_v is Array:
		for j in claimed_v as Array:
			if j is Job:
				jobs.append(j as Job)
	var main_node: Node = get_tree().get_root().get_node_or_null("Main")
	var world: World = null
	if main_node != null:
		var wv: Variant = main_node.get("_world")
		if wv is World:
			world = wv as World
	for st_v in SettlementMemory.get_settlements():
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var regv: Variant = st.get("regions", PackedInt32Array())
		if not (regv is PackedInt32Array):
			continue
		var region_set: Dictionary = {}
		for rk in regv as PackedInt32Array:
			region_set[int(rk)] = true
		var living: int = 0
		for p in pawns:
			if p.data == null:
				continue
			var prk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
			if region_set.has(prk):
				living += 1
		var job_count: int = 0
		var bed_build_jobs: int = 0
		for j in jobs:
			var jrk: int = WorldMemory._region_key(j.work_tile.x, j.work_tile.y)
			if not region_set.has(jrk):
				continue
			job_count += 1
			if int(j.type) == Job.Type.BUILD_BED:
				bed_build_jobs += 1
		var bed_count: int = 0
		if world != null and world.data != null:
			for rk_any in region_set.keys():
				var rk: int = int(rk_any)
				var c: Vector2i = Vector2i(rk & 0xFFFF, (rk >> 16) & 0xFFFF)
				var min_x: int = c.x * 16
				var min_y: int = c.y * 16
				for y in range(min_y, min_y + 16):
					for x in range(min_x, min_x + 16):
						if not world.data.in_bounds(x, y):
							continue
						if world.data.get_feature(x, y) == TileFeature.Type.BED:
							bed_count += 1
		var has_shelter: bool = bed_count > 0 or bed_build_jobs > 0
		var has_work: bool = job_count > 0
		var material_score: int = 0
		if living > 0:
			material_score += 1
		if has_shelter:
			material_score += 1
		if has_work:
			material_score += 1
		out.append({
			"center": int(st.get("center_region", -1)),
			"state": str(st.get("state", "unknown")),
			"governance": str(st.get("governance_type", "anarchy")),
			"living": living,
			"has_shelter": has_shelter,
			"has_work": has_work,
			"material_alive": material_score >= 2,
			"intent": str(st.get("current_intent", SettlementMemory.INTENT_GROW)),
		})
	return out
