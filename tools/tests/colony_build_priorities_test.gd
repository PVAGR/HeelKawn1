extends SceneTree
## Validates ColonySimServices.build priority helpers without a full play session.
## Run: godot --headless --path . -s res://tools/tests/colony_build_priorities_test.gd

const SEED: int = 7


func _init() -> void:
	print("\n=== COLONY BUILD PRIORITIES TEST ===")


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	_run_checks()
	quit(0 if _failed == 0 else 1)


var _failed: int = 0
var _passed: int = 0


func _run_checks() -> void:
	if ColonySimServices == null:
		print("[FAIL] ColonySimServices autoload missing")
		_failed += 1
		return
	_test_estimate_farm_cap()
	_test_compute_priorities_shape()
	_test_can_seed_fire_pit_shape()


func _assert_true(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		print("[FAIL] %s" % label)


func _test_estimate_farm_cap() -> void:
	var low: int = ColonySimServices.estimate_farm_cap(10, 0.2, 0)
	var high: int = ColonySimServices.estimate_farm_cap(10, 0.85, 0)
	_assert_true(low >= 2, "farm_cap baseline for pop 10")
	_assert_true(high >= low, "farm_cap rises with food pressure")


func _test_compute_priorities_shape() -> void:
	var features: Dictionary = {"hearth": 0, "bed": 0, "storage_hut": 0, "farm": 0}
	var pri: Dictionary = ColonySimServices.compute_settlement_build_priorities(-1, 6, features, false)
	_assert_true(pri.has("ranked_needs"), "priorities include ranked_needs")
	_assert_true(pri.has("job_cap"), "priorities include job_cap")
	_assert_true(pri.has("farm_cap"), "priorities include farm_cap")
	_assert_true(int(pri.get("job_cap", 0)) >= 1, "job_cap positive")
	var ranked: Array = pri.get("ranked_needs", [])
	_assert_true(not ranked.is_empty(), "ranked_needs non-empty for needy settlement")


func _test_can_seed_fire_pit_shape() -> void:
	var ok: bool = ColonySimServices.can_seed_fire_pit(-1, Vector2i(64, 64), 0, 1)
	_assert_true(ok is bool, "can_seed_fire_pit returns bool")
