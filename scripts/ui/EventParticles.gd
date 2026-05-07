class_name EventParticles
extends CanvasLayer

## Spawns short-lived GPUParticles2D on world events.
## Fire = orange sparks, death = red scatter, build = dust puff,
## knowledge = blue sparkles, birth = green sparkles, bond = gold hearts.

const POLL_EVERY_N_TICKS: int = 5
const MAX_PARTICLES_PER_POLL: int = 3
const CLEANUP_LIFETIME: float = 1.5

# Event type → particle recipe
const RECIPES: Dictionary = {
	"pawn_death": {"color": Color(0.9, 0.15, 0.1), "amount": 8, "lifetime": 0.6, "speed_min": 10.0, "speed_max": 30.0, "scale_min": 0.3, "scale_max": 0.6, "gravity": Vector3(0.0, 30.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 60.0},
	"starvation_death": {"color": Color(0.6, 0.3, 0.1), "amount": 6, "lifetime": 0.5, "speed_min": 5.0, "speed_max": 15.0, "scale_min": 0.2, "scale_max": 0.4, "gravity": Vector3(0.0, 20.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 45.0},
	"pawn_birth": {"color": Color(0.3, 0.9, 0.4), "amount": 6, "lifetime": 0.5, "speed_min": 8.0, "speed_max": 20.0, "scale_min": 0.2, "scale_max": 0.5, "gravity": Vector3(0.0, -15.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 80.0},
	"building_constructed": {"color": Color(0.7, 0.65, 0.5), "amount": 10, "lifetime": 0.7, "speed_min": 5.0, "speed_max": 18.0, "scale_min": 0.3, "scale_max": 0.7, "gravity": Vector3(0.0, 25.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 40.0},
	"bed_built": {"color": Color(0.8, 0.7, 0.45), "amount": 5, "lifetime": 0.4, "speed_min": 4.0, "speed_max": 12.0, "scale_min": 0.2, "scale_max": 0.4, "gravity": Vector3(0.0, 15.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 30.0},
	"wall_built": {"color": Color(0.6, 0.5, 0.35), "amount": 8, "lifetime": 0.5, "speed_min": 3.0, "speed_max": 10.0, "scale_min": 0.3, "scale_max": 0.6, "gravity": Vector3(0.0, 20.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 25.0},
	"fire_started": {"color": Color(1.0, 0.5, 0.1), "amount": 12, "lifetime": 0.8, "speed_min": 8.0, "speed_max": 25.0, "scale_min": 0.3, "scale_max": 0.8, "gravity": Vector3(0.0, -20.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 30.0},
	"fire_extinguished": {"color": Color(0.5, 0.5, 0.6), "amount": 8, "lifetime": 0.5, "speed_min": 3.0, "speed_max": 12.0, "scale_min": 0.4, "scale_max": 0.8, "gravity": Vector3(0.0, 5.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 50.0},
	"knowledge_discovery": {"color": Color(0.3, 0.5, 1.0), "amount": 8, "lifetime": 0.6, "speed_min": 10.0, "speed_max": 25.0, "scale_min": 0.2, "scale_max": 0.5, "gravity": Vector3(0.0, -12.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 90.0},
	"knowledge_rediscovery": {"color": Color(0.4, 0.6, 1.0), "amount": 6, "lifetime": 0.5, "speed_min": 8.0, "speed_max": 20.0, "scale_min": 0.2, "scale_max": 0.4, "gravity": Vector3(0.0, -10.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 80.0},
	"social_bond_milestone": {"color": Color(1.0, 0.85, 0.3), "amount": 5, "lifetime": 0.5, "speed_min": 6.0, "speed_max": 18.0, "scale_min": 0.2, "scale_max": 0.5, "gravity": Vector3(0.0, -8.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 70.0},
	"crop_harvested": {"color": Color(0.6, 0.85, 0.2), "amount": 6, "lifetime": 0.4, "speed_min": 5.0, "speed_max": 15.0, "scale_min": 0.2, "scale_max": 0.4, "gravity": Vector3(0.0, 15.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 50.0},
	"enemy_killed": {"color": Color(0.9, 0.2, 0.15), "amount": 10, "lifetime": 0.5, "speed_min": 12.0, "speed_max": 30.0, "scale_min": 0.3, "scale_max": 0.6, "gravity": Vector3(0.0, 25.0, 0.0), "direction": Vector3(0.0, -1.0, 0.0), "spread": 70.0},
}

var _world: World = null
var _last_polled_event_id: int = -1
var _tick_counter: int = 0


func _ready() -> void:
	layer = 5


func initialize(world_ref: World) -> void:
	_world = world_ref


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % POLL_EVERY_N_TICKS == 0:
		_poll_events()


func _poll_events() -> void:
	if WorldMemory == null:
		return
	var total: int = WorldMemory.event_count()
	if total == 0:
		return

	var recent: Array = WorldMemory.get_recent_events(mini(20, total))
	if recent.is_empty():
		return

	if _last_polled_event_id < 0:
		var latest: Dictionary = recent[recent.size() - 1] as Dictionary
		_last_polled_event_id = int(latest.get("eid", 0))
		return

	var new_events: Array[Dictionary] = []
	for e in recent:
		var eid: int = int(e.get("eid", 0))
		if eid > _last_polled_event_id:
			new_events.append(e)

	if new_events.is_empty():
		return

	var max_eid: int = _last_polled_event_id
	for e in new_events:
		max_eid = maxi(max_eid, int(e.get("eid", 0)))
	_last_polled_event_id = max_eid

	var spawned: int = 0
	for e in new_events:
		if spawned >= MAX_PARTICLES_PER_POLL:
			break
		var typ: String = str(e.get("type", ""))
		if not RECIPES.has(typ):
			continue
		var pos: Vector2 = _event_world_position(e)
		if pos == Vector2.ZERO:
			continue
		_spawn_particles(typ, pos)
		spawned += 1


func _event_world_position(e: Dictionary) -> Vector2:
	if _world == null:
		return Vector2.ZERO
	# Try x/y first
	if e.has("x") and e.has("y"):
		var tile: Vector2i = Vector2i(int(e.get("x", -1)), int(e.get("y", -1)))
		if tile.x >= 0 and tile.y >= 0:
			return _world.tile_to_world(tile)
	# Try tile dict
	var tv: Variant = e.get("tile", null)
	if tv is Vector2i:
		return _world.tile_to_world(tv as Vector2i)
	if tv is Dictionary:
		var td: Dictionary = tv as Dictionary
		if td.has("x") and td.has("y"):
			return _world.tile_to_world(Vector2i(int(td.get("x", -1)), int(td.get("y", -1))))
	# Try region key
	if e.has("r"):
		var rk: int = int(e.get("r", -1))
		if rk >= 0:
			# Region key = (rx & 0xFFFF) | ((ry & 0xFFFF) << 16)
			# where rx = tx >> 4, ry = ty >> 4 (16x16 tile regions)
			var rx: int = rk & 0xFFFF
			var ry: int = (rk >> 16) & 0xFFFF
			var tile: Vector2i = Vector2i(rx * 16 + 8, ry * 16 + 8)
			return _world.tile_to_world(tile)
	return Vector2.ZERO


func _spawn_particles(event_type: String, world_pos: Vector2) -> void:
	var recipe: Dictionary = RECIPES.get(event_type, {})
	if recipe.is_empty():
		return

	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "EvtParticle_%s_%d" % [event_type, Time.get_ticks_msec()]
	particles.one_shot = true
	particles.emitting = false
	particles.amount = int(recipe.get("amount", 6))
	particles.lifetime = float(recipe.get("lifetime", 0.5))
	particles.explosiveness = 1.0
	particles.preprocess = 0.0
	particles.local_coords = false
	particles.position = world_pos
	particles.z_index = 20

	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = Vector3(float(recipe.get("direction", Vector3(0.0, -1.0, 0.0)).x), float(recipe.get("direction", Vector3(0.0, -1.0, 0.0)).y), float(recipe.get("direction", Vector3(0.0, -1.0, 0.0)).z))
	material.spread = float(recipe.get("spread", 45.0))
	material.gravity = recipe.get("gravity", Vector3(0.0, 20.0, 0.0))
	material.initial_velocity_min = float(recipe.get("speed_min", 5.0))
	material.initial_velocity_max = float(recipe.get("speed_max", 15.0))
	material.scale_min = float(recipe.get("scale_min", 0.2))
	material.scale_max = float(recipe.get("scale_max", 0.5))
	particles.process_material = material
	particles.modulate = recipe.get("color", Color.WHITE)

	add_child(particles)
	particles.emitting = true

	# Cleanup timer
	var cleanup: Timer = Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = CLEANUP_LIFETIME
	# Use weakref to avoid capturing freed particles
	var particles_weak: WeakRef = weakref(particles)
	cleanup.timeout.connect(func() -> void:
		var p: Node = particles_weak.get_ref()
		if p != null and is_instance_valid(p):
			p.queue_free()
		if is_instance_valid(cleanup):
			cleanup.queue_free()
	)
	add_child(cleanup)
	cleanup.start()
