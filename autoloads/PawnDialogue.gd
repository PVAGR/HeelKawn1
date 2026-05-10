extends Node
## PawnDialogue — dialogue generation system

signal conversation_started(pawn_id: int, pawn_name: String)
signal message_received(pawn_id: int, speaker: String, text: String)
signal conversation_ended(pawn_id: int)
signal thinking_started(pawn_id: int)
signal error_occurred(pawn_id: int, message: String)

var _histories: Dictionary = {}  # pawn_id -> Array of {"role": str, "content": str}
var _llm_client = null
var _PawnConsciousness = null
var _GameManager = null
var _active_pawn_id: int = -1

const SYSTEM_PROMPT_TEMPLATE: String = "You are {name}, a {age}-year-old pawn in the world of HeelKawn.\nProfession: {profession}\n\nCurrent state:\n- Hunger: {hunger}/100\n- Rest: {rest}/100\n- Mood: {mood}/100\n- Health: {health}/100\n- Current activity: {activity}\n\nRecent memories:\n{memories}\n\nCore beliefs:\n{beliefs}\n\nSubconscious desires:\n{desires}\n\nSelf-awareness level: {awareness}\n\n{incarnation_status}\n\nLocation: {location}\nWorld tick: {tick}\n\nYou are speaking with a visitor (the observer/player). Respond in character as a simple medieval tribal villager. Be conversational, natural, and react according to your mood and situation. Use simple language. Keep responses to 2-4 sentences unless asked a detailed question.\n\nIf you are hungry, tired, or in pain, let it show in how you speak. If you are happy, be warm. If you just experienced something traumatic, it should color your words."

func _ready() -> void:
	_llm_client = get_node_or_null("/root/HeelKawnAIOrchestrator/LLMClient")
	if _llm_client == null:
		_llm_client = get_node_or_null("/root/LLMClient")
	if _llm_client == null:
		_llm_client = LLMClient.new()
		add_child(_llm_client)
	_PawnConsciousness = get_node_or_null("/root/PawnConsciousness")
	_GameManager = get_node_or_null("/root/GameManager")

func start_conversation(pawn_id: int, pawn_name: String) -> void:
	if not _histories.has(pawn_id):
		_histories[pawn_id] = []
	_active_pawn_id = pawn_id
	conversation_started.emit(pawn_id, pawn_name)

func end_conversation(pawn_id: int) -> void:
	_active_pawn_id = -1
	conversation_ended.emit(pawn_id)

func send_message(pawn_id: int, player_message: String) -> void:
	if not _histories.has(pawn_id):
		_histories[pawn_id] = []
	_histories[pawn_id].append({"role": "player", "content": player_message})
	thinking_started.emit(pawn_id)
	var response: Dictionary = await _generate_response(pawn_id)
	if response.has("error"):
		error_occurred.emit(pawn_id, response.get("error", "Unknown error"))
		return
	_histories[pawn_id].append({"role": "pawn", "content": response.content})
	message_received.emit(pawn_id, _get_pawn_name(pawn_id), response.content)
	var pawn_node = _find_pawn_node(pawn_id)
	if pawn_node != null and is_instance_valid(pawn_node):
		var bubbles: Node = get_node_or_null("/root/PawnChatterBubbles")
		if bubbles != null and bubbles.has_method("show_chat_bubble"):
			bubbles.show_chat_bubble(pawn_id, pawn_node, response.content)

func get_conversation(pawn_id: int) -> Array:
	return _histories.get(pawn_id, []).duplicate()

func clear_conversation(pawn_id: int) -> void:
	_histories.erase(pawn_id)

func _generate_response(pawn_id: int) -> Dictionary:
	var pawn_node: Node = _find_pawn_node(pawn_id)
	if pawn_node == null or not is_instance_valid(pawn_node):
		return {"error": "HeelKawnian not found"}
	var context: Dictionary = _build_pawn_context(pawn_node)
	var system_prompt: String = _build_system_prompt(pawn_node, context)
	var conv: Array = _histories.get(pawn_id, [])
	var recent: Array = conv.slice(max(0, conv.size() - 20), conv.size())
	var messages_text: String = ""
	for msg in recent:
		var prefix: String = "Player" if msg.role == "player" else pawn_node.data.display_name
		messages_text += "%s: %s\n" % [prefix, msg.content]
	messages_text += "%s: " % pawn_node.data.display_name
	var prompt: String = messages_text
	if _llm_client == null:
		return {"error": "No LLM client", "content": "...", "usage": 0}
	return await _llm_client.request(prompt, context, system_prompt)

func _build_pawn_context(pawn_node: Node) -> Dictionary:
	var data = pawn_node.data
	if data == null:
		return {}
	var pid: int = int(data.id)
	var tile_pos: Vector2i = data.tile_pos
	var ctx: Dictionary = {
		"pawn_id": pid,
		"name": str(data.display_name),
		"age": int(data.age) if "age" in data else 0,
		"profession": _get_profession_name(data),
		"hunger": int(pawn_node.get("_hunger_level")) if pawn_node.get("_hunger_level") != null else 50,
		"rest": int(pawn_node.get("_rest_level")) if pawn_node.get("_rest_level") != null else 50,
		"mood": int(pawn_node.get("_mood_level")) if pawn_node.get("_mood_level") != null else 50,
		"health": 100,
		"activity": _get_activity_name(pawn_node),
		"tick": _GameManager.tick_count if _GameManager != null else 0,
		"location": "(%d, %d)" % [tile_pos.x, tile_pos.y],
		"is_player_incarnation": false,
	}
	if _PawnConsciousness != null:
		var pid2: int = ctx.pawn_id
		if pid2 > 0:
			var memories: Array = _PawnConsciousness.get_memories(pid2, "", 5)
			var mem_text: String = ""
			for m in memories:
				if m is Dictionary:
					mem_text += "- %s: %s\n" % [m.get("event_type", "event"), m.get("description", "")]
			ctx["memories"] = mem_text
			var beliefs: Array = _PawnConsciousness.get_core_beliefs(pid2)
			ctx["beliefs"] = "\n".join(beliefs) if beliefs.size() > 0 else "(none yet)"
			var desires: Array = _PawnConsciousness.get_subconscious_desires(pid2)
			ctx["desires"] = "\n".join(desires) if desires.size() > 0 else "(none yet)"
			var awareness: int = _PawnConsciousness.get_awareness_level(pid2)
			var awareness_names: Array = ["Unaware", "Drowsing", "Aware", "Self-Aware", "Enlightened"]
			ctx["awareness"] = awareness_names[clampi(awareness, 0, awareness_names.size() - 1)]
		else:
			ctx["memories"] = "(none yet)"
			ctx["beliefs"] = "(none yet)"
			ctx["desires"] = "(none yet)"
			ctx["awareness"] = "Unaware"
	else:
		ctx["memories"] = "(unavailable)"
		ctx["beliefs"] = "(unavailable)"
		ctx["desires"] = "(unavailable)"
		ctx["awareness"] = "Unknown"
	# Incarnation check — is this pawn the player's vessel?
	var main_node: Node = get_node_or_null("/root/Main")
	if main_node != null:
		var player_pawn: Node = main_node.get("_player_pawn") if main_node.get("_player_pawn") != null else null
		if player_pawn != null and is_instance_valid(player_pawn):
			ctx["is_player_incarnation"] = (player_pawn == pawn_node)
	ctx["incarnation_status"] = "You are the player's vessel — they experience the world through you." if ctx.is_player_incarnation else "You are a regular pawn in the settlement."
	return ctx

func _build_system_prompt(pawn_node: Node, ctx: Dictionary) -> String:
	return SYSTEM_PROMPT_TEMPLATE.format(ctx)

func _get_profession_name(data) -> String:
	var prof = data.get("profession", -1)
	var names: Array = ["None", "Farmer", "Builder", "Gatherer", "Warrior", "Scholar", "Trader", "Smith", "Healer"]
	if prof is int and prof >= 0 and prof < names.size():
		return names[prof]
	return "Tribal Villager"

func _get_activity_name(pawn_node: Node) -> String:
	var state: int = int(pawn_node.get("_state")) if pawn_node.get("_state") != null else -1
	if state < 0:
		return "idle"
	var names: Array = ["IDLE", "WORKING", "EATING", "SLEEPING", "WALKING", "FLEEING", "FIGHTING", "DEAD"]
	if state < names.size():
		return names[state].to_lower()
	return "idle"

func _get_pawn_name(pawn_id: int) -> String:
	var pawn: Node = _find_pawn_node(pawn_id)
	if pawn != null and is_instance_valid(pawn) and pawn.data != null:
		var name: String = str(pawn.data.display_name) if "display_name" in pawn.data else ""
		if not name.is_empty():
			return name
	return "HeelKawnian %d" % pawn_id

func _find_pawn_node(pawn_id: int):
	if not is_instance_valid(get_tree()):
		return null
	var pawns: Array[Node] = get_tree().get_nodes_in_group("pawns")
	for p in pawns:
		if is_instance_valid(p) and p.data != null and ("id" in p.data) and int(p.data.id) == pawn_id:
			return p
	return null
