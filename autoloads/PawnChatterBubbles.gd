extends Node
## PawnChatterBubbles - Compact, zoom-stable speech bubbles above pawns
##
## Design rules:
## - Bubbles do NOT scale with camera zoom (anchored in world, sized in screen px)
## - Max 1 bubble per pawn, max 6 bubbles total on screen
## - Short labels only: "Building", "Planting", "Resting", etc.
## - Detail goes to the Action Ledger, not the bubble
## - Per-pawn cooldown prevents spam

const BUBBLE_LIFETIME_SEC: float = 2.5
const MAX_TOTAL_BUBBLES: int = 6
const BUBBLE_FONT_SIZE: int = 9
const BUBBLE_MAX_WIDTH: float = 110.0
const COOLDOWN_SEC: float = 4.0  # Same pawn can't re-bubble for 4s
const BUBBLE_OFFSET_Y: float = -18.0  # Pixels above pawn

const BUBBLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.92)
const BUBBLE_BG: Color = Color(0.0, 0.0, 0.0, 0.72)
const BUBBLE_BORDER: Color = Color(0.85, 0.78, 0.40, 0.7)

# Active bubbles: pawn_id -> { "node": Control, "pawn": WeakRef, "born_msec": int }
var _active: Dictionary = {}
# Per-pawn cooldown: pawn_id -> msec timestamp of last bubble
var _cooldowns: Dictionary = {}
var _cleanup_timer: Timer


func _ready() -> void:
	_cleanup_timer = Timer.new()
	_cleanup_timer.wait_time = 0.5
	_cleanup_timer.autostart = true
	_cleanup_timer.timeout.connect(_tick_cleanup)
	add_child(_cleanup_timer)


func _exit_tree() -> void:
	for pid in _active:
		var entry: Dictionary = _active[pid]
		var n: Control = entry.get("node")
		if n != null and is_instance_valid(n):
			n.queue_free()
	_active.clear()


## Show a compact work bubble above a pawn.
func show_bubble(pawn_id: int, pawn_node: Node2D, text: String, _bubble_type: String = "speech") -> void:
	if pawn_node == null or not is_instance_valid(pawn_node):
		return
	if pawn_node.is_queued_for_deletion():
		return

	var now_msec: int = Time.get_ticks_msec()

	# Per-pawn cooldown
	if _cooldowns.has(pawn_id):
		if now_msec - int(_cooldowns[pawn_id]) < int(COOLDOWN_SEC * 1000.0):
			return

	# If this pawn already has a bubble, replace it
	if _active.has(pawn_id):
		var old: Dictionary = _active[pawn_id]
		var old_node: Control = old.get("node")
		if old_node != null and is_instance_valid(old_node):
			old_node.queue_free()
		_active.erase(pawn_id)

	# Enforce global cap — remove oldest
	while _active.size() >= MAX_TOTAL_BUBBLES:
		_remove_oldest()

	# Truncate text
	var display_text: String = text
	if display_text.length() > 20:
		display_text = display_text.substr(0, 18) + ".."

	# Create bubble
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BUBBLE_BG
	style.border_color = BUBBLE_BORDER
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.set_corner_radius_all(3)
	style.set_content_margin_all(3)
	panel.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = display_text
	label.add_theme_font_size_override("font_size", BUBBLE_FONT_SIZE)
	label.add_theme_color_override("font_color", BUBBLE_COLOR)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BUBBLE_MAX_WIDTH, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	# Add to the UI layer (CanvasLayer) so it doesn't scale with world zoom
	# We'll position it in _process by projecting pawn world pos to screen
	var ui_layer: CanvasLayer = _get_ui_layer()
	if ui_layer == null:
		panel.queue_free()
		return
	ui_layer.add_child(panel)

	_active[pawn_id] = {
		"node": panel,
		"pawn": weakref(pawn_node),
		"born_msec": now_msec,
	}
	_cooldowns[pawn_id] = now_msec

	# Auto-fade timer
	var fade_timer: Timer = Timer.new()
	fade_timer.wait_time = BUBBLE_LIFETIME_SEC
	fade_timer.autostart = true
	var pid: int = pawn_id
	fade_timer.timeout.connect(func():
		_fade_out(pid)
		if is_instance_valid(fade_timer):
			fade_timer.queue_free()
	)
	add_child(fade_timer)


func _process(_delta: float) -> void:
	# Reposition all bubbles above their pawns in screen space
	var camera: Camera2D = _get_camera()
	if camera == null:
		return
	var canvas_transform: Transform2D = camera.get_canvas_transform()
	for pid in _active.keys():
		if not _active.has(pid):
			continue
		var entry: Dictionary = _active[pid]
		var pawn_ref: WeakRef = entry.get("pawn")
		var panel: Control = entry.get("node")
		if pawn_ref == null or panel == null or not is_instance_valid(panel):
			continue
		var pawn: Node2D = pawn_ref.get_ref()
		if pawn == null or not is_instance_valid(pawn):
			continue
		# Project pawn world position to screen via canvas transform
		var world_to_screen: Vector2 = canvas_transform * pawn.global_position
		var bubble_size: Vector2 = panel.size
		panel.position = Vector2(
			world_to_screen.x - bubble_size.x / 2.0,
			world_to_screen.y + BUBBLE_OFFSET_Y - bubble_size.y
		)


func _fade_out(pawn_id: int) -> void:
	if not _active.has(pawn_id):
		return
	var entry: Dictionary = _active[pawn_id]
	var panel: Control = entry.get("node")
	if panel != null and is_instance_valid(panel):
		var tween: Tween = create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.4)
		tween.tween_callback(func():
			if is_instance_valid(panel):
				panel.queue_free()
		)
	_active.erase(pawn_id)


func _remove_oldest() -> void:
	var oldest_pid: int = -1
	var oldest_msec: int = 999999999
	for pid in _active:
		var msec: int = int(_active[pid].get("born_msec", 999999999))
		if msec < oldest_msec:
			oldest_msec = msec
			oldest_pid = pid
	if oldest_pid >= 0:
		var entry: Dictionary = _active[oldest_pid]
		var panel: Control = entry.get("node")
		if panel != null and is_instance_valid(panel):
			panel.queue_free()
		_active.erase(oldest_pid)


func _tick_cleanup() -> void:
	var now_msec: int = Time.get_ticks_msec()
	# Remove stale entries (pawn freed or bubble expired)
	var to_remove: Array = []
	for pid in _active:
		var entry: Dictionary = _active[pid]
		var pawn_ref: WeakRef = entry.get("pawn")
		var panel: Control = entry.get("node")
		var pawn_alive: bool = false
		if pawn_ref != null:
			var p: Node2D = pawn_ref.get_ref()
			pawn_alive = p != null and is_instance_valid(p)
		var panel_alive: bool = panel != null and is_instance_valid(panel)
		if not pawn_alive or not panel_alive:
			if panel_alive:
				panel.queue_free()
			to_remove.append(pid)
	for pid in to_remove:
		_active.erase(pid)
	# Clean old cooldowns
	var cooldown_cutoff: int = now_msec - int(COOLDOWN_SEC * 1000.0 * 3)
	for pid in _cooldowns.keys():
		if int(_cooldowns[pid]) < cooldown_cutoff:
			_cooldowns.erase(pid)


func _get_ui_layer() -> CanvasLayer:
	# Find a CanvasLayer above the world for bubble rendering
	var main: Node = get_node_or_null("/root/Main")
	if main != null:
		var ui_vp: Node = main.get_node_or_null("UI_Viewport")
		if ui_vp != null:
			# UI_Viewport is a SubViewport, not a CanvasLayer.
			# We need to add bubbles to a CanvasLayer that renders above the world.
			pass
	# Fallback: use a dedicated CanvasLayer child
	if not has_node("_BubbleLayer"):
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "_BubbleLayer"
		layer.layer = 10  # Above world, below HUD
		add_child(layer)
		return layer
	return get_node("_BubbleLayer") as CanvasLayer


func _get_camera() -> Camera2D:
	var main: Node = get_node_or_null("/root/Main")
	if main != null:
		var cam: Node = main.get_node_or_null("WorldViewport/Camera2D")
		if cam is Camera2D:
			return cam
	return null


## Get short bubble text for a job type.
func get_job_bubble_text(job_type: int) -> String:
	match job_type:
		Job.Type.BUILD_BED: return "Building"
		Job.Type.BUILD_WALL: return "Building"
		Job.Type.BUILD_DOOR: return "Building"
		Job.Type.BUILD_FIRE_PIT: return "Building"
		Job.Type.BUILD_STORAGE_HUT: return "Building"
		Job.Type.BUILD_MARKER_STONE: return "Carving"
		Job.Type.BUILD_SHRINE: return "Building"
		Job.Type.BUILD_SHELTER: return "Building"
		Job.Type.BUILD_HEARTH: return "Building"
		Job.Type.MINE, Job.Type.MINE_WALL: return "Mining"
		Job.Type.CHOP: return "Chopping"
		Job.Type.FORAGE: return "Foraging"
		Job.Type.HUNT: return "Hunting"
		Job.Type.PLANT_SEEDS: return "Planting"
		Job.Type.HARVEST_CROPS: return "Harvesting"
		Job.Type.COOK_MEAT, Job.Type.COOK_BERRIES: return "Cooking"
		Job.Type.DRY_MEAT: return "Preserving"
		Job.Type.CRAFT_KNIFE, Job.Type.CRAFT_TORCH, Job.Type.CRAFT_PICK, Job.Type.CRAFT_SPEAR: return "Crafting"
		Job.Type.GATHER_FLINT, Job.Type.GATHER_STICK: return "Gathering"
		Job.Type.TEACH_SKILL, Job.Type.APPRENTICESHIP: return "Teaching"
		Job.Type.CARVE_GRAVE_MARKER, Job.Type.CARVE_KNOWLEDGE_STONE, Job.Type.CARVE_LEDGER_STONE: return "Carving"
		Job.Type.TRADE_HAUL: return "Hauling"
		Job.Type.PROTECT, Job.Type.DEFEND: return "Guarding"
		_: return "Working"


## Get bubble text for pawn state/need.
func get_need_bubble_text(need_type: String, value: float) -> String:
	match need_type:
		"hunger":
			if value < 20: return "Starving!"
			elif value < 40: return "Hungry"
			return ""
		"rest":
			if value < 20: return "Exhausted!"
			elif value < 40: return "Tired"
			return ""
		"mood":
			if value > 80: return "Happy"
			elif value < 20: return "Distressed"
			return ""
		_:
			return ""


## Show work bubble when pawn starts job.
func show_work_bubble(pawn_id: int, pawn_node: Node2D, job_type: int) -> void:
	if pawn_node == null or not is_instance_valid(pawn_node):
		return
	if pawn_node.is_queued_for_deletion():
		return
	var text: String = get_job_bubble_text(job_type)
	show_bubble(pawn_id, pawn_node, text, "work")


## Show chat bubble when pawn talks.
func show_chat_bubble(pawn_id: int, pawn_node: Node2D, message: String) -> void:
	if pawn_node == null or not is_instance_valid(pawn_node):
		return
	if pawn_node.is_queued_for_deletion():
		return
	show_bubble(pawn_id, pawn_node, message, "chat")


## Show thought bubble for pawn needs.
func show_thought_bubble(pawn_id: int, pawn_node: Node2D, need_type: String, value: float) -> void:
	if pawn_node == null or not is_instance_valid(pawn_node):
		return
	if pawn_node.is_queued_for_deletion():
		return
	var text: String = get_need_bubble_text(need_type, value)
	if text != "":
		show_bubble(pawn_id, pawn_node, text, "thought")
