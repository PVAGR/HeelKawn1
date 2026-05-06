extends RefCounted
class_name BuildingsVisualizer

## Procedural visualizer for built structures in HeelKawn.
## Draws details for walls, doors, beds, etc. during construction and completion.

static func draw_wall(canvas_item: CanvasItem, pos: Vector2, size: float, color: Color, progress: float = 1.0) -> void:
	# Base wall rect
	var rect := Rect2(pos - Vector2(size/2, size/2), Vector2(size, size))
	canvas_item.draw_rect(rect, color)
	
	# Plank/Stone pattern overlay
	var line_color := color.darkened(0.3)
	line_color.a = 0.5
	
	# Drawing progress-based "scaffolding" or "incomplete" visual
	if progress < 1.0:
		# Draw frame/outline first
		canvas_item.draw_rect(rect, color, false, 1.0)
		# Filled portion based on progress (vertical fill)
		var fill_h := size * progress
		var fill_rect := Rect2(pos.x - size/2, pos.y + size/2 - fill_h, size, fill_h)
		canvas_item.draw_rect(fill_rect, color)
	else:
		# Finished wall details: horizontal "planks" or "bricks"
		for i in range(1, 4):
			var y_off := -size/2 + (size/4) * i
			canvas_item.draw_line(pos + Vector2(-size/2, y_off), pos + Vector2(size/2, y_off), line_color, 0.5)

static func draw_door(canvas_item: CanvasItem, pos: Vector2, size: float, color: Color, progress: float = 1.0, is_open: bool = false) -> void:
	var rect := Rect2(pos - Vector2(size/2, size/2), Vector2(size, size))
	
	if progress < 1.0:
		# Skeleton frame
		canvas_item.draw_rect(rect, color.darkened(0.5), false, 1.0)
		var fill_h := size * progress
		canvas_item.draw_rect(Rect2(pos.x - size/4, pos.y + size/2 - fill_h, size/2, fill_h), color)
	else:
		# Door frame
		canvas_item.draw_rect(rect, color.darkened(0.4), false, 1.5)
		# Inner door panel
		var panel_rect := Rect2(pos - Vector2(size/3, size/3), Vector2(size*0.66, size*0.66))
		if is_open:
			# Visual "open" state: thin panel to the side
			panel_rect = Rect2(pos.x + size/4, pos.y - size/3, size/6, size*0.66)
		canvas_item.draw_rect(panel_rect, color)
		# Doorknob/Handle
		canvas_item.draw_circle(pos + Vector2(size/6, 0), size/10, color.lightened(0.2))

static func draw_bed(canvas_item: CanvasItem, pos: Vector2, size: float, color: Color, progress: float = 1.0) -> void:
	var rect := Rect2(pos - Vector2(size * 0.4, size * 0.6), Vector2(size * 0.8, size * 1.2))
	
	if progress < 1.0:
		# Wood frame only
		canvas_item.draw_rect(rect, color.darkened(0.6), false, 1.0)
	else:
		# Bed frame
		canvas_item.draw_rect(rect, color.darkened(0.3))
		# Mattress/Sheets
		var mattress := Rect2(pos - Vector2(size * 0.35, size * 0.5), Vector2(size * 0.7, size * 1.0))
		canvas_item.draw_rect(mattress, color.lightened(0.1))
		# Pillow
		var pillow := Rect2(pos - Vector2(size * 0.25, size * 0.55), Vector2(size * 0.5, size * 0.25))
		canvas_item.draw_rect(pillow, color.lightened(0.4))

static func draw_fire_pit(canvas_item: CanvasItem, pos: Vector2, size: float, color: Color, anim_t: float) -> void:
	# Stones circle
	var stone_color := Color8(120, 120, 130)
	for i in range(6):
		var angle := i * TAU / 6.0
		var stone_pos := pos + Vector2(cos(angle), sin(angle)) * size * 0.4
		canvas_item.draw_circle(stone_pos, size * 0.15, stone_color)
	
	# Fire flickers
	var flicker := sin(anim_t * 10.0) * 0.2 + 0.8
	var fire_color := color # assuming orange-ish
	canvas_item.draw_circle(pos, size * 0.25 * flicker, fire_color)
	canvas_item.draw_circle(pos, size * 0.15 * flicker, fire_color.lightened(0.3))
