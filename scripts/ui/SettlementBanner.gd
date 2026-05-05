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


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % UPDATE_EVERY_N_TICKS == 0:
		_refresh_banners()
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
		var name: String = str(d.get("name", "Settlement"))
		var pop: int = int(d.get("population", 0))
		var gov: String = str(d.get("governance_type", ""))
		if pop <= 0:
			continue
		_banners.append({
			"pos": world_pos,
			"name": name,
			"pop": pop,
			"gov": gov,
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
		draw_string(font, name_centered + Vector2(0.5, 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, name_centered, name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, NAME_COLOR)

		# Population
		var pop_text: String = "Pop: %d" % pop
		var pop_pos: Vector2 = name_pos + Vector2(0.0, 9.0)
		var pop_size: Vector2 = font.get_string_size(pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE)
		var pop_centered: Vector2 = pop_pos - Vector2(pop_size.x * 0.5, 0.0)
		draw_string(font, pop_centered + Vector2(0.5, 0.5), pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, pop_centered, pop_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POP_FONT_SIZE, POP_COLOR)

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
