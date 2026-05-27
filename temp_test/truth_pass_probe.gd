extends SceneTree

var _done: bool = false
var _out_path: String = "res://temp_test/truth_probe_output_from_godot.txt"


func _ready() -> void:
	call_deferred("_emit_report")


func _process(_delta: float) -> bool:
	if _done:
		return false
	return false


func _write_line(line: String) -> void:
	var f: FileAccess = FileAccess.open(_out_path, FileAccess.WRITE)
	if f == null:
		# Fallback: if file write fails, at least try stdout.
		print("[TRUTH_PROBE_FILE_FAIL] reason=FileAccess.open returned null")
		return
	# If file already exists from a prior run, overwrite semantics are fine for this one-shot probe.
	f.store_string(line + "\n")
	f.close()


func _emit_report() -> void:
	var lines: Array[String] = []

	var sm: Node = root.get_node_or_null("SettlementMemory")
	var fm: Node = root.get_node_or_null("FactionManager")
	var fs: Node = root.get_node_or_null("FactionSystem")
	var tm: Node = root.get_node_or_null("TradeMemory")
	if sm == null or fm == null or fs == null or tm == null:
		lines.append("[TRUTH_PROBE_FAIL] reason=missing_autoloads sm=%s fm=%s fs=%s tm=%s" % [
			str(sm != null),
			str(fm != null),
			str(fs != null),
			str(tm != null),
		])
		_done = true
		# Write even on failure so we can inspect.
		var joined := "\n".join(lines)
		_write_line(joined)
		quit(1)
		return

	var formal_count: int = int(sm.call("get_formal_settlement_count")) if sm.has_method("get_formal_settlement_count") else -1
	var proto_count: int = int(sm.call("get_proto_sites").size()) if sm.has_method("get_proto_sites") else -1
	var formal_settlements: Array = sm.call("get_formal_settlements") if sm.has_method("get_formal_settlements") else []
	var formal_centers: Dictionary = {}
	for st_any in formal_settlements:
		if st_any is Dictionary:
			var st: Dictionary = st_any as Dictionary
			var center: int = int(st.get("center_region", -1))
			if center >= 0:
				formal_centers[center] = true

	var house_count: int = int(fm.call("get_synced_house_count")) if fm.has_method("get_synced_house_count") else -1
	var faction_summary: String = str(fm.call("debug_summary_block")) if fm.has_method("debug_summary_block") else ""
	var system_factions: Array = fs.call("get_all_factions") if fs.has_method("get_all_factions") else []
	var trade_stats: Dictionary = tm.call("get_stats") if tm.has_method("get_stats") else {}
	var active_routes: Array = tm.call("get_active_routes") if tm.has_method("get_active_routes") else []

	var route_violations: Array[String] = []
	for route_any in active_routes:
		if route_any is not Dictionary:
			continue
		var route: Dictionary = route_any as Dictionary
		var from_settlement: int = int(route.get("from_settlement", -1))
		var to_settlement: int = int(route.get("to_settlement", -1))
		if not formal_centers.has(from_settlement) or not formal_centers.has(to_settlement):
			route_violations.append("%d->%d" % [from_settlement, to_settlement])

	var stale_factions: Array[String] = []
	for faction_any in system_factions:
		if faction_any is not Dictionary:
			continue
		var faction: Dictionary = faction_any as Dictionary
		var settlement_a: int = int(faction.get("settlement_a", -1))
		var settlement_b: int = int(faction.get("settlement_b", -1))
		if not formal_centers.has(settlement_a) or not formal_centers.has(settlement_b):
			stale_factions.append("%d<->%d" % [settlement_a, settlement_b])

	lines.append("[TRUTH_PROBE] formal=%d proto=%d houses=%d faction_pairs=%d active_routes=%d route_violations=%d stale_factions=%d" % [
		formal_count,
		proto_count,
		house_count,
		system_factions.size(),
		active_routes.size(),
		route_violations.size(),
		stale_factions.size(),
	])
	lines.append("[TRUTH_PROBE_FRACTION_SUMMARY]\n%s" % faction_summary)
	lines.append("[TRUTH_PROBE_ROUTE_STATS] %s" % str(trade_stats))
	lines.append("[TRUTH_PROBE_ROUTE_VIOLATIONS] %s" % str(route_violations))
	lines.append("[TRUTH_PROBE_STALE_FACTIONS] %s" % str(stale_factions))

	var joined := "\n".join(lines)
	_write_line(joined)

	# Also try stdout, but file is the primary sink for headless verification.
	print(joined)
	_done = true
	quit(0)

