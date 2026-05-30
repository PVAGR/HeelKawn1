extends Node
## AshaDrujSystem — cosmic dualism of truth/order vs. deceit/chaos.
##
## Asha (truth, order, civilization) and Druj (deceit, chaos, entropy)
## are independent cosmic forces (0–100 each). When both sit in the
## 40–60 range the world is balanced. Extremes trigger excess events,
## prophecies, Veil instability, and settlement blessings/curses.
##
## Integrates with EventBus (betrayal, oathkeeping, justice), VeilSystem,
## EchoSystem, WorldMemory, and SettlementSystem.

const DRIFT_INTERVAL: int = 4000
const HISTORY_SAMPLE_INTERVAL: int = 2000
const MAX_HISTORY_SAMPLES: int = 500
const MAX_PAWN_TRACKED: int = 500
const MAX_PROPHELIES: int = 20
const BALANCE_LOW: float = 40.0
const BALANCE_HIGH: float = 60.0
const EXCESS_THRESHOLD: float = 75.0
const EXTREME_THRESHOLD: float = 85.0
const PROPHECY_CHANCE_BASE: float = 0.15
const DRIFT_RATE_BASE: float = 0.05
const DRIFT_RATE_EXTREME_BOOST: float = 0.12
const ASHA_ACTION_DECAY: float = 0.97
const DRUJ_ACTION_DECAY: float = 0.97
const SETTLEMENT_FAVOR_CAP: float = 100.0
const VEIL_WEAKEN_THRESHOLD: float = 35.0

var _asha_score: float = 50.0
var _druj_score: float = 50.0
var _asha_drift_rate: float = 0.0
var _druj_drift_rate: float = 0.0
var _last_drift_tick: int = -999999
var _last_history_tick: int = -999999
var _asha_action_momentum: float = 0.0
var _druj_action_momentum: float = 0.0
var _total_asha_actions: int = 0
var _total_druj_actions: int = 0
var _excess_event_cooldown_asha: int = -999999
var _excess_event_cooldown_druj: int = -999999
var _excess_event_cooldown_ticks: int = 15000
var _prophecy_cooldown_tick: int = -999999
var _prophecy_cooldown_ticks: int = 12000
var _balance_restored_cooldown_tick: int = -999999
var _balance_restored_cooldown_ticks: int = 10000

var _pawn_alignments: Dictionary = {}
var _settlement_favor: Dictionary = {}
var _history: Array[Dictionary] = []
var _active_prophecies: Array[Dictionary] = []
var _event_bus_connected: bool = false

signal balance_changed(asha: float, druj: float)
signal asha_excess(severity: int, description: String)
signal druj_excess(severity: int, description: String)
signal balance_restored(description: String)
signal prophecy_emerged(prophecy: Dictionary)
signal major_shift(delta: float, reason: String, force: String)

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	_connect_event_bus()

func _connect_event_bus() -> void:
	if _event_bus_connected:
		return
	var eb := get_node_or_null("/root/EventBus")
	if eb == null:
		return
	if eb.has_method("subscribe"):
		eb.subscribe("betrayal", self, "_on_betrayal_event")
		eb.subscribe("oath_kept", self, "_on_oath_kept_event")
		eb.subscribe("justice_served", self, "_on_justice_served_event")
		eb.subscribe("crime_committed", self, "_on_crime_committed_event")
		eb.subscribe("heroic_deed", self, "_on_heroic_deed_event")
		eb.subscribe("settlement_founded", self, "_on_settlement_founded_event")
		_event_bus_connected = true

func _disconnect_event_bus() -> void:
	if not _event_bus_connected:
		return
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("unsubscribe"):
		eb.unsubscribe("betrayal", self, "_on_betrayal_event")
		eb.unsubscribe("oath_kept", self, "_on_oath_kept_event")
		eb.unsubscribe("justice_served", self, "_on_justice_served_event")
		eb.unsubscribe("crime_committed", self, "_on_crime_committed_event")
		eb.unsubscribe("heroic_deed", self, "_on_heroic_deed_event")
		eb.unsubscribe("settlement_founded", self, "_on_settlement_founded_event")
	_event_bus_connected = false

func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)
	_disconnect_event_bus()

func _on_game_tick(tick: int) -> void:
	_apply_natural_drift(tick)
	_sample_history(tick)
	_check_excess_thresholds(tick)
	_check_prophecy_emergence(tick)
	_check_balance_restored(tick)
	_apply_settlement_favor_decay(tick)
	_apply_pawn_alignment_decay(tick)
	_decay_action_momentum(tick)

func _apply_natural_drift(tick: int) -> void:
	if tick - _last_drift_tick < DRIFT_INTERVAL:
		return
	_last_drift_tick = tick
	var drift_asha: float = _calculate_asha_drift()
	var drift_druj: float = _calculate_druj_drift()
	var accelerated: float = 1.0 + (_asha_action_momentum + _druj_action_momentum) * 0.5
	_asha_score = clampf(_asha_score + drift_asha * accelerated, 0.0, 100.0)
	_druj_score = clampf(_druj_score + drift_druj * accelerated, 0.0, 100.0)
	_asha_drift_rate = drift_asha * accelerated
	_druj_drift_rate = drift_druj * accelerated

func _calculate_asha_drift() -> float:
	if _asha_score > BALANCE_HIGH:
		return DRIFT_RATE_BASE + (_asha_score - BALANCE_HIGH) * 0.002
	elif _asha_score < BALANCE_LOW:
		return -DRIFT_RATE_BASE - (BALANCE_LOW - _asha_score) * 0.002
	var proximity: float = absf(_asha_score - 50.0) / 10.0
	if _asha_score > 50.0:
		return DRIFT_RATE_BASE * proximity * 0.5
	elif _asha_score < 50.0:
		return -DRIFT_RATE_BASE * proximity * 0.5
	return 0.0

func _calculate_druj_drift() -> float:
	if _druj_score > BALANCE_HIGH:
		return DRIFT_RATE_BASE + (_druj_score - BALANCE_HIGH) * 0.002
	elif _druj_score < BALANCE_LOW:
		return -DRIFT_RATE_BASE - (BALANCE_LOW - _druj_score) * 0.002
	var proximity: float = absf(_druj_score - 50.0) / 10.0
	if _druj_score > 50.0:
		return DRIFT_RATE_BASE * proximity * 0.5
	elif _druj_score < 50.0:
		return -DRIFT_RATE_BASE * proximity * 0.5
	return 0.0

func _decay_action_momentum(tick: int) -> void:
	if tick % 100 != 0:
		return
	_asha_action_momentum *= ASHA_ACTION_DECAY
	_druj_action_momentum *= DRUJ_ACTION_DECAY
	if _asha_action_momentum < 0.01:
		_asha_action_momentum = 0.0
	if _druj_action_momentum < 0.01:
		_druj_action_momentum = 0.0

func _sample_history(tick: int) -> void:
	if tick - _last_history_tick < HISTORY_SAMPLE_INTERVAL:
		return
	_last_history_tick = tick
	_history.append({
		"tick": tick,
		"asha": _asha_score,
		"druj": _druj_score,
		"asha_drift": _asha_drift_rate,
		"druj_drift": _druj_drift_rate,
		"asha_momentum": _asha_action_momentum,
		"druj_momentum": _druj_action_momentum,
		"total_asha_actions": _total_asha_actions,
		"total_druj_actions": _total_druj_actions,
		"balance_state": get_balance_state(),
	})
	while _history.size() > MAX_HISTORY_SAMPLES:
		_history.pop_front()

func _check_excess_thresholds(tick: int) -> void:
	if _asha_score >= EXCESS_THRESHOLD and tick - _excess_event_cooldown_asha >= _excess_event_cooldown_ticks:
		_excess_event_cooldown_asha = tick
		_trigger_asha_excess(tick)
	elif _asha_score >= EXTREME_THRESHOLD and tick - _excess_event_cooldown_asha >= _excess_event_cooldown_ticks / 2:
		_excess_event_cooldown_asha = tick
		_trigger_asha_excess(tick)
	if _druj_score >= EXCESS_THRESHOLD and tick - _excess_event_cooldown_druj >= _excess_event_cooldown_ticks:
		_excess_event_cooldown_druj = tick
		_trigger_druj_excess(tick)
	elif _druj_score >= EXTREME_THRESHOLD and tick - _excess_event_cooldown_druj >= _excess_event_cooldown_ticks / 2:
		_excess_event_cooldown_druj = tick
		_trigger_druj_excess(tick)

func _check_prophecy_emergence(tick: int) -> void:
	if _active_prophecies.size() >= MAX_PROPHELIES:
		return
	if tick - _prophecy_cooldown_tick < _prophecy_cooldown_ticks:
		return
	var force: String = ""
	var score: float = -1.0
	if _asha_score >= EXTREME_THRESHOLD:
		force = "asha"
		score = _asha_score
	elif _druj_score >= EXTREME_THRESHOLD:
		force = "druj"
		score = _druj_score
	else:
		return
	var wrng := get_node_or_null("/root/WorldRNG")
	var roll_ok: bool = false
	if wrng != null and wrng.has_method("chance_for"):
		roll_ok = wrng.chance_for(StringName("asha_druj_prophecy_%s_%d" % [force, tick]), PROPHECY_CHANCE_BASE + (score - EXTREME_THRESHOLD) * 0.01, tick)
	else:
		roll_ok = true
	if not roll_ok:
		return
	_prophecy_cooldown_tick = tick
	var prophecy: Dictionary = _generate_prophecy(force, score, tick)
	_active_prophecies.append(prophecy)
	prophecy_emerged.emit(prophecy)
	var description: String = prophecy.get("description", "A prophecy emerges from the cosmic imbalance.")
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("emit"):
		eb.emit("prophecy_emerged", {"prophecy": prophecy, "force": force, "tick": tick})
	_record_world_event("prophecy_emerged", {"prophecy": prophecy, "force": force}, tick)

func _generate_prophecy(force: String, score: float, tick: int) -> Dictionary:
	var severity: int = int(score / 10.0)
	var prefix_pool: Array[String] = []
	var suffix_pool: Array[String] = []
	if force == "asha":
		prefix_pool = ["The Spire of Truth shall cast a long shadow", "Order's edict falls upon the land", "The unyielding light judges all", "The celestial Law demands conformity", "Righteous flame purges the uncertain"]
		suffix_pool = ["until the Lie finds voice in the faithful.", "and the flexible reed survives the gale.", "but rigidity precedes the fracture.", "yet mercy softens the hardest decree.", "for even truth may become tyranny."]
	else:
		prefix_pool = ["The Serpent of Lies coils beneath the world", "Chaos blooms in the garden of certainty", "The Whisper sows discord among the faithful", "Deceit wears the crown of the hour", "The unreality spreads like rot through the foundations"]
		suffix_pool = ["and only the honest blade may cut the knot.", "until the world forgets its own name.", "but from decay springs unexpected life.", "yet a single truth may unravel the tapestry.", "for the Lie feeds on certainty."]
	var wrng := get_node_or_null("/root/WorldRNG")
	var prefix_idx: int = 0
	var suffix_idx: int = 0
	if wrng != null and wrng.has_method("index_for"):
		prefix_idx = wrng.index_for(StringName("prophecy_prefix_%s_%d" % [force, tick]), prefix_pool.size(), tick)
		suffix_idx = wrng.index_for(StringName("prophecy_suffix_%s_%d" % [force, tick + 1]), suffix_pool.size(), tick + 7)
	var description: String = prefix_pool[prefix_idx] + " " + suffix_pool[suffix_idx]
	return {
		"type": "asha" if force == "asha" else "druj",
		"description": description,
		"severity": severity,
		"threshold_score": score,
		"tick_emerged": tick,
		"fulfilled": false,
		"fulfilled_tick": -1,
		"expired": false,
	}

func _check_balance_restored(tick: int) -> void:
	if tick - _balance_restored_cooldown_tick < _balance_restored_cooldown_ticks:
		return
	if _history.size() < 2:
		return
	var prev: Dictionary = _history[_history.size() - 1]
	var current_state: String = get_balance_state()
	if current_state != "balanced":
		return
	var prev_asha: float = prev.get("asha", _asha_score)
	var prev_druj: float = prev.get("druj", _druj_score)
	var was_extreme: bool = (prev_asha >= EXCESS_THRESHOLD or prev_druj >= EXCESS_THRESHOLD)
	if not was_extreme:
		return
	_balance_restored_cooldown_tick = tick
	var desc: String = _generate_restoration_description(prev_asha, prev_druj)
	balance_restored.emit(desc)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("emit"):
		eb.emit("balance_restored", {"description": desc, "asha": _asha_score, "druj": _druj_score, "tick": tick})
	_record_world_event("balance_restored", {"description": desc}, tick)

func _generate_restoration_description(prev_asha: float, prev_druj: float) -> String:
	if prev_asha >= EXCESS_THRESHOLD:
		return "The iron grip of absolute Order loosens. The world breathes free once more."
	elif prev_druj >= EXCESS_THRESHOLD:
		return "The shadow of the Lie recedes. Clarity returns to the world."
	return "The cosmic forces find equilibrium once again."

func _trigger_asha_excess(tick: int) -> void:
	var severity: int = 1 if _asha_score < EXTREME_THRESHOLD else 2
	var description: String = _generate_asha_excess_description(severity, tick)
	asha_excess.emit(severity, description)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("emit"):
		eb.emit("asha_excess", {"severity": severity, "description": description, "asha": _asha_score, "tick": tick})
	_record_world_event("asha_excess", {"severity": severity, "description": description}, tick)
	_apply_asha_excess_effects(tick, severity)

func _generate_asha_excess_description(severity: int, tick: int) -> String:
	var pool: Array[String] = []
	if severity == 1:
		pool = [
			"Order tightens its grip. Dissent is met with judgment.",
			"The weight of tradition presses down. Innovation stalls.",
			"Conformity becomes law. The unusual is cast out.",
		]
	else:
		pool = [
			"Inquisition sweeps the land. The righteous hunt for heretics.",
			"Rigidity fractures the spirit. Creativity is a crime.",
			"The Spire of Truth casts a shadow of absolute conformity.",
		]
	var wrng := get_node_or_null("/root/WorldRNG")
	var idx: int = 0
	if wrng != null and wrng.has_method("index_for"):
		idx = wrng.index_for(StringName("asha_excess_desc_%d" % tick), pool.size(), tick + 3)
	return pool[idx] if idx < pool.size() else pool[0]

func _apply_asha_excess_effects(tick: int, severity: int) -> void:
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null and vs.has_method("thicken_veil"):
		vs.thicken_veil(float(severity) * 5.0, tick)
	var es := get_node_or_null("/root/EcologySystem")
	if es != null and es.has_method("apply_blessing"):
		es.apply_blessing(tick)
	if severity >= 2:
		var cs := get_node_or_null("/root/AuthoritySystem")
		if cs != null and cs.has_method("increase_authority"):
			cs.increase_authority("asha_excess", tick)

func _trigger_druj_excess(tick: int) -> void:
	var severity: int = 1 if _druj_score < EXTREME_THRESHOLD else 2
	var description: String = _generate_druj_excess_description(severity, tick)
	druj_excess.emit(severity, description)
	var eb := get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("emit"):
		eb.emit("druj_excess", {"severity": severity, "description": description, "druj": _druj_score, "tick": tick})
	_record_world_event("druj_excess", {"severity": severity, "description": description}, tick)
	_apply_druj_excess_effects(tick, severity)

func _generate_druj_excess_description(severity: int, tick: int) -> String:
	var pool: Array[String] = []
	if severity == 1:
		pool = [
			"Whispers of deceit spread. Trust erodes between neighbors.",
			"Chaos ripples through the land. Law becomes suggestion.",
			"The shadow lengthens. Honesty is met with suspicion.",
		]
	else:
		pool = [
			"The Lie takes root. Reality itself becomes uncertain.",
			"Decay spreads through the foundations of civilization.",
			"Chaos reigns. Nothing is as it seems.",
		]
	var wrng := get_node_or_null("/root/WorldRNG")
	var idx: int = 0
	if wrng != null and wrng.has_method("index_for"):
		idx = wrng.index_for(StringName("druj_excess_desc_%d" % tick), pool.size(), tick + 5)
	return pool[idx] if idx < pool.size() else pool[0]

func _apply_druj_excess_effects(tick: int, severity: int) -> void:
	var vs := get_node_or_null("/root/VeilSystem")
	if vs != null and vs.has_method("thin_veil"):
		vs.thin_veil(float(severity) * 8.0, tick)
	var cs := get_node_or_null("/root/CataclysmSystem")
	if cs != null and cs.has_method("trigger_cataclysm"):
		var wrng := get_node_or_null("/root/WorldRNG")
		var cat_type: int = 0
		if wrng != null and wrng.has_method("index_for"):
			cat_type = wrng.index_for(StringName("druj_excess_cataclysm_%d" % tick), 5, tick + 11)
		var cat_severity: int = 5 + severity * 3
		cs.trigger_cataclysm(cat_type, cat_severity, tick)
	var es := get_node_or_null("/root/EchoSystem")
	if es != null and es.has_method("spawn_echo"):
		es.spawn_echo("druj_excess", Vector2i.ZERO, tick)

func shift(reason: String, asha_delta: float, druj_delta: float, tick: int) -> void:
	if reason.is_empty():
		return
	_asha_score = clampf(_asha_score + asha_delta, 0.0, 100.0)
	_druj_score = clampf(_druj_score + druj_delta, 0.0, 100.0)
	if asha_delta > 0.0:
		_asha_action_momentum += asha_delta * 0.1
		_total_asha_actions += 1
		major_shift.emit(asha_delta, reason, "asha")
	elif asha_delta < 0.0:
		_druj_action_momentum += absf(asha_delta) * 0.1
	if druj_delta > 0.0:
		_druj_action_momentum += druj_delta * 0.1
		_total_druj_actions += 1
		major_shift.emit(druj_delta, reason, "druj")
	elif druj_delta < 0.0:
		_asha_action_momentum += absf(druj_delta) * 0.1
	balance_changed.emit(_asha_score, _druj_score)
	var combined_delta: float = absf(asha_delta) + absf(druj_delta)
	if combined_delta > 2.0:
		_record_world_event("asha_druj_shift", {
			"reason": reason,
			"asha_delta": asha_delta,
			"druj_delta": druj_delta,
			"asha": _asha_score,
			"druj": _druj_score,
		}, tick)
	_apply_veil_integration(tick)
	_apply_echo_integration(tick)

func _apply_veil_integration(tick: int) -> void:
	var vs := get_node_or_null("/root/VeilSystem")
	if vs == null:
		return
	if _asha_score < VEIL_WEAKEN_THRESHOLD:
		var weaken_amount: float = (VEIL_WEAKEN_THRESHOLD - _asha_score) * 0.02
		if vs.has_method("thin_veil"):
			vs.thin_veil(weaken_amount, tick)
	if _asha_score > 65.0:
		var strengthen_amount: float = (_asha_score - 65.0) * 0.02
		if vs.has_method("thicken_veil"):
			vs.thicken_veil(strengthen_amount, tick)

func _apply_echo_integration(tick: int) -> void:
	var es := get_node_or_null("/root/EchoSystem")
	if es == null:
		return
	if _druj_score > 60.0:
		var distortion: float = (_druj_score - 60.0) * 0.01
		if es.has_method("apply_distortion"):
			es.apply_distortion(distortion, tick)
	if _druj_score > 80.0:
		if es.has_method("spawn_echo"):
			es.spawn_echo("druj_distortion", Vector2i.ZERO, tick)

func record_truthful_action(tick: int, significance: float = 1.0) -> void:
	shift("truthful_action", 0.15 * significance, -0.05 * significance, tick)

func record_deceitful_action(tick: int, significance: float = 1.0) -> void:
	shift("deceitful_action", -0.05 * significance, 0.15 * significance, tick)

func record_civilization_achievement(tick: int) -> void:
	shift("civilization_achievement", 2.0, -1.0, tick)

func record_cataclysm(tick: int, severity: int) -> void:
	var shift_druj: float = float(severity) * 0.75
	shift("cataclysm", -shift_druj * 0.3, shift_druj, tick)

func record_heroic_death(tick: int) -> void:
	shift("heroic_death", 3.0, -1.5, tick)

func record_betrayal(tick: int) -> void:
	shift("betrayal", -2.0, 2.5, tick)

func record_justice(tick: int, severity: float = 1.0) -> void:
	shift("justice_served", 1.5 * severity, -0.5 * severity, tick)

func record_oath_kept(tick: int, significance: float = 1.0) -> void:
	shift("oath_kept", 1.0 * significance, -0.3 * significance, tick)

func record_oath_broken(tick: int, significance: float = 1.0) -> void:
	shift("oath_broken", -1.5 * significance, 2.0 * significance, tick)

func record_judgment(tick: int, is_just: bool, severity: float = 1.0) -> void:
	if is_just:
		shift("just_judgment", 1.0 * severity, -0.5 * severity, tick)
	else:
		shift("unjust_judgment", -0.8 * severity, 1.2 * severity, tick)

func record_diplomacy(tick: int, outcome: String, significance: float = 1.0) -> void:
	match outcome:
		"treaty":
			shift("diplomatic_treaty", 1.5 * significance, -0.5 * significance, tick)
		"alliance":
			shift("diplomatic_alliance", 2.0 * significance, -0.8 * significance, tick)
		"betrayal":
			shift("diplomatic_betrayal", -2.5 * significance, 3.0 * significance, tick)
		"trade":
			shift("diplomatic_trade", 0.5 * significance, -0.2 * significance, tick)

func record_disaster_aftermath(tick: int, recovery_effort: float) -> void:
	if recovery_effort > 0.0:
		shift("disaster_recovery", recovery_effort * 0.5, -recovery_effort * 0.3, tick)
	else:
		shift("disaster_neglect", -0.3, 0.5, tick)

func record_cultural_flowering(tick: int, magnitude: float = 1.0) -> void:
	shift("cultural_flowering", 1.0 * magnitude, -0.5 * magnitude, tick)

func record_technological_breakthrough(tick: int, magnitude: float = 1.0) -> void:
	shift("technological_breakthrough", 0.8 * magnitude, -0.3 * magnitude, tick)

func record_self_sacrifice(tick: int) -> void:
	shift("self_sacrifice", 5.0, -3.0, tick)

func record_great_deed(tick: int, asha_value: float = 0.0, druj_value: float = 0.0) -> void:
	if asha_value == 0.0 and druj_value == 0.0:
		asha_value = 4.0
		druj_value = -2.0
	shift("great_deed", asha_value, druj_value, tick)

func record_prophecy_fulfillment(tick: int) -> void:
	shift("prophecy_fulfilled", 6.0, -4.0, tick)

func restore_equilibrium(tick: int) -> void:
	var asha_before: float = _asha_score
	var druj_before: float = _druj_score
	var target: float = 50.0
	var asha_diff: float = target - _asha_score
	var druj_diff: float = target - _druj_score
	_asha_score = clampf(_asha_score + asha_diff * 0.5, 0.0, 100.0)
	_druj_score = clampf(_druj_score + druj_diff * 0.5, 0.0, 100.0)
	_asha_action_momentum = 0.0
	_druj_action_momentum = 0.0
	balance_changed.emit(_asha_score, _druj_score)
	_apply_veil_integration(tick)
	_apply_echo_integration(tick)
	_record_world_event("equilibrium_restored", {
		"asha_before": asha_before,
		"druj_before": druj_before,
		"asha_after": _asha_score,
		"druj_after": _druj_score,
	}, tick)
	balance_restored.emit("A great act restores the cosmic balance. Asha and Druj find harmony.")

func _on_betrayal_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var significance: float = payload.get("significance", 1.0)
	record_betrayal(tick)
	var pawn_id: int = payload.get("pawn_id", -1)
	if pawn_id >= 0:
		_record_pawn_action(pawn_id, "druj", significance)

func _on_oath_kept_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var significance: float = payload.get("significance", 1.0)
	record_oath_kept(tick, significance)
	var pawn_id: int = payload.get("pawn_id", -1)
	if pawn_id >= 0:
		_record_pawn_action(pawn_id, "asha", significance)

func _on_justice_served_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var severity: float = payload.get("severity", 1.0)
	record_justice(tick, severity)

func _on_crime_committed_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var severity_str: float = payload.get("severity", 1.0)
	shift("crime_committed", -0.5 * severity_str, 0.8 * severity_str, tick)
	var pawn_id: int = payload.get("pawn_id", -1)
	if pawn_id >= 0:
		_record_pawn_action(pawn_id, "druj", severity_str)

func _on_heroic_deed_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var significance: float = payload.get("significance", 1.0)
	shift("heroic_deed", 2.0 * significance, -1.0 * significance, tick)
	var pawn_id: int = payload.get("pawn_id", -1)
	if pawn_id >= 0:
		_record_pawn_action(pawn_id, "asha", significance)

func _on_settlement_founded_event(payload: Dictionary) -> void:
	var tick: int = payload.get("tick", GameManager.tick_count if GameManager != null else 0)
	var settlement_id: int = payload.get("settlement_id", -1)
	if settlement_id >= 0 and not _settlement_favor.has(settlement_id):
		_settlement_favor[settlement_id] = {"asha_favor": 5.0, "druj_favor": 5.0}
	shift("settlement_founded", 0.5, -0.3, tick)

func _record_pawn_action(pawn_id: int, alignment: String, significance: float) -> void:
	if _pawn_alignments.size() >= MAX_PAWN_TRACKED:
		var oldest: int = -1
		var oldest_tick: int = 2147483647
		for pid in _pawn_alignments:
			var last: int = _pawn_alignments[pid].get("last_action_tick", 0)
			if last < oldest_tick:
				oldest_tick = last
				oldest = pid
		if oldest >= 0 and _pawn_alignments.has(oldest):
			_pawn_alignments.erase(oldest)
	if not _pawn_alignments.has(pawn_id):
		_pawn_alignments[pawn_id] = {
			"asha_actions": 0,
			"druj_actions": 0,
			"asha_affinity": 0.0,
			"druj_affinity": 0.0,
			"last_action_tick": GameManager.tick_count if GameManager != null else 0,
		}
	var entry: Dictionary = _pawn_alignments[pawn_id]
	if alignment == "asha":
		entry.asha_actions += 1
		entry.asha_affinity = clampf(entry.asha_affinity + significance * 0.1, -10.0, 10.0)
		entry.druj_affinity = clampf(entry.druj_affinity - significance * 0.05, -10.0, 10.0)
	else:
		entry.druj_actions += 1
		entry.druj_affinity = clampf(entry.druj_affinity + significance * 0.1, -10.0, 10.0)
		entry.asha_affinity = clampf(entry.asha_affinity - significance * 0.05, -10.0, 10.0)
	entry.last_action_tick = GameManager.tick_count if GameManager != null else 0

func _apply_pawn_alignment_decay(tick: int) -> void:
	if tick % 5000 != 0:
		return
	for pawn_id in _pawn_alignments:
		var entry: Dictionary = _pawn_alignments[pawn_id]
		var ticks_since: int = tick - entry.get("last_action_tick", tick)
		if ticks_since > 10000:
			entry.asha_affinity *= 0.95
			entry.druj_affinity *= 0.95
			if absf(entry.asha_affinity) < 0.01 and absf(entry.druj_affinity) < 0.01:
				_pawn_alignments.erase(pawn_id)

func get_pawn_alignment(pawn_id: int) -> Dictionary:
	if not _pawn_alignments.has(pawn_id):
		return {"asha_affinity": 0.0, "druj_affinity": 0.0, "alignment": "neutral", "asha_actions": 0, "druj_actions": 0}
	var entry: Dictionary = _pawn_alignments[pawn_id]
	var alignment: String = "neutral"
	var diff: float = entry.asha_affinity - entry.druj_affinity
	if diff > 3.0:
		alignment = "asha"
	elif diff < -3.0:
		alignment = "druj"
	return {
		"asha_affinity": entry.asha_affinity,
		"druj_affinity": entry.druj_affinity,
		"alignment": alignment,
		"asha_actions": entry.asha_actions,
		"druj_actions": entry.druj_actions,
		"last_action_tick": entry.last_action_tick,
	}

func get_all_pawn_alignments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pawn_id in _pawn_alignments:
		result.append(get_pawn_alignment(pawn_id))
	return result

func apply_settlement_blessing(settlement_id: int, tick: int) -> void:
	if not _settlement_favor.has(settlement_id):
		_settlement_favor[settlement_id] = {"asha_favor": 5.0, "druj_favor": 5.0}
	if _asha_score > EXCESS_THRESHOLD:
		var favor: float = _asha_score - EXCESS_THRESHOLD
		var entry: Dictionary = _settlement_favor[settlement_id]
		entry.asha_favor = clampf(entry.asha_favor + favor * 0.05, 0.0, SETTLEMENT_FAVOR_CAP)
		entry.druj_favor = clampf(entry.druj_favor - favor * 0.02, 0.0, SETTLEMENT_FAVOR_CAP)
		var eb := get_node_or_null("/root/EventBus")
		if eb != null and eb.has_method("emit"):
			eb.emit("settlement_blessed", {"settlement_id": settlement_id, "asha": _asha_score, "tick": tick})
		_record_world_event("settlement_blessing", {"settlement_id": settlement_id, "asha_favor": entry.asha_favor}, tick)

func apply_settlement_curse(settlement_id: int, tick: int) -> void:
	if not _settlement_favor.has(settlement_id):
		_settlement_favor[settlement_id] = {"asha_favor": 5.0, "druj_favor": 5.0}
	if _druj_score > EXCESS_THRESHOLD:
		var favor: float = _druj_score - EXCESS_THRESHOLD
		var entry: Dictionary = _settlement_favor[settlement_id]
		entry.druj_favor = clampf(entry.druj_favor + favor * 0.05, 0.0, SETTLEMENT_FAVOR_CAP)
		entry.asha_favor = clampf(entry.asha_favor - favor * 0.02, 0.0, SETTLEMENT_FAVOR_CAP)
		var eb := get_node_or_null("/root/EventBus")
		if eb != null and eb.has_method("emit"):
			eb.emit("settlement_cursed", {"settlement_id": settlement_id, "druj": _druj_score, "tick": tick})
		_record_world_event("settlement_curse", {"settlement_id": settlement_id, "druj_favor": entry.druj_favor}, tick)

func get_settlement_favor(settlement_id: int) -> Dictionary:
	if not _settlement_favor.has(settlement_id):
		return {"asha_favor": 0.0, "druj_favor": 0.0, "net_bias": "neutral"}
	var entry: Dictionary = _settlement_favor[settlement_id]
	var bias: String = "neutral"
	if entry.asha_favor > entry.druj_favor + 10.0:
		bias = "asha"
	elif entry.druj_favor > entry.asha_favor + 10.0:
		bias = "druj"
	return {
		"asha_favor": entry.asha_favor,
		"druj_favor": entry.druj_favor,
		"net_bias": bias,
	}

func _apply_settlement_favor_decay(tick: int) -> void:
	if tick % 3000 != 0:
		return
	for sid in _settlement_favor:
		var entry: Dictionary = _settlement_favor[sid]
		entry.asha_favor = maxf(0.0, entry.asha_favor - 0.1)
		entry.druj_favor = maxf(0.0, entry.druj_favor - 0.1)
		if entry.asha_favor <= 0.0 and entry.druj_favor <= 0.0:
			_settlement_favor.erase(sid)

func _record_world_event(event_type: String, data: Dictionary, tick: int) -> void:
	var wm := get_node_or_null("/root/WorldMemory")
	if wm == null or not wm.has_method("record_event"):
		return
	var event_data: Dictionary = data.duplicate()
	event_data["type"] = event_type
	event_data["tick"] = tick
	event_data["asha"] = _asha_score
	event_data["druj"] = _druj_score
	wm.record_event(event_data)

func get_asha() -> float:
	return _asha_score

func get_druj() -> float:
	return _druj_score

func get_balance() -> Dictionary:
	return {"asha": _asha_score, "druj": _druj_score}

func get_balance_state() -> String:
	var asha_in_range: bool = _asha_score >= BALANCE_LOW and _asha_score <= BALANCE_HIGH
	var druj_in_range: bool = _druj_score >= BALANCE_LOW and _druj_score <= BALANCE_HIGH
	if asha_in_range and druj_in_range:
		return "balanced"
	if _asha_score > _druj_score:
		return "asha_dominant"
	elif _druj_score > _asha_score:
		return "druj_dominant"
	return "balanced"

func get_dominant_force() -> String:
	if _asha_score > _druj_score:
		return "asha"
	elif _druj_score > _asha_score:
		return "druj"
	return "balance"

func get_balance_description() -> String:
	var state: String = get_balance_state()
	var diff: float = _asha_score - _druj_score
	if state == "balanced":
		var both_low: bool = _asha_score < BALANCE_LOW and _druj_score < BALANCE_LOW
		if both_low:
			return "Both cosmic forces are quiet, neither truth nor lies hold sway."
		return "The cosmic balance holds. Asha and Druj are in harmony."
	if state == "asha_dominant":
		if diff > 40.0:
			return "Absolute Order prevails. The Spire of Truth casts an unbroken shadow."
		elif diff > 20.0:
			return "Asha's light is strong. Truth and law guide the world."
		else:
			return "Asha holds a quiet edge over the Lie."
	else:
		if diff < -40.0:
			return "Chaos absolute. The Lie has consumed all certainty."
		elif diff < -20.0:
			return "Druj's shadow is deep. Deceit and entropy spread."
		else:
			return "Druj whispers at the edge of truth."

func get_drift_rates() -> Dictionary:
	return {
		"asha_drift_rate": _asha_drift_rate,
		"druj_drift_rate": _druj_drift_rate,
		"asha_momentum": _asha_action_momentum,
		"druj_momentum": _druj_action_momentum,
	}

func get_balance_history(count: int = 50) -> Array[Dictionary]:
	if count <= 0:
		return _history.duplicate()
	return _history.slice(-count)

func get_score_at_tick(target_tick: int) -> Dictionary:
	var best: Dictionary = {"asha": _asha_score, "druj": _druj_score, "tick": target_tick}
	var best_dist: int = 9999999
	for sample in _history:
		var dist: int = absi(sample.tick - target_tick)
		if dist < best_dist:
			best_dist = dist
			best = sample.duplicate()
	return best

func get_asha_history() -> Array[float]:
	var result: Array[float] = []
	for sample in _history:
		result.append(sample.asha)
	return result

func get_druj_history() -> Array[float]:
	var result: Array[float] = []
	for sample in _history:
		result.append(sample.druj)
	return result

func get_balance_trend() -> Dictionary:
	if _history.size() < 2:
		return {"asha_trend": 0.0, "druj_trend": 0.0, "direction": "stable"}
	var first: Dictionary = _history[0]
	var last: Dictionary = _history[_history.size() - 1]
	var asha_trend: float = last.asha - first.asha
	var druj_trend: float = last.druj - first.druj
	var direction: String = "stable"
	if asha_trend > 5.0 and druj_trend < -5.0:
		direction = "asha_rising"
	elif druj_trend > 5.0 and asha_trend < -5.0:
		direction = "druj_rising"
	elif asha_trend > 5.0 and druj_trend > 5.0:
		direction = "both_rising"
	return {"asha_trend": asha_trend, "druj_trend": druj_trend, "direction": direction}

func get_active_prophecies() -> Array[Dictionary]:
	return _active_prophecies.duplicate()

func fulfill_prophecy(index: int, tick: int) -> bool:
	if index < 0 or index >= _active_prophecies.size():
		return false
	var prophecy: Dictionary = _active_prophecies[index]
	if prophecy.fulfilled or prophecy.expired:
		return false
	prophecy.fulfilled = true
	prophecy.fulfilled_tick = tick
	record_prophecy_fulfillment(tick)
	return true

func expire_prophecy(index: int) -> bool:
	if index < 0 or index >= _active_prophecies.size():
		return false
	var prophecy: Dictionary = _active_prophecies[index]
	if prophecy.fulfilled:
		return false
	prophecy.expired = true
	return true

func get_dominant_force_intensity() -> float:
	var dominant: String = get_dominant_force()
	if dominant == "asha":
		return _asha_score / 100.0
	elif dominant == "druj":
		return _druj_score / 100.0
	return 0.5

func get_extremity_level() -> String:
	var max_score: float = maxf(_asha_score, _druj_score)
	if max_score < BALANCE_HIGH:
		return "tranquil"
	elif max_score < EXCESS_THRESHOLD:
		return "mild"
	elif max_score < EXTREME_THRESHOLD:
		return "excessive"
	return "extreme"

func is_asha_dominant() -> bool:
	return get_balance_state() == "asha_dominant"

func is_druj_dominant() -> bool:
	return get_balance_state() == "druj_dominant"

func is_balanced() -> bool:
	return get_balance_state() == "balanced"

func get_action_totals() -> Dictionary:
	return {
		"total_asha_actions": _total_asha_actions,
		"total_druj_actions": _total_druj_actions,
		"asha_momentum": _asha_action_momentum,
		"druj_momentum": _druj_action_momentum,
	}

func get_all_prophecies() -> Array[Dictionary]:
	return _active_prophecies.duplicate()

func count_fulfilled_prophecies() -> int:
	var count: int = 0
	for p in _active_prophecies:
		if p.fulfilled:
			count += 1
	return count

func prune_old_prophecies(tick: int, max_age: int = 50000) -> void:
	var to_remove: Array[int] = []
	for i in range(_active_prophecies.size()):
		var p: Dictionary = _active_prophecies[i]
		if tick - p.get("tick_emerged", tick) > max_age and not p.fulfilled:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_active_prophecies.remove_at(to_remove[i])

func get_settlement_bias_summary() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sid in _settlement_favor:
		result.append({
			"settlement_id": sid,
			"asha_favor": _settlement_favor[sid].asha_favor,
			"druj_favor": _settlement_favor[sid].druj_favor,
			"net_bias": "asha" if _settlement_favor[sid].asha_favor > _settlement_favor[sid].druj_favor + 10.0 else ("druj" if _settlement_favor[sid].druj_favor > _settlement_favor[sid].asha_favor + 10.0 else "neutral"),
		})
	return result

func get_stats() -> Dictionary:
	return {
		"asha": _asha_score,
		"druj": _druj_score,
		"balance_state": get_balance_state(),
		"dominant": get_dominant_force(),
		"description": get_balance_description(),
		"asha_drift_rate": _asha_drift_rate,
		"druj_drift_rate": _druj_drift_rate,
		"asha_momentum": _asha_action_momentum,
		"druj_momentum": _druj_action_momentum,
		"extremity_level": get_extremity_level(),
		"total_asha_actions": _total_asha_actions,
		"total_druj_actions": _total_druj_actions,
		"history_samples": _history.size(),
		"active_prophecies": _active_prophecies.size(),
		"tracked_pawns": _pawn_alignments.size(),
		"settlements_with_favor": _settlement_favor.size(),
	}

func debug_print_status() -> void:
	if not OS.is_debug_build():
		return
	print("=== ASHA-DRUJ SYSTEM STATUS ===")
	print("  Asha: %.1f  Druj: %.1f" % [_asha_score, _druj_score])
	print("  State: %s  Dominant: %s" % [get_balance_state(), get_dominant_force()])
	print("  Description: %s" % get_balance_description())
	print("  Drift Rates: Asha=%.3f  Druj=%.3f" % [_asha_drift_rate, _druj_drift_rate])
	print("  Momentum: Asha=%.2f  Druj=%.2f" % [_asha_action_momentum, _druj_action_momentum])
	print("  Extremity: %s" % get_extremity_level())
	print("  History samples: %d  Prophecies: %d" % [_history.size(), _active_prophecies.size()])
	print("  Tracked pawns: %d  Settlements: %d" % [_pawn_alignments.size(), _settlement_favor.size()])
	print("=== END ===")

func save() -> Dictionary:
	return {
		"asha_score": _asha_score,
		"druj_score": _druj_score,
		"asha_drift_rate": _asha_drift_rate,
		"druj_drift_rate": _druj_drift_rate,
		"last_drift_tick": _last_drift_tick,
		"last_history_tick": _last_history_tick,
		"asha_action_momentum": _asha_action_momentum,
		"druj_action_momentum": _druj_action_momentum,
		"total_asha_actions": _total_asha_actions,
		"total_druj_actions": _total_druj_actions,
		"excess_event_cooldown_asha": _excess_event_cooldown_asha,
		"excess_event_cooldown_druj": _excess_event_cooldown_druj,
		"prophecy_cooldown_tick": _prophecy_cooldown_tick,
		"balance_restored_cooldown_tick": _balance_restored_cooldown_tick,
		"pawn_alignments": _pawn_alignments.duplicate(true),
		"settlement_favor": _settlement_favor.duplicate(true),
		"history": _history.duplicate(true),
		"active_prophecies": _active_prophecies.duplicate(true),
	}

func load(data: Dictionary) -> void:
	_asha_score = data.get("asha_score", 50.0)
	_druj_score = data.get("druj_score", 50.0)
	_asha_drift_rate = data.get("asha_drift_rate", 0.0)
	_druj_drift_rate = data.get("druj_drift_rate", 0.0)
	_last_drift_tick = data.get("last_drift_tick", -999999)
	_last_history_tick = data.get("last_history_tick", -999999)
	_asha_action_momentum = data.get("asha_action_momentum", 0.0)
	_druj_action_momentum = data.get("druj_action_momentum", 0.0)
	_total_asha_actions = data.get("total_asha_actions", 0)
	_total_druj_actions = data.get("total_druj_actions", 0)
	_excess_event_cooldown_asha = data.get("excess_event_cooldown_asha", -999999)
	_excess_event_cooldown_druj = data.get("excess_event_cooldown_druj", -999999)
	_prophecy_cooldown_tick = data.get("prophecy_cooldown_tick", -999999)
	_balance_restored_cooldown_tick = data.get("balance_restored_cooldown_tick", -999999)
	_pawn_alignments = data.get("pawn_alignments", {}).duplicate(true)
	_settlement_favor = data.get("settlement_favor", {}).duplicate(true)
	_history = data.get("history", []).duplicate(true)
	_active_prophecies = data.get("active_prophecies", []).duplicate(true)

func clear() -> void:
	_asha_score = 50.0
	_druj_score = 50.0
	_asha_drift_rate = 0.0
	_druj_drift_rate = 0.0
	_last_drift_tick = -999999
	_last_history_tick = -999999
	_asha_action_momentum = 0.0
	_druj_action_momentum = 0.0
	_total_asha_actions = 0
	_total_druj_actions = 0
	_excess_event_cooldown_asha = -999999
	_excess_event_cooldown_druj = -999999
	_prophecy_cooldown_tick = -999999
	_balance_restored_cooldown_tick = -999999
	_pawn_alignments.clear()
	_settlement_favor.clear()
	_history.clear()
	_active_prophecies.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()
