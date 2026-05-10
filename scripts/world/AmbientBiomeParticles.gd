extends Node2D
## AmbientBiomeParticles — persistent particle systems for atmosphere.
## Forest: drifting leaves. Plains: pollen. Desert: sand wisps.
## Night near water: fireflies. Tundra: snow flurries.

const REFRESH_EVERY_N_TICKS: int = 120
const MAX_PARTICLE_SYSTEMS: int = 6

var _world: World = null
var _camera: Camera2D = null
var _tick_counter: int = 0

# Active particle systems
var _systems: Array[Dictionary] = []  # {particles: GPUParticles2D, biome: int, position: Vector2}


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 7  # Above world overlay, below pawns


func _process(_delta: float) -> void:
	_tick_counter += 1
	if _tick_counter % REFRESH_EVERY_N_TICKS == 0:
		_refresh_systems()


func _refresh_systems() -> void:
	if _world == null or _world.data == null or _camera == null:
		return
	var data: WorldData = _world.data
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
	if not data.in_bounds(cam_tile.x, cam_tile.y):
		return
	# Determine dominant biome near camera
	var biome_counts: Dictionary = {}
	var scan_r: int = 8
	for dy in range(-scan_r, scan_r + 1, 2):
		for dx in range(-scan_r, scan_r + 1, 2):
			var tx: int = cam_tile.x + dx
			var ty: int = cam_tile.y + dy
			if not data.in_bounds(tx, ty):
				continue
			var b: int = data.biomes[data.index(tx, ty)]
			if not biome_counts.has(b):
				biome_counts[b] = 0
			biome_counts[b] += 1
	# Find dominant biome
	var dominant: int = Biome.Type.PLAINS
	var max_count: int = 0
	for b in biome_counts:
		if int(biome_counts[b]) > max_count:
			max_count = int(biome_counts[b])
			dominant = int(b)
	# Check if it's night
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count) if DayNightCycle != null else false
	# Determine what particle types to spawn
	var desired: Array[Dictionary] = []
	# Forest: leaves
	if dominant == Biome.Type.FOREST:
		desired.append({"biome": Biome.Type.FOREST, "offset": Vector2(-30, -20)})
		desired.append({"biome": Biome.Type.FOREST, "offset": Vector2(25, 15)})
	# Plains: pollen
	if dominant == Biome.Type.PLAINS:
		desired.append({"biome": Biome.Type.PLAINS, "offset": Vector2(-20, -15)})
	# Desert: sand wisps
	if dominant == Biome.Type.DESERT:
		desired.append({"biome": Biome.Type.DESERT, "offset": Vector2(0, 0)})
	# Tundra: snow flurries
	if dominant == Biome.Type.TUNDRA:
		desired.append({"biome": Biome.Type.TUNDRA, "offset": Vector2(0, -10)})
	# Night near water: fireflies
	if is_night and dominant == Biome.Type.WATER:
		desired.append({"biome": Biome.Type.WATER, "offset": Vector2(0, 0)})
	# Always: if night and near forest, add fireflies
	if is_night and dominant == Biome.Type.FOREST:
		desired.append({"biome": -1, "offset": Vector2(15, 10)})  # -1 = fireflies
	# Trim to max
	while desired.size() > MAX_PARTICLE_SYSTEMS:
		desired.pop_back()
	# Ensure we have the right number of systems
	while _systems.size() < desired.size():
		var ps: GPUParticles2D = _make_particle_system(0)
		add_child(ps)
		_systems.append({"particles": ps, "biome": -2, "position": Vector2.ZERO})
	# Update existing systems
	for i in range(_systems.size()):
		var sys: Dictionary = _systems[i]
		var ps: GPUParticles2D = sys["particles"]
		if i < desired.size():
			var d: Dictionary = desired[i]
			var new_biome: int = int(d["biome"])
			if int(sys["biome"]) != new_biome:
				# Recreate with new biome config
				remove_child(ps)
				ps.queue_free()
				var new_ps: GPUParticles2D = _make_particle_system(new_biome)
				add_child(new_ps)
				_systems[i] = {"particles": new_ps, "biome": new_biome, "position": _camera.global_position + Vector2(d["offset"])}
				new_ps.position = _camera.global_position + Vector2(d["offset"])
				new_ps.emitting = true
			else:
				# Just update position to follow camera
				ps.position = _camera.global_position + Vector2(d["offset"])
				ps.emitting = true
		else:
			# Deactivate unused
			ps.emitting = false


func _make_particle_system(biome: int) -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.name = "Ambient_%d" % biome
	p.local_coords = false
	p.z_index = 7
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.8
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	match biome:
		Biome.Type.FOREST:
			# Drifting leaves
			p.amount = 6
			p.lifetime = 3.0
			mat.direction = Vector3(1.0, 0.5, 0.0)
			mat.spread = 30.0
			mat.gravity = Vector3(0.0, 2.0, 0.0)
			mat.initial_velocity_min = 5.0
			mat.initial_velocity_max = 15.0
			mat.scale_min = 0.5
			mat.scale_max = 1.2
			p.modulate = Color8(100, 140, 50, 80)
		Biome.Type.PLAINS:
			# Pollen dust
			p.amount = 8
			p.lifetime = 4.0
			mat.direction = Vector3(0.5, -0.3, 0.0)
			mat.spread = 40.0
			mat.gravity = Vector3(0.0, -0.5, 0.0)
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 6.0
			mat.scale_min = 0.2
			mat.scale_max = 0.5
			p.modulate = Color8(220, 210, 150, 50)
		Biome.Type.DESERT:
			# Sand wisps
			p.amount = 10
			p.lifetime = 2.5
			mat.direction = Vector3(1.0, 0.0, 0.0)
			mat.spread = 15.0
			mat.gravity = Vector3(0.0, 1.0, 0.0)
			mat.initial_velocity_min = 10.0
			mat.initial_velocity_max = 25.0
			mat.scale_min = 0.3
			mat.scale_max = 0.8
			p.modulate = Color8(220, 190, 100, 60)
		Biome.Type.TUNDRA:
			# Snow flurries
			p.amount = 12
			p.lifetime = 3.5
			mat.direction = Vector3(0.3, 1.0, 0.0)
			mat.spread = 25.0
			mat.gravity = Vector3(0.0, 3.0, 0.0)
			mat.initial_velocity_min = 3.0
			mat.initial_velocity_max = 8.0
			mat.scale_min = 0.3
			mat.scale_max = 0.7
			p.modulate = Color8(230, 240, 250, 90)
		Biome.Type.WATER:
			# Fireflies near water at night
			p.amount = 4
			p.lifetime = 5.0
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 60.0
			mat.gravity = Vector3(0.0, -1.0, 0.0)
			mat.initial_velocity_min = 1.0
			mat.initial_velocity_max = 4.0
			mat.scale_min = 0.3
			mat.scale_max = 0.6
			p.modulate = Color8(200, 255, 100, 120)
		-1:
			# Fireflies in forest at night
			p.amount = 5
			p.lifetime = 6.0
			mat.direction = Vector3(0.0, -0.5, 0.0)
			mat.spread = 70.0
			mat.gravity = Vector3(0.0, -0.5, 0.0)
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 3.0
			mat.scale_min = 0.2
			mat.scale_max = 0.5
			p.modulate = Color8(180, 255, 80, 100)
		_:
			p.amount = 4
			p.lifetime = 3.0
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 30.0
			mat.gravity = Vector3(0.0, -1.0, 0.0)
			mat.initial_velocity_min = 2.0
			mat.initial_velocity_max = 5.0
			mat.scale_min = 0.3
			mat.scale_max = 0.6
			p.modulate = Color8(200, 200, 200, 40)
	p.process_material = mat
	return p
