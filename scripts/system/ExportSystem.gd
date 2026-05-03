class_name ExportSystem
extends Node

## Export system for characters and items
## Allows exporting pawn data for future online MMO integration

## Export a pawn to JSON format
static func export_pawn(pawn: Pawn) -> Dictionary:
	if pawn == null or not is_instance_valid(pawn):
		return {}
	
	var pd: PawnData = pawn.data
	if pd == null:
		return {}
	
	var export_data: Dictionary = {
		"version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"pawn_id": pd.id,
		"name": pd.display_name,
		"age": pd.age,
		"age_years": pd.age_years,
		"gender": pd.gender,
		"profession": str(PawnData.Profession.keys()[pd.current_profession]),
		
		# Stage 1: Individual progression
		"level": pd.level,
		"stamina": pd.stamina,
		"body_temperature": pd.body_temperature,
		"pain": pd.pain,
		"exposure_sickness": pd.exposure_sickness,
		"injuries": pd.injuries,
		"job_proficiency": pd.job_proficiency,
		"skill_xp": pd.skill_xp,
		"skill_trees": pd.skill_trees,
		"mastery_perks": pd.mastery_perks,
		"perception_radius": pd.perception_radius,
		"location_memory": pd.location_memory,
		
		# Stage 2: Family & Trust
		"family_bonds": pd.family_bonds,
		"co_presence": pd.co_presence,
		"household_id": pd.household_id,
		"trust": pd.trust,
		"spouse_id": pd.spouse_id,
		"children_ids": pd.children_ids,
		
		# Stage 3: Clan & Household Network
		"clan_id": pd.clan_id,
		"clan_reputation": pd.clan_reputation,
		"reputation_score": pd.reputation_score,
		"leadership_role": pd.leadership_role,
		"labor_contributions": pd.labor_contributions,
		"clan_influence": pd.clan_influence,
		
		# Stage 4: Settlement/Homestead
		"settlement_id": pd.settlement_id,
		"homestead_tile": pd.homestead_tile,
		"food_produced": pd.food_produced,
		"buildings_constructed": pd.buildings_constructed,
		"trade_relationships": pd.trade_relationships,
		"settlement_role": pd.settlement_role,
		"owned_properties": pd.owned_properties,
		
		# Stage 5: Region/Local Polity
		"region_id": pd.region_id,
		"roads_built": pd.roads_built,
		"regional_safety": pd.regional_safety,
		"known_customs": pd.known_customs,
		"citizenship_status": pd.citizenship_status,
		"taxes_paid": pd.taxes_paid,
		
		# Stage 6: Nation/Country
		"nation_id": pd.nation_id,
		"law_compliance": pd.law_compliance,
		"cultural_affinity": pd.cultural_affinity,
		"military_service_years": pd.military_service_years,
		"military_rank": pd.military_rank,
		"diplomatic_standing": pd.diplomatic_standing,
		"national_citizenship": pd.national_citizenship,
		
		# Stage 7: World systems
		"cross_region_influence": pd.cross_region_influence,
		"climate_adaptation": pd.climate_adaptation,
		"myth_knowledge": pd.myth_knowledge,
		"world_events_witnessed": pd.world_events_witnessed,
		"legacy_score": pd.legacy_score,
		
		# Base stats
		"hunger": pd.hunger,
		"rest": pd.rest,
		"mood": pd.mood,
		"health": pd.health,
		"parent_a_id": pd.parent_a_id,
		"parent_b_id": pd.parent_b_id,
		"traits": pd.traits,
	}
	
	return export_data


## Export a pawn to a JSON file
static func export_pawn_to_file(pawn: Pawn, file_path: String) -> bool:
	var export_data: Dictionary = export_pawn(pawn)
	if export_data.is_empty():
		return false
	
	var json_string: String = JSON.stringify(export_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[ExportSystem] Exported pawn %s to %s" % [pawn.data.display_name, file_path])
	return true


## Import a pawn from JSON data
static func import_pawn_from_data(import_data: Dictionary, target_pawn: Pawn) -> bool:
	if target_pawn == null or not is_instance_valid(target_pawn):
		return false
	
	var pd: PawnData = target_pawn.data
	if pd == null:
		return false
	
	# Verify version
	if import_data.get("version", "") != "1.0":
		print("[ExportSystem] Warning: Import version mismatch")
	
	# Import basic info
	pd.display_name = import_data.get("name", pd.display_name)
	pd.age = import_data.get("age", pd.age)
	pd.age_years = import_data.get("age_years", pd.age_years)
	pd.gender = import_data.get("gender", pd.gender)
	
	# Stage 1: Individual progression
	pd.level = import_data.get("level", pd.level)
	pd.stamina = import_data.get("stamina", pd.stamina)
	pd.body_temperature = import_data.get("body_temperature", pd.body_temperature)
	pd.pain = import_data.get("pain", pd.pain)
	pd.exposure_sickness = import_data.get("exposure_sickness", pd.exposure_sickness)
	pd.injuries = import_data.get("injuries", pd.injuries)
	pd.job_proficiency = import_data.get("job_proficiency", pd.job_proficiency)
	pd.skill_xp = import_data.get("skill_xp", pd.skill_xp)
	pd.skill_trees = import_data.get("skill_trees", pd.skill_trees)
	pd.mastery_perks = import_data.get("mastery_perks", pd.mastery_perks)
	pd.perception_radius = import_data.get("perception_radius", pd.perception_radius)
	pd.location_memory = import_data.get("location_memory", pd.location_memory)
	
	# Stage 2: Family & Trust
	pd.family_bonds = import_data.get("family_bonds", pd.family_bonds)
	pd.co_presence = import_data.get("co_presence", pd.co_presence)
	pd.household_id = import_data.get("household_id", pd.household_id)
	pd.trust = import_data.get("trust", pd.trust)
	pd.spouse_id = import_data.get("spouse_id", pd.spouse_id)
	pd.children_ids = import_data.get("children_ids", pd.children_ids)
	
	# Stage 3: Clan & Household Network
	pd.clan_id = import_data.get("clan_id", pd.clan_id)
	pd.clan_reputation = import_data.get("clan_reputation", pd.clan_reputation)
	pd.reputation_score = import_data.get("reputation_score", pd.reputation_score)
	pd.leadership_role = import_data.get("leadership_role", pd.leadership_role)
	pd.labor_contributions = import_data.get("labor_contributions", pd.labor_contributions)
	pd.clan_influence = import_data.get("clan_influence", pd.clan_influence)
	
	# Stage 4: Settlement/Homestead
	pd.settlement_id = import_data.get("settlement_id", pd.settlement_id)
	pd.homestead_tile = import_data.get("homestead_tile", pd.homestead_tile)
	pd.food_produced = import_data.get("food_produced", pd.food_produced)
	pd.buildings_constructed = import_data.get("buildings_constructed", pd.buildings_constructed)
	pd.trade_relationships = import_data.get("trade_relationships", pd.trade_relationships)
	pd.settlement_role = import_data.get("settlement_role", pd.settlement_role)
	pd.owned_properties = import_data.get("owned_properties", pd.owned_properties)
	
	# Stage 5: Region/Local Polity
	pd.region_id = import_data.get("region_id", pd.region_id)
	pd.roads_built = import_data.get("roads_built", pd.roads_built)
	pd.regional_safety = import_data.get("regional_safety", pd.regional_safety)
	pd.known_customs = import_data.get("known_customs", pd.known_customs)
	pd.citizenship_status = import_data.get("citizenship_status", pd.citizenship_status)
	pd.taxes_paid = import_data.get("taxes_paid", pd.taxes_paid)
	
	# Stage 6: Nation/Country
	pd.nation_id = import_data.get("nation_id", pd.nation_id)
	pd.law_compliance = import_data.get("law_compliance", pd.law_compliance)
	pd.cultural_affinity = import_data.get("cultural_affinity", pd.cultural_affinity)
	pd.military_service_years = import_data.get("military_service_years", pd.military_service_years)
	pd.military_rank = import_data.get("military_rank", pd.military_rank)
	pd.diplomatic_standing = import_data.get("diplomatic_standing", pd.diplomatic_standing)
	pd.national_citizenship = import_data.get("national_citizenship", pd.national_citizenship)
	
	# Stage 7: World systems
	pd.cross_region_influence = import_data.get("cross_region_influence", pd.cross_region_influence)
	pd.climate_adaptation = import_data.get("climate_adaptation", pd.climate_adaptation)
	pd.myth_knowledge = import_data.get("myth_knowledge", pd.myth_knowledge)
	pd.world_events_witnessed = import_data.get("world_events_witnessed", pd.world_events_witnessed)
	pd.legacy_score = import_data.get("legacy_score", pd.legacy_score)
	
	# Base stats
	pd.hunger = import_data.get("hunger", pd.hunger)
	pd.rest = import_data.get("rest", pd.rest)
	pd.mood = import_data.get("mood", pd.mood)
	pd.health = import_data.get("health", pd.health)
	pd.parent_a_id = import_data.get("parent_a_id", pd.parent_a_id)
	pd.parent_b_id = import_data.get("parent_b_id", pd.parent_b_id)
	pd.traits = import_data.get("traits", pd.traits)
	
	print("[ExportSystem] Imported pawn data for %s" % pd.display_name)
	return true


## Import a pawn from a JSON file
static func import_pawn_from_file(file_path: String, target_pawn: Pawn) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: int = json.parse(json_string)
	if parse_result != OK:
		print("[ExportSystem] Failed to parse JSON from %s" % file_path)
		return false
	
	var import_data: Dictionary = json.data
	return import_pawn_from_data(import_data, target_pawn)


## Export all pawns to a directory
static func export_all_pawns(directory: String, tree: Node) -> int:
	var exported_count: int = 0
	
	for pawn in PawnSpawner.find_pawns():
		if not is_instance_valid(pawn):
			continue
		
		var file_name: String = "pawn_%d_%s.json" % [pawn.data.id, pawn.data.display_name.replace(" ", "_")]
		var file_path: String = directory.path_join(file_name)
		
		if export_pawn_to_file(pawn, file_path):
			exported_count += 1
	
	print("[ExportSystem] Exported %d pawns to %s" % [exported_count, directory])
	return exported_count


## Export world seed and configuration
static func export_world_seed(file_path: String) -> bool:
	var export_data: Dictionary = {
		"version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"world_seed": WorldRNG.current_seed() if WorldRNG != null else 0,
		"tick_count": GameManager.tick_count if GameManager != null else 0,
		"game_speed": GameManager.game_speed if GameManager != null else 1.0,
		"is_paused": GameManager.is_paused if GameManager != null else false,
	}
	
	var json_string: String = JSON.stringify(export_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[ExportSystem] Exported world seed to %s" % file_path)
	return true


static func _write_text_file(file_path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true


## One-click folder under [code]user://heelkawn_promotion_exports/[/code]: seed JSON, readable summary, full chronicle, bloodlines, artifacts.
## Returns [code]ok[/code], [code]path[/code] ([code]user://…[/code]), and OS path in [code]absolute_path[/code] for Finder/Explorer.
static func export_promotion_bundle() -> Dictionary:
	var ts: int = int(Time.get_unix_time_from_system())
	var rel_folder: String = "user://heelkawn_promotion_exports/export_%d" % ts
	var abs_folder: String = ProjectSettings.globalize_path(rel_folder)
	var mk_err: Error = DirAccess.make_dir_recursive_absolute(abs_folder)
	if mk_err != OK and mk_err != ERR_ALREADY_EXISTS:
		push_warning("[ExportSystem] promotion bundle mkdir failed: %s err=%d" % [abs_folder, mk_err])
		return {"ok": false, "error": "mkdir %d" % mk_err, "path": rel_folder, "absolute_path": abs_folder}
	var pawn_n: int = PawnSpawner.find_pawns().size()
	var set_n: int = 0
	if SettlementMemory != null:
		set_n = SettlementMemory.get_settlements().size()
	var rich: Dictionary = {
		"schema": "heelkawn_promotion_world_seed/v1",
		"export_unix_time": ts,
		"world_seed": WorldRNG.current_seed() if WorldRNG != null else 0,
		"tick_count": GameManager.tick_count if GameManager != null else 0,
		"game_speed": GameManager.game_speed if GameManager != null else 1.0,
		"is_paused": GameManager.is_paused if GameManager != null else false,
		"pawn_count_live": pawn_n,
		"settlement_count": set_n,
		"world_memory_events": WorldMemory.event_count() if WorldMemory != null else 0,
	}
	var seed_path: String = rel_folder.path_join("world_seed.json")
	var seed_file: FileAccess = FileAccess.open(seed_path, FileAccess.WRITE)
	if seed_file == null:
		return {"ok": false, "error": "open world_seed.json", "path": rel_folder, "absolute_path": abs_folder}
	seed_file.store_string(JSON.stringify(rich, "\t"))
	seed_file.close()
	if WorldMemory != null:
		_write_text_file(rel_folder.path_join("chronicle_summary.txt"), WorldMemory.build_readable_chronicle_summary(22))
		export_chronicle(rel_folder.path_join("chronicle.json"))
	export_bloodlines(rel_folder.path_join("bloodlines.json"))
	export_artifacts(rel_folder.path_join("artifacts.json"))
	print("[ExportSystem] Promotion bundle -> %s (OS: %s)" % [rel_folder, abs_folder])
	return {"ok": true, "error": "", "path": rel_folder, "absolute_path": abs_folder}


## Export world chronicle (events from WorldMemory)
static func export_chronicle(file_path: String) -> bool:
	var export_data: Dictionary = {
		"version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"tick_count": GameManager.tick_count if GameManager != null else 0,
		"events": WorldMemory.to_save_dict().get("events", []) if WorldMemory != null else [],
	}
	
	var json_string: String = JSON.stringify(export_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[ExportSystem] Exported chronicle with %d events to %s" % [export_data.events.size(), file_path])
	return true


## Export bloodline data from family memory
static func export_bloodlines(file_path: String) -> bool:
	var export_data: Dictionary = {
		"version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"tick_count": GameManager.tick_count if GameManager != null else 0,
		"families": WorldPersistence.family_memory.duplicate(true) if WorldPersistence != null else {},
	}
	
	var json_string: String = JSON.stringify(export_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[ExportSystem] Exported %d bloodlines to %s" % [export_data.families.size(), file_path])
	return true


## Export artifacts (landmarks, ruins, road traces)
static func export_artifacts(file_path: String) -> bool:
	var export_data: Dictionary = {
		"version": "1.0",
		"export_timestamp": Time.get_unix_time_from_system(),
		"tick_count": GameManager.tick_count if GameManager != null else 0,
		"landmarks": WorldPersistence.named_landmarks.duplicate(true) if WorldPersistence != null else {},
		"ruins": WorldPersistence.ruins.duplicate(true) if WorldPersistence != null else {},
		"road_traces": WorldPersistence.road_traces.duplicate(true) if WorldPersistence != null else {},
	}
	
	var json_string: String = JSON.stringify(export_data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(json_string)
	file.close()
	
	print("[ExportSystem] Exported artifacts to %s" % file_path)
	return true


## Export complete world state (all exports combined)
static func export_complete_world(directory: String) -> bool:
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		print("[ExportSystem] Failed to open directory: %s" % directory)
		return false
	
	# Ensure directory exists
	if not dir.dir_exists(directory):
		dir.make_dir_recursive(directory)
	
	var success: bool = true
	
	# Export world seed
	if not export_world_seed(directory.path_join("world_seed.json")):
		success = false
	
	# Export chronicle
	if not export_chronicle(directory.path_join("chronicle.json")):
		success = false
	
	# Export bloodlines
	if not export_bloodlines(directory.path_join("bloodlines.json")):
		success = false
	
	# Export artifacts
	if not export_artifacts(directory.path_join("artifacts.json")):
		success = false
	
	if success:
		print("[ExportSystem] Complete world export successful to %s" % directory)
	else:
		print("[ExportSystem] Complete world export had errors")
	
	return success
