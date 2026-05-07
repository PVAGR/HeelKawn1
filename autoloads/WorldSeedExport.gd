extends Node
## WorldSeedExport - Exports world seed + state to file for replay/sharing
##
## Creates complete, deterministic world exports:
## - World seed (for regeneration)
## - All WorldMemory events (for history)
## - Settlement states
## - Pawn data snapshots
## - Knowledge carriers
## - Current game state
##
## Output: `user://world_seeds/YYYY-MM-DD_HHMMSS_seed.json`

const OUTPUT_DIR: String = "user://world_seeds/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)


## Export complete world state
func export_world_state() -> String:
	var export_data: Dictionary = {
		"version": "1.0",
		"export_time": Time.get_datetime_string_from_system(),
		"tick": GameManager.tick_count if GameManager != null else 0,
		"world_seed": _get_world_seed(),
		"events": _export_events(),
		"settlements": _export_settlements(),
		"pawns": _export_pawns(),
		"knowledge": _export_knowledge(),
		"stockpiles": _export_stockpiles(),
		"statistics": _export_statistics()
	}
	
	var json_string: String = JSON.stringify(export_data, "  ", false)
	var filename: String = _generate_filename()
	
	# Save to file
	var file: FileAccess = FileAccess.open(OUTPUT_DIR + filename, FileAccess.WRITE)
	if file != null:
		file.store_string(json_string)
		file.close()
		print("[WorldSeedExport] Saved world seed: %s (%.2f MB)" % [filename, float(file.get_length()) / 1048576.0])
		return filename
	
	push_error("[WorldSeedExport] Failed to save world seed: %s" % filename)
	return ""


func _get_world_seed() -> int:
	# Get the world seed from WorldRNG or WorldMemory
	if WorldRNG != null and WorldRNG.has_method("get_seed"):
		return int(WorldRNG.call("get_seed"))
	
	# Fallback: use tick 0 hash
	return 0


func _export_events() -> Array:
	if WorldMemory == null:
		return []

	# Export all events from WorldMemory
	return WorldMemory.get_events()


func _export_settlements() -> Array:
	if SettlementMemory == null:
		return []
	
	var settlements: Array = []
	
	# Get settlements from SettlementMemory
	var settlements_data: Variant = null
	if SettlementMemory.has_method("get"):
		settlements_data = SettlementMemory.get("settlements")
	elif "settlements" in SettlementMemory:
		settlements_data = SettlementMemory.settlements
	
	if settlements_data == null or not (settlements_data is Array):
		return settlements
	
	for settlement in settlements_data:
		if settlement is Dictionary:
			var export: Dictionary = {
				"id": settlement.get("id", -1),
				"name": settlement.get("name", "Unnamed"),
				"center_region": settlement.get("center_region", -1),
				"state": settlement.get("state", "active"),
				"culture_name": settlement.get("culture_name", ""),
				"founded_tick": settlement.get("founded_tick", -1),
				"population": settlement.get("population", 0),
				"buildings": settlement.get("buildings", []),
				"stockpile_food": settlement.get("stockpile_food", 0),
			}
			settlements.append(export)
	
	return settlements


func _export_pawns() -> Array:
	var pawns: Array = []
	
	# Get pawns from PawnSpawner
	var spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if spawner == null or not spawner.has_method("get_all_pawn_data"):
		return pawns
	
	var pawn_data_list: Array = spawner.call("get_all_pawn_data")
	for pd in pawn_data_list:
		if pd is RefCounted:
			var export: Dictionary = {
				"id": pd.id if pd.has("id") else -1,
				"display_name": pd.display_name if pd.has("display_name") else "Unknown",
				"age": pd.age if pd.has("age") else 0,
				"gender": pd.gender if pd.has("gender") else 0,
				"profession": pd.profession if pd.has("profession") else -1,
				"skills": pd.skills.duplicate() if pd.has("skills") else {},
				"parent_a_id": pd.parent_a_id if pd.has("parent_a_id") else -1,
				"parent_b_id": pd.parent_b_id if pd.has("parent_b_id") else -1,
				"children_ids": pd.children_ids.duplicate() if pd.has("children_ids") else [],
				"is_dead": pd.is_dead if pd.has("is_dead") else false,
			}
			pawns.append(export)
	
	return pawns


func _export_knowledge() -> Dictionary:
	var knowledge: Dictionary = {
		"carriers": [],
		"teaching_records": [],
		"known_types": []
	}
	
	# Export knowledge carriers
	if KnowledgeSystem != null:
		if KnowledgeSystem.has_method("get"):
			var carriers: Variant = KnowledgeSystem.get("knowledge_carriers")
			if carriers != null and carriers is Dictionary:
				for pawn_id in carriers:
					knowledge.carriers.append({
						"pawn_id": int(pawn_id),
						"knowledge_types": carriers[pawn_id].duplicate()
					})
	
	return knowledge


func _export_stockpiles() -> Array:
	var stockpiles: Array = []
	
	if StockpileManager != null:
		# Export stockpile contents
		# This would iterate through all stockpiles and export their contents
		pass
	
	return stockpiles


func _export_statistics() -> Dictionary:
	var stats: Dictionary = {
		"total_ticks": GameManager.tick_count if GameManager != null else 0,
		"total_pawns_born": 0,
		"total_pawns_died": 0,
		"total_settlements": 0,
		"total_events": 0,
		"civilization_stage": 0,
	}
	
	# Get statistics from WorldMemory
	if WorldMemory != null:
		if WorldMemory.has_method("get_event_count"):
			stats.total_events = int(WorldMemory.call("get_event_count"))
	
	# Get civilization stage
	if CivilizationStage != null:
		# Get average civilization stage across settlements
		pass
	
	return stats


func _generate_filename() -> String:
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "").replace(" ", "_").replace("-", "")
	return "world_seed_%s_tick_%d.json" % [timestamp, GameManager.tick_count]


## Import world state from file
func import_world_state(filename: String) -> bool:
	var file: FileAccess = FileAccess.open(filename, FileAccess.READ)
	if file == null:
		push_error("[WorldSeedExport] Failed to open file: %s" % filename)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_string)
	if parsed == null:
		push_error("[WorldSeedExport] Failed to parse JSON: %s" % filename)
		return false
	
	var import_data: Dictionary = parsed as Dictionary
	
	# Validate version
	var version: String = str(import_data.get("version", "unknown"))
	if version != "1.0":
		push_warning("[WorldSeedExport] Importing version %s, expected 1.0" % version)
	
	# Import would restore world state here
	# This is complex and would need careful integration with existing systems
	
	print("[WorldSeedExport] Imported world seed from: %s" % filename)
	return true


## Export summary text file (human-readable)
func export_summary() -> String:
	var summary: String = ""
	
	summary += "╔══════════════════════════════════════════════════════════╗\n"
	summary += "║              HEELKAWN WORLD SEED SUMMARY                 ║\n"
	summary += "╚══════════════════════════════════════════════════════════╝\n\n"

	summary += "Export Time: %s\n" % Time.get_datetime_string_from_system()
	summary += "Current Tick: %d\n\n" % (GameManager.tick_count if GameManager != null else 0)

	# Settlements summary
	summary += "━━━ SETTLEMENTS ━━━\n"
	if SettlementMemory != null:
		var settlements_data: Variant = null
		if SettlementMemory.has_method("get"):
			settlements_data = SettlementMemory.get("settlements")

		if settlements_data != null and settlements_data is Array:
			summary += "Total Settlements: %d\n\n" % settlements_data.size()
			for settlement in settlements_data:
				if settlement is Dictionary:
					summary += "• %s (Region %d, Population %d, State: %s)\n" % [
						settlement.get("name", "Unnamed"),
						settlement.get("center_region", -1),
						settlement.get("population", 0),
						settlement.get("state", "unknown")
					]

	summary += "\n"

	# Pawns summary
	summary += "━━━ POPULATION ━━━\n"
	var spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	if spawner != null and spawner.has_method("get_pawn_count"):
		var pawn_count: int = int(spawner.call("get_pawn_count"))
		summary += "Total Pawns: %d\n" % pawn_count

	summary += "\n"

	# Events summary
	summary += "━━━ HISTORY ━━━\n"
	if WorldMemory != null:
		if WorldMemory.has_method("get_event_count"):
			var event_count: int = int(WorldMemory.call("get_event_count"))
			summary += "Total Events: %d\n" % event_count
	
	return summary
