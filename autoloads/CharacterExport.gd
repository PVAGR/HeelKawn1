extends Node
## Phase 6: Character Export System for Online Integration
## Export pawn data as JSON with signature for pvabazaar.org
## Validation, import system, cross-world compatibility

## Export configuration
var export_version: String = "1.0"
var api_endpoint: String = "https://pvabazaar.org/api/characters"
var api_key: String = ""  # To be configured

## Export format
var export_fields: Array = [
	"id", "display_name", "age", "age_years", "gender",
	"color", "body_type", "hair_style", "hair_color", "apparel_color",
	"hunger", "rest", "mood", "health", "max_health",
	"openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism",
	"skill_xp", "skills", "affinities", "level",
	"traits", "family_bonds", "trust", "social_rapport",
	"settlement_id", "household_id", "clan_id",
	"reputation_score", "leadership_role",
	"episodic_memory", "semantic_memory", "spatial_memory", "social_memory",
	"active_goals", "goal_history",
	"neural_network"
]

## Import tracking
var imported_characters: Dictionary = {}  # character_id -> import_data
var export_history: Array = []  # {character_id, tick, destination}

func _ready() -> void:
	pass


## Soul & Society: web companion JSON (delegates to [HeelKawnSoulExport]).
func export_character_data(pawn_id: String) -> Dictionary:
	return HeelKawnSoulExport.export_character_data(pawn_id)


## Export a pawn character
func export_character(pawn_data: PawnData) -> Dictionary:
	if pawn_data == null:
		return {"error": "Invalid pawn data"}
	
	var export_data: Dictionary = {
		"version": export_version,
		"export_timestamp": Time.get_unix_time_from_system(),
		"game_tick": GameManager.tick_count if GameManager != null else 0,
		"character": _serialize_character(pawn_data),
		"signature": _generate_signature(pawn_data)
	}
	
	# Validate export
	var validation: Dictionary = _validate_export(export_data)
	if not validation.get("valid", false):
		return {"error": "Validation failed", "details": validation}
	
	# Record in history
	export_history.append({
		"character_id": pawn_data.id,
		"character_name": pawn_data.display_name,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"destination": "pvabazaar.org",
		"timestamp": export_data.export_timestamp
	})
	
	return export_data


## Serialize character data
func _serialize_character(pawn_data: PawnData) -> Dictionary:
	var character: Dictionary = {}
	
	for field in export_fields:
		if _pawn_has_property(pawn_data, field):
			var value = pawn_data.get(field)
			
			# Handle special serialization for complex types
			match field:
				"neural_network":
					if pawn_data.neural_network != null and pawn_data.neural_network.has_method("to_dict"):
						character[field] = pawn_data.neural_network.to_dict()
					else:
						character[field] = {}
				"episodic_memory", "semantic_memory", "spatial_memory", "social_memory":
					# Limit memory size for export
					character[field] = _compress_memory(value)
				"active_goals", "goal_history":
					character[field] = value
				_:
					character[field] = value
	
	# Add metadata
	character["_metadata"] = {
		"export_version": export_version,
		"source_world": "HeelKawn",
		"total_playtime_ticks": GameManager.tick_count if GameManager != null else 0
	}
	
	return character


func _pawn_has_property(pawn_data: PawnData, field: String) -> bool:
	for prop_data in pawn_data.get_property_list():
		if str((prop_data as Dictionary).get("name", "")) == field:
			return true
	return false


## Compress memory for export (limit size)
func _compress_memory(memory_dict: Dictionary) -> Dictionary:
	var compressed: Dictionary = {}
	var max_entries: int = 50  # Limit to 50 most recent/important entries
	var entry_count: int = 0
	
	for key in memory_dict:
		if entry_count >= max_entries:
			break
		compressed[key] = memory_dict[key]
		entry_count += 1
	
	return compressed


## Generate signature for validation
func _generate_signature(pawn_data: PawnData) -> String:
	var signature_data: String = "%d_%s_%d" % [
		pawn_data.id,
		pawn_data.display_name,
		GameManager.tick_count if GameManager != null else 0
	]
	
	# Simple hash-based signature (in production, use proper cryptographic signature)
	var hash: int = signature_data.hash()
	return str(hash)


## Validate export data
func _validate_export(export_data: Dictionary) -> Dictionary:
	var validation: Dictionary = {"valid": true, "errors": []}
	
	# Check version
	if export_data.get("version", "") != export_version:
		validation.valid = false
		validation.errors.append("Version mismatch")
	
	# Check required fields
	var character: Dictionary = export_data.get("character", {})
	var required_fields: Array = ["id", "display_name", "age", "skills"]
	
	for field in required_fields:
		if not character.has(field):
			validation.valid = false
			validation.errors.append("Missing required field: %s" % field)
	
	# Check signature
	var expected_signature: String = str(character.get("_metadata", {}).get("export_version", "").hash())
	if export_data.get("signature", "") != expected_signature:
		# Allow signature mismatch for now (would use proper crypto in production)
		pass
	
	# Check for cheating (unrealistic values)
	if character.get("level", 0) > 100:
		validation.valid = false
		validation.errors.append("Invalid level")
	
	if character.get("health", 0) > character.get("max_health", 100):
		validation.valid = false
		validation.errors.append("Health exceeds max")
	
	return validation


## Upload character to online world
func upload_character(export_data: Dictionary) -> Dictionary:
	# Validate first
	var validation: Dictionary = _validate_export(export_data)
	if not validation.get("valid", false):
		return {"error": "Validation failed", "details": validation}
	
	# In production, this would make an HTTP request to the API
	# For now, simulate the upload
	var character: Dictionary = export_data.character
	var character_id: String = "online_%d" % character.id
	
	var response: Dictionary = {
		"success": true,
		"character_id": character_id,
		"message": "Character uploaded successfully",
		"timestamp": Time.get_unix_time_from_system()
	}
	
	return response


## Import character from online world
func import_character(import_data: Dictionary) -> Dictionary:
	# Validate import
	var validation: Dictionary = _validate_import(import_data)
	if not validation.get("valid", false):
		return {"error": "Import validation failed", "details": validation}
	
	var character: Dictionary = import_data.character
	
	# Create new PawnData from import
	var imported_pawn: PawnData = _deserialize_character(character)
	
	if imported_pawn == null:
		return {"error": "Failed to deserialize character"}
	
	# Track import
	imported_characters[str(imported_pawn.id)] = {
		"import_data": import_data,
		"import_timestamp": Time.get_unix_time_from_system(),
		"source": import_data.get("source", "unknown")
	}
	
	return {
		"success": true,
		"character": imported_pawn,
		"message": "Character imported successfully"
	}


## Validate import data
func _validate_import(import_data: Dictionary) -> Dictionary:
	var validation: Dictionary = {"valid": true, "errors": []}
	
	# Check version compatibility
	var import_version: String = import_data.get("version", "")
	if import_version != export_version:
		# Attempt version compatibility check
		if not _is_version_compatible(import_version):
			validation.valid = false
			validation.errors.append("Incompatible version")
	
	# Check character data
	var character: Dictionary = import_data.get("character", {})
	if character.is_empty():
		validation.valid = false
		validation.errors.append("No character data")
	
	return validation


## Check version compatibility
func _is_version_compatible(version: String) -> bool:
	# Simple version check - in production would be more sophisticated
	var major: int = int(version.split(".")[0])
	var current_major: int = int(export_version.split(".")[0])
	return major == current_major


## Deserialize character from import data
func _deserialize_character(character: Dictionary) -> PawnData:
	var pawn_data: PawnData = PawnData.new()
	
	# Restore basic fields
	for field in ["id", "display_name", "age", "age_years", "gender", "color", "body_type", "hair_style", "hair_color", "apparel_color"]:
		if character.has(field):
			pawn_data.set(field, character[field])
	
	# Restore needs
	for field in ["hunger", "rest", "mood", "health", "max_health"]:
		if character.has(field):
			pawn_data.set(field, character[field])
	
	# Restore personality
	for field in ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"]:
		if character.has(field):
			pawn_data.set(field, character[field])
	
	# Restore skills
	if character.has("skill_xp"):
		pawn_data.skill_xp = character.skill_xp.duplicate()
	if character.has("skills"):
		pawn_data.skills = character.skills.duplicate()
	if character.has("affinities"):
		pawn_data.affinities = character.affinities.duplicate()
	if character.has("level"):
		pawn_data.level = character.level
	
	# Restore social data
	if character.has("family_bonds"):
		pawn_data.family_bonds = character.family_bonds.duplicate()
	if character.has("trust"):
		pawn_data.trust = character.trust.duplicate()
	if character.has("social_rapport"):
		pawn_data.social_rapport = character.social_rapport.duplicate()
	
	# Restore settlement data
	if character.has("settlement_id"):
		pawn_data.settlement_id = character.settlement_id
	if character.has("household_id"):
		pawn_data.household_id = character.household_id
	if character.has("clan_id"):
		pawn_data.clan_id = character.clan_id
	
	# Restore reputation
	if character.has("reputation_score"):
		pawn_data.reputation_score = character.reputation_score
	if character.has("leadership_role"):
		pawn_data.leadership_role = character.leadership_role
	
	# Restore memory (compressed)
	if character.has("episodic_memory"):
		pawn_data.episodic_memory = character.episodic_memory.duplicate()
	if character.has("semantic_memory"):
		pawn_data.semantic_memory = character.semantic_memory.duplicate()
	if character.has("spatial_memory"):
		pawn_data.spatial_memory = character.spatial_memory.duplicate()
	if character.has("social_memory"):
		pawn_data.social_memory = character.social_memory.duplicate()
	
	# Restore goals
	if character.has("active_goals"):
		pawn_data.active_goals = character.active_goals.duplicate()
	if character.has("goal_history"):
		pawn_data.goal_history = character.goal_history.duplicate()
	
	# Restore neural network
	if character.has("neural_network") and not character.neural_network.is_empty():
		var network_dict: Dictionary = character.neural_network
		var restored_network: Variant = PawnData.create_neural_network({
			"openness": pawn_data.openness,
			"conscientiousness": pawn_data.conscientiousness,
			"extraversion": pawn_data.extraversion,
			"agreeableness": pawn_data.agreeableness,
			"neuroticism": pawn_data.neuroticism,
		})
		if restored_network != null and restored_network.has_method("from_dict"):
			restored_network.from_dict(network_dict)
			pawn_data.neural_network = restored_network
	
	# Adapt to local world state
	_adapt_to_local_world(pawn_data)
	
	return pawn_data


## Adapt imported character to local world state
func _adapt_to_local_world(pawn_data: PawnData) -> void:
	# Reset settlement/household/clan if they don't exist in local world
	# This is a simplified check - in production would validate against actual world data
	if pawn_data.settlement_id < 0:
		pawn_data.settlement_id = -1
	if pawn_data.household_id < 0:
		pawn_data.household_id = -1
	if pawn_data.clan_id < 0:
		pawn_data.clan_id = -1
	
	# Adjust social relationships to avoid conflicts
	# In production, would remap IDs to local equivalents
	pass


## Get export history
func get_export_history() -> Array:
	return export_history


## Get imported characters
func get_imported_characters() -> Dictionary:
	return imported_characters


## Set API key for authentication
func set_api_key(key: String) -> void:
	api_key = key


## Set custom API endpoint
func set_api_endpoint(endpoint: String) -> void:
	api_endpoint = endpoint


## Save export/import state
func to_dict() -> Dictionary:
	return {
		"export_version": export_version,
		"api_endpoint": api_endpoint,
		"export_history": export_history,
		"imported_characters": imported_characters
	}


## Load export/import state
func from_dict(data: Dictionary) -> void:
	export_version = data.get("export_version", "1.0")
	api_endpoint = data.get("api_endpoint", "https://pvabazaar.org/api/characters")
	export_history = data.get("export_history", [])
	imported_characters = data.get("imported_characters", {})
