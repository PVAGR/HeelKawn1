extends Node
## Phase 4 Identity: Visual meaning for settlement states and cultures
## Handles visual transformations (graves, scorched earth) for permanently abandoned settlements
## without affecting gameplay mechanics (those remain in SettlementPlanner/SettlementMemory)

const ARCHITECT_INTERVAL_TICKS: int = 5000  # Run infrequently - visual updates only

var _last_architect_tick: int = -1_000_000_000


func process(world: World, main: Node2D) -> void:
	if world == null or not is_instance_valid(world) or world.data == null:
		return
	
	var tick_now: int = GameManager.tick_count
	if tick_now - _last_architect_tick < ARCHITECT_INTERVAL_TICKS:
		return
	
	_last_architect_tick = tick_now
	
	# Process permanently abandoned settlements for visual decay
	var settlements: Array = SettlementMemory.settlements
	for s in settlements:
		if not (s is Dictionary):
			continue
		var d: Dictionary = s as Dictionary
		var state: String = str(d.get("state", ""))
		if state != "permanently_abandoned":
			continue
		
		var reg: Variant = d.get("regions", null)
		if not (reg is PackedInt32Array):
			continue
		var regions: PackedInt32Array = reg as PackedInt32Array
		if regions.is_empty():
			continue
		
		_apply_permanent_abandonment_visuals(world, regions)


## Apply visual decay to permanently abandoned settlement regions
## Converts some built features to graves/scorched earth tiles for visual storytelling
func _apply_permanent_abandonment_visuals(world: World, regions: PackedInt32Array) -> void:
	var rng_seed: int = GameManager.tick_count
	
	for rk in regions:
		var center_tile: Vector2i = _center_tile_of_region_key(rk)
		
		# Convert some BED features to graves (visual only)
		# Scan a 5x5 area around the region center
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var tx: int = center_tile.x + dx
				var ty: int = center_tile.y + dy
				if tx < 0 or tx >= WorldData.WIDTH or ty < 0 or ty >= WorldData.HEIGHT:
					continue
				
				var feature: int = world.data.get_feature(tx, ty)
				
				# Convert BED to RUIN (grave marker) with low probability
				# This is deterministic based on position and tick
				var feature_hash: int = (tx * 73856093) ^ (ty * 19349663) ^ rng_seed
				var grave_chance: float = float(feature_hash & 0xFFFF) / 65536.0
				
				if feature == TileFeature.Type.BED and grave_chance < 0.15:
					# Convert to RUIN (visual grave marker)
					world.set_feature(tx, ty, TileFeature.Type.RUIN)
				
				# Convert WALL to RUIN (scorched/collapsed wall) with lower probability
				if feature == TileFeature.Type.WALL and grave_chance < 0.08:
					world.set_feature(tx, ty, TileFeature.Type.RUIN)


static func _center_tile_of_region_key(rk: int) -> Vector2i:
	var rx: int = int(rk) & 0xFFFF
	var ry: int = (int(rk) >> 16) & 0xFFFF
	return Vector2i(rx * 16 + 8, ry * 16 + 8)
