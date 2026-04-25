extends Node
## v1: Derived (not saved) — recurring trade pairs, soft supplier/dependent roles, route tiers on tiles.
## Updated on [JobManager.job_completed] for [Job.Type.TRADE_HAUL] only; no per-tick work.

const ROUTE_T1: int = 3
const ROUTE_T2: int = 8
const TIER_NONE: int = 0
const TIER_ROUTE_1: int = 1
const TIER_ROUTE_2: int = 2
const PATH_W_T2: float = 0.94

## Role: [ROLE_BALANCED] if within one of parity; [ROLE_SUPPLIER] if exports run ahead; [ROLE_DEPENDENT] if imports do.
const ROLE_BALANCED: int = 0
const ROLE_SUPPLIER: int = 1
const ROLE_DEPENDENT: int = 2
const ROLE_GAP: int = 2

## pair_key (u64) -> completed trade count
var _pair_count: Dictionary = {}
## pair_key -> last GameManager tick when a trade completed
var _pair_last_tick: Dictionary = {}
## center_region -> total completed exports / imports
var _exports: Dictionary = {}
var _imports: Dictionary = {}
## per tile: 0 none, 1 T1, 2 T2 (T2 overwrites T1 on same tile)
var _route_tier: PackedInt32Array = PackedInt32Array()
## Last [GameManager] tick a T2 trade-route tile was present (set by [update_t2_collapse_cursor]).
var _last_tick_t2_existed: int = -1

var _ready_connected: bool = false


func _ready() -> void:
	_ensure_route_buffer()
	if not _ready_connected:
		_ready_connected = true
		JobManager.job_completed.connect(_on_job_completed)


func _ensure_route_buffer() -> void:
	if _route_tier.size() == WorldData.TILE_COUNT:
		return
	_route_tier.resize(WorldData.TILE_COUNT)
	for i0 in range(WorldData.TILE_COUNT):
		_route_tier[i0] = 0


## Clear on world reroll; routes and counters are re-derived only from new play.
func clear() -> void:
	_pair_count.clear()
	_pair_last_tick.clear()
	_exports.clear()
	_imports.clear()
	_ensure_route_buffer()
	for i1 in range(WorldData.TILE_COUNT):
		_route_tier[i1] = 0
	_last_tick_t2_existed = -1


static func pair_key_for_centers(c_a: int, c_b: int) -> int:
	var lo: int = mini(c_a, c_b)
	var hi: int = maxi(c_a, c_b)
	# Two 32-bit region keys combined (center_region is a packed u32 key).
	return (lo & 0xFFFFFFFF) | ((hi & 0xFFFFFFFF) << 32)


func get_route_tier_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return TIER_NONE
	_ensure_route_buffer()
	return int(_route_tier[y * WorldData.WIDTH + x])


## Extra path multiplier after [RoadMemory] and with scar/myth; T2 only (T1 is visual).
func get_trade_path_weight_mul(x: int, y: int) -> float:
	if get_route_tier_at(x, y) >= TIER_ROUTE_2:
		return PATH_W_T2
	return 1.0


func get_exports(center_region: int) -> int:
	return int(_exports.get(center_region, 0))


func get_imports(center_region: int) -> int:
	return int(_imports.get(center_region, 0))


func get_role(center_region: int) -> int:
	var ex: int = get_exports(center_region)
	var im: int = get_imports(center_region)
	if ex >= im + ROLE_GAP:
		return ROLE_SUPPLIER
	if im >= ex + ROLE_GAP:
		return ROLE_DEPENDENT
	return ROLE_BALANCED


func get_pair_trade_count(c_a: int, c_b: int) -> int:
	var k: int = pair_key_for_centers(c_a, c_b)
	return int(_pair_count.get(k, 0))


func get_last_trade_tick(c_a: int, c_b: int) -> int:
	var k2: int = pair_key_for_centers(c_a, c_b)
	return int(_pair_last_tick.get(k2, -1))


func count_t2_tiles() -> int:
	_ensure_route_buffer()
	var n2: int = 0
	for i2 in range(WorldData.TILE_COUNT):
		if int(_route_tier[i2]) >= TIER_ROUTE_2:
			n2 += 1
	return n2


## Route corridor tiles (T1+T2) for density classifiers.
func count_route_tiles() -> int:
	_ensure_route_buffer()
	var n3: int = 0
	for i3 in range(WorldData.TILE_COUNT):
		if int(_route_tier[i3]) > TIER_NONE:
			n3 += 1
	return n3


## Call from [AgeMemory] on its cadence so [last-t2-existed] tracks while T2 is on the map.
func update_t2_collapse_cursor() -> void:
	if count_t2_tiles() > 0:
		_last_tick_t2_existed = GameManager.tick_count


func get_last_tick_t2_existed() -> int:
	return _last_tick_t2_existed


func _on_job_completed(job: Job) -> void:
	if job == null or job.type != Job.Type.TRADE_HAUL:
		return
	var c_from: int = _center_for_stockpile(job.trade_from)
	var c_to: int = _center_for_stockpile(job.trade_to)
	if c_from < 0 or c_to < 0 or c_from == c_to:
		return
	_record_pair_and_flow(c_from, c_to)
	var w: World = _find_world()
	if w == null or w.pathfinder == null or w.data == null:
		return
	_apply_route_thresholds(w, c_from, c_to)
	w.refresh_trade_memory_terrain()
	w.refresh_pawn_historic_path_weights()
	IntentMemory.recompute(w)


func _record_pair_and_flow(c_from: int, c_to: int) -> void:
	var k: int = pair_key_for_centers(c_from, c_to)
	_pair_count[k] = int(_pair_count.get(k, 0)) + 1
	_pair_last_tick[k] = GameManager.tick_count
	_exports[c_from] = int(_exports.get(c_from, 0)) + 1
	_imports[c_to] = int(_imports.get(c_to, 0)) + 1


func _apply_route_thresholds(w: World, c_from: int, c_to: int) -> void:
	var k4: int = pair_key_for_centers(c_from, c_to)
	var n: int = int(_pair_count.get(k4, 0))
	var need_t1: bool = n >= ROUTE_T1
	var need_t2: bool = n >= ROUTE_T2
	if not need_t1:
		return
	var tier: int = TIER_ROUTE_2 if need_t2 else TIER_ROUTE_1
	_mark_path_for_pair(w, c_from, c_to, tier)


static func _center_for_stockpile(sp: Stockpile) -> int:
	if sp == null or not is_instance_valid(sp):
		return -1
	var best: int = 0x7FFFFFFF
	var found: bool = false
	for s_any in SettlementMemory.get_settlements():
		if not (s_any is Dictionary):
			continue
		var st: Dictionary = s_any as Dictionary
		var reg: Variant = st.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		if not _zone_overlaps_region_set(sp, reg as PackedInt32Array):
			continue
		var c: int = int(st.get("center_region", 0x7FFFFFFF))
		if c < best:
			best = c
			found = true
	if not found:
		return -1
	return best


static func _zone_overlaps_region_set(z: Stockpile, region_want: PackedInt32Array) -> bool:
	if z == null or region_want.is_empty():
		return false
	var r: Rect2i = z.rect
	for y3 in range(r.position.y, r.position.y + r.size.y):
		for x3 in range(r.position.x, r.position.x + r.size.x):
			var rk: int = WorldMemory._region_key(x3, y3)
			for u2 in range(region_want.size()):
				if int(region_want[u2]) == rk:
					return true
	return false


func _mark_path_for_pair(w: World, c_a: int, c_b: int, tier: int) -> void:
	var start: Vector2i = SettlementPlanner._center_tile_of_region_key(c_a)
	var goal: Vector2i = SettlementPlanner._center_tile_of_region_key(c_b)
	if not w.data.in_bounds(start.x, start.y) or not w.data.in_bounds(goal.x, goal.y):
		return
	# Geometric path for stable route paint (not historic-weighted; tile set is the same "corridor" aim).
	var steps: Array[Vector2i] = w.pathfinder.find_path(start, goal)
	if steps.is_empty():
		return
	# [steps] is every passable step after [start] through [goal] (see [PathFinder.find_path]).
	_ensure_route_buffer()
	_paint_tier_at(start, tier)
	for st in steps:
		_paint_tier_at(st, tier)


func _paint_tier_at(t: Vector2i, tier: int) -> void:
	if t.x < 0 or t.y < 0 or t.x >= WorldData.WIDTH or t.y >= WorldData.HEIGHT:
		return
	var i2: int = t.y * WorldData.WIDTH + t.x
	var cur5: int = int(_route_tier[i2])
	_route_tier[i2] = maxi(cur5, tier)
	if int(_route_tier[i2]) >= TIER_ROUTE_2 and cur5 < TIER_ROUTE_2:
		RemnantMemory.on_t2_painted(t.x, t.y)


func _find_world() -> World:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	for n in tree.get_nodes_in_group("colony_world"):
		if n is World:
			return n as World
	return null
