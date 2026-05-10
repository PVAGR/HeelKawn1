extends DirectionalLight2D
## Rotates a DirectionalLight2D to simulate sun/moon movement across the sky.
## Day phase: warm yellow light from above. Night phase: cool blue moonlight.
## Shadow color and energy shift with the day/night cycle.

var _world: World = null


func initialize(world_ref: World) -> void:
	_world = world_ref
	# Start with correct position
	_sync_to_tick(GameManager.tick_count)


func _process(_delta: float) -> void:
	_sync_to_tick(GameManager.tick_count)


func _sync_to_tick(tick: int) -> void:
	if DayNightCycle == null:
		return
	var phase: float = float(tick % SimTime.TICKS_PER_VISUAL_DAY) / float(SimTime.TICKS_PER_VISUAL_DAY)
	# Sun angle: rises east (phase 0.25) → overhead (0.5) → sets west (0.75)
	# Night: moon from west (0.75) → overhead (0.0) → east (0.25)
	# Map phase to rotation: 0=midnight, 0.25=dawn, 0.5=noon, 0.75=dusk
	# Rotation: 0° = light from right, 90° = from below, 180° = from left, 270° = from above
	# At noon (0.5): light from above = 270°
	# At dawn (0.25): light from right = 0°
	# At dusk (0.75): light from left = 180°
	# At midnight (0.0): light from below = 90°
	var angle_deg: float = phase * 360.0
	rotation_degrees = angle_deg

	# Energy: bright at noon, dim at night
	var is_night: bool = DayNightCycle.is_night_for_tick(tick)
	if is_night:
		# Moon: cool blue, low energy
		color = Color8(140, 160, 220)
		energy = 0.15
		shadow_color = Color(0.0, 0.0, 0.1, 0.3)
	else:
		# Sun: warm yellow, energy varies with height
		var sun_height: float = sin(phase * TAU)  # -1 at midnight, +1 at noon
		var sun_energy: float = clampf(0.2 + sun_height * 0.4, 0.1, 0.6)
		color = Color8(255, 240, 200)
		energy = sun_energy
		shadow_color = Color(0.0, 0.0, 0.0, 0.25 + 0.15 * (1.0 - sun_height))
