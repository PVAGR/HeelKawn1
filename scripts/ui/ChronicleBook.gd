class_name ChronicleBook
extends CanvasLayer

const REFRESH_EVERY_N_TICKS: int = 20
const REFRESH_EVERY_N_TICKS_FAST: int = 40
const REFRESH_EVERY_N_TICKS_ULTRA: int = 60

@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var _text: RichTextLabel = $Panel/Margin/VBox/Scroll/ChronicleText

var _spawner: PawnSpawner = null
var _visible: bool = false
var _hud_dirty: bool = true
var _last_refresh_tick: int = 0


func _ready() -> void:
	layer = 26
	_panel.visible = false
	_close_button.pressed.connect(_toggle_visibility)
	if has_node("/root/GameManager"):
		GameManager.game_tick.connect(_on_tick)
		GameManager.speed_changed.connect(_on_speed_changed)
	_apply_panel_style()


func bind(spawner: PawnSpawner) -> void:
	_spawner = spawner
	_hud_dirty = true
	if _visible:
		_refresh()


func _toggle_visibility() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_hud_dirty = true
		_refresh()


func show_book() -> void:
	if _visible:
		return
	_toggle_visibility()


func hide_book() -> void:
	if not _visible:
		return
	_toggle_visibility()


func _on_tick(tick: int) -> void:
	if not _visible:
		return
	var refresh_stride: int = _refresh_stride_for_speed(GameManager.game_speed)
	if tick % refresh_stride == 0 or _hud_dirty:
		_refresh()
		_hud_dirty = false
		_last_refresh_tick = tick


func _on_speed_changed(_s: float, _p: bool) -> void:
	_hud_dirty = true


func _refresh_stride_for_speed(speed: float) -> int:
	if speed >= 100.0:
		return REFRESH_EVERY_N_TICKS_ULTRA
	if speed >= 50.0:
		return REFRESH_EVERY_N_TICKS_FAST
	return REFRESH_EVERY_N_TICKS


func _apply_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.94)
	style.border_color = Color(0.83, 0.74, 0.50, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)


func _refresh() -> void:
	if _text == null:
		return
	var lines: Array[String] = []
	lines.append("[b][color=#F2D6A2]CHRONICLE BOOK[/color][/b]")
	lines.append("[color=#AFA39A]A running record of the colony's remembered turns.[/color]")
	lines.append("")
	lines.append("[b]Session:[/b]")
	lines.append("  Tick %d" % GameManager.tick_count)
	lines.append("  World seed %d" % (WorldRNG.current_seed() if WorldRNG != null else 0))
	if _spawner != null:
		var living: int = 0
		for pawn in _spawner.pawns:
			if pawn != null and is_instance_valid(pawn) and pawn.data != null:
				living += 1
		lines.append("  Living pawns %d" % living)
	lines.append("")
	lines.append("[b]Recent entries:[/b]")
	if WorldMemory == null:
		lines.append("  [color=#888888]WorldMemory not loaded.[/color]")
	else:
		var recent_events: Array = WorldMemory.get_recent_events(12)
		if recent_events.is_empty():
			lines.append("  [color=#888888]No entries yet.[/color]")
		else:
			for event in recent_events:
				var entry: String = _format_event(event)
				if not entry.is_empty():
					lines.append("  • %s" % entry)
	lines.append("")
	lines.append("[b]Memorials:[/b]")
	if MemorialSystem == null or not MemorialSystem.has_method("get_memorials"):
		lines.append("  [color=#888888]No memorial archive available.[/color]")
	else:
		var memorials: Array = MemorialSystem.get_memorials()
		if memorials.is_empty():
			lines.append("  [color=#888888]No memorials recorded.[/color]")
		else:
			var shown: int = 0
			for memorial in memorials:
				if shown >= 4:
					lines.append("  [color=#888888]...and %d more[/color]" % (memorials.size() - 4))
					break
				var tile: Vector2i = memorial.get("tile", Vector2i.ZERO)
				lines.append("  %s at (%d,%d)" % [
					str(memorial.get("memorial_type", "memorial")),
					tile.x,
					tile.y,
				])
				shown += 1
	_text.clear()
	_text.append_text("\n".join(lines))


func _format_event(ev: Dictionary) -> String:
	var event_type: String = str(ev.get("type", "unknown"))
	var tick: int = int(ev.get("tick", ev.get("t", 0)))
	var age_ticks: int = maxi(0, GameManager.tick_count - tick)
	var age_label: String = "%d ticks ago" % age_ticks if age_ticks < 60 else "%d min ago" % int(age_ticks / 60)
	match event_type:
		"pawn_death":
			return "Death at %s" % age_label
		"birth", "pawn_birth":
			return "Birth at %s" % age_label
		"building_constructed":
			return "Built %s (%s)" % [str(ev.get("building_type", "structure")), age_label]
		"knowledge_inscribed", "knowledge_read", "teaching_event":
			return "%s (%s)" % [event_type.replace("_", " ").capitalize(), age_label]
		"memorial_created":
			return "Memorial added (%s)" % age_label
		_:
			return "%s (%s)" % [event_type.replace("_", " "), age_label]
