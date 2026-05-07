extends Node
## PawnChatterBubbles - Shows speech bubbles above pawns when they work/communicate
##
## Displays floating text above pawns:
## - When claiming jobs ("Building wall!")
## - When completing tasks ("Done!")
## - When talking to other pawns (gossip, teaching)
## - When expressing needs ("Hungry...", "Tired...")
##
## Bubbles fade after 3 seconds, stack max 2 per pawn

const BUBBLE_LIFETIME_SEC: float = 3.0
const MAX_BUBBLES_PER_PAWN: int = 2
const BUBBLE_FONT_SIZE: int = 11
const BUBBLE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const BUBBLE_BG: Color = Color(0.0, 0.0, 0.0, 0.75)
const BUBBLE_BORDER: Color = Color(0.85, 0.78, 0.40, 0.9)

# Cache of active bubbles per pawn
var pawn_bubbles: Dictionary = {}  # pawn_id -> [bubble_nodes]


func _ready() -> void:
	# Auto-cleanup old bubbles
	var timer: Timer = Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_cleanup_old_bubbles)
	add_child(timer)


func _exit_tree() -> void:
	# Cleanup all bubbles when node is freed
	for pawn_id in pawn_bubbles:
		var bubbles: Array = pawn_bubbles[pawn_id]
		for bubble in bubbles:
			if is_instance_valid(bubble):
				bubble.queue_free()
	pawn_bubbles.clear()


## Show speech bubble above pawn
func show_bubble(pawn_id: int, pawn_node: Node2D, text: String, bubble_type: String = "speech") -> void:
	if pawn_node == null:
		return
	
	# Remove oldest bubble if too many
	if pawn_bubbles.has(pawn_id):
		var bubbles: Array = pawn_bubbles[pawn_id]
		while bubbles.size() >= MAX_BUBBLES_PER_PAWN:
			var old_bubble: Node = bubbles.pop_front()
			if is_instance_valid(old_bubble):
				old_bubble.queue_free()
	
	# Create bubble node
	var bubble: Node = _create_bubble(pawn_node, text, bubble_type)
	if bubble == null:
		return
	
	# Add to pawn's bubble list
	if not pawn_bubbles.has(pawn_id):
		pawn_bubbles[pawn_id] = []
	pawn_bubbles[pawn_id].append(bubble)
	
	# Auto-fade after lifetime
	var timer: Timer = Timer.new()
	timer.wait_time = BUBBLE_LIFETIME_SEC
	timer.autostart = true
	# Use weakref to avoid capturing freed bubble
	var bubble_weak: WeakRef = weakref(bubble)
	timer.timeout.connect(func():
		var b: Node = bubble_weak.get_ref()
		if b != null and is_instance_valid(b):
			_fade_out_bubble(b)
		timer.queue_free()
	)
	add_child(timer)


func _create_bubble(pawn_node: Node2D, text: String, bubble_type: String) -> Node:
	# Create container panel
	var panel: PanelContainer = PanelContainer.new()
	
	# Style
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BUBBLE_BG
	style.border_color = BUBBLE_BORDER
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	# Label
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", BUBBLE_FONT_SIZE)
	label.add_theme_color_override("font_color", BUBBLE_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	
	# Add to pawn's parent (world viewport)
	var viewport: Node = pawn_node.get_parent()
	if viewport == null:
		viewport = get_node_or_null("/root/Main/WorldViewport")
	if viewport == null:
		return null
	
	viewport.add_child(panel)
	
	# Position above pawn
	_update_bubble_position(panel, pawn_node)

	# Connect to pawn's movement for following - use weakref to avoid capturing freed pawn
	if pawn_node.has_signal("tree_exiting"):
		var panel_weak: WeakRef = weakref(panel)
		pawn_node.tree_exiting.connect(func():
			var p: Node = panel_weak.get_ref()
			if p != null and is_instance_valid(p):
				p.queue_free()
		)

	return panel


func _update_bubble_position(bubble: Node, pawn_node: Node2D) -> void:
	if not is_instance_valid(bubble) or not is_instance_valid(pawn_node):
		return
	
	var control: Control = bubble as Control
	if control == null:
		return
	
	# Position above pawn (world coordinates)
	var pawn_pos: Vector2 = pawn_node.global_position
	var bubble_size: Vector2 = control.size
	
	control.global_position = Vector2(
		pawn_pos.x - bubble_size.x / 2,
		pawn_pos.y - 40  # 40px above pawn
	)


func _fade_out_bubble(bubble: Node) -> void:
	if not is_instance_valid(bubble):
		return
	
	# Tween fade out
	var tween: Tween = create_tween()
	tween.tween_property(bubble, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
	)


func _cleanup_old_bubbles() -> void:
	# Remove bubbles for pawns that no longer exist
	var to_remove: Array = []
	for pawn_id in pawn_bubbles:
		var bubbles: Array = pawn_bubbles[pawn_id]
		var valid_bubbles: Array = []
		for bubble in bubbles:
			if is_instance_valid(bubble):
				valid_bubbles.append(bubble)
		if valid_bubbles.is_empty():
			to_remove.append(pawn_id)
		else:
			pawn_bubbles[pawn_id] = valid_bubbles
	
	for pawn_id in to_remove:
		pawn_bubbles.erase(pawn_id)


## Get bubble text for job type
func get_job_bubble_text(job_type: int) -> String:
	match job_type:
		5: return "🛏️ Building bed"
		6: return "🧱 Building wall"
		7: return "🚪 Building door"
		10: return "🔥 Building fire pit"
		11: return "🏠 Building storage"
		12: return "⛏️ Mining"
		13: return "🪓 Chopping wood"
		14: return "🌾 Foraging"
		15: return "🏹 Hunting"
		16: return "🌱 Planting seeds"
		17: return "🌾 Harvesting"
		18: return "🍳 Cooking"
		19: return "🔨 Crafting"
		_: return "💼 Working"


## Get bubble text for pawn state/need
func get_need_bubble_text(need_type: String, value: float) -> String:
	match need_type:
		"hunger":
			if value < 20:
				return "😫 Starving!"
			elif value < 40:
				return "😟 Hungry"
			return ""
		"thirst":
			if value < 20:
				return "😫 Thirsty!"
			elif value < 40:
				return "😟 Thirsty"
			return ""
		"tired":
			if value < 20:
				return "😴 Exhausted!"
			elif value < 40:
				return "😪 Tired"
			return ""
		"cold":
			if value < 20:
				return "🥶 Freezing!"
			elif value < 40:
				return "😖 Cold"
			return ""
		"happy":
			if value > 80:
				return "😊 Happy!"
			elif value > 60:
				return "🙂 Content"
			return ""
		_:
			return ""


## Show work bubble when pawn starts job
func show_work_bubble(pawn_id: int, pawn_node: Node2D, job_type: int) -> void:
	var text: String = get_job_bubble_text(job_type)
	show_bubble(pawn_id, pawn_node, text, "work")


## Show chat bubble when pawn talks
func show_chat_bubble(pawn_id: int, pawn_node: Node2D, message: String) -> void:
	show_bubble(pawn_id, pawn_node, "💬 " + message, "chat")


## Show thought bubble for pawn needs
func show_thought_bubble(pawn_id: int, pawn_node: Node2D, need_type: String, value: float) -> void:
	var text: String = get_need_bubble_text(need_type, value)
	if text != "":
		show_bubble(pawn_id, pawn_node, "💭 " + text, "thought")
