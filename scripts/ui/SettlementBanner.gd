class_name SettlementBanner
extends Node2D

## Floating name + population labels at each settlement's center tile.
## Updates every 60 ticks. Shows settlement name, population count,
## and governance type icon (text-based).

const UPDATE_EVERY_N_TICKS: int = 60
const NAME_FONT_SIZE: int = 7
const POP_FONT_SIZE: int = 5
const NAME_COLOR: Color = Color(0.95, 0.9, 0.75, 0.85)
const POP_COLOR: Color = Color(0.65, 0.6, 0.45, 0.7)
const GOV_COLOR: Color = Color(0.5, 0.55, 0.65, 0.6)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.4)

var _world: World = null
var _tick_counter: int = 0
var _banners: Array[Dictionary] = []


func initialize(world_ref: World) -> void:
	_world = world_ref


var _last_banner_count: int = -1

func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % UPDATE_EVERY_N_TICKS == 0:
		_refresh_banners()
	# Only redraw if banner data changed
	if _banners.size() != _last_banner_count:
		_last_banner_count = _banners.size()
		queue_redraw()


func _refresh_banners() -> void:
	if _world == null or _world.data == null:
		return
	_banners.clear()
	var settlements: Array = SettlementMemory.get_settlements()
	for s in settlements:
		if not s is Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var center_region: int = int(d.get("center_region", -1))
		if center_region < 0:
			continue
		# Convert region key to tile position
		# Region key = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
		# where rx = tx >> 4, ry = ty >> 4 (16x16 tile regions)
		var rx: int = center_region & 0xFFFF
		var ry: int = (center_region >> 16) & 0xFFFF
		var tile_pos: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)  # center of region
		if not _world.data.in_bounds(tile_pos.x, tile_pos.y):
			continue
		var world_pos: Vector2 = _world.tile_to_world(tile_pos)
		var name: String = str(d.get("name", ""))
		if name.is_empty():
			name = "Unnamed"
		var pop: int = int(d.get("population", 0))
		var gov: String = str(d.get("governance_type", ""))
		if pop <= 0:
			continue
		# Compute profession composition dots
		var prof_dots: Array = _get_prof_dots_for_settlement(d)
		_banners.append({
			"pos": world_pos,
			"name": name,
			"pop": pop,
			"gov": gov,
			"prof_dots": prof_dots,
		})


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	for b in _banners:
		var pos: Vector2 = b.get("pos", Vector2.ZERO) - global_position
		var name: String = b.get("name", "Settlement")
		var pop: int = int(b.get("pop", 0))
		var gov: String = b.get("gov", "")

		# Name
		var name_pos: Vector2 = pos + Vector2(0.0, -20.0)
		var name_size: Vector2 = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE)
		var name_centered: Vector2 = name_pos - Vector2(name_size.x * 0.5, 0.0)
		# Background panel behind name
		var bg_rect: Rect2 = Rect2(name_centered - Vector2(2.0, 1.0), name_size + Vector2(4.0, 2.0))
		draw_rect(bg_rect, Color(0.0, 0.0, 0.0, 0.45), true)
		draw_rect(bg_rect, Color(0.85, 0.78, 0.40, 0.15), false)
		# Shadow + text
		draw_string(font, name_centered + Vector2(0.5, 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, name_centered, name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, NAME_COLOR)

		# Population
		var pop_text: String = "Pop: %d" % pop
		var pop_pos: Vector2 = name_pos + Vector2(0.0, 9.0)
		var pop_size: Vector2 = font.get_string_size(pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE)
		var pop_centered: Vector2 = pop_pos - Vector2(pop_size.x * 0.5, 0.0)
		# Background panel behind population
		var pop_bg: Rect2 = Rect2(pop_centered - Vector2(2.0, 1.0), pop_size + Vector2(4.0, 2.0))
		draw_rect(pop_bg, Color(0.0, 0.0, 0.0, 0.35), true)
		draw_string(font, pop_centered + Vector2(0.5, 0.5), pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, pop_centered, pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE, POP_COLOR)

		# Profession composition dots (1-3 colored dots showing dominant roles)
		var prof_dots: Array = b.get("prof_dots", [])
		if prof_dots.size() > 0:
			var dot_x: float = pop_centered.x + pop_size.x + 3.0
			var dot_y: float = pop_pos.y - 1.0
			for dot_color in prof_dots:
				draw_circle(Vector2(dot_x, dot_y), 1.5, dot_color)
				dot_x += 4.0

		# Governance type
		if not gov.is_empty():
			var gov_text: String = _gov_short(gov)
			var gov_pos: Vector2 = pop_pos + Vector2(0.0, 8.0)
			var gov_size: Vector2 = font.get_string_size(gov_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE)
			var gov_centered: Vector2 = gov_pos - Vector2(gov_size.x * 0.5, 0.0)
			draw_string(font, gov_centered, gov_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE, GOV_COLOR)


func _gov_short(gov: String) -> String:
	match gov:
		"elder_council": return "Elder Council"
		"chief": return "Chief"
		"democratic": return "Council"
		"autocratic": return "Autocrat"
		"military": return "Military"
		_: return ""


## Get up to 3 profession-colored dots for a settlement's dominant professions.
func _get_prof_dots_for_settlement(s: Dictionary) -> Array:
	var counts: Dictionary = {}
	var pawns: Variant = s.get("pawns", null)
	if pawns == null or not (pawns is Array):
		return []
	for p in pawns:
		if p == null or not is_instance_valid(p):
			continue
		var data: Variant = p.get("data") if p.has_method("get") else null
		if data == null:
			continue
		var prof: int = int(data.current_profession) if data.current_profession != null else 0
		if prof == 0:
			continue
		if not counts.has(prof):
			counts[prof] = 0
		counts[prof] += 1
	# Sort by count descending, take top 3
	var sorted: Array = counts.keys()
	sorted.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b])
	var dots: Array = []
	for i in range(mini(3, sorted.size())):
		var prof: int = int(sorted[i])
		dots.append(_profession_color(prof))
	return dots


func _profession_color(prof: int) -> Color:
	match prof:
		1: return Color(0.85, 0.65, 0.2)   # FARMER gold
		2: return Color(0.6, 0.6, 0.6)     # BUILDER silver
		3: return Color(0.2, 0.75, 0.3)    # GATHERER green
		4: return Color(0.9, 0.2, 0.2)     # WARRIOR red
		5: return Color(0.3, 0.5, 0.9)     # SCHOLAR blue
		6: return Color(0.85, 0.75, 0.2)   # TRADER amber
		7: return Color(0.55, 0.55, 0.6)   # SMITH steel
		8: return Color(0.3, 0.75, 0.65)   # HEALER teal
		_: return Color.WHITE
