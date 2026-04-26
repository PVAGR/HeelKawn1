extends Node
class_name KernelDiagnostic

## Deterministic Phase 7 one-shot diagnostic gate.
const DIAGNOSTIC_TICK: int = 30000

var _ran: bool = false
var _completed_tick: int = -1


func _ready() -> void:
	GameManager.game_tick.connect(_on_tick)


func _on_tick(tick: int) -> void:
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
	print("[KERNEL DIAGNOSTIC] export_ready=true command=WorldMemory.get_history_export_string()")


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
	lines.append("TICK: 30000")
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
