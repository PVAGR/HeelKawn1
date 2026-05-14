extends Node
## HeelKawnianVoice — Conversational AI for HeelKawnians.
## Generates natural language from the mind snapshot. HeelKawnians can tell
## you about their day, their feelings, their work, their relationships.
## They take apart words and letters, come up with their own phrasing.
## Deterministic: same mind state = same words (via stable_hash).
##
## This is NOT an LLM. It's a deterministic language composer that reads
## the HeelKawnianMind snapshot and produces human-readable dialogue.
## The richness comes from the depth of the mind data, not from randomness.

## Compose a conversational response from a HeelKawnian's mind.
## `topic` can be: "day", "work", "feelings", "family", "home", "dreams",
## "knowledge", "gossip", "meaning", or "" (auto-pick based on current state).
func compose_dialogue(pawn: Node, topic: String = "") -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return ""
	var mind: Dictionary = HeelKawnianMind.compute_mind_snapshot(pawn)
	if mind.is_empty():
		return ""
	var data = pawn.data
	var name: String = data.display_name

	# Auto-pick topic based on current state
	if topic == "":
		topic = _auto_topic(mind, data)

	# Compose based on topic
	var response: String = ""
	match topic:
		"day":
			response = _compose_day(name, mind, data)
		"work":
			response = _compose_work(name, mind, data)
		"feelings":
			response = _compose_feelings(name, mind, data)
		"family":
			response = _compose_family(name, mind, data)
		"home":
			response = _compose_home(name, mind, data)
		"dreams":
			response = _compose_dreams(name, mind, data)
		"knowledge":
			response = _compose_knowledge(name, mind, data)
		"gossip":
			response = _compose_gossip(name, mind, data)
		"meaning":
			response = _compose_meaning(name, mind, data)
		_:
			response = _compose_general(name, mind, data)

	return response


## Auto-pick the most relevant topic based on current state
func _auto_topic(mind: Dictionary, data) -> String:
	var hunger: float = float(mind.get("raw", {}).get("hunger", 100.0))
	var rest: float = float(mind.get("raw", {}).get("rest", 100.0))
	var mood: float = float(mind.get("raw", {}).get("mood", 50.0))

	# Urgent needs first
	if hunger < 30.0:
		return "feelings"
	if rest < 20.0:
		return "feelings"

	# Mood-driven
	if mood < 25.0:
		return "feelings"
	if mood > 80.0:
		return "day"

	# Work-driven
	var work_intent: String = str(mind.get("work_intent", ""))
	if not work_intent.is_empty():
		return "work"

	# Family
	var family: String = str(mind.get("family", ""))
	if not family.is_empty() and family != "none":
		return "family"

	# Default: talk about the day
	return "day"


# ==================== TOPIC COMPOSERS ====================

func _compose_day(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var thought: String = str(mind.get("current_thought", ""))
	var pursuit: String = str(mind.get("pursuit", ""))
	var body: String = str(mind.get("body_pressure", ""))
	var emotion: String = str(mind.get("emotional_pressure", ""))

	# Opening — how the day feels
	parts.append(_day_opening(name, emotion, data))

	# What they're doing
	if not pursuit.is_empty():
		parts.append(_pursuit_sentence(pursuit))

	# Body state
	if not body.is_empty():
		parts.append(_body_sentence(body, data))

	# Current thought
	if not thought.is_empty():
		parts.append(_thought_sentence(thought))

	return " ".join(parts)


func _compose_work(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var work_intent: String = str(mind.get("work_intent", ""))
	var pursuit: String = str(mind.get("pursuit", ""))
	var profession: String = _profession_label(data)

	parts.append("%s is a %s." % [name, profession])

	if not work_intent.is_empty():
		parts.append(work_intent)
	elif not pursuit.is_empty():
		parts.append("Right now, %s." % pursuit.to_lower())
	else:
		parts.append("Looking for something to do.")

	# Knowledge context
	var knowledge_count: int = int(mind.get("knowledge_count", 0))
	if knowledge_count > 0:
		parts.append("Knows %d things." % knowledge_count)

	return " ".join(parts)


func _compose_feelings(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var emotion: String = str(mind.get("emotional_pressure", ""))
	var body: String = str(mind.get("body_pressure", ""))
	var mood: float = float(mind.get("raw", {}).get("mood", 50.0))
	var hunger: float = float(mind.get("raw", {}).get("hunger", 100.0))
	var rest: float = float(mind.get("raw", {}).get("rest", 100.0))

	# Emotional state
	if not emotion.is_empty():
		parts.append("%s feels %s." % [name, emotion.to_lower()])
	else:
		if mood > 70:
			parts.append("%s feels good." % name)
		elif mood > 40:
			parts.append("%s is doing alright." % name)
		else:
			parts.append("%s is struggling." % name)

	# Physical needs
	if hunger < 30:
		parts.append("Hungry — needs food badly.")
	elif hunger < 60:
		parts.append("Could use a meal.")

	if rest < 20:
		parts.append("Exhausted — needs rest.")
	elif rest < 50:
		parts.append("Getting tired.")

	# Body pressure
	if not body.is_empty():
		parts.append(body)

	return " ".join(parts)


func _compose_family(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var family: String = str(mind.get("family", ""))
	var relationships: String = str(mind.get("relationships", ""))

	if not family.is_empty() and family != "none":
		parts.append("%s's family: %s." % [name, family])
	else:
		parts.append("%s has no family yet." % name)

	if not relationships.is_empty() and relationships != "none":
		parts.append(relationships)

	return " ".join(parts)


func _compose_home(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var settlement: String = str(mind.get("settlement_history", ""))
	var culture: String = str(mind.get("culture_summary", ""))
	var place_feeling: String = str(mind.get("raw", {}).get("place_feeling", ""))

	if not settlement.is_empty():
		parts.append(settlement)
	else:
		parts.append("%s hasn't settled yet." % name)

	if not culture.is_empty():
		parts.append("Culture: %s." % culture.to_lower())

	if not place_feeling.is_empty():
		parts.append("This place feels %s." % place_feeling.to_lower())

	return " ".join(parts)


func _compose_dreams(name: String, mind: Dictionary, data) -> String:
	var pawn_id: int = int(data.id)
	var dreams: Array = PawnConsciousness.get_dreams(pawn_id, 3)
	if dreams.is_empty():
		return "%s hasn't dreamed yet." % name

	var parts: PackedStringArray = []
	parts.append("%s's recent dreams:" % name)
	for dream in dreams:
		if dream is Dictionary:
			var content: String = str(dream.get("content", ""))
			var theme: String = str(dream.get("theme", ""))
			var lucid: bool = dream.get("lucid", false)
			if not content.is_empty():
				var prefix: String = "Lucid" if lucid else "Dreamt"
				parts.append("%s of %s (%s)." % [prefix, content.to_lower(), theme])

	return " ".join(parts)


func _compose_knowledge(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var knowledge_count: int = int(mind.get("knowledge_count", 0))
	var knowledge_summary: String = str(mind.get("knowledge_summary", ""))
	var at_risk: bool = mind.get("knowledge_at_risk", false)

	if knowledge_count == 0:
		return "%s doesn't know much yet." % name

	parts.append("%s knows %d things." % [name, knowledge_count])

	if not knowledge_summary.is_empty():
		parts.append(knowledge_summary)

	if at_risk:
		parts.append("This knowledge is at risk — %s is the only one who knows it." % name)

	return " ".join(parts)


func _compose_gossip(name: String, mind: Dictionary, data) -> String:
	var pawn_id: int = int(data.id)
	var gossip: Array = SocialManager.get_gossip_about(pawn_id)
	if gossip.is_empty():
		# Try recent world events instead
		var memory_summary: String = str(mind.get("memory_summary", ""))
		if not memory_summary.is_empty():
			return "%s remembers: %s" % [name, memory_summary]
		return "%s hasn't heard any gossip." % name

	var parts: PackedStringArray = []
	parts.append("%s has heard things:" % name)
	for g in gossip:
		if g is Dictionary:
			var text: String = str(g.get("text", ""))
			if not text.is_empty():
				parts.append(text)

	return " ".join(parts)


func _compose_meaning(name: String, mind: Dictionary, data) -> String:
	var parts: PackedStringArray = []
	var culture: String = str(mind.get("culture_summary", ""))
	var reason: String = str(mind.get("reason", ""))

	if not reason.is_empty():
		parts.append("%s thinks: %s" % [name, reason])
	elif not culture.is_empty():
		parts.append("%s follows %s traditions." % [name, culture.to_lower()])
	else:
		parts.append("%s is still figuring out what matters." % name)

	return " ".join(parts)


func _compose_general(name: String, mind: Dictionary, data) -> String:
	var thought: String = str(mind.get("current_thought", ""))
	var pursuit: String = str(mind.get("pursuit", ""))

	if not thought.is_empty():
		return "%s: %s" % [name, thought]
	elif not pursuit.is_empty():
		return "%s is %s." % [name, pursuit.to_lower()]
	else:
		return "%s is here." % name


# ==================== HELPER COMPOSERS ====================

func _day_opening(name: String, emotion: String, data) -> String:
	var mood: float = float(data.mood) if data != null else 50.0
	var hunger: float = float(data.hunger) if data != null else 100.0

	if hunger < 20:
		return "%s is starving." % name
	if hunger < 40:
		return "%s is hungry." % name

	if not emotion.is_empty():
		return "%s feels %s today." % [name, emotion.to_lower()]

	if mood > 80:
		return "%s is having a good day." % name
	if mood > 50:
		return "%s is doing fine." % name
	if mood > 25:
		return "%s is having a rough day." % name
	return "%s is struggling." % name


func _pursuit_sentence(pursuit: String) -> String:
	if pursuit.is_empty():
		return ""
	return "Working on %s." % pursuit.to_lower()


func _body_sentence(body: String, data) -> String:
	if body.is_empty():
		return ""
	var hunger: float = float(data.hunger) if data != null else 100.0
	if hunger < 30:
		return "Needs food."
	return body


func _thought_sentence(thought: String) -> String:
	if thought.is_empty():
		return ""
	return "Thinking: %s" % thought


func _profession_label(data) -> String:
	if data == null:
		return "wanderer"
	var prof: int = int(data.current_profession) if data.get("current_profession") != null else 0
	match prof:
		1: return "farmer"
		2: return "builder"
		3: return "gatherer"
		4: return "warrior"
		5: return "scholar"
		6: return "trader"
		7: return "smith"
		8: return "healer"
		_: return "wanderer"


## Compose a brief one-line status for the HUD (not full dialogue)
func compose_status_line(pawn: Node) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return ""
	var mind: Dictionary = HeelKawnianMind.compute_mind_snapshot(pawn)
	if mind.is_empty():
		return ""
	var name: String = pawn.data.display_name
	var thought: String = str(mind.get("current_thought", ""))
	var pursuit: String = str(mind.get("pursuit", ""))

	if not thought.is_empty():
		return "%s: \"%s\"" % [name, thought]
	elif not pursuit.is_empty():
		return "%s — %s" % [name, pursuit.to_lower()]
	else:
		return name


## Compose what a HeelKawnian says when you click on them (greeting)
func compose_greeting(pawn: Node) -> String:
	if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return ""
	var mind: Dictionary = HeelKawnianMind.compute_mind_snapshot(pawn)
	if mind.is_empty():
		return ""
	var name: String = pawn.data.display_name
	var mood: float = float(mind.get("raw", {}).get("mood", 50.0))
	var hunger: float = float(mind.get("raw", {}).get("hunger", 100.0))

	# Greeting varies by mood and state
	if hunger < 20:
		return "%s looks at you weakly. \"Please... food...\"" % name
	if mood > 80:
		return "%s smiles. \"Good to see you! What a day.\"" % name
	if mood > 50:
		return "%s nods. \"Hey. What do you need?\"" % name
	if mood > 25:
		return "%s sighs. \"It's been a rough one.\"" % name
	return "%s barely looks up. \"...what?\"" % name
