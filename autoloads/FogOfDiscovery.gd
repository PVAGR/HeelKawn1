extends Node
## FogOfDiscovery — pawn interaction limiter + needs-based job posting.
## Pawns discover tiles by walking near them. Only discovered tiles get jobs.
## The spectator sees everything — this is a CPU saver, not a visual blocker.
## Jobs are posted based on actual population needs (per-capita economy),
## not just because resources exist. Prevents job spam and CPU overload.
## Uses PackedByteArray (64KB) for O(1) per-tile discovery checks.

const DISCOVERY_RADIUS: int = 12
const DISCOVERY_CHECK_INTERVAL: int = 10
const STOCKPILE_DISCOVERY_RADIUS: int = 20

var _discovered: PackedByteArray = PackedByteArray()
var _world_ref: WeakRef = WeakRef.new()

# === Per-capita needs-based economy ===
# Hunger decays at 0.03/tick. A "day" ≈ 1000 ticks.
# Daily hunger drain = 30 points. One berry = 60, one meat = 85.
# A pawn needs ~0.5 berries/day or ~0.35 meat/day.
# We post enough food jobs to cover 2 days of buffer (survival margin).
# Building materials scale with population too — more pawns = more building.

const FOOD_JOBS_PER_PAWN: float = 1.0       # 1 forage/hunt job per pawn keeps food flowing
const WOOD_JOBS_PER_PAWN: float = 0.5       # 1 chop job per 2 pawns (building + fuel)
const STONE_JOBS_PER_PAWN: float = 0.3      # 1 mine job per ~3 pawns (construction)
const FOOD_BUFFER_DAYS: int = 2             # Keep 2 days of food buffer in stockpile
const HUNGER_PER_TICK: float = 0.03         # Matches HeelKawnian.gd HUNGER_DECAY_PER_TICK
const BERRY_HUNGER_RESTORE: float = 60.0     # Matches Item.gd
const MEAT_HUNGER_RESTORE: float = 85.0     # Matches Item.gd
const TICKS_PER_DAY: int = 1000

# Cached counts — recalculated every DISCOVERY_CHECK_INTERVAL
var _cached_food_jobs_needed: int = 0
var _cached_wood_jobs_needed: int = 0
var _cached_stone_jobs_needed: int = 0
var _cached_hunt_jobs_needed: int = 0


func _ready() -> void:
	_discovered.resize(WorldData.TILE_COUNT)
	_discovered.fill(0)
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)


func _exit_tree() -> void:
	if GameManager != null and GameManager.game_tick.is_connected(_on_game_tick):
		GameManager.game_tick.disconnect(_on_game_tick)


func set_world(world: World) -> void:
	_world_ref = weakref(world)


func is_discovered(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return false
	return _discovered[y * WorldData.WIDTH + x] != 0


func discover(x: int, y: int) -> void:
	if x < 0 or y < 0 or x >= WorldData.WIDTH or y >= WorldData.HEIGHT:
		return
	var idx: int = y * WorldData.WIDTH + x
	if _discovered[idx] != 0:
		return
	_discovered[idx] = 1
	_post_job_for_feature(x, y)


## Pre-discover an area around a center tile (used at bootstrap for stockpile area)
func discover_area(center_x: int, center_y: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var tx: int = center_x + dx
			var ty: int = center_y + dy
			discover(tx, ty)


func total_discovered() -> int:
	var count: int = 0
	for i in range(_discovered.size()):
		if _discovered[i] != 0:
			count += 1
	return count


func clear() -> void:
	_discovered.fill(0)
	_cached_food_jobs_needed = 0
	_cached_wood_jobs_needed = 0
	_cached_stone_jobs_needed = 0
	_cached_hunt_jobs_needed = 0


func _on_game_tick(tick: int) -> void:
	if tick % DISCOVERY_CHECK_INTERVAL != 0:
		return
	var pawns: Array = PawnAccess.find_pawns()
	# Discover tiles around each pawn
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var px: int = int(pawn.data.tile_pos.x)
		var py: int = int(pawn.data.tile_pos.y)
		_discover_radius(px, py)
	# Recalculate per-capita job needs
	_recalculate_needs(pawns)


func _discover_radius(cx: int, cy: int) -> void:
	var r2: int = DISCOVERY_RADIUS * DISCOVERY_RADIUS
	for dy in range(-DISCOVERY_RADIUS, DISCOVERY_RADIUS + 1):
		for dx in range(-DISCOVERY_RADIUS, DISCOVERY_RADIUS + 1):
			if dx * dx + dy * dy > r2:
				continue
			var tx: int = cx + dx
			var ty: int = cy + dy
			if tx < 0 or ty < 0 or tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
				continue
			discover(tx, ty)


## Per-capita needs calculation.
## How many food/wood/stone jobs should be open right now?
## Based on: population × need_rate, minus what's already in stockpile.
func _recalculate_needs(pawns: Array) -> void:
	var pop: int = 0
	for p in pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			pop += 1
	if pop == 0:
		_cached_food_jobs_needed = 0
		_cached_wood_jobs_needed = 0
		_cached_stone_jobs_needed = 0
		_cached_hunt_jobs_needed = 0
		return

	# Count current open jobs by type
	var open_food: int = 0
	var open_wood: int = 0
	var open_stone: int = 0
	var open_hunt: int = 0
	if JobManager != null:
		for job in JobManager._open:
			if job == null:
				continue
			var jt: int = job.type
			if jt == Job.Type.FORAGE:
				open_food += 1
			elif jt == Job.Type.MINE or jt == Job.Type.MINE_WALL:
				open_stone += 1
			elif jt == Job.Type.CHOP:
				open_wood += 1
			elif jt == Job.Type.HUNT:
				open_hunt += 1

	# Count food in stockpile
	var stock_food: int = 0
	if StockpileManager != null and not StockpileManager._zones.is_empty():
		for zone in StockpileManager._zones:
			if zone != null and is_instance_valid(zone):
				stock_food += int(zone.count_food())

	# How many days of food do we have in stockpile?
	# Each pawn eats ~0.5 berries/day (30 hunger/day ÷ 60 hunger/berry)
	var food_days_in_stock: float = float(stock_food) / (float(pop) * 0.5) if pop > 0 else 999.0

	# Target: keep FOOD_BUFFER_DAYS of food. If we have enough, fewer food jobs.
	var food_deficit: float = max(0.0, FOOD_BUFFER_DAYS - food_days_in_stock)
	# Each food job produces ~1 item. Need deficit × pop × 0.5 items to fill.
	var target_food_jobs: int = int(ceil(food_deficit * float(pop) * 0.5))
	# Minimum: always keep at least 1 food job per pawn (they need to eat daily)
	target_food_jobs = maxi(target_food_jobs, int(ceil(float(pop) * FOOD_JOBS_PER_PAWN)))

	# Split food jobs between forage and hunt (70/30 — berries are easier)
	var target_forage: int = int(ceil(float(target_food_jobs) * 0.7))
	var target_hunt: int = int(ceil(float(target_food_jobs) * 0.3))

	# Building materials: scale with population
	var target_wood: int = int(ceil(float(pop) * WOOD_JOBS_PER_PAWN))
	var target_stone: int = int(ceil(float(pop) * STONE_JOBS_PER_PAWN))

	# Only post new jobs if we're below target
	_cached_food_jobs_needed = maxi(0, target_forage - open_food)
	_cached_wood_jobs_needed = maxi(0, target_wood - open_wood)
	_cached_stone_jobs_needed = maxi(0, target_stone - open_stone)
	_cached_hunt_jobs_needed = maxi(0, target_hunt - open_hunt)


func _post_job_for_feature(x: int, y: int) -> void:
	if JobManager == null:
		return
	var w: World = _world_ref.get_ref() as World
	if w == null or w.data == null:
		return
	var tile: Vector2i = Vector2i(x, y)
	if JobManager.has_job_at(tile):
		return
	var feature: int = int(w.data.get_feature(x, y))
	if feature == TileFeature.Type.FERTILE_SOIL:
		if _cached_food_jobs_needed > 0:
			var fj: Job = JobManager.post(Job.Type.FORAGE, tile)
			if fj != null:
				JobManager.stamp_seeder_metadata(fj, "fog_discovery_seed", "nearby")
			_cached_food_jobs_needed -= 1
	elif feature == TileFeature.Type.ORE_VEIN:
		if _cached_stone_jobs_needed > 0:
			var mj: Job = JobManager.post(Job.Type.MINE, tile)
			if mj != null:
				JobManager.stamp_seeder_metadata(mj, "fog_discovery_seed", "nearby")
			_cached_stone_jobs_needed -= 1
	elif feature == TileFeature.Type.TREE:
		if _cached_wood_jobs_needed > 0:
			var cj: Job = JobManager.post(Job.Type.CHOP, tile)
			if cj != null:
				JobManager.stamp_seeder_metadata(cj, "fog_discovery_seed", "nearby")
			_cached_wood_jobs_needed -= 1
	elif TileFeature.is_wildlife(feature):
		if _cached_hunt_jobs_needed > 0:
			var hj: Job = JobManager.post(Job.Type.HUNT, tile)
			if hj != null:
				JobManager.stamp_seeder_metadata(hj, "fog_discovery_seed", "nearby")
			_cached_hunt_jobs_needed -= 1
