extends SceneTree

## Smoke test for PawnMoodUI.set_pawn(pawn_id) through Main/PawnSpawner chain.

const BOOT_WAIT_FRAMES: int = 10
var _frame_count: int = 0
var _main_spawned: bool = false
var _done: bool = false
var _failures: Array[String] = []


func _initialize() -> void:
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("pause"):
		gm.call("pause")
	call_deferred("_spawn_main")


func _spawn_main() -> void:
	print("[SETPAWN_SMOKE] loading Main.tscn")
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_failures.append("Main.tscn load failed")
		_report()
		return
	print("[SETPAWN_SMOKE] instantiating Main.tscn")
	var main: Node = packed.instantiate()
	print("[SETPAWN_SMOKE] adding Main to root")
	root.add_child(main)
	if main != null and main.has_method("_reroll_world"):
		print("[SETPAWN_SMOKE] calling _reroll_world")
		main.call("_reroll_world")
		print("[SETPAWN_SMOKE] _reroll_world completed")
	_main_spawned = true
	print("[SETPAWN_SMOKE] main spawned, waiting %d frames" % BOOT_WAIT_FRAMES)


func _process(_delta: float) -> bool:
	if _done:
		return false
	if not _main_spawned:
		return false
	_frame_count += 1
	if _frame_count < BOOT_WAIT_FRAMES:
		return false

	_done = true
	_run_test()
	return true


func _run_test() -> void:
	print("[SETPAWN_SMOKE] starting")

	var pa: Node = root.get_node_or_null("PawnAccess")
	if pa == null or not pa.has_method("find_alive_pawns"):
		_failures.append("PawnAccess not available")
		_report()
		return

	var pawns: Array = pa.call("find_alive_pawns")
	if pawns.is_empty():
		_failures.append("No alive pawns found after boot")
		_report()
		return

	var first_pawn = pawns[0]
	var pawn_data_raw: Variant = first_pawn.get("data") if first_pawn.has_method("get") else null
	var pawn_id: int = -1
	if pawn_data_raw != null and pawn_data_raw.has_method("get"):
		pawn_id = int(pawn_data_raw.get("id")) if pawn_data_raw.get("id") != null else -1
	if pawn_id < 0:
		_failures.append("Pawn has no valid id")
		_report()
		return

	var ui: Node = root.get_node_or_null("PawnMoodUI")
	if ui == null:
		_failures.append("PawnMoodUI autoload not found")
		_report()
		return

	ui.call("set_pawn", pawn_id)

	var stored_pawn_id: int = ui.get("_pawn_id") if ui.has_method("get") else -1
	if stored_pawn_id != pawn_id:
		_failures.append("_pawn_id mismatch: got %d expected %d" % [stored_pawn_id, pawn_id])

	var pawn_data: Variant = ui.get("_pawn_data") if ui.has_method("get") else null
	if pawn_data == null:
		_failures.append("_pawn_data is null after set_pawn(%d)" % pawn_id)
	else:
		var data_id: int = pawn_data.get("id") if pawn_data.has_method("get") else -1
		if data_id != pawn_id:
			_failures.append("_pawn_data.id mismatch: got %d expected %d" % [data_id, pawn_id])

		var dn: String = pawn_data.get("display_name") if pawn_data.has_method("get") else ""
		if dn.is_empty():
			_failures.append("_pawn_data.display_name is empty for pawn %d" % pawn_id)

		var mood_label: Label = ui.get("_mood_label") if ui.has_method("get") else null
		if mood_label == null:
			_failures.append("_mood_label not found after set_pawn")
		else:
			var expected_mood: int = int(pawn_data.get("mood")) if pawn_data.get("mood") != null else 0
			var expected_text: String = "%d/100" % expected_mood
			if mood_label.text != expected_text:
				_failures.append("mood_label.text was '%s' expected '%s'" % [mood_label.text, expected_text])

	_report()


func _report() -> void:
	if _failures.is_empty():
		print("[SETPAWN_SMOKE] PASS")
	else:
		for f in _failures:
			printerr("[SETPAWN_SMOKE] FAIL: " + f)
		print("[SETPAWN_SMOKE] FAILED (%d failures)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
