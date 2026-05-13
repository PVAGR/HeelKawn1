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
	if WorldData == null:
		return
	match action:
		TerraformAction.DIG_CHANNEL:
			WorldData.set_feature(tile.x, tile.y, TileFeature.Type.RIVER)
			WorldData.set_biome(tile.x, tile.y, Biome.Type.WATER)
		TerraformAction.BUILD_DAM:
			WorldData.set_feature(tile.x, tile.y, TileFeature.Type.DAM)
		TerraformAction.IRRIGATE:
			WorldData.set_biome(tile.x, tile.y, Biome.Type.FERTILE_SOIL)
		TerraformAction.FILL_LAND:
			WorldData.set_biome(tile.x, tile.y, Biome.Type.GRASS)
			WorldData.set_feature(tile.x, tile.y, TileFeature.Type.NONE)
		TerraformAction.TERRACE:
			WorldData.set_feature(tile.x, tile.y, TileFeature.Type.TERRACE)

func get_terraformed_tile(tile: Vector2i) -> Dictionary:
	var key: String = "%d,%d" % [tile.x, tile.y]
	return terraformed_tiles.get(key, {})

func is_terraformed(tile: Vector2i) -> bool:
	return not get_terraformed_tile(tile).is_empty()

func _on_game_tick(_tick: int) -> void:
	pass

func clear() -> void:
	terraformed_tiles.clear()
