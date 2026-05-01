extends SceneTree
var _start_ms: int = 0
var _start_tick: int = 0
var _done: bool = false

func _initialize() -> void:
	call_deferred("_begin")

func _begin() -> void:
	var tm: Node = get_root().get_node_or_null("TickManager")
	var gm: Node = get_root().get_node_or_null("GameManager")
	if tm == null or gm == null:
		push_error("[TICK_MEASURE] missing autoloads tm=%s gm=%s" % [tm, gm])
		quit(2)
		return
	tm.call("set_speed", 100.0)
	if gm.has_method("resume"):
		gm.call("resume")
	_start_tick = int(gm.get("tick_count"))
	_start_ms = Time.get_ticks_msec()
	print("[TICK_MEASURE] start_tick=%d speed=%.1f" % [_start_tick, float(tm.call("get_speed_multiplier"))])

func _process(_delta: float) -> bool:
	if _done:
		return false
	var gm: Node = get_root().get_node_or_null("GameManager")
	if gm == null:
		return false
	var now: int = Time.get_ticks_msec()
	if now - _start_ms < 1000:
		return false
	var end_tick: int = int(gm.get("tick_count"))
	var dt: int = end_tick - _start_tick
	print("[TICK_MEASURE] after_1000ms_wall delta_tick=%d tick_rate_per_s_approx=%d" % [dt, dt])
	_done = true
	quit(0)
	return false
