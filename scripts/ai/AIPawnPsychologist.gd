extends RefCounted
class_name AIPawnPsychologist

## Layer 2: RimWorld Spirit - Pawn Psychology AI
## Manages individual pawn needs, moods, social dynamics, psychological states
##
## Reads from: PawnData, GrudgeManager, GossipManager
## Writes to: Pawn mood modifiers, social desires, fear states

var _llm_client: LLMClient = null
var _grudge_manager: Node = null
var _gossip_manager: Node = null
var _initialized: bool = false


func initialize(deps: Dictionary) -> void:
	_llm_client = deps.get("llm_client")
	_grudge_manager = deps.get("grudge_manager")
	_gossip_manager = deps.get("gossip_manager")
	_initialized = true


func evaluate(context: Dictionary) -> Dictionary:
	if not _initialized:
		return {"error": "not_initialized"}
	
	var sample_pawns: Array = context.get("sample_pawns", [])
	
	if sample_pawns.is_empty():
		return {"psych_profiles": 0, "reason": "no_pawns_sampled"}
	
	# Generate psychological profiles for sample pawns
	var profiles: Array[Dictionary] = []
	
	for pawn_data in sample_pawns:
		var profile: Dictionary = await _generate_pawn_psychology(pawn_data, context)
		if not profile.is_empty():
			profiles.append(profile)
			# Apply mood modifier to pawn
			_apply_mood_modifier(pawn_data, profile)
	
	return {
		"psych_profiles": profiles.size(),
		"profiles": profiles,
		"action": "psychological_assessment"
	}


func _generate_pawn_psychology(pawn_data: Dictionary, context: Dictionary) -> Dictionary:
	var pawn_id: int = pawn_data.get("id", 0)
	var pawn_name: String = pawn_data.get("name", "Unknown")
	
	# Build psychological context
	var physical_state: String = _build_physical_state(pawn_data)
	var social_state: String = _build_social_state(pawn_id)
	var recent_events: Array = _get_pawn_recent_events(pawn_id)
	
	# Build prompt
	var prompt: String = """
Analyze this pawn's psychological state:

PAWN: {name} (ID: {id})

PHYSICAL STATE:
{physical}

SOCIAL STATE:
{social}

RECENT EVENTS:
{events}

TRAITS: {traits}

What is this pawn's emotional state? What do they want most right now?
Consider: loneliness, ambition, fear, loyalty, grudges, social needs.

RimWorld style: "The pawn weighs personal happiness against survival needs."

RESPOND JSON:
{{
  "mood_modifier": -10,
  "desire": "socialize",
  "fear": "wolf_attack",
  "thought": "I haven't spoken to anyone in days...",
  "stress_level": "medium",
  "coping_mechanism": "work_harder"
}}
""".format({
		"name": pawn_name,
		"id": pawn_id,
		"physical": physical_state,
		"social": social_state,
		"events": "\n".join(recent_events) if recent_events else "None recent",
		"traits": pawn_data.get("traits", "none")
	})
	
	# Request from LLM
	var response: Dictionary = await _llm_client.request_json(
		prompt,
		{"pawn_id": pawn_id, "pawn_name": pawn_name},
		{},
		"Respond with valid JSON only. No markdown, no explanations."
	)
	
	return response


func _build_physical_state(pawn_data: Dictionary) -> String:
	var lines: PackedStringArray = []
	
	# Needs
	lines.append("- Hunger: {hunger}%".format({"hunger": pawn_data.get("hunger", 100)}))
	lines.append("- Rest: {rest}%".format({"rest": pawn_data.get("rest", 100)}))
	lines.append("- Health: {health}%".format({"health": pawn_data.get("health", 100)}))
	lines.append("- Mood: {mood}%".format({"mood": pawn_data.get("mood", 100)}))
	
	# Current state
	lines.append("- Current state: {state}".format({"state": pawn_data.get("state", "unknown")}))
	lines.append("- Profession: {prof}".format({"prof": pawn_data.get("profession", "none")}))
	
	# Skills
	var skills: Dictionary = pawn_data.get("skills", {})
	for skill in skills:
		lines.append("- {skill}: {level}".format({"skill": skill, "level": skills[skill]}))
	
	return "\n".join(lines)


func _build_social_state(pawn_id: int) -> String:
	var lines: PackedStringArray = []
	
	# Get grudges
	var grudge_count: int = 0
	if _grudge_manager != null and _grudge_manager.has_method("get_grudges_for_pawn"):
		var grudges: Array = _grudge_manager.get_grudges_for_pawn(pawn_id)
		grudge_count = grudges.size()
		if grudges.size() > 0:
			lines.append("- Active grudges: {count}".format({"count": grudges.size()}))
	
	# Get gossip
	var gossip_count: int = 0
	if _gossip_manager != null and _gossip_manager.has_method("get_gossip_about_pawn"):
		var gossip: Array = _gossip_manager.get_gossip_about_pawn(pawn_id)
		gossip_count = gossip.size()
	
	# Social summary
	lines.append("- Total grudges against pawn: {grudges}".format({"grudges": grudge_count}))
	lines.append("- Gossip items about pawn: {gossip}".format({"gossip": gossip_count}))
	
	# Friendship estimate (would need social network data)
	lines.append("- Estimated friends: 2-3")
	
	return "\n".join(lines)


func _get_pawn_recent_events(pawn_id: int) -> Array:
	var events: Array[String] = []
	
	# Would query WorldMemory for pawn-specific events
	# For now, return placeholder
	
	if randi() % 2 == 0:
		events.append("Recently completed a work job successfully")
	if randi() % 3 == 0:
		events.append("Had a social interaction with another pawn")
	
	return events


func _apply_mood_modifier(pawn_data: Dictionary, profile: Dictionary) -> void:
	var mood_modifier: int = profile.get("mood_modifier", 0)
	
	# Would apply to actual pawn via PawnData
	# For now, just log
	
	if mood_modifier != 0:
		print("[AIPawnPsychologist] Applied mood modifier {mod} to {name}".format({
			"mod": mood_modifier,
			"name": pawn_data.get("name", "Unknown")
		}))


## Get psychologist statistics
func get_stats() -> Dictionary:
	return {
		"initialized": _initialized,
		"profiles_generated": 0,
		"last_update_tick": -1
	}
