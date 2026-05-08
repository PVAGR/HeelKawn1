extends Node

## Global registry of player-designated zones (forage, build, defend, territory).
## Pawns query this during job scoring to prefer jobs inside designated areas.
## Storage zones are handled by StockpileManager — this is only for the
## priority-bias zones that the player paints via Ctrl+Z, plus auto-generated
## territory zones from SettlementMemory.

enum ZoneType { FORAGE, BUILD, DEFEND, TERRITORY }

signal zone_registered(zone_type: int, rect: Rect2i)
signal zone_unregistered(zone_type: int, rect: Rect2i)

var _zones: Dictionary = {}  # zone_type (int) -> Array[Rect2i]

## Spatial index for TERRITORY zones: set of region keys for O(1) lookup.
## Region key = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16) where rx = tx >> 4.
var _territory_region_keys: Dictionary = {}


func register(zone_type: int, rect: Rect2i) -> void:
	if not _zones.has(zone_type):
		_zones[zone_type] = []
	_zones[zone_type].append(rect)
	zone_registered.emit(zone_type, rect)
	# Update territory spatial index
	if zone_type == ZoneType.TERRITORY:
		_add_rect_to_territory_index(rect)


func unregister(zone_type: int, rect: Rect2i) -> void:
	if _zones.has(zone_type):
		_zones[zone_type].erase(rect)
		zone_unregistered.emit(zone_type, rect)
	# Rebuild territory index on unregister (simpler than incremental removal)
	if zone_type == ZoneType.TERRITORY:
		_rebuild_territory_index()


func tile_in_zone_type(tile: Vector2i, zone_type: int) -> bool:
	if not _zones.has(zone_type):
		return false
	# Fast path for TERRITORY: O(1) region key lookup
	if zone_type == ZoneType.TERRITORY:
		var rk: int = (tile.x >> 4 & 0xFFFF) | (((tile.y >> 4) & 0xFFFF) << 16)
		return _territory_region_keys.has(rk)
	# General path: linear scan (fine for small player-painted zones)
	for r: Rect2i in _zones[zone_type]:
		if r.has_point(tile):
			return true
	return false


func zones_of_type(zone_type: int) -> Array:
	return _zones.get(zone_type, [])


func clear_all() -> void:
	_zones.clear()
	_territory_region_keys.clear()


func total_zone_count() -> int:
	var count: int = 0
	for key in _zones:
		count += _zones[key].size()
	return count


## Add a rect's region keys to the territory spatial index.
func _add_rect_to_territory_index(rect: Rect2i) -> void:
	# Each 16×16 region covers tiles from (rx*16, ry*16) to (rx*16+15, ry*16+15)
	# Find all region keys that overlap with this rect
	var start_rx: int = rect.position.x >> 4
	var start_ry: int = rect.position.y >> 4
	var end_rx: int = (rect.position.x + rect.size.x - 1) >> 4
	var end_ry: int = (rect.position.y + rect.size.y - 1) >> 4
	for ry in range(start_ry, end_ry + 1):
		for rx in range(start_rx, end_rx + 1):
			var rk: int = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
			_territory_region_keys[rk] = true


## Rebuild the territory spatial index from scratch.
func _rebuild_territory_index() -> void:
	_territory_region_keys.clear()
	if not _zones.has(ZoneType.TERRITORY):
		return
	for r: Rect2i in _zones[ZoneType.TERRITORY]:
		_add_rect_to_territory_index(r)
