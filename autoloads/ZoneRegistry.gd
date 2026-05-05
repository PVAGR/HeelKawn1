extends Node

## Global registry of player-designated zones (forage, build, defend).
## Pawns query this during job scoring to prefer jobs inside designated areas.
## Storage zones are handled by StockpileManager — this is only for the
## priority-bias zones that the player paints via Ctrl+Z.

enum ZoneType { FORAGE, BUILD, DEFEND }

signal zone_registered(zone_type: int, rect: Rect2i)
signal zone_unregistered(zone_type: int, rect: Rect2i)

var _zones: Dictionary = {}  # zone_type (int) -> Array[Rect2i]


func register(zone_type: int, rect: Rect2i) -> void:
	if not _zones.has(zone_type):
		_zones[zone_type] = []
	_zones[zone_type].append(rect)
	zone_registered.emit(zone_type, rect)


func unregister(zone_type: int, rect: Rect2i) -> void:
	if _zones.has(zone_type):
		_zones[zone_type].erase(rect)
		zone_unregistered.emit(zone_type, rect)


func tile_in_zone_type(tile: Vector2i, zone_type: int) -> bool:
	if not _zones.has(zone_type):
		return false
	for r: Rect2i in _zones[zone_type]:
		if r.has_point(tile):
			return true
	return false


func zones_of_type(zone_type: int) -> Array:
	return _zones.get(zone_type, [])


func clear_all() -> void:
	_zones.clear()


func total_zone_count() -> int:
	var count: int = 0
	for key in _zones:
		count += _zones[key].size()
	return count
