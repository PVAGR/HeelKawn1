extends SceneTree

## P1 parse probe for the high-speed batching/coalescing change.
## Loads the scheduler + clock + F10 scripts and reports parse health.
## NEVER boots Main, NEVER advances a tick (load-only), so it cannot write a save.

const TARGETS := [
	"res://autoloads/TickManager.gd",
	"res://autoloads/SimulationClock.gd",
	"res://scripts/ui/CreatorDebugMenu.gd",
	"res://scripts/pawn/HeelKawnian.gd",
	"res://autoloads/SettlementMemory.gd",
]

func _initialize() -> void:
	var failures := 0
	for t in TARGETS:
		var res: Script = load(t)
		if res == null:
			print("P1_BATCH_PARSE: %s -> FAILED TO LOAD" % t)
			failures += 1
		elif res.can_instantiate():
			print("P1_BATCH_PARSE: %s -> OK" % t)
		else:
			var msg: String = res.get_script_error_message() if res.has_method("get_script_error_message") else "n/a"
			var line: int = res.get_script_error_line() if res.has_method("get_script_error_line") else -1
			print("P1_BATCH_PARSE: %s -> ERROR line=%d msg=%s" % [t, line, msg])
			failures += 1
	print("P1_BATCH_PARSE: failures=%d targets=%d" % [failures, TARGETS.size()])
	quit(0 if failures == 0 else 1)
