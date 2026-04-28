extends Node
## Phase 5: Observation API - Programmatic access to Focus Inspector data
## Provides the same data that human players see via mouse inspection, but for AI agents

## Get comprehensive pawn observation data (same as Focus Inspector pawn view)
static func observe_pawn(pawn_id: int) -> Dictionary:
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null or not main.has_method("_pawn_spawner"):
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
	if main == null or not main.has_method("_world"):
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
	if main == null or not main.has_method("_pawn_spawner"):
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
	if main == null or not main.has_method("_world") or not main.has_method("_camera"):
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
	if main != null and main.has_method("_pawn_spawner"):
		var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
		if spawner != null:
			obs["pawn_count"] = main._count_pawns_in_regions(regions) if main.has_method("_count_pawns_in_regions") else 0
	
	return obs

static func _pawn_governance_role(pawn_data: PawnData, gov_profile: Dictionary) -> String:
	var ruler_id: int = int(gov_profile.get("ruler_id", -1))
	if int(pawn_data.id) == ruler_id:
		return "Ruler"
	var council_ids: PackedInt32Array = gov_profile.get("council_ids", PackedInt32Array())
	if council_ids.has(int(pawn_data.id)):
		return "Council"
	return "Citizen"
