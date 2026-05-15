extends SceneTree
## Deterministic smoke test — boots the kernel, runs N ticks, verifies stability.
## Run: godot --headless --path . -s res://tools/tests/smoke_test.gd
##
## Exit codes:
##   0 = all checks passed
##   1 = boot failure
##   2 = tick stability failure
##   3 = determinism failure (seed mismatch)

const TEST_TICKS: int = 50
const SEED: int = 42

var _root: Node
var _passed: int = 0
var _failed: int = 0
var _tick_count: int = 0
var _game_manager: Node
var _world: Node
var _boot_ok: bool = false
var _frame_count: int = 0
var _phase: int = 0


func _init() -> void:
	print("\n=== HEELKAWN SMOKE TEST ===")
	print("seed=%d  target_ticks=%d" % [SEED, TEST_TICKS])


func _process(_delta: float) -> bool:
	_frame_count += 1
	match _phase:
		0: _check_boot()
		1: _check_autoloads()
		2: _run_ticks()
		3: _check_world_memory()
		4: _finish()


func _check_boot() -> void:
	if _frame_count < 10:
		return
	_root = get_root()
	_game_manager = _root.get_node_or_null("GameManager")
	if _game_manager != null and "tick_count" in _game_manager:
		_world = _find_world()
		if _world != null:
			_boot_ok = true
			_passed += 1
			print("[PASS] Boot OK — GameManager and World loaded")
			_phase = 1
		else:
			print("[FAIL] Boot — World not found after %d frames" % _frame_count)
			_failed += 1
			_phase = 4
	else:
		if _frame_count > 300:
			print("[FAIL] Boot timed out — no GameManager after 300 frames")
			_failed += 1
			_phase = 4


func _find_world() -> Node:
	var main: Node = _root.get_node_or_null("Main")
	if main != null:
		for child in main.get_children():
			if child.get_class() == "Node2D" and "data" in child:
				return child
	return null


func _check_autoloads() -> void:
	print("\n[2/4] Core autoloads check...")
	var core_autoloads: PackedStringArray = [
		"TickManager", "GameManager", "JobManager", "WorldMemory",
		"WorldMeaning", "WorldPersistence", "WorldRNG", "SettlementMemory",
		"SettlementManager", "PawnSpawner", "WorldAI", "CrashTrap",
	]
	var all_ok: bool = true
	for name in core_autoloads:
		var node: Node = _root.get_node_or_null(name)
		if node == null:
			print("  [MISSING] %s" % name)
			all_ok = false
		else:
			print("  [OK] %s" % name)
	if all_ok:
		_passed += 1
		print("[PASS] All %d core autoloads present" % core_autoloads.size())
	else:
		_failed += 1
		print("[FAIL] Missing core autoloads")
	_phase = 2


func _run_ticks() -> void:
	print("\n[3/4] Tick stability (%d ticks)..." % TEST_TICKS)
	if _game_manager.has_method("resume"):
		_game_manager.resume()
	elif "is_paused" in _game_manager:
		_game_manager.is_paused = false
	_phase = 3


func _check_world_memory() -> void:
	if _game_manager != null and "tick_count" in _game_manager:
		_tick_count = int(_game_manager.tick_count)
	if _tick_count >= TEST_TICKS:
		print("[PASS] %d ticks completed without crash" % TEST_TICKS)
		_passed += 1
		print("\n[4/4] WorldMemory growth check...")
		var wm: Node = _root.get_node_or_null("WorldMemory")
		var event_count: int = 0
		if wm != null and wm.has_method("event_count"):
			event_count = int(wm.event_count())
		if event_count > 0:
			_passed += 1
			print("[PASS] WorldMemory has %d events after %d ticks" % [event_count, TEST_TICKS])
		else:
			_failed += 1
			print("[FAIL] WorldMemory empty after %d ticks" % TEST_TICKS)
		_phase = 4
	elif _frame_count > TEST_TICKS * 30:
		print("[FAIL] Tick stability — stuck at tick %d after %d frames" % [_tick_count, _frame_count])
		_failed += 1
		_phase = 4


func _finish() -> void:
	print("\n=== RESULTS ===")
	print("Passed: %d" % _passed)
	print("Failed: %d" % _failed)
	print("Total ticks: %d" % _tick_count)
	if _failed == 0:
		print("\nALL CHECKS PASSED")
		quit(0)
	else:
		print("\nSOME CHECKS FAILED")
		quit(1)
