extends SceneTree

## Parse probe for the single-pause-authority change (must not reference the
## HeelKawnian class_name statically). Load each edited script and report.

const TARGETS := [
	"res://autoloads/GameManager.gd",
	"res://autoloads/TickManager.gd",
	"res://scripts/ui/SpeedControlUI.gd",
	"res://tools/diagnose/dev_debug_ui.gd",
	"res://tools/sim_tick_profiler.gd",
	"res://tools/sim_performance_smoothness_smoke.gd",
	"res://tools/diag_stall_audit.gd",
]

func _initialize() -> void:
	var failures := 0
	for t in TARGETS:
		var res: Script = load(t)
		if res == null:
			print("PAUSE_PARSE: %s -> FAILED TO LOAD" % t)
			failures += 1
		elif res.can_instantiate():
			print("PAUSE_PARSE: %s -> OK" % t)
		else:
			var msg: String = res.get_script_error_message() if res.has_method("get_script_error_message") else "n/a"
			var line: int = res.get_script_error_line() if res.has_method("get_script_error_line") else -1
			print("PAUSE_PARSE: %s -> ERROR line=%d msg=%s" % [t, line, msg])
			failures += 1
	print("PAUSE_PARSE: failures=%d targets=%d" % [failures, TARGETS.size()])
	quit(0 if failures == 0 else 1)