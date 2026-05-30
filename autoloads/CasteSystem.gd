extends Node
## CasteSystem — birth-based caste assignment with occupational restrictions.
##
## Five-tier varna system inherited at birth: brahmin, kshatriya, vaishya,
## shudra, outcast. Mobility between castes is extremely rare and requires
## exceptional deeds (heroism, discovery, cataclysm survival).
##
## Tick-based enforcement checks all pawns for caste-appropriate jobs and
## applies penalties (happiness, work speed, social standing) for violations.
## Higher castes receive privilege bonuses for appropriate occupations.
## Inter-caste interactions (romance, alliance) incur additional social cost.
##
## Integrates with EventBus, WorldMemory, BloodlineSystem, KinshipSystem,
## SocialDynamics, PawnAccess, and SettlementMemory.

signal caste_changed(pawn_id: int, from_caste: int, to_caste: int, reason: String)
signal caste_violation(pawn_id: int, caste: int, job_name: String, severity: float)
signal caste_mobility(pawn_id: int, old_caste: int, new_caste: int, deed_type: String)

const CASTE_CHECK_INTERVAL: int = 2000
const MOBILITY_CHANCE_BASE: float = 0.002
const PENALTY_HAPPINESS_BASE: float = -0.15
const PENALTY_WORK_SPEED_BASE: float = -0.25
const PENALTY_SOCIAL_STANDING_BASE: float = -0.20
const PRIVILEGE_WORK_SPEED_BONUS: float = 0.12
const INTER_CASTE_ROMANCE_COST_MULTIPLIER: float = 1.8
const INTER_CASTE_ALLIANCE_COST_MULTIPLIER: float = 1.4
const MAX_VIOLATION_LOG: int = 200
const MAX_SETTLEMENT_REGISTRY: int = 500
const CASTE_COLLAPSE_THRESHOLD: float = 0.10
const SINGLE_CASTE_POPULATION_MIN: int = 3

enum CasteType {
	NONE = -1,
	BRAHMIN = 0,
	KSHATRIYA = 1,
	VAISHYA = 2,
	SHRAMANA = 3,
	OUTCAST = 4,
}

const CASTE_NAMES: Dictionary = {
	CasteType.BRAHMIN: "Brahmin",
	CasteType.KSHATRIYA: "Kshatriya",
	CasteType.VAISHYA: "Vaishya",
	CasteType.SHRAMANA: "Shramana",
	CasteType.OUTCAST: "Outcast",
}

const CASTE_HIERARCHY: Array[int] = [
	CasteType.BRAHMIN,
	CasteType.KSHATRIYA,
	CasteType.VAISHYA,
	CasteType.SHRAMANA,
	CasteType.OUTCAST,
]

const CASTE_OCCUPATIONS: Dictionary = {
	CasteType.BRAHMIN: ["priest", "scholar", "teacher", "scribe", "healer", "astrologer"],
	CasteType.KSHATRIYA: ["warrior", "officer", "ruler", "guard", "general", "commander"],
	CasteType.VAISHYA: ["farmer", "merchant", "trader", "herder", "artisan", "craftsman"],
	CasteType.SHRAMANA: ["builder", "laborer", "cleaner", "porter", "digger", "hauler"],
	CasteType.OUTCAST: ["menial", "gravedigger", "tanner", "scavenger", "waste_hauler"],
}

const CASTE_PRIVILEGE_BY_CASTE: Dictionary = {
	CasteType.BRAHMIN: {"work_speed": 0.25, "social_standing": 0.30, "happiness": 0.10},
	CasteType.KSHATRIYA: {"work_speed": 0.20, "social_standing": 0.20, "happiness": 0.05},
	CasteType.VAISHYA: {"work_speed": 0.10, "social_standing": 0.10, "happiness": 0.02},
	CasteType.SHRAMANA: {"work_speed": 0.00, "social_standing": 0.00, "happiness": 0.00},
	CasteType.OUTCAST: {"work_speed": -0.10, "social_standing": -0.15, "happiness": -0.05},
}

const MOBILITY_DEEDS: Dictionary = {
	"heroism": CasteType.KSHATRIYA,
	"discovery": CasteType.BRAHMIN,
	"cataclysm_survival": CasteType.KSHATRIYA,
	"exceptional_trade": CasteType.VAISHYA,
	"master_craft": CasteType.VAISHYA,
	"divine_blessing": CasteType.BRAHMIN,
	"martial_victory": CasteType.KSHATRIYA,
	"great_construction": CasteType.VAISHYA,
}

var _pawn_caste: Dictionary = {}
var _pawn_violation_log: Dictionary = {}
var _settlement_caste_system: Dictionary = {}
var _settlement_last_profile: Dictionary = {}
var _caste_mobility_log: Array[Dictionary] = []
var _last_check_tick: int = -999999
var _orphaned_pawns: Array[int] = []
var _total_mobility_events: int = 0
var _total_violations_recorded: int = 0
var _caste_locked_settlements: Dictionary = {}

var _GameManager: Variant = null
var _WorldMemory: Variant = null
var _WorldRNG: Variant = null
var _EventBus: Variant = null
var _BloodlineSystem: Variant = null
var _KinshipSystem: Variant = null
var _SocialDynamics: Variant = null
var _SettlementMemory: Variant = null
var _PawnAccess: Variant = null

func _ready() -> void:
	_GameManager = get_node_or_null("/root/GameManager")
	_WorldMemory = get_node_or_null("/root/WorldMemory")
	_WorldRNG = get_node_or_null("/root/WorldRNG")
	_EventBus = get_node_or_null("/root/EventBus")
	_BloodlineSystem = get_node_or_null("/root/BloodlineSystem")
	_KinshipSystem = get_node_or_null("/root/KinshipSystem")
	_SocialDynamics = get_node_or_null("/root/SocialDynamics")
	_SettlementMemory = get_node_or_null("/root/SettlementMemory")
	_PawnAccess = get_node_or_null("/root/PawnAccess")
	if _GameManager != null and _GameManager.has_signal("game_tick"):
		_GameManager.game_tick.connect(_on_game_tick)
	if _EventBus != null and _EventBus.has_method("subscribe"):
		if _EventBus.has_method("EVENT_PAWN_BORN"):
			_EventBus.subscribe("pawn_born", self, "_on_event_pawn_born")
		if _EventBus.has_method("EVENT_SETTLEMENT_FOUNDED"):
			_EventBus.subscribe("settlement_founded", self, "_on_event_settlement_founded")
		if _EventBus.has_method("EVENT_SETTLEMENT_ATTACKED"):
			_EventBus.subscribe("settlement_attacked", self, "_on_event_settlement_attacked")
		if _EventBus.has_method("EVENT_PAWN_DIED"):
			_EventBus.subscribe("pawn_died", self, "_on_event_pawn_died")

func _on_game_tick(tick: int) -> void:
	if tick - _last_check_tick < CASTE_CHECK_INTERVAL:
		return
	_last_check_tick = tick
	if _SettlementMemory == null:
		return
	var settlements_v: Variant = _SettlementMemory.get("settlements", [])
	if settlements_v == null or not (settlements_v is Array):
		return
	var settlements: Array = settlements_v as Array
	for idx in range(settlements.size()):
		var st_v: Variant = settlements[idx]
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_update_caste_system(st, center, tick)
	for idx in range(settlements.size()):
		var st_v: Variant = settlements[idx]
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_enforce_caste_occupations(center, tick)
	var orphan_cleanup: Array[int] = []
	for pid in _orphaned_pawns:
		if _resolve_orphan_caste(pid):
			orphan_cleanup.append(pid)
	for pid in orphan_cleanup:
		var idx_found: int = _orphaned_pawns.find(pid)
		if idx_found >= 0:
			_orphaned_pawns.remove_at(idx_found)

func _update_caste_system(st: Dictionary, center: int, tick: int) -> void:
	var trad: Variant = st.get("tradition", {})
	var has_caste: bool = false
	if trad is Dictionary:
		var taboo: Array = (trad as Dictionary).get("taboo_jobs", [])
		var taboo_str: String = str(taboo).to_lower()
		has_caste = "caste" in taboo_str or taboo.size() > 3
	if not has_caste:
		if _settlement_caste_system.has(center) and _settlement_caste_system[center]:
			on_caste_system_collapse(center, tick)
		_settlement_caste_system[center] = false
		return
	_settlement_caste_system[center] = true
	var pop: int = int(st.get("population", 0))
	if pop <= 0:
		return
	var pop_before: int = _settlement_last_profile.get(center, {}).get("total_tracked", 0)
	var rng_seed: int = absi(center * 7919 + tick)
	var pawns_in_settlement: Array = _get_pawns_in_settlement(center)
	var prev_distribution: Dictionary = _settlement_last_profile.get(center, {})
	for p in pawns_in_settlement:
		if p == null:
			continue
		var pid_v: Variant = _PawnAccess.call("pawn_data_for_id", p) if _PawnAccess != null and _PawnAccess.has_method("pawn_data_for_id") else null
		var pid: int = -1
		if pid_v != null and pid_v is HeelKawnianData:
			pid = int(pid_v.id)
		elif p is Node and p.has_method("get_id"):
			pid = int(p.call("get_id"))
		elif p is Node:
			pid = int(p.name)
		if pid < 0:
			continue
		if _pawn_caste.has(pid):
			_update_caste_stats(pid, center, tick)
			continue
		var parent_caste: int = _get_parent_caste(pid)
		if parent_caste >= 0:
			_pawn_caste[pid] = parent_caste
		else:
			var assigned: int = _assign_birth_caste(rng_seed ^ (pid * 486187739))
			_pawn_caste[pid] = assigned
			if assigned == CasteType.OUTCAST and _parent_info_available(pid) == false:
				if not _orphaned_pawns.has(pid):
					_orphaned_pawns.append(pid)
	var new_distribution: Dictionary = _compute_caste_distribution(pawns_in_settlement)
	_settlement_last_profile[center] = new_distribution
	if pop_before > 0 and prev_distribution.has("total_tracked"):
		_detect_caste_collapse(center, prev_distribution, new_distribution, tick)

func _get_pawns_in_settlement(center: int) -> Array:
	var out: Array = []
	if _PawnAccess != null and _PawnAccess.has_method("find_alive_pawns"):
		var all_pawns: Array = _PawnAccess.find_alive_pawns()
		for p in all_pawns:
			if p == null or not is_instance_valid(p):
				continue
			var pos_v: Variant = null
			if p.has_method("get_tile_pos"):
				pos_v = p.call("get_tile_pos")
			elif p.has_method("get_pos"):
				pos_v = p.call("get_pos")
			if pos_v == null:
				continue
			var pt: Vector2i = Vector2i(-1, -1)
			if pos_v is Vector2i:
				pt = pos_v as Vector2i
			elif pos_v is Dictionary and (pos_v as Dictionary).has("x") and (pos_v as Dictionary).has("y"):
				var pdd: Dictionary = pos_v as Dictionary
				pt = Vector2i(int(pdd["x"]), int(pdd["y"]))
			if pt.x < 0 or pt.y < 0:
				continue
			var p_center: int = pt.y * 256 + pt.x
			if abs(p_center - center) <= 10:
				out.append(p)
		return out
	var ps := get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if ps == null or not ps.has_method("pawns"):
		return out
	var direct_pawns_v: Variant = ps.call("pawns")
	if direct_pawns_v is Array:
		var direct_pawns: Array = direct_pawns_v as Array
		for p in direct_pawns:
			if p == null or not is_instance_valid(p) or p.data == null:
				continue
			var pt: Vector2i = p.data.tile_pos if "tile_pos" in p.data else Vector2i(-1, -1)
			if pt.x < 0:
				continue
			var p_center: int = pt.y * 256 + pt.x
			if abs(p_center - center) <= 10:
				out.append(p)
	return out

func _get_parent_caste(pawn_id: int) -> int:
	var parent_ids: Array = []
	if _BloodlineSystem != null and _BloodlineSystem.has_method("get_parents"):
		var result: Variant = _BloodlineSystem.call("get_parents", pawn_id)
		if result is Array:
			parent_ids = result as Array
	if parent_ids.is_empty() and _KinshipSystem != null and _KinshipSystem.has_method("_parent_ids"):
		var kresult: Variant = _KinshipSystem.call("_parent_ids", pawn_id)
		if kresult is Array:
			parent_ids = kresult as Array
	if parent_ids.is_empty():
		var bfs_result: Variant = _get_fallback_parents(pawn_id)
		if bfs_result is Array:
			parent_ids = bfs_result as Array
	if parent_ids.is_empty():
		return -1
	for parent_v in parent_ids:
		var pid: int = int(parent_v) if parent_v is int else -1
		if pid < 0:
			continue
		if _pawn_caste.has(pid):
			return _pawn_caste[pid]
	return -1

func _get_fallback_parents(pawn_id: int) -> Array:
	var out: Array = []
	if _PawnAccess != null and _PawnAccess.has_method("pawn_data_for_id"):
		var pdata: Variant = _PawnAccess.call("pawn_data_for_id", pawn_id)
		if pdata != null:
			if pdata.has_method("get_parent_a_id"):
				var pa: int = int(pdata.call("get_parent_a_id"))
				if pa >= 0:
					out.append(pa)
			if pdata.has_method("get_parent_b_id"):
				var pb: int = int(pdata.call("get_parent_b_id"))
				if pb >= 0:
					out.append(pb)
	return out

func _parent_info_available(pawn_id: int) -> bool:
	var pa: int = -1
	var pb: int = -1
	if _PawnAccess != null and _PawnAccess.has_method("pawn_data_for_id"):
		var pdata: Variant = _PawnAccess.call("pawn_data_for_id", pawn_id)
		if pdata != null:
			if pdata.has_method("get_parent_a_id"):
				pa = int(pdata.call("get_parent_a_id"))
			if pdata.has_method("get_parent_b_id"):
				pb = int(pdata.call("get_parent_b_id"))
	return pa >= 0 or pb >= 0

func _resolve_orphan_caste(pawn_id: int) -> bool:
	if not _pawn_caste.has(pawn_id):
		return false
	var parent_caste: int = _get_parent_caste(pawn_id)
	if parent_caste < 0:
		return false
	_pawn_caste[pawn_id] = parent_caste
	return true

func _update_caste_stats(pid: int, center: int, tick: int) -> void:
	if not _PawnAccess.has_method("pawn_data_for_id"):
		return
	var pdata: Variant = _PawnAccess.call("pawn_data_for_id", pid)
	if pdata == null:
		return
	var current_job: String = ""
	if pdata.has_method("get_current_job"):
		current_job = str(pdata.call("get_current_job")).to_lower()
	elif pdata.has("current_profession"):
		var prof_code: int = int(pdata.current_profession)
		var prof_names: Dictionary = {0: "farmer", 1: "builder", 2: "warrior", 3: "scholar", 4: "trader", 5: "healer", 6: "artisan"}
		current_job = prof_names.get(prof_code, str(prof_code))
	if current_job.is_empty():
		return
	var caste: int = _pawn_caste.get(pid, CasteType.NONE)
	if caste == CasteType.NONE:
		return
	if not _is_job_allowed_for_caste(current_job, caste):
		_apply_caste_penalty(pid, caste, current_job, tick)

func _is_job_allowed_for_caste(job_name: String, caste: int) -> bool:
	if caste == CasteType.NONE:
		return true
	var allowed: Array = CASTE_OCCUPATIONS.get(caste, [])
	var job_lower: String = job_name.to_lower().strip_edges()
	if job_lower.is_empty():
		return true
	for a in allowed:
		var a_lower: String = str(a).to_lower().strip_edges()
		if job_lower.find(a_lower) >= 0 or a_lower.find(job_lower) >= 0:
			return true
	return false

func _assign_birth_caste(seed_hash: int) -> int:
	var roll: int = absi(seed_hash) % 100
	if roll < 5:
		return CasteType.BRAHMIN
	elif roll < 15:
		return CasteType.KSHATRIYA
	elif roll < 40:
		return CasteType.VAISHYA
	elif roll < 70:
		return CasteType.SHRAMANA
	else:
		return CasteType.OUTCAST

func _compute_caste_distribution(pawns: Array) -> Dictionary:
	var counts: Dictionary = {}
	for ct in CasteType.values():
		if ct != CasteType.NONE:
			counts[ct] = 0
		else:
			counts[-1] = 0
	var total: int = 0
	var tracked: int = 0
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pid: int = -1
		if p is Node and p.has_method("get_id"):
			pid = int(p.call("get_id"))
		elif p is Node:
			pid = int(p.name)
		if pid < 0 and p.data != null:
			pid = int(p.data.id)
		if pid < 0:
			continue
		total += 1
		var c: int = _pawn_caste.get(pid, CasteType.NONE)
		if c == CasteType.NONE:
			counts[-1] = counts.get(-1, 0) + 1
		else:
			counts[c] = counts.get(c, 0) + 1
			tracked += 1
	return {"counts": counts, "total": total, "total_tracked": tracked}

func _detect_caste_collapse(center: int, prev: Dictionary, curr: Dictionary, tick: int) -> void:
	var prev_counts: Dictionary = prev.get("counts", {})
	var curr_counts: Dictionary = curr.get("counts", {})
	var prev_pop: int = prev.get("total_tracked", 0)
	var curr_pop: int = curr.get("total_tracked", 0)
	if prev_pop <= 0 or curr_pop <= 0:
		return
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		var prev_n: int = prev_counts.get(ct, 0)
		var curr_n: int = curr_counts.get(ct, 0)
		if prev_n <= 0:
			continue
		var ratio: float = float(curr_n) / float(prev_n)
		if ratio < CASTE_COLLAPSE_THRESHOLD:
			_on_caste_collapse(center, ct, prev_n, curr_n, tick)

func _on_caste_collapse(center: int, caste: int, prev_count: int, curr_count: int, tick: int) -> void:
	if _WorldMemory != null and _WorldMemory.has_method("record_event"):
		_WorldMemory.record_event({
			"type": "caste_collapse",
			"center_region": center,
			"caste": CASTE_NAMES.get(caste, "Unknown"),
			"previous_count": prev_count,
			"current_count": curr_count,
			"tick": tick,
		})
	if _EventBus != null and _EventBus.has_method("emit"):
		_EventBus.emit("caste_collapse", {
			"center": center,
			"caste": caste,
			"prev_count": prev_count,
			"curr_count": curr_count,
			"tick": tick,
		})
	if _SettlementMemory != null:
		var settlements_v: Variant = _SettlementMemory.get("settlements", [])
		if settlements_v is Array:
			var st_list: Array = settlements_v as Array
			for st_v in st_list:
				if st_v is Dictionary:
					var sc: int = int((st_v as Dictionary).get("center_region", -1))
					if sc == center:
						var caste_name: String = CASTE_NAMES.get(caste, "Unknown")
						var entry: String = "The %s caste has nearly vanished from this settlement (fell from %d to %d)." % [caste_name, prev_count, curr_count]
						(st_v as Dictionary)["chronicle_entry"] = entry
						break

func on_caste_system_collapse(center: int, tick: int) -> void:
	if _WorldMemory != null and _WorldMemory.has_method("record_event"):
		_WorldMemory.record_event({
			"type": "caste_system_abolished",
			"center_region": center,
			"tick": tick,
		})
	var pawn_ids_in_settlement: Array[int] = []
	for pid in _pawn_caste.keys():
		var settlement_of_pawn: int = _pawn_settlement(pid)
		if settlement_of_pawn == center:
			pawn_ids_in_settlement.append(pid)
	for pid in pawn_ids_in_settlement:
		_pawn_caste[pid] = CasteType.NONE

func _pawn_settlement(pawn_id: int) -> int:
	if _SettlementMemory == null:
		return -1
	var settlements_v: Variant = _SettlementMemory.get("settlements", [])
	if not (settlements_v is Array):
		return -1
	var settlements: Array = settlements_v as Array
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		var pawns: Array = _get_pawns_in_settlement(center)
		for p in pawns:
			if p == null:
				continue
			var pid: int = -1
			if p is Node and p.has_method("get_id"):
				pid = int(p.call("get_id"))
			elif p is Node:
				pid = int(p.name)
			if pid == pawn_id:
				return center
	return -1

func _enforce_caste_occupations(center: int, tick: int) -> void:
	if not _settlement_caste_system.get(center, false):
		return
	var pawns: Array = _get_pawns_in_settlement(center)
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pid: int = -1
		if p is Node and p.has_method("get_id"):
			pid = int(p.call("get_id"))
		elif p is Node:
			pid = int(p.name)
		if pid < 0 and p.data != null:
			pid = int(p.data.id)
		if pid < 0:
			continue
		var caste: int = _pawn_caste.get(pid, CasteType.NONE)
		if caste == CasteType.NONE:
			continue
		var current_job: String = _get_pawn_current_job(p)
		if current_job.is_empty():
			continue
		if _is_job_allowed_for_caste(current_job, caste):
			continue
		var severity: float = _compute_violation_severity(caste, current_job)
		_apply_caste_penalty(pid, caste, current_job, tick)
		if _WorldMemory != null and _WorldMemory.has_method("record_event"):
			_WorldMemory.record_event({
				"type": "caste_violation",
				"pawn_id": pid,
				"caste": CASTE_NAMES.get(caste, "Unknown"),
				"job": current_job,
				"severity": severity,
				"tick": tick,
			})
		_total_violations_recorded += 1
		caste_violation.emit(pid, caste, current_job, severity)
		var violation_entry: Dictionary = {
			"pawn_id": pid,
			"caste": caste,
			"job": current_job,
			"severity": severity,
			"tick": tick,
		}
		if not _pawn_violation_log.has(pid):
			_pawn_violation_log[pid] = []
		_pawn_violation_log[pid].append(violation_entry)
		if _pawn_violation_log[pid].size() > MAX_VIOLATION_LOG:
			_pawn_violation_log[pid].pop_front()

func _get_pawn_current_job(p: Node) -> String:
	var job: String = ""
	if p.has_method("get_current_job_label"):
		var result: Variant = p.call("get_current_job_label")
		if result is String:
			job = (result as String).to_lower()
	elif p.has_method("get_current_job"):
		var result2: Variant = p.call("get_current_job")
		if result2 is String:
			job = (result2 as String).to_lower()
	if job.is_empty() and p.data != null and "current_job" in p.data:
		job = str(p.data.current_job).to_lower()
	if job.is_empty() and _PawnAccess != null and _PawnAccess.has_method("pawn_data_for_id"):
		var pid: int = int(p.name)
		var pdata: Variant = _PawnAccess.call("pawn_data_for_id", pid)
		if pdata != null:
			if pdata.has_method("get_current_job"):
				job = str(pdata.call("get_current_job")).to_lower()
			elif pdata.has("current_profession"):
				var prof_map: Dictionary = {0: "farmer", 1: "builder", 2: "warrior", 3: "scholar", 4: "trader", 5: "healer", 6: "artisan", 7: "cleaner", 8: "menial"}
				job = prof_map.get(int(pdata.current_profession), str(pdata.current_profession))
	return job

func _compute_violation_severity(caste: int, job_name: String) -> float:
	var allowed_jobs: Array = CASTE_OCCUPATIONS.get(caste, [])
	if allowed_jobs.is_empty():
		return 1.0
	var forbidden_depth: int = 0
	var caste_level: int = CASTE_HIERARCHY.find(caste)
	if caste_level < 0:
		return 0.5
	for ot in CASTE_HIERARCHY:
		if ot == caste:
			continue
		var ot_occupations: Array = CASTE_OCCUPATIONS.get(ot, [])
		for occ in ot_occupations:
			if job_name.find(str(occ).to_lower()) >= 0:
				var ot_level: int = CASTE_HIERARCHY.find(ot)
				forbidden_depth = abs(caste_level - ot_level)
				break
		if forbidden_depth > 0:
			break
	var base: float = 0.3 + float(forbidden_depth) * 0.15
	if caste == CasteType.BRAHMIN:
		base *= 1.3
	return clampf(base, 0.2, 1.0)

func _apply_caste_penalty(pid: int, caste: int, job_name: String, tick: int) -> void:
	var severity: float = _compute_violation_severity(caste, job_name)
	if _SocialDynamics != null and _SocialDynamics.has_method("add_interaction"):
		_SocialDynamics.call("add_interaction", pid, -1, "caste_violation", -severity * 0.3, tick)
	if _SocialDynamics != null and _SocialDynamics.has_method("modify_happiness"):
		var happiness_mod: float = PENALTY_HAPPINESS_BASE * severity * 2.0
		_SocialDynamics.call("modify_happiness", pid, happiness_mod, "caste_violation:" + job_name)
	if _SocialDynamics != null and _SocialDynamics.has_method("modify_social_standing"):
		var standing_mod: float = PENALTY_SOCIAL_STANDING_BASE * severity
		_SocialDynamics.call("modify_social_standing", pid, standing_mod, "caste_violation:" + job_name)
	var pawn_node: Node = _find_pawn_node(pid)
	if pawn_node != null:
		var stored_speed: String = "_caste_work_speed_penalty"
		var existing: float = float(pawn_node.get_meta(stored_speed)) if pawn_node.has_meta(stored_speed) else 0.0
		var new_penalty: float = PENALTY_WORK_SPEED_BASE * severity
		if abs(new_penalty) > abs(existing):
			pawn_node.set_meta(stored_speed, new_penalty)
			if pawn_node.has_method("modify_work_speed"):
				pawn_node.call("modify_work_speed", -existing + new_penalty, "caste_violation")

func _find_pawn_node(pawn_id: int) -> Node:
	if _PawnAccess != null and _PawnAccess.has_method("find_pawn_by_id"):
		var result: Variant = _PawnAccess.call("find_pawn_by_id", pawn_id)
		if result is Node:
			return result as Node
	var all_pawns: Array = []
	if _PawnAccess != null and _PawnAccess.has_method("find_alive_pawns"):
		all_pawns = _PawnAccess.find_alive_pawns()
	elif _PawnAccess != null and _PawnAccess.has_method("find_pawns"):
		all_pawns = _PawnAccess.find_pawns()
	for p in all_pawns:
		if p == null or not is_instance_valid(p):
			continue
		var pid: int = -1
		if p.has_method("get_id"):
			pid = int(p.call("get_id"))
		elif p.is_in_group("pawns") and p.has_method("get_instance_id"):
			pid = int(p.call("get_instance_id"))
		if pid == pawn_id:
			return p
	return null

func get_caste(pawn_id: int) -> int:
	return _pawn_caste.get(pawn_id, CasteType.NONE)

func get_caste_name(pawn_id: int) -> String:
	var c: int = _pawn_caste.get(pawn_id, CasteType.NONE)
	return CASTE_NAMES.get(c, "None")

func get_allowed_occupations(pawn_id: int) -> Array[String]:
	var caste: int = get_caste(pawn_id)
	if caste == CasteType.NONE:
		return []
	return CASTE_OCCUPATIONS.get(caste, []).duplicate()

func get_allowed_occupations_for_caste(caste: int) -> Array[String]:
	if caste == CasteType.NONE:
		return []
	return CASTE_OCCUPATIONS.get(caste, []).duplicate()

func can_perform_job(pawn_id: int, job_name: String) -> bool:
	var caste: int = get_caste(pawn_id)
	if caste == CasteType.NONE:
		return true
	return _is_job_allowed_for_caste(job_name, caste)

func can_perform_job_for_caste(caste: int, job_name: String) -> bool:
	if caste == CasteType.NONE:
		return true
	return _is_job_allowed_for_caste(job_name, caste)

func has_caste_system(center: int) -> bool:
	return _settlement_caste_system.get(center, false)

func attempt_caste_mobility(pawn_id: int, new_caste: int, deed_type: String = "unknown") -> bool:
	if not _pawn_caste.has(pawn_id):
		return false
	var old_caste: int = _pawn_caste[pawn_id]
	if old_caste == new_caste:
		return false
	if old_caste == CasteType.NONE:
		return false
	var stream_name: StringName = StringName("caste_mobility:%d" % pawn_id)
	var mobility_seed: int = _WorldRNG.stream_seed(stream_name, _total_mobility_events) if _WorldRNG != null else absi(pawn_id * 7919 + _total_mobility_events)
	var mobility_roll: float = float(mobility_seed % 10000) / 10000.0
	if mobility_roll >= MOBILITY_CHANCE_BASE:
		return false
	if new_caste == CasteType.BRAHMIN and old_caste != CasteType.KSHATRIYA:
		var purity_check: int = mobility_seed % 3
		if purity_check == 0:
			new_caste = CasteType.VAISHYA
	_pawn_caste[pawn_id] = new_caste
	_total_mobility_events += 1
	var mobility_record: Dictionary = {
		"pawn_id": pawn_id,
		"from": CASTE_NAMES.get(old_caste, "Unknown"),
		"to": CASTE_NAMES.get(new_caste, "Unknown"),
		"deed": deed_type,
		"tick": _GameManager.tick_count if _GameManager != null else 0,
	}
	_caste_mobility_log.append(mobility_record)
	if _caste_mobility_log.size() > 200:
		_caste_mobility_log.pop_front()
	caste_changed.emit(pawn_id, old_caste, new_caste, "mobility:" + deed_type)
	caste_mobility.emit(pawn_id, old_caste, new_caste, deed_type)
	if _WorldMemory != null and _WorldMemory.has_method("record_event"):
		_WorldMemory.record_event({
			"type": "caste_mobility",
			"pawn_id": pawn_id,
			"from_caste": CASTE_NAMES.get(old_caste, "Unknown"),
			"to_caste": CASTE_NAMES.get(new_caste, "Unknown"),
			"deed": deed_type,
		})
	if _EventBus != null and _EventBus.has_method("emit"):
		_EventBus.emit("caste_mobility", {
			"pawn_id": pawn_id,
			"from": old_caste,
			"to": new_caste,
			"deed": deed_type,
		})
	return true

func try_mobility_by_deed(pawn_id: int, deed_type: String) -> bool:
	if not MOBILITY_DEEDS.has(deed_type):
		return false
	var target_caste: int = MOBILITY_DEEDS[deed_type]
	if _PawnAccess != null and _PawnAccess.has_method("pawn_data_for_id"):
		var pdata: Variant = _PawnAccess.call("pawn_data_for_id", pawn_id)
		if pdata != null:
			var deed_count: int = _count_deeds_of_type(pawn_id, deed_type)
			var chance_mult: float = 1.0 + float(deed_count) * 0.5
			var stream_salt: int = _total_mobility_events + deed_count
			var check_seed: int = _WorldRNG.stream_seed(StringName("caste_deed:%d:%s" % [pawn_id, deed_type]), stream_salt) if _WorldRNG != null else absi(pawn_id * 7919 + stream_salt)
			var check_roll: float = float(check_seed % 10000) / 10000.0
			if check_roll < MOBILITY_CHANCE_BASE * chance_mult:
				return attempt_caste_mobility(pawn_id, target_caste, deed_type)
	return false

func _count_deeds_of_type(pawn_id: int, deed_type: String) -> int:
	var count: int = 0
	for entry in _caste_mobility_log:
		if entry.get("pawn_id", -1) == pawn_id and entry.get("deed", "") == deed_type:
			count += 1
	return count

func get_caste_work_speed_bonus(pawn_id: int, job_name: String) -> float:
	var caste: int = get_caste(pawn_id)
	if caste == CasteType.NONE:
		return 0.0
	if _is_job_allowed_for_caste(job_name, caste):
		var privilege: Dictionary = CASTE_PRIVILEGE_BY_CASTE.get(caste, {})
		return privilege.get("work_speed", 0.0)
	return 0.0

func get_caste_privilege(pawn_id: int) -> Dictionary:
	var caste: int = get_caste(pawn_id)
	return CASTE_PRIVILEGE_BY_CASTE.get(caste, {}).duplicate()

func get_caste_happiness_modifier(pawn_id: int, job_name: String) -> float:
	var caste: int = get_caste(pawn_id)
	if caste == CasteType.NONE:
		return 0.0
	if _is_job_allowed_for_caste(job_name, caste):
		var privilege: Dictionary = CASTE_PRIVILEGE_BY_CASTE.get(caste, {})
		return privilege.get("happiness", 0.0)
	var severity: float = _compute_violation_severity(caste, job_name)
	return PENALTY_HAPPINESS_BASE * severity

func get_inter_caste_romance_cost(pawn_a: int, pawn_b: int) -> float:
	var caste_a: int = _pawn_caste.get(pawn_a, CasteType.NONE)
	var caste_b: int = _pawn_caste.get(pawn_b, CasteType.NONE)
	if caste_a == CasteType.NONE or caste_b == CasteType.NONE:
		return 1.0
	if caste_a == caste_b:
		return 1.0
	var level_a: int = CASTE_HIERARCHY.find(caste_a)
	var level_b: int = CASTE_HIERARCHY.find(caste_b)
	var gap: int = abs(level_a - level_b)
	if gap <= 0:
		return 1.0
	var cost: float = 1.0 + (INTER_CASTE_ROMANCE_COST_MULTIPLIER - 1.0) * (float(gap) / float(CASTE_HIERARCHY.size() - 1))
	return cost

func get_inter_caste_alliance_cost(pawn_a: int, pawn_b: int) -> float:
	var caste_a: int = _pawn_caste.get(pawn_a, CasteType.NONE)
	var caste_b: int = _pawn_caste.get(pawn_b, CasteType.NONE)
	if caste_a == CasteType.NONE or caste_b == CasteType.NONE:
		return 1.0
	if caste_a == caste_b:
		return 1.0
	var level_a: int = CASTE_HIERARCHY.find(caste_a)
	var level_b: int = CASTE_HIERARCHY.find(caste_b)
	var gap: int = abs(level_a - level_b)
	if gap <= 0:
		return 1.0
	var cost: float = 1.0 + (INTER_CASTE_ALLIANCE_COST_MULTIPLIER - 1.0) * (float(gap) / float(CASTE_HIERARCHY.size() - 1))
	return cost

func get_inter_caste_interaction_cost(pawn_a: int, pawn_b: int, interaction_type: String) -> float:
	var lower: String = interaction_type.to_lower()
	if lower == "romance" or lower == "marriage":
		return get_inter_caste_romance_cost(pawn_a, pawn_b)
	elif lower == "alliance" or lower == "trade" or lower == "friendship":
		return get_inter_caste_alliance_cost(pawn_a, pawn_b)
	return 1.0

func get_settlement_caste_profile(center: int) -> Dictionary:
	var profile: Dictionary = _settlement_last_profile.get(center, {})
	if not profile.is_empty():
		return profile.duplicate(true)
	var pawns: Array = _get_pawns_in_settlement(center)
	var computed: Dictionary = _compute_caste_distribution(pawns)
	_settlement_last_profile[center] = computed
	return computed.duplicate(true)

func get_settlement_caste_diversity_score(center: int) -> float:
	var profile: Dictionary = get_settlement_caste_profile(center)
	var counts: Dictionary = profile.get("counts", {})
	var total: int = profile.get("total_tracked", 0)
	if total <= 0:
		return 0.0
	var caste_present: int = 0
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		if int(counts.get(ct, 0)) > 0:
			caste_present += 1
	if caste_present <= 1:
		return 0.0
	var shannon_entropy: float = 0.0
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		var n: int = int(counts.get(ct, 0))
		if n <= 0:
			continue
		var p: float = float(n) / float(total)
		shannon_entropy -= p * log(p) / log(5.0)
	return clampf(shannon_entropy, 0.0, 1.0)

func get_caste_distribution(center: int) -> Dictionary:
	var profile: Dictionary = get_settlement_caste_profile(center)
	return profile.get("counts", {}).duplicate()

func is_settlement_single_caste(center: int) -> bool:
	var profile: Dictionary = get_settlement_caste_profile(center)
	var counts: Dictionary = profile.get("counts", {})
	var total: int = profile.get("total_tracked", 0)
	if total < SINGLE_CASTE_POPULATION_MIN:
		return false
	var non_zero: int = 0
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		if int(counts.get(ct, 0)) > 0:
			non_zero += 1
	return non_zero <= 1

func register_exceptional_mobility(pawn_id: int, new_caste: int, deed_type: String) -> bool:
	return attempt_caste_mobility(pawn_id, new_caste, deed_type)

func register_post_cataclysm_mobility(pawn_id: int, new_caste: int) -> bool:
	return attempt_caste_mobility(pawn_id, new_caste, "cataclysm_survival")

func assign_caste(pawn_id: int, caste: int, reason: String = "admin") -> void:
	var old_caste: int = _pawn_caste.get(pawn_id, CasteType.NONE)
	if old_caste == caste and old_caste != CasteType.NONE:
		return
	_pawn_caste[pawn_id] = caste
	caste_changed.emit(pawn_id, old_caste, caste, reason)
	if _WorldMemory != null and _WorldMemory.has_method("record_event"):
		_WorldMemory.record_event({
			"type": "caste_assigned",
			"pawn_id": pawn_id,
			"from_caste": CASTE_NAMES.get(old_caste, "Unknown"),
			"to_caste": CASTE_NAMES.get(caste, "Unknown"),
			"reason": reason,
		})

func set_settlement_caste_system(center: int, enabled: bool) -> void:
	_settlement_caste_system[center] = enabled
	if not enabled:
		on_caste_system_collapse(center, _GameManager.tick_count if _GameManager != null else 0)

func on_caste_mixing_event(settlement_center: int, tick: int) -> void:
	if not _settlement_caste_system.get(settlement_center, false):
		return
	var profile: Dictionary = get_settlement_caste_profile(settlement_center)
	var counts: Dictionary = profile.get("counts", {})
	var total: int = profile.get("total_tracked", 0)
	if total <= 0:
		return
	var mixed_pairs: int = 0
	var caste_list: Array[int] = []
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		if int(counts.get(ct, 0)) > 0:
			caste_list.append(ct)
	for i in range(caste_list.size()):
		for j in range(i + 1, caste_list.size()):
			var ci: int = caste_list[i]
			var cj: int = caste_list[j]
			var ni: int = int(counts.get(ci, 0))
			var nj: int = int(counts.get(cj, 0))
			if ni > 0 and nj > 0:
				mixed_pairs += 1
	if mixed_pairs >= 3:
		if _WorldMemory != null and _WorldMemory.has_method("record_event"):
			_WorldMemory.record_event({
				"type": "caste_mixing",
				"center_region": settlement_center,
				"mixed_pairs": mixed_pairs,
				"total_castes_present": caste_list.size(),
				"tick": tick,
			})

func get_violation_log(pawn_id: int) -> Array:
	return _pawn_violation_log.get(pawn_id, []).duplicate()

func get_all_violations() -> Dictionary:
	return _pawn_violation_log.duplicate(true)

func get_mobility_log(limit: int = -1) -> Array:
	if limit <= 0 or limit >= _caste_mobility_log.size():
		return _caste_mobility_log.duplicate()
	return _caste_mobility_log.slice(-limit).duplicate()

func get_stats() -> Dictionary:
	var total: int = _pawn_caste.size()
	var with_caste: int = 0
	var per_caste: Dictionary = {}
	for ct in CasteType.values():
		if ct != CasteType.NONE:
			per_caste[ct] = 0
	for pid in _pawn_caste.keys():
		var c: int = _pawn_caste[pid]
		if c != CasteType.NONE:
			with_caste += 1
			per_caste[c] = per_caste.get(c, 0) + 1
	var settlement_count: int = 0
	var active_systems: int = 0
	for center in _settlement_caste_system.keys():
		settlement_count += 1
		if _settlement_caste_system[center]:
			active_systems += 1
	var single_caste_count: int = 0
	for center in _settlement_caste_system.keys():
		if _settlement_caste_system[center]:
			var profile: Dictionary = _settlement_last_profile.get(center, {})
			var counts: Dictionary = profile.get("counts", {})
			var present: int = 0
			for ct in CasteType.values():
				if ct == CasteType.NONE:
					continue
				if int(counts.get(ct, 0)) > 0:
					present += 1
			if present <= 1 and int(profile.get("total_tracked", 0)) >= SINGLE_CASTE_POPULATION_MIN:
				single_caste_count += 1
	return {
		"total_pawns_tracked": total,
		"with_caste": with_caste,
		"without_caste": total - with_caste,
		"per_caste": per_caste,
		"caste_systems_tracked": settlement_count,
		"active_caste_systems": active_systems,
		"single_caste_settlements": single_caste_count,
		"total_mobility_events": _total_mobility_events,
		"total_violations_recorded": _total_violations_recorded,
		"orphaned_pawns": _orphaned_pawns.size(),
		"mobility_log_size": _caste_mobility_log.size(),
	}

func get_pawn_ids_by_caste(caste: int) -> Array[int]:
	var out: Array[int] = []
	for pid in _pawn_caste.keys():
		if _pawn_caste[pid] == caste:
			out.append(int(pid))
	return out

func get_caste_count(caste: int) -> int:
	var count: int = 0
	for pid in _pawn_caste.keys():
		if _pawn_caste[pid] == caste:
			count += 1
	return count

func pawn_has_violations(pawn_id: int) -> bool:
	return _pawn_violation_log.has(pawn_id) and not _pawn_violation_log[pawn_id].is_empty()

func get_violation_count(pawn_id: int) -> int:
	return _pawn_violation_log.get(pawn_id, []).size()

func get_caste_hierarchy_position(caste: int) -> int:
	return CASTE_HIERARCHY.find(caste)

func is_higher_caste(caste_a: int, caste_b: int) -> bool:
	var pos_a: int = CASTE_HIERARCHY.find(caste_a)
	var pos_b: int = CASTE_HIERARCHY.find(caste_b)
	if pos_a < 0 or pos_b < 0:
		return false
	return pos_a < pos_b

func get_settlement_dominant_caste(center: int) -> int:
	var profile: Dictionary = get_settlement_caste_profile(center)
	var counts: Dictionary = profile.get("counts", {})
	var best: int = CasteType.NONE
	var best_count: int = 0
	for ct in CasteType.values():
		if ct == CasteType.NONE:
			continue
		var c: int = int(counts.get(ct, 0))
		if c > best_count:
			best_count = c
			best = ct
	return best

func get_mobility_log_for_pawn(pawn_id: int) -> Array:
	var out: Array = []
	for entry in _caste_mobility_log:
		if entry.get("pawn_id", -1) == pawn_id:
			out.append(entry.duplicate())
	return out

func _on_event_pawn_born(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", payload.get("id", -1)))
	if pawn_id < 0:
		return
	if _pawn_caste.has(pawn_id):
		return
	var parent_caste: int = _get_parent_caste(pawn_id)
	if parent_caste >= 0:
		_pawn_caste[pawn_id] = parent_caste
		return
	var center: int = int(payload.get("settlement_id", payload.get("center_region", -1)))
	var rng_seed: int = absi(pawn_id * 486187739 + 1337)
	if center >= 0:
		rng_seed ^= center * 7919
	if _WorldRNG != null:
		rng_seed = _WorldRNG.stream_seed(StringName("caste_birth:%d" % pawn_id), center)
	var assigned: int = _assign_birth_caste(rng_seed)
	_pawn_caste[pawn_id] = assigned
	if assigned == CasteType.OUTCAST and not _parent_info_available(pawn_id):
		if not _orphaned_pawns.has(pawn_id):
			_orphaned_pawns.append(pawn_id)

func _on_event_settlement_founded(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	var trad_v: Variant = payload.get("tradition", {})
	var has_caste: bool = false
	if trad_v is Dictionary:
		var taboo: Array = (trad_v as Dictionary).get("taboo_jobs", [])
		has_caste = "caste" in str(taboo).to_lower() or taboo.size() > 3
	_settlement_caste_system[center] = has_caste
	if has_caste:
		var founder_id: int = int(payload.get("founder_id", -1))
		if founder_id >= 0 and not _pawn_caste.has(founder_id):
			var parent_caste: int = _get_parent_caste(founder_id)
			if parent_caste >= 0:
				_pawn_caste[founder_id] = parent_caste
			else:
				var rng: int = _WorldRNG.stream_seed(StringName("caste_founder:%d" % founder_id), center) if _WorldRNG != null else absi(founder_id * 7919 + center)
				_pawn_caste[founder_id] = _assign_birth_caste(rng)

func _on_event_settlement_attacked(payload: Dictionary) -> void:
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	if center < 0:
		return
	if _settlement_caste_system.get(center, false):
		if _WorldMemory != null and _WorldMemory.has_method("record_event"):
			_WorldMemory.record_event({
				"type": "caste_settlement_attacked",
				"center_region": center,
				"attacker": payload.get("attacker", "unknown"),
				"tick": _GameManager.tick_count if _GameManager != null else 0,
			})

func _on_event_pawn_died(payload: Dictionary) -> void:
	var pawn_id: int = int(payload.get("pawn_id", payload.get("id", -1)))
	if pawn_id < 0:
		return
	if _pawn_caste.has(pawn_id):
		_pawn_caste.erase(pawn_id)
	if _pawn_violation_log.has(pawn_id):
		_pawn_violation_log.erase(pawn_id)
	var orphan_idx: int = _orphaned_pawns.find(pawn_id)
	if orphan_idx >= 0:
		_orphaned_pawns.remove_at(orphan_idx)

func add_caste_marriage_restriction(pawn_a: int, pawn_b: int, settlement_center: int) -> float:
	var cost: float = get_inter_caste_romance_cost(pawn_a, pawn_b)
	if cost > 1.0:
		if _SocialDynamics != null and _SocialDynamics.has_method("modify_relationship_cost"):
			_SocialDynamics.call("modify_relationship_cost", pawn_a, pawn_b, cost, "caste_difference")
		if _WorldMemory != null and _WorldMemory.has_method("record_event"):
			_WorldMemory.record_event({
				"type": "caste_mixed_marriage",
				"pawn_a": pawn_a,
				"pawn_b": pawn_b,
				"settlement": settlement_center,
				"cost_multiplier": cost,
			})
	return cost

func to_save_dict() -> Dictionary:
	var per_caste: Dictionary = {}
	for ct in CasteType.values():
		if ct != CasteType.NONE:
			per_caste[ct] = 0
	for pid in _pawn_caste.keys():
		var c: int = _pawn_caste[pid]
		per_caste[c] = per_caste.get(c, 0) + 1
	return {
		"schema": 1,
		"pawn_caste": _pawn_caste.duplicate(),
		"settlement_caste_system": _settlement_caste_system.duplicate(),
		"settlement_last_profile": _settlement_last_profile.duplicate(true),
		"caste_mobility_log": _caste_mobility_log.duplicate(),
		"last_check_tick": _last_check_tick,
		"orphaned_pawns": _orphaned_pawns.duplicate(),
		"total_mobility_events": _total_mobility_events,
		"total_violations_recorded": _total_violations_recorded,
		"per_caste_summary": per_caste,
		"caste_locked_settlements": _caste_locked_settlements.duplicate(),
	}

func from_save_dict(data: Variant) -> void:
	if data == null or not (data is Dictionary):
		return
	var d: Dictionary = data as Dictionary
	clear()
	if d.has("pawn_caste") and d["pawn_caste"] is Dictionary:
		var pc: Dictionary = d["pawn_caste"] as Dictionary
		for k in pc.keys():
			var pid: int = int(k)
			var cval: int = int(pc[k])
			if cval >= CasteType.BRAHMIN and cval <= CasteType.OUTCAST:
				_pawn_caste[pid] = cval
	if d.has("settlement_caste_system") and d["settlement_caste_system"] is Dictionary:
		var scs: Dictionary = d["settlement_caste_system"] as Dictionary
		for k in scs.keys():
			_settlement_caste_system[int(k)] = bool(scs[k])
	if d.has("settlement_last_profile") and d["settlement_last_profile"] is Dictionary:
		var slp: Dictionary = d["settlement_last_profile"] as Dictionary
		for k in slp.keys():
			_settlement_last_profile[int(k)] = (slp[k] as Dictionary).duplicate(true)
	if d.has("caste_mobility_log") and d["caste_mobility_log"] is Array:
		_caste_mobility_log = (d["caste_mobility_log"] as Array).duplicate()
	if d.has("last_check_tick"):
		_last_check_tick = int(d["last_check_tick"])
	if d.has("orphaned_pawns") and d["orphaned_pawns"] is Array:
		_orphaned_pawns = (d["orphaned_pawns"] as Array).duplicate()
	if d.has("total_mobility_events"):
		_total_mobility_events = int(d["total_mobility_events"])
	if d.has("total_violations_recorded"):
		_total_violations_recorded = int(d["total_violations_recorded"])
	if d.has("caste_locked_settlements") and d["caste_locked_settlements"] is Dictionary:
		var cls: Dictionary = d["caste_locked_settlements"] as Dictionary
		for k in cls.keys():
			_caste_locked_settlements[int(k)] = bool(cls[k])

func clear() -> void:
	_pawn_caste.clear()
	_pawn_violation_log.clear()
	_settlement_caste_system.clear()
	_settlement_last_profile.clear()
	_caste_mobility_log.clear()
	_orphaned_pawns.clear()
	_caste_locked_settlements.clear()
	_last_check_tick = -999999
	_total_mobility_events = 0
	_total_violations_recorded = 0

func debug_dump(center: int = -1) -> String:
	var lines: PackedStringArray = []
	lines.append("=== CASTESYSTEM DEBUG ===")
	lines.append("Total pawns tracked: %d" % _pawn_caste.size())
	lines.append("With caste: %d" % get_stats()["with_caste"])
	lines.append("Total mobility events: %d" % _total_mobility_events)
	lines.append("Total violations: %d" % _total_violations_recorded)
	lines.append("Orphaned pawns: %d" % _orphaned_pawns.size())
	if center >= 0:
		lines.append("--- Settlement %d ---" % center)
		lines.append("Has caste system: %s" % _settlement_caste_system.get(center, false))
		var profile: Dictionary = get_settlement_caste_profile(center)
		var counts: Dictionary = profile.get("counts", {})
		var total: int = profile.get("total_tracked", 0)
		lines.append("Tracked pawns: %d" % total)
		for ct in CasteType.values():
			if ct == CasteType.NONE:
				continue
			var n: int = int(counts.get(ct, 0))
			if n > 0:
				lines.append("  %s: %d" % [CASTE_NAMES.get(ct, "?"), n])
		lines.append("Diversity: %.3f" % get_settlement_caste_diversity_score(center))
		lines.append("Dominant: %s" % CASTE_NAMES.get(get_settlement_dominant_caste(center), "None"))
		lines.append("Single-caste: %s" % is_settlement_single_caste(center))
	lines.append("--- Mobility Log (%d entries) ---" % _caste_mobility_log.size())
	var log_limit: int = mini(10, _caste_mobility_log.size())
	for i in range(_caste_mobility_log.size() - log_limit, _caste_mobility_log.size()):
		if i < 0:
			continue
		var entry: Dictionary = _caste_mobility_log[i]
		lines.append("  pawn=%d %s -> %s (%s)" % [entry.get("pawn_id", -1), entry.get("from", "?"), entry.get("to", "?"), entry.get("deed", "?")])
	lines.append("=== END CASTESYSTEM DEBUG ===")
	var result: String = ""
	for li in range(lines.size()):
		if li > 0:
			result += "\n"
		result += lines[li]
	return result
