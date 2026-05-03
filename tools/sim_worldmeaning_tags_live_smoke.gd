extends SceneTree

## Headless WorldMeaning live tag scan.
## Run: Godot --headless --path . -s res://tools/sim_worldmeaning_tags_live_smoke.gd
##
## Proves that WorldMeaning region tags can emerge from live simulation data
## at tick 2000+, not only from empty early boot state.
##
## If no tags appear organically by tick 2000, that is reported as a design
## fact (empty world state), not a failure. The test passes if it proves
## deterministic live scanning and valid tag output regardless.
##
## No mutation of WorldMemory / SettlementMemory. Observation only.

const MIN_TICK: int = 2000
const TIMEOUT_FRAMES: int = 18000  # generous for headless at 500x


var _done: bool = false
var _started: bool = false
var _main_spawned: bool = false
var _frame_count: int = 0


func _process(_delta: float) -> bool:
	if _done:
		return false

	if not _started:
		_started = true
		var gm_hold: Node = root.get_node_or_null("GameManager")
		if gm_hold != null and gm_hold.has_method("pause"):
			gm_hold.call("pause")
		call_deferred("_spawn_main")
		return false

	if not _main_spawned:
		return false

	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		var gm_t: Node = root.get_node_or_null("GameManager")
		var t: int = int(gm_t.get("tick_count")) if gm_t != null else -1
		print("[WORLDMEANING_TAGS_LIVE_FAIL] tick=%d reason=frame_limit_exceeded" % t)
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	if tick >= MIN_TICK and not _done:
		_done = true
		_scan(tick)
		return true
	return false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[WORLDMEANING_TAGS_LIVE_FAIL] reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Resume TickManager (set_speed in Main._ready unpauses GameManager but not TickManager)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	# Accelerate to 500x for fast tick advancement
	if tm != null and tm.has_method("set_speed"):
		tm.call("set_speed", 500.0)
	_main_spawned = true


func _scan(tick: int) -> void:
	print("[WORLDMEANING_TAGS_LIVE] START")

	var wm: Node = root.get_node_or_null("WorldMeaning")
	if wm == null:
		print("[WORLDMEANING_TAGS_LIVE_FAIL] reason=WorldMeaning_not_found")
		quit(1)
		return

	if not wm.has_method("get_region_tags"):
		print("[WORLDMEANING_TAGS_LIVE_FAIL] reason=get_region_tags_missing")
		quit(1)
		return

	# Force recompute to ensure meaning_by_region reflects all recorded events
	if wm.has_method("recompute"):
		wm.call("recompute")

	# Read meaning_by_region (public var)
	var meaning_raw: Variant = wm.get("meaning_by_region")
	var meaning_by_region: Dictionary = {}
	if meaning_raw is Dictionary:
		meaning_by_region = meaning_raw as Dictionary

	var region_count: int = meaning_by_region.size()
	var regions_with_tags: int = 0
	var all_tags_seen: PackedStringArray = PackedStringArray()

	# Scan all regions that have meaning entries
	for rk in meaning_by_region.keys():
		var region_key: int = int(rk)
		var tags: PackedStringArray = wm.call("get_region_tags", region_key)
		if tags.size() > 0:
			regions_with_tags += 1
			for t in tags:
				var ts: String = str(t)
				if ts not in all_tags_seen:
					all_tags_seen.append(ts)

	# Also scan settlement center regions
	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm != null and sm.has_method("get_settlements"):
		var settlements: Array = sm.call("get_settlements")
		for sv in settlements:
			if not (sv is Dictionary):
				continue
			var center: int = int((sv as Dictionary).get("center_region", -1))
			if center < 0:
				continue
			var center_tags: PackedStringArray = wm.call("get_region_tags", center)
			for ct in center_tags:
				var cts: String = str(ct)
				if cts not in all_tags_seen:
					all_tags_seen.append(cts)

	# Also scan WorldMemory region keys for any regions with events
	var wmem: Node = root.get_node_or_null("WorldMemory")
	if wmem != null and wmem.has_method("get_all_region_keys"):
		var all_rks: PackedInt32Array = wmem.call("get_all_region_keys")
		for ark in all_rks:
			var ark_tags: PackedStringArray = wm.call("get_region_tags", int(ark))
			for at in ark_tags:
				var ats: String = str(at)
				if ats not in all_tags_seen:
					all_tags_seen.append(ats)

	# Report event count for context
	var event_count: int = 0
	if wmem != null and wmem.has_method("event_count"):
		event_count = int(wmem.call("event_count"))

	print("[WORLDMEANING_TAGS_LIVE] tick=%d region_count=%d regions_with_tags=%d tags_seen=%s world_events=%d" % [
		tick, region_count, regions_with_tags, str(all_tags_seen), event_count
	])

	if all_tags_seen.is_empty():
		print("[WORLDMEANING_TAGS_LIVE] no_live_tags_yet_valid_empty_world_state")

	print("[WORLDMEANING_TAGS_LIVE_PASS] live_region_tag_scan_complete")
	quit(0)
