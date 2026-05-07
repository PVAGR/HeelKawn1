class_name CommandIndicator
extends Node2D

## Visual feedback for issued commands. Shows a target reticle on the
## ordered tile that fades over 3 seconds. Also shows a brief text
## label ("Move", "Forage", "Chop", "Mine", "Hunt", "Defend").

const FADE_DURATION: float = 3.0
const RETICLE_RADIUS: float = 6.0
const RETICLE_SEGMENTS: int = 4
const RETICLE_GAP: float = 0.4  # radians gap per segment
const LABEL_OFFSET: Vector2 = Vector2(0.0, -12.0)

var _indicators: Array[Dictionary] = []
var _world: World = null


func initialize(world_ref: World) -> void:
	_world = world_ref


func show_indicator(tile: Vector2i, order_type: String) -> void:
	if _world == null:
		return
	var world_pos: Vector2 = _world.tile_to_world(tile)
	var color: Color = _color_for_order(order_type)
	var label: String = _label_for_order(order_type)
	_indicators.append({
		"pos": world_pos,
		"color": color,
		"label": label,
		"born": Time.get_ticks_msec(),
	})


func _process(_delta: float) -> void:
	var now: float = Time.get_ticks_msec()
	# Remove expired indicators
	var before_size: int = _indicators.size()
	_indicators = _indicators.filter(func(d: Dictionary) -> bool:
		return (now - float(d.get("born", 0.0))) < FADE_DURATION * 1000.0
	)
	# Only redraw if indicators changed or still fading
	if _indicators.size() != before_size or not _indicators.is_empty():
		queue_redraw()


func _draw() -> void:
	var now: float = Time.get_ticks_msec()
	for d in _indicators:
		var pos: Vector2 = d.get("pos", Vector2.ZERO)
		var color: Color = d.get("color", Color.WHITE)
		var label: String = d.get("label", "")
		var born: float = float(d.get("born", 0.0))
		var age: float = (now - born) / 1000.0
		var alpha: float = clampf(1.0 - age / FADE_DURATION, 0.0, 1.0)

		# Animated reticle — rotates slowly
		var rotation: float = age * 1.5
		var r: float = RETICLE_RADIUS + age * 2.0  # Expands slightly
		color.a = alpha

		# Draw 4 arc segments (crosshair)
		for i in range(RETICLE_SEGMENTS):
			var start_angle: float = rotation + (TAU / RETICLE_SEGMENTS) * i + RETICLE_GAP * 0.5
			var end_angle: float = start_angle + (TAU / RETICLE_SEGMENTS) - RETICLE_GAP
			draw_arc(pos, r, start_angle, end_angle, 8, color, 1.2, true)

		# Center dot
		draw_circle(pos, 1.5, Color(color.r, color.g, color.b, alpha * 0.8))

		# Label
		if not label.is_empty() and alpha > 0.2:
			var font: Font = ThemeDB.fallback_font
			var label_pos: Vector2 = pos + LABEL_OFFSET - Vector2(0.0, age * 3.0)
			var label_color: Color = Color(color.r, color.g, color.b, alpha * 0.9)
			var shadow_color: Color = Color(0.0, 0.0, 0.0, alpha * 0.5)
			var str_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
			var centered: Vector2 = label_pos - Vector2(str_size.x * 0.5, 0.0)
			draw_string(font, centered + Vector2(0.5, 0.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, shadow_color)
			draw_string(font, centered, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, label_color)


func _color_for_order(order_type: String) -> Color:
	match order_type:
		"move": return Color(0.45, 0.95, 1.0)    # cyan
		"forage": return Color(0.3, 0.85, 0.3)   # green
		"chop": return Color(0.6, 0.45, 0.2)     # brown
		"mine": return Color(0.85, 0.55, 0.15)   # orange
		"hunt": return Color(0.9, 0.3, 0.2)      # red
		"defend": return Color(0.9, 0.2, 0.15)   # red
		_: return Color(1.0, 0.92, 0.18)         # gold


func _label_for_order(order_type: String) -> String:
	match order_type:
		"move": return "Move"
		"forage": return "Forage"
		"chop": return "Chop"
		"mine": return "Mine"
		"hunt": return "Hunt"
		"defend": return "Defend"
		_: return "Go"
