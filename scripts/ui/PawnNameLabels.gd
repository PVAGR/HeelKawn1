class_name PawnNameLabels
extends Node2D

## Shows pawn names above their heads when hovered or selected.
## Also shows a brief status line (profession + current action).
## Lives in world space so labels track pawns naturally.

const LABEL_FONT_SIZE: int = 7
const STATUS_FONT_SIZE: int = 5
const NAME_COLOR: Color = Color(1.0, 0.95, 0.8, 0.9)
const STATUS_COLOR: Color = Color(0.7, 0.7, 0.65, 0.7)
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.5)
const Y_OFFSET: float = -16.0
const HOVER_RADIUS: float = 20.0  # pixels

var _world: World = null
var _camera: Camera2D = null
var _hovered_pawn = null
var _selected_pawn = null


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref


func set_selected_pawn(pawn) -> void:
	_selected_pawn = pawn


func _process(_delta: float) -> void:
	_hovered_pawn = _find_pawn_under_cursor()
	queue_redraw()


func _find_pawn_under_cursor():
	if _camera == null:
		return null
	var mouse_world: Vector2 = _camera.get_global_mouse_position()
	var best = null
	var best_dist: float = HOVER_RADIUS * HOVER_RADIUS
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var spawners: Array = tree.get_nodes_in_group("pawn_spawner")
	if spawners.is_empty():
		return null
	var spawner = spawners[0]
	if spawner == null or not spawner.has_method("get_all_pawns"):
		return null
	for p in spawner.get_all_pawns():
		if p == null or not is_instance_valid(p):
			continue
		var d_sq: float = p.global_position.distance_squared_to(mouse_world)
		if d_sq <= best_dist:
			best = p
			best_dist = d_sq
	return best


func _draw() -> void:
	var to_show: Array = []
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		to_show.append(_selected_pawn)
	if _hovered_pawn != null and is_instance_valid(_hovered_pawn) and _hovered_pawn != _selected_pawn:
		to_show.append(_hovered_pawn)

	var font: Font = ThemeDB.fallback_font

	for pawn in to_show:
		if pawn.data == null:
			continue
		# World-space position: pawn position relative to this node
		var pos: Vector2 = pawn.global_position - global_position
		var name: String = pawn.data.display_name if pawn.data.display_name != "" else "Pawn"
		var prof: String = ""
		if pawn.data.has_method("profession_label_from_enum"):
			prof = pawn.data.profession_label_from_enum(pawn.data.current_profession)

		# Name
		var name_pos: Vector2 = pos + Vector2(0.0, Y_OFFSET)
		var name_size: Vector2 = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var name_centered: Vector2 = name_pos - Vector2(name_size.x * 0.5, 0.0)
		draw_string(font, name_centered + Vector2(0.5, 0.5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, SHADOW_COLOR)
		draw_string(font, name_centered, name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, NAME_COLOR)

		# Status line (profession)
		if not prof.is_empty() and prof != "None":
			var status_text: String = prof
			var status_pos: Vector2 = name_pos + Vector2(0.0, 8.0)
			var status_size: Vector2 = font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE)
			var status_centered: Vector2 = status_pos - Vector2(status_size.x * 0.5, 0.0)
			draw_string(font, status_centered + Vector2(0.5, 0.5), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, SHADOW_COLOR)
			draw_string(font, status_centered, status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, STATUS_FONT_SIZE, STATUS_COLOR)
