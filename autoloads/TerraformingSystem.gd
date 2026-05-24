extends Node
## TerraformingSystem — Dig channels, build dams, irrigate land.
## Pawns can excavate canals to redirect water, build dams to block flow,
## and irrigate dry land for farming. All deterministic.
## Terraforming actions cost time and resources. Results persist in WorldData.

enum TerraformAction {
	DIG_CHANNEL,   # excavate a canal (water can flow through)
	BUILD_DAM,     # block water flow
	IRRIGATE,      # convert dry land to fertile soil
	FILL_LAND,     # convert shallow water to land
	TERRACE,       # flatten terrain for building
}

const ACTION_COST: Dictionary = {
	TerraformAction.DIG_CHANNEL: {"work_ticks": 80, "tool": "pickaxe"},
	TerraformAction.BUILD_DAM: {"work_ticks": 120, "stone": 10, "wood": 5},
	TerraformAction.IRRIGATE: {"work_ticks": 40, "water": 5},
	TerraformAction.FILL_LAND: {"work_ticks": 100, "stone": 15},
	TerraformAction.TERRACE: {"work_ticks": 60},
}

var terraformed_tiles: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func perform_terraforming(action: int, tile: Vector2i, pawn_id: int) -> bool:
	var key: String = "%d,%d" % [tile.x, tile.y]
	terraformed_tiles[key] = {
		"action": action,
		"tile": tile,
		"pawn_id": pawn_id,
		"tick": GameManager.tick_count if GameManager != null else 0,
	}
	_apply_terraforming(action, tile)
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.BUILD_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"terraforming": true,
		"action": action,
		"x": tile.x, "y": tile.y,
		"pawn_id": pawn_id,
	})
	return true

func _apply_terraforming(action: int, tile: Vector2i) -> void:
	var _wd = WorldData.current
	if _wd == null:
		return
	match action:
		TerraformAction.DIG_CHANNEL:
			_wd.set_feature(tile.x, tile.y, TileFeature.Type.RIVER)
			_wd.set_biome(tile.x, tile.y, Biome.Type.WATER)
		TerraformAction.BUILD_DAM:
			_wd.set_feature(tile.x, tile.y, TileFeature.Type.DAM)
		TerraformAction.IRRIGATE:
			_wd.set_biome(tile.x, tile.y, Biome.Type.FERTILE_SOIL)
		TerraformAction.FILL_LAND:
			_wd.set_biome(tile.x, tile.y, Biome.Type.GRASS)
			_wd.set_feature(tile.x, tile.y, TileFeature.Type.NONE)
		TerraformAction.TERRACE:
			_wd.set_feature(tile.x, tile.y, TileFeature.Type.TERRACE)

func get_terraformed_tile(tile: Vector2i) -> Dictionary:
	var key: String = "%d,%d" % [tile.x, tile.y]
	return terraformed_tiles.get(key, {})

func is_terraformed(tile: Vector2i) -> bool:
	return not get_terraformed_tile(tile).is_empty()

func _on_game_tick(_tick: int) -> void:
	pass


## Apply sea level changes based on climate system. When sea_level > 1.0,
## coastal lowland biomes may become water tiles. When sea_level < 1.0,
## shallow water tiles may become land. This is deterministic and only
## affects tiles at the margin of current water coverage.
func apply_sea_level_change(new_sea_level: float, old_sea_level: float) -> void:
	if abs(new_sea_level - old_sea_level) < 0.05:
		return  # No significant change
	var _wd = WorldData.current
	if _wd == null:
		return
	# Sea level change direction: rise or fall
	var is_rising: bool = new_sea_level > old_sea_level
	if is_rising:
		# Check coastal lowland biomes for flooding
		_flood_coastal_tiles(_wd, new_sea_level)
	else:
		# Check shallow water tiles for revealing land
		_reveal_land_tiles(_wd, new_sea_level)


func _flood_coastal_tiles(_wd: WorldData, sea_level: float) -> void:
	# Only flood tiles when sea level is significantly higher
	if sea_level < 1.15:
		return
	var threshold: float = (sea_level - 1.0) * 100.0  # Scale: 1.1 -> 10, 1.2 -> 20
	var flooded: int = 0
	var max_floods: int = mini(50, int(threshold))  # Limit per call
	for x in range(WorldData.WIDTH):
		for y in range(WorldData.HEIGHT):
			if flooded >= max_floods:
				return
			var biome: int = _wd.get_biome(x, y)
			# Only flood GRASS or PLAINS adjacent to existing water
			if biome == Biome.Type.GRASS or biome == Biome.Type.PLAINS:
				if _is_adjacent_to_water(_wd, x, y):
					# Deterministic check based on position and current tick
					var tile_hash: int = (x * 73856093) ^ (y * 19349663)
					var tick_now: int = GameManager.tick_count if GameManager != null else 0
					var check_hash: int = (tile_hash ^ tick_now) & 0xFFFF
					var threshold_val: int = maxi(100, 600 - int(threshold * 20))
					if check_hash < threshold_val:
						_wd.set_biome(x, y, Biome.Type.WATER)
						flooded += 1


func _reveal_land_tiles(_wd: WorldData, sea_level: float) -> void:
	# Only reveal land when sea level is significantly lower
	if sea_level > 0.85:
		return
	var threshold: float = (1.0 - sea_level) * 100.0  # Scale: 0.9 -> 10, 0.8 -> 20
	var revealed: int = 0
	var max_reveals: int = mini(50, int(threshold))  # Limit per call
	for x in range(WorldData.WIDTH):
		for y in range(WorldData.HEIGHT):
			if revealed >= max_reveals:
				return
			var biome: int = _wd.get_biome(x, y)
			var feat: int = _wd.get_feature(x, y)
			# Only reveal shallow water tiles adjacent to land
			if biome == Biome.Type.WATER and feat == TileFeature.Type.NONE:
				if _is_adjacent_to_land(_wd, x, y):
					# Deterministic check based on position and current tick
					var tile_hash: int = (x * 73856093) ^ (y * 19349663)
					var tick_now: int = GameManager.tick_count if GameManager != null else 0
					var check_hash: int = (tile_hash ^ tick_now) & 0xFFFF
					var threshold_val: int = maxi(100, 600 - int(threshold * 20))
					if check_hash < threshold_val:
						_wd.set_biome(x, y, Biome.Type.GRASS)
						revealed += 1


func _is_adjacent_to_water(_wd: WorldData, x: int, y: int) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or nx >= WorldData.WIDTH or ny < 0 or ny >= WorldData.HEIGHT:
				continue
			var biome: int = _wd.get_biome(nx, ny)
			if biome == Biome.Type.WATER or biome == Biome.Type.OCEAN:
				return true
	return false


func _is_adjacent_to_land(_wd: WorldData, x: int, y: int) -> bool:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or nx >= WorldData.WIDTH or ny < 0 or ny >= WorldData.HEIGHT:
				continue
			var biome: int = _wd.get_biome(nx, ny)
			if biome == Biome.Type.GRASS or biome == Biome.Type.PLAINS or biome == Biome.Type.FOREST or biome == Biome.Type.MOUNTAIN:
				return true
	return false


func clear() -> void:
	terraformed_tiles.clear()
