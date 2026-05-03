extends Node
## Phase 2.3: deterministic consequences from WorldMeaning only.
## Does not write to WorldMemory or WorldMeaning. No RNG, no UI.

## Quiet period (ticks) with no new deaths in region before one step of *visual* recovery.
const RECOVERY_TICKS: int = 20000
const ORPHAN_RETIRE_TICKS: int = RECOVERY_TICKS * 3

## region_key (int) -> persistence record
var persistent_regions: Dictionary = {}

## Named landmarks: landmark_id -> landmark data
var named_landmarks: Dictionary = {}

## Family memory: family_id -> family history
var family_memory: Dictionary = {}

## Road traces: path_id -> path data
var road_traces: Dictionary = {}

## Ruins: tile_position -> ruin data
var ruins: Dictionary = {}

## Placed items: tile_key -> PlaceableItem dict
var placed_items: Dictionary = {}


func clear() -> void:
	persistent_regions.clear()
	named_landmarks.clear()
	family_memory.clear()
	road_traces.clear()
	ruins.clear()


func to_save_dict() -> Dictionary:
	return {
		"persistent_regions": persistent_regions.duplicate(true),
		"named_landmarks": named_landmarks.duplicate(true),
		"family_memory": family_memory.duplicate(true),
		"road_traces": road_traces.duplicate(true),
		"ruins": ruins.duplicate(true),
		"placed_items": placed_items.duplicate(true),
	}


func from_save_dict(d: Dictionary) -> void:
	persistent_regions.clear()
	named_landmarks.clear()
	family_memory.clear()
	road_traces.clear()
	ruins.clear()
	
	if d.is_empty():
		return
	
	var raw: Variant = d.get("persistent_regions", {})
	if raw is Dictionary:
		for k in (raw as Dictionary).keys():
			var region_key: int
			if typeof(k) == TYPE_INT:
				region_key = k as int
			else:
				region_key = int(str(k))
			var rec: Variant = (raw as Dictionary)[k]
			if rec is Dictionary:
				persistent_regions[region_key] = (rec as Dictionary).duplicate(true)
	
	var raw_landmarks: Variant = d.get("named_landmarks", {})
	if raw_landmarks is Dictionary:
		named_landmarks = raw_landmarks.duplicate(true)
	
	var raw_family: Variant = d.get("family_memory", {})
	if raw_family is Dictionary:
		family_memory = raw_family.duplicate(true)
	
	var raw_roads: Variant = d.get("road_traces", {})
	if raw_roads is Dictionary:
		road_traces = raw_roads.duplicate(true)
	
		var raw_ruins: Variant = d.get("ruins", {})
		if raw_ruins is Dictionary:
			ruins = raw_ruins.duplicate(true)
		
		# Load placed items
		var raw_placed: Variant = d.get("placed_items", {})
		if raw_placed is Dictionary:
			for tile_key in raw_placed.keys():
				var item_dict: Dictionary = raw_placed[tile_key]
				var item: PlaceableItem = PlaceableItem.from_dict(item_dict)
				placed_items[tile_key] = item


func _default_entry() -> Dictionary:
	return {
		"scarred": false,
		"scar_level": 0,
		"last_applied_tick": -1,
		"last_death_tick": -1,
		"recovery_stage": 0,
		"next_recovery_at_tick": 0,
	}


func get_region_persistence(region_key: int) -> Dictionary:
	if persistent_regions.has(region_key):
		return (persistent_regions[region_key] as Dictionary).duplicate(true)
	return _default_entry()


## Fast hot-path read used by pawn job filters/priority logic.
## Avoids dictionary duplication in [method get_region_persistence].
func get_region_scar_level(region_key: int) -> int:
	if persistent_regions.has(region_key):
		var v: Variant = persistent_regions[region_key]
		if v is Dictionary:
			return int((v as Dictionary).get("scar_level", 0))
	return 0


func recompute() -> void:
	var old: Dictionary = persistent_regions.duplicate(true)
	persistent_regions.clear()
	var now: int = GameManager.tick_count
	# -- Phase 1: scar_level / meaning merge + recovery state (scar_level never decreases)
	for rk in WorldMeaning.meaning_by_region.keys():
		var region_key: int = int(rk)
		var m: Dictionary = WorldMeaning.get_region_meaning(region_key)
		var density: String = str(m.get("death_density", "none"))
		var target: int = _scar_level_from_density(density)
		var prev_level: int = 0
		if old.has(region_key):
			prev_level = int((old[region_key] as Dictionary).get("scar_level", 0))
		var final_level: int = maxi(target, prev_level)
		var last_d: int = int(m.get("last_death_tick", -1))
		var old_p: Dictionary = (old[region_key] as Dictionary) if old.has(region_key) else {}
		var old_last_d: int = int(old_p.get("last_death_tick", -999999))
		var rs: int
		var nxt: int
		if not old.has(region_key):
			rs = final_level
			nxt = _initial_next_recovery_at(last_d)
		else:
			if last_d > old_last_d:
				rs = final_level
				nxt = _initial_next_recovery_at(last_d)
			else:
				rs = int(old_p.get("recovery_stage", final_level))
				rs = mini(rs, final_level)
				nxt = int(old_p.get("next_recovery_at_tick", _initial_next_recovery_at(last_d)))
		persistent_regions[region_key] = {
			"scarred": final_level >= 3,
			"scar_level": final_level,
			"last_applied_tick": last_d,
			"last_death_tick": last_d,
			"recovery_stage": rs,
			"next_recovery_at_tick": nxt,
		}
	# Orphans: fall out of WorldMeaning; keep full prior record; merge in missing keys
	for rk in old.keys():
		if not persistent_regions.has(rk):
			var o: Dictionary = (old[rk] as Dictionary).duplicate(true)
			if not o.has("last_death_tick"):
				o["last_death_tick"] = int(o.get("last_applied_tick", -1))
			if not o.has("recovery_stage"):
				o["recovery_stage"] = int(o.get("scar_level", 0))
			if not o.has("next_recovery_at_tick"):
				o["next_recovery_at_tick"] = _initial_next_recovery_at(int(o.get("last_death_tick", -1)))
			var orphan_since_tick: int = int(o.get("orphan_since_tick", now))
			o["orphan_since_tick"] = orphan_since_tick
			var region_key: int = int(rk)
			var no_death_facts: bool = (
				int(o.get("last_death_tick", -1)) < 0
				and WorldMemory.get_last_pawn_death_tick_for_region(region_key) < 0
			)
			var orphan_retire_due: bool = (now - orphan_since_tick) >= ORPHAN_RETIRE_TICKS
			if no_death_facts and orphan_retire_due:
				if OS.is_debug_build() and GameManager.verbose_logs():
					print(
							"[WorldPersistence] Retired orphan region %d (no deaths, idle for %d ticks)"
							% [region_key, now - orphan_since_tick]
					)
				continue
			persistent_regions[rk] = o
	# -- Phase 2: one step of visual recovery (recovery_stage only; never scar_level; ticks only)
	for rk2 in persistent_regions.keys():
		var pr: Dictionary = persistent_regions[rk2]
		var slev: int = int(pr.get("scar_level", 0))
		if slev < 1:
			continue
		var rstage: int = int(pr.get("recovery_stage", 0))
		if rstage <= 0:
			continue
		var nxt2: int = int(pr.get("next_recovery_at_tick", 0))
		var ldeath: int = int(pr.get("last_death_tick", -1))
		if nxt2 <= 0 and ldeath >= 0:
			nxt2 = ldeath + RECOVERY_TICKS
			pr["next_recovery_at_tick"] = nxt2
		elif nxt2 <= 0 and ldeath < 0:
			# Inconsistent (scar with no last_death); do not free-run recoveries.
			pr["next_recovery_at_tick"] = now + RECOVERY_TICKS
			continue
		if now < nxt2:
			continue
		pr["recovery_stage"] = maxi(0, rstage - 1)
		pr["next_recovery_at_tick"] = now + RECOVERY_TICKS


func _initial_next_recovery_at(last_death: int) -> int:
	if last_death < 0:
		return 0
	return last_death + RECOVERY_TICKS


func _scar_level_from_density(density: String) -> int:
	match density:
		"none":
			return 0
		"low":
			return 1
		"medium":
			return 2
		"high":
			return 3
	return 0


# === Named Landmarks ===

func register_named_landmark(
		tile: Vector2i,
		name: String,
		landmark_type: String,
		created_tick: int = -1,
		description: String = ""
	) -> void:
	if created_tick < 0:
		created_tick = GameManager.tick_count
	
	var landmark_id: String = "%d,%d" % [tile.x, tile.y]
	named_landmarks[landmark_id] = {
		"tile": tile,
		"name": name,
		"type": landmark_type,
		"created_tick": created_tick,
		"description": description,
		"region": WorldMemory._region_key(tile.x, tile.y),
	}


func get_landmark_at_tile(tile: Vector2i) -> Dictionary:
	var landmark_id: String = "%d,%d" % [tile.x, tile.y]
	if named_landmarks.has(landmark_id):
		return (named_landmarks[landmark_id] as Dictionary).duplicate(true)
	return {}


func get_landmarks_in_region(region_key: int) -> Array:
	var results: Array = []
	for landmark_id in named_landmarks.keys():
		var landmark: Dictionary = named_landmarks[landmark_id]
		if int(landmark.get("region", -1)) == region_key:
			results.append(landmark.duplicate(true))
	return results


# === Family Memory ===

func record_family_event(
		family_id: int,
		event_type: String,
		tick: int = -1,
		description: String = "",
		related_pawns: Array = []
	) -> void:
	if tick < 0:
		tick = GameManager.tick_count
	
	if not family_memory.has(family_id):
		family_memory[family_id] = {
			"family_id": family_id,
			"events": [],
			"founding_tick": tick,
			"last_event_tick": tick,
		}
	
	var family_data: Dictionary = family_memory[family_id]
	var event_record: Dictionary = {
		"type": event_type,
		"tick": tick,
		"description": description,
		"related_pawns": related_pawns,
	}
	
	family_data["events"].append(event_record)
	family_data["last_event_tick"] = tick


func get_family_history(family_id: int) -> Dictionary:
	if family_memory.has(family_id):
		return (family_memory[family_id] as Dictionary).duplicate(true)
	return {}


# === Road Traces ===

func record_road_trace(
		path_id: String,
		path_tiles: Array[Vector2i],
		created_tick: int = -1,
		road_type: String = "dirt",
		settlement_id: int = -1
	) -> void:
	if created_tick < 0:
		created_tick = GameManager.tick_count
	
	road_traces[path_id] = {
		"path_id": path_id,
		"tiles": path_tiles,
		"created_tick": created_tick,
		"road_type": road_type,
		"settlement_id": settlement_id,
		"length": path_tiles.size(),
	}


func get_road_trace(path_id: String) -> Dictionary:
	if road_traces.has(path_id):
		return (road_traces[path_id] as Dictionary).duplicate(true)
	return {}


func get_roads_in_region(region_key: int) -> Array:
	var results: Array = []
	for path_id in road_traces.keys():
		var road: Dictionary = road_traces[path_id]
		var tiles: Array = road.get("tiles", [])
		for tile in tiles:
			if tile is Vector2i:
				var tile_region: int = WorldMemory._region_key(tile.x, tile.y)
				if tile_region == region_key:
					results.append(road.duplicate(true))
					break
	return results


# === Ruins ===

func record_ruin(
		tile: Vector2i,
		original_building_type: String,
		destroyed_tick: int = -1,
		cause: String = "unknown",
		settlement_id: int = -1
	) -> void:
	if destroyed_tick < 0:
		destroyed_tick = GameManager.tick_count
	
	var ruin_key: String = "%d,%d" % [tile.x, tile.y]
	ruins[ruin_key] = {
		"tile": tile,
		"original_building_type": original_building_type,
		"destroyed_tick": destroyed_tick,
		"cause": cause,
		"settlement_id": settlement_id,
		"region": WorldMemory._region_key(tile.x, tile.y),
		"age_ticks": 0,
	}


func update_ruin_age(current_tick: int) -> void:
	for ruin_key in ruins.keys():
		var ruin: Dictionary = ruins[ruin_key]
		var destroyed_tick: int = int(ruin.get("destroyed_tick", 0))
		if destroyed_tick > 0:
			ruin["age_ticks"] = current_tick - destroyed_tick


func get_ruin_at_tile(tile: Vector2i) -> Dictionary:
	var ruin_key: String = "%d,%d" % [tile.x, tile.y]
	if ruins.has(ruin_key):
		return (ruins[ruin_key] as Dictionary).duplicate(true)
	return {}


func get_ruins_in_region(region_key: int) -> Array:
	var results: Array = []
	for ruin_key in ruins.keys():
		var ruin: Dictionary = ruins[ruin_key]
		if int(ruin.get("region", -1)) == region_key:
			results.append(ruin.duplicate(true))
	return results
