extends Node
## HeelKawnianMind — Deterministic mind snapshot engine
##
## Computes a readable mind snapshot for any pawn by composing data from
## existing systems (HeelKawnianData, PawnConsciousness, KinshipSystem,
## GrudgeManager, GossipManager, WorldMemory, WorldMeaning, CulturalMemory,
## HeelKawnianManager). Every line in the snapshot comes from actual state —
## no invented text, no random flavor.
##
## Architecture: facts first, meaning second, UI last.
## WorldMemory records what objectively happened.
## WorldMeaning derives interpretation from those facts.
## HeelKawnianMind composes what the pawn "thinks" from those layers.
## The inspect UI only displays what the simulation actually knows.

## Cache: pawn_id -> { "tick": int, "snapshot": Dictionary }
var _cache: Dictionary = {}
const CACHE_TTL: int = 10  # Re-compute every 10 ticks


# ==================== DETERMINISTIC HASH ====================

## FNV-1a-inspired stable hash. Deterministic: same inputs always produce
## same output. No reliance on global RNG state.
static func stable_hash(a: int, b: int, c: int) -> int:
	var h: int = 2166136261  # FNV offset basis
	h = h ^ (a & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((a >> 8) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((a >> 16) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((a >> 24) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ (b & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((b >> 8) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((b >> 16) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((b >> 24) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ (c & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	h = h ^ ((c >> 8) & 0xFF)
	h = (h * 16777619) & 0xFFFFFFFF
	return h


## Deterministic float in [0, 1) from seed + two ints.
static func stable_randf(seed_a: int, seed_b: int, seed_c: int) -> float:
	return float(absi(stable_hash(seed_a, seed_b, seed_c)) % 10000) / 10000.0


# ==================== PUBLIC API ====================

## Compute a full mind snapshot for a pawn. Returns a Dictionary with
## current_thought, pursuit, body_pressure, emotional_pressure, likes,
## dislikes, family, relationships, memory_summary, culture_summary,
## work_intent, reason, and raw data.
func compute_mind_snapshot(pawn: Node) -> Dictionary:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return {}
	var data: HeelKawnianData = pawn.data
	var pawn_id: int = int(data.id)
	var tick: int = GameManager.tick_count if GameManager != null else 0

	# Check cache
	var cached: Dictionary = _cache.get(pawn_id, {})
	if not cached.is_empty() and int(cached.get("tick", -1)) >= tick - CACHE_TTL:
		return cached.get("snapshot", {})

	# Layer 1: Body
	var body: Dictionary = _compute_body(data, pawn)

	# Layer 2: Memory
	var memory: Dictionary = _compute_memory(pawn_id, data)

	# Layer 3: Relationships
	var relationships: Dictionary = _compute_relationships(pawn_id, data)

	# Layer 4: Desire / Pursuit
	var desire: Dictionary = _compute_desire(data, pawn, body, memory)

	# Layer 5: Culture
	var culture: Dictionary = _compute_culture(data)

	# Layer 6: Meaning
	var meaning: Dictionary = _compute_meaning(data)

	# Layer 7: Thought composition
	var thought: Dictionary = _compose_thought(body, memory, desire, meaning, data)

	# Layer 8: Work intent
	var work: Dictionary = _compute_work_intent(pawn, data)

	# Layer 9: Knowledge
	var knowledge: Dictionary = _compute_knowledge(pawn_id, data)

	# Layer 10: War/Conflict memory
	var war: Dictionary = _compute_war_memory(pawn_id, data)

	# Layer 11: Settlement history
	var settlement: Dictionary = _compute_settlement_history(data)

	# Compose snapshot
	var snapshot: Dictionary = {
		"current_thought": thought.get("text", ""),
		"pursuit": desire.get("pursuit", ""),
		"body_pressure": body.get("summary", ""),
		"emotional_pressure": body.get("emotional", ""),
		"likes": _format_likes(data),
		"dislikes": _format_dislikes(data),
		"family": relationships.get("family", ""),
		"relationships": relationships.get("summary", ""),
		"memory_summary": memory.get("summary", ""),
		"culture_summary": culture.get("summary", ""),
		"work_intent": work.get("text", ""),
		"reason": thought.get("reason", ""),
		"knowledge_summary": knowledge.get("summary", ""),
		"knowledge_count": int(knowledge.get("count", 0)),
		"knowledge_at_risk": knowledge.get("at_risk", false),
		"war_memory": war.get("summary", ""),
		"conflict_count": int(war.get("conflict_count", 0)),
		"settlement_history": settlement.get("summary", ""),
		"raw": {
			"hunger": float(data.hunger),
			"rest": float(data.rest),
			"mood": float(data.mood),
			"health": float(data.health),
			"trauma": float(memory.get("trauma", 0.0)),
			"awareness": int(memory.get("awareness", 0)),
			"beliefs": memory.get("beliefs", []),
			"desires": memory.get("desires", []),
			"grudge_count": int(relationships.get("grudge_count", 0)),
			"reputation": float(relationships.get("reputation", 0.0)),
			"knowledge_count": int(knowledge.get("count", 0)),
			"conflict_count": int(war.get("conflict_count", 0)),
		},
	}

	# Cache
	_cache[pawn_id] = { "tick": tick, "snapshot": snapshot }
	return snapshot


## Clear cache (for world reroll)
func clear() -> void:
	_cache.clear()


# ==================== LAYER 1: BODY ====================

func _compute_body(data: HeelKawnianData, pawn: Node) -> Dictionary:
	var pressures: PackedStringArray = []
	var emotional: PackedStringArray = []

	# Hunger
	if data.hunger < 20:
		pressures.append("Starving")
		emotional.append("desperate")
	elif data.hunger < 40:
		pressures.append("Hungry")
		emotional.append("anxious")
	elif data.hunger < 60:
		pressures.append("Peckish")

	# Rest
	if data.rest < 20:
		pressures.append("Exhausted")
		emotional.append("foggy")
	elif data.rest < 40:
		pressures.append("Tired")
		emotional.append("drowsy")
	elif data.rest < 60:
		pressures.append("Drowsy")

	# Mood
	if data.mood < 20:
		emotional.append("despondent")
	elif data.mood < 40:
		emotional.append("gloomy")
	elif data.mood > 80:
		emotional.append("content")

	# Health
	if data.health < 30:
		pressures.append("Injured")
		emotional.append("fearful")
	elif data.health < 60:
		pressures.append("Wounded")

	# Warmth — check ambient temperature
	var warmth: float = _estimate_warmth(data, pawn)
	if warmth < -5.0:
		pressures.append("Freezing")
		emotional.append("panicked")
	elif warmth < 0.0:
		pressures.append("Cold")
		emotional.append("uncomfortable")

	# If no pressures, report good state
	if pressures.is_empty():
		pressures.append("Fed")
		if data.rest >= 60:
			pressures.append("rested")
		if warmth >= 5.0:
			pressures.append("warm")

	if emotional.is_empty():
		emotional.append("calm")

	return {
		"summary": ", ".join(pressures),
		"emotional": ", ".join(emotional),
		"dominant_need": _dominant_need(data),
		"warmth": warmth,
	}


func _estimate_warmth(data: HeelKawnianData, pawn: Node) -> float:
	# Approximate warmth from pawn's current tile
	# (Full warmth calc is in HeelKawnian.gd — this is a simplified version for mind)
	if pawn.has_method("_hearth_proxy_warmth_bonus"):
		var bonus: float = pawn.call("_hearth_proxy_warmth_bonus", data.tile_pos)
		return bonus
	return 0.0


func _dominant_need(data: HeelKawnianData) -> String:
	var min_val: float = 100.0
	var dominant: String = "none"
	if data.hunger < min_val:
		min_val = data.hunger
		dominant = "hunger"
	if data.rest < min_val:
		min_val = data.rest
		dominant = "rest"
	if data.health < min_val:
		min_val = data.health
		dominant = "health"
	if data.mood < min_val:
		min_val = data.mood
		dominant = "mood"
	return dominant


# ==================== LAYER 2: MEMORY ====================

func _compute_memory(pawn_id: int, data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"summary": "No significant memories yet.",
		"trauma": 0.0,
		"awareness": 0,
		"beliefs": [],
		"desires": [],
	}

	if PawnConsciousness == null:
		return result

	var consciousness: Dictionary = PawnConsciousness.get_consciousness(pawn_id)
	if consciousness.is_empty():
		return result

	result.trauma = float(consciousness.get("trauma_level", 0.0))
	result.awareness = int(consciousness.get("self_awareness", 0))
	result.beliefs = consciousness.get("core_beliefs", [])
	result.desires = consciousness.get("subconscious_desires", [])

	# Compose memory summary from top memories
	var memories: Array = PawnConsciousness.get_memories(pawn_id, "", 3)
	if memories.is_empty():
		return result

	var summaries: PackedStringArray = []
	for m in memories:
		if not m is Dictionary:
			continue
		var desc: String = str(m.get("description", ""))
		if desc.is_empty():
			var event_type: String = str(m.get("event_type", "event"))
			var emotion: float = float(m.get("emotion", 0.0))
			if emotion < -50:
				summaries.append("Traumatic %s" % event_type.to_lower())
			elif emotion > 50:
				summaries.append("Joyful %s" % event_type.to_lower())
			else:
				summaries.append("Remembers %s" % event_type.to_lower())
		else:
			summaries.append(desc)

	if not summaries.is_empty():
		result.summary = "; ".join(summaries)

	# Trauma adds to emotional context
	if result.trauma >= 75:
		result.summary += " Carries deep scars."
	elif result.trauma >= 50:
		result.summary += " Still haunted by the past."

	return result


# ==================== LAYER 3: RELATIONSHIPS ====================

func _compute_relationships(pawn_id: int, data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"family": "No family recorded.",
		"summary": "No strong bonds recorded yet.",
		"grudge_count": 0,
		"reputation": 0.0,
	}

	# Family from KinshipSystem
	if KinshipSystem != null:
		var family_parts: PackedStringArray = []
		var parents: Array = KinshipSystem.get_lineage_parents(pawn_id)
		if not parents.is_empty():
			family_parts.append("Has living parents")
		var children: Array = KinshipSystem.get_lineage_children(pawn_id)
		if not children.is_empty():
			family_parts.append("Parent of %d" % children.size())
		var siblings: Array = KinshipSystem.get_lineage_siblings(pawn_id)
		if not siblings.is_empty():
			family_parts.append("%d siblings" % siblings.size())

		# Clan/nation
		var kinship: Array = KinshipSystem.get_kinship(pawn_id)
		var clan_id: int = -1
		for k in kinship:
			if k is Dictionary:
				clan_id = int(k.get("clan_id", -1))
				break
		if clan_id >= 0:
			family_parts.append("Clan %d" % clan_id)

		if not family_parts.is_empty():
			result.family = ", ".join(family_parts)

	# Grudges and trust from SocialManager
	var grudges: Array = SocialManager.get_grudges_held_by(pawn_id)
	result.grudge_count = grudges.size()

	var rel_parts: PackedStringArray = []
	if not grudges.is_empty():
		for g in grudges:
			if not g is Dictionary:
				continue
			var target_id: int = int(g.get("target_id", -1))
			var intensity: float = float(g.get("intensity", 0.0))
			var target_name: String = _pawn_name_for_id(target_id)
			if intensity >= 0.7:
				rel_parts.append("Hates %s" % target_name)
			elif intensity >= 0.4:
				rel_parts.append("Distrusts %s" % target_name)
			else:
				rel_parts.append("Wary of %s" % target_name)

	# Also check who trusts this pawn
	var grudges_against: Array = SocialManager.get_grudges_against(pawn_id)
	if not grudges_against.is_empty():
		rel_parts.append("Disliked by %d others" % grudges_against.size())

	if not rel_parts.is_empty():
		result.summary = ", ".join(rel_parts)
	elif result.grudge_count == 0:
		result.summary = "No conflicts recorded."

	# Reputation from SocialManager
	result.reputation = SocialManager.get_reputation_for(pawn_id)
	var rep_label: String = SocialManager.get_reputation_label(pawn_id)
	if rep_label != "unknown" and not rep_label.is_empty():
		if result.summary == "No strong bonds recorded yet.":
			result.summary = "Reputation: %s" % rep_label.to_lower()
		else:
			result.summary += "; reputation: %s" % rep_label.to_lower()

	return result


# ==================== LAYER 4: DESIRE / PURSUIT ====================

func _compute_desire(data: HeelKawnianData, pawn: Node, body: Dictionary, memory: Dictionary) -> Dictionary:
	var pursuit: String = "Seeking purpose"
	var reason: String = ""

	# Priority: survival > shelter > community > knowledge > growth
	var dominant: String = body.get("dominant_need", "none")

	# Survival pursuits
	if dominant == "hunger":
		pursuit = "Find food"
		reason = "Hunger (%.0f) is the most pressing need" % data.hunger
	elif dominant == "rest":
		pursuit = "Rest"
		reason = "Exhaustion (%.0f) demands sleep" % data.rest
	elif dominant == "health":
		pursuit = "Seek healing"
		reason = "Health (%.0f) is dangerously low" % data.health
	elif dominant == "mood":
		pursuit = "Seek comfort"
		reason = "Morale (%.0f) is the lowest need" % data.mood
	else:
		# Not in survival crisis — check work and ambition
		var current_job = pawn.get("_current_job")
		if current_job != null and is_instance_valid(current_job):
			var job_type: int = int(current_job.type)
			pursuit = _pursuit_for_job(job_type)
			reason = "Working on assigned task"
		else:
			# Check development drive from HeelKawnianManager
			if HeelKawnianManager != null:
				var profile: Dictionary = HeelKawnianManager.get_development_profile_for_pawn(pawn)
				if not profile.is_empty():
					var drive: String = str(profile.get("development_drive", ""))
					var next_need: String = str(profile.get("next_need", ""))
					if not drive.is_empty():
						pursuit = _pursuit_for_drive(drive, next_need)
						reason = "Driven by %s" % drive.replace("_", " ")

			# Trauma-driven avoidance
			var trauma: float = float(memory.get("trauma", 0.0))
			if trauma >= 75 and pursuit == "Seeking purpose":
				pursuit = "Avoid danger"
				reason = "Severe trauma makes safety the priority"

	return {
		"pursuit": pursuit,
		"reason": reason,
	}


func _pursuit_for_job(job_type: int) -> String:
	# Map job types to readable pursuits
	var _Job: Object = _job_class()
	if _Job == null:
		return "Working"
	match job_type:
		_Job.Type.FORAGE:
			return "Forage for food"
		_Job.Type.MINE:
			return "Mine for stone"
		_Job.Type.CHOP:
			return "Chop wood"
		_Job.Type.HUNT:
			return "Hunt for meat"
		_Job.Type.BUILD_BED:
			return "Build a bed"
		_Job.Type.BUILD_WALL:
			return "Build walls"
		_Job.Type.BUILD_DOOR:
			return "Build a door"
		_Job.Type.BUILD_FIRE_PIT:
			return "Build a hearth"
		_Job.Type.BUILD_STORAGE_HUT:
			return "Build storage"
		_Job.Type.BUILD_SHELTER:
			return "Build shelter"
		_Job.Type.BUILD_HEARTH:
			return "Build a hearth"
		_Job.Type.BUILD_FARM_WHEAT, _Job.Type.BUILD_FARM_CORN, _Job.Type.BUILD_FARM_VEGETABLES, _Job.Type.BUILD_HERB_GARDEN:
			return "Build a farm"
		_Job.Type.BUILD_WORKSHOP:
			return "Build a workshop"
		_Job.Type.BUILD_APOTHECARY:
			return "Build an apothecary"
		_Job.Type.BUILD_MARKET:
			return "Build a market"
		_Job.Type.BUILD_LIBRARY:
			return "Build a library"
		_Job.Type.BUILD_BARRACKS:
			return "Build barracks"
		_Job.Type.BUILD_GRANARY:
			return "Build a granary"
		_Job.Type.BUILD_CELLAR:
			return "Build a cellar"
		_Job.Type.BUILD_SCHOOL:
			return "Build a school"
		_Job.Type.BUILD_WATCHTOWER:
			return "Build a watchtower"
		_Job.Type.BUILD_BOATYARD:
			return "Build a boatyard"
		_Job.Type.BUILD_DOCK:
			return "Build a dock"
		_Job.Type.BUILD_FISHERMAN_HUT:
			return "Build a fisherman hut"
		_Job.Type.BUILD_LOOM:
			return "Build a loom"
		_Job.Type.BUILD_KILN:
			return "Build a kiln"
		_Job.Type.BUILD_SMELTER:
			return "Build a smelter"
		_Job.Type.BUILD_TRADING_POST:
			return "Build a trading post"
		_Job.Type.BUILD_ROAD:
			return "Build a road"
		_Job.Type.BUILD_MARKER_STONE:
			return "Carve a marker stone"
		_Job.Type.BUILD_SHRINE:
			return "Build a shrine"
		_Job.Type.COOK_MEAT, _Job.Type.COOK_BERRIES, _Job.Type.COOK_FISH:
			return "Cook food"
		_Job.Type.DRY_MEAT:
			return "Preserve meat"
		_Job.Type.PLANT_SEEDS:
			return "Plant crops"
		_Job.Type.HARVEST_CROPS:
			return "Harvest crops"
		_Job.Type.GROW_FOOD:
			return "Tend crops"
		_Job.Type.TEACH_SKILL, _Job.Type.APPRENTICESHIP:
			return "Teach skills"
		_Job.Type.PROTECT:
			return "Guard the settlement"
		_Job.Type.DEFEND:
			return "Defend the settlement"
		_Job.Type.TOOL_MAKING:
			return "Craft tools"
		_Job.Type.CRAFT_KNIFE, _Job.Type.CRAFT_PICK, _Job.Type.CRAFT_SPEAR, _Job.Type.CRAFT_TORCH:
			return "Craft equipment"
		_Job.Type.GATHER_FLINT:
			return "Gather flint"
		_Job.Type.GATHER_STICK:
			return "Gather sticks"
		_Job.Type.MINE_WALL:
			return "Mine a wall"
		_Job.Type.CARVE_GRAVE_MARKER:
			return "Carve a grave marker"
		_Job.Type.CARVE_KNOWLEDGE_STONE:
			return "Carve a knowledge stone"
		_Job.Type.CARVE_LEDGER_STONE:
			return "Carve a ledger stone"
		_Job.Type.PAPER_MAKING:
			return "Make paper"
		_Job.Type.INK_MAKING:
			return "Make ink"
		_Job.Type.BOOK_BINDING:
			return "Bind a book"
		_Job.Type.LEATHER_MAKING:
			return "Work leather"
		_Job.Type.TRADE_HAUL:
			return "Haul trade goods"
		_:
			return "Working"


func _pursuit_for_drive(drive: String, next_need: String) -> String:
	match drive:
		"serve_settlement":
			return "Serve the settlement"
		"seek_knowledge":
			return "Learn and teach"
		"expand_territory":
			return "Expand territory"
		"build_infrastructure":
			return "Build infrastructure"
		"seek_safety":
			return "Find safety"
		"seek_food":
			return "Find food"
		_:
			if not next_need.is_empty():
				return next_need.replace("_", " ").capitalize()
			return "Seek purpose"


# ==================== LAYER 5: CULTURE ====================

func _compute_culture(data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"summary": "No cultural traditions yet.",
	}

	if CulturalMemory == null:
		return result

	var settlement_id: int = _settlement_id_for_pawn(data)
	if settlement_id < 0:
		return result

	var tradition: Dictionary = CulturalMemory.get_tradition(settlement_id)
	if tradition.is_empty():
		return result

	var parts: PackedStringArray = []

	# Traditions
	var tradition_type: String = str(tradition.get("type", ""))
	if not tradition_type.is_empty():
		parts.append("Values %s" % tradition_type.replace("_", " "))

	# Culture at region
	var region_key: int = _region_key_for_tile(data.tile_pos)
	var culture: Dictionary = CulturalMemory.get_culture_at_region(region_key)
	if not culture.is_empty():
		var maturity: float = float(culture.get("maturity", 0.0))
		if maturity > 0.5:
			parts.append("mature culture")
		elif maturity > 0.2:
			parts.append("developing culture")

	if not parts.is_empty():
		result.summary = ", ".join(parts)

	return result


# ==================== LAYER 6: MEANING ====================

func _compute_meaning(data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"place_feeling": "",
		"tags": [],
	}

	if WorldMeaning == null:
		return result

	var region_key: int = _region_key_for_tile(data.tile_pos)
	var tags: PackedStringArray = WorldMeaning.get_region_tags(region_key)
	result.tags = tags

	if tags.is_empty():
		result.place_feeling = ""
		return result

	# Derive feeling from meaning tags
	var feelings: PackedStringArray = []
	for tag in tags:
		match tag:
			"sacred":
				feelings.append("sacred")
			"dangerous", "death", "blood":
				feelings.append("dangerous")
			"home", "settlement", "hearth":
				feelings.append("like home")
			"wild", "untamed":
				feelings.append("wild")
			"abandoned", "ruin":
				feelings.append("haunted")
			"fertile", "abundant":
				feelings.append("promising")

	if not feelings.is_empty():
		result.place_feeling = "This place feels %s" % feelings[0]

	return result


# ==================== LAYER 7: THOUGHT COMPOSITION ====================

func _compose_thought(body: Dictionary, memory: Dictionary, desire: Dictionary, meaning: Dictionary, data: HeelKawnianData) -> Dictionary:
	var thought: String = ""
	var reason: String = desire.get("reason", "")

	# Build thought from dominant pressure + pursuit + meaning
	var dominant: String = body.get("dominant_need", "none")
	var pursuit: String = desire.get("pursuit", "")
	var emotional: String = body.get("emotional", "calm")
	var place_feeling: String = meaning.get("place_feeling", "")

	# Priority: survival thought > work thought > meaning thought > idle thought
	if dominant == "hunger":
		thought = "I need food before I can keep working."
		if reason.is_empty():
			reason = "Hunger (%.0f) is the most pressing need" % data.hunger
	elif dominant == "rest":
		thought = "I can barely keep my eyes open. I need to rest."
		if reason.is_empty():
			reason = "Rest (%.0f) is critically low" % data.rest
	elif dominant == "health":
		thought = "I'm hurt. I need to find healing or I won't make it."
		if reason.is_empty():
			reason = "Health (%.0f) is dangerously low" % data.health
	elif dominant == "mood":
		thought = "Everything feels heavy. I need something to lift my spirits."
		if reason.is_empty():
			reason = "Mood (%.0f) is the lowest need" % data.mood
	elif not pursuit.is_empty() and pursuit != "Seeking purpose":
		thought = "I should %s." % pursuit.to_lower()
		if not place_feeling.is_empty():
			thought += " %s." % place_feeling
	elif not place_feeling.is_empty():
		thought = place_feeling.capitalize() + "."
	else:
		# Idle thought from personality
		thought = _idle_thought_from_personality(data)

	# Trauma modifies thought
	var trauma: float = float(memory.get("trauma", 0.0))
	if trauma >= 75 and not thought.contains("hurt") and not thought.contains("danger"):
		thought = "I can't stop thinking about what happened. " + thought
	elif trauma >= 50 and not thought.contains("past"):
		thought = "The past weighs on me. " + thought

	return {
		"text": thought,
		"reason": reason,
	}


func _idle_thought_from_personality(data: HeelKawnianData) -> String:
	# Deterministic idle thought based on personality traits
	# Uses stable_hash instead of randf
	var h: int = stable_hash(int(data.id), GameManager.tick_count / 100, 42)

	if data.openness > 0.7:
		return "I wonder what lies beyond the horizon."
	elif data.conscientiousness > 0.7:
		return "There must be something useful I can do."
	elif data.extraversion > 0.7:
		return "I should find someone to talk to."
	elif data.agreeableness > 0.7:
		return "I hope everyone is doing well."
	elif data.neuroticism > 0.7:
		return "Something feels wrong. I should be careful."
	else:
		# Use hash to pick a generic thought deterministically
		var options: PackedStringArray = [
			"I should find something to do.",
			"The settlement needs work.",
			"I wonder what the others are doing.",
		]
		return options[absi(h) % options.size()]


# ==================== LAYER 8: WORK INTENT ====================

func _compute_work_intent(pawn: Node, data: HeelKawnianData) -> Dictionary:
	var current_job = pawn.get("_current_job")
	if current_job != null and is_instance_valid(current_job):
		var job_type: int = int(current_job.type)
		var job_name: String = "Working"
		if JobManager != null:
			job_name = Job.describe_type(job_type)
		return {
			"text": "%s at (%d, %d)" % [job_name, int(current_job.work_tile.x), int(current_job.work_tile.y)],
		}

	# Not working — check state
	var state: int = int(pawn.get_state()) if pawn.has_method("get_state") else 0
	# HeelKawnian.State enum: IDLE=0, WALKING=1, WORKING=2, EATING=3, SLEEPING=6
	match state:
		0:
			return {"text": "Idle — looking for work"}
		1:
			return {"text": "Walking to task"}
		3:
			return {"text": "Eating"}
		6:
			return {"text": "Sleeping"}
		_:
			return {"text": "Busy"}


# ==================== HELPERS ====================

func _format_likes(data: HeelKawnianData) -> String:
	if data.likes.is_empty():
		return "No strong preferences yet."
	var parts: PackedStringArray = []
	for key in data.likes:
		var val: float = float(data.likes[key])
		if val > 0.5:
			parts.append(str(key).replace("_", " ").capitalize())
	if parts.is_empty():
		return "No strong preferences yet."
	return ", ".join(parts)


func _format_dislikes(data: HeelKawnianData) -> String:
	if data.dislikes.is_empty():
		return "No strong aversions yet."
	var parts: PackedStringArray = []
	for key in data.dislikes:
		var val: float = float(data.dislikes[key])
		if val > 0.5:
			parts.append(str(key).replace("_", " ").capitalize())
	if parts.is_empty():
		return "No strong aversions yet."
	return ", ".join(parts)


func _pawn_name_for_id(pawn_id: int) -> String:
	var ps: Node = _pawn_spawner()
	if ps == null or not ps.has_method("get_pawn_by_id"):
		return "HeelKawnian #%d" % pawn_id
	var pawn: Variant = ps.call("get_pawn_by_id", pawn_id)
	if pawn == null or not is_instance_valid(pawn):
		return "HeelKawnian #%d" % pawn_id
	var d = pawn.get("data")
	if d != null and d is HeelKawnianData:
		return str(d.display_name)
	return "HeelKawnian #%d" % pawn_id


func _pawn_spawner() -> Node:
	var main: Node = get_tree().get_root().get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("WorldViewport/PawnSpawner")


func _job_class() -> Object:
	return load("res://scripts/jobs/Job.gd")


func _settlement_id_for_pawn(data: HeelKawnianData) -> int:
	if SettlementMemory == null:
		return -1
	return SettlementMemory.get_settlement_id_for_pawn(int(data.id))


func _region_key_for_tile(tile: Vector2i) -> int:
	var rx: int = tile.x >> 4
	var ry: int = tile.y >> 4
	return (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)


# ==================== LAYER 9: KNOWLEDGE ====================

func _compute_knowledge(pawn_id: int, data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"summary": "No knowledge recorded.",
		"count": 0,
		"at_risk": false,
	}

	if KnowledgeSystem == null:
		return result

	var known: Array = KnowledgeSystem.get_pawn_knowledge(pawn_id)
	result.count = known.size()

	if known.is_empty():
		return result

	# Build readable summary
	var parts: PackedStringArray = []
	for kt in known:
		var name: String = _knowledge_name_for_type(int(kt))
		parts.append(name)

	if not parts.is_empty():
		if parts.size() <= 5:
			result.summary = "Knows: " + ", ".join(parts)
		else:
			var first5: PackedStringArray = []
			for i in range(5):
				first5.append(parts[i])
			result.summary = "Knows: " + ", ".join(first5) + " (+%d more)" % (parts.size() - 5)

	# Check if any knowledge is at risk (only 1 carrier)
	for kt in known:
		var carrier_count: int = KnowledgeSystem.get_carrier_count(int(kt))
		if carrier_count <= 1:
			result.at_risk = true
			break

	return result


func _knowledge_name_for_type(kt: int) -> String:
	if KnowledgeSystem == null:
		return "knowledge_%d" % kt
	# Use the enum keys
	var keys: Array = KnowledgeSystem.KnowledgeType.keys()
	if kt >= 0 and kt < keys.size():
		return str(keys[kt]).to_lower().replace("_", " ")
	return "knowledge_%d" % kt


# ==================== LAYER 10: WAR/CONFLICT MEMORY ====================

func _compute_war_memory(pawn_id: int, data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"summary": "No conflict memories.",
		"conflict_count": 0,
	}

	if WorldMemory == null:
		return result

	# Check for conflict events involving this pawn
	var events: Array = WorldMemory.get_recent_events_for_pawn(pawn_id, 20)
	var conflict_events: Array = []
	var injury_events: Array = []
	var death_witnessed: int = 0

	for e in events:
		if not e is Dictionary:
			continue
		var kind: int = int(e.get("type", -1))
		match kind:
			WorldMemory.Kind.CONFLICT_EVENT:
				conflict_events.append(e)
			WorldMemory.Kind.INJURY_EVENT:
				injury_events.append(e)
			WorldMemory.Kind.PAWN_DEATH:
				# Only count if this pawn was nearby (same tile or adjacent)
				var ex: int = int(e.get("x", -999))
				var ey: int = int(e.get("y", -999))
				if ex >= 0:
					var dist: float = absf(float(data.tile_pos.x) - float(ex)) + absf(float(data.tile_pos.y) - float(ey))
					if dist <= 4.0:
						death_witnessed += 1

	result.conflict_count = conflict_events.size()

	var parts: PackedStringArray = []

	if not conflict_events.is_empty():
		parts.append("%d conflict%s" % [conflict_events.size(), "s" if conflict_events.size() > 1 else ""])

	if not injury_events.is_empty():
		parts.append("%d injur%s" % [injury_events.size(), "y" if injury_events.size() == 1 else "ies"])

	if death_witnessed > 0:
		parts.append("witnessed %d death%s" % [death_witnessed, "s" if death_witnessed != 1 else ""])

	if not parts.is_empty():
		result.summary = ", ".join(parts)
	else:
		var grudges: Array = SocialManager.get_grudges_held_by(pawn_id)
		if not grudges.is_empty():
			result.summary = "Carries %d grudge%s" % [grudges.size(), "s" if grudges.size() > 1 else ""]
			result.conflict_count = grudges.size()

	return result


# ==================== LAYER 11: SETTLEMENT HISTORY ====================

func _compute_settlement_history(data: HeelKawnianData) -> Dictionary:
	var result: Dictionary = {
		"summary": "No settlement history.",
	}

	var settlement_id: int = _settlement_id_for_pawn(data)
	if settlement_id < 0:
		return result

	# Read settlement data from SettlementMemory
	if SettlementMemory == null:
		return result

	var settlements: Array = SettlementMemory.get_settlements()
	if settlement_id >= settlements.size():
		return result

	var st: Variant = settlements[settlement_id]
	if not st is Dictionary:
		return result

	var sdict: Dictionary = st as Dictionary
	var parts: PackedStringArray = []

	# Population
	var pop: int = int(sdict.get("population", 0))
	if pop > 0:
		parts.append("Pop %d" % pop)

	# Buildings
	var buildings: int = int(sdict.get("building_count", 0))
	if buildings > 0:
		parts.append("%d buildings" % buildings)

	# Era/stage from CivilizationStage
	if HeelKawnianManager != null:
		var profile: Dictionary = HeelKawnianManager.get_development_profile_for_pawn(_pawn_for_id(int(data.id)))
		if not profile.is_empty():
			var era: String = str(profile.get("era", ""))
			if not era.is_empty():
				parts.append(era)

	# Deaths near settlement
	var deaths: int = int(sdict.get("total_deaths", 0))
	if deaths > 0:
		parts.append("%d fallen" % deaths)

	if not parts.is_empty():
		result.summary = ", ".join(parts)

	return result


func _pawn_for_id(pawn_id: int) -> Node:
	var ps: Node = _pawn_spawner()
	if ps == null or not ps.has_method("get_pawn_by_id"):
		return null
	return ps.call("get_pawn_by_id", pawn_id)
