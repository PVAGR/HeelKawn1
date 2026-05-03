extends SceneTree

## Headless public SettlementMemory structure smoke.
## Run: Godot --headless --path . -s res://tools/sim_settlement_public_state_smoke.gd
##
## Boots Main.tscn, waits for tick >= 10, then reads SettlementMemory.get_settlements()
## and validates every settlement dict for public structural sanity.
##
## This test proves only live public SettlementMemory structure at boot/tick 10.
## It does NOT prove lifecycle transitions, hysteresis, WorldMemory transition
## logging, material activity overrides, or 60,000-tick permanent ruin behavior.

const VALID_STATES: Array[String] = [
	"active",
	"recovering",
	"revivable",
	"abandoned",
	"permanently_abandoned",
]

const VALID_INTENTS: Array[String] = [
	"GROW",
	"HOARD",
	"DEFEND",
	"RECOVER",
]

const MIN_TICK: int = 10
const TIMEOUT_FRAMES: int = 1800  # ~30s at 60fps; headless can be slower than realtime

var _smoke_done: bool = false
var _frame_count: int = 0
var _main_spawned: bool = false
var _started: bool = false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=0 field=Main.tscn reason=load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null:
		if gm.has_method("set_game_tick_trace_enabled"):
			gm.call("set_game_tick_trace_enabled", false)
		else:
			gm.set("trace_game_tick_dispatch", false)
		# Resume simulation - paused GameManager so ticks wouldn't
		# fire before Main connected game_tick. Now Main is in the tree, so
		# unpause to let tick_count advance toward MIN_TICK.
		# Main._ready() may have already unpaused GameManager via set_speed(),
		# but TickManager can still be paused because set_speed() does not
		# propagate to TickManager. Resume both explicitly.
		var tm: Node = root.get_node_or_null("TickManager")
		if tm != null and tm.has_method("resume"):
			tm.call("resume")
		if gm.has_method("resume"):
			gm.call("resume")
		elif "is_paused" in gm:
			gm.set("is_paused", false)
	_main_spawned = true
	print("[SETTLEMENT_STRUCTURE_SMOKE] START")


func _process(_delta: float) -> bool:
	if _smoke_done:
		return false

	# SceneTree-safe startup: _ready() is not reliable for `-s` scripts,
	# so bootstrap on the first _process frame instead.
	if not _started:
		_started = true
		# Quiet CI: disable tick trace before any ticks fire.
		var gm_trace: Node = root.get_node_or_null("GameManager")
		if gm_trace != null:
			if gm_trace.has_method("set_game_tick_trace_enabled"):
				gm_trace.call("set_game_tick_trace_enabled", false)
			else:
				gm_trace.set("trace_game_tick_dispatch", false)
		# Hold sim until Main connects game_tick (same guard as sim_boot_smoke).
		var gm_hold: Node = root.get_node_or_null("GameManager")
		if gm_hold != null and gm_hold.has_method("pause"):
			gm_hold.call("pause")
		call_deferred("_spawn_main")
		return false

	if not _main_spawned:
		return false
	_frame_count += 1

	# Hard timeout: if we never reach MIN_TICK, fail instead of hanging.
	if _frame_count > TIMEOUT_FRAMES:
		var gm_t: Node = root.get_node_or_null("GameManager")
		var t: int = int(gm_t.get("tick_count")) if gm_t != null else -1
		print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=timeout reason=frame_limit_exceeded" % t)
		_smoke_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))
	if tick < MIN_TICK:
		return false

	# Tick threshold reached - run the structure validation.
	_smoke_done = true
	_validate_settlement_structure(tick)
	return true


func _validate_settlement_structure(tick: int) -> void:
	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm == null:
		print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=SettlementMemory reason=autoload_not_found" % tick)
		quit(1)
		return

	if not sm.has_method("get_settlements"):
		print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=get_settlements reason=method_not_found" % tick)
		quit(1)
		return

	var settlements: Array = sm.call("get_settlements")

	print("[SETTLEMENT_STRUCTURE_SMOKE] tick=%d settlements=%d" % [tick, settlements.size()])

	# Empty settlements is valid — bootstrap may not produce public entries at tick 10.
	if settlements.is_empty():
		print("[SETTLEMENT_STRUCTURE_SMOKE_PASS] tick=%d settlements_empty_valid_no_public_entries" % tick)
		quit(0)
		return

	var idx: int = 0
	for st_v in settlements:
		if not (st_v is Dictionary):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=settlement[%d] reason=not_dictionary" % [tick, idx])
			quit(1)
			return
		var st: Dictionary = st_v as Dictionary
		var prefix: String = "settlement[%d]" % idx

		# --- Required field validations ---

		# regions
		var regions_v: Variant = st.get("regions", null)
		if regions_v == null:
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.regions reason=missing" % [tick, prefix])
			quit(1)
			return
		var regions_ok: bool = false
		if regions_v is PackedInt32Array:
			regions_ok = (regions_v as PackedInt32Array).size() > 0
		elif regions_v is Array:
			regions_ok = (regions_v as Array).size() > 0
		if not regions_ok:
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.regions reason=empty_or_wrong_type" % [tick, prefix])
			quit(1)
			return

		# center_region
		var center_region_v: Variant = st.get("center_region", null)
		if not _is_int_valid(center_region_v, 0, 999999):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.center_region reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# scar_max
		var scar_max_v: Variant = st.get("scar_max", null)
		if not _is_int_valid(scar_max_v, 0, 3):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.scar_max reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# reputation_min
		var rep_min_v: Variant = st.get("reputation_min", null)
		if not _is_int_valid(rep_min_v, -3, 0):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.reputation_min reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# revival_score
		var revival_v: Variant = st.get("revival_score", null)
		if not _is_number_in_range(revival_v, 0, 100):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.revival_score reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# state
		var state_v: Variant = st.get("state", null)
		if not (state_v is String):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.state reason=missing_or_not_string" % [tick, prefix])
			quit(1)
			return
		var state_str: String = state_v as String
		if state_str not in VALID_STATES:
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.state reason=invalid_value value=%s" % [tick, prefix, state_str])
			quit(1)
			return

		# culture_type
		var culture_v: Variant = st.get("culture_type", null)
		if not _is_int_valid(culture_v, 0, 2):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.culture_type reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# peace_threshold_ticks
		var peace_v: Variant = st.get("peace_threshold_ticks", null)
		if not _is_int_valid(peace_v, 1, 999999):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.peace_threshold_ticks reason=missing_or_not_positive" % [tick, prefix])
			quit(1)
			return

		# current_intent
		var intent_v: Variant = st.get("current_intent", null)
		if not (intent_v is String):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.current_intent reason=missing_or_not_string" % [tick, prefix])
			quit(1)
			return
		var intent_str: String = intent_v as String
		if intent_str not in VALID_INTENTS:
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.current_intent reason=invalid_value value=%s" % [tick, prefix, intent_str])
			quit(1)
			return

		# war_status
		var war_v: Variant = st.get("war_status", null)
		if not (war_v is Dictionary):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.war_status reason=missing_or_not_dictionary" % [tick, prefix])
			quit(1)
			return
		var war: Dictionary = war_v as Dictionary
		var war_state_v: Variant = war.get("state", null)
		if not (war_state_v is String) or (war_state_v as String) != "peace":
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.war_status.state reason=not_peace value=%s" % [tick, prefix, str(war_state_v)])
			quit(1)
			return

		# total_pawn_deaths
		var deaths_v: Variant = st.get("total_pawn_deaths", null)
		if not _is_int_valid(deaths_v, 0, 999999):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.total_pawn_deaths reason=missing_or_negative" % [tick, prefix])
			quit(1)
			return

		# last_activity_tick
		var lat_v: Variant = st.get("last_activity_tick", null)
		if not _is_int_valid(lat_v, -1, 999999):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.last_activity_tick reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# last_pawn_death_tick
		var lpdt_v: Variant = st.get("last_pawn_death_tick", null)
		if not _is_int_valid(lpdt_v, -1, 999999):
			print("[SETTLEMENT_STRUCTURE_SMOKE_FAIL] tick=%d field=%s.last_pawn_death_tick reason=missing_or_out_of_range" % [tick, prefix])
			quit(1)
			return

		# --- Optional field presence checks (no failure, just informational) ---
		for opt_field in ["culture_name", "specialization_phase", "specialization_channel", "resource_pressure", "cultural_tags"]:
			if not st.has(opt_field):
				print("[SETTLEMENT_STRUCTURE_SMOKE] tick=%d field=%s.%s reason=optional_field_absent" % [tick, prefix, opt_field])

		idx += 1

	# All settlements passed.
	print("[SETTLEMENT_STRUCTURE_SMOKE_PASS] tick=%d all_fields_valid" % tick)
	quit(0)


## Check that a Variant is an int (or convertible) within [lo, hi].
func _is_int_valid(v: Variant, lo: int, hi: int) -> bool:
	if v == null:
		return false
	if v is int:
		var i: int = v as int
		return i >= lo and i <= hi
	# Godot sometimes stores ints as float in dictionaries.
	if v is float:
		var f: float = v as float
		if f != floorf(f):
			return false
		var i2: int = int(f)
		return i2 >= lo and i2 <= hi
	return false


## Check that a Variant is a number (int or float) within [lo, hi].
func _is_number_in_range(v: Variant, lo: float, hi: float) -> bool:
	if v == null:
		return false
	if v is int:
		var i: int = v as int
		return float(i) >= lo and float(i) <= hi
	if v is float:
		var f: float = v as float
		return f >= lo and f <= hi
	return false
