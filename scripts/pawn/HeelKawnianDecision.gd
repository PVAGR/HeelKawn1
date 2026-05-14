class_name HeelKawnianDecision
extends RefCounted

## Central decision system for HeelKawnian pawns.
## Each pawn consults this system to decide what to do next.
## Decisions are driven by: Matrix profile (drive, next_need, phase),
## local conditions (features, stockpiles, population), and needs.
## All deterministic — uses WorldRNG for any variance.

## Result of a decision: what job to pursue and why.
var job_type: int = -1
var target_tile: Vector2i = Vector2i(-1, -1)
var priority: int = 5
var reason: String = ""
var drive: String = ""


## Compute a decision for the given pawn context.
## Returns a populated HeelKawnianDecision or null if no action is needed.
static func decide(
	pawn_data: HeelKawnianData,
	profile: Dictionary,
	world,
	tick: int
) -> HeelKawnianDecision:
	if pawn_data == null or profile.is_empty():
		return null
	var d: HeelKawnianDecision = HeelKawnianDecision.new()
	d.drive = str(profile.get("development_drive", "serve_settlement"))
	var next_need: String = str(profile.get("next_need", "serve local needs"))
	var local_features: Dictionary = HeelKawnianManager._scan_local_features(pawn_data.tile_pos, 10)
	var hearths: int = int(local_features.get("hearth", 0))
	var beds: int = int(local_features.get("bed", 0))
	var storage_huts: int = int(local_features.get("storage_hut", 0))
	var walls: int = int(local_features.get("wall", 0))
	var doors: int = int(local_features.get("door", 0))
	var local_pop: int = int(local_features.get("population", 1))
	var stock_wood: int = 0
	var stock_stone: int = 0
	var stock_food: int = 0
	var _sm = _root_node("StockpileManager")
	if _sm != null:
		if _sm.has_method("total_count_of"):
			stock_wood = int(_sm.call("total_count_of", 3))
			stock_stone = int(_sm.call("total_count_of", 2))
		if _sm.has_method("total_food"):
			stock_food = int(_sm.call("total_food"))
	# Survival first: if starving or food critically low
	var hunger: float = float(pawn_data.hunger)
	if hunger <= 20.0 or stock_food < 10:
		d.job_type = Job.Type.FORAGE if WorldRNG.rangei(0, 100, tick, &"decide_food") < 70 else Job.Type.HUNT
		d.priority = 10
		d.reason = "survival: food critical"
		return d
	# Drive-based decisions
	match d.drive:
		"survive":
			if hearths <= 0:
				d.job_type = Job.Type.BUILD_FIRE_PIT
				d.priority = 9
				d.reason = "drive=survive: no hearth"
			elif beds < maxi(2, int(round(local_pop / 2.2))):
				d.job_type = Job.Type.BUILD_BED
				d.priority = 8
				d.reason = "drive=survive: need beds"
			elif stock_food < 30:
				d.job_type = Job.Type.FORAGE
				d.priority = 7
				d.reason = "drive=survive: stock food low"
			elif stock_wood < 10:
				d.job_type = Job.Type.CHOP
				d.priority = 6
				d.reason = "drive=survive: need wood"
			else:
				d.job_type = Job.Type.FORAGE
				d.priority = 5
				d.reason = "drive=survive: gather"
		"preserve":
			if storage_huts <= 0 and local_pop >= 3:
				d.job_type = Job.Type.BUILD_STORAGE_HUT
				d.priority = 9
				d.reason = "drive=preserve: need storage"
			elif int(local_features.get("marker", 0)) <= 0:
				d.job_type = Job.Type.BUILD_MARKER_STONE
				d.priority = 8
				d.reason = "drive=preserve: need marker"
			else:
				d.job_type = Job.Type.CARVE_KNOWLEDGE_STONE
				d.priority = 7
				d.reason = "drive=preserve: record knowledge"
		"innovate":
			if int(local_features.get("workshop", 0)) <= 0 and local_pop >= 3:
				d.job_type = Job.Type.BUILD_WORKSHOP
				d.priority = 9
				d.reason = "drive=innovate: need workshop"
			elif stock_wood < 5 or stock_stone < 3:
				d.job_type = Job.Type.CHOP if stock_wood < 5 else Job.Type.MINE
				d.priority = 7
				d.reason = "drive=innovate: gather materials"
			else:
				d.job_type = Job.Type.TOOL_MAKING
				d.priority = 8
				d.reason = "drive=innovate: craft tools"
		"bond":
			if hearths <= 0:
				d.job_type = Job.Type.BUILD_FIRE_PIT
				d.priority = 9
				d.reason = "drive=bond: no hearth"
			elif int(local_features.get("hearth", 0)) <= 1:
				d.job_type = Job.Type.BUILD_HEARTH
				d.priority = 8
				d.reason = "drive=bond: social hearth"
			elif int(local_features.get("tavern", 0)) <= 0 and local_pop >= 4:
				d.job_type = Job.Type.BUILD_MARKER_STONE
				d.priority = 7
				d.reason = "drive=bond: community space"
			else:
				d.job_type = Job.Type.TEACH_SKILL
				d.priority = 6
				d.reason = "drive=bond: teach"
		_:
			# serve_settlement or unknown — scan local needs
			if hearths <= 0:
				d.job_type = Job.Type.BUILD_FIRE_PIT
				d.priority = 9
				d.reason = "settlement need: no hearth"
			elif storage_huts <= 0 and local_pop >= 3:
				d.job_type = Job.Type.BUILD_STORAGE_HUT
				d.priority = 8
				d.reason = "settlement need: no storage"
			elif beds < maxi(2, int(round(local_pop / 2.2))):
				d.job_type = Job.Type.BUILD_BED
				d.priority = 7
				d.reason = "settlement need: more beds"
			elif walls < 4 and local_pop >= 4:
				d.job_type = Job.Type.BUILD_WALL
				d.priority = 6
				d.reason = "settlement need: walls"
			elif stock_wood < 5:
				d.job_type = Job.Type.CHOP
				d.priority = 5
				d.reason = "gather: need wood"
			elif stock_stone < 3:
				d.job_type = Job.Type.MINE
				d.priority = 5
				d.reason = "gather: need stone"
			elif stock_food < 20:
				d.job_type = Job.Type.FORAGE
				d.priority = 5
				d.reason = "gather: need food"
			else:
				d.job_type = Job.Type.FORAGE
				d.priority = 3
				d.reason = "default: gather"
	# Find target tile for the job
	if d.job_type >= 0:
		d.target_tile = _find_target_tile(pawn_data, d.job_type, world, tick)
	return d


## Find the best tile for a given job type near the pawn.
static func _find_target_tile(pawn_data: HeelKawnianData, job_type: int, world, tick: int) -> Vector2i:
	var origin: Vector2i = pawn_data.tile_pos
	var radius: int = 8
	if job_type == Job.Type.BUILD_WALL or job_type == Job.Type.BUILD_DOOR:
		radius = 12
	elif job_type == Job.Type.CHOP or job_type == Job.Type.MINE or job_type == Job.Type.FORAGE:
		radius = 15
	elif job_type == Job.Type.HUNT:
		radius = 20
	# Try to find a valid tile near the pawn
	for r in range(1, radius + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var tx: int = origin.x + dx
				var ty: int = origin.y + dy
				if tx < 0 or ty < 0 or tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
					continue
				if world != null and world.data != null:
					var feat: int = world.data.get_feature(tx, ty)
					if job_type == Job.Type.CHOP and feat == TileFeature.Type.TREE:
						return Vector2i(tx, ty)
					if job_type == Job.Type.MINE and feat == TileFeature.Type.ORE_VEIN:
						return Vector2i(tx, ty)
					if job_type == Job.Type.FORAGE and feat == TileFeature.Type.FERTILE_SOIL:
						return Vector2i(tx, ty)
					if job_type == Job.Type.HUNT:
						return Vector2i(tx, ty)
				# Build jobs: find empty passable tile
				if _is_build_job(job_type):
					if world != null and world.data != null and world.pathfinder != null:
						if WorldData.is_tile_walkable(world.data, tx, ty):
							return Vector2i(tx, ty)
	return Vector2i(-1, -1)


static func _is_build_job(jt: int) -> bool:
	return jt in [
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_BED, Job.Type.BUILD_WALL,
		Job.Type.BUILD_DOOR, Job.Type.BUILD_STORAGE_HUT, Job.Type.BUILD_SHELTER,
		Job.Type.BUILD_HEARTH, Job.Type.BUILD_MARKER_STONE, Job.Type.BUILD_WORKSHOP,
		Job.Type.BUILD_LIBRARY, Job.Type.BUILD_APOTHECARY, Job.Type.BUILD_MARKET,
		Job.Type.BUILD_BARRACKS, Job.Type.BUILD_GRANARY, Job.Type.BUILD_CELLAR,
		Job.Type.BUILD_FARM_WHEAT, Job.Type.BUILD_ROAD, Job.Type.CARVE_KNOWLEDGE_STONE,
	]


static func _root_node(name: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml != null and ml.has_node("/root/" + name):
		return ml.get_node("/root/" + name)
	return null
