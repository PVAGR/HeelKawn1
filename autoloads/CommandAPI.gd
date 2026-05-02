extends Node
## Phase 5: Command API - Unified interface for human and AI agents
## Provides the same validation and execution paths for both player UI and AI agents

enum CommandType {
	MOVE_PAWN = 0,
	CLAIM_JOB = 1,
	DESIGNATE_TILE = 2,
	INSPECT_TILE = 3,
	PERFORM_PRESENCE = 4,
	TOGGLE_DRAFT_MODE = 5,
	REQUEST_INCARNATION = 6,
	RETURN_TO_SPECTATOR = 7,
	SHARE_GOSSIP = 8,
	SET_GOAL = 9,
	RECORD_MEMORY = 10,
	TRIGGER_STORY_BEAT = 11,
	CHANGE_CAREER_TRACK = 12,
}

## Command structure for unified processing
class Command:
	extends RefCounted
	var type: int
	var actor_id: int  # pawn_id for pawn commands, -1 for spectator commands
	var target_data: Dictionary
	var metadata: Dictionary = {}
	
	func _init(cmd_type: int, actor: int, target: Dictionary):
		type = cmd_type
		actor_id = actor
		target_data = target

## Execute a command with the same validation as UI actions
static func execute_command(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	# Validate command structure
	if command == null:
		result.error = "Invalid command: null"
		return result
	
	match command.type:
		CommandType.MOVE_PAWN:
			result = _execute_move_pawn(command)
		CommandType.CLAIM_JOB:
			result = _execute_claim_job(command)
		CommandType.DESIGNATE_TILE:
			result = _execute_designate_tile(command)
		CommandType.INSPECT_TILE:
			result = _execute_inspect_tile(command)
		CommandType.PERFORM_PRESENCE:
			result = _execute_perform_presence(command)
		CommandType.TOGGLE_DRAFT_MODE:
			result = _execute_toggle_draft_mode(command)
		CommandType.REQUEST_INCARNATION:
			result = _execute_request_incarnation(command)
		CommandType.RETURN_TO_SPECTATOR:
			result = _execute_return_to_spectator(command)
		CommandType.SHARE_GOSSIP:
			result = _execute_share_gossip(command)
		CommandType.SET_GOAL:
			result = _execute_set_goal(command)
		CommandType.RECORD_MEMORY:
			result = _execute_record_memory(command)
		CommandType.TRIGGER_STORY_BEAT:
			result = _execute_trigger_story_beat(command)
		CommandType.CHANGE_CAREER_TRACK:
			result = _execute_change_career_track(command)
		_:
			result.error = "Unknown command type: %d" % command.type
	
	return result

## Get available commands for a specific actor (pawn or spectator)
static func get_available_commands(actor_id: int) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	
	if actor_id == -1:  # Spectator mode
		commands.append({
			"type": CommandType.REQUEST_INCARNATION,
			"name": "incarnate",
			"description": "Enter the world as a pawn",
			"requires_target": true
		})
		commands.append({
			"type": CommandType.INSPECT_TILE,
			"name": "inspect",
			"description": "Inspect a tile for information",
			"requires_target": true
		})
	else:  # Incarnated pawn
		commands.append({
			"type": CommandType.MOVE_PAWN,
			"name": "move",
			"description": "Move to a specific tile",
			"requires_target": true
		})
		commands.append({
			"type": CommandType.CLAIM_JOB,
			"name": "claim_job",
			"description": "Claim an available job",
			"requires_target": true
		})
		commands.append({
			"type": CommandType.PERFORM_PRESENCE,
			"name": "presence",
			"description": "Perform presence action at current location",
			"requires_target": false
		})
		commands.append({
			"type": CommandType.TOGGLE_DRAFT_MODE,
			"name": "draft",
			"description": "Toggle draft/combat mode",
			"requires_target": false
		})
		commands.append({
			"type": CommandType.INSPECT_TILE,
			"name": "inspect",
			"description": "Inspect a tile for information",
			"requires_target": true
		})
		commands.append({
			"type": CommandType.RETURN_TO_SPECTATOR,
			"name": "return",
			"description": "Return to spectator mode",
			"requires_target": false
		})
	
	return commands

## Validate if a command can be executed (without executing it)
static func validate_command(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	if command == null:
		result.error = "Invalid command: null"
		return result
	
	# Check if actor exists and is valid
	if command.actor_id != -1:
		var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
		if pawn_obs.has("error"):
			result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
			return result
		
		# Check if pawn is alive and capable
		if pawn_obs.get("health_percentage", 0) <= 0:
			result.error = "Actor is not alive"
			return result
	
	match command.type:
		CommandType.MOVE_PAWN:
			result = _validate_move_pawn(command)
		CommandType.CLAIM_JOB:
			result = _validate_claim_job(command)
		CommandType.DESIGNATE_TILE:
			result = _validate_designate_tile(command)
		CommandType.INSPECT_TILE:
			result = _validate_inspect_tile(command)
		CommandType.PERFORM_PRESENCE:
			result = _validate_perform_presence(command)
		CommandType.TOGGLE_DRAFT_MODE:
			result = _validate_toggle_draft_mode(command)
		CommandType.REQUEST_INCARNATION:
			result = _validate_request_incarnation(command)
		CommandType.RETURN_TO_SPECTATOR:
			result = _validate_return_to_spectator(command)
		_:
			result.error = "Unknown command type: %d" % command.type
	
	return result

# === Private command execution methods ===

static func _execute_move_pawn(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	var target_tile: Vector2i = Vector2i(
		command.target_data.get("x", -1),
		command.target_data.get("y", -1)
	)
	
	if target_tile.x < 0:
		result.error = "Invalid target tile"
		return result
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		result.error = "PawnSpawner not available"
		return result
	
	# Find the pawn
	var target_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == command.actor_id:
			target_pawn = p
			break
	
	if target_pawn == null:
		result.error = "Pawn not found"
		return result
	
	# Execute movement through Pawn's public pathing surface.
	if target_pawn.has_method("draft_goto"):
		target_pawn.draft_goto(target_tile)
		result.success = true
		result.data = {"target_tile": {"x": target_tile.x, "y": target_tile.y}}
	else:
		result.error = "Move method not available"
	
	return result

static func _execute_claim_job(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	var job_id: int = command.target_data.get("job_id", -1)
	if job_id < 0:
		result.error = "Invalid job ID"
		return result
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		result.error = "PawnSpawner not available"
		return result
	
	# Find the pawn
	var target_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == command.actor_id:
			target_pawn = p
			break
	
	if target_pawn == null:
		result.error = "Pawn not found"
		return result
	
	var job_manager = JobManager
	if job_manager == null:
		result.error = "JobManager not available"
		return result
	
	var target_job: Job = job_manager.claim_by_id_for(target_pawn, job_id) if job_manager.has_method("claim_by_id_for") else null
	if target_job == null:
		result.error = "Job not found, already claimed, or pawn is not eligible"
		return result
	
	result.success = true
	result.data = {"job_id": job_id, "job_type": target_job.type}
	
	return result

static func _execute_inspect_tile(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var tile_x: int = command.target_data.get("x", -1)
	var tile_y: int = command.target_data.get("y", -1)
	
	if tile_x < 0:
		result.error = "Invalid tile coordinates"
		return result
	
	# Get observation data
	var obs: Dictionary = ObservationAPI.observe_tile(tile_x, tile_y)
	if obs.has("error"):
		result.error = "Observation failed: %s" % obs.get("error", "Unknown")
		return result
	
	# Record inspect event if this is from a pawn
	if command.actor_id != -1:
		var main: Node2D = Engine.get_main_loop().current_scene as Node2D
		if main != null and main.has_method("_pawn_inspect_tile"):
			var success: bool = main._pawn_inspect_tile(command.actor_id, Vector2i(tile_x, tile_y))
			if not success:
				result.error = "Failed to record inspect event"
				return result
	
	result.success = true
	result.data = obs
	
	return result

static func _execute_perform_presence(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		result.error = "PawnSpawner not available"
		return result
	
	# Find the pawn
	var target_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == command.actor_id:
			target_pawn = p
			break
	
	if target_pawn == null:
		result.error = "Pawn not found"
		return result
	
	# Execute presence action
	if target_pawn.has_method("_perform_presence_action"):
		target_pawn._perform_presence_action()
		result.success = true
		result.data = {"pawn_id": command.actor_id}
	else:
		result.error = "Presence action method not available"
	
	return result

static func _execute_toggle_draft_mode(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	var spawner: PawnSpawner = main.get("_pawn_spawner") as PawnSpawner
	if spawner == null:
		result.error = "PawnSpawner not available"
		return result
	
	# Find the pawn
	var target_pawn: Pawn = null
	for p in spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == command.actor_id:
			target_pawn = p
			break
	
	if target_pawn == null:
		result.error = "Pawn not found"
		return result
	
	# Execute draft mode toggle
	if main.has_method("_toggle_draft_mode"):
		main._toggle_draft_mode()
		result.success = true
		result.data = {"pawn_id": command.actor_id, "draft_mode": main._is_draft_mode if main.has_method("_is_draft_mode") else false}
	else:
		result.error = "Draft mode method not available"
	
	return result

static func _execute_request_incarnation(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	if command.metadata.get("source", "") == "ai_agent":
		result.error = "AI agent incarnation is disabled until NPC ownership is separate from the player channel"
		return result
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	# Get pawn candidates
	var candidates: Array = main._incarnation_candidates_snapshot() if main.has_method("_incarnation_candidates_snapshot") else []
	if candidates.is_empty():
		result.error = "No incarnation candidates available"
		return result
	
	var target_pawn_id: int = command.target_data.get("pawn_id", -1)
	if target_pawn_id < 0:
		result.error = "Invalid pawn ID for incarnation"
		return result
	
	# Execute incarnation
	if main.has_method("_on_incarnation_entry_confirmed"):
		main._on_incarnation_entry_confirmed(target_pawn_id)
		result.success = true
		result.data = {"pawn_id": target_pawn_id}
	else:
		result.error = "Incarnation method not available"
	
	return result

static func _execute_return_to_spectator(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	# Execute return to spectator
	if main.has_method("request_spectator_return"):
		main.request_spectator_return()
		result.success = true
		result.data = {"previous_pawn_id": command.actor_id}
	else:
		result.error = "Return to spectator method not available"
	
	return result

static func _execute_designate_tile(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	
	# Designation is currently disabled for AI agents (player-only feature)
	result.error = "Tile designation is player-only feature"
	return result

# === Private validation methods ===

static func _validate_move_pawn(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	var target_tile: Vector2i = Vector2i(
		command.target_data.get("x", -1),
		command.target_data.get("y", -1)
	)
	
	if target_tile.x < 0:
		result.error = "Invalid target tile"
		return result
	
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	# Check if pawn can move (not busy with critical actions)
	var state: String = pawn_obs.get("state", "unknown")
	if state == "SLEEPING" or state == "EATING":
		result.error = "Pawn cannot move while %s" % state.to_lower()
		return result
	
	# Check if target tile is reachable
	var tile_obs: Dictionary = ObservationAPI.observe_tile(target_tile.x, target_tile.y)
	if tile_obs.has("error"):
		result.error = "Cannot observe target tile: %s" % tile_obs.get("error", "Unknown")
		return result
	
	if not tile_obs.get("walkable", false):
		result.error = "Target tile is not walkable"
		return result
	
	result.valid = true
	return result

static func _validate_claim_job(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	var job_id: int = command.target_data.get("job_id", -1)
	if job_id < 0:
		result.error = "Invalid job ID"
		return result
	
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	# Check if pawn can claim jobs (not already working)
	var state: String = pawn_obs.get("state", "unknown")
	if state == "WORKING" or state == "WALKING_TO_JOB":
		result.error = "Pawn already has a job"
		return result
	
	result.valid = true
	return result

static func _validate_inspect_tile(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	var tile_x: int = command.target_data.get("x", -1)
	var tile_y: int = command.target_data.get("y", -1)
	
	if tile_x < 0:
		result.error = "Invalid tile coordinates"
		return result
	
	var tile_obs: Dictionary = ObservationAPI.observe_tile(tile_x, tile_y)
	if tile_obs.has("error"):
		result.error = "Cannot observe tile: %s" % tile_obs.get("error", "Unknown")
		return result
	
	result.valid = true
	return result

static func _validate_perform_presence(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	# Check if pawn can perform presence (not busy)
	var state: String = pawn_obs.get("state", "unknown")
	if state == "SLEEPING" or state == "EATING" or state == "HAULING":
		result.error = "Pawn cannot perform presence while %s" % state.to_lower()
		return result
	
	result.valid = true
	return result

static func _validate_toggle_draft_mode(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	result.valid = true
	return result

static func _validate_request_incarnation(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	if command.metadata.get("source", "") == "ai_agent":
		result.error = "AI agent incarnation is disabled until NPC ownership is separate from the player channel"
		return result
	
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	
	# Check if already incarnated
	var player_pawn: Pawn = main.get_player_pawn() if main.has_method("get_player_pawn") else null
	if player_pawn != null and is_instance_valid(player_pawn):
		result.error = "Already incarnated"
		return result
	
	var target_pawn_id: int = command.target_data.get("pawn_id", -1)
	if target_pawn_id < 0:
		result.error = "Invalid pawn ID for incarnation"
		return result
	
	# Check if pawn exists and is alive
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(target_pawn_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe target pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	if pawn_obs.get("health_percentage", 0) <= 0:
		result.error = "Target pawn is not alive"
		return result
	
	result.valid = true
	return result

static func _validate_return_to_spectator(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	
	if command.actor_id == -1:
		result.error = "Not currently incarnated"
		return result
	
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Cannot observe pawn: %s" % pawn_obs.get("error", "Unknown")
		return result
	
	result.valid = true
	return result

static func _validate_designate_tile(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}

	# Designation is player-only
	result.error = "Tile designation is player-only feature"
	return result

# === Phase 4: New Command Execution Methods ===

static func _execute_share_gossip(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Pawn not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	var target_id: int = command.target_data.get("target_pawn_id", -1)
	if target_id < 0:
		result.error = "No target pawn specified for gossip"
		return result
	# Get pawn node to access gossip system
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	var pawn: Pawn = null
	if main.has_method("get_pawn_by_id"):
		pawn = main.get_pawn_by_id(command.actor_id)
	if pawn == null or not is_instance_valid(pawn):
		result.error = "Pawn instance not found"
		return result
	if "_gossip" in pawn and "share_gossip" in pawn:
		var shared: int = pawn.share_gossip(target_id)
		result.success = true
		result.data["shared_count"] = shared
	else:
		result.error = "Pawn gossip system not initialized"
	return result


static func _execute_set_goal(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	var pawn: Pawn = null
	if main.has_method("get_pawn_by_id"):
		pawn = main.get_pawn_by_id(command.actor_id)
	if pawn == null or not is_instance_valid(pawn):
		result.error = "Pawn instance not found"
		return result
	var goal_key: String = command.target_data.get("goal_key", "")
	var scope: int = command.target_data.get("scope", GoalEngine.GoalScope.TODAY)
	if goal_key.is_empty():
		result.error = "No goal key specified"
		return result
	if pawn._goal_engine != null and "add_goal" in pawn._goal_engine:
		pawn._goal_engine.add_goal(goal_key, scope, "AI set goal", [], 0.5)
		result.success = true
		result.data["goal_key"] = goal_key
	else:
		result.error = "Goal engine not initialized for pawn"
	return result


static func _execute_record_memory(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	var pawn: Pawn = null
	if main.has_method("get_pawn_by_id"):
		pawn = main.get_pawn_by_id(command.actor_id)
	if pawn == null or not is_instance_valid(pawn):
		result.error = "Pawn instance not found"
		return result
	if pawn._long_term_memory != null and "add_memory" in pawn._long_term_memory:
		var mem_type: int = command.target_data.get("memory_type", LongTermMemory.MemoryType.EVENT)
		var summary: String = command.target_data.get("summary", "command_memory")
		var importance: float = command.target_data.get("importance", 0.5)
		var mem_id: int = pawn._long_term_memory.add_memory(mem_type, summary, "neutral", importance, Vector2i.ZERO, [])
		result.success = true
		result.data["memory_id"] = mem_id
	else:
		result.error = "Long-term memory not initialized for pawn"
	return result


static func _execute_trigger_story_beat(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	var pawn: Pawn = null
	if main.has_method("get_pawn_by_id"):
		pawn = main.get_pawn_by_id(command.actor_id)
	if pawn == null or not is_instance_valid(pawn):
		result.error = "Pawn instance not found"
		return result
	if pawn._dramatic_engine != null and "attempt_story_beat" in pawn._dramatic_engine:
		var world_state: Dictionary = pawn._build_world_state_for_ai() if "get_world_state_for_ai" in pawn else {}
		var beat: Dictionary = pawn._dramatic_engine.attempt_story_beat(pawn.data, world_state)
		result.success = not beat.is_empty()
		result.data["beat"] = beat
	else:
		result.error = "Dramatic event engine not initialized for pawn"
	return result


static func _execute_change_career_track(command: Command) -> Dictionary:
	var result: Dictionary = {"success": false, "error": "", "data": {}}
	var main: Node2D = Engine.get_main_loop().current_scene as Node2D
	if main == null:
		result.error = "Main scene not available"
		return result
	var pawn: Pawn = null
	if main.has_method("get_pawn_by_id"):
		pawn = main.get_pawn_by_id(command.actor_id)
	if pawn == null or not is_instance_valid(pawn):
		result.error = "Pawn instance not found"
		return result
	if pawn._career != null and "set_career" in pawn._career:
		var track: int = command.target_data.get("career_track", CareerXP.CareerTrack.NONE)
		var master_id: int = command.target_data.get("master_id", -1)
		pawn._career.set_career(track, master_id)
		result.success = true
		result.data["track"] = track
	else:
		result.error = "Career system not initialized for pawn"
	return result


# === Validation methods for new commands ===

static func _validate_share_gossip(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	if command.target_data.get("target_pawn_id", -1) < 0:
		result.error = "No target pawn specified"
		return result
	result.valid = true
	return result


static func _validate_set_goal(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	if command.target_data.get("goal_key", "").is_empty():
		result.error = "No goal key specified"
		return result
	result.valid = true
	return result


static func _validate_record_memory(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	result.valid = true
	return result


static func _validate_trigger_story_beat(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	result.valid = true
	return result


static func _validate_change_career_track(command: Command) -> Dictionary:
	var result: Dictionary = {"valid": false, "error": "", "requirements": {}}
	var pawn_obs: Dictionary = ObservationAPI.observe_pawn(command.actor_id)
	if pawn_obs.has("error"):
		result.error = "Actor not found: %s" % pawn_obs.get("error", "Unknown")
		return result
	result.valid = true
	return result
