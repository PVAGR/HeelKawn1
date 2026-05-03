extends SceneTree

## Headless WorldMeaning region tags validation.
## Run: Godot --headless --path . -s res://tools/sim_worldmeaning_region_tags_smoke.gd
##
## Proves:
##   1. get_region_tags(region_key) public API exists and returns PackedStringArray.
##   2. Tags are deterministic — same input produces same output.
##   3. Returned tags are valid known strings from the canonical set.
##   4. At least one region can be queried (even if it returns empty tags).
##   5. No mutation of WorldMemory / SettlementMemory is required.
##
## Does NOT prove:
##   - That tags are non-empty (depends on recorded events).
##   - That tag transitions occur over time.
##   - Zone-level tags (get_zone_tags) — only region-level.

const VALID_REGION_TAGS: Array[String] = [
	# Construction
	"built_up",
	"developed",
	"ruined",
	# Fire
	"fire_prone",
	"burned",
	# Starvation
	"famine_stricken",
	"hungry",
	"hunger_place",
	# Knowledge
	"learned",
	"educated",
	# Migration
	"cosmopolitan",
	"welcoming",
	# Death
	"graveyard",
	"blood_soaked",
	"repeated_death",
	# Positive
	"safe_hearth",
]

const MIN_TICK: int = 10
const TIMEOUT_FRAMES: int = 1800

var _done: bool = false
var _started: bool = false
var _main_spawned: bool = false
var _frame_count: int = 0


func _process(_delta: float) -> bool:
	if _done:
		return false

	if not _started:
		_started = true
		var gm_hold: Node = root.get_node_or_null("GameManager")
		if gm_hold != null and gm_hold.has_method("pause"):
			gm_hold.call("pause")
		call_deferred("_spawn_main")
		return false

	if not _main_spawned:
		return false

	_frame_count += 1
	if _frame_count > TIMEOUT_FRAMES:
		print("[WORLDMEANING_TAGS_FAIL] reason=frame_limit_exceeded")
		_done = true
		quit(1)
		return true

	var gm: Node = root.get_node_or_null("GameManager")
	if gm == null:
		return false
	var tick: int = int(gm.get("tick_count"))

	if tick >= MIN_TICK and not _done:
		_done = true
		_validate(tick)
		return true
	return false


func _spawn_main() -> void:
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		print("[WORLDMEANING_TAGS_FAIL] reason=Main_load_failed")
		quit(1)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Resume TickManager (set_speed in Main._ready unpauses GameManager but not TickManager)
	var tm: Node = root.get_node_or_null("TickManager")
	if tm != null and tm.has_method("resume"):
		tm.call("resume")
	var gm: Node = root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("resume"):
		gm.call("resume")
	_main_spawned = true


func _validate(tick: int) -> void:
	print("[WORLDMEANING_TAGS] START")

	var wm: Node = root.get_node_or_null("WorldMeaning")
	if wm == null:
		print("[WORLDMEANING_TAGS_FAIL] reason=WorldMeaning_not_found")
		quit(1)
		return

	# --- Test 1: get_region_tags API exists ---
	if not wm.has_method("get_region_tags"):
		print("[WORLDMEANING_TAGS_FAIL] reason=get_region_tags_method_missing")
		quit(1)
		return

	# --- Test 2: query a known-absent region (0) — should return empty, not crash ---
	var empty_tags: PackedStringArray = wm.call("get_region_tags", 0)
	if not (empty_tags is PackedStringArray):
		print("[WORLDMEANING_TAGS_FAIL] reason=return_type_not_PackedStringArray")
		quit(1)
		return
	print("[WORLDMEANING_TAGS] region=0 tags=%s facts_checked=0" % str(empty_tags))

	# --- Test 3: determinism — same query twice must produce same result ---
	var empty_tags_2: PackedStringArray = wm.call("get_region_tags", 0)
	if empty_tags != empty_tags_2:
		print("[WORLDMEANING_TAGS_FAIL] reason=non_deterministic_empty_query")
		quit(1)
		return

	# --- Test 4: iterate actual regions with recorded facts ---
	var region_count: int = int(wm.call("region_count"))
	var regions_with_tags: int = 0
	var total_facts_checked: int = 0
	# meaning_by_region is a public var — access via get() on the script object
	var meaning_raw: Variant = wm.get("meaning_by_region")
	var meaning_by_region: Dictionary = {}
	if meaning_raw is Dictionary:
		meaning_by_region = meaning_raw as Dictionary

	for rk in meaning_by_region.keys():
		var region_key: int = int(rk)
		var tags: PackedStringArray = wm.call("get_region_tags", region_key)
		if not (tags is PackedStringArray):
			print("[WORLDMEANING_TAGS_FAIL] region=%d reason=tags_not_PackedStringArray" % region_key)
			quit(1)
			return

		# Validate each tag is a known string
		var facts_checked: int = 0
		for tag in tags:
			facts_checked += 1
			if not (tag is String):
				print("[WORLDMEANING_TAGS_FAIL] region=%d reason=tag_not_string" % region_key)
				quit(1)
				return
			if str(tag) not in VALID_REGION_TAGS:
				print("[WORLDMEANING_TAGS_FAIL] region=%d reason=unknown_tag value=%s" % [region_key, str(tag)])
				quit(1)
				return

		# Determinism check on real region
		var tags_2: PackedStringArray = wm.call("get_region_tags", region_key)
		if tags != tags_2:
			print("[WORLDMEANING_TAGS_FAIL] region=%d reason=non_deterministic" % region_key)
			quit(1)
			return

		if tags.size() > 0:
			regions_with_tags += 1
		total_facts_checked += facts_checked
		print("[WORLDMEANING_TAGS] region=%d tags=%s facts_checked=%d" % [region_key, str(tags), facts_checked])

	# --- Test 5: at least one region can be queried (even if empty) ---
	# The bootstrap region (stockpile area) should be queryable
	var sm: Node = root.get_node_or_null("SettlementMemory")
	if sm != null and sm.has_method("get_settlements"):
		var settlements: Array = sm.call("get_settlements")
		if settlements.size() > 0:
			var s0: Dictionary = settlements[0] as Dictionary
			var center: int = int(s0.get("center_region", -1))
			if center >= 0:
				var center_tags: PackedStringArray = wm.call("get_region_tags", center)
				print("[WORLDMEANING_TAGS] region=%d tags=%s facts_checked=%d settlement_center=yes" % [center, str(center_tags), center_tags.size()])

	print("[WORLDMEANING_TAGS] tick=%d region_count=%d regions_with_tags=%d total_facts_checked=%d" % [
		tick, region_count, regions_with_tags, total_facts_checked
	])
	print("[WORLDMEANING_TAGS_PASS] deterministic_region_tags_valid")
	quit(0)
