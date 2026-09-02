extends SceneTree

## 02A B1 probe (measurement only, never modifies world truth). Boots Main
## with the playtest fence, fast-forwards to a warmed tick, pauses, then for up
## to N real pawns times WorldAI.get_pawn_neural_state on a force-miss (full
## resolve: input vector + forward_propagate + decision-rule ctx + matrix
## evaluate + soul/society nudge) versus an immediate TTL-cache HIT with an
## unchanged signature, and verifies the hit returns a deep-equal state.
##
## Why: the idle utility build costs ~25ms headless-200x per rebuild, and the
## single largest component is the WorldAI per-pawn neural resolve. At 200x the
## idle-action refresh stride (>=58 ticks) exceeds NEURAL_STATE_CACHE_TTL_TICKS
## (8), so a 200x run cannot demonstrate the hit path — at 1x the stride is 1
## and every idle pawn rebuilt every tick. This probe times the two paths
## directly so the 1x model (1 resolve + (TTL-1) hits per TTL ticks) is honest.
##
## Permanent Tool Rule: this tool boots Main and MUST run with
## --playtest-no-save. It hard-refuses otherwise.

const RUN_TO_TICK := 2000
const FRAME_CAP := 2000
const PROBE_PAWNS := 3

var _frame := 0
var _phase := "boot"
var _done := false

var _gm: Node = null
var _main: Node = null

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _pawn_nodes() -> Array:
	var grp: Array = get_nodes_in_group("pawns")
	if not grp.is_empty():
		return grp
	var spawner: Node = _main.get_node_or_null("WorldViewport/PawnSpawner") if _main != null else null
	if spawner == null or not spawner.has_method("get_all_pawns"):
		return []
	return spawner.call("get_all_pawns")

func _initialize() -> void:
	var gm_trace: Node = root.get_node_or_null("GameManager")
	if gm_trace != null:
		if gm_trace.has_method("set_game_tick_trace_enabled"):
			gm_trace.call("set_game_tick_trace_enabled", false)
		else:
			gm_trace.set("trace_game_tick_dispatch", false)
	call_deferred("_spawn_main")

func _spawn_main() -> void:
	if not OS.get_cmdline_user_args().has("--playtest-no-save"):
		push_error("B1PROBE: this tool boots Main and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("B1PROBE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("B1PROBE: Main autosave fence not active; refusing to run")
		quit(1)

func _probe() -> void:
	var world_ai: Node = _al("WorldAI")
	if world_ai == null:
		print("B1PROBE: WorldAI missing; abort")
		_done = true
		quit(1)
		return
	var pawns: Array = _pawn_nodes()
	if pawns.is_empty():
		print("B1PROBE: no pawns found; abort")
		_done = true
		quit(1)
		return
	var harvest: Array = []
	var count: int = mini(PROBE_PAWNS, pawns.size())
	for i in range(count):
		var p: Node = pawns[i]
		var pd: RefCounted = p.get("data")
		if pd == null:
			print("B1PROBE: pawn %d has no data; skip" % i)
			continue
		var pid: int = int(pd.get("id"))
		var miss_a: Array[float] = []
		var hit_a: Array[float] = []
		# Force a miss on the next call: erase only THIS pawn's cache entry
		# (derived state — recomputing it deterministically changes nothing).
		var cache: Dictionary = world_ai.get("_pawn_neural_cache") if world_ai.get("_pawn_neural_cache") is Dictionary else {}
		cache.erase(pid)
		world_ai.set("_pawn_neural_cache", cache)
		var t0: int = Time.get_ticks_usec()
		var ns_miss: Dictionary = world_ai.call("get_pawn_neural_state", pid)
		var t1: int = Time.get_ticks_usec()
		var miss_us: int = t1 - t0
		# Immediate second call: TTL cache hit with unchanged signature.
		var t2: int = Time.get_ticks_usec()
		var ns_hit: Dictionary = world_ai.call("get_pawn_neural_state", pid)
		var t3: int = Time.get_ticks_usec()
		var hit_us: int = t3 - t2
		var equal: bool = ns_miss == ns_hit
		# Repeated hits while the tick is frozen must keep landing on the cache
		# (frozen sim tick + frozen sig => every call is a hit).
		for k in range(5):
			var tk0: int = Time.get_ticks_usec()
			var ns_r: Dictionary = world_ai.call("get_pawn_neural_state", pid)
			var tk1: int = Time.get_ticks_usec()
			hit_a.append(float(tk1 - tk0))
			if ns_r != ns_hit:
				equal = false
		miss_a.append(float(miss_us))
		var hit_avg: float = 0.0
		if not hit_a.is_empty():
			for v in hit_a:
				hit_avg += v
			hit_avg /= float(hit_a.size())
		harvest.append({
			"pid": pid,
			"miss_us": miss_us,
			"hit_avg_us": int(hit_avg),
			"equal": equal,
		})
		print("B1PROBE pawn=%d resolve_miss_us=%d cache_hit_avg_us=%d equal=%s ratio=%.1fx" % [pid, miss_us, int(hit_avg), str(equal), (float(miss_us) / max(1.0, hit_avg))])
	var miss_tot: int = 0
	var hit_tot: int = 0
	var all_eq: bool = true
	for h in harvest:
		miss_tot += int(h["miss_us"])
		hit_tot += int(h["hit_avg_us"])
		if not bool(h["equal"]):
			all_eq = false
	if count > 0:
		print("B1PROBE SUMMARY pawns=%d avg_resolve_miss_us=%d avg_cache_hit_us=%d all_hits_equal=%s" % [count, int(miss_tot / count), int(hit_tot / count), str(all_eq)])
	_done = true
	quit(0)

func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			_gm.call("set_speed", 200.0)
			print("B1PROBE: Main ready, running at 200x to tick %d" % RUN_TO_TICK)
			return false
	if _phase == "run":
		var t: int = int(_gm.get("tick_count"))
		if t >= RUN_TO_TICK:
			_phase = "paused"
			_gm.call("pause")
			var tm: Node = root.get_node_or_null("/root/TickManager")
			if tm != null and tm.has_method("pause"):
				tm.call("pause")
			# Probe after this frame settles so no mid-flight tick mutates.
			call_deferred("_probe")
			return false
	if _frame > FRAME_CAP and _phase != "paused":
		_done = true
		print("B1PROBE: frame cap reached without reaching tick %d (tick=%s)" % [RUN_TO_TICK, _tick()])
		quit(1)
		return false
	if _phase == "paused":
		return false
	return false

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1