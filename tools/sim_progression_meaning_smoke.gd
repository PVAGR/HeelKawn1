extends SceneTree

## Headless smoke test for Gate 5: ProgressionSystem -> WorldMeaning integration.
## Run: godot --path . --headless -s res://tools/sim_progression_meaning_smoke.gd

var _test_done: bool = false

func _init() -> void:
	print("=== GATE-5 PROGRESSION MEANING SMOKE TEST ===")

func _process(_delta: float) -> bool:
	if _test_done:
		return false
	_test_done = true

	# Validate autoloads
	var ps = get_node_or_null("/root/ProgressionSystem")
	var wm = get_node_or_null("/root/WorldMeaning")
	if ps == null or wm == null:
		print("[FAIL] ProgressionSystem or WorldMeaning missing")
		quit(1)
		return true

	# Record test impacts
	ps.record_impact(1, 1500, "build_shelter")  # >1000 threshold
	ps.record_impact(2, 6000, "teach_skill")    # >5000 threshold

	# Recompute meaning
	wm.recompute()

	# Test region 0 (default)
	var region_key: int = 0  # or WorldMemory._region_key(0,0)
	var meaning: Dictionary = wm.get_region_meaning(region_key)
	if not meaning.has("influential_here") or not meaning["influential_here"]:
		print("[FAIL] influential_here tag not set (impact=1500)")
		quit(2)
		return true
	if not meaning.has("legendary_land") or not meaning["legendary_land"]:
		print("[FAIL] legendary_land tag not set (impact=6000)")
		quit(3)
		return true

	print("[PASS] Gate 5: ProgressionSystem impacts propagate to WorldMeaning tags")
	print("Test complete.")
	quit(0)
	return true
