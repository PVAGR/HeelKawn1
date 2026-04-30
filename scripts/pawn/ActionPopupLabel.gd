class_name ActionPopupLabel
extends Label

## Floating label above pawns showing AI-driven action context
## Displays personality-influenced motivation, goal context, and memory references

const FADE_DURATION: float = 2.0
const MAX_VISIBLE_TIME: float = 4.0

var _fade_timer: float = 0.0
var _lifetime_timer: float = 0.0
var _is_fading: bool = false


func _ready() -> void:
	visible = false
	modulate = Color.WHITE


func show_action_context(pawn_name: String, action: String, personality_context: String, goal_context: String, memory_context: String) -> void:
	var lines: Array[String] = []
	lines.append("[b]%s[/b]" % pawn_name)
	lines.append(action)
	
	if not personality_context.is_empty():
		lines.append("[color=#dcb478]%s[/color]" % personality_context)
	if not goal_context.is_empty():
		lines.append("[color=#aed581]%s[/color]" % goal_context)
	if not memory_context.is_empty():
		lines.append("[color=#90caf9]%s[/color]" % memory_context)
	
	text = "\n".join(lines)
	visible = true
	modulate.a = 1.0
	_lifetime_timer = 0.0
	_fade_timer = 0.0
	_is_fading = false


func _process(delta: float) -> void:
	if not visible:
		return
	
	_lifetime_timer += delta
	
	if _lifetime_timer >= MAX_VISIBLE_TIME:
		_is_fading = true
	
	if _is_fading:
		_fade_timer += delta
		var progress: float = _fade_timer / FADE_DURATION
		modulate.a = 1.0 - progress
		
		if modulate.a <= 0.0:
			visible = false
			modulate.a = 1.0


func hide_immediately() -> void:
	visible = false
	modulate.a = 1.0
	_lifetime_timer = 0.0
	_fade_timer = 0.0
	_is_fading = false
