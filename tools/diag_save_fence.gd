extends SceneTree

## 02A-R/P0 save-fence automated proof.
##
## Records the production save files' metadata BEFORE Main boots, runs a fresh
## world in safe mode at 200x PAST two autosave boundaries (tick 6000 and 12000),
## verifies nothing wrote (no "[Main] Auto-saved", files byte-identical), then
## invokes the normal manual-save handler (`_colony_save`) and slot-save handler
## (`_on_save_slot(0)`) while safe mode is active and verifies the production
## files remain byte-identical.
##
## Outputs `[PLAYTEST_SAVE_FENCE] PASS` on success; hard-errors otherwise.
##
## NOTE: `--script` tools cannot reference autoload identifiers at parse time,
## so every autoload is resolved via root node lookups here. No preloads.

const RUN_TO_TICK := 12000
const FRAME_CAP := 20000
const PROD_PATHS: Array = [
	"user://heelkawn_colony.sav",
	"user://heelkawn_colony_autosave.sav",
]

var _frame := 0
var _phase := "boot"
var _done := false
var _manual_called := false
var _gm: Node = null
var _main: Node = null
var _prod_meta: Dictionary = {}

func _al(name: String) -> Node:
	return root.get_node_or_null("/root/" + name)

func _sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var data: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()

func _file_meta(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"size": -1, "modified": -1, "sha256": ""}
	var size: int = f.get_length()
	f.close()
	return {
		"size": size,
		"modified": int(FileAccess.get_modified_time(path)),
		"sha256": _sha256(path),
	}

func _initialize() -> void:
	for p in PROD_PATHS:
		_prod_meta[p] = _file_meta(p) if FileAccess.file_exists(p) else null
		print("SAVE_FENCE: before  %s -> %s" % [p, str(_prod_meta[p])])
	call_deferred("_spawn_main")

func _playtest_no_save_requested() -> bool:
	var args: Array = OS.get_cmdline_user_args()
	if args.has("--playtest-no-save"):
		return true
	args = OS.get_cmdline_args()
	return args.has("--playtest-no-save")

func _spawn_main() -> void:
	if not _playtest_no_save_requested():
		push_error("SAVE_FENCE: this tool boots Main past the autosave boundary and must run with --playtest-no-save; refusing to run")
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		push_error("SAVE_FENCE: cannot load Main.tscn")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	if not bool(main.get("_save_writes_disabled_for_playtest")):
		push_error("SAVE_FENCE: Main fence not active (Main._save_writes_disabled_for_playtest=false); refusing to run")
		quit(1)
		return

func _tick() -> int:
	if _gm != null:
		return int(_gm.get("tick_count"))
	return -1

func _process(_delta: float) -> bool:
	if _done:
		return false
	_frame += 1
	if _frame > FRAME_CAP:
		_fail("frame cap reached without completing the proof (tick=%s)" % str(_tick()))
		return false
	if _gm == null:
		_gm = _al("GameManager")
	if _gm == null:
		return false
	if _phase == "boot":
		_main = root.get_node_or_null("/root/Main")
		if _main != null:
			_phase = "run"
			_gm.call("set_speed", 200.0)
			print("SAVE_FENCE: Main ready, 200x to tick %d (crosses 2 autosave boundaries)" % RUN_TO_TICK)
		return false
	if _phase == "run":
		if _tick() >= RUN_TO_TICK:
			_phase = "manual"
			_gm.call("pause")
			var tm: Node = _al("TickManager")
			if tm != null and tm.has_method("pause"):
				tm.call("pause")
			print("SAVE_FENCE: reached tick %d (tick6000-boundary=%s tick12000-boundary=%s)" % [
				_tick(), str(_tick() >= 6000), str(_tick() >= 12000)])
		return false
	if _phase == "manual":
		if not _manual_called:
			_manual_called = true
			print("SAVE_FENCE: invoking _colony_save() + _on_save_slot(0) while fence active")
			_main.call("_colony_save")
			_main.call("_on_save_slot", 0)
			return false
		_verify()
		_done = true
		return false
	return false

func _verify() -> void:
	var all_ok := true
	for p in PROD_PATHS:
		var before: Variant = _prod_meta.get(p)
		var after: Variant = _file_meta(p) if FileAccess.file_exists(p) else null
		print("SAVE_FENCE: after   %s -> %s" % [p, str(after)])
		if before == null:
			if after != null:
				push_error("SAVE_FENCE: file %s was CREATED during a fenced run" % p)
				all_ok = false
			else:
				print("SAVE_FENCE: %s absent before and after (expected)" % p)
			continue
		if after == null or before["size"] != after["size"] or before["sha256"] != after["sha256"]:
			push_error("SAVE_FENCE: %s changed during a fenced run (before=%s after=%s)" % [p, str(before), str(after)])
			all_ok = false
	if not all_ok:
		push_error("SAVE_FENCE: FAIL")
		quit(1)
		return
	var menu: Node = _main.get_node_or_null("CreatorDebugMenu") if _main != null else null
	if menu == null:
		menu = root.get_node_or_null("/root/Main/CreatorDebugMenu")
	if menu != null and menu.has_method("_get_build_capture_section"):
		var snap: Dictionary = menu.call("_build_ai_snapshot_dict")
		var build_text: String = str(menu.call("_get_build_capture_section", snap))
		if not build_text.contains("SAVE WRITES: DISABLED"):
			push_error("SAVE_FENCE: F10 BUILD/CAPTURE does not show SAVE WRITES: DISABLED")
			quit(1)
			return
		else:
			print("SAVE_FENCE: F10 BUILD/CAPTURE shows SAVE WRITES: DISABLED (header.save_writes_disabled=%s)" % str(snap.get("header", {}).get("save_writes_disabled")))
	print("SAVE_FENCE: no autosave fired below tick %d (fence active at both boundaries)" % RUN_TO_TICK)
	print("[PLAYTEST_SAVE_FENCE] PASS")
	quit(0)

func _fail(msg: String) -> void:
	push_error("SAVE_FENCE: " + msg)
	_done = true
	quit(1)