extends Node
## Phase 5: Observation API - Programmatic access to Focus Inspector data
## Provides the same data that human players see via mouse inspection, but for AI agents

## Get comprehensive pawn observation data (same as Focus Inspector pawn view)
static func observe_pawn(pawn_id: int) -> Dictionary:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return {"error": "Main scene not available"}
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return {"error": "PawnSpawner not available"}
	
	# Find pawn by ID
	var target_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			target_pawn = p
			break
	
	if target_pawn == null:
		return {"error": "Pawn not found", "pawn_id": pawn_id}
	
	return _build_pawn_observation(target_pawn)

## Get comprehensive tile observation data (same as Focus Inspector tile view)
static func observe_tile(tile_x: int, tile_y: int) -> Dictionary:
	var tile: Vector2i = Vector2i(tile_x, tile_y)
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return {"error": "Main scene not available"}
	
	var world: World = main.get("_world") as World
	if world == null or world.data == null:
		return {"error": "World not available"}
	
	if not world.data.in_bounds(tile_x, tile_y):
		return {"error": "Tile out of bounds", "tile": {"x": tile_x, "y": tile_y}}
	
	return _build_tile_observation(tile, world)

## Get comprehensive settlement observation data
static func observe_settlement(center_region: int) -> Dictionary:
	var settlement: Variant = SettlementMemory.get_settlement_at_region(center_region)
	if not (settlement is Dictionary):
		return {"error": "Settlement not found", "center_region": center_region}
	
	var st: Dictionary = settlement as Dictionary
	return _build_settlement_observation(st, center_region)

## Get observation data for whatever is under the given world coordinates
static func observe_at_world_position(world_pos: Vector2) -> Dictionary:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null or not main.has_method("_world"):
		return {"error": "Main scene not available"}
	
	var world: World = main.get("_world") as World
	if world == null:
		return {"error": "World not available"}
	
	# Check for pawn first
	var mouse_pawn: Pawn = main._focus_pawn_under_world_pos(world_pos) if main.has_method("_focus_pawn_under_world_pos") else null
	if mouse_pawn != null and mouse_pawn.data != null:
		var obs: Dictionary = _build_pawn_observation(mouse_pawn)
		obs["focus_type"] = "pawn"
		return obs
	
	# Check for tile
	var mouse_tile: Vector2i = world.world_to_tile(world_pos)
	if mouse_tile.x >= 0 and mouse_tile.y >= 0:
		var settlement: Variant = SettlementMemory.get_settlement_at_region(preload("res://autoloads/WorldMemory.gd")._region_key(mouse_tile.x, mouse_tile.y))
		if settlement is Dictionary:
			var obs: Dictionary = _build_settlement_observation(settlement as Dictionary, preload("res://autoloads/WorldMemory.gd")._region_key(mouse_tile.x, mouse_tile.y))
			obs["focus_type"] = "settlement"
			obs["tile"] = {"x": mouse_tile.x, "y": mouse_tile.y}
			return obs
		else:
			var obs: Dictionary = _build_tile_observation(mouse_tile, world)
			obs["focus_type"] = "tile"
			return obs
	
	return {"error": "No valid target at position", "world_pos": world_pos}

## Get all pawns in a specific region
static func observe_pawns_in_region(region_key: int) -> Array[Dictionary]:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return []
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return []
	
	var results: Array[Dictionary] = []
	for p in spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pawn_rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if pawn_rk == region_key:
			results.append(_build_pawn_observation(p))
	
	return results

## Get observation summary for current camera position
static func observe_camera_view() -> Dictionary:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return {"error": "Main scene not available"}
	
	var world: World = main.get("_world") as World
	var camera: Camera2D = main.get("_camera") as Camera2D
	
	if world == null or camera == null:
		return {"error": "World or camera not available"}
	
	var cam_tile: Vector2i = world.world_to_tile(camera.global_position)
	if cam_tile.x < 0:
		return {"error": "Camera out of world bounds"}
	
	var obs: Dictionary = observe_at_world_position(camera.global_position)
	obs["camera_world_pos"] = camera.global_position
	obs["camera_tile"] = {"x": cam_tile.x, "y": cam_tile.y}
	obs["camera_region_key"] = preload("res://autoloads/WorldMemory.gd")._region_key(cam_tile.x, cam_tile.y)
	
	return obs


## Get a settlement-region level observation summary.
static func observe_region(region_key: int) -> Dictionary:
	var settlement_v: Variant = SettlementMemory.get_settlement_at_region(region_key)
	if not (settlement_v is Dictionary):
		return {"error": "Settlement not found", "region_key": region_key}
	
	var settlement: Dictionary = settlement_v as Dictionary
	var obs: Dictionary = _build_settlement_observation(settlement, region_key)
	obs["type"] = "region_observation"
	obs["pawn_count"] = observe_pawns_in_region(region_key).size()
	return obs


## Canonical focus snapshot used by Main + external tools.
static func build_focus_snapshot_from_focus(focus: Dictionary, tick: int = -1) -> Dictionary:
	var focus_type: String = str(focus.get("type", "NONE")).to_upper()
	var source: String = str(focus.get("source", "none"))
	var title: String = "FOCUS INSPECTOR"
	var main_lines: PackedStringArray = PackedStringArray()

	match focus_type:
		"PAWN":
			title = "FOCUS: PAWN"
			main_lines = _focus_lines_for_pawn(focus)
		"SETTLEMENT":
			title = "FOCUS: SETTLEMENT"
			main_lines = _focus_lines_for_settlement(focus)
		"TILE":
			title = "FOCUS: TILE"
			main_lines = _focus_lines_for_tile(focus)
		_:
			main_lines = PackedStringArray([
				"NO FOCUS",
				"Move cursor over a pawn, settlement, or tile",
			])

	return {
		"title": title,
		"focus_type": focus_type,
		"main_lines": main_lines,
		"footer": "Tick %d | source: %s" % [tick, source],
	}

# === Private helper methods ===

static func _build_pawn_observation(pawn: Pawn) -> Dictionary:
	var d: PawnData = pawn.data
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(d.tile_pos.x, d.tile_pos.y)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(rk)
	var st_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	
	var settlement_label: String = "Unknown"
	if st_v is Dictionary:
		settlement_label = str((st_v as Dictionary).get("state", "unknown"))
	
	var health_pct: int = int(round(d.get_health_percentage() * 100.0)) if d.has_method("get_health_percentage") else 0
	var state_label: String = pawn.get_state_name() if pawn.has_method("get_state_name") else "Unknown"
	var job_label: String = pawn.get_current_job_label() if pawn.has_method("get_current_job_label") else "None"
	
	return {
		"type": "pawn_observation",
		"pawn_id": int(d.id),
		"display_name": d.display_name,
		"gender": d.gender,
		"age_years": float(d.age_years),
		"health_percentage": health_pct,
		"hunger": d.hunger,
		"rest": d.rest,
		"mood": d.mood,
		"profession": d.profession_name(),
		"military_rank": String(d.military_rank).capitalize(),
		"state": state_label,
		"current_job": job_label,
		"tile_pos": {"x": d.tile_pos.x, "y": d.tile_pos.y},
		"region_key": rk,
		"governance_role": _pawn_governance_role(d, gov),
		"governance_profile": gov,
		"war_profile": war,
		"settlement_state": settlement_label,
		"skills": d.skill_xp,
		"is_carrying": d.is_carrying(),
		"carrying_item": d.carrying if d.is_carrying() else null,
		"carrying_quantity": d.carrying_qty if d.is_carrying() else 0
	}


static func _focus_lines_for_pawn(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var p: Pawn = focus.get("pawn", null) as Pawn
	if p == null or p.data == null:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var obs: Dictionary = _build_pawn_observation(p)
	var d: PawnData = p.data
	var gov: Dictionary = obs.get("governance_profile", {})
	var war: Dictionary = obs.get("war_profile", {})
	var role: String = str(obs.get("governance_role", "Citizen"))
	var settlement_label: String = str(obs.get("settlement_state", "unknown"))
	var health_pct: int = int(obs.get("health_percentage", 0))
	var state_label: String = str(obs.get("state", "Unknown"))
	var job_label: String = str(obs.get("current_job", "None"))
	var local_mode: String = "Retreat" if health_pct < 50 else "Ordered"
	out.append("Name: %s" % d.display_name)
	out.append("Profession: %s | Military Rank: %s" % [str(obs.get("profession", "None")), str(obs.get("military_rank", "None"))])
	out.append("Governance Role: %s" % role)
	out.append("Health: %d%% | Hunger %.0f | Rest %.0f | Mood %.0f" % [health_pct, float(obs.get("hunger", 0.0)), float(obs.get("rest", 0.0)), float(obs.get("mood", 0.0))])
	out.append("Action: %s | Job: %s" % [state_label, job_label])
	out.append("Settlement state (committed/hysteresis): %s | War: %s" % [settlement_label, _pretty_war_state(str(war.get("state", "peace")))])
	out.append("Battlefield Posture: %s" % local_mode)
	if p.has_method("get_runtime_cohort_observability"):
		var cobs: Dictionary = p.call("get_runtime_cohort_observability")
		var c_job_type: int = int(cobs.get("cohort_job_type", -1))
		var a_job_type: int = int(cobs.get("active_job_type", -1))
		var s_job_type: int = int(cobs.get("stability_job_type", -1))
		var locus_tile: Vector2i = cobs.get("locus_tile", Vector2i(-1, -1))
		out.append("Cohort: anchor=%s active=%s stored=%s is_anchor=%s" % [
			str(cobs.get("anchor_id", -1)),
			Job.describe_type(a_job_type) if a_job_type >= 0 else "None",
			Job.describe_type(c_job_type) if c_job_type >= 0 else "None",
			"Yes" if bool(cobs.get("is_anchor", false)) else "No",
		])
		out.append("Cohort Locus: (%d,%d) | Stability: %d ticks [%s]" % [
			locus_tile.x,
			locus_tile.y,
			int(cobs.get("stability_ticks", 0)),
			Job.describe_type(s_job_type) if s_job_type >= 0 else "None",
		])
	var rk: int = int(obs.get("region_key", -1))
	_focus_append_house_stub_lines(out, rk)
	return out


static func _focus_lines_for_settlement(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	var st: Dictionary = focus.get("settlement", {})
	var center: int = int(st.get("center_region", -1))
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(center)
	out.append("Region: %d | Tile: (%d,%d)" % [center, tile.x, tile.y])
	out.append("Settlement state (committed/hysteresis-smoothed): %s" % _pretty_settlement_state(str(st.get("state", "unknown"))))
	out.append("Settlement truth raw (material audit, not smoothed): %s" % str(st.get("state_truth_raw", st.get("state", "unknown"))))
	out.append(("Material signals: liv=%d shelter=%s work=%d stockpile=%s (flag=designated stockpile-zone overlap only) " + "sp_zone_overlap_hits=%d | hysteresis_key=center_region:%d") % [
		int(st.get("material_signal_living", 0)),
		"Y" if int(st.get("material_signal_shelter", 0)) != 0 else "N",
		int(st.get("material_signal_work", 0)),
		"Y" if int(st.get("material_signal_stockpile", 0)) != 0 else "N",
		int(st.get("material_stockpile_overlap_hits", 0)),
		center,
	])
	out.append("Governance (political identity, not material liveness): %s | Ruler: %s" % [_pretty_governance_name(str(gov.get("type", "anarchy"))), _pawn_name_by_id(int(gov.get("ruler_id", -1)))])
	var pop: int = _count_pawns_in_regions(st.get("regions", PackedInt32Array()))
	var council_ids_v: Variant = gov.get("council_ids", PackedInt32Array())
	var council_size: int = council_ids_v.size() if council_ids_v is PackedInt32Array else 0
	out.append("Population: %d | Council Size: %d" % [pop, council_size])
	out.append("War: %s | Target: %s" % [_pretty_war_state(str(war.get("state", "peace"))), _observer_war_target_label(int(war.get("target_settlement_id", -1)))])
	out.append("Intent: %s" % str(st.get("current_intent", SettlementMemory.INTENT_GROW)))
	var wf_ph: String = str(st.get("specialization_phase", SettlementMemory.SPECIALIZATION_PHASE_UNKNOWN))
	var wf_lk: String = str(st.get("specialization_channel", ""))
	var wf_cd: String = str(st.get("specialization_candidate_channel", ""))
	var wf_cf: int = int(st.get("specialization_confidence", 0))
	var wf_line: String = "Work-focus (proxy): %s" % wf_ph
	match wf_ph:
		SettlementMemory.SPECIALIZATION_PHASE_LOCKED:
			wf_line += " — %s [%d%%]" % [SettlementMemory.specialization_work_focus_label(wf_lk), wf_cf]
		SettlementMemory.SPECIALIZATION_PHASE_CANDIDATE:
			wf_line += " — → %s [%d%%]" % [SettlementMemory.specialization_work_focus_label(wf_cd), wf_cf]
		_:
			wf_line += " — Unspecialized"
	out.append(wf_line)
	var fronts_v: Variant = st.get("preferred_fronts", [])
	if fronts_v is Array and not (fronts_v as Array).is_empty():
		var idx: int = 0
		for fv in fronts_v as Array:
			if not (fv is Dictionary):
				continue
			if idx >= 2:
				break
			var f: Dictionary = fv as Dictionary
			var ftile: Vector2i = f.get("tile", Vector2i(-1, -1))
			out.append("Front %d: %s @ (%d,%d) support=%d stability=%d" % [
				idx + 1,
				Job.describe_type(int(f.get("job_type", -1))) if int(f.get("job_type", -1)) >= 0 else "Unknown",
				ftile.x,
				ftile.y,
				int(f.get("support", 0)),
				int(f.get("stability_ticks", 0)),
			])
			idx += 1
	else:
		out.append("Fronts: none")
	out.append("Food Pressure: %d%% | Housing Pressure: %d%%" % [int(round(ColonySimServices.get_food_pressure() * 100.0)), int(round(ColonySimServices.get_housing_pressure() * 100.0))])
	_focus_append_house_stub_lines(out, center)
	return out


static func _focus_lines_for_tile(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	if tile.x < 0:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var obs: Dictionary = observe_tile(tile.x, tile.y)
	if obs.has("error"):
		return PackedStringArray(["NO FOCUS", str(obs.get("error", "Unknown"))])
	var rk: int = int(obs.get("region_key", -1))
	out.append("Tile: (%d,%d) | Region: %d" % [tile.x, tile.y, rk])
	out.append("Biome: %s | Scar: %d" % [str(obs.get("biome_name", "unknown")), int(obs.get("scar_level", 0))])
	var settlement_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	if settlement_v is Dictionary:
		var st: Dictionary = settlement_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
		out.append("Settlement committed: %s | truth raw: %s | Governance (political): %s" % [
			_pretty_settlement_state(str(st.get("state", "unknown"))),
			str(st.get("state_truth_raw", st.get("state", "unknown"))),
			_pretty_governance_name(str(gov.get("type", "anarchy"))),
		])
		_focus_append_house_stub_lines(out, center)
	var events: Array[Dictionary] = WorldMemory.get_events_for_tile(tile)
	if not events.is_empty():
		var evt: Dictionary = events[events.size() - 1]
		var etype: String = str(evt.get("type", "event"))
		out.append("Last Event: %s @ tick %d" % [etype.replace("_", " "), int(evt.get("t", 0))])
	return out

static func _build_tile_observation(tile: Vector2i, world: World) -> Dictionary:
	var rk: int = preload("res://autoloads/WorldMemory.gd")._region_key(tile.x, tile.y)
	var biome: int = world.data.get_biome(tile.x, tile.y)
	var feature: int = world.data.get_feature(tile.x, tile.y)
	
	var obs: Dictionary = {
		"type": "tile_observation",
		"tile": {"x": tile.x, "y": tile.y},
		"region_key": rk,
		"biome_id": biome,
		"biome_name": Biome.name_for(biome),
		"feature_id": feature,
		"feature_name": TileFeature.name_for(feature),
		"scar_level": int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0)),
		"recovery_stage": int(WorldPersistence.get_region_persistence(rk).get("recovery_stage", 0)),
		"forage": int(world.data.forage_at(tile.x, tile.y)),
		"walkable": world.pathfinder.is_passable(tile) if world.pathfinder != null else false
	}
	
	# Add settlement info if present
	var st_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	if st_v is Dictionary:
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
		obs["settlement"] = {
			"state": str(st.get("state", "unknown")),
			"state_truth_raw": str(st.get("state_truth_raw", st.get("state", "unknown"))),
			"governance_type": str(gov.get("type", "anarchy")),
			"center_region": center,
			"culture_type": int(st.get("culture_type", 0)),
			"culture_name": str(st.get("culture_name", "unknown")),
			"scar_max": int(st.get("scar_max", 0)),
			"reputation_min": int(st.get("reputation_min", 0))
		}
	
	# Add recent events
	var events: Array[Dictionary] = WorldMemory.get_events_for_tile(tile)
	if not events.is_empty():
		obs["recent_events"] = events.slice(-5) # Last 5 events
	
	return obs

static func _build_settlement_observation(settlement: Dictionary, center_region: int) -> Dictionary:
	var regions: Variant = settlement.get("regions", PackedInt32Array())
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center_region)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(center_region)
	
	var obs: Dictionary = {
		"type": "settlement_observation",
		"center_region": center_region,
		"state": str(settlement.get("state", "unknown")),
		"state_truth_raw": str(settlement.get("state_truth_raw", settlement.get("state", "unknown"))),
		"culture_type": int(settlement.get("culture_type", 0)),
		"culture_name": str(settlement.get("culture_name", "unknown")),
		"scar_max": int(settlement.get("scar_max", 0)),
		"reputation_min": int(settlement.get("reputation_min", 0)),
		"regions": regions if regions is PackedInt32Array else PackedInt32Array(),
		"governance": gov,
		"war_profile": war,
		"last_activity_tick": int(settlement.get("last_activity_tick", -1)),
		"last_pawn_death_tick": int(settlement.get("last_pawn_death_tick", -1)),
		"peace_threshold_ticks": int(settlement.get("peace_threshold_ticks", 0))
	}
	
	# Add region count and pawns if available
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main != null:
		obs["pawn_count"] = _count_pawns_in_regions(regions)
	
	return obs

static func _pawn_governance_role(pawn_data: PawnData, gov_profile: Dictionary) -> String:
	var ruler_id: int = int(gov_profile.get("ruler_id", -1))
	if int(pawn_data.id) == ruler_id:
		return "Ruler"
	var council_ids: PackedInt32Array = gov_profile.get("council_ids", PackedInt32Array())
	if council_ids.has(int(pawn_data.id)):
		return "Council"
	return "Citizen"


static func _focus_append_house_stub_lines(out: PackedStringArray, center_region: int) -> void:
	if center_region < 0:
		return
	FactionRegistry.sync_from_settlements()
	var house: Dictionary = FactionRegistry.get_house_for_zone(str(center_region))
	if house.is_empty():
		out.append("Faction / house (stub): (none for this zone yet)")
		return
	var disp: String = str(house.get("house_display", house.get("house_id", "")))
	var hid: String = str(house.get("house_id", ""))
	var rgb_v: Variant = house.get("banner_rgb", [])
	var rgb_s: String = "n/a"
	if rgb_v is Array:
		var rgb: Array = rgb_v as Array
		if rgb.size() >= 3:
			rgb_s = "%.2f,%.2f,%.2f" % [float(rgb[0]), float(rgb[1]), float(rgb[2])]
	out.append("Faction / house (stub): %s [%s] | banner %s" % [disp, hid, rgb_s])


static func _pretty_governance_name(raw: String) -> String:
	match raw.to_lower():
		"monarchy":
			return "Monarchy"
		"council":
			return "Council"
		"chieftain":
			return "Chieftain"
		"tribal":
			return "Tribal"
		_:
			return "Anarchy"


static func _pretty_settlement_state(raw: String) -> String:
	match raw.to_lower():
		"active":
			return "Active"
		"revivable":
			return "Revivable"
		"recovering":
			return "Recovering"
		"abandoned":
			return "Abandoned"
		"permanently_abandoned":
			return "Permanently Abandoned"
		"grave":
			return "Grave"
		_:
			return raw.capitalize()


static func _pretty_war_state(raw: String) -> String:
	match raw.to_lower():
		"peace":
			return "Peace"
		"proposed":
			return "Proposed"
		"mobilizing":
			return "Mobilizing"
		"at_war":
			return "At War"
		"truce":
			return "Truce"
		_:
			return raw.capitalize()


static func _observer_war_target_label(target_settlement_id: int) -> String:
	if target_settlement_id < 0:
		return "None"
	return str(target_settlement_id)


static func _pawn_name_by_id(pawn_id: int) -> String:
	if pawn_id < 0:
		return "None"
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return "Unknown"
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return "Unknown"
	for p in spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if int(p.data.id) == pawn_id:
			return str(p.data.display_name)
	return "Unknown"


static func _count_pawns_in_regions(regions_v: Variant) -> int:
	if not (regions_v is PackedInt32Array):
		return 0
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		return 0
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		return 0
	var wanted: Dictionary = {}
	for rk in regions_v as PackedInt32Array:
		wanted[int(rk)] = true
	var n: int = 0
	for p in spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var pawn_region: int = preload("res://autoloads/WorldMemory.gd")._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if wanted.has(pawn_region):
			n += 1
	return n
