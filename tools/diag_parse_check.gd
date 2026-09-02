extends SceneTree

const TARGETS := [
	"res://scripts/ui/CreatorDebugMenu.gd",
	"res://scripts/pawn/HeelKawnian.gd",
	"res://autoloads/SettlementMemory.gd",
	"res://scenes/main/Main.gd",
	"res://tools/f10_live_data_regression.gd",
	"res://tools/diag_save_fence.gd",
]

func _initialize() -> void:
	for t in TARGETS:
		var res: Script = load(t)
		if res == null:
			print("PARSE_CHECK: %s -> FAILED TO LOAD" % t)
		elif res.can_instantiate():
			print("PARSE_CHECK: %s -> OK" % t)
		else:
			var msg: String = res.get_script_error_message() if res.has_method("get_script_error_message") else "n/a"
			var line: int = res.get_script_error_line() if res.has_method("get_script_error_line") else -1
			print("PARSE_CHECK: %s -> ERROR line=%d msg=%s" % [t, line, msg])
	quit()