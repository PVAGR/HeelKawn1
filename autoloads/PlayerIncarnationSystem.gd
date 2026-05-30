extends Node
## PlayerIncarnationSystem — player becomes a living pawn in the simulation.
##
## The player "incarnates" as a pawn: camera follows them, buffs are applied,
## and the player gains special abilities tied to their pawn's stats.
##
## Integrates with CameraController, HeelKawnUI, SocialDynamics, EventBus,
## WorldMemory, and PawnSpawner for a full incarnation lifecycle.

## ─── Constants ──────────────────────────────────────────────────────────────

const TILE_SIZE: float = 16.0
const PAWN_SPAWNER_PATH: String = "/root/Main/WorldViewport/PawnSpawner"
const CAMERA_PATH: String = "/root/Main/WorldViewport/Camera2D"
const CAMERA_FALLBACK_PATH: String = "/root/Main/WorldViewport/Camera"

const BUFF_WORK_SPEED_BASE: float = 1.4
const BUFF_LEARNING_BASE: float = 1.5
const BUFF_HEALTH_REGEN_BASE: float = 0.5
const BUFF_CHARISMA_BASE: float = 1.3

const BUFF_DURATION_FACTOR_CAP: float = 2.5
const BUFF_DURATION_FACTOR_TICKS: int = 5000
const BUFF_PREVIOUS_INCARNATION_DECAY: float = 0.03

const COOLDOWN_TICKS_NORMAL: int = 200
const COOLDOWN_TICKS_DEATH_PENALTY: int = 800
const SKILL_TRANSFER_FRACTION: float = 0.05

const MIN_INCARNATION_AGE_YEARS: float = 13.0
const MAX_INCARNATION_AGE_YEARS: float = 70.0
const MIN_HEALTH_FOR_INCARNATION: float = 20.0
const UNCONSCIOUS_THRESHOLD: float = 5.0

const CAMERA_SMOOTH_SPEED: float = 0.08
const CAMERA_OFFSET_DEFAULT: Vector2 = Vector2(0.0, -32.0)
const CAMERA_FOLLOW_INTERVAL: int = 3

const HISTORY_MAX: int = 200
const PREVIOUS_PAWN_IDS_MAX: int = 50

const SAVE_SCHEMA_VERSION: int = 1

## ─── Enums ──────────────────────────────────────────────────────────────────

enum CameraMode { FOLLOW, FREE, HYBRID }
enum ReleaseReason { MANUAL, PAWN_DEATH, PAWN_INCAPACITATED, PLAYER_COMMAND, ERROR, SAME_TICK_DEATH }

## ─── State ──────────────────────────────────────────────────────────────────

var current_pawn_id: int = -1
var previous_pawn_ids: Array[int] = []
var tick_started: int = -1
var total_incarnation_ticks: int = 0
var incarnation_count: int = 0
var camera_mode: int = CameraMode.FOLLOW
var camera_offset: Vector2 = CAMERA_OFFSET_DEFAULT

var _incarnation_history: Array[Dictionary] = []
var _cooldown_until_tick: int = -1
var _current_buff_factor: float = 1.0
var _buff_work_speed: float = 1.0
var _buff_learning: float = 1.0
var _buff_health_regen: float = 0.0
var _buff_charisma: float = 1.0
var _previous_camera_pos: Vector2 = Vector2.ZERO
var _previous_camera_zoom: Vector2 = Vector2.ONE
var _previous_camera_mode: int = -1
var _tick_last_camera_update: int = -1
var _dirty: bool = false
var _pending_death_release: bool = false
var _last_tick_processed: int = -1
var _incarnation_reentry_guard: bool = false
var _validity_check_interval: int = 60
var _ticks_since_validity_check: int = 0
var _rng: RandomNumberGenerator
var _camera_zoom_level: float = 1.0
var _camera_zoom_speed: float = 0.05
var _incarnation_started_this_tick: bool = false
var _needs_ui_refresh: bool = false
var _last_emitted_buff_factor: float = 1.0
var _error_recovery_cooldown_active: bool = false

## ─── Signals ────────────────────────────────────────────────────────────────

signal incarnated(pawn_id: int, pawn_name: String)
signal released(pawn_id: int, duration_ticks: int, reason: int)
signal pawn_died_while_incarnated(pawn_id: int, pawn_name: String, cause: String)
signal buff_changed(buff_factor: float, work_speed: float, learning: float, health_regen: float, charisma: float)
signal camera_mode_changed(mode: int, pawn_id: int)
signal incarnation_cooldown_started(remaining_ticks: int, reason: int)
signal no_valid_pawns_found()
signal pawn_status_changed(pawn_id: int, status: String, value: float)
signal incarnation_error(pawn_id: int, error_code: int, message: String)
signal camera_zoom_changed(zoom_level: float)

## ─── Lifecycle ──────────────────────────────────────────────────────────────

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	if WorldRNG != null:
		_rng.seed = WorldRNG.current_seed()
	else:
		_rng.seed = 0

func _ready() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	if EventBus != null:
		if not EventBus.has_method("subscribe"):
			push_warning("[PlayerIncarnationSystem] EventBus missing subscribe method")
		else:
			EventBus.subscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_died_event")
			EventBus.subscribe(EventBus.EVENT_PAWN_BORN, self, "_on_pawn_born_event")

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	if EventBus != null and EventBus.has_method("unsubscribe"):
		EventBus.unsubscribe(EventBus.EVENT_PAWN_DIED, self, "_on_pawn_died_event")
		EventBus.unsubscribe(EventBus.EVENT_PAWN_BORN, self, "_on_pawn_born_event")

## ─── Tick ───────────────────────────────────────────────────────────────────

func _on_game_tick(tick: int) -> void:
	if _last_tick_processed == tick:
		return
	_last_tick_processed = tick
	_incarnation_started_this_tick = false

	if current_pawn_id < 0:
		_ticks_since_validity_check = 0
		_needs_ui_refresh = false
		return

	_ticks_since_validity_check += 1
	if _ticks_since_validity_check >= _validity_check_interval:
		_ticks_since_validity_check = 0
		_validate_incarnation_integrity(tick)

	var pawn := _find_pawn(current_pawn_id)
	if pawn == null:
		_handle_incarnation_error(current_pawn_id, 1, "Pawn node vanished")
		return
	if pawn.data == null:
		_handle_incarnation_error(current_pawn_id, 2, "Pawn data is null")
		return

	if pawn.data.is_dead:
		_handle_pawn_death(pawn, pawn.data)
		return

	if pawn.data.health <= UNCONSCIOUS_THRESHOLD:
		pawn_status_changed.emit(current_pawn_id, "incapacitated", pawn.data.health)
		_release_internal(ReleaseReason.PAWN_INCAPACITATED)
		return

	if pawn.data.health <= MIN_HEALTH_FOR_INCARNATION * 0.5:
		pawn_status_changed.emit(current_pawn_id, "low_health", pawn.data.health)

	_apply_passive_regen(pawn.data)
	_update_buff_factor(tick)

	if _tick_last_camera_update < 0 or tick - _tick_last_camera_update >= CAMERA_FOLLOW_INTERVAL:
		_tick_last_camera_update = tick
		_update_camera_follow(pawn)

	if tick % 100 == 0 and tick_started >= 0:
		total_incarnation_ticks += 100
		_needs_ui_refresh = true

func _handle_incarnation_error(pawn_id: int, code: int, message: String) -> void:
	incarnation_error.emit(pawn_id, code, message)
	if current_pawn_id == pawn_id:
		_release_internal(ReleaseReason.ERROR)

func _apply_passive_regen(data) -> void:
	if data.health <= 0.0:
		return
	if _buff_health_regen > 0.0 and data.health < data.max_health:
		var heal: float = _buff_health_regen
		if data.health + heal > data.max_health:
			heal = data.max_health - data.health
		if heal > 0.0:
			data.health += heal
			_dirty = true

func _update_buff_factor(tick: int) -> void:
	if tick_started < 0:
		return
	var elapsed: int = tick - tick_started
	var t: float = float(elapsed) / float(BUFF_DURATION_FACTOR_TICKS)
	var duration_factor: float = 1.0 + t * (BUFF_DURATION_FACTOR_CAP - 1.0)
	duration_factor = minf(duration_factor, BUFF_DURATION_FACTOR_CAP)
	var decay: float = 1.0 - float(incarnation_count) * BUFF_PREVIOUS_INCARNATION_DECAY
	decay = maxf(decay, 0.25)
	var new_factor: float = duration_factor * decay
	if abs(new_factor - _current_buff_factor) > 0.001:
		_current_buff_factor = new_factor
		_buff_work_speed = 1.0 + (BUFF_WORK_SPEED_BASE - 1.0) * _current_buff_factor
		_buff_learning = 1.0 + (BUFF_LEARNING_BASE - 1.0) * _current_buff_factor
		_buff_health_regen = BUFF_HEALTH_REGEN_BASE * _current_buff_factor
		_buff_charisma = 1.0 + (BUFF_CHARISMA_BASE - 1.0) * _current_buff_factor
		_last_emitted_buff_factor = new_factor
		buff_changed.emit(_current_buff_factor, _buff_work_speed, _buff_learning, _buff_health_regen, _buff_charisma)

func get_buff_scaling_progress() -> float:
	if tick_started < 0:
		return 0.0
	var now: int = GameManager.tick_count if GameManager != null else 0
	var elapsed: int = maxi(0, now - tick_started)
	return clampf(float(elapsed) / float(BUFF_DURATION_FACTOR_TICKS), 0.0, 1.0)

func _validate_incarnation_integrity(tick: int) -> void:
	if current_pawn_id < 0:
		return
	var pawn := _find_pawn(current_pawn_id)
	if pawn == null:
		push_warning("[PlayerIncarnationSystem] Integrity check: incarnated pawn %d no longer exists, releasing" % current_pawn_id)
		_release_internal(ReleaseReason.ERROR)
		return
	var data = pawn.data
	if data == null:
		_release_internal(ReleaseReason.ERROR)
		return
	if data.is_dead and not _pending_death_release:
		_handle_pawn_death(pawn, data)
		return
	if data.health <= 0.0:
		if not _pending_death_release:
			_release_internal(ReleaseReason.PAWN_DEATH)
		return

## ─── Incarnation ────────────────────────────────────────────────────────────

func incarnate(pawn_id: int) -> bool:
	if pawn_id < 0:
		return false
	if current_pawn_id >= 0:
		return false
	if _incarnation_reentry_guard:
		return false

	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if _cooldown_until_tick > tick_now:
		return false

	var pawn := _find_pawn(pawn_id)
	if pawn == null or pawn.data == null:
		return false
	if not _can_incarnate_pawn(pawn.data):
		return false

	_incarnation_reentry_guard = true
	_incarnate_impl(pawn_id, pawn, tick_now)
	_incarnation_reentry_guard = false
	return true

func _incarnate_impl(pawn_id: int, pawn, tick_now: int) -> void:
	current_pawn_id = pawn_id
	tick_started = tick_now
	_tick_last_camera_update = -1
	_camera_mode_default_for_pawn(pawn.data)
	_save_camera_state()
	_set_camera_follow(pawn)
	_dirty = true

	var name_str: String = pawn.data.display_name if pawn.data and "display_name" in pawn.data else str(pawn_id)
	incarnated.emit(pawn_id, name_str)

	if not _incarnation_history.is_empty():
		var last_entry: Dictionary = _incarnation_history.back()
		if int(last_entry.get("pawn_id", -1)) == pawn_id and int(last_entry.get("tick_ended", -1)) < 0:
			last_entry["tick_ended"] = tick_now
			last_entry["duration"] = 0
			last_entry["reason"] = ReleaseReason.ERROR

	_incarnation_history.push_back({
		"pawn_id": pawn_id,
		"pawn_name": name_str,
		"tick_started": tick_now,
		"tick_ended": -1,
		"duration": -1,
		"reason": -1,
		"buff_factor_at_end": 0.0,
	})
	while _incarnation_history.size() > HISTORY_MAX:
		_incarnation_history.pop_front()

	if WorldMemory != null and WorldMemory.has_method("record_event"):
		WorldMemory.record_event({
			"type": "incarnation_started",
			"pawn_id": pawn_id,
			"pawn_name": name_str,
			"tick": tick_now,
		})

func force_incarnate(pawn_id: int) -> bool:
	if pawn_id < 0:
		return false
	if current_pawn_id >= 0:
		return false
	if _incarnation_reentry_guard:
		return false
	var pawn := _find_pawn(pawn_id)
	if pawn == null or pawn.data == null:
		return false
	_cooldown_until_tick = -1
	_incarnation_reentry_guard = true
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	_incarnate_impl(pawn_id, pawn, tick_now)
	_incarnation_reentry_guard = false
	return true

## ─── Pawn Selection ─────────────────────────────────────────────────────────

func find_best_pawn_for_incarnation() -> int:
	var ps := get_node_or_null(PAWN_SPAWNER_PATH)
	if ps == null or not ps.has_method("pawns"):
		return -1

	var candidate_id: int = -1
	var candidate_score: float = -1.0
	var valid_found: bool = false
	var tick_now: int = GameManager.tick_count if GameManager != null else 0

	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d = p.data
		if not _can_incarnate_pawn(d):
			continue
		valid_found = true
		var score := _score_pawn_for_incarnation(d, tick_now)
		if score > candidate_score:
			candidate_score = score
			candidate_id = int(d.id)

	if not valid_found:
		no_valid_pawns_found.emit()

	return candidate_id

func find_best_pawn_with_rng_tiebreak() -> int:
	var ps := get_node_or_null(PAWN_SPAWNER_PATH)
	if ps == null or not ps.has_method("pawns"):
		return -1

	var candidates: Array = []
	var tick_now: int = GameManager.tick_count if GameManager != null else 0

	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d = p.data
		if not _can_incarnate_pawn(d):
			continue
		var score := _score_pawn_for_incarnation(d, tick_now)
		candidates.push_back({"pawn_id": int(d.id), "score": score})

	if candidates.is_empty():
		no_valid_pawns_found.emit()
		return -1

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if abs(a.score - b.score) < 0.001:
			return _rng.randf() < 0.5
		return a.score > b.score
	)

	return int(candidates[0].get("pawn_id", -1))

func count_available_pawns() -> int:
	var ps := get_node_or_null(PAWN_SPAWNER_PATH)
	if ps == null or not ps.has_method("pawns"):
		return 0
	var count: int = 0
	for p in ps.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if _can_incarnate_pawn(p.data):
			count += 1
	return count

func _score_pawn_for_incarnation(data, tick_now: int) -> float:
	var score: float = 50.0

	if data.has_method("get_highest_skill_level"):
		var skill_level: int = data.get_highest_skill_level()
		score += float(skill_level) * 5.0

	score += data.health * 0.3

	var age_y: float = data.age_years if "age_years" in data else float(data.age) / 360.0
	if age_y >= 21.0 and age_y < 51.0:
		score += 20.0
	elif age_y >= 13.0 and age_y < 21.0:
		score += 10.0
	elif age_y >= 51.0 and age_y < 70.0:
		score += 5.0

	if previous_pawn_ids.find(int(data.id)) >= 0:
		score *= 0.85

	if data.health < 50.0:
		score *= 0.7 + (data.health / 100.0) * 0.3

	if "current_profession" in data:
		var prof: int = data.current_profession
		if prof == HeelKawnianData.Profession.WARRIOR:
			score += 15.0
		elif prof == HeelKawnianData.Profession.SCHOLAR:
			score += 10.0
		elif prof == HeelKawnianData.Profession.HEALER:
			score += 12.0

	if "level" in data:
		score += float(data.level) * 3.0

	if "reputation_score" in data:
		score += data.reputation_score * 0.2

	return score

func _can_incarnate_pawn(data) -> bool:
	if data == null:
		return false
	if data.is_dead:
		return false
	if data.health <= UNCONSCIOUS_THRESHOLD:
		return false
	var age_y: float = data.age_years if "age_years" in data else float(data.age) / 360.0
	if age_y < MIN_INCARNATION_AGE_YEARS:
		return false
	if age_y > MAX_INCARNATION_AGE_YEARS:
		return false
	if data.health < MIN_HEALTH_FOR_INCARNATION:
		return false
	var life_stage: int = data.life_stage if "life_stage" in data else -1
	if life_stage >= 0:
		if life_stage == HeelKawnianData.LifeStage.INFANT:
			return false
		if life_stage == HeelKawnianData.LifeStage.CHILD:
			return false
	if "is_incapacitated" in data and data.is_incapacitated:
		return false
	return true

## ─── Release ────────────────────────────────────────────────────────────────

func release() -> bool:
	if current_pawn_id < 0:
		return false
	_release_internal(ReleaseReason.MANUAL)
	return true

func release_with_reason(reason: int) -> bool:
	if current_pawn_id < 0:
		return false
	if reason < 0 or reason > ReleaseReason.SAME_TICK_DEATH:
		return false
	_release_internal(reason)
	return true

func _release_internal(reason: int) -> void:
	if current_pawn_id < 0:
		return
	if _incarnation_reentry_guard:
		return
	_incarnation_reentry_guard = true

	var old_id: int = current_pawn_id
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	var duration: int = maxi(0, tick_now - tick_started)

	var name_str: String = ""
	var pawn := _find_pawn(old_id)
	if pawn != null and pawn.data != null:
		name_str = pawn.data.display_name if "display_name" in pawn.data else str(old_id)

	if not previous_pawn_ids.has(old_id):
		previous_pawn_ids.push_back(old_id)
		while previous_pawn_ids.size() > PREVIOUS_PAWN_IDS_MAX:
			previous_pawn_ids.pop_front()

	current_pawn_id = -1
	tick_started = -1
	_tick_last_camera_update = -1

	var cooldown: int = COOLDOWN_TICKS_NORMAL
	if reason == ReleaseReason.PAWN_DEATH:
		cooldown = COOLDOWN_TICKS_DEATH_PENALTY
	elif reason == ReleaseReason.SAME_TICK_DEATH:
		cooldown = COOLDOWN_TICKS_DEATH_PENALTY
	elif reason == ReleaseReason.ERROR:
		cooldown = COOLDOWN_TICKS_NORMAL * 2
	_cooldown_until_tick = tick_now + cooldown
	incarnation_cooldown_started.emit(cooldown, reason)

	_restore_camera_state()
	_current_buff_factor = 1.0
	_buff_work_speed = 1.0
	_buff_learning = 1.0
	_buff_health_regen = 0.0
	_buff_charisma = 1.0
	buff_changed.emit(1.0, 1.0, 1.0, 0.0, 1.0)

	_append_history_end(old_id, name_str, duration, reason)

	released.emit(old_id, duration, reason)

	if WorldMemory != null and WorldMemory.has_method("record_event"):
		WorldMemory.record_event({
			"type": "incarnation_ended",
			"pawn_id": old_id,
			"pawn_name": name_str,
			"duration_ticks": duration,
			"reason": reason,
			"tick": tick_now,
		})

	_incarnation_reentry_guard = false

func _append_history_end(pawn_id: int, pawn_name: String, duration: int, reason: int) -> void:
	for i in range(_incarnation_history.size() - 1, -1, -1):
		var h: Dictionary = _incarnation_history[i]
		if int(h.get("pawn_id", -1)) == pawn_id and int(h.get("tick_ended", -1)) < 0:
			h["tick_ended"] = GameManager.tick_count if GameManager != null else 0
			h["duration"] = duration
			h["reason"] = reason
			h["buff_factor_at_end"] = _current_buff_factor
			total_incarnation_ticks += duration
			incarnation_count += 1
			_dirty = true
			return

	if not _incarnation_history.is_empty():
		var last_entry: Dictionary = _incarnation_history.back()
		if int(last_entry.get("tick_ended", -1)) < 0:
			last_entry["tick_ended"] = GameManager.tick_count if GameManager != null else 0
			last_entry["duration"] = duration
			last_entry["reason"] = reason
			last_entry["buff_factor_at_end"] = _current_buff_factor

	total_incarnation_ticks += duration
	incarnation_count += 1
	_dirty = true

func _find_pawn(pawn_id: int):
	var ps := get_node_or_null(PAWN_SPAWNER_PATH)
	if ps == null or not ps.has_method("pawns"):
		return null
	for p in ps.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			return p
	return null

## ─── Death Handling ─────────────────────────────────────────────────────────

func _handle_pawn_death(pawn, data) -> void:
	if _pending_death_release:
		return
	_pending_death_release = true

	var name_str: String = data.display_name if "display_name" in data else str(current_pawn_id)
	var cause: String = "unknown"
	if data.has_method("get_death_cause"):
		cause = data.get_death_cause()
	if data.has_meta("death_cause"):
		cause = str(data.get_meta("death_cause"))

	pawn_died_while_incarnated.emit(current_pawn_id, name_str, cause)

	if WorldMemory != null and WorldMemory.has_method("record_event"):
		WorldMemory.record_event({
			"type": "pawn_died_while_incarnated",
			"pawn_id": current_pawn_id,
			"pawn_name": name_str,
			"cause": cause,
			"tick": GameManager.tick_count if GameManager != null else 0,
		})

	var release_reason: int = ReleaseReason.PAWN_DEATH
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if tick_now == tick_started:
		release_reason = ReleaseReason.SAME_TICK_DEATH

	_release_internal(release_reason)
	_pending_death_release = false

func _on_pawn_died_event(payload: Dictionary) -> void:
	if payload == null:
		return
	var died_pawn_id: int = int(payload.get("pawn_id", -1))
	if died_pawn_id < 0:
		return
	if died_pawn_id != current_pawn_id:
		if previous_pawn_ids.has(died_pawn_id):
			var idx: int = previous_pawn_ids.find(died_pawn_id)
			if idx >= 0:
				previous_pawn_ids.remove_at(idx)
		return
	if current_pawn_id < 0 or _pending_death_release:
		return
	var pawn := _find_pawn(died_pawn_id)
	if pawn != null and pawn.data != null:
		_handle_pawn_death(pawn, pawn.data)

func _on_pawn_born_event(payload: Dictionary) -> void:
	if payload == null:
		return
	if current_pawn_id >= 0:
		return
	if not payload.has("pawn_id"):
		return
	var new_pawn_id: int = int(payload.get("pawn_id", -1))
	if new_pawn_id < 0:
		return
	var pawn := _find_pawn(new_pawn_id)
	if pawn == null or pawn.data == null:
		return
	if _can_incarnate_pawn(pawn.data):
		pawn_status_changed.emit(new_pawn_id, "born_available", 1.0)
	elif is_on_cooldown():
		pawn_status_changed.emit(new_pawn_id, "born_cooldown", float(get_cooldown_ticks_remaining()))

func validate_all_pawns() -> Dictionary:
	var ps := get_node_or_null(PAWN_SPAWNER_PATH)
	var result: Dictionary = {
		"total": 0,
		"valid": 0,
		"invalid_reasons": {},
		"invalid_ids": [],
	}
	if ps == null or not ps.has_method("pawns"):
		result["error"] = "PawnSpawner not found"
		return result
	for p in ps.pawns:
		if p == null or not is_instance_valid(p):
			result["invalid_ids"].push_back(-1)
			continue
		if p.data == null:
			result["invalid_ids"].push_back(-1)
			result["invalid_reasons"]["null_data"] = result["invalid_reasons"].get("null_data", 0) + 1
			continue
		result["total"] += 1
		if _can_incarnate_pawn(p.data):
			result["valid"] += 1
		else:
			var pid: int = int(p.data.id)
			result["invalid_ids"].push_back(pid)
			if p.data.is_dead:
				result["invalid_reasons"]["dead"] = result["invalid_reasons"].get("dead", 0) + 1
			elif p.data.health <= UNCONSCIOUS_THRESHOLD:
				result["invalid_reasons"]["unconscious"] = result["invalid_reasons"].get("unconscious", 0) + 1
			elif p.data.health < MIN_HEALTH_FOR_INCARNATION:
				result["invalid_reasons"]["low_health"] = result["invalid_reasons"].get("low_health", 0) + 1
			else:
				result["invalid_reasons"]["age_restricted"] = result["invalid_reasons"].get("age_restricted", 0) + 1
	return result

## ─── Camera ─────────────────────────────────────────────────────────────────

func _camera_mode_default_for_pawn(data) -> void:
	var prev_mode: int = camera_mode
	if data.current_profession == HeelKawnianData.Profession.SCHOLAR:
		camera_mode = CameraMode.HYBRID
	elif data.current_profession == HeelKawnianData.Profession.WARRIOR:
		camera_mode = CameraMode.FOLLOW
	else:
		camera_mode = CameraMode.FOLLOW
	if prev_mode != camera_mode:
		camera_mode_changed.emit(camera_mode, int(data.id))

func set_camera_mode(mode: int) -> bool:
	if mode < CameraMode.FOLLOW or mode > CameraMode.HYBRID:
		return false
	var prev: int = camera_mode
	camera_mode = mode
	if prev != mode:
		camera_mode_changed.emit(camera_mode, current_pawn_id)
	return true

func set_camera_offset(offset: Vector2) -> void:
	camera_offset = offset

func get_camera_mode_name() -> String:
	match camera_mode:
		CameraMode.FOLLOW:
			return "Follow"
		CameraMode.FREE:
			return "Free"
		CameraMode.HYBRID:
			return "Hybrid"
	return "Unknown"

func _save_camera_state() -> void:
	var cam := get_node_or_null(CAMERA_PATH)
	if cam == null:
		cam = get_node_or_null(CAMERA_FALLBACK_PATH)
	if cam != null:
		_previous_camera_pos = cam.position
		_previous_camera_zoom = cam.zoom
	if cam == null:
		_previous_camera_pos = Vector2.ZERO
		_previous_camera_zoom = Vector2.ONE

func _restore_camera_state() -> void:
	var cam := get_node_or_null(CAMERA_PATH)
	if cam == null:
		cam = get_node_or_null(CAMERA_FALLBACK_PATH)
	if cam != null:
		cam.position = _previous_camera_pos
		cam.zoom = _previous_camera_zoom

func _set_camera_follow(pawn) -> void:
	var cam := get_node_or_null(CAMERA_PATH)
	if cam == null:
		cam = get_node_or_null(CAMERA_FALLBACK_PATH)
	if cam == null:
		return
	var target_pos: Vector2 = _get_pawn_world_pos(pawn)
	cam.position = target_pos + camera_offset

func _update_camera_follow(pawn) -> void:
	var cam := get_node_or_null(CAMERA_PATH)
	if cam == null:
		cam = get_node_or_null(CAMERA_FALLBACK_PATH)
	if cam == null:
		return
	var target_pos: Vector2 = _get_pawn_world_pos(pawn)
	match camera_mode:
		CameraMode.FOLLOW:
			var dest: Vector2 = target_pos + camera_offset
			cam.position = cam.position.lerp(dest, CAMERA_SMOOTH_SPEED)
		CameraMode.FREE:
			pass
		CameraMode.HYBRID:
			var viewport_offset: Vector2 = get_viewport_relative_offset()
			var dest: Vector2 = target_pos + camera_offset + (viewport_offset * 48.0)
			cam.position = cam.position.lerp(dest, CAMERA_SMOOTH_SPEED)

func _get_pawn_world_pos(pawn) -> Vector2:
	if pawn.data == null:
		return Vector2.ZERO
	var tile_pos: Vector2i = pawn.data.tile_pos if "tile_pos" in pawn.data else Vector2i.ZERO
	return Vector2(float(tile_pos.x) * TILE_SIZE, float(tile_pos.y) * TILE_SIZE)

func get_viewport_relative_offset() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ZERO
	var center: Vector2 = viewport_size * 0.5
	var offset: Vector2 = (mouse_pos - center) / viewport_size
	offset.x = clampf(offset.x, -0.5, 0.5)
	offset.y = clampf(offset.y, -0.5, 0.5)
	return offset

func set_camera_zoom(zoom: float) -> void:
	if zoom <= 0.0:
		return
	_camera_zoom_level = clampf(zoom, 0.1, 5.0)
	var cam := get_node_or_null(CAMERA_PATH)
	if cam == null:
		cam = get_node_or_null(CAMERA_FALLBACK_PATH)
	if cam != null:
		cam.zoom = Vector2(_camera_zoom_level, _camera_zoom_level)
		camera_zoom_changed.emit(_camera_zoom_level)

func get_camera_zoom() -> float:
	return _camera_zoom_level

func zoom_in(amount: float = 0.1) -> void:
	set_camera_zoom(_camera_zoom_level - amount)

func zoom_out(amount: float = 0.1) -> void:
	set_camera_zoom(_camera_zoom_level + amount)

func reset_camera_zoom() -> void:
	set_camera_zoom(1.0)

## ─── Buff Application ───────────────────────────────────────────────────────

func apply_incarnation_buff(value: float) -> float:
	if current_pawn_id < 0:
		return value
	return value * _buff_work_speed

func apply_learning_buff(xp_gain: float) -> float:
	if current_pawn_id < 0:
		return xp_gain
	return xp_gain * _buff_learning

func apply_charisma_buff(base_value: float) -> float:
	if current_pawn_id < 0:
		return base_value
	return base_value * _buff_charisma

func apply_health_regen_tick(current_health: float, max_health: float) -> float:
	if current_pawn_id < 0:
		return current_health
	if _buff_health_regen <= 0.0 or current_health >= max_health:
		return current_health
	return minf(current_health + _buff_health_regen, max_health)

func get_incarnation_buff_factor() -> float:
	return _current_buff_factor if current_pawn_id >= 0 else 1.0

func get_buff_info() -> Dictionary:
	return {
		"active": current_pawn_id >= 0,
		"buff_factor": _current_buff_factor,
		"work_speed": _buff_work_speed,
		"learning": _buff_learning,
		"health_regen": _buff_health_regen,
		"charisma": _buff_charisma,
		"duration_factor_raw": _current_buff_factor / maxf(1.0 - float(incarnation_count) * BUFF_PREVIOUS_INCARNATION_DECAY, 0.25),
	}

## ─── Skill Transfer ─────────────────────────────────────────────────────────

func get_retained_skill_level(base_level: int) -> int:
	if incarnation_count <= 0:
		return base_level
	var retention: float = float(incarnation_count) * SKILL_TRANSFER_FRACTION
	retention = minf(retention, 0.5)
	return maxi(0, int(floor(float(base_level) * retention)))

func get_skill_retention_fraction() -> float:
	return minf(float(incarnation_count) * SKILL_TRANSFER_FRACTION, 0.5)

func get_retained_skill_xp(base_xp: float) -> float:
	if incarnation_count <= 0:
		return base_xp
	var retention: float = float(incarnation_count) * SKILL_TRANSFER_FRACTION
	retention = minf(retention, 0.5)
	return base_xp * retention

## ─── Toggle ─────────────────────────────────────────────────────────────────

func toggle_incarnation(pawn_id: int) -> bool:
	if current_pawn_id == pawn_id:
		_release_internal(ReleaseReason.PLAYER_COMMAND)
		return false
	return incarnate(pawn_id)

## ─── Getters ────────────────────────────────────────────────────────────────

func get_incarnated_pawn_id() -> int:
	return current_pawn_id

func get_incarnation_mode() -> int:
	return current_pawn_id

func is_incarnated() -> bool:
	return current_pawn_id >= 0

func get_incarnation_duration() -> int:
	if tick_started < 0:
		return 0
	var now: int = GameManager.tick_count if GameManager != null else 0
	return maxi(0, now - tick_started)

func get_incarnated_pawn():
	if current_pawn_id < 0:
		return null
	return _find_pawn(current_pawn_id)

func get_cooldown_ticks_remaining() -> int:
	if _cooldown_until_tick < 0:
		return 0
	var now: int = GameManager.tick_count if GameManager != null else 0
	return maxi(0, _cooldown_until_tick - now)

func is_on_cooldown() -> bool:
	if _cooldown_until_tick < 0:
		return false
	if GameManager == null:
		return false
	return GameManager.tick_count < _cooldown_until_tick

func get_previous_pawn_ids() -> Array[int]:
	return previous_pawn_ids.duplicate()

## ─── Status / Debug ─────────────────────────────────────────────────────────

func get_incarnation_status() -> Dictionary:
	var pawn := get_incarnated_pawn()
	var name_str: String = "None"
	var health_val: float = 0.0
	var max_hp: float = 100.0
	var age_y: float = 0.0
	var life_stage_name: String = "Unknown"
	var skills_info: Dictionary = {}
	var profession_name: String = "None"
	var mood_val: float = 50.0
	var hunger_val: float = 100.0
	var tile: Vector2i = Vector2i.ZERO
	var settlement_name: String = ""
	if pawn != null and pawn.data != null:
		name_str = pawn.data.display_name if "display_name" in pawn.data else "Unknown"
		health_val = pawn.data.health if "health" in pawn.data else 0.0
		max_hp = pawn.data.max_health if "max_health" in pawn.data else 100.0
		age_y = pawn.data.age_years if "age_years" in pawn.data else float(pawn.data.age) / 360.0
		if "life_stage" in pawn.data:
			life_stage_name = HeelKawnianData.LIFE_STAGE_NAMES.get(pawn.data.life_stage, "Unknown")
		if "skills" in pawn.data:
			skills_info = pawn.data.skills.duplicate()
		if "mood" in pawn.data:
			mood_val = pawn.data.mood
		if "hunger" in pawn.data:
			hunger_val = pawn.data.hunger
		if "tile_pos" in pawn.data:
			tile = pawn.data.tile_pos
		if "current_profession" in pawn.data:
			profession_name = HeelKawnianData.LIFE_STAGE_NAMES.get(pawn.data.current_profession, "None")
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	return {
		"is_incarnated": current_pawn_id >= 0,
		"pawn_id": current_pawn_id,
		"pawn_name": name_str,
		"health": health_val,
		"max_health": max_hp,
		"health_percent": (health_val / max_hp * 100.0) if max_hp > 0.0 else 0.0,
		"age_years": age_y,
		"life_stage": life_stage_name,
		"skills": skills_info,
		"mood": mood_val,
		"hunger": hunger_val,
		"tile": tile,
		"profession": profession_name,
		"duration_ticks": get_incarnation_duration(),
		"total_incarnation_ticks": total_incarnation_ticks,
		"incarnation_count": incarnation_count,
		"camera_mode": camera_mode,
		"camera_mode_name": get_camera_mode_name(),
		"buff_factor": _current_buff_factor,
		"buff_info": get_buff_info(),
		"on_cooldown": is_on_cooldown(),
		"cooldown_remaining": get_cooldown_ticks_remaining(),
		"tick": tick_now,
	}

func get_incarnation_history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in _incarnation_history:
		out.push_back(h.duplicate(true))
	return out

func get_incarnation_history_for_pawn(pawn_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h in _incarnation_history:
		if int(h.get("pawn_id", -1)) == pawn_id:
			out.push_back(h.duplicate(true))
	return out

func get_recent_incarnations(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start: int = maxi(0, _incarnation_history.size() - count)
	for i in range(start, _incarnation_history.size()):
		out.push_back(_incarnation_history[i].duplicate(true))
	out.reverse()
	return out

func get_incarnation_count_for_pawn(pawn_id: int) -> int:
	var count: int = 0
	for h in _incarnation_history:
		if int(h.get("pawn_id", -1)) == pawn_id:
			count += 1
	return count

func get_total_time_for_pawn(pawn_id: int) -> int:
	var total: int = 0
	for h in _incarnation_history:
		if int(h.get("pawn_id", -1)) == pawn_id:
			total += int(h.get("duration", 0))
	return total

func get_stats() -> Dictionary:
	return {
		"incarnated": current_pawn_id >= 0,
		"pawn_id": current_pawn_id,
		"next_cooldown_end": _cooldown_until_tick,
		"cooldown_remaining_ticks": get_cooldown_ticks_remaining(),
		"duration_ticks": get_incarnation_duration(),
		"total_incarnation_ticks": total_incarnation_ticks,
		"incarnation_count": incarnation_count,
		"previous_pawn_count": previous_pawn_ids.size(),
		"history_size": _incarnation_history.size(),
		"buff_factor": _current_buff_factor,
		"camera_mode": camera_mode,
		"dirty": _dirty,
		"pending_death_release": _pending_death_release,
	}

func get_history_summary() -> String:
	var sb: PackedStringArray = PackedStringArray()
	sb.push_back("=== Incarnation History ===")
	sb.push_back("Total incarnations: %d" % incarnation_count)
	sb.push_back("Total ticks incarnated: %d" % total_incarnation_ticks)
	sb.push_back("Previous pawns: %d" % previous_pawn_ids.size())
	if not _incarnation_history.is_empty():
		sb.push_back("--- Recent ---")
		var start: int = maxi(0, _incarnation_history.size() - 10)
		for i in range(start, _incarnation_history.size()):
			var h: Dictionary = _incarnation_history[i]
			var pid: int = int(h.get("pawn_id", -1))
			var pname: String = str(h.get("pawn_name", "?"))
			var ts: int = int(h.get("tick_started", 0))
			var dur: int = int(h.get("duration", -1))
			var rsn: int = int(h.get("reason", -1))
			var rsn_name: String = ReleaseReason.keys()[rsn] if rsn >= 0 and rsn < ReleaseReason.keys().size() else "?"
			sb.push_back("  [%d] %s (id=%d) start=%d dur=%d reason=%s" % [i, pname, pid, ts, dur, rsn_name])
	sb.push_back("========================")
	return "\n".join(sb)

## ─── Save / Load / Clear ────────────────────────────────────────────────────

func to_save_dict() -> Dictionary:
	return {
		"schema": SAVE_SCHEMA_VERSION,
		"current_pawn_id": current_pawn_id,
		"previous_pawn_ids": previous_pawn_ids.duplicate(),
		"tick_started": tick_started,
		"total_incarnation_ticks": total_incarnation_ticks,
		"incarnation_count": incarnation_count,
		"camera_mode": camera_mode,
		"camera_offset_x": camera_offset.x,
		"camera_offset_y": camera_offset.y,
		"_cooldown_until_tick": _cooldown_until_tick,
		"_current_buff_factor": _current_buff_factor,
		"_buff_work_speed": _buff_work_speed,
		"_buff_learning": _buff_learning,
		"_buff_health_regen": _buff_health_regen,
		"_buff_charisma": _buff_charisma,
		"incarnation_history": _incarnation_history.duplicate(true),
		"_dirty": _dirty,
	}

func from_save_dict(d: Variant) -> void:
	if d == null or not (d is Dictionary):
		return
	var sd: Dictionary = d as Dictionary
	clear()
	current_pawn_id = int(sd.get("current_pawn_id", -1))
	var prev_ids: Variant = sd.get("previous_pawn_ids", [])
	if prev_ids is Array:
		for pid in prev_ids:
			if pid is int and pid >= 0 and not previous_pawn_ids.has(pid):
				previous_pawn_ids.push_back(pid)
	while previous_pawn_ids.size() > PREVIOUS_PAWN_IDS_MAX:
		previous_pawn_ids.pop_front()
	tick_started = int(sd.get("tick_started", -1))
	total_incarnation_ticks = int(sd.get("total_incarnation_ticks", 0))
	incarnation_count = int(sd.get("incarnation_count", 0))
	camera_mode = int(sd.get("camera_mode", CameraMode.FOLLOW))
	camera_offset = Vector2(
		float(sd.get("camera_offset_x", CAMERA_OFFSET_DEFAULT.x)),
		float(sd.get("camera_offset_y", CAMERA_OFFSET_DEFAULT.y)),
	)
	_cooldown_until_tick = int(sd.get("_cooldown_until_tick", -1))
	_current_buff_factor = float(sd.get("_current_buff_factor", 1.0))
	var hist: Variant = sd.get("incarnation_history", [])
	if hist is Array:
		for h in hist:
			if h is Dictionary:
				_incarnation_history.push_back((h as Dictionary).duplicate(true))
	if _incarnation_history.size() > HISTORY_MAX:
		while _incarnation_history.size() > HISTORY_MAX:
			_incarnation_history.pop_front()
	_dirty = bool(sd.get("_dirty", false))
	_rebuild_buff_from_save()

func _rebuild_buff_from_save() -> void:
	if current_pawn_id >= 0 and _current_buff_factor > 1.0:
		_buff_work_speed = 1.0 + (BUFF_WORK_SPEED_BASE - 1.0) * _current_buff_factor
		_buff_learning = 1.0 + (BUFF_LEARNING_BASE - 1.0) * _current_buff_factor
		_buff_health_regen = BUFF_HEALTH_REGEN_BASE * _current_buff_factor
		_buff_charisma = 1.0 + (BUFF_CHARISMA_BASE - 1.0) * _current_buff_factor
	else:
		_current_buff_factor = 1.0
		_buff_work_speed = 1.0
		_buff_learning = 1.0
		_buff_health_regen = 0.0
		_buff_charisma = 1.0

func clear() -> void:
	_pending_death_release = false
	_incarnation_reentry_guard = false
	if current_pawn_id >= 0:
		_release_internal(ReleaseReason.MANUAL)
	current_pawn_id = -1
	previous_pawn_ids.clear()
	tick_started = -1
	total_incarnation_ticks = 0
	incarnation_count = 0
	camera_mode = CameraMode.FOLLOW
	camera_offset = CAMERA_OFFSET_DEFAULT
	_cooldown_until_tick = -1
	_current_buff_factor = 1.0
	_buff_work_speed = 1.0
	_buff_learning = 1.0
	_buff_health_regen = 0.0
	_buff_charisma = 1.0
	_incarnation_history.clear()
	_tick_last_camera_update = -1
	_dirty = false
	_ticks_since_validity_check = 0

func is_dirty() -> bool:
	return _dirty

func clear_dirty() -> void:
	_dirty = false

func needs_ui_refresh() -> bool:
	return _needs_ui_refresh

func consume_ui_refresh() -> bool:
	var val: bool = _needs_ui_refresh
	_needs_ui_refresh = false
	return val

func reset_cooldown() -> void:
	_cooldown_until_tick = -1
	_error_recovery_cooldown_active = false

func set_cooldown(ticks: int) -> void:
	var now: int = GameManager.tick_count if GameManager != null else 0
	_cooldown_until_tick = now + maxi(0, ticks)

func debug_print_state() -> void:
	var sb: PackedStringArray = PackedStringArray()
	sb.push_back("=== PlayerIncarnationSystem Debug ===")
	sb.push_back("current_pawn_id: %d" % current_pawn_id)
	sb.push_back("tick_started: %d" % tick_started)
	sb.push_back("total_incarnation_ticks: %d" % total_incarnation_ticks)
	sb.push_back("incarnation_count: %d" % incarnation_count)
	sb.push_back("camera_mode: %s (%d)" % [get_camera_mode_name(), camera_mode])
	sb.push_back("buff_factor: %.3f" % _current_buff_factor)
	sb.push_back("cooldown_until_tick: %d (remaining: %d)" % [_cooldown_until_tick, get_cooldown_ticks_remaining()])
	sb.push_back("previous_pawns: %s" % str(previous_pawn_ids))
	sb.push_back("history_size: %d" % _incarnation_history.size())
	sb.push_back("dirty: %s" % str(_dirty))
	sb.push_back("pending_death_release: %s" % str(_pending_death_release))
	sb.push_back("reentry_guard: %s" % str(_incarnation_reentry_guard))
	print("\n".join(sb) + "\n")
