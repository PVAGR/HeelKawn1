class_name PawnChatter
extends Node2D

## Procedural speech bubbles for idle pawns. Shows brief text when
## pawns are near each other and idle, based on their needs, mood,
## profession, and recent events. Throttled to avoid spam.

const CHECK_EVERY_N_TICKS: int = 60  # Throttled from 30 to reduce O(n²) scan frequency
const MAX_BUBBLES: int = 5
const BUBBLE_LIFETIME: float = 2.5
const BUBBLE_RADIUS: float = 60.0  # proximity for social chatter
const FONT_SIZE: int = 5
const BUBBLE_PADDING: float = 3.0
const BUBBLE_BG: Color = Color(0.08, 0.09, 0.12, 0.75)
const BUBBLE_BORDER: Color = Color(0.4, 0.38, 0.3, 0.3)
const TEXT_COLOR: Color = Color(0.88, 0.84, 0.72, 0.9)

var _world: World = null
var _tick_counter: int = 0
var _bubbles: Array[Dictionary] = []

var _llm_client: Node = null
var _llm_busy: bool = false
const LLM_EVERY_N_TICKS: int = 300

var _waiting_for_llm: Dictionary = {}  # {pawn: text}

# Pawn-to-pawn conversations
var _active_conversations: Dictionary = {}  # "pair_key" -> Dictionary
const CONV_PAIR_RADIUS: float = 50.0
const CONV_EXCHANGE_MS: float = 2000.0  # 2s between exchanges
const CONV_MAX_EXCHANGES: int = 4       # total bubble count per pair
const CONV_EVERY_N_TICKS: int = 360    # ~6 seconds


func initialize(world_ref: World) -> void:
	_world = world_ref


func set_llm_client(client: Node) -> void:
	_llm_client = client


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % CHECK_EVERY_N_TICKS == 0:
		_try_spawn_bubbles()

	# Async LLM chatter (slower cadence)
	if _llm_client != null and not _llm_busy and _tick_counter % LLM_EVERY_N_TICKS == 0:
		_try_spawn_llm_chatter()

	# Advance pawn-to-pawn conversations
	_advance_conversations()

	# Remove expired bubbles
	var now: float = Time.get_ticks_msec()
	var before_size: int = _bubbles.size()
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool:
		return (now - float(b.get("born", 0.0))) < BUBBLE_LIFETIME * 1000.0
	)
	# Only redraw if bubbles changed or still active
	if _bubbles.size() != before_size or not _bubbles.is_empty():
		queue_redraw()

	# Apply any completed LLM chatter
	if not _waiting_for_llm.is_empty() and _bubbles.size() < MAX_BUBBLES:
		for pawn_node in _waiting_for_llm:
			var text: String = str(_waiting_for_llm[pawn_node])
			if not text.is_empty():
				_bubbles.append({
					"pawn": pawn_node,
					"text": text,
					"born": Time.get_ticks_msec(),
				})
			break
		_waiting_for_llm.clear()
		queue_redraw()


func _try_spawn_bubbles() -> void:
	if _bubbles.size() >= MAX_BUBBLES:
		return

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var spawners: Array = tree.get_nodes_in_group("pawn_spawner")
	if spawners.is_empty():
		return
	var spawner = spawners[0]
	if spawner == null or not spawner.has_method("get_all_pawns"):
		return

	var all_pawns: Array = spawner.get_all_pawns()
	if all_pawns.is_empty():
		return

	# Collect idle pawns
	var idle_pawns: Array = []
	for p in all_pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p._state != p.State.IDLE:
			continue
		if p.data == null:
			continue
		idle_pawns.append(p)

	# Try starting a pawn-to-pawn conversation first (30% chance when pair available)
	if _active_conversations.size() < 2 and Time.get_ticks_msec() % 10 < 3:
		_try_start_conversation(idle_pawns)
		if _bubbles.size() >= MAX_BUBBLES:
			return

	# Single-pawn chatter (original behavior)
	var candidates: Array[Dictionary] = []
	var r_sq: float = BUBBLE_RADIUS * BUBBLE_RADIUS
	for p in idle_pawns:
		var has_neighbor: bool = false
		for other in idle_pawns:
			if other == p:
				continue
			var dist: float = p.global_position.distance_squared_to(other.global_position)
			if dist <= r_sq:
				has_neighbor = true
				break
		if has_neighbor:
			candidates.append({"pawn": p, "text": _generate_text(p)})

	if candidates.is_empty():
		return

	var choice: Dictionary = candidates[Time.get_ticks_msec() % maxi(candidates.size(), 1)]
	var pawn = choice.get("pawn")
	var text: String = choice.get("text", "")
	if text.is_empty() or pawn == null:
		return

	_bubbles.append({
		"pawn": pawn,
		"text": text,
		"born": Time.get_ticks_msec(),
	})


func _try_spawn_llm_chatter() -> void:
	_llm_busy = true
	var pawn = _find_llm_candidate()
	if pawn == null:
		_llm_busy = false
		return
	var context: String = _build_llm_context(pawn)
	var prompt: String = (
		"You are a pawn in a world. Generate one short line of ambient dialogue (10 words or fewer) "
		+ "that fits this pawn's current state. Do NOT use markdown or quotes. Return ONLY the line.\n\n"
		+ context
	)
	var response = await _llm_client.request(prompt, {})
	if response != null and typeof(response) == TYPE_DICTIONARY and response.has("content"):
		var text: String = str(response.get("content", "")).strip_edges()
		if not text.is_empty():
			_waiting_for_llm[pawn] = text
	_llm_busy = false


func _find_llm_candidate():
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var spawners: Array = tree.get_nodes_in_group("pawn_spawner")
	if spawners.is_empty():
		return null
	var spawner = spawners[0]
	if spawner == null or not spawner.has_method("get_all_pawns"):
		return null
	var all_pawns: Array = spawner.get_all_pawns()
	if all_pawns.is_empty():
		return null
	var candidates: Array = []
	for p in all_pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.data == null:
			continue
		if p._state != p.State.IDLE:
			continue
		candidates.append(p)
	if candidates.is_empty():
		return null
	return candidates[Time.get_ticks_msec() % candidates.size()]


func _build_llm_context(pawn) -> String:
	if pawn.data == null:
		return ""
	var d = pawn.data
	var parts: Array[String] = []
	parts.append("Profession: %s" % d.profession_name())
	parts.append("Hunger: %.0f%%" % d.hunger)
	parts.append("Energy: %.0f%%" % d.rest)
	parts.append("Mood: %.0f%%" % d.mood)
	if d.has_method("get") and d.get("current_activity") != null:
		parts.append("Current activity: %s" % str(d.get("current_activity")))
	var hour: int = 12
	if GameManager != null:
		hour = (GameManager.tick_count / 600) % 24 if GameManager.tick_count > 0 else 12
	parts.append("Time: %02d:00" % hour)
	return "\n".join(parts)


func _try_start_conversation(idle_pawns: Array) -> void:
	if idle_pawns.size() < 2:
		return
	var cr_sq: float = CONV_PAIR_RADIUS * CONV_PAIR_RADIUS
	for i in range(idle_pawns.size()):
		var a = idle_pawns[i]
		for j in range(i + 1, idle_pawns.size()):
			var b = idle_pawns[j]
			var key: String = _pair_key(a, b)
			if _active_conversations.has(key):
				continue
			var dist: float = a.global_position.distance_squared_to(b.global_position)
			if dist > cr_sq:
				continue
			var text_a: String = _generate_text(a)
			if text_a.is_empty():
				continue
			_active_conversations[key] = {
				"a": a, "b": b,
				"exchanges": 1,
				"next_time": Time.get_ticks_msec() + CONV_EXCHANGE_MS,
			}
			_bubbles.append({"pawn": a, "text": text_a, "born": Time.get_ticks_msec()})
			return


func _pair_key(a, b) -> String:
	var id_a: int = a.data.id if a.data != null else int(a.get_instance_id())
	var id_b: int = b.data.id if b.data != null else int(b.get_instance_id())
	return "%d-%d" % [mini(id_a, id_b), maxi(id_a, id_b)]


func _advance_conversations() -> void:
	if _active_conversations.is_empty():
		return
	var now: float = Time.get_ticks_msec()
	var to_remove: Array[String] = []
	for key in _active_conversations:
		var conv: Dictionary = _active_conversations[key]
		if conv.exchanges >= CONV_MAX_EXCHANGES:
			to_remove.append(key)
			continue
		var a = conv.a
		var b = conv.b
		if a == null or not is_instance_valid(a) or b == null or not is_instance_valid(b):
			to_remove.append(key)
			continue
		if now < conv.next_time:
			continue
		var speaker = b if (conv.exchanges % 2 == 1) else a
		var text: String = await _generate_response(conv, speaker)
		if not text.is_empty():
			_bubbles.append({"pawn": speaker, "text": text, "born": now})
			conv.exchanges += 1
			conv.next_time = now + CONV_EXCHANGE_MS
		else:
			to_remove.append(key)
	for key in to_remove:
		_active_conversations.erase(key)


func _generate_response(conv: Dictionary, speaker) -> String:
	if speaker.data == null:
		return ""
	var d = speaker.data
	var others = conv.a if speaker == conv.b else conv.b
	var o_data = others.data

	# If LLM available, try rich response
	if _llm_client != null and not _llm_busy:
		var ctx: String = _build_llm_context(speaker)
		var other_ctx: String = _build_llm_context(others) if others != null else ""
		var prompt: String = (
			"Two pawns are talking. Generate a short reply (8 words or fewer) "
			+ "for the responding pawn based on their state.\n\n"
			+ "Speaker: %s (%s)\n" % [d.display_name, ctx.replace("\n", ", ")]
			+ "Other pawn: %s (%s)\n" % [o_data.display_name if o_data != null else "?", other_ctx.replace("\n", ", ") if other_ctx != "" else "?"]
			+ "\nReply as %s: " % d.display_name
		)
		_llm_busy = true
		var response = await _llm_client.request(prompt, {}, "Generate one short line of dialogue. No markdown, no quotes.")
		_llm_busy = false
		if response != null and typeof(response) == TYPE_DICTIONARY and response.has("content"):
			var text: String = str(response.get("content", "")).strip_edges()
			if not text.is_empty():
				return text

	# Fallback: template-based responses
	var exchange: int = conv.exchanges
	if exchange == 1:
		return _pick(["Yeah...", "I hear you.", "True.", "Same here.", "Tell me about it."])
	elif exchange == 2:
		return _pick(["Things are tough.", "Hang in there.", "Could be worse.", "What else is new?"])
	else:
		return _pick(["Yeah.", "Mhm.", "Anyway...", "Back to it.", "Alright."])


func _generate_text(pawn) -> String:
	if pawn.data == null:
		return ""
	var d = pawn.data

	# Priority: urgent needs first
	if d.hunger < 30.0:
		return _pick(["Need food...", "Hungry...", "Any berries?", "Starving..."])
	if d.rest < 20.0:
		return _pick(["So tired...", "Need sleep...", "Exhausted..."])
	if d.mood < 25.0:
		return _pick(["Bad day...", "Feeling low...", "Not great...", "Ugh..."])

	# Mood-driven
	if d.mood > 80.0:
		return _pick(["Good day!", "Nice weather.", "Life's okay.", "Feeling good."])

	# Profession chatter
	if d.current_profession != 0:  # NONE = 0
		var prof_name: String = ""
		if d.has_method("profession_label_from_enum"):
			prof_name = d.profession_label_from_enum(d.current_profession)
		if not prof_name.is_empty() and prof_name != "None":
			match d.current_profession:
				1: return _pick(["Crops need tending.", "Soil looks good.", "Planting soon."])  # FARMER
				2: return _pick(["Need more wood.", "Walls going up.", "Building."])             # BUILDER
				3: return _pick(["Found berries!", "Gathering.", "Foraging nearby."])            # GATHERER
				4: return _pick(["Staying alert.", "Patrol soon.", "Watching."])                  # WARRIOR
				5: return _pick(["Interesting...", "Studying.", "So much to learn."])            # SCHOLAR
				6: return _pick(["Good trade today.", "Need a deal.", "Prices looking up."])     # TRADER
				7: return _pick(["Forge is hot.", "Need more ore.", "Hammering."])               # SMITH
				8: return _pick(["Who's hurt?", "Healing herbs.", "Tending wounds."])            # HEALER

	# Time-of-day
	if GameManager != null and DayNightCycle.is_night_for_tick(GameManager.tick_count):
		return _pick(["Dark out...", "Cold night.", "Can't sleep.", "Quiet..."])

	# Generic social
	return _pick(["Hey.", "How's it going?", "Nice day.", "Hmm.", "Seen any food?", "What's new?"])


func _pick(options: PackedStringArray) -> String:
	if options.is_empty():
		return ""
	return options[Time.get_ticks_msec() % options.size()]


func _draw() -> void:
	var now: float = Time.get_ticks_msec()
	var font: Font = ThemeDB.fallback_font

	for b in _bubbles:
		var pawn = b.get("pawn")
		if pawn == null or not is_instance_valid(pawn):
			continue
		var text: String = b.get("text", "")
		if text.is_empty():
			continue
		var born: float = float(b.get("born", 0.0))
		var age: float = (now - born) / 1000.0
		var alpha: float = clampf(1.0 - age / BUBBLE_LIFETIME, 0.0, 1.0)

		# Position above pawn
		var pos: Vector2 = pawn.global_position + Vector2(0.0, -14.0) - global_position
		var str_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var rect: Rect2 = Rect2(
			pos - Vector2(str_size.x * 0.5 + BUBBLE_PADDING, BUBBLE_PADDING),
			str_size + Vector2(BUBBLE_PADDING * 2.0, BUBBLE_PADDING * 2.0)
		)

		# Bubble background
		var bg_color: Color = Color(BUBBLE_BG.r, BUBBLE_BG.g, BUBBLE_BG.b, BUBBLE_BG.a * alpha)
		var border_color: Color = Color(BUBBLE_BORDER.r, BUBBLE_BORDER.g, BUBBLE_BORDER.b, BUBBLE_BORDER.a * alpha)
		draw_rect(rect, bg_color, true)
		draw_rect(rect, border_color, false, 1.0)

		# Text
		var text_color: Color = Color(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b, TEXT_COLOR.a * alpha)
		var text_pos: Vector2 = pos - Vector2(str_size.x * 0.5, -2.0)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, text_color)
