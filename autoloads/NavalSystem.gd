extends Node
## NavalSystem — Boats, sailing, rivers, and ocean travel.
## Pawns can build rafts/boats at riverbanks or coasts.
## Boats enable river travel (faster than walking), fishing at sea,
## and crossing water tiles that are normally impassable.
## All movement is deterministic and tick-based.

enum BoatType {
	RAFT,       # simple log raft, 1 passenger, slow
	ROWBOAT,    # small rowboat, 2 passengers, medium
	SAILING_BOAT, # sailing boat, 4 passengers, fast (requires wind)
}

const BOAT_NAMES: Dictionary = {
	BoatType.RAFT: "Raft",
	BoatType.ROWBOAT: "Rowboat",
	BoatType.SAILING_BOAT: "Sailing Boat",
}

const BOAT_BUILD_COST: Dictionary = {
	BoatType.RAFT: {"wood": 5},
	BoatType.ROWBOAT: {"wood": 10, "rope": 2},
	BoatType.SAILING_BOAT: {"wood": 20, "rope": 5, "cloth": 10},
}

const BOAT_SPEED: Dictionary = {
	BoatType.RAFT: 0.5,
	BoatType.ROWBOAT: 0.8,
	BoatType.SAILING_BOAT: 1.5,
}

var boats: Dictionary = {}
var _next_boat_id: int = 1

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func build_boat(boat_type: int, at_tile: Vector2i, owner_id: int) -> int:
	var cost: Dictionary = BOAT_BUILD_COST.get(boat_type, {})
	var boat_id: int = _next_boat_id
	_next_boat_id += 1
	boats[boat_id] = {
		"id": boat_id,
		"type": boat_type,
		"name": BOAT_NAMES.get(boat_type, "Boat"),
		"tile": at_tile,
		"owner_id": owner_id,
		"passengers": [],
		"max_passengers": _max_passengers(boat_type),
		"speed": BOAT_SPEED.get(boat_type, 0.5),
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.BUILD_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"boat_built": true,
		"boat_type": boat_type,
		"x": at_tile.x, "y": at_tile.y,
		"owner_id": owner_id,
	})
	return boat_id

func _max_passengers(boat_type: int) -> int:
	match boat_type:
		BoatType.RAFT: return 1
		BoatType.ROWBOAT: return 2
		BoatType.SAILING_BOAT: return 4
	return 1

func board_boat(boat_id: int, pawn_id: int) -> bool:
	if not boats.has(boat_id):
		return false
	var b: Dictionary = boats[boat_id]
	if b.get("passengers").size() >= int(b.get("max_passengers", 1)):
		return false
	if b.get("passengers").has(pawn_id):
		return false
	b["passengers"].append(pawn_id)
	return true

func disembark(boat_id: int, pawn_id: int) -> bool:
	if not boats.has(boat_id):
		return false
	var b: Dictionary = boats[boat_id]
	return b["passengers"].erase(pawn_id)

func is_water_travel_possible(from_tile: Vector2i, to_tile: Vector2i) -> bool:
	return _is_navigable_water(from_tile) and _is_navigable_water(to_tile)

func _is_navigable_water(tile: Vector2i) -> bool:
	if WorldData == null:
		return false
	var biome: int = WorldData.get_biome(tile.x, tile.y)
	var feature: int = WorldData.get_feature(tile.x, tile.y)
	return biome == Biome.Type.WATER or feature == TileFeature.Type.RIVER or feature == TileFeature.Type.OCEAN

func get_boat_at(tile: Vector2i) -> Dictionary:
	for bid in boats:
		var b: Dictionary = boats[bid]
		if b.get("tile") == tile:
			return b
	return {}

func _on_game_tick(tick: int) -> void:
	if tick % 100 != 0:
		return
	_process_boat_movement(tick)

func _process_boat_movement(tick: int) -> void:
	for bid in boats:
		var b: Dictionary = boats[bid]
		if b.get("passengers").is_empty():
			continue
		_apply_current(b, tick)

func _apply_current(b: Dictionary, tick: int) -> void:
	_ = tick
	var tile: Vector2i = b.get("tile", Vector2i())
	if WindSystem != null:
		var wind_dir: Vector2 = WindSystem.get_wind_direction()
		var drift: float = WindSystem.get_wind_strength() * 0.1
		if drift > 0.01:
			tile.x += int(wind_dir.x * drift)
			tile.y += int(wind_dir.y * drift)
			tile.x = clampi(tile.x, 0, WorldData.WIDTH - 1)
			tile.y = clampi(tile.y, 0, WorldData.HEIGHT - 1)
			if _is_navigable_water(tile):
				b["tile"] = tile

func count_boats() -> int:
	return boats.size()

func clear() -> void:
	boats.clear()
