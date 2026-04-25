extends Node
## Phase 3 v1: regional reputation derived read-only from WorldMemory + WorldMeaning
## (events) and WorldPersistence. Does not write to those systems. No UI, no RNG.

## Same scale as land-recovery "long quiet" — pawn deaths at or before (now - this)
## count as "far in the past" for the ruin+peace reputation bump.
const PAWN_DEATH_PEACE_TICKS: int = 20000

## region_key (int) -> int in [-3, +1], clamped: dreaded .. neutral .. respected (capped 0 in v1 rules).
var reputation_by_region: Dictionary = {}


func recompute(world: World) -> void:
	reputation_by_region.clear()
	var last_pawn_death: Dictionary = _build_last_pawn_death_tick_by_region()
	var ruin_region: Dictionary = _build_regions_with_ruins(world)
	var now: int = GameManager.tick_count
	for region_key in WorldPersistence.persistent_regions:
		var rk: int = int(region_key)
		var pr: Dictionary = WorldPersistence.persistent_regions[rk] as Dictionary
		if pr == null:
			continue
		var sl: int = int(pr.get("scar_level", 0))
		var rep: int = _reputation_base_from_scar_level(sl)
		if _ruin_and_long_peace_allows_bump(
				rk, last_pawn_death, ruin_region, now
		):
			rep = mini(0, rep + 1)
		if rep < -3:
			rep = -3
		if rep > 0:
			rep = 0
		reputation_by_region[rk] = rep


func get_region_reputation(region_key: int) -> int:
	return int(reputation_by_region.get(region_key, 0))


func _reputation_base_from_scar_level(scar_level: int) -> int:
	match scar_level:
		0:
			return 0
		1:
			return -1
		2:
			return -2
		3:
			return -3
		_:
			return 0


## Read WorldMemory only (same events as WorldMeaning) — last *pawn* death tick.
func _build_last_pawn_death_tick_by_region() -> Dictionary:
	var out: Dictionary = {}
	var ev: Variant = WorldMemory.to_save_dict().get("events", [])
	if not (ev is Array):
		return out
	for item in (ev as Array):
		if not (item is Dictionary):
			continue
		var e: Dictionary = item
		if not e.has("r") or not e.has("k"):
			continue
		## Matches WorldMeaning: KIND_PAWN_DEATH = 0
		if int(e["k"]) != 0:
			continue
		var rk: int = int(e["r"])
		var t: int = int(e.get("t", 0))
		if not out.has(rk) or t > int(out[rk]):
			out[rk] = t
	return out


func _build_regions_with_ruins(world: World) -> Dictionary:
	var s: Dictionary = {}
	if world == null or world.data == null:
		return s
	var feats: Array = world.data.features
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var i: int = y * WorldData.WIDTH + x
			if int(feats[i]) == TileFeature.Type.RUIN:
				var rk: int = WorldMemory._region_key(x, y)
				s[rk] = true
	return s


func _ruin_and_long_peace_allows_bump(
		rk: int,
		last_pawn_death: Dictionary,
		ruin_region: Dictionary,
		now: int
) -> bool:
	if not ruin_region.has(rk):
		return false
	if not last_pawn_death.has(rk):
		## Need a prior pawn death to treat as "old wounds + ruins"; otherwise skip.
		return false
	var lp: int = int(last_pawn_death[rk])
	if now - lp < PAWN_DEATH_PEACE_TICKS:
		return false
	return true
