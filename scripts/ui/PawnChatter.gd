class_name PawnChatter
extends Node2D

## Procedural speech bubbles for idle pawns. Shows brief text when
## pawns are near each other and idle, based on their needs, mood,
## profession, and recent events. Throttled to avoid spam.

const CHECK_EVERY_N_TICKS: int = 30
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


func initialize(world_ref: World) -> void:
	_world = world_ref


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % CHECK_EVERY_N_TICKS == 0:
		_try_spawn_bubbles()

	# Remove expired bubbles
	var now: float = Time.get_ticks_msec()
	_bubbles = _bubbles.filter(func(b: Dictionary) -> bool:
		return (now - float(b.get("born", 0.0))) < BUBBLE_LIFETIME * 1000.0
	)
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

	# Find idle pawns near other idle pawns
	var candidates: Array[Dictionary] = []
	for p in all_pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p._state != p.State.IDLE:
			continue
		if p.data == null:
			continue
		# Check if near another idle pawn
		var has_neighbor: bool = false
		for other in all_pawns:
			if other == p or other == null or not is_instance_valid(other):
				continue
			if other._state != other.State.IDLE:
				continue
			var dist: float = p.global_position.distance_squared_to(other.global_position)  # OPTIMIZATION: Avoid sqrt
			if dist <= BUBBLE_RADIUS * BUBBLE_RADIUS:
				has_neighbor = true
				break
		if has_neighbor:
			candidates.append({"pawn": p, "text": _generate_text(p)})

	if candidates.is_empty():
		return

	# Pick one random candidate
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
