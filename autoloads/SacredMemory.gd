extends Node
class_name SacredMemory
## v1: Sacred sites (permanent ruin centers, future battlefields) — small dict; saved with colony.
## Keys are string "x_y" for stable [store_var] round-trip. No per-tick loops.

## tile_key string -> { "type": String, "myth": float }
var _sites: Dictionary = {}


func clear() -> void:
	_sites.clear()


func _tile_key(t: Vector2i) -> String:
	return "%d_%d" % [t.x, t.y]


## Mark a tile as sacred. Overwrites the same key deterministically.
func mark_sacred(tile_pos: Vector2i, site_type: String, myth_score: float) -> void:
	var k: String = _tile_key(tile_pos)
	_sites[k] = {"type": site_type, "myth": clampf(myth_score, 0.0, 1.0)}


func site_count() -> int:
	return _sites.size()


## Read-only sample for [ReligionLens] / F10 (sorted tile keys, cap [param max_n]).
func list_sites_sorted(max_n: int = 64) -> Array:
	var keys: Array = _sites.keys()
	keys.sort()
	var out: Array = []
	var lim: int = mini(maxi(0, max_n), keys.size())
	for i in range(lim):
		var k: String = str(keys[i])
		var d: Variant = _sites[keys[i]]
		var row: Dictionary = {"tile_key": k, "type": "", "myth": 0.0}
		if d is Dictionary:
			row["type"] = str((d as Dictionary).get("type", ""))
			row["myth"] = float((d as Dictionary).get("myth", 0.0))
		out.append(row)
	return out


func is_sacred_at(x: int, y: int) -> bool:
	return _sites.has("%d_%d" % [x, y])


func is_tile_sacred(tile_pos: Vector2i) -> bool:
	return _sites.has(_tile_key(tile_pos))


func get_sacred_type_at(x: int, y: int) -> String:
	var d: Variant = _sites.get("%d_%d" % [x, y], null)
	if d is Dictionary:
		return str((d as Dictionary).get("type", ""))
	return ""


func get_sacred_myth_at(x: int, y: int) -> float:
	var d: Variant = _sites.get("%d_%d" % [x, y], null)
	if d is Dictionary:
		return float((d as Dictionary).get("myth", 0.0))
	return 0.0


func clear_at_tile(tile_pos: Vector2i) -> void:
	_sites.erase(_tile_key(tile_pos))


## True if any 16x16 [param pack0] region contains a stored sacred site.
func pack_touches_sacred(pack0: PackedInt32Array) -> bool:
	for u in range(pack0.size()):
		var rki: int = int(pack0[u])
		var rx0: int = rki & 0xFFFF
		var ry0: int = (rki >> 16) & 0xFFFF
		for dy in 16:
			for dx in 16:
				var x: int = rx0 * 16 + dx
				var y: int = ry0 * 16 + dy
				if is_sacred_at(x, y):
					return true
	return false


## One settlement center: idempotent; safe when [MythMemory] is mid-rebuild.
func mark_permanent_collapse_from_center_rk(center_rk: int) -> void:
	if center_rk < 0:
		return
	var rx0: int = int(center_rk) & 0xFFFF
	var ry0: int = (int(center_rk) >> 16) & 0xFFFF
	var center_tile: Vector2i = Vector2i(rx0 * 16 + 8, ry0 * 16 + 8)
	var mst: int = MythMemory.get_region_myth_state(center_rk)
	var norm: float = 0.5
	if mst == 1:
		norm = 1.0
	elif mst == -1:
		norm = 0.0
	mark_sacred(center_tile, "permanent_ruin", 0.7 + 0.3 * norm)
	if OS.is_debug_build():
		print(
				"[Sacred] permanent_ruin  ckr=%d  tile=%s  myth_state=%d" % [center_rk, center_tile, mst]
		)


## After [SettlementMemory] + [MythMemory] recompute, ensure permanent collapse centers read as sacred.
func sync_permanent_ruins_from_settlements() -> void:
	for s_any in SettlementMemory.get_formal_settlements():
		if not (s_any is Dictionary):
			continue
		var sd: Dictionary = s_any
		if str(sd.get("state", "")) != "permanently_abandoned":
			continue
		var ckr: int = int(sd.get("center_region", -1))
		if ckr < 0:
			continue
		var rx: int = int(ckr) & 0xFFFF
		var ry: int = (int(ckr) >> 16) & 0xFFFF
		var center_tile: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)
		var mst: int = MythMemory.get_region_myth_state(ckr)
		var norm: float = 0.5
		if mst == 1:
			norm = 1.0
		elif mst == -1:
			norm = 0.0
		mark_sacred(center_tile, "permanent_ruin", 0.7 + 0.3 * norm)


func to_save_dict() -> Dictionary:
	return _sites.duplicate(true)


func from_save_dict(d: Variant) -> void:
	_sites.clear()
	if d is not Dictionary:
		return
	for k0 in (d as Dictionary).keys():
		_sites[str(k0)] = (d as Dictionary)[k0]
