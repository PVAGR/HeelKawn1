extends RefCounted
class_name ProceduresPawnVisualizer

## Procedural pixel-art humanoid sprite renderer for pawns.
## Generates unique, state-responsive figures based on PawnData appearance fields.
## Uses canvas drawing (draw_circle, draw_line, draw_rect) for deterministic pixel art.

# State enum (must match Pawn.State)
const State = {
	IDLE = 0,
	WALKING_TO_JOB = 1,
	WORKING = 2,
	HAULING = 3,
	GOING_TO_EAT = 4,
	EATING = 5,
	GOING_TO_BED = 6,
	SLEEPING = 7,
	FETCHING_MATERIAL = 8,
	DRAFT_WALK = 9,
	TEACHING = 10,
	CHALLENGE = 11,
	GATHERING = 12,
	CRAFTING = 13,
	FLEEING = 14,
	HIDING = 15,
}

# Hair style constants (must match PawnData.HairStyle)
const HairStyle = {
	NONE = 0,
	SHORT = 1,
	MOHAWK = 2,
	BUN = 3,
}

# Body type constants (must match PawnData.BodyType)
const BodyType = {
	SLIM = 0,
	AVERAGE = 1,
	BROAD = 2,
}

const BASE_RADIUS = 3.5
const SLIM_MULT = 0.87
const BROAD_MULT = 1.13

#---------------------------------------------------------------------------
# Main Entry Point
#---------------------------------------------------------------------------

static func draw_pawn(
	canvas_item: CanvasItem,
	pos: Vector2,
	state: int,
	anim_t: float,
	data,
	body_radius: float = 3.5
) -> void:
	"""Main entry point. Renders a complete pawn at the given position."""
	
	# Determine pose based on state
	var pose_type = _get_pose_type(state)
	
	# Draw body structure (head, torso, arms, legs)
	_draw_humanoid_body(canvas_item, pos, data, pose_type, anim_t, body_radius)
	
	# Draw hair on top
	_draw_humanoid_hair(canvas_item, pos, data, pose_type, body_radius)
	
	# Draw apparel (clothing) overlay
	_draw_humanoid_apparel(canvas_item, pos, data, pose_type, body_radius)

#---------------------------------------------------------------------------
# Pose Type Determination
#---------------------------------------------------------------------------

static func _get_pose_type(state: int) -> int:
	"""Map state to pose category: idle, walk, work, sleep, eat."""
	match state:
		State.IDLE, State.GOING_TO_JOB, State.GOING_TO_EAT, State.GOING_TO_BED, State.FETCHING_MATERIAL:
			return 0  # IDLE
		State.WALKING_TO_JOB, State.HAULING, State.DRAFT_WALK:
			return 1  # WALK
		State.WORKING, State.CRAFTING, State.GATHERING:
			return 2  # WORK
		State.SLEEPING:
			return 3  # SLEEP
		State.EATING:
			return 4  # EAT
		State.TEACHING, State.CHALLENGE, State.FLEEING, State.HIDING:
			return 2  # WORK (alert/active)
		_:
			return 0  # Default to idle

#---------------------------------------------------------------------------
# Body Rendering
#---------------------------------------------------------------------------

static func _draw_humanoid_body(
	canvas_item: CanvasItem,
	pos: Vector2,
	data,
	pose_type: int,
	anim_t: float
) -> void:
	"""Draw the main body structure (head, torso, arms, legs) based on pose."""
	
	var radius = _get_body_radius(data)
	var color = data.color
	
	match pose_type:
		0:  # IDLE
			_draw_pose_idle(canvas_item, pos, radius, color)
		1:  # WALK
			_draw_pose_walk(canvas_item, pos, radius, color, anim_t)
		2:  # WORK
			_draw_pose_work(canvas_item, pos, radius, color)
		3:  # SLEEP
			_draw_pose_sleep(canvas_item, pos, radius, color)
		4:  # EAT
			_draw_pose_eat(canvas_item, pos, radius, color)

#---------------------------------------------------------------------------
# Individual Poses
#---------------------------------------------------------------------------

static func _draw_pose_idle(canvas_item: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	"""Standing pose: upright, arms at sides."""
	
	# Head
	canvas_item.draw_circle(pos + Vector2(0, -radius * 1.8), radius * 0.7, color)
	
	# Torso
	canvas_item.draw_rect(
		Rect2(pos.x - radius * 0.5, pos.y - radius * 0.6, radius, radius * 1.2),
		color
	)
	
	# Left arm
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.6, -radius * 0.3),
		pos + Vector2(-radius * 0.9, radius * 0.4),
		color, 1.0
	)
	
	# Right arm
	canvas_item.draw_line(
		pos + Vector2(radius * 0.6, -radius * 0.3),
		pos + Vector2(radius * 0.9, radius * 0.4),
		color, 1.0
	)
	
	# Left leg
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.3, radius * 0.6),
		pos + Vector2(-radius * 0.3, radius * 1.5),
		color, 1.0
	)
	
	# Right leg
	canvas_item.draw_line(
		pos + Vector2(radius * 0.3, radius * 0.6),
		pos + Vector2(radius * 0.3, radius * 1.5),
		color, 1.0
	)

static func _draw_pose_walk(canvas_item: CanvasItem, pos: Vector2, radius: float, color: Color, anim_t: float) -> void:
	"""Walking pose: legs animate in 4-frame cycle, torso sways."""
	
	# Determine walk frame (0–3)
	var frame = int((anim_t * 4.0)) % 4
	var torso_bob = sin(anim_t * TAU) * 2.0
	var adjusted_pos = pos + Vector2(0, torso_bob)
	
	# Head
	canvas_item.draw_circle(adjusted_pos + Vector2(0, -radius * 1.8), radius * 0.7, color)
	
	# Torso
	canvas_item.draw_rect(
		Rect2(adjusted_pos.x - radius * 0.5, adjusted_pos.y - radius * 0.6, radius, radius * 1.2),
		color
	)
	
	# Arm swing (opposite to leading leg)
	var left_arm_forward = (frame == 0 or frame == 1)
	var left_arm_y = -radius * 0.3 + (10 if left_arm_forward else -5)
	var right_arm_y = -radius * 0.3 + (-5 if left_arm_forward else 10)
	
	canvas_item.draw_line(
		adjusted_pos + Vector2(-radius * 0.6, left_arm_y),
		adjusted_pos + Vector2(-radius * 0.9, radius * 0.3),
		color, 1.0
	)
	
	canvas_item.draw_line(
		adjusted_pos + Vector2(radius * 0.6, right_arm_y),
		adjusted_pos + Vector2(radius * 0.9, radius * 0.3),
		color, 1.0
	)
	
	# Legs animate
	var left_leg_forward = (frame == 0 or frame == 1)
	var left_leg_offset_x = -radius * 0.5 if left_leg_forward else -radius * 0.1
	var right_leg_offset_x = radius * 0.1 if left_leg_forward else radius * 0.5
	
	# Left leg
	canvas_item.draw_line(
		adjusted_pos + Vector2(left_leg_offset_x, radius * 0.6),
		adjusted_pos + Vector2(left_leg_offset_x, radius * 1.5),
		color, 1.0
	)
	
	# Right leg
	canvas_item.draw_line(
		adjusted_pos + Vector2(right_leg_offset_x, radius * 0.6),
		adjusted_pos + Vector2(right_leg_offset_x, radius * 1.5),
		color, 1.0
	)

static func _draw_pose_work(canvas_item: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	"""Working pose: bent forward, arms raised."""
	
	# Head (bent forward)
	canvas_item.draw_circle(pos + Vector2(0.5, -radius * 1.5), radius * 0.7, color)
	
	# Torso (bent ±15°)
	var torso_center = pos + Vector2(radius * 0.3, -radius * 0.2)
	canvas_item.draw_rect(
		Rect2(torso_center.x - radius * 0.5, torso_center.y, radius, radius * 1.0),
		color
	)
	
	# Left arm (raised)
	canvas_item.draw_line(
		torso_center + Vector2(-radius * 0.5, -radius * 0.3),
		torso_center + Vector2(-radius * 0.8, -radius * 1.2),
		color, 1.0
	)
	
	# Right arm (raised)
	canvas_item.draw_line(
		torso_center + Vector2(radius * 0.5, -radius * 0.3),
		torso_center + Vector2(radius * 0.8, -radius * 1.2),
		color, 1.0
	)
	
	# Left leg (planted)
	canvas_item.draw_line(
		torso_center + Vector2(-radius * 0.3, radius * 1.0),
		torso_center + Vector2(-radius * 0.3, radius * 1.8),
		color, 1.0
	)
	
	# Right leg (planted)
	canvas_item.draw_line(
		torso_center + Vector2(radius * 0.3, radius * 1.0),
		torso_center + Vector2(radius * 0.3, radius * 1.8),
		color, 1.0
	)

static func _draw_pose_sleep(canvas_item: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	"""Sleeping pose: horizontal, head on pillow."""
	
	# Head (resting)
	canvas_item.draw_circle(pos + Vector2(-radius * 1.2, radius * 0.2), radius * 0.7, color)
	
	# Torso (horizontal)
	canvas_item.draw_rect(
		Rect2(pos.x - radius * 1.5, pos.y - radius * 0.3, radius * 2.0, radius * 0.6),
		color
	)
	
	# Left arm (folded)
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.5, -radius * 0.1),
		pos + Vector2(-radius * 1.0, radius * 0.3),
		color, 1.0
	)
	
	# Right arm (folded under)
	canvas_item.draw_line(
		pos + Vector2(radius * 0.5, -radius * 0.1),
		pos + Vector2(radius * 1.0, radius * 0.3),
		color, 1.0
	)
	
	# Legs (extended)
	canvas_item.draw_line(
		pos + Vector2(radius * 1.0, -radius * 0.3),
		pos + Vector2(radius * 1.5, -radius * 0.5),
		color, 1.0
	)
	
	canvas_item.draw_line(
		pos + Vector2(radius * 0.9, radius * 0.1),
		pos + Vector2(radius * 1.4, radius * 0.3),
		color, 1.0
	)

static func _draw_pose_eat(canvas_item: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	"""Eating pose: sitting, head up, one arm raised."""
	
	# Head (up)
	canvas_item.draw_circle(pos + Vector2(0, -radius * 1.5), radius * 0.7, color)
	
	# Torso (sitting)
	canvas_item.draw_rect(
		Rect2(pos.x - radius * 0.5, pos.y - radius * 0.3, radius, radius * 0.8),
		color
	)
	
	# Left arm (raised, holding food)
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.5, -radius * 0.1),
		pos + Vector2(-radius * 0.9, -radius * 0.9),
		color, 1.0
	)
	
	# Right arm (at side)
	canvas_item.draw_line(
		pos + Vector2(radius * 0.5, -radius * 0.1),
		pos + Vector2(radius * 0.8, radius * 0.3),
		color, 1.0
	)
	
	# Legs (bent, sitting)
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.3, radius * 0.5),
		pos + Vector2(-radius * 0.3, radius * 1.0),
		color, 1.0
	)
	
	canvas_item.draw_line(
		pos + Vector2(radius * 0.3, radius * 0.5),
		pos + Vector2(radius * 0.3, radius * 1.0),
		color, 1.0
	)

#---------------------------------------------------------------------------
# Hair Rendering
#---------------------------------------------------------------------------

static func _draw_humanoid_hair(
	canvas_item: CanvasItem,
	pos: Vector2,
	data,
	pose_type: int
) -> void:
	"""Draw hair style above head."""
	
	if data.hair_style == HairStyle.NONE:
		return
	
	var head_pos = pos + Vector2(0, -data.color_radius * 1.8) if pose_type != 3 else pos + Vector2(-data.color_radius * 1.2, data.color_radius * 0.2)
	var color = data.hair_color
	var radius = _get_body_radius(data)
	
	match data.hair_style:
		HairStyle.SHORT:
			# Short cap above head
			canvas_item.draw_arc(head_pos, radius * 0.9, 0, PI, 2, color)
		
		HairStyle.MOHAWK:
			# Spiky ridge down center
			for i in range(3):
				var spike_pos = head_pos + Vector2(0, -radius * 0.5 - i * 0.5)
				canvas_item.draw_circle(spike_pos, 0.5, color)
		
		HairStyle.BUN:
			# Bun on top
			canvas_item.draw_circle(head_pos + Vector2(0, -radius * 1.2), radius * 0.5, color)

#---------------------------------------------------------------------------
# Apparel/Clothing Rendering
#---------------------------------------------------------------------------

static func _draw_humanoid_apparel(
	canvas_item: CanvasItem,
	pos: Vector2,
	data,
	pose_type: int
) -> void:
	"""Draw clothing trim overlay on shoulders and waist."""
	
	var color = data.apparel_color
	var radius = _get_body_radius(data)
	
	# Shoulder trim (left)
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.6, -radius * 0.3),
		pos + Vector2(-radius * 0.4, -radius * 0.5),
		color, 0.5
	)
	
	# Shoulder trim (right)
	canvas_item.draw_line(
		pos + Vector2(radius * 0.6, -radius * 0.3),
		pos + Vector2(radius * 0.4, -radius * 0.5),
		color, 0.5
	)
	
	# Waist trim
	canvas_item.draw_line(
		pos + Vector2(-radius * 0.5, radius * 0.4),
		pos + Vector2(radius * 0.5, radius * 0.4),
		color, 0.5
	)

#---------------------------------------------------------------------------
# Helper Functions
#---------------------------------------------------------------------------

static func _get_body_radius(data) -> float:
	"""Calculate body radius based on body_type."""
	match data.body_type:
		BodyType.SLIM:
			return BASE_RADIUS * SLIM_MULT
		BodyType.BROAD:
			return BASE_RADIUS * BROAD_MULT
		_:  # AVERAGE
			return BASE_RADIUS
